# ==================================================================================
# SolidgroundUX - Document processor
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : -
#   Source      : doc-processor.sh
#   Type        : library
#   Group       : Developer Tools
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
#     - Normalizes detected elements into a flat render stream (DOC_RENDERED)
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
#   - Minimal side effects outside controlled doc_* and meta_* variables
#   - Transparent state transitions for debuggability
#
# Role in framework:
#   - Core documentation data collector
#   - Produces the canonical DOC_RENDERED dataset consumed by renderers
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
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Behavior:
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
    _sgnd_lib_guard() {
        local lib_base
        local guard

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

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"
# - Local definitions
    # var: Datamodel
        MOD_TABLE_SCHEMA="file|name|title|type|purpose|version|build|group|product"
        MOD_TABLE=()

        MOD_ATTRIBUTION_SCHEMA="modulename|developers|company|client|copyright|license"
        MOD_ATTRIBUTION=()
        
        DOC_RENDERED_SCHEMA="file|source_linenr|doc_linenr|section|parentsection|grandparentsection|commentsection|item|title|contenttype|content"
        DOC_RENDERED=()

    # fn: _init_localvars - Initialize and defune locakl variables
    _init_localvars(){
        src_line=""
        src_linenr=0
        src_linetype=""
        src_haltlineprocessing=0

        mod_product=""
        mod_title=""
        mod_name=""
        
        doc_section=""
        doc_sectionlevel=0
        doc_parentsection=""
        doc_grandparentsection=""

        doc_item=""
        doc_itemtitle=""

        doc_commentsection=""
        doc_linenr=0
        doc_contenttype="" 
        doc_content=""


        doc_inheader=0
        doc_started=0
        doc_emitline=0
    }

    # -- Parser expressions ------------------------------------------------------------
        # Defines the regular expressions used by the source parser.
        #
        # Expressions:
        #   _rgx_header
        #     Matches header boundary lines, for example:
        #       # ==================================================================================
        #
        #   _rgx_moduletitle
        #     Matches the module title line and captures:
        #       1. Product name
        #       2. Module title
        #
        #     Example:
        #       # SolidgroundUX - Library Template
        #
        #   _rgx_commentsectionheader
        #     Matches comment section headers and captures the section name.
        #
        #     Example:
        #       # Metadata:
        #       # Attribution:
        #
        #   _rgx_headerfield
        #     Matches metadata/attribution fields and captures:
        #       1. Field name
        #       2. Field value
        #
        #     Example:
        #       #   Version     : 1.1
        #
        #   _rgx_section
        #     Matches documentation section markers and captures:
        #       1. Section marker depth (-, --, ---)
        #       2. Section title
        #
        #     Example:
        #       # - Chapter ----------------------------------------------------------------
        #       # -- Paragraph -------------------------------------------------------------
        #       # --- Subparagraph ---------------------------------------------------------
    _rgx_header='^# =+[[:space:]]*$'
    _rgx_moduletitle='^#[[:space:]]+([^-]+)[[:space:]]+-[[:space:]]+(.+)[[:space:]]*$'
    _rgx_commentsectionheader='^#[[:space:]]+([^:]+):[[:space:]]*$'
    _rgx_headerfield='^#[[:space:]]+([[:alnum:]_]+)[[:space:]]*:[[:space:]]+(.+)[[:space:]]*$'  
    _rgx_section='^[[:space:]]*#[[:space:]](-{1,3})[[:space:]]+(.+)[[:space:]]*-*[[:space:]]*$'
    _rgx_docitem='^[[:space:]]*#[[:space:]]+([a-z]{2,3})([:$])[[:space:]]+([^[:space:]]+)([[:space:]]+-[[:space:]]+(.+))?[[:space:]]*$'
    _rgx_commentseparator='^[[:space:]]*#[[:space:]]+-{3,}[[:space:]]*$'

    # -- Detection functions
    _detect_noncommentline() {
        (( src_haltlineprocessing )) && return 0

        [[ "$src_line" =~ ^[[:space:]]*# ]] && return 0

        # doc: Some extra documentation
            # line 1
            # line 2
        src_linetype=""
        doc_contenttype=""
        src_haltlineprocessing=1

        saydebug "Non-comment line detected; source/content type reset"
    }

    _detect_headermarker() {
        (( src_haltlineprocessing )) && return 0

        saydebug "Detecting header marker"
        [[ "$src_line" =~ $_rgx_header ]] || return 0

        if (( ! doc_started )); then
            src_linetype="moduleheader"
            doc_inheader=1
            doc_linenr=1
            doc_started=1
            doc_emitline=0
        else
            src_linetype=""
            doc_inheader=0
            doc_commentsection=""
            _action_headerend
        fi

        src_haltlineprocessing=1

        saydebug "Header marker detected"
    }

    _detect_moduletitle() {
        (( doc_inheader == 1 && doc_linenr == 1 )) || return 0

        saydebug "Detecting module title"

        [[ "$src_line" =~ $_rgx_moduletitle ]] || return 0

        mod_product="${BASH_REMATCH[1]}"
        mod_title="${BASH_REMATCH[2]}"
        src_hallineprocessing=1

        saydebug "Module title detected: Product $mod_product, Title $mod_title"
    }

    _detect_headerfields() {       
        (( src_haltlineprocessing )) && return 0

        saydebug "Detecting header fields"

        # Only applies inside the header.
        (( doc_inheader )) || return 0

        # Only applies to Metadata and Attribution sections.
        [[ "$doc_commentsection" == "Metadata" || "$doc_commentsection" == "Attribution" ]] || return 0

        [[ "$src_line" =~ $_rgx_headerfield ]] || return 0

        local field_name
        local field_value
        local var_name

        field_name="${BASH_REMATCH[1]}"
        field_value="${BASH_REMATCH[2]}"

        # Normalize field name for variable use.
        field_name="${field_name,,}"
        field_name="${field_name//-/_}"

        var_name="mod_${field_name}"

        printf -v "$var_name" '%s' "$field_value"
        src_haltlineprocessing=1

        saydebug "Header field detected: $var_name=$field_value"
    }

    _detect_section() {       
        (( src_haltlineprocessing )) && return 0

        saydebug "Detecting sections"

        [[ "$src_line" =~ $_rgx_section ]] || return 0

        local marker
        local section_name
        local section_level

        marker="${BASH_REMATCH[1]}"
        section_name="${BASH_REMATCH[2]}"
        section_name="$(sed -E 's/[[:space:]-]+$//' <<< "$section_name")"

        section_level="${#marker}"

        doc_grandparentsection="$doc_parentsection"
        doc_parentsection="$doc_section"
        doc_section="$section_name"
        doc_sectionlevel="$section_level"

        src_linetype="sectionblock"

        src_haltlineprocessing=1        

        saydebug "Section detected: level $doc_sectionlevel, section $doc_section, parentsection $doc_parentsection, grandparent $doc_grandparentsection"
    }

    _detect_items(){
        (( src_haltlineprocessing )) && return 0

        saydebug "Detecting items"
        if [[ "$src_line" =~ $_rgx_docitem ]]; then
            local item_type="${BASH_REMATCH[1]}"      # fn, var, doc
            local item_marker="${BASH_REMATCH[2]}"    # : or $
            local item_name="${BASH_REMATCH[3]}"
            local item_title="${BASH_REMATCH[5]}"

            if [[ "$item_marker" == '$' ]]; then
                item_is_template=1
            else
                item_is_template=0
            fi
            
            saydebug "Item detected $item_type. $item_marker, $item_name, $item_title"
            
            doc_item="$item_name"
            src_linetype="$item_type"

            case "$item_type" in
                fn)
                    doc_contenttype="functioncomment"
                    ;;
                var)
                    doc_contenttype="variablecomment"
                    ;;
                doc)
                    doc_contenttype="gencomment"
                    ;;
                *)
                    doc_contenttype="itemcomment"
                    ;;
            esac

            src_haltlineprocessing=1
        fi
    }

    _detect_commentsectionheader() {        
        (( src_haltlineprocessing )) && return 0
        
        saydebug "Detecting commentsectionheader"
        [[ "$src_line" =~ $_rgx_commentsectionheader ]] || return 0

        doc_commentsection="${BASH_REMATCH[1]}"
        doc_contenttype="commentsectionheader"
        doc_content="$doc_commentsection"
        [[ "$doc_commentsection" == "Metadata" || "$doc_commentsection" == "Attribution" ]] && doc_emitline=0 || doc_emitline=1

        src_linetype="commentsectionheader"
        src_haltlineprocessing=1

        saydebug "Comment section detected: $doc_commentsection"
    }

    _detect_default(){
        (( src_haltlineprocessing )) && return 0

        (( doc_inheader && $doc_linenr <= 3 )) && doc_contenttype="moduleheader"
        (( doc_inheader && $doc_linenr > 3 )) && doc_contenttype="modulecomment"
        
        [[ -z "$doc_contenttype" ]] && return 0 

        # remove leading whitespace
        doc_content="${src_line#"${src_line%%[![:space:]]*}"}"

        # remove leading '# ' (exactly one # and optional one space)
        doc_content="${doc_content#\#}"
        doc_content="${doc_content# }"

        # remove trailing whitespace
        doc_content="${doc_content%"${doc_content##*[![:space:]]}"}"

        doc_emitline=1

    }

    _get_section_comments() {
        (( src_haltlineprocessing )) && return 0

        [[ "$src_linetype" == "sectioncomment" ]] || return 0

        doc_contenttype="sectioncomment"
        doc_content="$src_line"

        # Strip leading indentation, "#", and exactly one following space.
        doc_content="${doc_content#"${doc_content%%[![:space:]]*}"}"
        doc_content="${doc_content#\# }"

        saydebug "Section comment detected: $doc_contenttype, $doc_linenr, $doc_content, $doc_section, $doc_sectionlevel, $doc_commentsection"
    }

    _detect_commentseparator() {
        (( src_haltlineprocessing )) && return 0

        [[ "$src_line" =~ $_rgx_commentseparator ]] || return 0

        src_haltlineprocessing=1
        doc_contenttype=""
        doc_content=""

        saydebug "Comment separator ignored"
    }

    # -- Action -------------------------------------------------------------------
    _action_headerend() {

        saydebug "Adding module: ${src_file:-}, ${mod_name:-}, ${mod_title:-}, ${mod_type:-}, ${mod_purpose:-}, ${mod_version:-}, ${mod_build:-}, ${mod_group:-}, ${mod_product:-}"

        sgnd_dt_append \
            "$MOD_TABLE_SCHEMA" \
            MOD_TABLE \
            "${src_file:-}" \
            "${mod_name:-}" \
            "${mod_title:-}" \
            "${mod_type:-}" \
            "${mod_purpose:-}" \
            "${mod_version:-}" \
            "${mod_build:-}" \
            "${mod_group:-}" \
            "${mod_product:-}"

        saydebug "Adding module attribution: ${MOD_ATTRIBUTION_SCHEMA:-}, ${mod_name:-}, ${mod_developers:-}, ${mod_company:-}, ${mod_client:-}, ${mod_copyright:-}, ${mod_license:-}"

        sgnd_dt_append \
            "$MOD_ATTRIBUTION_SCHEMA" \
            MOD_ATTRIBUTION \
            "${mod_name:-}" \
            "${mod_developers:-}" \
            "${mod_company:-}" \
            "${mod_client:-}" \
            "${mod_copyright:-}" \
            "${mod_license:-}"

        doc_emitline=0

    }

    _emit_contentline() {
        [[ -z "$doc_contenttype" ]] && return 0
        (( ! doc_emitline )) && return 0

        ((doc_linenr++))
        saydebug "Emitting line: $mod_name, $src_linenr, $doc_linenr, $doc_section, $doc_parentsection, $doc_grandparentsection, $doc_commentsection, $doc_item, $doc_itemtitle, $doc_contenttype, $doc_content"
        
        sgnd_dt_append \
            "$DOC_RENDERED_SCHEMA" \
            DOC_RENDERED \
            "$mod_name" \
            "$src_linenr" \
            "$doc_linenr" \
            "$doc_section" \
            "$doc_parentsection" \
            "$doc_grandparentsection" \
            "$doc_commentsection" \
            "$doc_item" \
            "$doc_itemtitle" \
            "$doc_contenttype" \
            "$doc_content"

        saydebug "Rendered content emitted: $doc_contenttype, $doc_item, $doc_content"
        doc_emitline=0
    }

# - Internal API ----------------------------------------------------------------
    # fn:_parse_module_file
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

            sayprogress \
                --slot 1 \
                --current "$src_linenr" \
                --total "$total_lines" \
                --label "Parsing $(basename "$src_file")" \
                --type 5

            src_haltlineprocessing=0
            
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

            saydebug "Pre headerfield detection, commentsetcion $doc_commentsection, InHeader? $doc_inheader, $doc_linenr, $src_line"
            _detect_headerfields

            _detect_section
            _get_section_comments

            _detect_items
            
            _detect_commentsectionheader

            _detect_default
            
            _emit_contentline

        done < "$src_file"
        
        return 0
    }   

    _render_site(){
        local output_folder="${1:-}"
        [[ -z "$output_folder" ]] && {
            sayerror "No outputfolder was passed"
            return 1
        }
        sayinfo "Rendering site to $output_folder"
        return 0
    } 


