#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Documentation Generator
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2609100
#   Checksum    : none
#   Source      : doc-generator.sh
#   Type        : script
#   Purpose     : Generate documentation from source code comments using the sgnd-comment-parser library.
#
# Description:
#
# Design principles:
#
# Role in framework:
# Non-goals:
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

        local cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
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
            bootstrap="/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"
        else
            bootstrap="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"
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

# --- Script metadata (framework integration) -----------------------------------------
    # var: SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
        #
        # Example:
        #   SGND_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    SGND_USING=(
        sgnd-datatable.sh
        sgnd-comment-parser.sh
    )

    # var: SGND_ARGS_SPEC 
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
        #   default   Default value applied before parsing
        #   choices = for enum: comma-separated values (e.g. fast,slow,auto)
        #             for flag/value: leave empty
        #
        # Notes:
        #   - -h / --help is built in, you don't need to define it here.
        #   - After parsing you can use: FLAG_VERBOSE, VAL_CONFIG, ENUM_MODE, ...
    SGND_ARGS_SPEC=(
        "srcdir|s|value|VAL_SRCDIR|Source directory to scan||"
        "file|f|value|VAL_FILE|Single file to scan||"
        "mask|m|value|VAL_MASK|Filename mask for source scanning|*.sh|"
        "outdir|o|value|VAL_OUTDIR|Output directory for generated docs||"
        "recursive|r|flag|FLAG_RECURSIVE_SCAN|Recursively scan source directory|1|"
    )

    # var: SGND_SCRIPT_EXAMPLES
        # Optional: examples for --help output.
        # Each entry is a string that will be printed verbatim.
        #
        # Example:
        #   SGND_SCRIPT_EXAMPLES=(
        #       "Example usage:"
        #       "  script.sh --verbose --mode fast"
        #       "  script.sh -v -m slow"
        #   )
        #
        # Leave empty if no examples are needed.
    SGND_SCRIPT_EXAMPLES=(
        "Run in dry-run mode:"
        "  $SGND_SCRIPT_NAME --dryrun"
        ""
        "Show verbose logging"
        "  $SGND_SCRIPT_NAME --verbose"
    ) 

    # var: SGND_SCRIPT_GLOBALS
        # Explicit declaration of global variables intentionally used by this script.
        #
        # Purpose:
        #   - Declares which globals are part of the script’s public/config contract.
        #   - Enables optional configuration loading when non-empty.
        #
        # Behavior:
        #   - If this array is non-empty, sgnd_bootstrap enables config integration.
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
    SGND_SCRIPT_GLOBALS=(
    )

    # var: SGND_STATE_VARIABLES
        # List of variables participating in persistent state.
        #
        # Purpose:
        #   - Declares which variables should be saved/restored when state is enabled.
        #
        # Behavior:
        #   - Only used when sgnd_bootstrap is invoked with --state.
        #   - Variables listed here are serialized on exit (if SGND_STATE_SAVE=1).
        #   - On startup, previously saved values are restored before main logic runs.
        #
        # Contract:
        #   - Variables must be simple scalars (no arrays/associatives unless explicitly supported).
        #   - Script remains fully functional when state is disabled.
        #
        # Leave empty if:
        #   - The script does not use persistent state.
    SGND_STATE_VARIABLES=(
        "DOC_SOURCE|Source Directory||"
        "DOC_FILE|Source File||"
        "DOC_MASK|Filename Mask|*.sh|"
        "DOC_OUTDIR|Output Directory||"
        "RECURSIVE_SCAN|Recursive Scan|0|"
    )

    # var: SGND_ON_EXIT_HANDLERS
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
    SGND_ON_EXIT_HANDLERS=(
    )
    
    # State persistence is opt-in.
        # Scripts that want persistent state must:
        #   1) set SGND_STATE_SAVE=1
        #   2) call sgnd_bootstrap --state
    SGND_STATE_SAVE=1

# --- Local script Declarations -------------------------------------------------------
    # Put script-local constants and defaults here (NOT framework config).
    # Prefer local variables inside functions unless a value must be shared.
    DOC_MODULE_SCHEMA="file|product|title|purpose|type|version|build"
    DOC_MODULES=()
    
    DOC_FUNCTION_SCHEMA="file|line|major_section|minor_section|function_name|purpose"
    DOC_FUNCTIONS=()
    
    DOC_SCAN_SCHEMA="file|line_nr|record_type|name|parent_section|text"
    DOC_SCAN_ROWS=()

# --- Local helpers -------------------------------------------------------------------
    # fn: _is_header_separator
        # Returns:
        #   0 if LINE is a canonical header separator line.
        #   1 otherwise.
        #
        # Usage:
        #   _is_header_separator "$line"
    _is_header_separator() {
        [[ "$1" =~ ^[[:space:]]*#[[:space:]]*={3,}[[:space:]]*$ ]]
    }

    # fn: _is_header_section_line
        # Returns:
        #   0 if LINE is a canonical header section line.
        #   1 otherwise.
        #
        # Usage:
        #   _is_header_section_line "$line"
    _is_header_section_line() {
        [[ "$1" =~ ^#\ [A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]]
    }

    # fn: _parse_header_section_line
        # Returns:
        #   Prints the parsed header section title to stdout.
        #
        # Usage:
        #   _parse_header_section_line "$line"
    _parse_header_section_line() {
        local line="${1-}"
        local value=""

        value="${line#\# }"
        value="${value%:}"
        value="${value%"${value##*[![:space:]]}"}"

        printf '%s\n' "$value"
    }

    # fn: _is_section_line
    _is_section_line() {
        [[ "$1" =~ ^[[:space:]]*#\ (-|--|---)\ ([^[:space:]].*)$ ]]
    }

    # fn: _get_section_level
    _get_section_level() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#\ (-|--|---)\  ]] || return 1

        case "${BASH_REMATCH[1]}" in
            ---) printf '1\n' ;;
            --)  printf '2\n' ;;
            -)   printf '3\n' ;;
            *)   return 1 ;;
        esac
    }

    # fn: _parse_section_line
    _parse_section_line() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#\ (-|--|---)\ (.*)$ ]] || return 1
        printf '%s\n' "${BASH_REMATCH[2]}"
    }

    # fn: _is_detail_comment_start
    _is_detail_comment_start() {
        [[ "$1" =~ ^[[:space:]]*#[[:space:]]*(fn|var):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]]
    }

    # fn: _parse_detail_kind
    _parse_detail_kind() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#[[:space:]]*(fn|var):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]] || return 1
        printf '%s\n' "${BASH_REMATCH[1]}"
    }

    # fn: _parse_detail_name
    _parse_detail_name() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#[[:space:]]*(fn|var):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]] || return 1
        printf '%s\n' "${BASH_REMATCH[2]}"
    }

    # fn: _detail_matches_declaration
    _detail_matches_declaration() {
        local kind="${1:?missing kind}"
        local name="${2:?missing name}"
        local line="${3-}"

        case "$kind" in
            fn)
                [[ "$line" =~ ^[[:space:]]*${name}[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*$ ]]
                ;;
            var)
                [[ "$line" =~ ^[[:space:]]*${name}= ]]
                ;;
            *)
                return 1
                ;;
        esac
    }

    # fn: _normalize_comment_line
        # Remove leading comment marker and one optional following space.
    _normalize_comment_line() {
        local line="${1-}"

        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]?(.*)$ ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
        else
            printf '%s\n' "$line"
        fi
    }

# --- Local script functions ----------------------------------------------------------
    # fn: _resolve_parameters
        # Purpose:
        #   Resolve effective documentation generator input parameters from
        #   command-line values, existing globals, and interactive prompts.
        #
        # Behavior:
        #   - Establishes effective values for source directory, optional
        #     single-file mode, filename mask, output directory, and recursive scan.
        #   - Prefers parsed command-line values when present.
        #   - Falls back to existing globals or framework defaults when needed.
        #   - Prompts the user interactively to review or modify the resolved values.
        #   - Converts the recursive scan answer into the numeric flag
        #     RECURSIVE_SCAN (1 or 0).
        #   - Repeats the prompt cycle when the user chooses redo.
        #
        # Inputs (globals):
        #   VAL_SRCDIR
        #   VAL_FILE
        #   VAL_MASK
        #   VAL_OUTDIR
        #   FLAG_RECURSIVE_SCAN
        #   SGND_APPLICATION_ROOT
        #   SGND_DOCS_DIR
        #
        # Outputs (globals):
        #   DOC_SOURCE
        #   DOC_FILE
        #   DOC_MASK
        #   DOC_OUTDIR
        #   RECURSIVE_SCAN
        #
        # Returns:
        #   0 on success.
        #   1 if the user cancels or an unexpected dialog result occurs.
        #
        # Notes:
        #   - When DOC_FILE is specified later in processing, it takes precedence
        #     over directory scanning.
        #   - DOC_MASK should default to "*.sh".
    _resolve_parameters() {
        DOC_SOURCE="${VAL_SRCDIR:-${DOC_SOURCE:-$SGND_APPLICATION_ROOT}}"
        DOC_FILE="${VAL_FILE:-${DOC_FILE:-}}"
        DOC_MASK="${VAL_MASK:-${DOC_MASK:-*.sh}}"
        DOC_OUTDIR="${VAL_OUTDIR:-${DOC_OUTDIR:-$SGND_DOCS_DIR}}"
        RECURSIVE_SCAN="${FLAG_RECURSIVE_SCAN:-${RECURSIVE_SCAN:-1}}"
        DOC_SOURCE="/home/sysadmin/dev/SolidgroundUX/target-root/usr/local/libexec/solidgroundux"
        DOC_FILE="doc-generator.sh"
        local lw=25
        local lp=4

        while true; do
            sgnd_print
            sgnd_print_sectionheader "Enter Documentation Generator Parameters" --padend 0
            ask --label "Source directory" --var DOC_SOURCE --default "$DOC_SOURCE" --validate sgnd_validate_dir_exists --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            ask --label "Source file" --var DOC_FILE --default "$DOC_FILE" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            ask --label "Filename mask" --var DOC_MASK --default "$DOC_MASK" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            ask --label "Output directory" --var DOC_OUTDIR --default "$DOC_OUTDIR" --validate sgnd_validate_dir_exists --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"

            local recursive_default="No"
            local answ=""
            if (( RECURSIVE_SCAN )); then
                recursive_default="Yes"
            fi

            ask --label "Recursive scan (Y/N)" --var answ --type flag --default "$recursive_default" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            answ="${answ,,}"

            if [[ "$answ" == "y" || "$answ" == "yes" ]]; then
                RECURSIVE_SCAN=1
            else
                RECURSIVE_SCAN=0
            fi

            sgnd_print_sectionheader --maxwidth "$lw"
            sgnd_print
            ask_dlg_autocontinue --seconds 15 --message "Continue with these settings?" --redo --cancel --pause

            case $? in
                0|1) break ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                3) PROJECT_NAME=""; PROJECT_FOLDER=""; continue ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac
        done
    }

    # fn: _process_files
        # Purpose:
        #   Scan the selected source file set and populate the documentation
        #   datatables through the sgnd-comment-parser scan hooks.
        #
        # Behavior:
        #   - Clears previously collected module and function rows.
        #   - Uses DOC_FILE when a single file was explicitly specified.
        #   - Otherwise scans DOC_SOURCE for files matching DOC_MASK.
        #   - Honors RECURSIVE_SCAN when scanning a source directory.
        #   - Calls sgnd_scan_file for each matched file.
        #   - Relies on sgnd_scan_emit_module_hook and
        #     sgnd_scan_emit_function_hook to append normalized rows.
        #
        # Arguments:
        #   None.
        #
        # Inputs (globals):
        #   DOC_FILE
        #   DOC_SOURCE
        #   DOC_MASK
        #   RECURSIVE_SCAN
        #   DOC_MODULE_SCHEMA
        #   DOC_FUNCTION_SCHEMA
        #
        # Outputs (globals):
        #   DOC_MODULES
        #   DOC_FUNCTIONS
        #
        # Returns:
        #   0 on success.
        #   1 on invalid input or scan failure.
        #
        # Notes:
        #   - Single-file mode takes precedence over directory scanning.
        #   - Filename collection uses find -print0 to safely support spaces.
    _process_files() {
        local -a files=()
        local file=""
        local scanned_count=0
        local mask="${DOC_MASK:-*.sh}"

        DOC_MODULES=()
        DOC_FUNCTIONS=()

        # Assemble file list
        if [[ -n "${DOC_FILE:-}" ]]; then
            [[ -f "$DOC_FILE" ]] || {
                sayfail "Specified file does not exist: $DOC_FILE"
                return 1
            }

            [[ -r "$DOC_FILE" ]] || {
                sayfail "Specified file is not readable: $DOC_FILE"
                return 1
            }

            files+=("$DOC_FILE")
        else
            [[ -n "${DOC_SOURCE:-}" ]] || {
                sayfail "No source directory was specified."
                return 1
            }

            [[ -d "$DOC_SOURCE" ]] || {
                sayfail "Source directory does not exist: $DOC_SOURCE"
                return 1
            }

            if (( ${RECURSIVE_SCAN:-0} )); then
                while IFS= read -r -d '' file; do
                    files+=("$file")
                done < <(
                    find "$DOC_SOURCE" -type f -name "$mask" -print0
                )
            else
                while IFS= read -r -d '' file; do
                    files+=("$file")
                done < <(
                    find "$DOC_SOURCE" -maxdepth 1 -type f -name "$mask" -print0
                )
            fi
        fi

        if (( ${#files[@]} == 0 )); then
            saywarning "No matching files found."
            return 0
        fi

        saystart "Scanning ${#files[@]} file(s)..."
        
        total="${#files[@]}"
        current=0

        for file in "${files[@]}"; do
            current=$((current + 1))


            _scan_file "$file" || {
               sayprogress_done
               sayfail "Failed to scan file: $file"
               return 0
            }

            sayprogress \
                --current "$current" \
                --total "$total" \
                --label "Processing file: $(basename "$file")" \
                --type 5 \
                --padleft 4
        done
        sayprogress_done

        sayok "Scanned $total file(s)"
        sayinfo "Collected $(sgnd_dt_row_count DOC_MODULES) module row(s)"
        sayinfo "Collected $(sgnd_dt_row_count DOC_FUNCTIONS) function row(s)"

        return 0
    }

    # fn: _scan_file
        # Purpose:
        #   Scan one source file line by line and store normalized structural
        #   records in the documentation scan table.
        #
        # Behavior:
        #   - Detects the canonical top-of-file header between the first two
        #     header separator lines and stores one row per inner header line.
        #   - Detects section marker lines in three levels:
        #       # --- major
        #       # --  minor
        #       # -   micro
        #   - Detects explicit detail comment blocks:
        #       # fn: <name>
        #       # var: <name>
        #   - Collects subsequent comment lines as detail text.
        #   - Confirms a detail block only when a matching declaration line is found:
        #       fn  -> <name>() {
        #       var -> <name>=...
        #   - Discards pending detail blocks that are interrupted by unrelated code
        #     or a new structural marker.
        #
        # Arguments:
        #   $1  FILE
        #       Readable source file to scan.
        #
        # Inputs (globals):
        #   DOC_SCAN_SCHEMA
        #   DOC_SCAN_ROWS
        #
        # Returns:
        #   0 on success.
        #   1 on invalid input or append failure.
    _scan_file() {
        local file="${1:?missing file}"
        local line=""
        local line_nr=0
        local text=""

        local in_header=0
        local header_done=0
        local header_sep_count=0
        local current_header_section=""

        local current_major_section=""
        local current_minor_section=""
        local current_micro_section=""

        local pending_kind=""
        local pending_name=""
        local pending_major_section=""
        local pending_minor_section=""
        local pending_micro_section=""
        local pending_count=0
        local -a pending_lines=()
        local -a pending_line_nrs=()

        local i=0

        [[ -r "$file" ]] || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            line_nr=$((line_nr + 1))
            line="${line%$'\r'}"

            # --- Header ---------------------------------------------------------
            if (( ! header_done )); then
                if _is_header_separator "$line"; then
                    header_sep_count=$((header_sep_count + 1))

                    if (( header_sep_count == 1 )); then
                        in_header=1
                        current_header_section=""
                        continue
                    fi

                    if (( header_sep_count == 2 )); then
                        in_header=0
                        header_done=1
                        current_header_section=""
                        continue
                    fi
                fi

                if (( in_header )); then
                    if _is_header_section_line "$line"; then
                        current_header_section="$(_parse_header_section_line "$line")"

                        sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                            "$file" \
                            "$line_nr" \
                            "headersection" \
                            "$current_header_section" \
                            "" \
                            "$current_header_section" || return 1
                    else
                        text="$(_normalize_comment_line "$line")"

                        sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                            "$file" \
                            "$line_nr" \
                            "headerline" \
                            "" \
                            "$current_header_section" \
                            "$text" || return 1
                    fi

                    continue
                fi
            fi

            # --- Section markers ------------------------------------------------
            if _is_section_line "$line"; then
                text="$(_parse_section_line "$line")"

                case "$(_get_section_level "$line")" in
                    1)
                        current_major_section="$text"
                        current_minor_section=""
                        current_micro_section=""
                        ;;
                    2)
                        current_minor_section="$text"
                        current_micro_section=""
                        ;;
                    3)
                        current_micro_section="$text"
                        ;;
                esac

                sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                    "$file" \
                    "$line_nr" \
                    "section" \
                    "$text" \
                    "$current_major_section" \
                    "$text" || return 1

                pending_kind=""
                pending_name=""
                pending_count=0
                pending_lines=()
                pending_line_nrs=()
                continue
            fi

            # --- Start detail block --------------------------------------------
            if (( pending_count == 0 )) && _is_detail_comment_start "$line"; then
                pending_kind="$(_parse_detail_kind "$line")"
                pending_name="$(_parse_detail_name "$line")"
                pending_major_section="$current_major_section"
                pending_minor_section="$current_minor_section"
                pending_micro_section="$current_micro_section"

                pending_count=0
                pending_lines=()
                pending_line_nrs=()

                pending_lines[pending_count]="$line"
                pending_line_nrs[pending_count]="$line_nr"
                pending_count=$((pending_count + 1))

                saydebug "PENDING START: $pending_kind : $pending_name @ $line_nr"
                continue
            fi

            # --- Continue / confirm / discard detail block ----------------------
            if (( pending_count > 0 )); then
                if [[ "$line" =~ ^[[:space:]]*# ]]; then
                    pending_lines[pending_count]="$line"
                    pending_line_nrs[pending_count]="$line_nr"
                    pending_count=$((pending_count + 1))
                    saydebug "PENDING ADD: $pending_kind : $pending_name @ $line_nr :: $line"
                    continue
                fi

                if _detail_matches_declaration "$pending_kind" "$pending_name" "$line"; then
                    for (( i=0; i<pending_count; i++ )); do
                        text="$(_normalize_comment_line "${pending_lines[i]}")"

                        sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                            "$file" \
                            "${pending_line_nrs[i]}" \
                            "$pending_kind" \
                            "$pending_name" \
                            "$pending_major_section" \
                            "$text" || return 1
                    done
                fi

                pending_kind=""
                pending_name=""
                pending_count=0
                pending_lines=()
                pending_line_nrs=()
            fi
        done < "$file"

        return 0
    }
    
# --- Main ----------------------------------------------------------------------------
    # fn: main
        # Purpose:
        #   Canonical entry point for executable scripts.
        #
        # Behavior:
        #   - Loads the framework bootstrapper.
        #   - Initializes runtime via sgnd_bootstrap.
        #   - Handles built-in framework arguments.
        #   - Prepares UI state (runmode + title bar).
        #   - Executes script-specific logic.
        #
        # Arguments:
        #   $@  Command-line arguments (framework + script-specific).
        #
        # Returns:
        #   Exits with the resulting status code from bootstrap or script logic.
        #
        # Usage:
        #   main "$@"
        #
        # Examples:
        #   # Standard script entrypoint
        #   main "$@"
        #
        # Notes:
        #   - sgnd_bootstrap splits framework and script arguments automatically..
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
            _resolve_parameters || exit $?
           _process_files || exit $?

           sgnd_dt_print_table "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS
            printf "\n\n"   

           #sgnd_dt_display "${DOC_MODULE_SCHEMA}" "${DOC_MODULES}"
           #sgnd_dt_display "${DOC_FUNCTION_SCHEMA}" "${DOC_FUNCTIONS}"
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
