#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Prepare Release
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2602607900
#   Checksum    : 
#   Source      : prepare-release.sh
#   Type        : script
#   Purpose     : Prepare a workspace for release distribution
#
# Description:
#   Provides a utility that prepares a development workspace for release
#   by applying version updates and ensuring metadata consistency.
#
#   The script:
#     - Updates version, build, and checksum metadata in scripts
#     - Processes target files or folders for release readiness
#     - Ensures consistent metadata across all release artifacts
#     - Supports dry-run mode for safe verification
#
# Design principles:
#   - Release preparation is deterministic and repeatable
#   - Metadata consistency is enforced across all scripts
#   - Minimal assumptions about project structure beyond conventions
#   - Supports safe execution through dry-run capability
#
# Role in framework:
#   - Pre-release step for SolidgroundUX workspaces
#   - Ensures scripts are versioned and consistent before distribution
#
# Non-goals:
#   - Packaging or distributing release artifacts
#   - Managing version control or tagging
#   - Performing deployment operations
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail

# --- Bootstrap -----------------------------------------------------------------------
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
        local reply=""

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
            printf '%sINFO%s \t%s\n' "${MSG_CLR_INFO-}" "${RESET-}" "$*" >&2
        fi
    }
    sayok()      { printf '%sOK%s   \t%s\n' "${MSG_CLR_OK-}"   "${RESET-}" "$*" >&2; }
    saywarning() { printf '%sWARN%s \t%s\n' "${MSG_CLR_WARN-}" "${RESET-}" "$*" >&2; }
    sayfail()    { printf '%sFAIL%s \t%s\n' "${MSG_CLR_FAIL-}" "${RESET-}" "$*" >&2; }
    saydebug() {
        if (( ${FLAG_DEBUG:-0} )); then
            printf '%sDEBUG%s \t%s\n' "${MSG_CLR_DEBUG-}" "${RESET-}" "$*" >&2
        fi
    }
    saycancel() { printf '%sCANCEL%s\t%s\n' "${MSG_CLR_CNCL-}" "${RESET-}" "$*" >&2; }
    sayend() { printf '%sEND%s   \t%s\n' "${MSG_CLR_END-}" "${RESET-}" "$*" >&2; }

# --- Script metadata (identity) ------------------------------------------------------
    TD_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    TD_SCRIPT_DIR="$(cd -- "$(dirname -- "$TD_SCRIPT_FILE")" && pwd)"
    TD_SCRIPT_BASE="$(basename -- "$TD_SCRIPT_FILE")"
    TD_SCRIPT_NAME="${TD_SCRIPT_BASE%.sh}"
    TD_SCRIPT_TITLE="Metadata editor"
    TD_SCRIPT_DESC="Reads and writes fields in script comments"

# --- Script metadata (framework integration) -----------------------------------------
    # TD_USING
        # Libraries to source from TD_COMMON_LIB.
        # These are loaded automatically by td_bootstrap AFTER core libraries.
    TD_USING=(
        td-comment-parser.sh
        td-datatable.sh
    )

    # TD_ARGS_SPEC
    TD_ARGS_SPEC=(
        "file|f|value|VAL_FILE|Exact filename or glob mask to process|"
        "folder||value|VAL_FOLDER|Folder whose .sh files should be processed|"
        "section|s|enum|VAL_SECTION|Header section to update|Metadata,Attribution"
        "field||value|VAL_FIELD|Field name to update|"
        "value||value|VAL_VALUE|New value to write|"
        "auto|a|flag|FLAG_AUTO|Run non-interactively and update immediately|"
        "promptfor||value|VAL_PROMPTFOR|Comma-separated list of field names to prompt for|"
        "idem||flag|FLAG_IDEM|In multi-file mode, ask each selected field only once and reuse the answers|"
        "bumpversion||flag|FLAG_BUMPVERSION|Refresh checksum/build metadata for target file(s)|"
        "bumpmajor||flag|FLAG_BUMPMAJOR|Bump major version and refresh checksum/build metadata|"
        "bumpminor||flag|FLAG_BUMPMINOR|Bump minor version and refresh checksum/build metadata|"
    )

    # TD_SCRIPT_EXAMPLES
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
        ""
        "Refresh build/checksum on one file:"
        "  metadata-editor.sh --file ./my-script.sh --bumpversion"
        ""
        "Bump minor version on one file:"
        "  metadata-editor.sh --file ./my-script.sh --bumpminor"
        ""
        "Bump major version on all scripts in a folder:"
        "  metadata-editor.sh --folder ./scripts --bumpmajor"
    )

    # TD_SCRIPT_GLOBALS
    TD_SCRIPT_GLOBALS=(
    )

    # TD_STATE_VARIABLES
    TD_STATE_VARIABLES=(
    )

    # TD_ON_EXIT_HANDLERS
    TD_ON_EXIT_HANDLERS=(
    )

    # State persistence is opt-in.
    TD_STATE_SAVE=0

# --- Local script Declarations -------------------------------------------------------
    META_SCHEMA="section|field|value"
    declare -a META_ROWS=()

    declare -a TARGET_FILES=()
    current_script=""
    BUMP_MODE="none"

# --- Local UI ------------------------------------------------------------------------
    # __print_section_labeledvalues
        # Purpose:
        #   Print all rows from one metadata section as labeled values.
        #
        # Behavior:
        #   - Reads rows from the supplied td-datatable.
        #   - Filters rows by the requested section name.
        #   - Prints each matching field/value pair using td_print_labeledvalue().
        #
        # Arguments:
        #   $1  SCHEMA
        #       Datatable schema string.
        #   $2  TABLE_NAME
        #       Name of the datatable array variable.
        #   $3  WANTED_SECTION
        #       Section name to render (for example: Metadata, Attribution).
        #
        # Returns:
        #   0  success
        #   1  failed to read datatable contents
        #
        # Usage:
        #   __print_section_labeledvalues "$META_SCHEMA" META_ROWS "Metadata"
        #
        # Examples:
        #   __print_section_labeledvalues "$META_SCHEMA" META_ROWS "Attribution"
    __print_section_labeledvalues() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local wanted_section="${3:?missing section}"

        local row_count=0
        local i=0
        local section=""
        local field=""
        local value=""
        local lw=15

        row_count="$(td_dt_row_count "$table_name")" || return 1

        td_print
        td_print_sectionheader "$wanted_section" --border "${LN_H}" --padleft 2
        for (( i=0; i<row_count; i++ )); do
            section="$(td_dt_get "$schema" "$table_name" "$i" "section")" || return 1
            [[ "$section" == "$wanted_section" ]] || continue

            field="$(td_dt_get "$schema" "$table_name" "$i" "field")" || return 1
            value="$(td_dt_get "$schema" "$table_name" "$i" "value")" || return 1

            td_print_labeledvalue "$field" "$value" --pad 3 --labelwidth "$lw"
        done
    }

    # __show_current_metadata
        # Purpose:
        #   Render the currently loaded metadata for the active script.
        #
        # Behavior:
        #   - Prints a titled block for the current header data.
        #   - Renders the Metadata section.
        #   - Renders the Attribution section.
        #
        # Inputs (globals):
        #   META_SCHEMA
        #   META_ROWS
        #
        # Returns:
        #   0  success
        #   1  failed to render section contents
        #
        # Usage:
        #   __show_current_metadata
        #
        # Examples:
        #   __get_metadata || return 1
        #   __show_current_metadata
    __show_current_metadata(){
        local lw=
        td_print
        td_print_sectionheader "Current data" --border "${LN_H}" --padleft 2

        __print_section_labeledvalues "$META_SCHEMA" META_ROWS "Metadata"
        __print_section_labeledvalues "$META_SCHEMA" META_ROWS "Attribution"

        td_print
        td_print_sectionheader --border "${LN_H}" --padleft 0
    }

    # __show_pending_value_buffer
        # Purpose:
        #   Show a summary of changed fields in the pending value buffer.
        #
        # Behavior:
        #   - Compares the supplied buffer against the current values in META_ROWS.
        #   - Prints only fields whose values have changed.
        #   - Groups changed fields by section.
        #   - Does not print the new values, only the changed field names.
        #   - Prints "No changes" when the buffer matches the current metadata.
        #
        # Arguments:
        #   $1  BUFFER_NAME
        #       Name of the pending value buffer array variable.
        #
        # Inputs (globals):
        #   META_SCHEMA
        #   META_ROWS
        #
        # Returns:
        #   0  success
        #   1  failed to read metadata rows
        #
        # Usage:
        #   __show_pending_value_buffer value_buffer
        #
        # Examples:
        #   __show_pending_value_buffer io_buffer
    __show_pending_value_buffer() {
        local -n in_buffer="$1"
        local i=0
        local section=""
        local field=""
        local old_value=""
        local new_value=""
        local prev_section=""
        local any_changes=0

        td_print
        td_print_sectionheader "Summary" --border "${LN_H}" --padleft 2

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            old_value="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            new_value="${in_buffer[$i]-}"

            [[ "$new_value" == "$old_value" ]] && continue

            if [[ "$section" != "$prev_section" ]]; then
                td_print
                td_print_sectionheader "$section" --border "${LN_H}" --padend 0 --padleft 2
                prev_section="$section"
            fi

            td_print_labeledvalue "$field" "" --pad 3 --labelwidth 20
            (( any_changes++ ))
        done

        if (( any_changes == 0 )); then
            td_print
            td_print_labeledvalue "No changes" "" --pad 3
        fi

        td_print_sectionheader --border "${LN_H}"
    }

# --- Local script functions ----------------------------------------------------------
    # __field_is_selected
        # Purpose:
        #   Test whether a field is included in the interactive prompt selection.
        #
        # Behavior:
        #   - When VAL_PROMPTFOR is empty, all fields are considered selected.
        #   - When VAL_PROMPTFOR is set, splits the comma-separated list.
        #   - Trims surrounding whitespace from each list item.
        #   - Matches the requested field name exactly.
        #
        # Arguments:
        #   $1  FIELD
        #       Field name to test.
        #
        # Inputs (globals):
        #   VAL_PROMPTFOR
        #
        # Returns:
        #   0  field is selected
        #   1  field is not selected
        #
        # Usage:
        #   __field_is_selected "Version"
        #
        # Examples:
        #   if __field_is_selected "$field"; then
        #       :
        #   fi
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
        #   Resolve a file path or glob mask into TARGET_FILES.
        #
        # Behavior:
        #   - Expands the supplied mask using shell globbing.
        #   - Keeps only regular readable files.
        #   - Normalizes each accepted file to an absolute path.
        #   - Fails when no readable files match.
        #
        # Arguments:
        #   $1  MASK
        #       Exact file path or glob mask.
        #
        # Outputs (globals):
        #   TARGET_FILES
        #
        # Returns:
        #   0  success
        #   1  no mask supplied or no readable matches found
        #
        # Usage:
        #   __resolve_target_files "./*.sh"
        #
        # Examples:
        #   __resolve_target_files "$VAL_FILE" || return 1
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

    # __resolve_folder_scripts
        # Purpose:
        #   Resolve all readable .sh files in a folder into TARGET_FILES.
        #
        # Behavior:
        #   - Validates that the supplied folder exists.
        #   - Scans the folder for files matching *.sh.
        #   - Keeps only regular readable files.
        #   - Normalizes each accepted file to an absolute path.
        #   - Fails when no readable script files are found.
        #
        # Arguments:
        #   $1  FOLDER
        #       Folder path to scan.
        #
        # Outputs (globals):
        #   TARGET_FILES
        #
        # Returns:
        #   0  success
        #   1  missing folder, invalid folder, or no readable scripts found
        #
        # Usage:
        #   __resolve_folder_scripts "./scripts"
        #
        # Examples:
        #   __resolve_folder_scripts "$VAL_FOLDER" || return 1
    __resolve_folder_scripts() {
        local folder="${1:-}"
        local file=""

        TARGET_FILES=()

        [[ -n "$folder" ]] || {
            sayfail "No folder provided. Use --folder <path>"
            return 1
        }

        [[ -d "$folder" ]] || {
            sayfail "Folder not found: $folder"
            return 1
        }

        shopt -s nullglob
        for file in "$folder"/*.sh; do
            [[ -f "$file" ]] || continue
            [[ -r "$file" ]] || {
                saywarning "Skipping unreadable file: $file"
                continue
            }
            TARGET_FILES+=( "$(readlink -f "$file")" )
        done
        shopt -u nullglob

        if (( ${#TARGET_FILES[@]} == 0 )); then
            sayfail "No readable .sh files found in folder: $folder"
            return 1
        fi

        return 0
    }

    # __resolve_targets
        # Purpose:
        #   Resolve the effective processing targets into TARGET_FILES.
        #
        # Behavior:
        #   - Accepts either --file or --folder input.
        #   - Rejects cases where both are supplied.
        #   - Delegates to __resolve_target_files() or __resolve_folder_scripts().
        #
        # Inputs (globals):
        #   VAL_FILE
        #   VAL_FOLDER
        #
        # Outputs (globals):
        #   TARGET_FILES
        #
        # Returns:
        #   0  success
        #   1  invalid target arguments or target resolution failure
        #
        # Usage:
        #   __resolve_targets || return 1
        #
        # Examples:
        #   __resolve_targets
    __resolve_targets() {
        if [[ -n "${VAL_FILE:-}" && -n "${VAL_FOLDER:-}" ]]; then
            sayfail "Use either --file or --folder, not both"
            return 1
        fi

        if [[ -n "${VAL_FILE:-}" ]]; then
            __resolve_target_files "${VAL_FILE}"
            return $?
        fi

        if [[ -n "${VAL_FOLDER:-}" ]]; then
            __resolve_folder_scripts "${VAL_FOLDER}"
            return $?
        fi

        sayfail "Provide either --file <path|glob> or --folder <path>"
        return 1
    }

    # __get_metadata
        # Purpose:
        #   Load header metadata for the current script into META_ROWS.
        #
        # Behavior:
        #   - Clears the current META_ROWS buffer.
        #   - Loads the Metadata section from the current script header.
        #   - Loads the Attribution section from the current script header.
        #
        # Inputs (globals):
        #   current_script
        #   META_SCHEMA
        #
        # Outputs (globals):
        #   META_ROWS
        #
        # Returns:
        #   0  success
        #   1  failed to load one or more header sections
        #
        # Usage:
        #   __get_metadata || return 1
        #
        # Examples:
        #   current_script="$file"
        #   __get_metadata
    __get_metadata() {
        META_ROWS=()

        td_header_load_section_to_dt "$current_script" "Metadata" "$META_SCHEMA" META_ROWS || return 1
        td_header_load_section_to_dt "$current_script" "Attribution" "$META_SCHEMA" META_ROWS || return 1
    }

    # __resolve_bump_mode
        # Purpose:
        #   Resolve the effective non-interactive version update mode from flags.
        #
        # Behavior:
        #   - Initializes BUMP_MODE to none.
        #   - Maps --bumpversion to none.
        #   - Maps --bumpmajor to major.
        #   - Maps --bumpminor to minor.
        #   - Fails when more than one bump flag is supplied.
        #
        # Inputs (globals):
        #   FLAG_BUMPVERSION
        #   FLAG_BUMPMAJOR
        #   FLAG_BUMPMINOR
        #
        # Outputs (globals):
        #   BUMP_MODE
        #
        # Returns:
        #   0  success
        #   1  conflicting bump flags supplied
        #
        # Usage:
        #   __resolve_bump_mode || exit 2
        #
        # Examples:
        #   __resolve_bump_mode
    __resolve_bump_mode() {
        local bump_count=0

        BUMP_MODE="none"

        if (( ${FLAG_BUMPVERSION:-0} )); then
            BUMP_MODE="none"
            (( bump_count++ ))
        fi

        if (( ${FLAG_BUMPMAJOR:-0} )); then
            BUMP_MODE="major"
            (( bump_count++ ))
        fi

        if (( ${FLAG_BUMPMINOR:-0} )); then
            BUMP_MODE="minor"
            (( bump_count++ ))
        fi

        if (( bump_count > 1 )); then
            sayfail "Use only one of --bumpversion, --bumpmajor, or --bumpminor"
            return 1
        fi

        return 0
    }

    # __validate_auto_args
        # Purpose:
        #   Validate required arguments for automatic field update mode.
        #
        # Behavior:
        #   - Performs no checks when FLAG_AUTO is not set.
        #   - Requires --file or --folder.
        #   - Requires --section.
        #   - Requires --field.
        #   - Requires --value.
        #
        # Inputs (globals):
        #   FLAG_AUTO
        #   VAL_FILE
        #   VAL_FOLDER
        #   VAL_SECTION
        #   VAL_FIELD
        #   VAL_VALUE
        #
        # Returns:
        #   0  success
        #   1  missing required auto-mode arguments
        #
        # Usage:
        #   __validate_auto_args || exit 2
        #
        # Examples:
        #   __validate_auto_args
    __validate_auto_args() {
        (( ${FLAG_AUTO:-0} )) || return 0

        if [[ -z "${VAL_FILE:-}" && -z "${VAL_FOLDER:-}" ]]; then
            sayfail "--auto requires --file or --folder"
            return 1
        fi

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

    # __validate_bump_args
        # Purpose:
        #   Validate required arguments for version metadata update mode.
        #
        # Behavior:
        #   - Performs checks only when one or more bump flags are set.
        #   - Requires exactly one target source: --file or --folder.
        #   - Rejects cases where both are supplied.
        #
        # Inputs (globals):
        #   FLAG_BUMPVERSION
        #   FLAG_BUMPMAJOR
        #   FLAG_BUMPMINOR
        #   VAL_FILE
        #   VAL_FOLDER
        #
        # Returns:
        #   0  success
        #   1  invalid or missing bump-mode target arguments
        #
        # Usage:
        #   __validate_bump_args || exit 2
        #
        # Examples:
        #   __validate_bump_args
    __validate_bump_args() {
        if (( ${FLAG_BUMPVERSION:-0} || ${FLAG_BUMPMAJOR:-0} || ${FLAG_BUMPMINOR:-0} )); then
            if [[ -z "${VAL_FILE:-}" && -z "${VAL_FOLDER:-}" ]]; then
                sayfail "Version bump mode requires --file or --folder"
                return 1
            fi

            if [[ -n "${VAL_FILE:-}" && -n "${VAL_FOLDER:-}" ]]; then
                sayfail "Use either --file or --folder, not both"
                return 1
            fi
        fi

        return 0
    }

    # __auto_update_files
        # Purpose:
        #   Apply one direct field update to all resolved target files.
        #
        # Behavior:
        #   - Resolves target files from --file or --folder.
        #   - Applies td_header_set_field() to each target.
        #   - Continues across failures and reports a summary.
        #
        # Inputs (globals):
        #   VAL_SECTION
        #   VAL_FIELD
        #   VAL_VALUE
        #
        # Returns:
        #   0  all updates succeeded
        #   1  target resolution failed or one or more updates failed
        #
        # Usage:
        #   __auto_update_files || exit $?
        #
        # Examples:
        #   __auto_update_files
    __auto_update_files() {
        local file=""
        local rc=0
        local changed=0
        local failed=0

        __resolve_targets || return 1

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

    # __bump_one_file
        # Purpose:
        #   Apply a version bump to one file, respecting dry-run.
        #
        # Arguments:
        #   $1  FILE
        #   $2  MODE   none | major | minor
        #
        # Returns:
        #   0  success
        #   1  failure
    __bump_one_file() {
        local file="${1:?missing file}"
        local mode="${2:-none}"

        if (( ${FLAG_DRYRUN:-0} )); then
            case "$mode" in
                major) sayinfo "[DRYRUN] Would bump major version in $file" ;;
                minor) sayinfo "[DRYRUN] Would bump minor version in $file" ;;
                none)  sayinfo "[DRYRUN] Would update build/checksum in $file" ;;
            esac
            return 0
        fi

        td_header_bump_version "$file" "$mode"
    }

    # __bump_version_files
        # Purpose:
        #   Apply the resolved version metadata update mode to all target files.
        #
        # Behavior:
        #   - Resolves target files from --file or --folder.
        #   - Applies __bump_one_file() to each target.
        #   - Reports per-file results and a final summary.
        #
        # Inputs (globals):
        #   BUMP_MODE
        #
        # Returns:
        #   0  all targets processed successfully
        #   1  target resolution failed or one or more updates failed
        #
        # Usage:
        #   __bump_version_files || exit $?
        #
        # Examples:
        #   __bump_version_files
    __bump_version_files() {
        local file=""
        local changed=0
        local failed=0

        __resolve_targets || return 1

        for file in "${TARGET_FILES[@]}"; do
            if __bump_one_file "$file" "$BUMP_MODE"; then
                case "$BUMP_MODE" in
                    major) sayok "Bumped major version in $file" ;;
                    minor) sayok "Bumped minor version in $file" ;;
                    none)  sayok "Updated build/checksum in $file" ;;
                esac
                (( changed++ ))
            else
                sayfail "Failed version bump in $file"
                (( failed++ ))
            fi
        done

        sayinfo "Summary: $changed processed, $failed failed"
        (( failed == 0 ))
    }

    # __collect_changed_fields
        # Purpose:
        #   Collect the names of fields whose pending values differ from current metadata.
        #
        # Arguments:
        #   $1  BUFFER_NAME
        #
        # Outputs:
        #   Writes changed field names to stdout, one per line.
    __collect_changed_fields() {
        local -n in_buffer="$1"
        local i=0
        local field=""
        local old_value=""
        local new_value=""

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            old_value="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            new_value="${in_buffer[$i]-}"

            [[ "$new_value" == "$old_value" ]] && continue
            printf '%s\n' "$field"
        done
    }

# --- User input ----------------------------------------------------------------------
    # __build_value_buffer_from_meta
        # Purpose:
        #   Build an editable value buffer from the current metadata rows.
        #
        # Behavior:
        #   - Clears the destination array.
        #   - Copies the value column from META_ROWS into the destination buffer.
        #   - Preserves row order so buffer indexes match metadata row indexes.
        #
        # Arguments:
        #   $1  OUT_BUFFER_NAME
        #       Name of the destination array variable.
        #
        # Inputs (globals):
        #   META_SCHEMA
        #   META_ROWS
        #
        # Outputs (globals):
        #   Writes values into the supplied output buffer by reference.
        #
        # Returns:
        #   0  success
        #   1  failed to read metadata rows
        #
        # Usage:
        #   __build_value_buffer_from_meta value_buffer
        #
        # Examples:
        #   __build_value_buffer_from_meta io_buffer
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
        #   Prompt interactively for editable field values and update the buffer in place.
        #
        # Behavior:
        #   - Iterates through META_ROWS in order.
        #   - Prompts only for fields selected by __field_is_selected().
        #   - Groups prompts by section.
        #   - Uses the current buffer value as the editable default.
        #   - Writes accepted values back into the supplied buffer.
        #   - When prompt_mode is idem, skips prompting entirely.
        #
        # Arguments:
        #   $1  BUFFER_NAME
        #       Name of the editable value buffer array variable.
        #   $2  PROMPT_MODE
        #       Prompt mode token.
        #       Supported values:
        #         normal
        #         idem
        #
        # Inputs (globals):
        #   META_SCHEMA
        #   META_ROWS
        #
        # Outputs (globals):
        #   Updates the supplied buffer by reference.
        #
        # Returns:
        #   0  success
        #   1  failed to read metadata rows
        #
        # Usage:
        #   __prompt_value_buffer value_buffer normal
        #
        # Examples:
        #   __prompt_value_buffer io_buffer idem
    __prompt_value_buffer() {
        local -n buffer_ref="$1"
        local prompt_mode="${2:-normal}"
        local i=0
        local section=""
        local field=""
        local current_value=""
        local new_value=""
        local lw=15
        local prev_section=""
        local new_section=1

        td_print "Enter new values for the selected fields"

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            if [[ "$section" != "$prev_section" ]]; then
                prev_section="$section"
                new_section=1
            fi

            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            current_value="${buffer_ref[$i]-}"

            __field_is_selected "$field" || continue

            if [[ "$prompt_mode" == "idem" ]]; then
                continue
            fi

            if [[ "$new_section" == 1 ]]; then
                td_print
                td_print_sectionheader "$section" --border "${LN_H}" --padend 0 --padleft 2
                new_section=0
            fi

            ask --label "    $field" --var new_value --default "$current_value" --labelwidth "$lw" --labelclr "${CYAN}"
            buffer_ref[$i]="$new_value"
        done

        td_print
        td_print_sectionheader --border "${LN_H}"
    }

    # __ask_apply_first_answers_to_all
        # Purpose:
        #   Ask whether the first file's answers should be reused for all files.
        #
        # Returns:
        #   0  yes
        #   1  no
        #   2  cancel
    __ask_apply_first_answers_to_all() {
        ask_noyes "Apply first file's answers to all?"
        return $?
    }

    # __ask_interactive_action
        # Purpose:
        #   Ask which interactive action to apply to the selected targets.
        #
        # Behavior:
        #   - Displays the interactive action menu.
        #   - Reads the user's choice through td_choose().
        #   - Maps the accepted choice to an action token.
        #
        # Arguments:
        #   $1  OUT_ACTION
        #       Name of the destination variable.
        #
        # Outputs (globals):
        #   Sets the supplied variable (by reference) to:
        #     edit | bump | cancel
        #
        # Returns:
        #   0  success
        #
        # Usage:
        #   __ask_interactive_action action
        #
        # Examples:
        #   local action=""
        #   __ask_interactive_action action
            # Purpose:
            #   Ask whether to edit fields or bump version.
            #
            # Outputs:
            #   Writes selected action token to stdout:
            #     edit | bump | cancel
    __ask_interactive_action() {
        local -n out_action="$1"
        local choice=""

        td_print
        td_print_sectionheader "Action" --border "${LN_H}" --padleft 2
        td_print_labeledvalue --label "1" --value "Edit fields" --pad 3 --labelwidth 3
        td_print_labeledvalue --label "2" --value "Bump version" --pad 3 --labelwidth 3
        td_print_labeledvalue --label "Q" --value "Cancel" --pad 3 --labelwidth 3
        td_print

        td_choose --label "Choose" --choices "1,2,Q" --var choice

        case "${choice^^}" in
            1) out_action="edit" ;;
            2) out_action="bump" ;;
            Q) out_action="cancel" ;;
            *) out_action="cancel" ;;
        esac
    }

    # __ask_bump_mode
        # Purpose:
        #   Ask which version metadata update mode to apply.
        #
        # Behavior:
        #   - Displays the version update menu.
        #   - Supports refresh-only mode and semantic version bump modes.
        #   - Maps the accepted choice to a mode token.
        #
        # Arguments:
        #   $1  OUT_MODE
        #       Name of the destination variable.
        #
        # Outputs (globals):
        #   Sets the supplied variable (by reference) to:
        #     none | major | minor | cancel
        #
        # Returns:
        #   0  success
        #
        # Usage:
        #   __ask_bump_mode mode
        #
        # Examples:
        #   local mode=""
        #   __ask_bump_mode mode
            # Purpose:
            #   Ask which semantic version bump to apply.
            #
            # Outputs:
            #   Writes selected mode token to stdout:
            #     major | minor | cancel
    __ask_bump_mode() {
        local -n out_mode="$1"
        local choice=""

        td_print
        td_print_sectionheader "Version update" --border "${LN_H}" --padleft 2
        td_print_labeledvalue "0" "Refresh build/checksum" --pad 3 --labelwidth 4
        td_print_labeledvalue "1" "Major" --pad 3 --labelwidth 4
        td_print_labeledvalue "2" "Minor" --pad 3 --labelwidth 4
        td_print_labeledvalue "Q" "Cancel" --pad 3 --labelwidth 4
        td_print

        td_choose --label "Choose" --choices "0, 1,2,Q" --var choice

        case "${choice^^}" in
            0) out_mode="none" ;;
            1) out_mode="major" ;;
            2) out_mode="minor" ;;
            Q) out_mode="cancel" ;;
            *) out_mode="cancel" ;;
        esac
    }
    
    # __apply_value_buffer_to_file
        # Purpose:
        #   Apply changed values from the pending buffer to the current script header.
        #
        # Behavior:
        #   - Compares the supplied buffer against the current values in META_ROWS.
        #   - Updates only fields whose values actually changed.
        #   - Respects dry-run mode and reports simulated changes instead of writing.
        #   - Continues across field update failures and reports them individually.
        #   - Reports when there are no metadata changes to apply.
        #
        # Arguments:
        #   $1  BUFFER_NAME
        #       Name of the pending value buffer array variable.
        #
        # Inputs (globals):
        #   current_script
        #   META_SCHEMA
        #   META_ROWS
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0  all changed fields applied successfully (or no changes)
        #   1  one or more field updates failed
        #
        # Usage:
        #   __apply_value_buffer_to_file value_buffer
        #
        # Examples:
        #   __apply_value_buffer_to_file io_buffer
    __apply_value_buffer_to_file() {
        local -n in_buffer="$1"
        local i=0
        local section=""
        local field=""
        local old_value=""
        local new_value=""
        local rc=0
        local failed=0
        local changed=0

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            field="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            old_value="$(td_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            new_value="${in_buffer[$i]-}"

            [[ "$new_value" == "$old_value" ]] && continue

            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "[DRYRUN] Would update [$section] $field in $current_script: '$old_value' -> '$new_value'"
                (( changed++ ))
                continue
            fi

            if td_header_set_field "$current_script" "$section" "$field" "$new_value"; then
                (( changed++ ))
            else
                rc=$?
                case "$rc" in
                    2) saywarning "Header mismatch: [$section] $field not found in $current_script" ;;
                    *) sayfail "Failed to update [$section] $field in $current_script" ;;
                esac
                (( failed++ ))
            fi
        done

        if (( changed == 0 )); then
            sayinfo "No metadata changes to apply."
        fi

        (( failed == 0 ))
    }

# --- Main ----------------------------------------------------------------------------
    # __interactive_bump_files
        # Purpose:
        #   Apply an interactive version metadata update to the first file or all files.
        #
        # Behavior:
        #   - Prompts for the desired update mode.
        #   - Supports refresh-only, major, and minor update modes.
        #   - Applies the selected mode either to the first file only or to all targets.
        #
        # Arguments:
        #   $1  APPLY_ALL
        #       0 = first file only
        #       1 = all target files
        #
        # Inputs (globals):
        #   TARGET_FILES
        #
        # Returns:
        #   0  success
        #   1  failure
        #   2  cancelled
        #
        # Usage:
        #   __interactive_bump_files 0
        #
        # Examples:
        #   __interactive_bump_files "$apply_all_answers"
    __interactive_bump_files() {
        local apply_all="${1:-0}"
        local mode=""
        local file=""
        local -a bump_files=()

        local mode=""
        __ask_bump_mode mode

        case "$mode" in
            cancel) return 2 ;;
            none|major|minor) ;;
            *) return 2 ;;
        esac

        if (( apply_all )); then
            bump_files=( "${TARGET_FILES[@]}" )
        else
            bump_files=( "${TARGET_FILES[0]}" )
        fi

        for file in "${bump_files[@]}"; do
            if __bump_one_file "$file" "$mode"; then
                case "$mode" in
                    major) sayok "Bumped major version in $file" ;;
                    minor) sayok "Bumped minor version in $file" ;;
                esac
            else
                sayfail "Failed version bump in $file"
                return 1
            fi
        done

        return 0
    }

    # __interactive_edit_current_file
        # Purpose:
        #   Interactively edit metadata for the current script using a fresh value buffer.
        #
        # Behavior:
        #   - Loads current metadata into META_ROWS.
        #   - Builds an editable buffer from the current values.
        #   - Prompts for new values.
        #   - Shows a summary of changed fields.
        #   - Confirms whether the changed fields should be applied.
        #   - Allows redo before committing changes.
        #
        # Inputs (globals):
        #   current_script
        #
        # Returns:
        #   0  success
        #   1  failure or user abort
        #
        # Usage:
        #   __interactive_edit_current_file
        #
        # Examples:
        #   current_script="$file"
        #   __interactive_edit_current_file
    __interactive_edit_current_file() {
        local -a value_buffer=()
        local -a changed_fields=()
        local field_list=""
        local field_word="fields"

        __get_metadata || return 1
        __build_value_buffer_from_meta value_buffer || return 1

        while true; do
            sayinfo "Editing: $current_script"
            __show_current_metadata
            echo

            __prompt_value_buffer value_buffer || return 1

            echo
            sayinfo "Pending changes:"
            __show_pending_value_buffer value_buffer || return 1
            echo

            mapfile -t changed_fields < <(__collect_changed_fields value_buffer) || return 1
            field_list="$(td_join ", " "${changed_fields[@]}")"

            if (( ${#changed_fields[@]} == 0 )); then
                field_list="(no changes)"
                field_word="fields"
            elif (( ${#changed_fields[@]} == 1 )); then
                field_word="field"
            else
                field_word="fields"
            fi

            ask_ok_redo_quit \
                "Apply changes to ${field_word} ${field_list} in $(basename "$current_script")?" 15

            case $? in
                0)
                    __apply_value_buffer_to_file value_buffer || return 1
                    break
                    ;;
                1)
                    continue
                    ;;
                2)
                    saycancel "Aborting as per user request."
                    return 1
                    ;;
                *)
                    sayfail "Aborting (unexpected response)."
                    return 1
                    ;;
            esac
        done
    }

    # __interactive_edit_current_file_with_buffer
        # Purpose:
        #   Interactively edit metadata for the current script using a supplied value buffer.
        #
        # Behavior:
        #   - Reuses the caller-supplied buffer by reference.
        #   - Supports normal prompting and idem-style buffer reuse.
        #   - Shows the current metadata and the list of changed fields.
        #   - Confirms whether the changed fields should be applied.
        #   - Allows redo before committing changes.
        #
        # Arguments:
        #   $1  BUFFER_NAME
        #       Name of the editable value buffer array variable.
        #   $2  PROMPT_MODE
        #       Prompt mode token.
        #       Supported values:
        #         normal
        #         idem_reuse
        #
        # Inputs (globals):
        #   current_script
        #
        # Returns:
        #   0  success
        #   1  failure
        #   2  cancelled
        #
        # Usage:
        #   __interactive_edit_current_file_with_buffer value_buffer normal
        #
        # Examples:
        #   __interactive_edit_current_file_with_buffer value_buffer idem_reuse
    __interactive_edit_current_file_with_buffer() {
            local -n io_buffer="$1"
            local prompt_mode="${2:-normal}"
            local -a changed_fields=()
            local field_list=""
            local field_word="fields"

            while true; do
                sayinfo "Editing: $current_script"
                __show_current_metadata
                echo

                if [[ "$prompt_mode" == "idem_reuse" ]]; then
                    sayinfo "Reusing previous answers (--idem)"
                else
                    __prompt_value_buffer io_buffer normal || return 1
                fi

                mapfile -t changed_fields < <(__collect_changed_fields io_buffer) || return 1
                field_list="$(td_join ", " "${changed_fields[@]}")"

                if (( ${#changed_fields[@]} == 0 )); then
                    field_list="(no changes)"
                    field_word="fields"
                elif (( ${#changed_fields[@]} == 1 )); then
                    field_word="field"
                else
                    field_word="fields"
                fi

                ask_ok_redo_quit \
                    "Apply changes to ${field_word} ${field_list} in $(basename "$current_script")?" 15

                case $? in
                    0)
                        __apply_value_buffer_to_file io_buffer || return 1
                        break
                        ;;
                    1)
                        continue
                        ;;
                    2)
                        saycancel "Aborting as per user request."
                        return 2
                        ;;
                    *)
                        sayfail "Aborting (unexpected response)."
                        return 1
                        ;;
                esac
            done
        }

    
    
    # __interactive_edit_files
        # Purpose:
        #   Interactive entry flow for target files.
        #
        # Behavior:
        #   - Shows the first file name.
        #   - In multi-file mode, optionally reuses first-file answers for all files.
        #   - Lets the user choose between editing fields and bumping version.
        #
        # Returns:
        #   0  success
        #   1  failure
        #   2  cancelled
    __interactive_edit_files() {
        local file=""
        local rc=0
        local action=""
        local apply_all_answers=0
        local -a value_buffer=()
        local first_file=""

        (( ${#TARGET_FILES[@]} > 0 )) || return 1

        first_file="${TARGET_FILES[0]}"
        local lw=15

        td_print
        td_print_sectionheader "Target" --border "${LN_H}" --padleft 2
        td_print_labeledvalue "First file" "$first_file" --pad 3 --labelwidth "$lw"

        if (( ${#TARGET_FILES[@]} > 1 )); then
            td_print_labeledvalue "File count" "${#TARGET_FILES[@]}" --pad 3 --labelwidth "$lw"

            td_print_sectionheader --border "${LN_H}"
            __ask_apply_first_answers_to_all
            rc=$?
            case "$rc" in
                0) apply_all_answers=1 ;;
                1) apply_all_answers=0 ;;
                *) apply_all_answers=0 ;;
            esac
        fi

        __ask_interactive_action action
        case "$action" in
            cancel)
                saycancel "Aborting as per user request."
                return 2
                ;;
            bump)
                __interactive_bump_files "$apply_all_answers"
                return $?
                ;;
            edit)
                ;;
            *)
                sayfail "Unknown action."
                return 1
                ;;
        esac

        for file in "${TARGET_FILES[@]}"; do
            current_script="$file"
            __get_metadata || return 1

            if [[ "$file" == "$first_file" ]]; then
                __build_value_buffer_from_meta value_buffer || return 1
                __interactive_edit_current_file_with_buffer value_buffer "normal"
                rc=$?
                case "$rc" in
                    0) ;;
                    2) return 2 ;;
                    *) return 1 ;;
                esac
                continue
            fi

            if (( apply_all_answers )); then
                __interactive_edit_current_file_with_buffer value_buffer "idem_reuse"
            else
                __build_value_buffer_from_meta value_buffer || return 1
                __interactive_edit_current_file_with_buffer value_buffer "normal"
            fi

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
        #   Bootstrap the framework, validate arguments, and run metadata-editor mode logic.
        #
        # Behavior:
        #   - Loads the framework bootstrapper.
        #   - Runs td_bootstrap() and builtin argument handling.
        #   - Prints the title bar and updates run-mode state.
        #   - Validates auto-mode and bump-mode arguments.
        #   - Dispatches to auto update mode, version metadata update mode,
        #     or interactive edit mode.
        #
        # Returns:
        #   Exits with an appropriate process status code.
        #
        # Usage:
        #   main "$@"
        #
        # Examples:
        #   main "$@"
    main() {
        local rc=0

        # -- Bootstrap
        __load_bootstrapper || exit $?

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
        __resolve_bump_mode || exit 2
        __validate_auto_args || exit 2
        __validate_bump_args || exit 2

        if (( ${FLAG_AUTO:-0} )) && (( ${FLAG_IDEM:-0} )); then
            saywarning "--idem is ignored in --auto mode"
        fi

        if (( ${FLAG_AUTO:-0} )) && (( ${FLAG_BUMPVERSION:-0} || ${FLAG_BUMPMAJOR:-0} || ${FLAG_BUMPMINOR:-0} )); then
            sayfail "Do not combine --auto with --bumpversion, --bumpmajor, or --bumpminor"
            exit 2
        fi

        if (( ${FLAG_IDEM:-0} )) && (( ${FLAG_BUMPVERSION:-0} || ${FLAG_BUMPMAJOR:-0} || ${FLAG_BUMPMINOR:-0} )); then
            saywarning "--idem is ignored in version bump mode"
        fi

        if (( ${FLAG_AUTO:-0} )); then
            __auto_update_files || exit $?
            exit 0
        fi

        if (( ${FLAG_BUMPVERSION:-0} || ${FLAG_BUMPMAJOR:-0} || ${FLAG_BUMPMINOR:-0} )); then
            __bump_version_files || exit $?
            exit 0
        fi

        [[ -n "${VAL_FILE:-}" || -n "${VAL_FOLDER:-}" ]] || {
            sayfail "Interactive mode currently requires --file <script|glob> or --folder <path>"
            exit 2
        }

        __resolve_targets || exit $?
        
        __interactive_edit_files || exit $?
    }

    # Entrypoint: td_bootstrap will split framework args from script args.
    main "$@"