# ==================================================================================
# SolidGroundUX - Computer Setup
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : cf58f31f50c4e9bac24001349d50c99f29c85c3ab55cb9aea66710f471977f64
#   Source      : 10-computer-setup.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Prepare and maintain the base computer
#
# Description:
#   Configures computer identity, template state, SSH, SolidGroundUX sudo access, and the standard Ubuntu package baseline.
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : -
#   Copyright     : © 2025 - 2026 Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # . Behavior
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # . Returns
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard "example-0"
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
    
# - Module metadata -------------------------------------------------------------
    SGND_COMPUTER_SETUP_MODULE_ID="computer-setup"
    SGND_COMPUTER_SETUP_MODULE_NAME="Computer Setup"
    SGND_COMPUTER_SETUP_MODULE_VERSION="1.0.0"
    SGND_COMPUTER_SETUP_MODULE_DESC="Configure identity, SSH, sudo access, templates, and baseline packages"

    SGND_MODULE_NAME="${SGND_COMPUTER_SETUP_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_COMPUTER_SETUP_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_COMPUTER_SETUP_MODULE_DESC}"

    # Module script directory retained for compatibility with the existing helper scripts.
    SGND_COMPUTER_SETUP_SCRIPT_MODULE_ID="machine-config"

# - Module actions --------------------------------------------------------------
    # fn: _show_machine_status
        # . Purpose
        #   Show current network, machine identity, and SSH service status.
        #
        # . Behavior
        #   - Displays the current hostname and machine-id.
        #   - Displays active network addresses, routes, and DNS configuration.
        #   - Displays whether the SSH service is enabled and active.
        #
        # . Returns
        #   0 after displaying the available status information.
        #
        # . Usage
        #   _show_machine_status
    _show_machine_status() {
        local machine_id="Unavailable"
        local ssh_unit="ssh.service"
        local ssh_active="Unavailable"
        local ssh_enabled="Unavailable"

        [[ -r /etc/machine-id ]] && machine_id="$(< /etc/machine-id)"

        if command -v systemctl >/dev/null 2>&1; then
            if ! systemctl cat "$ssh_unit" >/dev/null 2>&1; then
                ssh_unit="sshd.service"
            fi

            ssh_active="$(systemctl is-active "$ssh_unit" 2>/dev/null || true)"
            ssh_enabled="$(systemctl is-enabled "$ssh_unit" 2>/dev/null || true)"
            [[ -n "$ssh_active" ]] || ssh_active="inactive"
            [[ -n "$ssh_enabled" ]] || ssh_enabled="disabled"
        fi

        sgnd_print_sectionheader "Machine identity"
        sgnd_print_labeledvalue --label "Hostname" --value "$(hostname)" --labelwidth 20
        sgnd_print_labeledvalue --label "Machine ID" --value "$machine_id" --labelwidth 20

        sgnd_print
        sgnd_print_sectionheader "Network configuration"
        if command -v ip >/dev/null 2>&1; then
            printf '%s\n' 'Addresses:'
            ip -brief address
            printf '\n%s\n' 'Routes:'
            ip route
        else
            saywarning "The ip command is unavailable"
        fi

        if command -v resolvectl >/dev/null 2>&1; then
            printf '\n%s\n' 'DNS:'
            resolvectl status --no-pager 2>/dev/null || saywarning "DNS status is unavailable"
        elif [[ -r /etc/resolv.conf ]]; then
            printf '\n%s\n' 'DNS (/etc/resolv.conf):'
            sed -n '/^[[:space:]]*\(nameserver\|search\|domain\)[[:space:]]/p' /etc/resolv.conf
        fi

        sgnd_print
        sgnd_print_sectionheader "SSH service"
        sgnd_print_labeledvalue --label "Unit" --value "$ssh_unit" --labelwidth 20
        sgnd_print_labeledvalue --label "Active" --value "$ssh_active" --labelwidth 20
        sgnd_print_labeledvalue --label "Enabled" --value "$ssh_enabled" --labelwidth 20

        return 0
    }

    # fn: _init_machine
        # . Purpose
        #   Generate a new machine-id for the VM.
        #
        # . Behavior
        #   - Calls systemd-machine-id-setup to generate a new machine-id.
        #   - Verifies that /etc/machine-id is non-empty after generation.
        #
        # . Returns
        #   0 if successful, 1 if failed to generate machine-id.
        #
        # . Usage
        #   _init_machine
    _init_machine() {
        local machine_id
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Skipping machine-id generation."
            return 0
        fi
        sayinfo "Generating machine-id..."

        if systemd-machine-id-setup && [[ -s /etc/machine-id ]]; then
            machine_id=$(< /etc/machine-id)
            sayinfo "Machine-id ($machine_id) generated successfully."
        else
            sayerror "Failed to generate machine-id."
            return 1
        fi
    }

    # fn: _generate_ssh_keys
        # . Purpose
        #   Generate SSH host keys for the VM.
        #
        # . Behavior
        #   - Calls ssh-keygen to generate new SSH host keys.
        #   - Restarts the SSH service after key generation.
        #
        # . Returns
        #   0 if successful, 1 if failed to generate SSH host keys.
        #
        # . Usage
        #   _generate_ssh_keys
    _generate_ssh_keys() {

        sayinfo "Verifying sshd..."

        sudo install -d -m 0755 -o root -g root /run/sshd

        sayinfo "Generating SSH host keys..."

        if ! sudo ssh-keygen -A; then
            sayfail "Failed to generate SSH host keys."
            return 1
        fi

        sayinfo "Validating SSH configuration..."

        if ! sudo sshd -t; then
            sayfail "SSH configuration validation failed."
            return 1
        fi

        sayinfo "Restarting SSH service..."

        if ! sudo systemctl restart ssh; then
            sayfail "Failed to restart SSH service."
            return 1
        fi

        sayinfo "SSH host keys generated and SSH service restarted successfully."
    }

    # fn: _configure_ssh_service
        # . Purpose
        #   Enable or disable the SSH service and keep its runtime state aligned.
        #
        # . Behavior
        #   - Detects ssh.service or sshd.service.
        #   - Shows the current enabled state as the prompt default.
        #   - Enables and starts SSH, or disables and stops it.
        #   - Honors console dry-run mode.
        #
        # . Usage
        #   _configure_ssh_service
    _configure_ssh_service() {
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
                else
                    sudo systemctl enable --now "$ssh_unit" || return $?
                    sayok "SSH service enabled and started."
                fi
                ;;
            *)
                if (( ${FLAG_DRYRUN:-0} == 1 )); then
                    sayinfo "Dry run: Would disable and stop $ssh_unit."
                else
                    sudo systemctl disable --now "$ssh_unit" || return $?
                    sayok "SSH service disabled and stopped."
                fi
                ;;
        esac
    }

    # fn: _set_identity - Set identity
        # . Purpose
        #   Set identity.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _set_identity
    _set_identity() {
        _sgnd_run_module_script \
            "set-identity.sh" \
            "$@"
    }

    # fn: _set_dns_server
        # . Purpose
        #   Update the machine's configured DNS server without changing its hostname
        #   or address assignment mode.
        #
        # . Behavior
        #   - Delegates to set-identity.sh in DNS-only automatic mode.
        #   - Preserves the current hostname, interface, IPv4 address, gateway, and
        #     DHCP/static selection.
        #   - Rewrites and applies the active Netplan configuration through the
        #     canonical identity workflow.
        #
        # Inputs:
        #   $1 - DNS server IPv4 address.
        #
        # . Returns
        #   Returns the underlying set-identity.sh status.
        #
        # . Usage
        #   _set_dns_server "192.168.0.15"
    _set_dns_server() {
        local dns_server="${1:-}"

        [[ -n "$dns_server" ]] || {
            sayfail "A DNS server IPv4 address is required."
            return 1
        }

        _sgnd_run_module_script \
            "set-identity.sh" \
            --dns-only \
            --DNS "$dns_server" \
            --Auto
    }

    # fn: _prep_template - Prep template
        # . Purpose
        #   Prep template.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _prep_template
    _prep_template() {
        _sgnd_run_module_script \
            "prepare-template.sh" \
            "$@"
    }






    # fn: _configure_solidgroundux_sudoers
        # . Purpose
        #   Configure passwordless sudo access for trusted SolidGroundUX administration tools.
        #
        # . Behavior
        #   - Prompts for the local administrator account.
        #   - Creates /etc/sudoers.d/solidgroundux using a temporary file.
        #   - Grants passwordless root execution for tools beneath
        #     /usr/local/libexec/solidgroundux.
        #   - Validates the generated rule with visudo before installation.
        #   - Honors console dry-run mode.
        #
        # . Returns
        #   0 when the sudoers rule is valid and installed, otherwise non-zero.
        #
        # . Usage
        #   _configure_solidgroundux_sudoers
    _configure_solidgroundux_sudoers() {
        local admin_user="${SUDO_USER:-${USER:-sysadmin}}"
        local sudoers_file="/etc/sudoers.d/solidgroundux"
        local temp_file=""
        local reply=0

        ask --label "SolidGroundUX administrator" \
            --var admin_user \
            --default "$admin_user" \
            --labelwidth 32

        if ! id "$admin_user" >/dev/null 2>&1; then
            sayfail "User does not exist: $admin_user"
            return 1
        fi

        sgnd_print
        sgnd_print "This grants $admin_user passwordless sudo access to trusted"
        sgnd_print "SolidGroundUX administration tools beneath:"
        sgnd_print "  /usr/local/libexec/solidgroundux"
        sgnd_print

        ask_dlg_autocontinue \
            --seconds 15 \
            --message "Configure SolidGroundUX sudo access for $admin_user?" \
            --cancel

        reply=$?
        case "$reply" in
            0|1) ;;
            2) saycancel "Sudo configuration cancelled."; return 1 ;;
            *) sayfail "Unexpected confirmation response: $reply"; return 1 ;;
        esac

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would create $sudoers_file for $admin_user."
            return 0
        fi

        command -v visudo >/dev/null 2>&1 || {
            sayfail "visudo is unavailable. Install the sudo package first."
            return 1
        }

        temp_file="$(mktemp "${TMPDIR:-/tmp}/solidgroundux-sudoers.XXXXXX")" || {
            sayfail "Cannot create temporary sudoers file."
            return 1
        }

        printf '%s\n' \
            '# SolidGroundUX sudo policy' \
            '# Passwordless elevation for trusted framework administration tools.' \
            'Cmnd_Alias SGND_ADMIN = /usr/local/libexec/solidgroundux/*' \
            "$admin_user ALL=(root) NOPASSWD: SGND_ADMIN" \
            > "$temp_file" || {
                rm -f -- "$temp_file"
                sayfail "Cannot write temporary sudoers configuration."
                return 1
            }

        if ! visudo -cf "$temp_file" >/dev/null; then
            rm -f -- "$temp_file"
            sayfail "Generated sudoers configuration is invalid."
            return 1
        fi

        if ! sudo install -m 0440 -o root -g root "$temp_file" "$sudoers_file"; then
            rm -f -- "$temp_file"
            sayfail "Failed to install $sudoers_file."
            return 1
        fi

        rm -f -- "$temp_file"

        if ! sudo visudo -cf "$sudoers_file" >/dev/null; then
            sayfail "Installed sudoers configuration failed validation."
            return 1
        fi

        sayok "SolidGroundUX passwordless sudo access configured for $admin_user."
        return 0
    }

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group \
        "$SGND_COMPUTER_SETUP_MODULE_ID" \
        "$SGND_COMPUTER_SETUP_MODULE_NAME" \
        "$SGND_COMPUTER_SETUP_MODULE_DESC" \
        0 1 100

    sgnd_console_register_item "machstat" "$SGND_COMPUTER_SETUP_MODULE_ID" "Show computer status" "_show_machine_status" "Show identity, network configuration, machine ID, and SSH status" 0 5 1
    sgnd_console_register_item "setnetid" "$SGND_COMPUTER_SETUP_MODULE_ID" "Set computer identity" "_set_identity" "Configure hostname and network identity" 0 5 1
    sgnd_console_register_item "prepclone" "$SGND_COMPUTER_SETUP_MODULE_ID" "Prepare for cloning" "_prep_template" "Prepare this computer to be used as a template" 0 5 1
    sgnd_console_register_item "machid" "$SGND_COMPUTER_SETUP_MODULE_ID" "Generate machine ID" "_init_machine" "Generate a new machine ID" 0 5 1
    sgnd_console_register_item "sshcfg" "$SGND_COMPUTER_SETUP_MODULE_ID" "Configure SSH service" "_configure_ssh_service" "Enable or disable the SSH service" 0 5 1
    sgnd_console_register_item "sshkeys" "$SGND_COMPUTER_SETUP_MODULE_ID" "Generate SSH host keys" "_generate_ssh_keys" "Generate SSH host keys and restart SSH" 0 5 1
    sgnd_console_register_item "sudoers" "$SGND_COMPUTER_SETUP_MODULE_ID" "Setup SolidGround sudo access" "_configure_solidgroundux_sudoers" "Allow the administrator to run trusted SolidGroundUX tools without a password" 0 5 1

