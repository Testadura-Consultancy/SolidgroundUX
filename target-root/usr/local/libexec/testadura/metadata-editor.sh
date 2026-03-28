#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Metadata Editor
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : 5ba467af9945d004a1e8354e89171c1dd8c4b99c36d728173c0191802f26028c
#   Source      : metadata-editor.sh
#   Type        : script
#   Purpose     : Inspect, edit, and version script metadata in a controlled workflow
#
# Description:
#   Provides an interactive and automated tool for managing script header metadata
#   across SolidgroundUX workspaces.
#
#   The script operates on one or more source files and allows:
#     - Interactive editing of metadata fields (with validation and preview)
#     - Controlled version bumping (build, minor, major)
#     - Batch processing of multiple scripts with optional answer reuse (--idem)
#     - Safe execution through dry-run simulation
#
#   Metadata is treated as structured data and processed through the framework's
#   datatable and comment-parser abstractions.
#
# Core capabilities:
#   - Discover source files via folder + mask or explicit file selection
#   - Parse header sections into structured data tables
#   - Present metadata in a readable, sectioned UI
#   - Collect user input through aligned, validated prompts
#   - Apply only actual changes (delta-based updates)
#   - Maintain consistency of Version, Build, and Checksum fields
#
# Interaction model:
#   - Interactive mode:
#       Guides the user through editing or versioning workflows
#   - Auto mode (--auto):
#       Applies direct updates without prompts
#   - Version mode (--bump*):
#       Updates version metadata deterministically
#
# Design principles:
#   - Metadata is treated as data, not text
#   - Changes are explicit, minimal, and traceable
#   - Interactive workflows remain predictable and reversible
#   - Batch operations remain safe and transparent
#   - UX consistency across all SolidgroundUX scripts
#
# Role in framework:
#   - Primary tool for maintaining script header integrity
#   - Supports release preparation workflows
#   - Acts as reference implementation for interactive CLI UX patterns
#
# Non-goals:
#   - Packaging or distributing artifacts
#   - Version control operations (commit, tag, push)
#   - Dependency or build management
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
    # _framework_locator
        # Purpose:
        #   Locate, create, and load the SolidGroundUX bootstrap configuration.
        #
        # Behavior:
        #   - Searches user and system bootstrap configuration locations.
        #   - Prefers the invoking user's config over the system config.
        #   - Creates a new bootstrap config when none exists.
        #   - Prompts for framework/application roots in interactive mode.
        #   - Applies default values when running non-interactively.
        #   - Sources the selected configuration file.
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # Returns:
        #   0   success
        #   126 configuration unreadable or invalid
        #   127 configuration directory or file could not be created
        #
        # Usage:
        #   _framework_locator || return $?
        #
        # Examples:
        #   _framework_locator
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
    _framework_locator (){
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

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            # Validate paths (must be absolute)
            case "$fw_root" in
                /*) ;;
                *) sayfail "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) sayfail "ERR: SGND_APPLICATION_ROOT must be an absolute path"; return 126 ;;
            esac

            # Create configuration file
            mkdir -p "$(dirname "$cfg")" || return 127

            # write cfg file 
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            saydebug "Created bootstrap cfg: $cfg"
        fi

        # Load configuration
        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"

            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            sayfail "Cannot read bootstrap cfg: $cfg"
            return 126
        fi

        saydebug "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT"

    }

    # _load_bootstrapper
        # Purpose:
        #   Resolve and source the framework bootstrap library.
        #
        # Behavior:
        #   - Calls _framework_locator to establish framework roots.
        #   - Derives the sgnd-bootstrap.sh path from SGND_FRAMEWORK_ROOT.
        #   - Verifies that the bootstrap library is readable.
        #   - Sources sgnd-bootstrap.sh into the current shell.
        #
        # Inputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #
        # Returns:
        #   0   success
        #   126 bootstrap library unreadable
        #
        # Usage:
        #   _load_bootstrapper || return $?
        #
        # Examples:
        #   _load_bootstrapper
        #
        # Notes:
        #   - This is executable-level startup logic, not reusable framework behavior.
    _load_bootstrapper(){
        local bootstrap=""

        _framework_locator || return $?

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            bootstrap="/usr/local/lib/testadura/common/sgnd-bootstrap.sh"
        else
            bootstrap="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/testadura/common/sgnd-bootstrap.sh"
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
    

# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Metadata editor"
    SGND_SCRIPT_DESC="Reads and writes fields in script comments"

# --- Script metadata (framework integration) -----------------------------------------
    # SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
    SGND_USING=(
        sgnd-comment-parser.sh
        sgnd-datatable.sh
    )

    # SGND_ARGS_SPEC
    SGND_ARGS_SPEC=(
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

    # SGND_SCRIPT_EXAMPLES
    SGND_SCRIPT_EXAMPLES=(
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

    # SGND_SCRIPT_GLOBALS
    SGND_SCRIPT_GLOBALS=(
    )

    # SGND_STATE_VARIABLES
    SGND_STATE_VARIABLES=(
        "VAL_FOLDER|Source folder|$SGND_SCRIPT_DIR|"
        "VAL_FILE|File mask|*.sh|"
        "FLAG_IDEM|Apply answers to all files|Y|"
        "FLAG_BUMPVERSION|Refresh checksum and buildnr|Y|"
        "FLAG_BUMPMAJOR|Bump major version by one|Y|"
        "FLAG_BUMPMINOR|Bump minor version by one|Y|"
    )

    # SGND_ON_EXIT_HANDLERS
    SGND_ON_EXIT_HANDLERS=(
    )

    # State persistence is opt-in.
    SGND_STATE_SAVE=0

# --- Local script Declarations -------------------------------------------------------
    META_SCHEMA="section|field|value"
    declare -a META_ROWS=()

    declare -a SOURCE_FILES=()
    current_script=""
    BUMP_MODE="none"

    _ask_lw=15
    _ask_lp=3
    _prnt_lw=15
    _prnt_lp=3
    _sect_lp=2

# --- Local UI ------------------------------------------------------------------------
    # _print_section_labeledvalues
        # Purpose:
        #   Print all rows from one metadata section as labeled values.
        #
        # Behavior:
        #   - Reads rows from the supplied sgnd-datatable.
        #   - Filters rows by the requested section name.
        #   - Prints each matching field/value pair using sgnd_print_labeledvalue().
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
        #   _print_section_labeledvalues "$META_SCHEMA" META_ROWS "Metadata"
        #
        # Examples:
        #   _print_section_labeledvalues "$META_SCHEMA" META_ROWS "Attribution"
    _print_section_labeledvalues() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local wanted_section="${3:?missing section}"

        local row_count=0
        local i=0
        local section=""
        local field=""
        local value=""

        row_count="$(sgnd_dt_row_count "$table_name")" || return 1

        sgnd_print
        sgnd_print_sectionheader "$wanted_section" --border "${LN_H}" --padleft 2
        for (( i=0; i<row_count; i++ )); do
            section="$(sgnd_dt_get "$schema" "$table_name" "$i" "section")" || return 1
            [[ "$section" == "$wanted_section" ]] || continue

            field="$(sgnd_dt_get "$schema" "$table_name" "$i" "field")" || return 1
            value="$(sgnd_dt_get "$schema" "$table_name" "$i" "value")" || return 1

            sgnd_print_labeledvalue "$field" "$value" --pad "$_prnt_lp" --labelwidth "$_prnt_lw"
        done
    }

    # _show_current_metadata
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
        #   _show_current_metadata
        #
        # Examples:
        #   _get_metadata || return 1
        #   _show_current_metadata
    _show_current_metadata(){
        sgnd_print
        sgnd_print_sectionheader "Current data" --border "${LN_H}" --padleft 2

        _print_section_labeledvalues "$META_SCHEMA" META_ROWS "Metadata"
        _print_section_labeledvalues "$META_SCHEMA" META_ROWS "Attribution"

        sgnd_print
        sgnd_print_sectionheader --border "${LN_H}" --padleft 0
    }

    # _show_pending_value_buffer
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
        #   _show_pending_value_buffer value_buffer
        #
        # Examples:
        #   _show_pending_value_buffer io_buffer
    _show_pending_value_buffer() {
        local -n in_buffer="$1"
        local i=0
        local section=""
        local field=""
        local old_value=""
        local new_value=""
        local prev_section=""
        local any_changes=0

        sgnd_print
        sgnd_print_sectionheader "Summary" --border "${LN_H}" --padleft 2

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            field="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            old_value="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            new_value="${in_buffer[$i]-}"

            [[ "$new_value" == "$old_value" ]] && continue

            if [[ "$section" != "$prev_section" ]]; then
                sgnd_print
                sgnd_print_sectionheader "$section" --border "${LN_H}" --padend 0 --padleft 2
                prev_section="$section"
            fi

            sgnd_print_labeledvalue "$field" "" --pad 3 --labelwidth 20
            (( any_changes++ ))
        done

        if (( any_changes == 0 )); then
            sgnd_print
            sgnd_print_labeledvalue "No changes" "" --pad 3
        fi

        sgnd_print_sectionheader --border "${LN_H}"
    }

# --- Local script functions ----------------------------------------------------------
    # _field_is_selected
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
        #   _field_is_selected "Version"
        #
        # Examples:
        #   if _field_is_selected "$field"; then
        #       :
        #   fi
    _field_is_selected() {
        local wanted="${1:?missing field}"
        local item=""
        local list="${VAL_PROMPTFOR:-}"

        [[ -n "$list" ]] || return 0

        IFS=',' read -r -a _me_promptfor <<< "$list"

        for item in "${_me_promptfor[@]}"; do
            item="${item#"${item%%[![:space:]]*}"}"
            item="${item%"${item##*[![:space:]]}"}"

            [[ "$item" == "$wanted" ]] && return 0
        done

        return 1
    }

    # _resolve_source
        # Purpose:
        #   Resolve effective processing targets into SOURCE_FILES.
        #
        # Behavior:
        #   - Normalizes folder and file mask via _resolve_source_input().
        #   - Combines folder + mask into a single glob expression.
        #   - Expands matches using shell globbing.
        #   - Keeps only regular readable files.
        #   - Normalizes all results to absolute paths.
        #   - Fails when no readable files match.
        #
        # Inputs (globals):
        #   VAL_FOLDER
        #   VAL_FILE
        #
        # Outputs (globals):
        #   SOURCE_FILES
        #
        # Returns:
        #   0  success
        #   1  invalid folder or no readable matches found
        #
        # Usage:
        #   _resolve_source || return 1
        #
        # Examples:
        #   _resolve_source
    _resolve_source() {
        local folder=""
        local mask=""
        local fullmask=""
        local file=""

        SOURCE_FILES=()

        _resolve_source_input

        folder="${VAL_FOLDER}"
        mask="${VAL_FILE}"

        [[ -d "$folder" ]] || {
            sayfail "Folder not found: $folder"
            return 1
        }

        fullmask="${folder%/}/$mask"

        shopt -s nullglob
        for file in $fullmask; do
            [[ -f "$file" ]] || continue

            if [[ ! -r "$file" ]]; then
                saywarning "Skipping unreadable file: $file"
                continue
            fi
            SOURCE_FILES+=( "$(readlink -f "$file")" )
        done
        shopt -u nullglob

        if (( ${#SOURCE_FILES[@]} == 0 )); then
            sayfail "No readable files matched: $fullmask"
            return 1
        fi

        return 0
    }

    # _get_metadata
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
        #   _get_metadata || return 1
        #
        # Examples:
        #   current_script="$file"
        #   _get_metadata
    _get_metadata() {
        local -a meta_rows=()
        local -a attr_rows=()

        META_ROWS=()

        sgnd_header_load_section_to_dt "$current_script" "Metadata" "$META_SCHEMA" meta_rows || return 1
        sgnd_header_load_section_to_dt "$current_script" "Attribution" "$META_SCHEMA" attr_rows || return 1

        META_ROWS+=( "${meta_rows[@]}" )
        META_ROWS+=( "${attr_rows[@]}" )
    }

    # _resolve_bump_mode
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
        #   _resolve_bump_mode || exit 2
        #
        # Examples:
        #   _resolve_bump_mode
    _resolve_bump_mode() {
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

    # _validate_auto_args
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
        #   _validate_auto_args || exit 2
        #
        # Examples:
        #   _validate_auto_args
    _validate_auto_args() {
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

    # _validate_bump_args
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
        #   _validate_bump_args || exit 2
        #
        # Examples:
        #   _validate_bump_args
    _validate_bump_args() {
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

    # _auto_update_files
        # Purpose:
        #   Apply one direct field update to all resolved target files.
        #
        # Behavior:
        #   - Resolves target files from --file or --folder.
        #   - Applies sgnd_header_set_field() to each target.
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
        #   _auto_update_files || exit $?
        #
        # Examples:
        #   _auto_update_files
    _auto_update_files() {
        local file=""
        local rc=0
        local changed=0
        local failed=0

        _resolve_source || return 1

        for file in "${SOURCE_FILES[@]}"; do
            if sgnd_header_set_field "$file" "$VAL_SECTION" "$VAL_FIELD" "$VAL_VALUE"; then
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

    # _bump_one_file
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
    _bump_one_file() {
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

        sgnd_header_bump_version "$file" "$mode"
    }

    # _bump_version_files
        # Purpose:
        #   Apply the resolved version metadata update mode to all target files.
        #
        # Behavior:
        #   - Resolves target files from --file or --folder.
        #   - Applies _bump_one_file() to each target.
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
        #   _bump_version_files || exit $?
        #
        # Examples:
        #   _bump_version_files
    _bump_version_files() {
        local file=""
        local changed=0
        local failed=0

        _resolve_source || return 1

        for file in "${SOURCE_FILES[@]}"; do
            if _bump_one_file "$file" "$BUMP_MODE"; then
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

    # _collect_changed_fields
        # Purpose:
        #   Collect the names of fields whose pending values differ from current metadata.
        #
        # Arguments:
        #   $1  BUFFER_NAME
        #
        # Outputs:
        #   Writes changed field names to stdout, one per line.
    _collect_changed_fields() {
        local -n in_buffer="$1"
        local i=0
        local field=""
        local old_value=""
        local new_value=""

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            field="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            old_value="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            new_value="${in_buffer[$i]-}"

            [[ "$new_value" == "$old_value" ]] && continue
            printf '%s\n' "$field"
        done
    }

# --- User input ----------------------------------------------------------------------
    # _resolve_source_input
        # Purpose:
        #   Normalize and optionally prompt for target folder and file mask.
        #
        # Behavior:
        #   - Accepts values from:
        #       VAL_FOLDER  (folder)
        #       VAL_FILE    (file name or glob mask)
        #   - When VAL_FILE contains a path, splits it into folder + mask.
        #   - Applies defaults when values are missing:
        #       folder -> .
        #       mask   -> *.sh
        #   - In interactive mode:
        #       prompts for folder and file mask using ask().
        #   - Writes normalized values back to:
        #       VAL_FOLDER
        #       VAL_FILE
        #
        # Inputs (globals):
        #   VAL_FOLDER
        #   VAL_FILE
        #
        # Outputs (globals):
        #   VAL_FOLDER
        #   VAL_FILE
        #
        # Returns:
        #   0  success
        #
        # Usage:
        #   _resolve_source_input
        #
        # Examples:
        #   _resolve_source_input
    _resolve_source_input() {
        local _folder="${VAL_FOLDER:-}"
        local _mask="${VAL_FILE:-}"

        # If file contains a path, split it
        if [[ -z "$_folder" && -n "$_mask" && "$_mask" == */* ]]; then
            _folder="$(dirname "$_mask")"
            _mask="$(basename "$_mask")"
        fi

        # Defaults
        [[ -n "$_folder" ]] || _folder="."
        [[ -n "$_mask"   ]] || _mask="*.sh"

        # Interactive prompt (TTY only)
        if [[ -t 0 && -t 1 ]]; then
            ask --label "Folder"    --default "$_folder" --var _folder --pad "$_ask_lp" --default "$VAL_FOLDER" --labelwidth "$_ask_lw" --labelclr "${CYAN}"
            ask --label "File mask" --default "$_mask"   --var _mask --pad "$_ask_lp" --default "$VAL_FILE" --labelwidth "$_ask_lw" --labelclr "${CYAN}"
        fi

        VAL_FOLDER="$_folder"
        VAL_FILE="$_mask"
    }

    # _build_value_buffer_from_meta
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
        #   _build_value_buffer_from_meta value_buffer
        #
        # Examples:
        #   _build_value_buffer_from_meta io_buffer
    _build_value_buffer_from_meta() {
        local -n out_buffer="$1"
        local i=0
        local value=""

        out_buffer=()

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            value="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            out_buffer+=( "$value" )
        done
    }

    # _prompt_value_buffer
        # Purpose:
        #   Prompt interactively for editable field values and update the buffer in place.
        #
        # Behavior:
        #   - Iterates through META_ROWS in order.
        #   - Prompts only for fields selected by _field_is_selected().
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
        #   _prompt_value_buffer value_buffer normal
        #
        # Examples:
        #   _prompt_value_buffer io_buffer idem
    _prompt_value_buffer() {
        local -n buffer_ref="$1"
        local prompt_mode="${2:-normal}"
        local i=0
        local section=""
        local field=""
        local current_value=""
        local new_value=""
        local prev_section=""
        local new_section=1

        sgnd_print "Enter new values for the selected fields"

        for (( i=0; i<${#META_ROWS[@]}; i++ )); do
            section="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            if [[ "$section" != "$prev_section" ]]; then
                prev_section="$section"
                new_section=1
            fi

            field="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            current_value="${buffer_ref[$i]-}"

            _field_is_selected "$field" || continue

            if [[ "$prompt_mode" == "idem" ]]; then
                continue
            fi

            if [[ "$new_section" == 1 ]]; then
                sgnd_print
                sgnd_print_sectionheader "$section" --border "${LN_H}" --padend 0 --padleft 2
                new_section=0
            fi

            ask --label "    $field" --var new_value --default "$current_value" --labelwidth "$_ask_lw" --labelclr "${CYAN}"
            buffer_ref[$i]="$new_value"
        done

        sgnd_print
        sgnd_print_sectionheader --border "${LN_H}"
    }

    # _ask_interactive_action
        # Purpose:
        #   Ask which interactive action to apply to the selected targets.
        #
        # Behavior:
        #   - Displays the interactive action menu.
        #   - Reads the user's choice through ask_choose().
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
        #   _ask_interactive_action action
        #
        # Examples:
        #   local action=""
        #   _ask_interactive_action action
            # Purpose:
            #   Ask whether to edit fields or bump version.
            #
            # Outputs:
            #   Writes selected action token to stdout:
            #     edit | bump | cancel
    _ask_interactive_action() {
        local -n out_action="$1"
        local choice=""

        sgnd_print
        sgnd_print_sectionheader "Action" --border "${LN_H}" --padleft 2
        sgnd_print_labeledvalue --label "E" --value "Edit fields" --pad 3 --labelwidth 3
        sgnd_print_labeledvalue --label "B" --value "Bump version" --pad 3 --labelwidth 3
        sgnd_print_labeledvalue --label "Q" --value "Cancel" --pad 3 --labelwidth 3
        sgnd_print
        
        ask_choose_immediate \
            --label "Choose" \
            --choices "E,B,Q" \
            --instantchoices "E,B,Q" \
            --var choice \
            --pad "$_ask_lp" \
            --labelclr "${CYAN}"

        case "${choice^^}" in
            E) out_action="edit" ;;
            B) out_action="bump" ;;
            Q) out_action="cancel" ;;
            *) out_action="cancel" ;;
        esac
    }

    # _ask_bump_mode
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
        #   _ask_bump_mode mode
        #
        # Examples:
        #   local mode=""
        #   _ask_bump_mode mode
            # Purpose:
            #   Ask which semantic version bump to apply.
            #
            # Outputs:
            #   Writes selected mode token to stdout:
            #     major | minor | cancel
    _ask_bump_mode() {
        local -n out_mode="$1"
        local choice=""
        local lw=4
        local lp=3

        sgnd_print
        sgnd_print_sectionheader "Version update" --border "${LN_H}" --padleft 2 --padend 0
        sgnd_print_labeledvalue "0" "Refresh build/checksum" --pad "$lp" --labelwidth "$lw"
        sgnd_print_labeledvalue "1" "Major" --pad "$lp" --labelwidth "$lw"
        sgnd_print_labeledvalue "2" "Minor" --pad "$lp" --labelwidth "$lw"
        sgnd_print_labeledvalue "Q" "Cancel" --pad "$lp" --labelwidth "$lw"
        sgnd_print

        ask_choose --label "Choose" --choices "0, 1,2,Q" --var choice   --pad "$_ask_lp" --labelclr "${CYAN}"

        case "${choice^^}" in
            0) out_mode="none" ;;
            1) out_mode="major" ;;
            2) out_mode="minor" ;;
            Q) out_mode="cancel" ;;
            *) out_mode="cancel" ;;
        esac
    }
    
    # _apply_value_buffer_to_file
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
        #   _apply_value_buffer_to_file value_buffer
        #
        # Examples:
        #   _apply_value_buffer_to_file io_buffer
    _apply_value_buffer_to_file() {
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
            section="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "section")" || return 1
            field="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "field")" || return 1
            old_value="$(sgnd_dt_get "$META_SCHEMA" META_ROWS "$i" "value")" || return 1
            new_value="${in_buffer[$i]-}"

            [[ "$new_value" == "$old_value" ]] && continue

            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "[DRYRUN] Would update [$section] $field in $current_script: '$old_value' -> '$new_value'"
                (( changed++ ))
                continue
            fi

            if sgnd_header_set_field "$current_script" "$section" "$field" "$new_value"; then
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
    # _interactive_bump_files
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
        #   SOURCE_FILES
        #
        # Returns:
        #   0  success
        #   1  failure
        #   2  cancelled
        #
        # Usage:
        #   _interactive_bump_files 0
        #
        # Examples:
        #   _interactive_bump_files "$apply_all_answers"
    _interactive_bump_files() {
        local apply_all="${1:-0}"
        local mode=""
        local file=""
        local -a bump_files=()

        local mode=""
        _ask_bump_mode mode

        case "$mode" in
            cancel) return 2 ;;
            none|major|minor) ;;
            *) return 2 ;;
        esac

        if (( apply_all )); then
            bump_files=( "${SOURCE_FILES[@]}" )
        else
            bump_files=( "${SOURCE_FILES[0]}" )
        fi

        for file in "${bump_files[@]}"; do
            if _bump_one_file "$file" "$mode"; then
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

    # _interactive_edit_current_file
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
        #   _interactive_edit_current_file
        #
        # Examples:
        #   current_script="$file"
        #   _interactive_edit_current_file
    _interactive_edit_current_file() {
        local -a value_buffer=()
        local -a changed_fields=()
        local field_list=""
        local field_word="fields"

        _get_metadata || return 1
        _build_value_buffer_from_meta value_buffer || return 1

        while true; do
            sayinfo "Editing: $current_script"
            _show_current_metadata
            echo

            _prompt_value_buffer value_buffer || return 1

            echo
            sayinfo "Pending changes:"
            _show_pending_value_buffer value_buffer || return 1
            echo

            mapfile -t changed_fields < <(_collect_changed_fields value_buffer) || return 1
            field_list="$(sgnd_join ", " "${changed_fields[@]}")"

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
                    _apply_value_buffer_to_file value_buffer || return 1
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

    # _interactive_edit_current_file_with_buffer
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
        #   _interactive_edit_current_file_with_buffer value_buffer normal
        #
        # Examples:
        #   _interactive_edit_current_file_with_buffer value_buffer idem_reuse
    _interactive_edit_current_file_with_buffer() {
            local -n io_buffer="$1"
            local prompt_mode="${2:-normal}"
            local -a changed_fields=()
            local field_list=""
            local field_word="fields"

            while true; do
                sayinfo "Editing: $current_script"
                _show_current_metadata
                echo

                if [[ "$prompt_mode" == "idem_reuse" ]]; then
                    sayinfo "Reusing previous answers (--idem)"
                else
                    _prompt_value_buffer io_buffer normal || return 1
                fi

                mapfile -t changed_fields < <(_collect_changed_fields io_buffer) || return 1
                field_list="$(sgnd_join ", " "${changed_fields[@]}")"

                if (( ${#changed_fields[@]} == 0 )); then
                    field_list="(no changes)"
                    field_word="fields"
                elif (( ${#changed_fields[@]} == 1 )); then
                    field_word="field"
                else
                    field_word="fields"
                fi

                ask_dlg_autocontinue --seconds 15 --message "Apply changes to ${field_word} ${field_list} in $(basename "$current_script")?" --redo --cancel

                case $? in
                    0|1)
                        _apply_value_buffer_to_file io_buffer || return 1
                        break
                        ;;
                    2)
                        saycancel "Aborting as per user request."
                        return 2
                        ;;
                    3)
                        continue
                        ;;
                    *)
                        sayfail "Aborting (unexpected response)."
                        return 1
                        ;;
                esac
            done
        }

    
    
    # _interactive_edit_files
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
    _interactive_edit_files() {
        local file=""
        local rc=0
        local action=""
        local apply_all_answers=0
        local -a value_buffer=()
        local first_file=""

        (( ${#SOURCE_FILES[@]} > 0 )) || return 1

        first_file="${SOURCE_FILES[0]}"        

        sgnd_print
        sgnd_print_labeledvalue "First file" "$first_file" --pad 3 --labelwidth "$_ask_lw" --labelclr "$(sgnd_sgr "$SILVER" "$FX_ITALIC")" --valueclr "$(sgnd_sgr "$SILVER" "$FX_ITALIC")"

        if (( ${#SOURCE_FILES[@]} > 1 )); then
            sgnd_print_labeledvalue "File count" "${#SOURCE_FILES[@]}" --pad "$_ask_lp" --labelwidth "$_ask_lw" --labelclr "$(sgnd_sgr "$SILVER" "$FX_ITALIC")" --valueclr "$(sgnd_sgr "$SILVER" "$FX_ITALIC")"
            sgnd_print

            ask --label "Apply first file's answers to all?" --var _resp --default "Y" --colorize both --labelclr "${CYAN}" --pad "$_ask_lp" --labelwidth "$_ask_lw"

            case "$_resp" in
                0) apply_all_answers=1 ;;
                1) apply_all_answers=0 ;;
                *) apply_all_answers=0 ;;
            esac
        fi

        _ask_interactive_action action
        case "$action" in
            cancel)
                saycancel "Aborting as per user request."
                return 2
                ;;
            bump)
                _interactive_bump_files "$apply_all_answers"
                return $?
                ;;
            edit)
                ;;
            *)
                sayfail "Unknown action."
                return 1
                ;;
        esac

        for file in "${SOURCE_FILES[@]}"; do
            current_script="$file"
            _get_metadata || return 1

            if [[ "$file" == "$first_file" ]]; then
                _build_value_buffer_from_meta value_buffer || return 1
                _interactive_edit_current_file_with_buffer value_buffer "normal"
                rc=$?
                case "$rc" in
                    0) ;;
                    2) return 2 ;;
                    *) return 1 ;;
                esac
                continue
            fi

            if (( apply_all_answers )); then
                _interactive_edit_current_file_with_buffer value_buffer "idem_reuse"
            else
                _build_value_buffer_from_meta value_buffer || return 1
                _interactive_edit_current_file_with_buffer value_buffer "normal"
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
        #   - Runs sgnd_bootstrap() and builtin argument handling.
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
        # -- Bootstrap
            local rc=0

            _load_bootstrapper || exit $?            

            # Recognized switches:
            #     --state      -> enable saving state variables 
            #     --autostate  -> enable state support and auto-save SGND_STATE_VARIABLES on exit
            #     --needroot   -> restart script if not root
            #     --cannotroot -> exit script if root
            #     --log        -> enable file logging
            #     --console    -> enable console logging
            # Example:
            #   sgnd_bootstrap --state --needroot -- "$@"
            sgnd_bootstrap --state -- "$@"
            rc=$?

            saydebug "After bootstrap: $rc"
            (( rc != 0 )) && exit "$rc"
                        
        # -- Handle builtin arguments
            saydebug "Calling builtinarg handler"
            sgnd_builtinarg_handler
            saydebug "Exited builtinarg handler"

        # -- UI
            sgnd_update_runmode
            sgnd_print_titlebar

        # -- Main script logic
        _resolve_bump_mode || exit 2
        _validate_auto_args || exit 2
        _validate_bump_args || exit 2

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
            _auto_update_files || exit $?
            exit 0
        fi

        if (( ${FLAG_BUMPVERSION:-0} || ${FLAG_BUMPMAJOR:-0} || ${FLAG_BUMPMINOR:-0} )); then
            _bump_version_files || exit $?
            exit 0
        fi

        _resolve_source || exit $?
        
        _interactive_edit_files || exit $?
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
