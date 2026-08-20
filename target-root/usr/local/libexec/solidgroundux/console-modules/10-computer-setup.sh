# ==================================================================================
# SolidGroundUX - Computer Setup
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623103
#   Checksum    : 2c2d4d2eab3de1cccb60857b6f4ff7e70209f76eee5b2a1aaf313183c8f062fc
#   Source      : 10-computer-setup.sh
#   Type        : module
#   Group       : SolidGround Console
#   Subgroup    : Console Modules
#   Purpose     : Configure and validate the base computer
#
# Description:
#   Registers the normal post-clone computer setup actions. The Prepare computer
#   action orchestrates the same individual actions shown beneath it in the menu.
# ==================================================================================
set -uo pipefail

# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the module is sourced and initialized only once.
        #
        # . Returns
        #   0 when loading may continue; exits with 2 when executed directly.
        #
        # . Usage
        #   _sgnd_lib_guard
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

# - Module metadata ----------------------------------------------------------------
    SGND_COMPUTER_SETUP_MODULE_ID="computer-setup"
    SGND_COMPUTER_SETUP_MODULE_NAME="Computer Setup"
    SGND_COMPUTER_SETUP_MODULE_VERSION="2.0.0"
    SGND_COMPUTER_SETUP_MODULE_DESC="Prepare and validate the base computer"

    SGND_MODULE_NAME="$SGND_COMPUTER_SETUP_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_COMPUTER_SETUP_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_COMPUTER_SETUP_MODULE_DESC"

# - Module actions -----------------------------------------------------------------
    # fn: _computer_set_identity
        # . Purpose
        #   Run the canonical SolidGroundUX identity workflow.
        #
        # . Returns
        #   Exit status from set-identity.sh.
    _computer_set_identity() {
        _sgnd_run_module_script "set-identity.sh" "$@"
    }

    # fn: _computer_configure_ssh_service
        # . Purpose
        #   Enable or disable SSH and keep its runtime state aligned.
        #
        # . Returns
        #   0 on success; non-zero on failure.
    _computer_configure_ssh_service() {
        local ssh_unit="ssh.service"
        local enabled="N"
        local requested="N"

        if ! systemctl cat "$ssh_unit" >/dev/null 2>&1; then
            ssh_unit="sshd.service"
        fi

        if ! systemctl cat "$ssh_unit" >/dev/null 2>&1; then
            sayfail "No SSH service unit was found."
            return 1
        fi

        if systemctl is-enabled "$ssh_unit" >/dev/null 2>&1; then
            enabled="Y"
        fi
        requested="$enabled"

        ask --label "Enable SSH service (Y/N)" --var requested --default "$requested" --labelwidth 32

        case "${requested^^}" in
            Y|YES)
                if (( ${FLAG_DRYRUN:-0} == 1 )); then
                    sayinfo "Dry run: Would enable and start $ssh_unit."
                    return 0
                fi

                sudo systemctl enable --now "$ssh_unit" || return $?
                sayok "SSH service enabled and started."
                ;;
            *)
                if (( ${FLAG_DRYRUN:-0} == 1 )); then
                    sayinfo "Dry run: Would disable and stop $ssh_unit."
                    return 0
                fi

                sudo systemctl disable --now "$ssh_unit" || return $?
                sayok "SSH service disabled and stopped."
                ;;
        esac
    }

    # fn: _computer_generate_ssh_keys
        # . Purpose
        #   Generate missing SSH host keys, validate sshd, and restart SSH.
        #
        # . Returns
        #   0 on success; non-zero on failure.
    _computer_generate_ssh_keys() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would generate SSH host keys and restart SSH."
            return 0
        fi

        sudo install -d -m 0755 -o root -g root /run/sshd || return 1
        sudo ssh-keygen -A || {
            sayfail "Failed to generate SSH host keys."
            return 1
        }

        sudo sshd -t || {
            sayfail "SSH configuration validation failed."
            return 1
        }

        sudo systemctl restart ssh.service 2>/dev/null || \
            sudo systemctl restart sshd.service || {
                sayfail "Failed to restart SSH service."
                return 1
            }

        sayok "SSH host keys are present and SSH configuration is valid."
    }

    # fn: _computer_configure_sudoers
        # . Purpose
        #   Grant the selected administrator passwordless access to trusted
        #   SolidGroundUX administration executables.
        #
        # . Returns
        #   0 on success; non-zero on failure or cancellation.
    _computer_configure_sudoers() {
        local admin_user="${SUDO_USER:-${USER:-sysadmin}}"
        local sudoers_file="/etc/sudoers.d/solidgroundux"
        local temp_file=""
        local decision="NO"

        ask --label "SolidGroundUX administrator" --var admin_user --default "$admin_user" --labelwidth 32

        id "$admin_user" >/dev/null 2>&1 || {
            sayfail "User does not exist: $admin_user"
            return 1
        }

        sgnd_print
        sgnd_print "This grants $admin_user passwordless sudo access to trusted"
        sgnd_print "SolidGroundUX administration tools beneath:"
        sgnd_print "  /usr/local/libexec/solidgroundux"
        sgnd_print

        ask_decision \
            --label "Configure SolidGroundUX sudo access for $admin_user?" \
            --choices "YES|Y,NO|N" \
            --default "NO" \
            --var decision || return $?

        [[ "$decision" == "YES" ]] || {
            saycancel "Sudo configuration cancelled."
            return 0
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would create $sudoers_file for $admin_user."
            return 0
        fi

        command -v visudo >/dev/null 2>&1 || {
            sayfail "visudo is unavailable. Install the sudo package first."
            return 1
        }

        temp_file="$(mktemp "${TMPDIR:-/tmp}/solidgroundux-sudoers.XXXXXX")" || return 1

        printf '%s\n' \
            '# SolidGroundUX sudo policy' \
            '# Passwordless elevation for trusted framework administration tools.' \
            'Cmnd_Alias SGND_ADMIN = /usr/local/libexec/solidgroundux/*' \
            "$admin_user ALL=(root) NOPASSWD: SGND_ADMIN" \
            > "$temp_file" || {
                rm -f -- "$temp_file"
                return 1
            }

        visudo -cf "$temp_file" >/dev/null || {
            rm -f -- "$temp_file"
            sayfail "Generated sudoers configuration is invalid."
            return 1
        }

        sudo install -m 0440 -o root -g root "$temp_file" "$sudoers_file" || {
            rm -f -- "$temp_file"
            return 1
        }
        rm -f -- "$temp_file"

        sudo visudo -cf "$sudoers_file" >/dev/null || {
            sayfail "Installed sudoers configuration failed validation."
            return 1
        }

        sayok "SolidGroundUX passwordless sudo access configured for $admin_user."
    }

    # fn: _computer_prepare
        # . Purpose
        #   Run the normal post-clone computer setup sequence.
        #
        # . Behavior
        #   - Runs the same four actions registered beneath Prepare computer.
        #   - Persists the result of each individual step through the console tracker.
        #   - Stops on the first failed step.
        #
        # . Returns
        #   0 when all steps succeed; otherwise the failing step status.
    _computer_prepare() {
        sgnd_console_run_tracked "setnetid" _computer_set_identity || return $?
        sgnd_console_run_tracked "sshcfg" _computer_configure_ssh_service || return $?
        sgnd_console_run_tracked "sshkeys" _computer_generate_ssh_keys || return $?
        sgnd_console_run_tracked "sudoers" _computer_configure_sudoers || return $?

        sayok "Computer preparation completed successfully."
        return 0
    }

    # fn: _computer_validate
        # . Purpose
        #   Validate the principal Computer Setup outcomes without changing the machine.
        #
        # . Returns
        #   0 when all required checks pass; 1 otherwise.
    _computer_validate() {
        local failures=0
        local hostname_short=""
        local primary_ip=""
        local ssh_unit="ssh.service"
        local host_key_count=0
        local sudoers_file="/etc/sudoers.d/solidgroundux"

        hostname_short="$(hostname -s 2>/dev/null || true)"
        primary_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')"

        sgnd_print
        sgnd_print_sectionheader "Computer setup validation"

        if [[ -n "$hostname_short" && "$hostname_short" != "localhost" ]]; then
            sgnd_print_labeledvalue --label "Hostname" --value "Passed"
        else
            sgnd_print_labeledvalue --label "Hostname" --value "Failed"
            failures=$((failures + 1))
        fi

        if [[ -n "$primary_ip" && "$primary_ip" != 127.* ]]; then
            sgnd_print_labeledvalue --label "Primary IPv4" --value "Passed ($primary_ip)"
        else
            sgnd_print_labeledvalue --label "Primary IPv4" --value "Failed"
            failures=$((failures + 1))
        fi

        if ! systemctl cat "$ssh_unit" >/dev/null 2>&1; then
            ssh_unit="sshd.service"
        fi

        if systemctl is-enabled --quiet "$ssh_unit" 2>/dev/null && systemctl is-active --quiet "$ssh_unit" 2>/dev/null; then
            sgnd_print_labeledvalue --label "SSH service" --value "Passed"
        else
            sgnd_print_labeledvalue --label "SSH service" --value "Failed"
            failures=$((failures + 1))
        fi

        host_key_count="$(find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key' 2>/dev/null | wc -l)"
        if (( host_key_count > 0 )); then
            sgnd_print_labeledvalue --label "SSH host keys" --value "Passed ($host_key_count)"
        else
            sgnd_print_labeledvalue --label "SSH host keys" --value "Failed"
            failures=$((failures + 1))
        fi

        if [[ -s "$sudoers_file" ]] && sudo visudo -cf "$sudoers_file" >/dev/null 2>&1; then
            sgnd_print_labeledvalue --label "SolidGround sudo" --value "Passed"
        else
            sgnd_print_labeledvalue --label "SolidGround sudo" --value "Failed"
            failures=$((failures + 1))
        fi

        sgnd_print
        if (( failures == 0 )); then
            sayok "Computer setup validation passed."
            return 0
        fi

        sayfail "$failures computer setup validation check(s) failed."
        return 1
    }

    # fn: _prepare-template.sh
        # . Purpose
        #   Prepare a template computer for cloning.
        #
        # . Returns
        #   0 on success; non-zero on failure.
    _prepare_template() {
        _sgnd_run_public_command "sgnd-prepare-template"
    }

# - Console registration ---------------------------------------------------------
    sgnd_menu_register_group \
        "$SGND_COMPUTER_SETUP_MODULE_ID" \
        "$SGND_COMPUTER_SETUP_MODULE_NAME" \
        "$SGND_COMPUTER_SETUP_MODULE_DESC" \
        0 1 100

    sgnd_menu_register_item "preparepc" "$SGND_COMPUTER_SETUP_MODULE_ID" "Prepare computer" "_computer_prepare" "Run the normal post-clone setup sequence" 0 15 1 0
    sgnd_menu_register_item "setnetid" "$SGND_COMPUTER_SETUP_MODULE_ID" "Set computer identity" "_computer_set_identity" "Configure hostname, network identity, DNS, and search domain" 0 15 1 1
    sgnd_menu_register_item "sshcfg" "$SGND_COMPUTER_SETUP_MODULE_ID" "Configure SSH service" "_computer_configure_ssh_service" "Enable or disable the SSH service" 0 15 1 1
    sgnd_menu_register_item "sshkeys" "$SGND_COMPUTER_SETUP_MODULE_ID" "Generate SSH host keys" "_computer_generate_ssh_keys" "Generate missing host keys, validate sshd, and restart SSH" 0 15 1 1
    sgnd_menu_register_item "sudoers" "$SGND_COMPUTER_SETUP_MODULE_ID" "Setup SolidGround sudo access" "_computer_configure_sudoers" "Allow the administrator to run trusted SolidGroundUX tools without a password" 0 15 1 1
    sgnd_menu_register_item "pcvalidate" "$SGND_COMPUTER_SETUP_MODULE_ID" "Validate computer setup" "_computer_validate" "Validate identity, SSH, host keys, and SolidGround sudo access" 0 15 1 0
    sgnd_menu_register_item "preptemplate" "$SGND_COMPUTER_SETUP_MODULE_ID" "Prepare for cloning" "_prepare_template" "Prepare a template computer for cloning" 0 15 1 0

    sayinfo "Computer Setup module registered with the console."
