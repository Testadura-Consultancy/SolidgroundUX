# ==================================================================================
# SolidGroundUX - Developer Tools Console Module
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.6
#   Build       : 2619513
#   Checksum    : 88b6ae3b450efc06eb0d1b6f47e409b799f593d33948006912b64610febdc33b
#   Source      : console-devtools.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Expose developer tools and framework smoke tests in sgnd-console
#
# Description:
#   Registers developer workflow scripts and in-process framework smoke tests with
#   sgnd-console. Smoke tests run inside the console's existing framework instance.
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : -
#   Copyright     : © 2025 - 2026 Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# --- Library guard ----------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the module is sourced and initialized only once.
        #
        # . Returns
        #   0 when loading may continue or the module was already loaded.
        #   Exits with status 2 when executed directly.
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

# --- Developer tool actions -------------------------------------------------------
    # fn: _exe_createworkspace
        # . Returns
        #   Exit status of create-workspace.sh.
        # . Usage
        #   _exe_createworkspace
    _exe_createworkspace() {
        _sgnd_run_script "create-workspace.sh"
    }

    # fn: _exe_deployworkspace
        # . Returns
        #   Exit status of deploy-workspace.sh.
        # . Usage
        #   _exe_deployworkspace
    _exe_deployworkspace() {
        _sgnd_run_script "deploy-workspace.sh"
    }

    # fn: _exe_preparerelease
        # . Returns
        #   Exit status of prepare-release.sh.
        # . Usage
        #   _exe_preparerelease
    _exe_preparerelease() {
        _sgnd_run_script "prepare-release.sh"
    }

    # fn: _exe_metadata_editor
        # . Returns
        #   Exit status of metadata-editor.sh.
        # . Usage
        #   _exe_metadata_editor
    _exe_metadata_editor() {
        _sgnd_run_script "metadata-editor.sh"
    }

# --- Framework smoke-test actions ------------------------------------------------
    # fn: devtools_input_test
        # . Purpose
        #   Run a simple prompt-form input test.
        #
        # . Returns
        #   0 when the form completes; otherwise the form status.
        #
        # . Usage
        #   devtools_input_test
    devtools_input_test() {
        local demo_string="sample"
        local demo_integer="4"
        local demo_date="2026-01-01"

        sgnd_print
        ask_prompt_form --autoalign --pad 2 -- \
            "demo_string|String value|$demo_string|sgnd_validate_text" \
            "demo_integer|Integer value|$demo_integer|sgnd_validate_text" \
            "demo_date|Date value|$demo_date|sgnd_validate_text"
    }

    # fn: devtools_ask_test
        # . Purpose
        #   Run the interactive ask helper smoke tests.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   devtools_ask_test
    devtools_ask_test(){
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

    # fn: devtools_say_test
        # . Purpose
        #   Emit the standard say message types.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   devtools_say_test
    devtools_say_test(){
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

    # fn: devtools_loglevel_test
        # . Purpose
        #   Exercise console filtering at every supported log level.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   devtools_loglevel_test
    devtools_loglevel_test() {
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

    # fn: devtools_file_loglevel_test
        # . Purpose
        #   Exercise file filtering at every supported log level.
        #
        # . Returns
        #   0 on success; 1 when the logfile or framework state cannot be resolved.
        #
        # . Usage
        #   devtools_file_loglevel_test
    devtools_file_loglevel_test() {
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

    # fn: devtools_view_log
        # . Purpose
        #   Display the resolved SolidGroundUX logfile.
        #
        # . Returns
        #   0 on success; 1 when the logfile is unavailable.
        #
        # . Usage
        #   devtools_view_log
    devtools_view_log() {
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

    # fn: devtools_motd_test
        # . Purpose
        #   Run the installed SolidGroundUX MOTD renderer.
        #
        # . Returns
        #   0 on success; non-zero when the MOTD cannot be run.
        #
        # . Usage
        #   devtools_motd_test
    devtools_motd_test() {
        local motd_file="$SGND_FRAMEWORK_ROOT/etc/update-motd.d/90-solidgroundux"

        sgnd_print
        sgnd_print_sectionheader --text "Testing MOTD generation"

        if [[ -r "$motd_file" ]]; then
            bash "$motd_file"
        else
            sayfail "MOTD file not readable: $motd_file"
        fi
    }

    # fn: devtools_sayprogress_test
        # . Purpose
        #   Run single-, double-, and triple-level progress tests.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   devtools_sayprogress_test
    devtools_sayprogress_test() {
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

    # fn: devtools_show_colorchart
        # . Purpose
        #   Display the active UI palette color chart.
        #
        # . Returns
        #   Status returned by sgnd_color_samples.
        #
        # . Usage
        #   devtools_show_colorchart
    devtools_show_colorchart(){
        sgnd_color_samples
    }

    # fn: devtools_show_theme
        # . Purpose
        #   Browse and preview installed SolidGroundUX themes.
        #
        # . Returns
        #   0 on exit; 1 when no themes are available.
        #
        # . Usage
        #   devtools_show_theme
    devtools_show_theme() {
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

# --- Console registration --------------------------------------------------------
    sgnd_console_register_group \
        "devtools" \
        "Developer tools" \
        "Workspace, deployment, release, and metadata tools" \
        0 1 800

    sgnd_console_register_item "createws" "devtools" "Create workspace" "_exe_createworkspace" "Create a template workspace with target-root structure" 0 15 1
    sgnd_console_register_item "deployws" "devtools" "Deploy workspace" "_exe_deployworkspace" "Deploy a target-root structure from workspace to root" 0 15 1
    sgnd_console_register_item "preprel" "devtools" "Prepare release" "_exe_preparerelease" "Create a release archive with checksums and manifests" 0 15 1
    sgnd_console_register_item "metaedt" "devtools" "Metadata editor" "_exe_metadata_editor" "Edit metadata fields in script header comments" 0 15 1

    sgnd_console_register_group \
        "smoketests" \
        "Framework smoke tests" \
        "Run framework component tests inside the console instance" \
        0 1 810

    sgnd_console_register_item "test-input" "smoketests" "Input form" "devtools_input_test" "Run a simple prompt-form input test" 0 15 1
    sgnd_console_register_item "test-ask" "smoketests" "Ask helpers" "devtools_ask_test" "Run interactive ask helper tests" 0 5 1
    sgnd_console_register_item "test-say" "smoketests" "Say helpers" "devtools_say_test" "Emit each standard say message type" 0 15 1
    sgnd_console_register_item "test-consolelog" "smoketests" "Console log levels" "devtools_loglevel_test" "Test console message filtering at every level" 0 15 1
    sgnd_console_register_item "test-filelog" "smoketests" "File log levels" "devtools_file_loglevel_test" "Test file message filtering and finish at silent" 0 15 1
    sgnd_console_register_item "view-log" "smoketests" "View logfile" "devtools_view_log" "Display the resolved SolidGroundUX logfile" 0 20 1
    sgnd_console_register_item "test-motd" "smoketests" "MOTD" "devtools_motd_test" "Run the SolidGroundUX MOTD script" 0 15 1
    sgnd_console_register_item "test-progress" "smoketests" "Progress display" "devtools_sayprogress_test" "Run single-, double-, and triple-level progress tests" 0 15 1
    sgnd_console_register_item "show-colors" "smoketests" "Color chart" "devtools_show_colorchart" "Display the active palette color chart" 0 15 1
    sgnd_console_register_item "show-themes" "smoketests" "Theme browser" "devtools_show_theme" "Browse and preview installed themes" 0 20 1
