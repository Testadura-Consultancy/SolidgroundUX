#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Documentation Generator Script
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : none
#   Source      : doc-generator.sh
#   Type        : script
#   Group       : Developer tools
#   Purpose     : Collect and prepare documentation data from source files using the
#                 SolidGroundUX framework.
#
# Description:
#   Provides the executable entry point for documentation data collection.
#
#   The script:
#     - Bootstraps the SolidGroundUX runtime
#     - Resolves source and output parameters from arguments, state, or user input
#     - Collects normalized documentation data from matching source files
#     - Prepares the basis for later rendering stages
#
# Design principles:
#   - Collection logic is kept separate from rendering logic
#   - Script behavior is deterministic and state-aware
#   - Framework conventions are reused wherever possible
#   - Interactive prompting remains optional rather than mandatory
#
# Role in framework:
#   - Executable entry point for documentation collection workflows
#   - Demonstrates canonical integration with sgnd-bootstrap and common libraries
#   - Bridges bootstrap, state, argument parsing, and collector execution
#
# Non-goals:
#   - Rendering Markdown or HTML directly
#   - Parsing arbitrary free-form comments outside framework conventions
#   - Replacing the lower-level parser libraries
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
    # tmp: _framework_locator
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

    # tmp: _load_bootstrapper
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
    # SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
        #
        # Example:
        #   SGND_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    SGND_USING=(
            sgnd-comment-parser.sh
            sgnd-doc-collector.sh
    )

    # SGND_ARGS_SPEC 
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
    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO_RUN|Automatically run with last used or default parameters|0|"
        "clean|c|flag|FLAG_CLEAN_OUTPUT|Clear output directory before writing|0|"
        "file|f|value|VAL_FILESPEC|File mask for source scanning||"
        "outdir|o|value|VAL_OUTDIR|Output directory for generated docs||"
        "recursive|r|flag|FLAG_RECURSIVE_SCAN|Recursively scan source directory|1|"
        "srcdir|s|value|VAL_SRCDIR|Source directory to scan||"
        "viewresults|v|flag|FLAG_VIEW_RESULTS|Automatically open generated docs in browser after generation (desktop mode only)|0|"
    )

    # SGND_SCRIPT_EXAMPLES
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

    # SGND_SCRIPT_GLOBALS
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

    # SGND_STATE_VARIABLES
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
            "VAL_SRCDIR|Source Directory||"
            "VAL_FILESPEC|Filename mask||"
            "VAL_OUTDIR|Output Directory||"
            "FLAG_RECURSIVE_SCAN|Recursive Scan||"
            "FLAG_CLEAN_OUTPUT|Clean Output Directory||"
            "FLAG_VIEW_RESULTS|Automatically open generated docs in browser after generation (desktop mode only)||"
        )

    # SGND_ON_EXIT_HANDLERS
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
    # -- Datamodel
    MODULE_META_SCHEMA="file|product|title|type|group|purpose"
    MODULE_META=()

    MODULE_INFO_SCHEMA="file|version|build|checksum|developers|company|client|copyright|license"
    MODULE_INFO=()

    SOURCE_SECTIONS_SCHEMA="file|parent|section|comments"
    SOURCE_SECTIONS=()

    MODULE_HEADER_SCHEMA="file|linenr|section|paragraph|content"
    MODULE_HEADER=()
    
    MODULE_ITEMS_SCHEMA="file|linenr|access|type|section|paragraph|name|content"
    MODULE_ITEMS=()

# --- Local script functions ----------------------------------------------------------
    # fn: _init_parameters
        # Purpose:
        #   Initialize parameter variables from defaults when still unset.
        #
        # Behavior:
        #   - Preserves values already supplied through parsed arguments or restored state.
        #   - Applies default values only where variables are unset or empty.
        #   - Does not validate or interpret parameter values.
        #   - Does not override explicit user input.
        #   - Does not perform interactive prompting.
        #
        # Usage:
        #   _init_parameters
        #
        # Examples:
        #   _init_parameters
    _init_parameters() {
        sgnd_internal_call_guard "_init_parameters"
        saydebug "Initializing parameters with defaults where not set by arguments"

        FLAG_AUTO_RUN="${FLAG_AUTO_RUN:-0}"
        FLAG_CLEAN_OUTPUT="${FLAG_CLEAN_OUTPUT:-1}"
        VAL_FILESPEC="${VAL_FILESPEC:-*.sh}"
        VAL_OUTDIR="${VAL_OUTDIR:-$SGND_DOCS_DIR}"
        FLAG_RECURSIVE_SCAN="${FLAG_RECURSIVE_SCAN:-1}"
        VAL_SRCDIR="${VAL_SRCDIR:-$SGND_APPLICATION_ROOT}"
        FLAG_VIEW_RESULTS="${FLAG_VIEW_RESULTS:-1}"
    }

        # fn: _get_userinput
        # Purpose:
        #   Interactively collect and confirm documentation generator parameters.
        #
        # Behavior:
        #   - Displays grouped prompts for source, destination, and behavioral flags.
        #   - Applies validation to supported fields.
        #   - Normalizes Y/N replies into numeric flag values.
        #   - Repeats until the user confirms, cancels, or requests redo.
        #
        # Outputs (globals):
        #   VAL_SRCDIR
        #   VAL_FILESPEC
        #   VAL_OUTDIR
        #   FLAG_CLEAN_OUTPUT
        #   FLAG_RECURSIVE_SCAN
        #   FLAG_VIEW_RESULTS
        #   SGND_STATE_SAVE
        #
        # Returns:
        #   0 on confirmed input.
        #   1 if the user cancels or an unexpected dialog result occurs.
        #
        # Usage:
        #   _get_userinput || return $?
        #
        # Examples:
        #   _get_userinput
    _get_userinput() {
        local lw=25
        local lp=4
        local default="N"
        local reply
    
        while true; do
            sgnd_print
            sgnd_print_sectionheader "Source and destination" --padend 0

            # Basic parameters
            ask --label "Source directory" \
                --var VAL_SRCDIR \
                --default "$VAL_SRCDIR" \
                --validate sgnd_validate_dir_exists \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Source file" \
                --var VAL_FILESPEC \
                --default "$VAL_FILESPEC" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Output directory" \
                --var VAL_OUTDIR \
                --default "$VAL_OUTDIR" \
                --validate sgnd_validate_dir_exists \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            
            sgnd_print
            sgnd_print_sectionheader "Behavioral flags" --padend 0
            lw=45
            (( ${FLAG_CLEAN_OUTPUT:-0} )) && default="Y" || default="N"
            ask --label "Clean output directory before writing (Y/N)" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_CLEAN_OUTPUT=1 || FLAG_CLEAN_OUTPUT=0

            (( ${FLAG_RECURSIVE_SCAN:-0} )) && default="Y" || default="N"
            ask --label "Scan recursively" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_RECURSIVE_SCAN=1 || FLAG_RECURSIVE_SCAN=0
        
            (( ${FLAG_VIEW_RESULTS:-0} )) && default="Y" || default="N"
            ask --label "View results after generation" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_VIEW_RESULTS=1 || FLAG_VIEW_RESULTS=0

            (( ${SGND_STATE_SAVE:-0} )) && default="Y" || default="N"
            ask --label "Save state variables" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && SGND_STATE_SAVE=1 || SGND_STATE_SAVE=0

            # Confirmation
            sgnd_print_sectionheader --maxwidth "$(( lw + 5 ))"
            sgnd_print
            ask_dlg_autocontinue --seconds 15 --message "Continue with these settings?" --redo --cancel --pause

            case $? in
                0|1) break ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                3) continue ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac

            sgnd_showenvironment
        done
    }
# --- Main ----------------------------------------------------------------------------
    # fn: main
        # Purpose:
        #   Provide the canonical executable entry point for the documentation generator.
        #
        # Behavior:
        #   - Loads the framework bootstrapper.
        #   - Initializes the runtime through sgnd_bootstrap.
        #   - Processes built-in framework arguments.
        #   - Prepares UI state and title bar output.
        #   - Initializes script parameters from defaults, state, and arguments.
        #   - Prompts for interactive input when auto-run is not enabled.
        #   - Hands off control to the script's main logic.
        #
        # Arguments:
        #   $@  Command-line arguments (framework and script-specific).
        #
        # Returns:
        #   0  on success.
        #   Non-zero on bootstrap, input, or script failure.
        #
        # Usage:
        #   main "$@"
        #
        # Examples:
        #   main "$@"
        #
        # Notes:
        #   - sgnd_bootstrap separates framework arguments from script arguments.
        #   - This function is script-owned orchestration logic, not template-only scaffolding.
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
            sgnd_bootstrap --autostate -- "$@"
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
        _init_parameters

        if (( !FLAG_AUTO_RUN )); then
            # Prompt for user input if not auto-running        
            _get_userinput || return $?
        fi
    
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
