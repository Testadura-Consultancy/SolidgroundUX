#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX Metadata Editor
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 26079
#   Source      : metadata-editor.sh
#   Type        : script
#   Purpose     : Read and write metadata in script header comments
#
# Description:
#   Interactive and automatic editor for structured script header metadata.
#
#   Supports:
#     - reading Metadata and Attribution sections from script headers
#     - prompting for updated values interactively
#     - limiting prompts to selected fields
#     - reusing entered values across multiple files (--idem)
#     - applying direct non-interactive updates (--auto)
#
# Design principles:
#   - Header comments are treated as structured data
#   - Interactive mode stages values before applying changes
#   - Automatic mode updates only explicitly requested fields
#   - Batch processing should report mismatches and continue
#
# Role in framework:
#   - Maintenance tool for script and library header metadata
#   - Consumer of td-comment-parser and td-datatable helpers
#
# Non-goals:
#   - Editing arbitrary comments outside canonical script headers
#   - Creating missing metadata fields or sections
#   - General-purpose text editing
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        :
#   Copyright     : © 2025 Mark Fieten — Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail

# --- Bootstrap --------------------------------------------------------------------
    # __framework_locator
        # Purpose:
        #   Locate, create, and load the SolidGroundUX bootstrap configuration.
        #
        # Behavior:
        #   - Resolves configuration from user or system location.
        #   - Creates configuration interactively or with defaults when missing.
        #   - Ensures TD_FRAMEWORK_ROOT and TD_APPLICATION_ROOT are set.
        #   - Sources the selected configuration file.
        #
        # Outputs (globals):
        #   TD_FRAMEWORK_ROOT
        #   TD_APPLICATION_ROOT
        #
        # Returns:
        #   0   success
        #   126 configuration unreadable or invalid
        #   127 configuration could not be created
        #
        # Usage:
        #   __framework_locator || exit $?
        #
        # Examples:
        #   __framework_locator
        #
        # Notes:
        #   - Prefers user config over system config.
        #   - Under sudo, resolves config relative to SUDO_USER.
    __framework_locator (){
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/testadura/solidgroundux.cfg"
        local cfg_sys="/etc/testadura/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply

        # Determine existing configuration
        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"

        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"

        else
            # Determine creation location
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            # Interactive prompts (first run only)
            if [[ -t 0 && -t 1 ]]; then

                sayinfo "SolidGroundUX bootstrap configuration"
                sayinfo "No configuration file found."
                sayinfo "Creating: $cfg"

                printf "TD_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "TD_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            # Validate paths (must be absolute)
            case "$fw_root" in
                /*) ;;
                *) sayfail "ERR: TD_FRAMEWORK_ROOT must be an absolute path"; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) sayfail "ERR: TD_APPLICATION_ROOT must be an absolute path"; return 126 ;;
            esac

            # Create configuration file
            mkdir -p "$(dirname "$cfg")" || return 127

            # write cfg file 
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'TD_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'TD_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            saydebug "Created bootstrap cfg: $cfg"
        fi

        # Load configuration
        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"

            : "${TD_FRAMEWORK_ROOT:=/}"
            : "${TD_APPLICATION_ROOT:=$TD_FRAMEWORK_ROOT}"
        else
            sayfail "Cannot read bootstrap cfg: $cfg"
            return 126
        fi

        saydebug "Bootstrap cfg loaded: $cfg, TD_FRAMEWORK_ROOT=$TD_FRAMEWORK_ROOT, TD_APPLICATION_ROOT=$TD_APPLICATION_ROOT"

    }

    # __load_bootstrapper
        # Purpose:
        #   Resolve and source the framework bootstrap library.
        #
        # Behavior:
        #   - Calls __framework_locator to establish framework roots.
        #   - Resolves td-bootstrap.sh path based on TD_FRAMEWORK_ROOT.
        #   - Verifies readability and sources the bootstrap library.
        #
        # Inputs (globals):
        #   TD_FRAMEWORK_ROOT
        #
        # Returns:
        #   0   success
        #   126 bootstrap library unreadable
        #
        # Usage:
        #   __load_bootstrapper || exit $?
        #
        # Examples:
        #   __load_bootstrapper
        #
        # Notes:
        #   - Must be called before any framework-dependent logic.
    __load_bootstrapper(){
        local bootstrap=""

        __framework_locator || return $?

        if [[ "$TD_FRAMEWORK_ROOT" == "/" ]]; then
            bootstrap="/usr/local/lib/testadura/common/td-bootstrap.sh"
        else
            bootstrap="${TD_FRAMEWORK_ROOT%/}/usr/local/lib/testadura/common/td-bootstrap.sh"
        fi

        [[ -r "$bootstrap" ]] || {
            printf "FATAL: Cannot read bootstrap: %s\n" "$bootstrap" >&2
            return 126
        }
        
        saydebug "Loading $bootstrap"
            
        # shellcheck source=/dev/null
        source "$bootstrap"
    }

    # Minimal colors
    MSG_CLR_INFO=$'\e[38;5;250m'
    MSG_CLR_STRT=$'\e[38;5;82m'
    MSG_CLR_OK=$'\e[38;5;82m'
    MSG_CLR_WARN=$'\e[1;38;5;208m'
    MSG_CLR_FAIL=$'\e[38;5;196m'
    MSG_CLR_CNCL=$'\e[0;33m'
    MSG_CLR_END=$'\e[38;5;82m'
    MSG_CLR_EMPTY=$'\e[2;38;5;250m'
    MSG_CLR_DEBUG=$'\e[1;35m'

    TUI_COMMIT=$'\e[2;37m'
    RESET=$'\e[0m'

    # Minimal UI
    saystart()   { printf '%sSTART%s\t%s\n' "${MSG_CLR_STRT-}" "${RESET-}" "$*" >&2; }
    sayinfo()    { 
        if (( ${FLAG_VERBOSE:-0} )); then
            printf '%sINFO%s \t%s\n' "${MSG_CLR_INFO-}" "${RESET-}" "$*" >&2; 
        fi
    }
    sayok()      { printf '%sOK%s   \t%s\n' "${MSG_CLR_OK-}"   "${RESET-}" "$*" >&2; }
    saywarning() { printf '%sWARN%s \t%s\n' "${MSG_CLR_WARN-}" "${RESET-}" "$*" >&2; }
    sayfail()    { printf '%sFAIL%s \t%s\n' "${MSG_CLR_FAIL-}" "${RESET-}" "$*" >&2; }
    saydebug() {
        if (( ${FLAG_DEBUG:-0} )); then
            printf '%sDEBUG%s \t%s\n' "${MSG_CLR_DEBUG-}" "${RESET-}" "$*" >&2;
        fi
    }
    saycancel() { printf '%sCANCEL%s\t%s\n' "${MSG_CLR_CNCL-}" "${RESET-}" "$*" >&2; }
    sayend() { printf '%sEND%s   \t%s\n' "${MSG_CLR_END-}" "${RESET-}" "$*" >&2; }

# --- Script metadata (identity) ---------------------------------------------------
    TD_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    TD_SCRIPT_DIR="$(cd -- "$(dirname -- "$TD_SCRIPT_FILE")" && pwd)"
    TD_SCRIPT_BASE="$(basename -- "$TD_SCRIPT_FILE")"
    TD_SCRIPT_NAME="${TD_SCRIPT_BASE%.sh}"
    TD_SCRIPT_TITLE="Metadata editor"
    TD_SCRIPT_DESC="Reads and writes fields in script comments"

# --- Script metadata (framework integration) --------------------------------------
    # TD_USING
        # Libraries to source from TD_COMMON_LIB.
        # These are loaded automatically by td_bootstrap AFTER core libraries.
        #
        # Example:
        #   TD_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    TD_USING=(
            td-comment-parser.sh
            td-datatable.sh
    )

    # TD_ARGS_SPEC 
        # Optional: script-specific arguments
        # --- Example: Arguments
        # Each entry:
        #   "name|short|type|var|help|choices"
        #
        #   name    = long option name WITHOUT leading --
        #   short   - short option name WITHOUT leading -
        #   type    = flag | value | enum
        #   var     = shell variable that will be set
        #   help    = help string for auto-generated --help output
        #   choices = for enum: comma-separated values (e.g. fast,slow,auto)
        #             for flag/value: leave empty
        #
        # Notes:
        #   - -h / --help is built in, you don't need to define it here.
        #   - After parsing you can use: FLAG_VERBOSE, VAL_CONFIG, ENUM_MODE, ...
    TD_ARGS_SPEC=(
        "file|f|value|VAL_FILE|Exact filename or glob mask to process|"
        "section|s|enum|VAL_SECTION|Header section to update|Metadata,Attribution"
        "field||value|VAL_FIELD|Field name to update|"
        "value||value|VAL_VALUE|New value to write|"
        "auto|a|flag|FLAG_AUTO|Run non-interactively and update immediately|"
        "promptfor||value|VAL_PROMPTFOR|Comma-separated list of field names to prompt for|"
        "idem||flag|FLAG_IDEM|In multi-file mode, ask each selected field only once and reuse the answers|"
    )

    # TD_SCRIPT_EXAMPLES
        # Optional: examples for --help output.
        # Each entry is a string that will be printed verbatim.
        #
        # Example:
        #   TD_SCRIPT_EXAMPLES=(
        #       "Example usage:"
        #       "  script.sh --verbose --mode fast"
        #       "  script.sh -v -m slow"
        #   )
        #
        # Leave empty if no examples are needed.
    TD_SCRIPT_EXAMPLES=(
        "Interactive on one file:"
        "  metadata-editor.sh --file ./my-script.sh"
        ""
        "Interactive on selected fields only:"
        "  metadata-editor.sh --file './*.sh' --promptfor Version,Build"
        ""
        "Interactive on selected fields, ask once for all files:"
        "  metadata-editor.sh --file './*.sh' --promptfor Version,Build --idem"
        ""
        "Auto update one field in one file:"
        "  metadata-editor.sh --auto --file ./my-script.sh --section Metadata --field Version --value 2.1"
    )

    # TD_SCRIPT_GLOBALS
        # Explicit declaration of global variables intentionally used by this script.
        #
        # Purpose:
        #   - Declares which globals are part of the script’s public/config contract.
        #   - Enables optional configuration loading when non-empty.
        #
        # Behavior:
        #   - If this array is non-empty, td_bootstrap enables config integration.
        #   - Variables listed here may be populated from configuration files.
        #   - Unlisted globals will NOT be auto-populated.
        #
        # Use this to:
        #   - Document intentional globals
        #   - Prevent accidental namespace leakage
        #   - Make configuration behavior explicit and predictable
        #
        # Only list:
        #   - Variables that must be globally accessible
        #   - Variables that may be defined in config files
        #
        # Leave empty if:
        #   - The script does not use configuration-driven globals
    TD_SCRIPT_GLOBALS=(
    )

    # TD_STATE_VARIABLES
        # List of variables participating in persistent state.
        #
        # Purpose:
        #   - Declares which variables should be saved/restored when state is enabled.
        #
        # Behavior:
        #   - Only used when td_bootstrap is invoked with --state.
        #   - Variables listed here are serialized on exit (if TD_STATE_SAVE=1).
        #   - On startup, previously saved values are restored before main logic runs.
        #
        # Contract:
        #   - Variables must be simple scalars (no arrays/associatives unless explicitly supported).
        #   - Script remains fully functional when state is disabled.
        #
        # Leave empty if:
        #   - The script does not use persistent state.
    TD_STATE_VARIABLES=(
    )

    # TD_ON_EXIT_HANDLERS
        # List of functions to be invoked on script termination.
        #
        # Purpose:
        #   - Allows scripts to register cleanup or finalization hooks.
        #
        # Behavior:
        #   - Functions listed here are executed during framework exit handling.
        #   - Execution order follows array order.
        #   - Handlers run regardless of normal exit or controlled termination.
        #
        # Contract:
        #   - Functions must exist before exit occurs.
        #   - Handlers must not call exit directly.
        #   - Handlers should be idempotent (safe if executed once).
        #
        # Typical uses:
        #   - Cleanup temporary files
        #   - Persist additional state
        #   - Release locks
        #
        # Leave empty if:
        #   - No custom exit behavior is required.
    TD_ON_EXIT_HANDLERS=(
    )
    
    # State persistence is opt-in.
        # Scripts that want persistent state must:
        #   1) set TD_STATE_SAVE=1
        #   2) call td_bootstrap --state
    TD_STATE_SAVE=0

# --- Local script Declarations ----------------------------------------------------
    # Put script-local constants and defaults here (NOT framework config).
    # Prefer local variables inside functions unless a value must be shared.
    META_SCHEMA="section|field|value"
    declare -a META_ROWS=()

    declare -a TARGET_FILES=()
    current_script=""
# --- Local UI --------------------------------------------------------------------
    # __print_section_labeledvalues
        # Purpose:
        #   Print all rows from a datatable that belong to one section.
        #
        # Behavior:
        #   - Iterates through all rows in the supplied table.
        #   - Selects rows whose section column matches the requested section.
        #   - Prints each matching field/value pair as a labeled value.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_NAME
        #   $3  SECTION
        #
        # Returns:
        #   0  success
        #   1  row lookup failure
    __print_section_labeledvalues() {
            local schema="${1:?missing schema}"
            local table_name="${2:?missing table name}"
            local wanted_section="${3:?missing section}"

            local row_count=0
            local i=0
            local section=""
            local field=""
            local value=""
            
            row_count="$(td_dt_row_count "$table_name")" || return 1
            
            td_print
            td_print_sectionheader "$wanted_section" --border "${LN_H}" --padleft 2
            for (( i=0; i<row_count; i++ )); do
                section="$(td_dt_get "$schema" "$table_name" "$i" "section")" || return 1
                [[ "$section" == "$wanted_section" ]] || continue

                field="$(td_dt_get "$schema" "$table_name" "$i" "field")" || return 1
                value="$(td_dt_get "$schema" "$table_name" "$i" "value")" || return 1

                td_print_labeledvalue "$field" "$value" --pad 3
            done
    }

    # __show_current_metadata
        # Purpose:
        #   Display the currently loaded metadata grouped by section.
        #
        # Behavior:
        #   - Prints a titled overview of the loaded metadata.
        #   - Displays the Metadata section.
        #   - Displays the Attribution section.
        #
        # Inputs (globals):
        #   META_SCHEMA
        #   META_ROWS
        #
        # Returns:
        #   0  success
    __show_current_metadata(){
        td_print
        td_print_sectionheader "Current data" --border "${LN_H}" --padleft 0

        __print_section_labeledvalues "$META_SCHEMA" META_ROWS "Metadata"
        __print_section_labeledvalues "$META_SCHEMA" META_ROWS "Attribution"

        td_print
        td_print_sectionheader --border "${LN_H}" --padleft 0
    }
    
    # __show_pending_value_buffer
        # Purpose:
        #   Display the staged values that are pending application.
        #
        # Behavior:
        #   - Iterates through META_ROWS in order.
        #   - Groups rows by section.
        #   - Prints the staged value from the supplied buffer for each field.
        #
        # Arguments:
        #   $1  BUFFER_ARRAY_NAME
        #
        # Inputs (globals):
        #   META_SCHEMA
        #   META_ROWS
        #
        # Returns:
        #   0  success
        #   1  datatable lookup failure
    __show_pending_value_buffer() {
        local -n in_buffer="$1"
        local i=0
        local section=""
        local field=""
        local new_value=""
        local prev_section=""

        td_print
        td_print_sectionheader "Summary" --border "${LN_H}" --padleft 2
        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            new_value="${in_buffer[$i]-}"
            
            if [[ "$section" != "$prev_section" ]]; then
                td_print
                td_print_sectionheader "$section" --border "${LN_H}" --padend 0 --padleft 2
                prev_section="$section"
            fi
            td_print_labeledvalue "$field" "$new_value" --pad 3
        done
        td_print_sectionheader --border "${LN_H}"
    }
# --- Local script functions -------------------------------------------------------
    # __field_is_selected
        # Purpose:
        #   Determine whether a field should be prompted in interactive mode.
        #
        # Behavior:
        #   - If VAL_PROMPTFOR is empty, all fields are selected.
        #   - Otherwise, matches FIELD against the comma-separated prompt list.
        #
        # Arguments:
        #   $1  FIELD
        #
        # Returns:
        #   0  field selected
        #   1  field not selected
    __field_is_selected() {
        local wanted="${1:?missing field}"
        local item=""
        local list="${VAL_PROMPTFOR:-}"

        [[ -n "$list" ]] || return 0

        IFS=',' read -r -a __me_promptfor <<< "$list"

        for item in "${__me_promptfor[@]}"; do
            item="${item#"${item%%[![:space:]]*}"}"
            item="${item%"${item##*[![:space:]]}"}"

            [[ "$item" == "$wanted" ]] && return 0
        done

        return 1
    }

    # __resolve_target_files
        # Purpose:
        #   Resolve a file path or glob mask into the TARGET_FILES array.
        #
        # Behavior:
        #   - Expands the supplied mask using shell globbing.
        #   - Keeps only readable regular files.
        #   - Stores resolved absolute paths in TARGET_FILES.
        #
        # Arguments:
        #   $1  FILE_OR_MASK
        #
        # Outputs (globals):
        #   TARGET_FILES
        #
        # Returns:
        #   0  one or more readable files resolved
        #   1  no matching readable files    
    __resolve_target_files() {
        local mask="${1:-}"
        local matches=()
        local file=""

        TARGET_FILES=()

        [[ -n "$mask" ]] || {
            sayfail "No file or mask provided. Use --file <path|glob>"
            return 1
        }

        shopt -s nullglob

        # Expand mask safely
        matches=( $mask )

        shopt -u nullglob

        if (( ${#matches[@]} == 0 )); then
            sayfail "No files matched: $mask"
            return 1
        fi

        for file in "${matches[@]}"; do
            [[ -f "$file" ]] || continue
            [[ -r "$file" ]] || {
                saywarning "Skipping unreadable file: $file"
                continue
            }
            TARGET_FILES+=( "$(readlink -f "$file")" )
        done

        if (( ${#TARGET_FILES[@]} == 0 )); then
            sayfail "No readable files matched: $mask"
            return 1
        fi

        return 0
    }

    # __get_metadata
        # Purpose:
        #   Load editable header metadata from the current script into META_ROWS.
        #
        # Behavior:
        #   - Clears META_ROWS.
        #   - Loads the Metadata section.
        #   - Loads the Attribution section.
        #
        # Inputs (globals):
        #   current_script
        #
        # Outputs (globals):
        #   META_ROWS
        #
        # Returns:
        #   0  success
        #   1  section load failure
    __get_metadata() {
        META_ROWS=()

        td_header_load_section_to_dt "$current_script" "Metadata" "$META_SCHEMA" META_ROWS || return 1
        td_header_load_section_to_dt "$current_script" "Attribution" "$META_SCHEMA" META_ROWS || return 1
    }

    # __validate_auto_args
        # Purpose:
        #   Validate that all required arguments for automatic mode are present.
        #
        # Behavior:
        #   - Returns immediately when FLAG_AUTO is not enabled.
        #   - Verifies that file, section, field, and value arguments are available.
        #   - Reports missing required arguments.
        #
        # Inputs (globals):
        #   FLAG_AUTO
        #   VAL_FILE
        #   VAL_SECTION
        #   VAL_FIELD
        #   VAL_VALUE
        #
        # Returns:
        #   0  arguments valid
        #   1  one or more required arguments missing
    __validate_auto_args() {
        (( ${FLAG_AUTO:-0} )) || return 0

        [[ -n "${VAL_FILE:-}" ]] || {
            sayfail "--auto requires --file"
            return 1
        }

        [[ -n "${VAL_SECTION:-}" ]] || {
            sayfail "--auto requires --section"
            return 1
        }

        [[ -n "${VAL_FIELD:-}" ]] || {
            sayfail "--auto requires --field"
            return 1
        }

        [[ -v VAL_VALUE ]] || {
            sayfail "--auto requires --value"
            return 1
        }

        return 0
    }

    # __auto_update_files
        # Purpose:
        #   Apply a single field update to all resolved target files.
        #
        # Behavior:
        #   - Resolves target files from VAL_FILE.
        #   - Updates the requested section/field in each file.
        #   - Reports per-file success or failure.
        #   - Continues processing after individual file failures.
        #
        # Inputs (globals):
        #   VAL_FILE
        #   VAL_SECTION
        #   VAL_FIELD
        #   VAL_VALUE
        #
        # Outputs (globals):
        #   TARGET_FILES
        #
        # Returns:
        #   0  all updates applied successfully
        #   1  one or more updates failed
    __auto_update_files() {
        local file=""
        local rc=0
        local changed=0
        local failed=0

        __resolve_target_files "${VAL_FILE:-}" || return 1

        for file in "${TARGET_FILES[@]}"; do
            if td_header_set_field "$file" "$VAL_SECTION" "$VAL_FIELD" "$VAL_VALUE"; then
                sayok "Updated [$VAL_SECTION] $VAL_FIELD in $file"
                (( changed++ ))
            else
                rc=$?
                case "$rc" in
                    2)
                        saywarning "Header mismatch: [$VAL_SECTION] $VAL_FIELD not found in $file"
                        ;;
                    *)
                        sayfail "Failed to update [$VAL_SECTION] $VAL_FIELD in $file"
                        ;;
                esac
                (( failed++ ))
            fi
        done

        sayinfo "Summary: $changed updated, $failed failed"

        (( failed == 0 ))
    }

# --- User input -------------------------------------------------------------------
    # __build_value_buffer_from_meta
        # Purpose:
        #   Build a staged value buffer from the current META_ROWS table.
        #
        # Behavior:
        #   - Reads the value column from each row in META_ROWS.
        #   - Writes the values into the target array in row order.
        #
        # Arguments:
        #   $1  OUTPUT_ARRAY_NAME
        #
        # Returns:
        #   0  success
        #   1  datatable lookup failure
    __build_value_buffer_from_meta() {
        local -n out_buffer="$1"
        local i=0
        local value=""

        out_buffer=()

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            value="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            out_buffer+=( "$value" )
        done
    }

    # __prompt_value_buffer
        # Purpose:
        #   Prompt the user for updated values using the staged value buffer.
        #
        # Behavior:
        #   - Iterates through META_ROWS in order.
        #   - Prompts only selected fields.
        #   - Uses the current buffer value as the default.
        #   - Updates the buffer in place.
        #
        # Arguments:
        #   $1  BUFFER_ARRAY_NAME
        #   $2  PROMPT_MODE (optional; default: normal)
        #
        # Returns:
        #   0  success
        #   1  datatable lookup failure
    __prompt_value_buffer() {
        local -n io_buffer="$1"
        local prompt_mode="${2:-normal}"
        local i=0
        local section=""
        local field=""
        local current_value=""
        local new_value=""
        local lw=15

        td_print "Enter new values for the selected fields"
        td_print
        local prev_section=""
        local new_section=1
        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            if [[ "$section" != "$prev_section" ]]; then
                prev_section="$section"
                new_section=1
            fi
            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            current_value="${io_buffer[$i]-}"

            __field_is_selected "$field" || continue

            if [[ "$prompt_mode" == "idem" ]]; then
                continue
            fi

            if [[ "$new_section" == 1 ]]; then
                td_print_sectionheader "$section" --border "${LN_H}" --padend 0 --padleft 2
                new_section=0
            fi

            ask --label "    $field" --var new_value --default "$current_value" --labelwidth "$lw" 
            io_buffer[$i]="$new_value"
        done
        td_print
        td_print_sectionheader --border "${LN_H}"
    }

    # __apply_value_buffer_to_file
        # Purpose:
        #   Apply the staged value buffer to the current script header.
        #
        # Behavior:
        #   - Iterates through META_ROWS.
        #   - Updates each corresponding field in current_script.
        #   - Reports mismatches and write failures.
        #
        # Arguments:
        #   $1  BUFFER_ARRAY_NAME
        #
        # Inputs (globals):
        #   current_script
        #
        # Returns:
        #   0  all updates applied
        #   1  one or more updates failed
    __apply_value_buffer_to_file() {
        local -n in_buffer="$1"
        local i=0
        local section=""
        local field=""
        local value=""
        local rc=0
        local failed=0

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            value="${in_buffer[$i]-}"

            if td_header_set_field "$current_script" "$section" "$field" "$value"; then
                :
            else
                rc=$?
                case "$rc" in
                    2) saywarning "Header mismatch: [$section] $field not found in $current_script" ;;
                    *) sayfail "Failed to update [$section] $field in $current_script" ;;
                esac
                (( failed++ ))
            fi
        done

        (( failed == 0 ))
    }
# --- Main -------------------------------------------------------------------------

    # __interactive_edit_current_file
        # Purpose:
        #   Edit the metadata of the current script interactively using a local value buffer.
        #
        # Behavior:
        #   - Loads metadata from current_script into META_ROWS.
        #   - Builds a staged value buffer from the current metadata.
        #   - Prompts the user for updated values.
        #   - Repeats the prompt loop until confirmed or cancelled.
        #
        # Inputs (globals):
        #   current_script
        #
        # Returns:
        #   0  confirmed
        #   1  cancelled or failed
    __interactive_edit_current_file() {
        local action=""
        local -a value_buffer=()

        __get_metadata
        __build_value_buffer_from_meta value_buffer

        while true; do
            sayinfo "Editing: $current_script"
            __show_current_metadata
            echo

            __prompt_value_buffer value_buffer

            echo
            sayinfo "Pending changes:"
            __show_pending_value_buffer value_buffer
            echo

            ask_ok_redo_quit "Apply changes to $current_script?" 15
            case $? in
                0) break ;;
                1) continue ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac
        done
    }

    # __interactive_edit_current_file_with_buffer
        # Purpose:
        #   Edit the metadata of the current script interactively using a supplied value buffer.
        #
        # Behavior:
        #   - Displays the current metadata.
        #   - Prompts for updated values unless prompt_mode indicates reuse.
        #   - Displays a summary of staged values.
        #   - Repeats until confirmed or cancelled.
        #
        # Arguments:
        #   $1  BUFFER_ARRAY_NAME
        #   $2  PROMPT_MODE (optional; default: normal)
        #
        # Inputs (globals):
        #   current_script
        #
        # Returns:
        #   0  confirmed
        #   1  cancelled or failed
    __interactive_edit_current_file_with_buffer() {
        local -n io_buffer="$1"
        local prompt_mode="${2:-normal}"
        local action=""

        while true; do
            clear
            sayinfo "Editing: $current_script"
            __show_current_metadata
            echo

            if [[ "$prompt_mode" == "idem_reuse" ]]; then
                sayinfo "Reusing previous answers (--idem)"
            else
                __prompt_value_buffer "$1" normal || return 1
            fi

            echo
            sayinfo "Pending changes:"
            __show_pending_value_buffer "$1"
            echo

            ask_ok_redo_quit "Apply changes to $current_script?" 15
            case $? in
                0) break ;;
                1) continue ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac
        done
    }

    # __interactive_edit_files
        # Purpose:
        #   Process all resolved target files in interactive mode.
        #
        # Behavior:
        #   - Loads metadata for each file.
        #   - Builds or reuses the staged value buffer.
        #   - Reuses previous answers when --idem is active.
        #   - Stops on user cancellation or unrecoverable failure.
        #
        # Inputs (globals):
        #   TARGET_FILES
        #   FLAG_IDEM
        #
        # Returns:
        #   0  success
        #   1  failure
        #   2  user cancelled
    __interactive_edit_files() {
        local file=""
        local rc=0
        local -a value_buffer=()
        local first_file=1
        local prompt_mode="normal"

        for file in "${TARGET_FILES[@]}"; do
            current_script="$file"
            __get_metadata || return 1

            if (( first_file )); then
                __build_value_buffer_from_meta value_buffer || return 1
                prompt_mode="normal"
                first_file=0
            else
                if (( ${FLAG_IDEM:-0} )); then
                    prompt_mode="idem_reuse"
                else
                    prompt_mode="normal"
                fi
            fi

            __interactive_edit_current_file_with_buffer value_buffer "$prompt_mode"
            rc=$?

            case "$rc" in
                0) ;;
                2) return 2 ;;
                *) return 1 ;;
            esac
        done

        return 0
    }

    # main
        # Purpose:
        #   Entry point for the metadata editor script.
        #
        # Behavior:
        #   - Loads and initializes the SolidGroundUX framework.
        #   - Processes built-in framework arguments.
        #   - Prepares UI state (runmode and title bar).
        #   - Validates script-specific arguments.
        #   - Executes either:
        #       * automatic batch updates (--auto), or
        #       * interactive editing across one or more files.
        #
        # Arguments:
        #   $@  Command-line arguments (framework + script-specific).
        #
        # Returns:
        #   Exits with the resulting status code from bootstrap or script logic.
        #
        # Notes:
        #   - Interactive mode requires --file.
        #   - --idem is ignored in --auto mode.
    main() {
        # -- Bootstrap
            local rc=0

            __load_bootstrapper || exit $?            

            # Recognized switches:
            #     --state      -> enable saving state variables 
            #     --autostate  -> enable state support and auto-save TD_STATE_VARIABLES on exit
            #     --needroot   -> restart script if not root
            #     --cannotroot -> exit script if root
            #     --log        -> enable file logging
            #     --console    -> enable console logging
            # Example:
            #   td_bootstrap --state --needroot -- "$@"
            td_bootstrap -- "$@"
            rc=$?

            saydebug "After bootstrap: $rc"
            (( rc != 0 )) && exit "$rc"
                        
        # -- Handle builtin arguments
            saydebug "Calling builtinarg handler"
            td_builtinarg_handler
            saydebug "Exited builtinarg handler"

        # -- UI
            td_update_runmode
            td_print_titlebar

        # -- Main script logic

        __validate_auto_args || exit 2

        if (( ${FLAG_AUTO:-0} )) && (( ${FLAG_IDEM:-0} )); then
            saywarning "--idem is ignored in --auto mode"
        fi

        if (( ${FLAG_AUTO:-0} )); then
            __auto_update_files || exit $?
            exit 0
        fi

        [[ -n "${VAL_FILE:-}" ]] || {
            sayfail "Interactive mode currently requires --file <script>"
            exit 2
        }

        __resolve_target_files "${VAL_FILE}" || exit $?
        __interactive_edit_files || exit $?

    }

    # Entrypoint: td_bootstrap will split framework args from script args.
    main "$@"