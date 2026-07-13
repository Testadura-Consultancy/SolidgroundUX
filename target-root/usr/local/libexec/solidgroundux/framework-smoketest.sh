#!/usr/bin/env bash
# ==================================================================================
# SolidGroundUX - Framework smoke tester
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2619012
#   Checksum    : 741e028bb77eab903c85a785fd5968c780dcebd17c1f544a6c94c218f274a959
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

        case "${SGND_CONSOLE_LOG_LEVEL:-silent}" in
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
    SGND_CONSOLE_LOG_LEVEL="${SGND_CONSOLE_LOG_LEVEL:-silent}"
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
        "view-log||flag|FLAG_VIEW_LOG|Display the active SolidGroundUX logfile and exit|"
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
        sgnd_print
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
        sgnd_print
        # -----------------------------------------------------------------------------
        # 1. ask
        # -----------------------------------------------------------------------------
        sgnd_print " 1. Testing ask()"

        TEST_NAME=""
        ask \
            --label "Your name" \
            --default "Mark" \
            --validate sgnd_validate_text \
            --var TEST_NAME \
            --labelwidth 28 \
            --pad 2 \
            --colorize both

        sgnd_print "Result: TEST_NAME=$TEST_NAME"

        # -----------------------------------------------------------------------------
        # 2. ask_decision
        # -----------------------------------------------------------------------------
        sgnd_print " 2. Testing ask_decision()"

        TEST_DECISION=""
        ask_decision \
            --label "Proceed with operation?" \
            --choices "YES|Y,NO|N" \
            --default "YES" \
            --var TEST_DECISION \
            --labelwidth 28 \
            --pad 2 

        sgnd_print "Result: TEST_DECISION='$TEST_DECISION'"

        # -----------------------------------------------------------------------------
        # 3. ask_dlg_autocontinue
        # -----------------------------------------------------------------------------
        sgnd_print " 3. Testing ask_dlg_autocontinue()"
        sgnd_print "Try Enter, R, C, P/Space, or do nothing and let it time out.\n"

        ask_dlg_autocontinue \
            --seconds 8 \
            --message "Auto-continue test" \
            --redo \
            --cancel \
            --pause

        TEST_RC=$?

        case "$TEST_RC" in
            0) sgnd_print "Result: continue\n\n" ;;
            1) sgnd_print "Result: timeout / auto-continue\n\n" ;;
            2) sgnd_print "Result: cancel\n\n" ;;
            3) sgnd_print "Result: redo\n\n" ;;
            *) sgnd_print "Result: unexpected rc=%s\n\n" "$TEST_RC" ;;
        esac

        # -----------------------------------------------------------------------------
        # 4. ask_choose
        # -----------------------------------------------------------------------------
        sgnd_print " 4. Testing ask_choose()"

        TEST_ENV=""
        ask_choose \
            --label "Environment" \
            --choices "dev,acc,prod" \
            --var TEST_ENV \
            --labelwidth 28 \
            --pad 2 

        sgnd_print "Result: TEST_ENV='$TEST_ENV'"

        # -----------------------------------------------------------------------------
        # 5. ask_choose_immediate
        # -----------------------------------------------------------------------------
        sgnd_print " 5. Testing ask_choose_immediate()"
        sgnd_print "Instant choices: B,D,Q. Other values require Enter.\n"

        TEST_ACTION=""
        ask_choose_immediate \
            --label "Action" \
            --choices "1-5,B,D,Q" \
            --instantchoices "B,D,Q" \
            --var TEST_ACTION

        sgnd_print "Result: TEST_ACTION='$TEST_ACTION'"

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
        # sgnd_print " 6. Testing ask_prompt_form()"
        #
        HOSTNAME=""
        PORT=""
        
        ask_prompt_form --autoalign --pad 2 -- \
             "HOSTNAME|Host name|localhost|sgnd_validate_text" \
             "PORT|Port|8080|sgnd_validate_text"
        #
        sgnd_print "Result: HOSTNAME='$HOSTNAME', PORT='$PORT'\n"

        sgnd_print "Done.\n"
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
        sgnd_print
        sgnd_print_sectionheader --text "Testing say*() helpers"

        local original_loglevel="${SGND_CONSOLE_LOG_LEVEL:-silent}"
        SGND_CONSOLE_LOG_LEVEL="trace"
        sayinfo "Info message"
        saystart "Start message"
        saywarning "Warning message"
        sayfail "Failure message"
        saycancel "Cancellation message"
        sayok "All is well"
        sayend "Ended gracefully"
        saydebug "Debug message"
        justsay "Just saying"
        SGND_CONSOLE_LOG_LEVEL="$original_loglevel"
    }

    # fn: loglevel_test - Run console message visibility tests for every log level
        # . Purpose
        #   Cycle through all supported SGND_CONSOLE_LOG_LEVEL values and emit one test message
        #   for each message type.
        #
        # . Behavior
        #   - Public smoke-test entry point.
        #   - Temporarily sets SGND_CONSOLE_LOG_LEVEL to off, quiet, normal, and debug.
        #   - Emits INFO, STRT, WARN, FAIL, CNCL, OK, END, DEBUG, and EMPTY messages
        #     for each level so console filtering can be inspected visually.
        #   - Restores the original SGND_CONSOLE_LOG_LEVEL before returning.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   loglevel_test
    loglevel_test() {
        sgnd_print
        sgnd_print_sectionheader --text "Testing loglevel visibility"
        local original_loglevel="${SGND_CONSOLE_LOG_LEVEL:-silent}"
        local level=""

        for level in silent quiet normal verbose debug trace; do
            SGND_CONSOLE_LOG_LEVEL="$level"

            printf '\n'
            printf '%s\n' '-----------------------------------------'
            printf 'SGND_CONSOLE_LOG_LEVEL=%s\n' "$SGND_CONSOLE_LOG_LEVEL"
            printf '%s\n' 'Expected visible message types depend on _say_should_print_console.'
            printf '%s\n' '-----------------------------------------'

            sayinfo "INFO message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saystart "STRT message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saywarning "WARN message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            sayfail "FAIL message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saycancel "CNCL message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            sayok "OK message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            sayend "END message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saydebug "DEBUG message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            say EMPTY "EMPTY message at loglevel=$SGND_CONSOLE_LOG_LEVEL"

            justsay "Just saying at loglevel=$SGND_CONSOLE_LOG_LEVEL"
        done

        SGND_CONSOLE_LOG_LEVEL="$original_loglevel"

        printf '\n'
        printf 'Restored SGND_CONSOLE_LOG_LEVEL=%s\n' "$SGND_CONSOLE_LOG_LEVEL"
    }

    # fn: file_loglevel_test - Run file logging tests for every log level
        # . Purpose
        #   Verify file logging and file-level filtering independently from console output.
        #
        # . Behavior
        #   - Resolves and displays the active logfile path.
        #   - Cycles through every supported SGND_FILE_LOG_LEVEL value.
        #   - Writes representative messages for each level so filtering can be inspected.
        #   - Finishes with SGND_FILE_LOG_LEVEL set to silent.
        #   - Saves the final silent setting in the framework state file when available.
        #
        # Outputs (globals):
        #   SGND_FILE_LOG_LEVEL
        #
        # Side effects:
        #   Appends test records to the active SolidGroundUX logfile.
        #   Updates SGND_FRAMEWORK_STATEFILE when framework state is available.
        #
        # . Returns
        #   0 when the test sequence completes.
        #   1 when no logfile can be resolved or the final state cannot be saved.
        #
        # . Usage
        #   file_loglevel_test
    file_loglevel_test() {
        local logfile=""
        local level=""

        logfile="$(_sgnd_logfile)" || {
            saywarning "Unable to resolve the active logfile"
            return 1
        }

        [[ -n "$logfile" ]] || {
            saywarning "No active logfile is available"
            return 1
        }

        sgnd_print
        sgnd_print_sectionheader --text "Testing file log levels"
        sgnd_print_labeledvalue --label "Logfile" --value "$logfile"

        for level in silent quiet normal verbose debug trace; do
            SGND_FILE_LOG_LEVEL="$level"
            printf 'Testing SGND_FILE_LOG_LEVEL=%s\n' "$level"

            case "$level" in
                silent)
                    sayfail "FILELOG silent: this line must not be written"
                    ;;
                quiet)
                    saywarning "FILELOG quiet: warning should be written"
                    sayinfo "FILELOG quiet: info must not be written"
                    ;;
                normal)
                    saystart "FILELOG normal: start should be written"
                    sayinfo "FILELOG normal: info must not be written"
                    ;;
                verbose)
                    sayinfo "FILELOG verbose: info should be written"
                    saydebug "FILELOG verbose: debug must not be written"
                    ;;
                debug)
                    saydebug "FILELOG debug: debug should be written"
                    say --type TRACE "FILELOG debug: trace must not be written"
                    ;;
                trace)
                    say --type TRACE "FILELOG trace: trace should be written"
                    ;;
            esac
        done

        SGND_FILE_LOG_LEVEL="silent"

        if [[ -n "${SGND_FRAMEWORK_STATEFILE:-}" ]]; then
            sgnd_state_set \
                --file "$SGND_FRAMEWORK_STATEFILE" \
                SGND_FILE_LOG_LEVEL \
                "$SGND_FILE_LOG_LEVEL" || return 1
        fi

        printf 'Finished with SGND_FILE_LOG_LEVEL=%s\n' "$SGND_FILE_LOG_LEVEL"
        return 0
    }

    # fn: view_log - Display the active SolidGroundUX logfile
        # . Purpose
        #   Display the logfile selected by the current SolidGroundUX logging configuration.
        #
        # . Behavior
        #   - Uses the same logfile resolver as say().
        #   - Displays the resolved path before showing the file contents.
        #   - Reports an empty or unavailable logfile without failing unexpectedly.
        #
        # . Returns
        #   0 when the logfile is displayed.
        #   1 when no readable logfile can be resolved.
        #
        # . Usage
        #   view_log
    view_log() {
        local logfile=""

        logfile="$(_sgnd_logfile)" || {
            saywarning "Unable to resolve the active logfile"
            return 1
        }

        [[ -n "$logfile" && -r "$logfile" ]] || {
            saywarning "Logfile is not readable: ${logfile:-<unresolved>}"
            return 1
        }

        sgnd_print
        sgnd_print_sectionheader --text "SolidGroundUX logfile"
        sgnd_print_labeledvalue --label "Logfile" --value "$logfile"
        sgnd_print
        sgnd_print_file "$logfile"
    }

    motd_test() {
        local motd_file="$SGND_FRAMEWORK_ROOT/etc/update-motd.d/90-solidgroundux"

        sgnd_print
        sgnd_print_sectionheader --text "Testing MOTD generation"

        if [[ -r "$motd_file" ]]; then
            bash "$motd_file"
        else
            sayerror "MOTD file not readable: $motd_file"
        fi
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

        sgnd_print
        sgnd_print_sectionheader --text "Testing sayprogress() helpers"
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

            (( outer % 5 == 0 )) && sleep 0.1
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

            (( outer % 5 == 0 )) && sleep 0.1
        done
        sayprogress_done
        sayok "Progress test 3/3 complete"
    }

    show_colorchart(){
        sgnd_color_samples
    }

    # fn: show_theme - Browse and preview installed UI themes
        # . Purpose
        #   Cycle through installed SolidGroundUX themes and preview each one.
        #
        # . Behavior
        #   - Discovers default-ui-style.sh and style-*.sh in SGND_STYLE_DIR.
        #   - Starts at the currently active theme when possible.
        #   - Uses Left/Right arrows to switch the runtime theme without saving it.
        #   - Displays sgnd_style_samples after every successful switch.
        #   - Q returns to the smoke-test menu and leaves the selected theme active.
        #
        # . Returns
        #   0 after leaving the theme browser.
        #   1 when no readable themes are found.
        #
        # . Usage
        #   show_theme
    show_theme() {
        local -a theme_files=()
        local -a theme_names=()
        local theme_file=""
        local theme_name=""
        local current_file="${SGND_UI_STYLE##*/}"
        local key=""
        local key_tail=""
        local index=0
        local i=0

        while IFS= read -r -d '' theme_file; do
            theme_files+=("$(basename -- "$theme_file")")
        done < <(
            find "$SGND_STYLE_DIR" -maxdepth 1 -type f \
                \( -name 'default-ui-style.sh' -o -name 'style-*.sh' \) \
                -print0 | sort -z
        )

        if (( ${#theme_files[@]} == 0 )); then
            saywarning "No themes found in $SGND_STYLE_DIR"
            return 1
        fi

        for theme_file in "${theme_files[@]}"; do
            theme_name="${theme_file%.sh}"
            theme_name="${theme_name#style-}"
            [[ "$theme_file" == "default-ui-style.sh" ]] && theme_name="default"
            theme_names+=("$theme_name")
        done

        for i in "${!theme_files[@]}"; do
            if [[ "${theme_files[$i]}" == "$current_file" ]]; then
                index=$i
                break
            fi
        done

        while true; do
            theme_name="${theme_names[$index]}"

            sgnd_theme "$theme_name" || return $?

            printf '\033[2J\033[H'
            printf 'Theme %d/%d: %s\n' \
                "$((index + 1))" \
                "${#theme_names[@]}" \
                "$theme_name"
            printf 'Use Left/Right arrows to browse; Q returns to the menu.\n\n'

            sgnd_style_samples

            IFS= read -r -s -n1 key

            case "$key" in
                $'\e')
                    key_tail=""
                    IFS= read -r -s -n2 -t 0.1 key_tail || true

                    case "$key_tail" in
                        '[D')
                            index=$(( (index - 1 + ${#theme_names[@]}) % ${#theme_names[@]} ))
                            ;;
                        '[C')
                            index=$(( (index + 1) % ${#theme_names[@]} ))
                            ;;
                    esac
                    ;;
                q|Q)
                    break
                    ;;
                '')
                    continue
                    ;;
            esac
        done

        return 0
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

            if (( ${FLAG_VIEW_LOG:-0} )); then
                view_log
                return $?
            fi

        # -- Main script logic
            local choice

            while true; do
                sgnd_print
                sgnd_print_sectionheader --text "SolidGroundUX — Framework Unit Test Menu\n"
                
                sgnd_print " 1) Ask tests"
                sgnd_print " 2) Input test"
                sgnd_print " 3) Say test"
                sgnd_print " 4) Log level visibility test"
                sgnd_print " 5) Call motd"
                sgnd_print " 6) Progress dialogue test"
                sgnd_print " 7) Show license"
                sgnd_print " 8) Show color chart"
                sgnd_print " 9) Show theme"
                sgnd_print " L) File log level test"
                sgnd_print " V) View logfile"
                sgnd_print
                sgnd_print " A) Run all tests"
                sgnd_print " q) Quit"
                sgnd_print_sectionheader --maxwidth 25
                printf "Select option: "

                choice=""

                for seconds_left in {30..1}; do
                    printf '\r\033[K%bSelect option (auto-exit in %2ss): %b' \
                        "${SGND_UI_TEXT:-}" \
                        "$seconds_left" \
                        "${RESET:-}" >/dev/tty

                    if read -r -s -n1 -t 1 choice; then
                        break
                    fi
                done

                printf "\n"

                if [[ -z "$choice" ]]; then
                    sgnd_print "No selection made. Exiting..."
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
                    7) 
                        saydebug "$SGND_DOCS_DIR/$SGND_LICENSE_FILE"
                        sgnd_print_license
                        ;;
                    8)
                        show_colorchart
                        ;;
                    9)
                        show_theme
                        ;;
                    l)
                        file_loglevel_test
                        ;;
                    v)
                        view_log
                        ;;
                    a)
                        ask_test
                        input_test
                        say_test
                        loglevel_test
                        file_loglevel_test
                        motd_test
                        sayprogress_test
                        ;;
                    q)
                        sgnd_print "Exiting..."
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
