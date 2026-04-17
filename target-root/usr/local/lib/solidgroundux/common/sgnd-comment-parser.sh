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

 
# - Local definitions for comment parsing ------------------------------------------
    # Comment header marker line (e.g. "# ======")
        # =~ regex explanation:
        #   ^           : start of line
        #   \#          : literal #
        #   [[:space:]] : at least one whitespace character
        #   =+          : one or more literal = characters
        #   [[:space:]] : at least one whitespace character
        #   $           : end of line
    RGX_HEADER_MARKER='^\#[[:space:]]*=+[[:space:]]*$'
    
    RGX_HDR_START='^[[:space:]]*#[[:space:]]*Description:[[:space:]]*$'
    RGX_HDR_END='^[[:space:]]*#[[:space:]]*Attribution:[[:space:]]*$'

    # Comment field marker line (e.g. "# Field : Value")
    RGX_COMMENT_FIELD='^\#[[:space:]]*([A-Za-z]+)[[:space:]]*:[[:space:]]*(.*)$'
    # Comment section marker (e.g. "# --- SectionName")
    RGX_SECTION_MARKER='^[[:space:]]*# (---|--|-) (.*[^[:space:]-])[[:space:]-]*$'
    # Typed comment block marker (e.g. "# fn: function_name")
    RGX_BLOCK_MARKER='^[[:space:]]*#[[:space:]]*(fn|var|doc|tmp):[[:space:]](.*)$'

    RGX_COMMENT_SECTION='^[[:space:]]*#[[:space:]]*([A-Za-z][A-Za-z[:space:]-]*):[[:space:]]*$'

    # Current section tracking
    _parsing_header=0
    _parsing_block=0
    _parsing_block_type=""
    _parsing_block_name=""

    _line_nr=0
    _line_parse_index=0
    
    _current_section="maindoc"
    _current_parentsection=""
    _current_grandparentsection=""
    _current_section_level=0 # 0 = maindoc, 1 = first-level section, etc.

# - Local helpers
    # fn: _init_module_metadata
        # Purpose:
        #   Initialize parsed metadata variables for a new source file.
        #
        # Behavior:
        #   - Resets all parsed header field variables listed in SGND_HEADER_FIELDS
        #   - Initializes checksum to "none"
        #   - Initializes all other parsed fields to an empty string
        #
        # Outputs (globals):
        #   _parsed_<field>
        #
        # Returns:
        #   0
        #
        # Usage:
        #   _init_module_metadata
        #
        # Examples:
        #   _init_module_metadata
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

    # fn: _assemble_module_metadata
        # Purpose:
        #   Parse known metadata fields from one header line.
        #
        # Arguments:
        #   $1  LINE
        #
        # Returns:
        #   0
        #
        # Usage:
        #   _assemble_module_metadata "$line"
    _assemble_module_metadata() {
        local line="$1"
        local field
        local var_name
        local var_value

        for field in "${SGND_HEADER_FIELDS[@]}"; do
            sgnd_get_comment_fieldvalue "$line" "$field" "module" || continue

            # Report
            var_name="module_${field}"
            var_value="${!var_name-}"
            sayinfo "Parsed metadata: ${field} = ${var_value}"
            
            return 0
        done

        # If no fields matched, just return without error (not all lines will contain metadata)
        return 1
    }

# - Public API -------------------------------------------------------------------   
    # fn: sgnd_get_comment_fieldvalue
        # Purpose:
        #   Parse a canonical comment field line and assign the value to a prefixed variable.
        #
        # Behavior:
        #   - Matches comment lines of the form: "#   Field : Value"
        #   - Extracts field name and value from the line
        #   - Normalizes the field name to lowercase
        #   - Assigns the value to the corresponding "<prefix><field>" variable
        #   - Ignores lines that do not match the canonical field format
        #
        # Arguments:
        #   $1  LINE
        #   $2  PREFIX
        #
        # Returns:
        #   0 if a field was parsed and assigned.
        #   1 if the line is not a recognized field line.
        #
        # Usage:
        #   sgnd_get_comment_fieldvalue "$line" "_parsed_"
        #
        # Examples:
        #   sgnd_get_comment_fieldvalue "#   Version     : 1.1" "_parsed_"
        #   sgnd_get_comment_fieldvalue "#   Purpose     : Generate documentation" "meta_"
        #
    sgnd_get_comment_fieldvalue() {
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

    # fn: sgnd_get_current_section
        # Purpose:
        #   Detect and register the current section header for one parsed line.
        #
        # Arguments:
        #   $1  LINE
        #
        # Returns:
        #   0 if a section header was detected.
        #   1 otherwise.
        #
        # Usage:
        #   sgnd_get_current_section "$line"
    sgnd_get_current_section() {
        local line="$1"
        local marker=""
        local title=""

        [[ "$line" =~ $RGX_SECTION_MARKER ]] || return 1

        marker="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
        # Normalize title by trimming '-' and spaces from both ends
        title="${title##[-[:space:]]}"
        title="${title%%[-[:space:]]}"

        case "$marker" in
            -)
                # First-level section
                # Start a new top-level branch under maindoc.
                _current_section="$title"
                _current_parentsection="maindoc"
                _current_grandparentsection=""
                _current_section_index="$title"
                _current_section_level=1
                ;;

            --)
                # Second-level section
                case "${_current_section_level:-0}" in
                    1)
                        # Coming from level 1:
                        # current section becomes parent of new level-2 section.
                        _current_grandparentsection="maindoc"
                        _current_parentsection="$_current_section"
                        ;;
                    2)
                        # Staying on level 2:
                        # keep existing parent/grandparent, just replace current section.
                        ;;
                    3)
                        # Coming from level 3:
                        # step one level up, so grandparent becomes parent.
                        _current_parentsection="$_current_grandparentsection"
                        _current_grandparentsection="maindoc"
                        ;;
                    *)
                        # No prior section context:
                        # treat as child of maindoc.
                        _current_grandparentsection=""
                        _current_parentsection="maindoc"
                        ;;
                esac

                _current_section="$title"
                _current_section_level=2
                ;;

            ---)
                # Third-level section
                # Only valid directly under an existing level-2 section.
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
        
        return 0
    }

    # fn: sgnd_parse_module_file
        # Purpose:
        #   Parse one source file and initialize parser state for line-by-line processing.
        #
        # Behavior:
        #   - Normalizes the input file path
        #   - Resets parsed metadata and parser state variables
        #   - Stores the current filename for downstream parsing logic
        #   - Iterates through the file line by line
        #   - Delegates line handling to sgnd_parse_module_line
        #
        # Arguments:
        #   $1  FILE
        #
        # Outputs (globals):
        #   _parsed_filename
        #   _line_nr
        #   _line_parse_index
        #   _parsing_header
        #   _current_section
        #   _current_parentsection
        #
        # Returns:
        #   0 on success.
        #   1 if FILE is unreadable.
        #
        # Usage:
        #   sgnd_parse_module_file "$file"
    sgnd_parse_module_file() {
        local file="$1"
        local line_ttl
        local line=""

        [[ -r "$file" ]] || return 1

        file="${file%/}"
        _parsed_filename="${file##*/}"

        _init_module_metadata

        saydebug "Parsing source file: $file"
        _line_nr=0
        _line_parse_index=0
        _parsing_header=0

        _current_section="header"
        _current_parentsection=""

        line_ttl=$(awk 'END {print NR}' "$file")

        while IFS= read -r line || [[ -n "$line" ]]; do
            ((_line_nr++))
            sgnd_parse_module_line "$line" "$file" "$_line_nr"
        done < "$file"

        return 0
    }

    # fn: _block_start_detector
        # Purpose:
        #   Detect whether a line starts a structured documentation block marker.
        #
        # Behavior:
        #   - Matches block markers of the form:
        #       # fn: <name>
        #       # var: <name>
        #       # doc: <name>
        #       # tmp: <name>
        #   - Allows indentation before the comment marker.
        #   - Allows optional spacing between '#' and the block type.
        #   - Requires exactly one space after ':'.
        #   - Extracts the block type and block name from the marker line.
        #   - Normalizes the extracted block name by trimming surrounding whitespace.
        #
        # Arguments:
        #   $1  LINE
        #
        # Outputs (globals):
        #   _parsing_block_type
        #   _parsing_block_name
        #
        # Returns:
        #   0 if a block marker was detected and parsed.
        #   1 otherwise.
        #
        # Usage:
        #   _block_start_detector "$line"
        #
        # Examples:
        #   _block_start_detector "# fn: my_function"
        #   _block_start_detector "    # var: MY_VALUE"
    _block_start_detector() {
        local line="$1"
        local file="${2:-}"
        local linenr="${3:-}"
        local block_type_code=""
        local block_name=""

        if [[ "$line" =~ $RGX_BLOCK_MARKER ]]; then
            block_type_code="${BASH_REMATCH[1]}"
            block_name="${BASH_REMATCH[2]}"

            case "$block_type_code" in
                fn|var|doc|tmp)
                    _parsing_block_type="$block_type_code"
                    ;;
                *)
                    return 1
                    ;;
            esac

            # trim leading whitespace
            block_name="${block_name#"${block_name%%[![:space:]]*}"}"
            # trim trailing whitespace
            block_name="${block_name%"${block_name##*[![:space:]]}"}"
            _parsing_block_name="$block_name"

            sayinfo "Detected block begin: type=$_parsing_block_type, name=$_parsing_block_name at line $linenr"

            return 0
        fi

        return 1
    }

    # fn: _block_end_detector
        # Purpose:
        #   Detect whether the current structured documentation block ends on the given line.
        #
        # Behavior:
        #   - Ends any active block on a completely empty line.
        #   - Ends fn blocks when the matching function declaration is encountered.
        #   - Ends var blocks when the matching variable assignment is encountered.
        #   - Leaves doc and tmp blocks to end only on an empty line.
        #
        # Arguments:
        #   $1  LINE
        #
        # Inputs (globals):
        #   _parsing_block_type
        #   _parsing_block_name
        #
        # Returns:
        #   0 if the current block ends on this line.
        #   1 otherwise.
        #
        # Usage:
        #   _block_end_detector "$line"
        #
        # Examples:
        #   _block_end_detector "my_function() {"
        #   _block_end_detector "MY_VAR=value"
        #   _block_end_detector ""
    _block_end_detector() {
        local line="$1"
        local name=""

        name="${_parsing_block_name:-}"
        [[ -n "${_parsing_block_type:-}" ]] || return 1

        # -- Any completely empty line ends the current block
        [[ "$line" =~ ^[[:space:]]*$ ]] && return 0

        case "$_parsing_block_type" in
            fn|tmp)
                # Match:
                #   my_function()
                #   my_function () 
                #   my_function() {
                #   my_function () {
                [[ "$line" =~ ^[[:space:]]*${name}[[:space:]]*\(\)[[:space:]]*(\{|$) ]] && {
                    sayinfo "Detected end of block type=$_parsing_block_type, name=$_parsing_block_name at line $linenr"
                    return 0
                }
                ;;

            var)
                # Match:
                #   my_var=
                #   my_var =
                #   my_var=123
                #   my_var ="x"
                [[ "$line" =~ ^[[:space:]]*${name}[[:space:]]*= ]] && {
                    
                    sayinfo "Detected end of block type=$_parsing_block_type, name=$_parsing_block_name at line $linenr"
                    return 0
                }
                ;;

            doc|tmp)
                return 1
                ;;

            *)
                return 1
                ;;
        esac

        return 1
    }

    # fn: sgnd_parse_module_line
        # Purpose:
        #   Process one source line and detect structural markers for documentation parsing.
        #
        # Behavior:
        #   - Detects the start of the canonical module header comment
        #   - Extracts product and title from the banner line
        #   - Detects the end of the canonical module header comment
        #   - Parses metadata fields while header parsing is active
        #   - Leaves section detection to later parser stages
        #
        # Arguments:
        #   $1  LINE
        #   $2  FILE
        #   $3  LINENR
        #
        # Returns:
        #   0
        #
        # Usage:
        #   sgnd_parse_module_line "$line" "$file" "$linenr"
        #
        # Examples:
        #   sgnd_parse_module_line "#   Version     : 1.0" "module.sh" 12
    sgnd_parse_module_line() {
        local line="$1"
        local file="${2:-}"
        local linenr="${3:-}"

        _line_parse_index=$(( _line_parse_index + 1 ))

        # Detect start of module header ----------------------------------------
        if (( !_parsing_header )) && [[ "$line" =~ $RGX_HEADER_MARKER ]]; then
            _parsing_header=1
            _parsing_block_type="header"
            sayinfo "Detected header start at line $linenr in $file"
            return 0
        fi

        # Detect header block start
        if (( _parsing_header )) && [[ "$line" =~ $RGX_HDR_START ]]; then
            _parsing_block=1
            _parsing_block_type="hdr"
            _parsing_block_name="header"
            sayinfo "Detected hdr block start at line $linenr"
            return 0
        fi

        # Detect header block end
        if (( _parsing_header )) && [[ "$line" =~ $RGX_HDR_END ]]; then
            _parsing_block=0
            _parsing_block_type=""
            _parsing_block_name="header"
            sayinfo "Detected hdr block end at line $linenr"
            return 0
        fi

        # Extract product and title from header banner -------------------------
        if (( _parsing_header && _line_parse_index == 2 )); then
            sgnd_header_parse_banner_line "$line" "_parsed_product" "_parsed_title" || {
                saywarning "Failed to parse product and title from header banner in $_parsed_filename: $line"
            }
            sayinfo "Parsed product: $_parsed_product, title: $_parsed_title from header in $_parsed_filename"
            return 0
        fi

        # Detect end of module header ------------------------------------------
        if (( _parsing_header )) && [[ "$line" =~ $RGX_HEADER_MARKER ]]; then
            _parsing_header=0
            _parsing_block_type=""
            sayinfo "Detected header end at line $linenr in $file"
            return 0
        fi

        # Gather module metadata fields while parsing header -------------------
        if (( _parsing_header )); then
            _assemble_module_metadata "$line" && return 0
        fi

        # Detect section start ------------------------------------------------
        sgnd_get_current_section "$line" && 
        {
            sayinfo "Section level $_current_section_level: $_current_section (parent: $_current_parentsection, grandparent: $_current_grandparentsection) at line $linenr"

            _parsing_block=1
            _parsing_block_type="sec"
            _parsing_block_name="$_current_section"
            sayinfo "Detected section start: $_current_section at line $linenr"
            return 0
        }

        # Detect typed block -------------------------------------------------
        _block_start_detector "$line" "$file" "$linenr" && return 0
        
        # Detect block end --------------------------------------------------
        _block_end_detector "$line" && {
            _parsing_block=0
            _parsing_block_type=""
            _parsing_block_name=""

            _current_comment_section=""
            _current_comment_paragraph=0
            return 0
        }   

        # Detect comment section header --------------------------------------
        if (( _parsing_block )) && [[ "$line" =~ $RGX_COMMENT_SECTION ]]; then
            local section_name="${BASH_REMATCH[1]}"

            # Trim whitespace
            section_name="${section_name#"${section_name%%[![:space:]]*}"}"
            section_name="${section_name%"${section_name##*[![:space:]]}"}"

            _current_comment_section="$section_name"
            _current_comment_paragraph=1

            sayinfo "Comment section: $_current_comment_section (line $linenr)"
            return 0
        fi
    }      




