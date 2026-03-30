#!/usr/bin/env bash
# ==================================================================================
# SolidgroundUX — Framework smoke tester
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : 4da5ec140b7c8f8edd2b4c7fa71b64ecd4e312aa2bfc8742d55afc82becc77a9
#   Source      : framework-smoketest.sh
#   Type        : script
#   Purpose     : Exercise and validate core SolidgroundUX framework functionality
#
# Description:
#   Standalone executable test harness for verifying foundational framework behavior.
#
#   The script:
#     - Locates and loads the SolidgroundUX bootstrap configuration
#     - Loads the framework bootstrapper and common runtime services
#     - Exercises argument parsing, state, config, UI, and messaging behavior
#     - Provides manual test routines for ask-* interaction helpers
#     - Serves as a smoke test for framework integration during development
#
# Design principles:
#   - Executable scripts explicitly bootstrap and opt into framework features
#   - Libraries are sourced only and never auto-run
#   - Test flow should stay simple, visible, and easy to extend
#   - Framework integration issues should fail early and clearly
#
# Non-goals:
#   - Full automated regression testing
#   - Fine-grained unit isolation for every library function
#   - Replacement for dedicated shell test frameworks
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      :
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
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
        #   - SGND_FRAMEWORK_ROOT is treated as a filesystem root/prefix.
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local framework_root="/"
        local app_root="$framework_root"
        local reply=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
            [[ -n "$cfg_home" ]] || cfg_home="$HOME"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"

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
            if [[ -r /dev/tty && -w /dev/tty ]]; then
                sayinfo "SolidGroundUX bootstrap configuration"
                sayinfo "No configuration file found."
                sayinfo "Creating: $cfg"

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                framework_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [%s] : " "$framework_root" > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$framework_root}"
            fi

            # Validate paths (must be absolute)
            case "$framework_root" in
                /*) ;;
                *)
                    sayfail "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"
                    return 126
                    ;;
            esac

            case "$app_root" in
                /*) ;;
                *)
                    sayfail "ERR: SGND_APPLICATION_ROOT must be an absolute path"
                    return 126
                    ;;
            esac

            # Create bootstrap configuration file
            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$framework_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            saydebug "Created bootstrap cfg: $cfg"
        fi

        # Load configuration
        [[ -r "$cfg" ]] || {
            sayfail "Cannot read bootstrap cfg: $cfg"
            return 126
        }

        # shellcheck source=/dev/null
        source "$cfg"

        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

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
        #   - SGND_FRAMEWORK_ROOT is treated as a filesystem root/prefix.
    _load_bootstrapper() {
        local bootstrap=""

        _framework_locator || return $?

        bootstrap="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"

        [[ -r "$bootstrap" ]] || {
            printf "FATAL: Cannot read bootstrap: %s\n" "$bootstrap" >&2
            return 126
        }

        saydebug "Loading bootstrap: $bootstrap"

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
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_DESC="Canonical executable template for Testadura scripts"
    : "${SGND_SCRIPT_DESC:=Canonical executable template for Testadura scripts}"
    : "${SGND_SCRIPT_VERSION:=1.0}"
    : "${SGND_SCRIPT_BUILD:=20250110}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 Mark Fieten — Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.0}"

# --- Script metadata (framework integration) --------------------------------------
    # Libraries to source from SGND_COMMON_LIB
    SGND_USING=(
    )

    # SGND_ARGS_SPEC
        # --- Example: Arguments ----------------------------------------------
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
        "load|l|flag|FLAG_LOAD|Random argument for testing|"
        "unload|u|flag|FLAG_UNLOAD|Random argument for testing|"
        "exit|x|flag|FLAG_EXIT|Random argument for testing|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "$SGND_SCRIPT_NAME --load --verbose  #Some example usage"
    ) 
    
    SGND_SCRIPT_GLOBALS=(
        "system|SGND_SYS_STRING|System CFG string|"
        "system|SGND_SYS_INT|System CFG int|"
        "system|SGND_SYS_DATE|System CFG date|"

        "user|SGND_USR_STRING|User CFG string|"
        "user|SGND_USR_INT|User CFG int|"
        "user|SGND_USR_DATE|User  CFG date|"

        "both|SGND_COMMON_STRING|Common CFG string|"
        "both|SGND_COMMON_INT|Common CFG int|"
        "both|SGND_COMMON_DATE|Common  CFG date|"
    )

    : "${INP_NAME=}"
    : "${INP_STREET=}"
    : "${INP_ZIPCODE=}"
    : "${INP_CITY=}"
    : "${INP_COUNTRY=}"
    : "${INP_AGE=}"
     
    SGND_STATE_VARIABLES=(
        "INP_NAME|Name|Petrus Puk|"
        "INP_STREET|Address|Nowhere straat|"
        "INP_ZIPCODE|Postcode|5544 QU|"
        "INP_CITY|Stad||"
        "INP_COUNTRY|||"
        "INP_AGE|Leeftijd|102|sgnd_is_number"
    )

    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=1

# --- Local script Declarations ----------------------------------------------------
    : "${SGND_SYS_STRING:=system-default}"
    : "${SGND_SYS_INT:=0}"
    : "${SGND_SYS_DATE:=1970-01-01}"

    : "${SGND_USR_STRING:=user-default}"
    : "${SGND_USR_INT:=0}"
    : "${SGND_USR_DATE:=1970-01-01}"

    : "${SGND_COMMON_STRING:=common-default}"
    : "${SGND_COMMON_INT:=0}"
    : "${SGND_COMMON_DATE:=1970-01-01}"

    : "${STATE_VAR1:=State VAR1}"
    : "${STATE_VAR2:=4}"
    : "${STATE_VAR3:=2025-01-01}"
    
# --- Local script functions -------------------------------------------------------
    input_test() {
        ask_prompt_form --autoalign "${SGND_STATE_VARIABLES[@]}" 
    }

    ask_test(){
        # -----------------------------------------------------------------------------
        # 1. ask
        # -----------------------------------------------------------------------------
        printf "%s1. Testing ask()%s\n" "$CYAN" "$RESET"

        TEST_NAME=""
        ask \
            --label "Your name" \
            --default "Mark" \
            --validate sgnd_validate_text \
            --var TEST_NAME \
            --labelwidth 28 \
            --pad 2 \
            --labelclr "$CYAN" \
            --colorize both

        printf "Result: TEST_NAME='%s'\n\n" "$TEST_NAME"

        # -----------------------------------------------------------------------------
        # 2. ask_decision
        # -----------------------------------------------------------------------------
        printf "%s2. Testing ask_decision()%s\n" "$CYAN" "$RESET"

        TEST_DECISION=""
        ask_decision \
            --label "Proceed with operation?" \
            --choices "YES|Y,NO|N" \
            --default "YES" \
            --var TEST_DECISION \
            --labelwidth 28 \
            --pad 2 \
            --labelclr "$CYAN"

        printf "Result: TEST_DECISION='%s'\n\n" "$TEST_DECISION"

        # -----------------------------------------------------------------------------
        # 3. ask_dlg_autocontinue
        # -----------------------------------------------------------------------------
        printf "%s3. Testing ask_dlg_autocontinue()%s\n" "$CYAN" "$RESET"
        printf "Try Enter, R, C, P/Space, or do nothing and let it time out.\n\n"

        ask_dlg_autocontinue \
            --seconds 8 \
            --message "Auto-continue test" \
            --redo \
            --cancel \
            --pause

        TEST_RC=$?

        case "$TEST_RC" in
            0) printf "Result: continue\n\n" ;;
            1) printf "Result: timeout / auto-continue\n\n" ;;
            2) printf "Result: cancel\n\n" ;;
            3) printf "Result: redo\n\n" ;;
            *) printf "Result: unexpected rc=%s\n\n" "$TEST_RC" ;;
        esac

        # -----------------------------------------------------------------------------
        # 4. ask_choose
        # -----------------------------------------------------------------------------
        printf "%s4. Testing ask_choose()%s\n" "$CYAN" "$RESET"

        TEST_ENV=""
        ask_choose \
            --label "Environment" \
            --choices "dev,acc,prod" \
            --var TEST_ENV \
            --labelwidth 28 \
            --pad 2 \
            --labelclr "$CYAN"

        printf "Result: TEST_ENV='%s'\n\n" "$TEST_ENV"

        # -----------------------------------------------------------------------------
        # 5. ask_choose_immediate
        # -----------------------------------------------------------------------------
        printf "%s5. Testing ask_choose_immediate()%s\n" "$CYAN" "$RESET"
        printf "Instant choices: B,D,Q. Other values require Enter.\n\n"

        TEST_ACTION=""
        ask_choose_immediate \
            --label "Action" \
            --choices "1-5,B,D,Q" \
            --instantchoices "B,D,Q" \
            --var TEST_ACTION

        printf "Result: TEST_ACTION='%s'\n\n" "$TEST_ACTION"

        # -----------------------------------------------------------------------------
        # Optional: ask_prompt_form
        # -----------------------------------------------------------------------------
        # Uncomment this block if you want to test ask_prompt_form too.
        #
        # _ask_parse_fieldspec() {
        #     local spec="${1-}"
        #     IFS='|' read -r \
        #         _ask_field_key \
        #         _ask_field_label \
        #         _ask_field_default \
        #         _ask_field_validate \
        #         <<< "$spec"
        # }
        #
        # _ask_is_ident() {
        #     [[ "${1-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
        # }
        #
        # printf "%s6. Testing ask_prompt_form()%s\n" "$CYAN" "$RESET"
        #
        HOSTNAME=""
        PORT=""
        
        ask_prompt_form --autoalign --pad 2 --labelclr "$CYAN" -- \
             "HOSTNAME|Host name|localhost|sgnd_validate_text" \
             "PORT|Port|8080|sgnd_validate_text"
        #
        printf "Result: HOSTNAME='%s', PORT='%s'\n\n" "$HOSTNAME" "$PORT"

        printf "%sDone.%s\n" "$CYAN" "$RESET"
    }
        # -- Sample/demo renderers
    say_test(){
        sayinfo "Info message"
        saystart "Start message"
        saywarning "Warning message"
        sayfail "Failure message"
        saycancel "Cancellation message"
        sayok "All is well"
        sayend "Ended gracefully"
        saydebug "Debug message"
        justsay "Just saying"
    }
# --- Main -------------------------------------------------------------------------
    # main MUST BE LAST function in script
        # Main entry point for the executable script.
        #
        # Execution flow:
        #   1) Invoke sgnd_bootstrap to initialize the framework environment, parse
        #      framework-level arguments, and optionally load UI, state, and config.
        #   2) Abort immediately if bootstrap reports an error condition.
        #   3) Enact framework builtin arguments (help, showargs, state reset, etc.).
        #      Info-only builtins terminate execution; mutating builtins may continue.
        #   4) Continue with script-specific logic.
        #
        # Bootstrap options:
        #   The script author explicitly selects which framework features to enable.
        #   None are required; include only what this script needs.
        #
        #   --state        Enable persistent state loading/saving.
        #   --needroot     Require execution as root.
        #   --cannotroot   Require execution as non-root.
        #   --log          Enable logging to file.
        #   --console      Enable logging to console output.
        #   --             End of bootstrap options; remaining args are script arguments.
        # Notes:
        #   - Builtin argument handling is centralized in sgnd_builtinarg_handler.
        #   - Scripts may override builtin handling, but doing so transfers
        #     responsibility for correct behavior to the script author.
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
            sgnd_bootstrap -- "$@"
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
            local choice

            while true; do
                printf "\n"
                printf "=========================================\n"
                printf " SolidGroundUX — Framework Unit Test Menu\n"
                printf "=========================================\n"
                printf " 1) Ask tests\n"
                printf " 2) Input test\n"
                printf " 3) Say test\n"
                printf " q) Quit\n"
                printf "-----------------------------------------\n"
                printf "Select option: "

                # Read single key (no Enter required)
                read -r -n1 choice
                printf "\n"

                case "${choice,,}" in
                    1)
                        ask_test
                        ;;
                    2)
                        input_test
                        ;;
                    3)
                        say_test
                        ;;
                    q)
                        printf "Exiting...\n"
                        break
                        ;;
                    *)
                        printf "Invalid option: %s\n" "$choice"
                        ;;
                esac
            done
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
