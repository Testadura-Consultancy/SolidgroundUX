# ==================================================================================
# SolidGroundUX - Document processor
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2624102
#   Checksum    : acd555d1a7bbec40f8ad485c54e0201cd694327baad0ead049f25a77dfb6f563
#   Source      : doc-processor.sh
#   Type        : library
#   Group       : SDK
#   Subgroup    : Documentation Generator
#   Purpose     : Parse source files for structured comments and assemble normalized
#                 documentation data
#
# Description:
#   Provides the core parsing engine for the SolidGroundUX documentation system.
#
#   The processor:
#     - Iterates source files line-by-line
#     - Interprets structured comment conventions (headers, metadata, sections, items)
#     - Maintains parsing state (header, section hierarchy, current item, etc.)
#     - Normalizes detected elements into a flat render stream (DOC_CONTENT_LINES)
#
#   Parsing is convention-based and deterministic. Each recognized line contributes
#   either state transitions or a normalized documentation record.
#
# Design principles:
#   - Single-pass parsing (no backtracking or multi-phase analysis)
#   - Separation of concerns:
#       * Detection/state mutation
#       * Content normalization
#       * Rendering (handled elsewhere)
#   - Convention over configuration (strict comment grammar)
#   - Minimal side effects outside controlled doc_* and mod_* variables
#   - Transparent state transitions for debuggability
#
# Role in framework:
#   - Core documentation data collector
#   - Produces the canonical DOC_CONTENT_LINES dataset consumed by renderers
#   - Bridges raw source code and higher-level documentation output (HTML, etc.)
#   - Shared parsing engine for all documentation-related tooling
#
# Non-goals:
#   - Rendering output formats (HTML, Markdown, PDF, etc.)
#   - Parsing arbitrary or free-form comments
#   - Semantic analysis of code (only structured comment interpretation)
#   - Cross-file linking or indexing logic
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Enforce source-only, single-load library initialization
        # . Purpose
        #   Ensure the file is sourced as a library and initialized only once.
        #
        # . Behavior
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution when the file is run directly instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Returns immediately when the library was already loaded.
        #
        # Inputs
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals)
        #   SGND_<MODULE>_LOADED
        #
        # . Returns
        #   0 when already loaded or successfully initialized.
        #   Exits with code 2 when executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard
    _sgnd_lib_guard() {
        local lib_base=""
        local guard=""

        lib_base="$(basename "${BASH_SOURCE[0]}" .sh)"
        lib_base="${lib_base//-/_}"
        guard="SGND_${lib_base^^}_LOADED"

        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            printf 'This is a library; source it, do not execute it: %s\n' "${BASH_SOURCE[0]}" >&2
            exit 2
        }

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    if declare -F sgnd_module_init_metadata >/dev/null 2>&1 \
        && declare -F sgnd_header_buffer_load >/dev/null 2>&1; then
        sgnd_module_init_metadata "${BASH_SOURCE[0]}"
    fi
# - Internal API ----------------------------------------------------------------
    # fn: _parse_module_file - Parse one module source file
        # . Purpose
        #   Parse a source file and collect normalized documentation tables.
        #
        # . Behavior
        #   - Validates the source filename argument.
        #   - Resets parser state for the file.
        #   - Reads the file line-by-line in source order.
        #   - Runs detectors in deterministic order.
        #   - Emits normalized content, section, item, metadata, and attribution records.
        #
        # . Arguments
        #   $1  Source file to parse.
        #
        # Outputs (globals):
        #   MOD_TABLE, MOD_ATTRIBUTION, MOD_SECTIONS, MOD_ITEMS, DOC_CONTENT_LINES
        #
        # . Returns
        #   0 on successful parsing.
        #   1 when no source filename is supplied.
        #
        # . Usage
        #   _parse_module_file "/usr/local/lib/solidgroundux/common/sgnd-core.sh"
    _parse_module_file(){
        src_file="${1:-}"
        [[ -z "$src_file" ]] && {
            sayerror "No filename was passed"
            return 1
        }

        _init_localvars
        local total_lines
        total_lines=$(wc -l < "$src_file")

        mod_name="$(basename "$src_file")"
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Line counters, src_linenr tracks current line number in source file, doc_linenr starts counting
            # when a header marker is found
            ((src_linenr++))
            src_line="$line"

            if declare -F _doc_progress_line >/dev/null; then
                _doc_progress_line "$src_linenr" "$total_lines" "$(basename "$src_file")"
            else
                sayprogress \
                    --slot 0 \
                    --current "$src_linenr" \
                    --total "$total_lines" \
                    --label "Parsing $(basename "$src_file")" \
                    --type 5
            fi

            src_haltlineprocessing=0
            
            # Source-level declarations
            _detect_global_array_entry
            _detect_global_array_start

            # Early filter
            _detect_commentseparator
            
            # Start conditions
            _detect_headermarker
            saydebug "after header marker: $src_linetype, $src_linenr, $doc_linenr, $src_line"

            # Stop conditions
            _detect_noncommentline
            (( !doc_started )) && continue

            # Contenttype detection
            _detect_moduletitle

            saydebug "Pre headerfield detection, headersection $doc_headersection, InHeader? $doc_inheader, $doc_linenr, $src_line"
            _detect_headersectionheader
            _detect_headerfields

            _detect_section
            _get_section_comments

            _detect_items

            _detect_default
            
            _emit_contentline

            _guess_nextcontenttype

        done < "$src_file"
        
        return 0
    } 

    # fn: _build_content_ref - Build a stable documentation content reference
        # . Purpose
        #   Create the canonical reference key used to link content to a module, section, and item context.
        #
        # . Behavior
        #   - Joins module, grandparent section, parent section, section, and item values.
        #   - Preserves empty hierarchy parts so the reference shape remains stable.
        #   - Writes the generated reference to stdout.
        #
        # . Arguments
        #   $1  Module name.
        #   $2  Grandparent section name.
        #   $3  Parent section name.
        #   $4  Current section name.
        #   $5  Current item name.
        #
        # . Returns
        #   0 after writing the content reference.
        #
        # . Usage
        #   _build_content_ref "sgnd-core" "Core" "Strings" "Formatting" "sgnd_sgr"
    _build_content_ref() {
        local module_name="${1-}"
        local grandparent_section="${2-}"
        local parent_section="${3-}"
        local section_name="${4-}"
        local item_name="${5-}"

        printf '%s:%s:%s:%s:%s\n' \
            "$module_name" \
            "$grandparent_section" \
            "$parent_section" \
            "$section_name" \
            "$item_name"
    }  




