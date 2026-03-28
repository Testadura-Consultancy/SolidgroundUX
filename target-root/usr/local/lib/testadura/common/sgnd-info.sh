# =====================================================================================
# SolidgroundUX - Framework Information
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    :
#   Source      : sgnd-info.sh
#   Type        : library
#   Purpose     : Provide framework metadata and runtime information helpers
#
# Description:
#   Exposes information about the SolidgroundUX framework and runtime environment.
#
#   The library:
#     - Provides access to framework identity (name, version, paths)
#     - Exposes resolved bootstrap values such as SGND_FRAMEWORK_ROOT and SGND_APPLICATION_ROOT
#     - Supplies helper functions for displaying framework and environment details
#     - Supports diagnostics, logging, and informational output
#
# Design principles:
#   - Keep information access centralized and consistent
#   - Avoid duplication of framework identity data across modules
#   - Ensure values reflect the active runtime environment
#   - Keep implementation lightweight and dependency-free where possible
#
# Role in framework:
#   - Provides introspection capabilities for scripts and tools
#   - Supports diagnostics, debugging, and informational commands
#   - Complements bootstrap and configuration modules
#
# Non-goals:
#   - Configuration management (handled by cfg.sh)
#   - Argument parsing or user interaction
#   - Persistent state tracking
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      :
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail

# --- Library guard ------------------------------------------------------------------
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

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# --- Internal helpers ----------------------------------------------------------------
    : "${_section_indent:=2}"
    : "${_items_indent:=4}"

    # _sgnd_print_arg_spec_entry
        # Purpose:
        #   Render a single SGND_ARGS_SPEC or SGND_BUILTIN_ARGS entry as a labeled value line.
        #
        # Arguments:
        #   $1  Spec entry string in format:
        #       name|short|type|varname|help|choices
        #
        # Inputs (globals):
        #   _items_indent
        #
        # Outputs:
        #   Prints one formatted line via sgnd_print_labeledvalue.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_print_arg_spec_entry "debug|d|flag|FLAG_DEBUG|Enable debug mode|"
    _sgnd_print_arg_spec_entry() {
        local entry="${1-}"
        local name=""
        local short=""
        local type=""
        local varname=""
        local help=""
        local choices=""
        local label=""
        local value=""

        IFS='|' read -r name short type varname help choices <<< "$entry"

        if [[ -n "$short" ]]; then
            label="--$name (-$short)"
        else
            label="--$name"
        fi

        if [[ -n "$varname" ]]; then
            value="${varname} = ${!varname-<unset>}"
        else
            value="<no var>"
        fi

        sgnd_print_labeledvalue "$label" "$value" --pad "$_items_indent"
    }

    # _sgnd_print_arg_spec_list
        # Purpose:
        #   Print all argument spec entries from a named array, with a section header.
        #
        # Arguments:
        #   $1  Header text.
        #   $2  Array variable name containing spec entries.
        #
        # Inputs (globals):
        #   _section_indent
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_print_arg_spec_list "Script arguments" "SGND_ARGS_SPEC"
        #
        # Notes:
        #   - Requires bash 4.3+ (nameref).
    _sgnd_print_arg_spec_list() {
        local header="${1:?missing header}"
        local array_name="${2:?missing array name}"
        local entry=""
        local printed_header=0

        declare -p "$array_name" >/dev/null 2>&1 || return 0

        local -n specs_ref="$array_name"
        (( ${#specs_ref[@]} > 0 )) || return 0

        for entry in "${specs_ref[@]}"; do
            if (( ! printed_header )); then
                sgnd_print_sectionheader --text "$header" --padleft "$_section_indent"
                printed_header=1
            fi
            _sgnd_print_arg_spec_entry "$entry"
        done
    }

    # _sgnd_print_cfg_pass
        # Purpose:
        #   Print configuration values for selected scopes from a named spec array.
        #
        # Arguments:
        #   $1  Header text.
        #   $2  Spec array name.
        #   $@  Accepted scopes after the first two arguments.
        #
        # Inputs (globals):
        #   _section_indent
        #   _items_indent
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_print_cfg_pass "System globals" SGND_FRAMEWORK_GLOBALS system both
        #
        # Notes:
        #   - Requires bash 4.3+ (nameref).
    _sgnd_print_cfg_pass() {
        local header_text="${1:?missing header text}"
        local array_name="${2:?missing array name}"
        shift 2

        local -n source_array="$array_name"
        local -a accept_scopes=( "$@" )
        local item=""
        local scope=""
        local name=""
        local desc=""
        local default=""
        local value=""
        local ok=0
        local s=""

        sgnd_print_sectionheader --text "$header_text" --padleft "$_section_indent"

        for item in "${source_array[@]}"; do
            IFS='|' read -r scope name desc default <<< "$item"

            ok=0
            for s in "${accept_scopes[@]}"; do
                if [[ "$scope" == "$s" ]]; then
                    ok=1
                    break
                fi
            done
            (( ok )) || continue

            value="${!name:-$default}"
            sgnd_print_labeledvalue "$name" "$value" --pad "$_items_indent"
        done
    }

# --- Public API ----------------------------------------------------------------------
    # sgnd_print_cfg
        # Purpose:
        #   Print configuration variables described by a spec array.
        #
        # Arguments:
        #   $1  Spec array name containing entries:
        #       scope|VARNAME|description|default_or_extra
        #   $2  Filter scope selector: system | user | both
        #
        # Inputs (globals):
        #   _section_indent
        #   _items_indent
        #
        # Outputs:
        #   Prints formatted configuration values.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_cfg SGND_SCRIPT_GLOBALS both
        #   sgnd_print_cfg SGND_FRAMEWORK_GLOBALS system
        #
        # Notes:
        #   - Requires bash 4.3+ (nameref).
    sgnd_print_cfg() {
        local array_name="${1:?missing spec array name}"
        local filter="${2:-both}"

        case "$filter" in
            system|user|both) ;;
            *) return 1 ;;
        esac

        if [[ "$filter" == "system" || "$filter" == "both" ]]; then
            _sgnd_print_cfg_pass "System globals" "$array_name" system both
            sgnd_print
        fi

        if [[ "$filter" == "user" || "$filter" == "both" ]]; then
            _sgnd_print_cfg_pass "User globals" "$array_name" user both
            sgnd_print
        fi
    }

    # sgnd_print_framework_metadata
        # Purpose:
        #   Print framework identity and versioning metadata.
        #
        # Inputs (globals):
        #   SGND_PRODUCT
        #   SGND_VERSION
        #   SGND_VERSION_DATE
        #   SGND_COMPANY
        #   SGND_COPYRIGHT
        #   SGND_LICENSE
        #
        # Outputs:
        #   Prints formatted metadata values.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_framework_metadata
    sgnd_print_framework_metadata() {
        sgnd_print_sectionheader --text "Framework metadata" --padleft "$_section_indent"
        sgnd_print_labeledvalue "Product"      "$SGND_PRODUCT" --pad "$_items_indent"
        sgnd_print_labeledvalue "Version"      "$SGND_VERSION" --pad "$_items_indent"
        sgnd_print_labeledvalue "Release date" "$SGND_VERSION_DATE" --pad "$_items_indent"
        sgnd_print_labeledvalue "Company"      "$SGND_COMPANY" --pad "$_items_indent"
        sgnd_print_labeledvalue "Copyright"    "$SGND_COPYRIGHT" --pad "$_items_indent"
        sgnd_print_labeledvalue "License"      "$SGND_LICENSE" --pad "$_items_indent"
        sgnd_print
    }

    # sgnd_print_metadata
        # Purpose:
        #   Print script identity and build metadata.
        #
        # Inputs (globals):
        #   SGND_SCRIPT_FILE
        #   SGND_SCRIPT_DESC
        #   SGND_SCRIPT_DIR
        #   SGND_SCRIPT_VERSION
        #   SGND_SCRIPT_BUILD
        #
        # Outputs:
        #   Prints formatted metadata values.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_metadata
    sgnd_print_metadata() {
        sgnd_print_sectionheader --text "Script metadata" --padleft "$_section_indent"
        sgnd_print_labeledvalue "File"               "$SGND_SCRIPT_FILE" --pad "$_items_indent"
        sgnd_print_labeledvalue "Script description" "$SGND_SCRIPT_DESC" --pad "$_items_indent"
        sgnd_print_labeledvalue "Script dir"         "$SGND_SCRIPT_DIR" --pad "$_items_indent"
        sgnd_print_labeledvalue "Script version"     "$SGND_SCRIPT_VERSION (build $SGND_SCRIPT_BUILD)" --pad "$_items_indent"
        sgnd_print
    }

    # sgnd_print_args
        # Purpose:
        #   Print a formatted overview of parsed arguments and their current values.
        #
        # Inputs (globals):
        #   SGND_ARGS_SPEC
        #   SGND_BUILTIN_ARGS
        #   SGND_POSITIONAL
        #
        # Outputs:
        #   Prints formatted argument overview.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_args
    sgnd_print_args() {
        sgnd_print
        _sgnd_print_arg_spec_list "Script arguments" "SGND_ARGS_SPEC"

        sgnd_print
        _sgnd_print_arg_spec_list "Framework arguments" "SGND_BUILTIN_ARGS"

        if declare -p SGND_POSITIONAL >/dev/null 2>&1 && (( ${#SGND_POSITIONAL[@]} > 0 )); then
            sgnd_print
            sgnd_print_sectionheader --text "Positional arguments"

            local i=0
            for i in "${!SGND_POSITIONAL[@]}"; do
                sgnd_print_labeledvalue "Arg[$i]" "${SGND_POSITIONAL[$i]}"
            done
        fi

        sgnd_print
    }

    # sgnd_print_state
        # Purpose:
        #   Print the current persistent state key/value pairs.
        #
        # Inputs:
        #   sgnd_state_list_keys output (key|value)
        #
        # Outputs:
        #   Prints formatted state variables.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_state
    sgnd_print_state() {
        sgnd_state_list_keys | {
            local printed_header=0
            local key=""
            local value=""

            while IFS='|' read -r key value; do
                if (( ! printed_header )); then
                    sgnd_print_sectionheader --text "State variables" --padleft "$_section_indent"
                    printed_header=1
                fi
                sgnd_print_labeledvalue "$key" "$value" --pad "$_items_indent"
            done

            sgnd_print
        }
    }

    # sgnd_print_license
        # Purpose:
        #   Print the framework license text, including acceptance status.
        #
        # Inputs (globals):
        #   SGND_DOCS_DIR
        #   SGND_LICENSE_FILE
        #   SGND_LICENSE_ACCEPTED
        #   TUI_INVALID
        #   TUI_VALID
        #   RESET
        #
        # Outputs:
        #   Prints formatted license text when the file is readable.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_license
    sgnd_print_license() {
        local license_file="$SGND_DOCS_DIR/$SGND_LICENSE_FILE"
        local status_text="${TUI_INVALID}NOT ACCEPTED${RESET}"

        if (( SGND_LICENSE_ACCEPTED )); then
            status_text="${TUI_VALID}[ACCEPTED]${RESET}"
        fi

        saydebug "sgnd_print_license: license status is: $status_text"
        saydebug "sgnd_print_license: looking for license file at: $license_file"

        if [[ -r "$license_file" ]]; then
            saydebug "sgnd_print_license: found license file, printing"
            sgnd_print
            sgnd_print_sectionheader --text "$SGND_PRODUCT license $status_text" --padleft "$_section_indent"
            sgnd_print
            sgnd_print_file "$license_file"
            sgnd_print
            sgnd_print_sectionheader --border "-"
        else
            saydebug "sgnd_print_license: license file not found or not readable: $license_file"
        fi
    }

    # sgnd_print_readme
        # Purpose:
        #   Print the framework README file if present.
        #
        # Inputs (globals):
        #   SGND_DOCS_DIR
        #
        # Outputs:
        #   Prints README contents.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_readme
    sgnd_print_readme() {
        local readme_file="$SGND_DOCS_DIR/README.md"

        if [[ -r "$readme_file" ]]; then
            sgnd_print_file "$readme_file"
        fi
    }

    # sgnd_showenvironment
        # Purpose:
        #   Print a full diagnostic snapshot of the current script/framework context.
        #
        # Inputs (globals expected):
        #   Metadata, arguments, configuration specs, and state variables.
        #
        # Outputs:
        #   Prints complete environment overview.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_showenvironment
        #
        # Examples:
        #   if (( FLAG_DEBUG )); then
        #       sgnd_showenvironment
        #   fi
        #
        # Notes:
        #   - Name retained for backward compatibility.
    sgnd_showenvironment() {
        sgnd_print_titlebar
        sgnd_print

        sgnd_print_metadata

        sgnd_print_sectionheader --text "Command line arguments"
        sgnd_print_args

        sgnd_print_state

        sgnd_print_sectionheader --text "Script configuration ($SGND_SCRIPT_NAME.cfg)"
        sgnd_print_cfg SGND_SCRIPT_GLOBALS both

        sgnd_print_sectionheader --border "-" --text "Framework configuration ($SGND_FRAMEWORK_CFG_BASENAME)"
        sgnd_print_framework_metadata
        sgnd_print_cfg SGND_FRAMEWORK_GLOBALS both

        sgnd_print_sectionheader --border "="
    }
