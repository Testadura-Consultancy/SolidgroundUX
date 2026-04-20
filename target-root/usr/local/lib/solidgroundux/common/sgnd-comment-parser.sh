# =====================================================================================
# SolidgroundUX - Comment Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    :
#   Source      : sgnd-comment-parser.sh
#   Type        : library
#   Group       : Developer tools
#   Purpose     : Parse structured inline documentation comments in SolidgroundUX source files
#
# Description:
#   Provides the structural parsing layer for source-level documentation comments
#   used by SolidgroundUX documentation tooling.
#
#   The library:
#     - Detects canonical documentation block markers such as fn, var, doc, and tmp
#     - Tracks source section hierarchy across nested section markers
#     - Detects header parsing boundaries relevant to documentation collection
#     - Parses structured comment-section headings within active documentation blocks
#     - Maintains parser state for line-by-line module scanning workflows
#
# Design principles:
#   - Source documentation is treated as structured data rather than free-form text
#   - Parsing is stateful, predictable, and line-oriented
#   - Structural detection is separated from later storage and rendering stages
#   - Parser behavior remains convention-based and explicit
#
# Role in framework:
#   - Core source-comment parser for documentation generation workflows
#   - Supports doc-generator and other source-analysis tooling
#   - Bridges raw source scanning and normalized documentation data collection
#
# Non-goals:
#   - Updating header metadata fields in source files
#   - Rendering documentation output formats
#   - Acting as a general-purpose text parsing library
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      :
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================

set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
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

# - Local definitions for comment parsing ------------------------------------------
    # Regex patterns
        RGX_HEADER_MARKER='^\#[[:space:]]*=+[[:space:]]*$'
        RGX_HDR_START='^[[:space:]]*#[[:space:]]*Description:[[:space:]]*$'
        RGX_HDR_END='^[[:space:]]*#[[:space:]]*Attribution:[[:space:]]*$'
        RGX_COMMENT_FIELD='^\#[[:space:]]*([A-Za-z]+)[[:space:]]*:[[:space:]]*(.*)$'
        RGX_SECTION_MARKER='^[[:space:]]*# (---|--|-) (.*[^[:space:]-])[[:space:]-]*$'
        RGX_BLOCK_MARKER='^[[:space:]]*#[[:space:]]*(fn|var|doc|tmp):[[:space:]](.*)$'
        RGX_COMMENT_SECTION='^[[:space:]]*#[[:space:]]*([A-Za-z][A-Za-z[:space:]-]*):[[:space:]]*$'

    # Datamodel
        SGND_HEADER_FIELDS=(
            version
            build
            checksum
            type
            group
            purpose
            developers
            company
            client
            copyright
            license
        )

        MODULE_TABLE_SCHEMA="file|product|title|type|group|purpose|version|build|checksum|developers|company|client|copyright|license"
        MODULE_TABLE=()

        DOC_SECTIONS_SCHEMA="file|section|section_level|parent|grandparent|source_linenr"
        DOC_SECTIONS=()

        DOC_ITEMS_SCHEMA="file|source_linenr|access|type|section|name"
        DOC_ITEMS=()

        DOC_CONTENT_SCHEMA="file|source_linenr|section|item_name|content_ord|content_type|content"
        DOC_CONTENT=()

    # Tracking variables
        _parsing_header=0
        _header_started=0
        _header_banner_parsed=0
        _parsing_block=0
        _parsing_block_type=""
        _parsing_block_name=""

        _line_nr=0
        _line_parse_index=0

        _parsed_filename=""
        _parsed_product=""
        _parsed_title=""
        _current_section="maindoc"
        _current_parentsection=""
        _current_grandparentsection=""
        _current_section_level=0
        _current_comment_section=""
        _current_comment_paragraph=0
        _content_ord=0
        _content_type=""

# - Local helpers ------------------------------------------------------------------
    # _get_comment_fieldvalue
        # Returns:
        #   0 if the requested field was parsed from LINE.
        #   1 otherwise.
    _get_comment_fieldvalue() {
        local line="$1"
        local field="$2"
        local prefix="$3"
        local found_field=""
        local value=""
        local var_name=""

        [[ "$line" =~ $RGX_COMMENT_FIELD ]] || return 1

        found_field="${BASH_REMATCH[1],,}"
        value="${BASH_REMATCH[2]}"
        field="${field,,}"

        [[ "$found_field" == "$field" ]] || return 1

        var_name="${prefix}_${field}"
        printf -v "$var_name" '%s' "$value"
        return 0
    }

    # _normalize_comment_content
        # Purpose:
        #   Remove indentation and the leading comment marker from one stored content line.
    _normalize_comment_content() {
        local text="$1"

        text="${text#"${text%%[![:space:]]*}"}"
        if [[ "$text" == \#* ]]; then
            text="${text#\#}"
            [[ "$text" == " "* ]] && text="${text# }"
        fi

        printf '%s' "$text"
    }

    # _reset_parser_state
        # Purpose:
        #   Reset parser state for a new file.
    _reset_parser_state() {
        _line_nr=0
        _line_parse_index=0

        _parsing_header=0
        _header_started=0
        _header_banner_parsed=0
        _parsing_block=0
        _parsing_block_type=""
        _parsing_block_name=""

        _parsed_product=""
        _parsed_title=""
        _current_section="header"
        _current_parentsection=""
        _current_grandparentsection=""
        _current_section_level=0
        _current_comment_section=""
        _current_comment_paragraph=0
        _content_ord=0
    }

    # _init_module_metadata
        # Purpose:
        #   Initialize parsed metadata variables for a new source file.
    _init_module_metadata() {
        local field

        for field in "${SGND_HEADER_FIELDS[@]}"; do
            if [[ "$field" == "checksum" ]]; then
                printf -v "module_${field}" '%s' "none"
            else
                printf -v "module_${field}" '%s' ""
            fi
        done
    }

    # _assemble_module_metadata
        # Purpose:
        #   Parse one known metadata field from one header line.
    _assemble_module_metadata() {
        local line="$1"
        local field
        local var_name
        local var_value

        for field in "${SGND_HEADER_FIELDS[@]}"; do
            _get_comment_fieldvalue "$line" "$field" "module" || continue

            var_name="module_${field}"
            var_value="${!var_name-}"
            sayinfo "Parsed metadata: ${field} = ${var_value}"
            return 0
        done

        return 1
    }

    # _emit_module_metadata
        # Purpose:
        #   Emit the collected module metadata as a row in MODULE_TABLE.
    _emit_module_metadata() {
        local metadata_line

        metadata_line="$_parsed_filename|$_parsed_product|$_parsed_title|$module_type|$module_group|$module_purpose|$module_version|$module_build|$module_checksum|$module_developers|$module_company|$module_client|$module_copyright|$module_license"
        MODULE_TABLE+=("$metadata_line")
    }

    # _emit_doc_section
        # Purpose:
        #   Emit the current section row to DOC_SECTIONS.
    _emit_doc_section() {
        local section_line

        section_line="$_parsed_filename|$_current_section|$_current_section_level|$_current_parentsection|$_current_grandparentsection|$_line_nr"
        DOC_SECTIONS+=("$section_line")
    }

    # _emit_doc_item
        # Purpose:
        #   Emit one documentation item row to DOC_ITEMS.
    _emit_doc_item() {
        local access="$1"
        local item_type="$2"
        local item_name="$3"
        local item_line

        item_line="$_parsed_filename|$_line_nr|$access|$item_type|$_current_section|$item_name"
        DOC_ITEMS+=("$item_line")
    }

    # _emit_module_content
        # Purpose:
        #   Emit one content row to DOC_CONTENT.
    _emit_module_content() {
        local raw_content="$1"
        local content=""
        local content_line

        content="$(_normalize_comment_content "$raw_content")"
        (( _content_ord++ ))
        content_line="$_parsed_filename|$_line_nr|$_current_section|$_parsing_block_name|$_content_ord|$_content_type|$content"
        DOC_CONTENT+=("$content_line")
    }

    # _detect_section
        # Purpose:
        #   Detect and register the current source section marker.
    _detect_section() {
        local line="$1"
        local marker=""
        local title=""

        [[ "$line" =~ $RGX_SECTION_MARKER ]] || return 1

        marker="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
        title="${title##[-[:space:]]}"
        title="${title%%[-[:space:]]}"

        case "$marker" in
            -)
                _current_section="$title"
                _current_parentsection="maindoc"
                _current_grandparentsection=""
                _current_section_level=1
                ;;
            --)
                case "${_current_section_level:-0}" in
                    1)
                        _current_grandparentsection="maindoc"
                        _current_parentsection="$_current_section"
                        ;;
                    2)
                        ;;
                    3)
                        _current_parentsection="$_current_grandparentsection"
                        _current_grandparentsection="maindoc"
                        ;;
                    *)
                        _current_grandparentsection=""
                        _current_parentsection="maindoc"
                        ;;
                esac

                _current_section="$title"
                _current_section_level=2
                ;;
            ---)
                [[ "${_current_section_level:-0}" -eq 2 ]] || return 1
                _current_grandparentsection="$_current_parentsection"
                _current_parentsection="$_current_section"
                _current_section="$title"
                _current_section_level=3
                ;;
            *)
                return 1
                ;;
        esac

        _parsing_block=1
        _parsing_block_type="sec"
        _parsing_block_name="$_current_section"
        _emit_doc_section
        return 0
    }

    # _block_start_detector
        # Purpose:
        #   Detect whether a line starts a structured documentation block marker.
    _block_start_detector() {
        local line="$1"
        local block_type_code=""
        local block_name=""

        [[ "$line" =~ $RGX_BLOCK_MARKER ]] || return 1

        block_type_code="${BASH_REMATCH[1]}"
        block_name="${BASH_REMATCH[2]}"
        block_name="${block_name#"${block_name%%[![:space:]]*}"}"
        block_name="${block_name%"${block_name##*[![:space:]]}"}"

        case "$block_type_code" in
            fn|var|doc|tmp) ;;
            *) return 1 ;;
        esac

        _parsing_block=1
        _parsing_block_type="$block_type_code"
        _parsing_block_name="$block_name"
        _current_comment_section=""
        _current_comment_paragraph=0

        _emit_doc_item "public" "$block_type_code" "$block_name"
        _content_type="item_header"
        _emit_module_content "$block_name"
        return 0
    }

    # _block_end_detector
        # Purpose:
        #   Detect whether the current structured documentation block ends on the given line.
    _block_end_detector() {
        local line="$1"
        local name=""

        name="${_parsing_block_name:-}"
        [[ -n "${_parsing_block_type:-}" ]] || return 1

        [[ "$line" =~ ^[[:space:]]*$ ]] && return 0

        case "$_parsing_block_type" in
            fn|tmp)
                [[ "$line" =~ ^[[:space:]]*${name}[[:space:]]*\(\)[[:space:]]*(\{|$) ]] && return 0
                ;;
            var)
                [[ "$line" =~ ^[[:space:]]*${name}[[:space:]]*= ]] && return 0
                ;;
            doc|sec|hdr|header)
                return 1
                ;;
            *)
                return 1
                ;;
        esac

        return 1
    }

    # _handle_header_boundaries
        # Purpose:
        #   Start and end the canonical file header lifecycle.
    _handle_header_boundaries() {
        local line="$1"
        local file="$2"
        local linenr="$3"

        if (( !_header_started )) && [[ "$line" =~ $RGX_HEADER_MARKER ]]; then
            _header_started=1
            _parsing_header=1
            _parsing_block=1
            _parsing_block_type="header"
            _parsing_block_name="header"
            sayinfo "Detected header start at line $linenr in $file"
            return 0
        fi

        if (( _parsing_header && _header_started )) && [[ "$line" =~ $RGX_HEADER_MARKER ]]; then
            _parsing_header=0
            _parsing_block=0
            _parsing_block_type=""
            _parsing_block_name=""
            sayinfo "Detected header end at line $linenr in $file"
            return 0
        fi

        return 1
    }

    # _handle_header_banner
        # Purpose:
        #   Parse the banner line once from within the active header.
    _handle_header_banner() {
        local line="$1"

        (( _parsing_header )) || return 1
        (( _header_banner_parsed )) && return 1
        [[ "$line" =~ $RGX_HEADER_MARKER ]] && return 1

        sgnd_header_parse_banner_line "$line" "_parsed_product" "_parsed_title" || true
        _header_banner_parsed=1
        return 0
    }

    # _handle_header_markers
        # Purpose:
        #   Detect structured sub-block markers inside the canonical file header.
    _handle_header_markers() {
        local line="$1"
        local linenr="$2"

        (( _parsing_header )) || return 1

        if [[ "$line" =~ $RGX_HDR_START ]]; then
            _parsing_block=1
            _parsing_block_type="hdr"
            _parsing_block_name="header"
            sayinfo "Detected hdr block start at line $linenr"
            return 0
        fi

        if [[ "$line" =~ $RGX_HDR_END ]]; then
            _parsing_block=0
            _parsing_block_type=""
            _parsing_block_name=""
            sayinfo "Detected hdr block end at line $linenr"
            return 0
        fi

        return 1
    }

    # _handle_header_content
        # Purpose:
        #   Collect header metadata and header content lines.
    _handle_header_content() {
        local line="$1"

        (( _parsing_header )) || return 1

        _assemble_module_metadata "$line" || true

    [[ "$line" =~ ^[[:space:]]*#[[:space:]]*-+[[:space:]]*$ ]] && return 0
    [[ "$line" =~ ^[[:space:]]*#[[:space:]]*$ ]] && return 0

        _content_type="metadata"
        _emit_module_content "$line"
        return 0
    }

    # _handle_section_marker
        # Purpose:
        #   Detect source section markers outside the file header.
    _handle_section_marker() {
        local line="$1"

        (( _parsing_header )) && return 1
        _detect_section "$line" || return 1

        _content_type="section_header"
        _parsing_block_name=""
        _emit_module_content "$_current_section"
        _parsing_block_name="$_current_section"
        return 0
    }

    # _handle_block_start
        # Purpose:
        #   Detect typed documentation block markers and emit the item start row.
    _handle_block_start() {
        local line="$1"

        (( _parsing_header )) && return 1
        _block_start_detector "$line" || return 1
        return 0
    }

    # _handle_block_end
        # Purpose:
        #   End the current active documentation block when its terminator is encountered.
    _handle_block_end() {
        local line="$1"

        _block_end_detector "$line" || return 1

        _parsing_block=0
        _parsing_block_type=""
        _parsing_block_name=""
        _current_comment_section=""
        _current_comment_paragraph=0
        return 0
    }

    # _handle_comment_subsection
        # Purpose:
        #   Detect structured comment subsection headers inside an active documentation block.
    _handle_comment_subsection() {
        local line="$1"
        local section_name=""

        (( _parsing_block )) || return 1
        [[ "$line" =~ $RGX_COMMENT_SECTION ]] || return 1

        section_name="${BASH_REMATCH[1]}"
        section_name="${section_name#"${section_name%%[![:space:]]*}"}"
        section_name="${section_name%"${section_name##*[![:space:]]}"}"

        _current_comment_section="$section_name"
        _current_comment_paragraph=1
        _content_type="comment_section"
        _emit_module_content "$line"
        return 0
    }

    # _handle_block_content
        # Purpose:
        #   Emit ordinary content lines while a block is active.
    _handle_block_content() {
        local line="$1"

        (( _parsing_block )) || return 1
        [[ "$line" =~ $RGX_SECTION_MARKER ]] && return 1
        [[ "$line" =~ ^[[:space:]]*#[[:space:]]*-+[[:space:]]*$ ]] && return 1

        case "${_parsing_block_type:-}" in
            sec|doc|fn|var|tmp|hdr|header)
                [[ "$line" =~ ^[[:space:]]*# ]] || return 1
                ;;
        esac

        _content_type="content"
        _emit_module_content "$line"
        return 0
    }

# - Public API ---------------------------------------------------------------------
    # sgnd_parse_module_file
        # Purpose:
        #   Parse one source file and initialize parser state for line-by-line processing.
    sgnd_parse_module_file() {
        local file="$1"
        local line=""

        [[ -r "$file" ]] || return 1

        file="${file%/}"
        _parsed_filename="${file##*/}"

        _reset_parser_state
        _init_module_metadata

        saydebug "Parsing source file: $file"

        while IFS= read -r line || [[ -n "$line" ]]; do
            ((_line_nr++))
            sgnd_parse_module_line "$line" "$file" "$_line_nr"
        done < "$file"

        if [[ -n "${module_type:-}${module_group:-}${module_purpose:-}${module_version:-}${module_build:-}${module_checksum:-}${module_developers:-}${module_company:-}${module_client:-}${module_copyright:-}${module_license:-}${_parsed_product:-}${_parsed_title:-}" ]]; then
            _emit_module_metadata
        fi

        return 0
    }

    # sgnd_parse_module_line
        # Purpose:
        #   Process one source line and delegate to small single-purpose handlers.
    sgnd_parse_module_line() {
        local line="$1"
        local file="${2:-}"
        local linenr="${3:-}"

        _line_parse_index=$(( _line_parse_index + 1 ))

        _handle_header_boundaries "$line" "$file" "$linenr" && return 0
        _handle_header_banner "$line" && return 0
        _handle_header_markers "$line" "$linenr" && return 0
        _handle_header_content "$line" && return 0
        _handle_section_marker "$line" && return 0
        _handle_block_start "$line" && return 0
        _handle_block_end "$line" && return 0
        _handle_comment_subsection "$line" && return 0
        _handle_block_content "$line" && return 0

        return 0
    }
