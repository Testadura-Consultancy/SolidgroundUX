# =====================================================================================
# SolidgroundUX - Framework Information
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608203
#   Checksum    : 03f59c4cec14617b06e7430af98ad6ffdd07f737588f11fcac0bcc27c8fe0df4
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
    : "${__section_indent:=2}"
    : "${__items_indent:=4}"
    
    # __sgnd_print_arg_spec_entry
        # Purpose:
        #   Render a single SGND_ARGS_SPEC / SGND_BUILTIN_ARGS entry as a labeled value line.
        #
        # Arguments:
        #   $1  Spec entry string in format:
        #         name|short|type|varname|help|choices
        #
        # Inputs (globals):
        #   __items_indent  : indentation used for sgnd_print_labeledvalue
        #
        # Behavior:
        #   - Builds an option label:
        #       --name (-s)  when short is present
        #       --name       otherwise
        #   - Resolves current value via indirect expansion of varname:
        #       varname = ${!varname-<unset>}
        #
        # Outputs:
        #   Prints one formatted line via sgnd_print_labeledvalue.
        #
        # Returns:
        #   0 always (display helper).
        #
        # Usage:
        #   __sgnd_print_arg_spec_entry "debug|d|flag|FLAG_DEBUG|Enable debug mode|"
        #
        # Notes:
        #   - Display helper only; does not parse arguments.
    __sgnd_print_arg_spec_entry() {
        local entry="$1"

        local name short type varname help choices
        local label value

        IFS='|' read -r name short type varname help choices <<<"$entry"

        if [[ -n "${short:-}" ]]; then
            label="--$name (-$short)"
        else
            label="--$name"
        fi

        if [[ -n "${varname:-}" ]]; then
            value="${varname} = ${!varname-<unset>}"
        else
            value="<no var>"
        fi

        sgnd_print_labeledvalue "$label" "$value" --pad "$__items_indent"
    }

    # __sgnd_print_arg_spec_list
        # Purpose:
        #   Print all argument spec entries from a named array, with a section header.
        #
        # Arguments:
        #   $1  Header text (e.g. "Script arguments").
        #   $2  Array variable name containing spec entries (e.g. "SGND_ARGS_SPEC").
        #
        # Inputs (globals):
        #   __section_indent : indentation for section header
        #   __items_indent   : indentation for entries
        #
        # Behavior:
        #   - If the named array is undefined or empty: prints nothing.
        #   - Otherwise prints a section header once, then one line per entry.
        #
        # Outputs:
        #   Prints formatted section and entries.
        #
        # Returns:
        #   0 always (display helper).
        #
        # Usage:
        #   __sgnd_print_arg_spec_list "Script arguments" "SGND_ARGS_SPEC"
        #
        # Notes:
        #   - Requires bash 4.3+ (nameref).
    __sgnd_print_arg_spec_list() {
        local header="$1"
        local array_name="$2"

        declare -p "$array_name" >/dev/null 2>&1 || return 0

        local -n specs_ref="$array_name"
        (( ${#specs_ref[@]} > 0 )) || return 0

        local entry
        local _printed_header=0
        for entry in "${specs_ref[@]}"; do
            if (( !_printed_header )); then
                sgnd_print_sectionheader --text "$header" --padleft "$__section_indent"
                _printed_header=1
            fi
            __sgnd_print_arg_spec_entry "$entry"
        done
    }

# --- Public API ----------------------------------------------------------------------
    # sgnd_print_cfg
        # Purpose:
        #   Print configuration variables described by a spec array.
        #
        # Arguments:
        #   $1  Spec array name (nameref) containing entries:
        #         scope|VARNAME|description|default_or_extra
        #   $2  Filter scope selector: system | user | both (default: both)
        #
        # Inputs (globals):
        #   __section_indent, __items_indent
        #
        # Behavior:
        #   - Prints system and/or user globals depending on filter.
        #   - Resolves values via ${!name:-default}.
        #
        # Outputs:
        #   Prints formatted configuration values.
        #
        # Returns:
        #   0 always (display helper).
        #
        # Usage:
        #   sgnd_print_cfg SGND_SCRIPT_GLOBALS both
        #   sgnd_print_cfg SGND_FRAMEWORK_GLOBALS system
        #
        # Notes:
        #   - Requires bash 4.3+ (nameref).
    sgnd_print_cfg(){
        local -n source_array="$1"
        local filter="${2:-both}"

        
        __print_cfg_pass() {
            local header_text="$1"
            shift
            local -a accept_scopes=( "$@" )

            sgnd_print_sectionheader --text "$header_text" --padleft "$__section_indent"

            local item scope name desc default
            for item in "${source_array[@]}"; do
                IFS='|' read -r scope name desc default <<<"$item"

                local ok=0
                local s
                for s in "${accept_scopes[@]}"; do
                    if [[ "$scope" == "$s" ]]; then
                        ok=1
                        break
                    fi
                done
                (( ok )) || continue

                local value="${!name:-$default}"
                sgnd_print_labeledvalue "$name" "$value" --pad "$__items_indent"
            done
        }

        if ( [[ "$filter" == "system" ]] || [[ "$filter" == "both" ]] ); then
              __print_cfg_pass "System globals" system both
              sgnd_print
        fi
        
        if ( [[ "$filter" == "user" ]] || [[ "$filter" == "both" ]] ); then
            __print_cfg_pass "User globals" user both
            sgnd_print
        fi
    }

    # sgnd_print_framework_metadata
        # Purpose:
        #   Print framework identity and versioning metadata.
        #
        # Inputs (globals):
        #   SGND_PRODUCT, SGND_VERSION, SGND_VERSION_DATE,
        #   SGND_COMPANY, SGND_COPYRIGHT, SGND_LICENSE
        #
        # Behavior:
        #   - Prints a "Framework metadata" section.
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
        sgnd_print_sectionheader --text "Framework metadata" --padleft "$__section_indent"
        sgnd_print_labeledvalue "Product"      "$SGND_PRODUCT" --pad "$__items_indent"
        sgnd_print_labeledvalue "Version"      "$SGND_VERSION" --pad "$__items_indent"
        sgnd_print_labeledvalue "Release date" "$SGND_VERSION_DATE" --pad "$__items_indent"
        sgnd_print_labeledvalue "Company"      "$SGND_COMPANY" --pad "$__items_indent"
        sgnd_print_labeledvalue "Copyright"    "$SGND_COPYRIGHT" --pad "$__items_indent"
        sgnd_print_labeledvalue "License"      "$SGND_LICENSE" --pad "$__items_indent"
        sgnd_print
    }

    # sgnd_print_metadata
        # Purpose:
        #   Print script identity and build metadata.
        #
        # Inputs (globals):
        #   SGND_SCRIPT_FILE, SGND_SCRIPT_DESC, SGND_SCRIPT_DIR,
        #   SGND_SCRIPT_VERSION, SGND_SCRIPT_BUILD
        #
        # Outputs:
        #   Prints formatted metadata values.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_print_metadata
    sgnd_print_metadata(){
        sgnd_print_sectionheader --text "Script metadata" --padleft "$__section_indent"
        sgnd_print_labeledvalue "File"               "$SGND_SCRIPT_FILE" --pad "$__items_indent"
        sgnd_print_labeledvalue "Script description" "$SGND_SCRIPT_DESC" --pad "$__items_indent"
        sgnd_print_labeledvalue "Script dir"         "$SGND_SCRIPT_DIR" --pad "$__items_indent"
        sgnd_print_labeledvalue "Script version"     "$SGND_SCRIPT_VERSION (build $SGND_SCRIPT_BUILD)" --pad "$__items_indent"
        sgnd_print
    }   

    # sgnd_print_args
        # Purpose:
        #   Print a formatted overview of parsed arguments and their current values.
        #
        # Inputs (globals):
        #   SGND_ARGS_SPEC, SGND_BUILTIN_ARGS, SGND_POSITIONAL
        #
        # Behavior:
        #   - Prints script args, framework args, and positional args.
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

        # Script args first
        sgnd_print
        __sgnd_print_arg_spec_list "Script arguments" "SGND_ARGS_SPEC"

        # Builtins last
        sgnd_print
        __sgnd_print_arg_spec_list "Framework arguments" "SGND_BUILTIN_ARGS" 

        # Positional
        if declare -p SGND_POSITIONAL >/dev/null 2>&1 && (( ${#SGND_POSITIONAL[@]} > 0 )); then
            sgnd_print
            sgnd_print_sectionheader --text "Positional arguments" 

            local i
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
    sgnd_print_state(){
        
        sgnd_state_list_keys | {
            local _printed_header=0
            while IFS='|' read -r key value; do
                if (( !_printed_header )); then
                    sgnd_print_sectionheader --text "State variables" --padleft "$__section_indent"
                    _printed_header=1
                fi
                sgnd_print_labeledvalue "$key" "$value" --pad "$__items_indent"
            done
            sgnd_print
        }
    }

    # sgnd_print_license
        # Purpose:
        #   Print the framework license text, including acceptance status.
        #
        # Inputs (globals):
        #   SGND_DOCS_DIR, SGND_LICENSE_FILE, SGND_LICENSE_ACCEPTED
        #
        # Behavior:
        #   - Prints license file if readable.
        #   - Shows acceptance status.
        #
        # Outputs:
        #   Prints formatted license text.
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
            sgnd_print_sectionheader --text "$SGND_PRODUCT license $status_text" --padleft "$__section_indent"
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
        # Behavior:
        #   - Prints metadata, arguments, state, and configuration in structured order.
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
        # Example:
        #   if (( FLAG_DEBUG )); then
        #       sgnd_showenvironment
        #   fi
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

        return 0
    }

    
    
