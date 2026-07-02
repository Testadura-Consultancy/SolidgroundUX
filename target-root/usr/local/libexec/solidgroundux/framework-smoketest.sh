#!/usr/bin/env bash
# ==================================================================================
# SolidGroundUX - Framework smoke tester
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2617512
#   Checksum    : f2a25ebaaa9cc622ba3c067ceedb17eac45296e00edfa5583ca3a3dd297290d0
#   Source      : framework-smoketest.sh
#   Type        : script
#   Purpose     : Exercise and validate core SolidGroundUX framework functionality
#
# Description:
#   Standalone executable test harness for verifying foundational framework behavior.
#
#   The script:
#     - Locates and loads the SolidGroundUX bootstrap configuration
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
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# --- Bootstrap ----------------------------------------------------------------------
    # fn: _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Purpose
        #   Locate, create, and load the SolidGroundUX bootstrap configuration, then
        #   load the executable runtime support library.
        #
        # . Behavior
        #   - Searches user and system bootstrap configuration locations.
        #   - Prefers the invoking user's config over the system config.
        #   - Creates a new bootstrap config when none exists.
        #   - Prompts for framework/application roots in interactive mode.
        #   - Applies default values when running non-interactively.
        #   - Sources the selected bootstrap configuration file.
        #   - Loads sgnd-exe-common.sh from the resolved framework root.
        #
        # . Globals (write)
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # . Output
        #   Writes primitive printf-based messages before the framework UI is available.
        #
        # . Returns
        #   0 when the bootstrap configuration and executable common library were loaded.
        #   126 when configuration or executable common library is unreadable or invalid.
        #   127 when the configuration directory or file could not be created.
        #
        # . Usage
        #   _framework_locator || return $?
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
        #   - This function intentionally uses printf rather than say* helpers because
        #     the executable common library has not been loaded yet.
    _framework_locator() {
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply=""

        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"

        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"

        else
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            if [[ -t 0 && -t 1 ]]; then
                printf '%s\n' "SolidGroundUX bootstrap configuration" >&2
                printf '%s\n' "No configuration file found." >&2
                printf '%s\n' "Creating: $cfg" >&2

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_FRAMEWORK_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_APPLICATION_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            printf '%s\n' "Created bootstrap cfg: $cfg" >&2
        fi

        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"

            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            printf '%s\n' "Cannot read bootstrap cfg: $cfg" >&2
            return 126
        fi

        case "${SGND_LOG_LEVEL:-silent}" in
            silent|quiet)
                ;;
            *)
                printf '%s\n' "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT" >&2
                ;;
        esac

        local exe_common=""

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        fi

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# --- Script metadata (identity) ---------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_DESC="Canonical executable template for Testadura scripts"
    SGND_LOG_LEVEL="${SGND_LOG_LEVEL:-silent}"
    : "${SGND_SCRIPT_DESC:=Canonical executable template for Testadura scripts}"
    : "${SGND_SCRIPT_VERSION:=1.0}"
    : "${SGND_SCRIPT_BUILD:=20250110}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

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
        # var: = shell variable that will be set
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
    # fn: input_test - Run simple shell input tests
        # . Purpose
        #   Run simple shell input tests.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   input_test
    input_test() {
        ask_prompt_form --autoalign "${SGND_STATE_VARIABLES[@]}" 
    }

    # fn: ask_test - Run interactive ask helper tests
        # . Purpose
        #   Run interactive ask helper tests.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   ask_test
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
    # fn: say_test - Run console message helper tests
        # . Purpose
        #   Run console message helper tests.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   say_test
    say_test(){
        local original_loglevel="${SGND_LOG_LEVEL:-silent}"
        SGND_LOG_LEVEL="trace"
        sayinfo "Info message"
        saystart "Start message"
        saywarning "Warning message"
        sayfail "Failure message"
        saycancel "Cancellation message"
        sayok "All is well"
        sayend "Ended gracefully"
        saydebug "Debug message"
        justsay "Just saying"
        SGND_LOG_LEVEL="$original_loglevel"
    }

    # fn: loglevel_test - Run console message visibility tests for every log level
        # . Purpose
        #   Cycle through all supported SGND_LOG_LEVEL values and emit one test message
        #   for each message type.
        #
        # . Behavior
        #   - Public smoke-test entry point.
        #   - Temporarily sets SGND_LOG_LEVEL to off, quiet, normal, and debug.
        #   - Emits INFO, STRT, WARN, FAIL, CNCL, OK, END, DEBUG, and EMPTY messages
        #     for each level so console filtering can be inspected visually.
        #   - Restores the original SGND_LOG_LEVEL before returning.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   loglevel_test
    loglevel_test() {
        local original_loglevel="${SGND_LOG_LEVEL:-silent}"
        local level=""

        for level in silent quiet normal verbose debug trace; do
            SGND_LOG_LEVEL="$level"

            printf '\n'
            printf '%s\n' '-----------------------------------------'
            printf 'SGND_LOG_LEVEL=%s\n' "$SGND_LOG_LEVEL"
            printf '%s\n' 'Expected visible message types depend on _say_should_print_console.'
            printf '%s\n' '-----------------------------------------'

            sayinfo "INFO message at loglevel=$SGND_LOG_LEVEL"
            saystart "STRT message at loglevel=$SGND_LOG_LEVEL"
            saywarning "WARN message at loglevel=$SGND_LOG_LEVEL"
            sayfail "FAIL message at loglevel=$SGND_LOG_LEVEL"
            saycancel "CNCL message at loglevel=$SGND_LOG_LEVEL"
            sayok "OK message at loglevel=$SGND_LOG_LEVEL"
            sayend "END message at loglevel=$SGND_LOG_LEVEL"
            saydebug "DEBUG message at loglevel=$SGND_LOG_LEVEL"
            say EMPTY "EMPTY message at loglevel=$SGND_LOG_LEVEL"

            justsay "Just saying at loglevel=$SGND_LOG_LEVEL"
        done

        SGND_LOG_LEVEL="$original_loglevel"

        printf '\n'
        printf 'Restored SGND_LOG_LEVEL=%s\n' "$SGND_LOG_LEVEL"
    }

    motd_test() {
        bash ~/dev/SolidgroundUX/target-root/etc/update-motd.d/90-solidgroundux
    }


    # fn: sayprogress_test - Run transient progress line tests
        # . Purpose
        #   Exercise sayprogress with one, two, and three reserved progress slots.
        #
        # . Behavior
        #   - Runs three visual progress scenarios after each other.
        #   - Stage 1 uses one progress level: 1..500.
        #   - Stage 2 uses two progress levels: outer 1..500, inner 1..150.
        #   - Stage 3 uses three progress levels: outer 1..500, middle 1..150,
        #     inner 1..80.
        #   - Uses explicit slots so stacked progress rendering can be inspected.
        #
        # . Returns
        #   0 when the visual test sequence completes.
        #
        # . Usage
        #   sayprogress_test
    sayprogress_test() {
        local outer=0
        local middle=0
        local inner=0
        local outer_total=1000
        local middle_total=250
        local inner_total=275

        printf '\n'
        saystart "Progress test 1/3: single level"

        sayprogress_begin --slots 1
        for (( outer = 1; outer <= outer_total; outer++ )); do
            sayprogress \
                --slot 0 \
                --current "$outer" \
                --total "$outer_total" \
                --label "Stage 1: single level $outer/$outer_total" \
                --type 7 \
                --padleft 0

            (( outer % 5 == 0 )) && sleep 0.01
        done
        sayprogress_done
        sayok "Progress test 1/3 complete"

        printf '\n'
        saystart "Progress test 2/3: double level"

        sayprogress_begin --slots 2
        for (( outer = 1; outer <= outer_total; outer++ )); do
            sayprogress \
                --slot 0 \
                --current "$outer" \
                --total "$outer_total" \
                --label "Stage 2 outer: $outer/$outer_total" \
                --type 7 \
                --padleft 0

            middle=$(( ((outer - 1) % middle_total) + 1 ))
            sayprogress \
                --slot 1 \
                --current "$middle" \
                --total "$middle_total" \
                --label "Stage 2 inner: $middle/$middle_total" \
                --type 7 \
                --padleft 2

            (( outer % 5 == 0 )) && sleep 0.01
        done
        sayprogress_done
        sayok "Progress test 2/3 complete"

        printf '\n'
        saystart "Progress test 3/3: triple level"

        sayprogress_begin --slots 3
        for (( outer = 1; outer <= outer_total; outer++ )); do
            sayprogress \
                --slot 0 \
                --current "$outer" \
                --total "$outer_total" \
                --label "Stage 3 outer: $outer/$outer_total" \
                --type 7 \
                --padleft 0

            middle=$(( ((outer - 1) % middle_total) + 1 ))
            sayprogress \
                --slot 1 \
                --current "$middle" \
                --total "$middle_total" \
                --label "Stage 3 middle: $middle/$middle_total" \
                --type 7 \
                --padleft 2

            inner=$(( ((outer - 1) % inner_total) + 1 ))
            sayprogress \
                --slot 2 \
                --current "$inner" \
                --total "$inner_total" \
                --label "Stage 3 inner: $inner/$inner_total" \
                --type 7 \
                --padleft 4

            (( outer % 5 == 0 )) && sleep 0.01
        done
        sayprogress_done
        sayok "Progress test 3/3 complete"
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
    # fn: main - Run the executable main sequence
        # . Purpose
        #   Run the executable main sequence.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   main
    main() {
        # -- Startup
            _framework_locator || exit $?
            sgnd_exe_start -- "$@"

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
                printf " 4) Log level visibility test\n"
                printf " 5) Call motd\n"
                printf " 6) Progress dialogue test\n"
                printf " q) Quit\n"
                printf '%s\n' '-----------------------------------------'
                printf "Select option: "

                choice=""

                for seconds_left in {30..1}; do
                    printf "\rSelect option (auto-exit in %2ss): " "$seconds_left"

                    if read -r -s -n1 -t 1 choice; then
                        break
                    fi
                done

                printf "\n"

                if [[ -z "$choice" ]]; then
                    printf "No selection made. Exiting...\n"
                    break
                fi

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
                    4)
                        loglevel_test
                        ;;
                    5)
                        motd_test
                        ;;
                    6)
                        sayprogress_test
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
