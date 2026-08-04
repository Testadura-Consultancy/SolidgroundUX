# ==================================================================================
# SolidGroundUX - Computer Setup
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621602
#   Checksum    : pending
#   Source      : 10-computer-setup.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Prepare and maintain the base computer
#
# Description:
#   Configures computer identity, template state, SSH, and the standard Ubuntu package baseline.
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
    SGND_COMPUTER_SETUP_MODULE_DESC="Configure identity, SSH, templates, and baseline packages"

    SGND_MODULE_ID="${SGND_COMPUTER_SETUP_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_COMPUTER_SETUP_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_COMPUTER_SETUP_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_COMPUTER_SETUP_MODULE_DESC}"

    # Module script directory retained for compatibility with the existing helper scripts.
    SGND_COMPUTER_SETUP_SCRIPT_MODULE_ID="machine-config"

# - Module actions --------------------------------------------------------------
    # fn$ _show_machine_status
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

    # fn$ _init_machine
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

    # fn$ _generate_ssh_keys
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

    # fn$ _configure_ssh_service
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

    # fn$ _install_basepackages
        # . Purpose
        #   Install or update the standard Ubuntu VM baseline packages.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs general administration, diagnostics, and Samba client tools.
        #   - Enables and starts the QEMU Guest Agent.
        #   - Reports the intended action without changing the system in dry-run mode.
        #
        # . Returns
        #   0 if the baseline was installed successfully, otherwise non-zero.
        #
        # . Usage
        #   _install_basepackages
    _install_basepackages() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install or update Ubuntu baseline packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing or updating Ubuntu baseline packages."
        sudo apt-get install -y \
            acl \
            attr \
            bash-completion \
            ca-certificates \
            cifs-utils \
            coreutils \
            curl \
            dnsutils \
            dos2unix \
            file \
            findutils \
            gawk \
            git \
            gnupg \
            grep \
            htop \
            iproute2 \
            iputils-arping \
            iputils-ping \
            jq \
            less \
            libc-bin \
            lsb-release \
            lsof \
            man-db \
            manpages \
            nano \
            ncdu \
            net-tools \
            openssh-server \
            python3 \
            qemu-guest-agent \
            rsync \
            smbclient \
            software-properties-common \
            tar \
            tcpdump \
            traceroute \
            tree \
            ufw \
            unzip \
            vim \
            wget \
            zip || return 1

        sayinfo "Enabling QEMU Guest Agent."
        sudo systemctl enable --now qemu-guest-agent.service || return 1

        sayinfo "Ubuntu baseline installation or update completed successfully."
    }

    # fn$ _update_package_index
        # . Purpose
        #   Refresh the local Ubuntu package index.
        #
        # . Behavior
        #   - Downloads current package metadata from configured APT repositories.
        #   - Does not install or upgrade packages.
        #   - Reports the intended action without changing the system in dry-run mode.
        #
        # . Returns
        #   0 if the package index was refreshed successfully, otherwise non-zero.
        #
        # . Usage
        #   _update_package_index
    _update_package_index() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would update the Ubuntu package index."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Ubuntu package index updated successfully."
    }

    # fn$ _upgrade_installed_packages
        # . Purpose
        #   Upgrade installed Ubuntu packages to their available versions.
        #
        # . Behavior
        #   - Refreshes the APT package index before upgrading.
        #   - Applies available upgrades without removing installed packages.
        #   - Reports the intended action without changing the system in dry-run mode.
        #
        # . Returns
        #   0 if installed packages were upgraded successfully, otherwise non-zero.
        #
        # . Usage
        #   _upgrade_installed_packages
    _upgrade_installed_packages() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would upgrade installed Ubuntu packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Upgrading installed Ubuntu packages."
        sudo apt-get upgrade -y || return 1

        sayinfo "Installed Ubuntu packages upgraded successfully."
    }

    # fn$ _clean_unused_packages
        # . Purpose
        #   Remove unused package dependencies and cached package data.
        #
        # . Behavior
        #   - Removes packages that were installed automatically and are no longer needed.
        #   - Removes obsolete package files from the local APT cache.
        #   - Reports the intended action without changing the system in dry-run mode.
        #
        # . Returns
        #   0 if package cleanup completed successfully, otherwise non-zero.
        #
        # . Usage
        #   _clean_unused_packages
    _clean_unused_packages() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would remove unused packages and clean the APT cache."
            return 0
        fi

        sayinfo "Removing unused package dependencies."
        sudo apt-get autoremove -y || return 1

        sayinfo "Cleaning obsolete package files from the APT cache."
        sudo apt-get autoclean || return 1

        sayinfo "Package cleanup completed successfully."
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

    sgnd_console_register_group "package-management" "Package Management" "Install the computer baseline and maintain Ubuntu packages" 0 1 110
    sgnd_console_register_item "basepkg" "package-management" "Install base packages" "_install_basepackages" "Install the Ubuntu baseline packages" 0 5 1
    sgnd_console_register_item "pkgindex" "package-management" "Update package index" "_update_package_index" "Refresh available package information" 0 5 1
    sgnd_console_register_item "pkgupgrade" "package-management" "Upgrade installed packages" "_upgrade_installed_packages" "Upgrade installed Ubuntu packages" 0 5 1
    sgnd_console_register_item "pkgclean" "package-management" "Clean unused packages" "_clean_unused_packages" "Remove unused packages and cached files" 0 5 1
