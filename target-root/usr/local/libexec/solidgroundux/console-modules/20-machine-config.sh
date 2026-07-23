# ==================================================================================
# VM Config - SolidGroundUX Console Module
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0.0
#   Build       : 2620423
#   Checksum    : 7580e2ea931eb6372f0fc29d0186da772186c9704e4ddf20539c1d91122f5327
#   Source      : 20-machine-config.sh
#   Type        : module
#   Group       : Machine Configuration
#   Purpose     : Configure machine identity, packages, roles, and template state
#
# Description:
#   Provides the VM configuration menu for freshly installed or cloned Ubuntu
#   virtual machines. The module manages machine identity, template preparation,
#   SolidGroundUX installation, baseline packages, and optional server roles.
#
# Design principles:
#   - Modules define functions first, then register themselves explicitly
#   - Registration is data-driven through sgnd_console_register_group/item
#   - Keep module logic local and menu-facing
#   - Avoid framework-wide policy decisions inside modules
#
# Role in framework:
#   - Extends sgnd-console with domain-specific actions and menu entries
#   - Acts as a lightweight plugin layer on top of the console host
#   - May depend on framework and sgnd-console primitives already being loaded
#
# Assumptions:
#   - Loaded by sgnd-console after framework bootstrap is complete
#   - sgnd_console_register_group and sgnd_console_register_item are available
#   - Framework helpers such as say* and sgnd_print_* may be used
#
# Non-goals:
#   - Standalone execution
#   - Bootstrap, path resolution, or framework initialization
#   - Full-screen UI behavior outside the sgnd-console host
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
    
# --- Internal helpers -------------------------------------------------------------
    # doc$ Internal helper naming
        # Prefix internal-only helpers with "_".
        # Keep internal helpers module-local and menu-focused.
        #
        # Example:
        #   _sample_format_status() { :; }

# --- Module metadata -------------------------------------------------------------
    SGND_MACHINE_CONFIG_MODULE_ID="machine-config"
    SGND_MACHINE_CONFIG_MODULE_NAME="Machine Configuration"
    SGND_MACHINE_CONFIG_MODULE_VERSION="1.0.0"
    SGND_MACHINE_CONFIG_MODULE_DESC="Configure machine identity, packages, roles, and template state"

    SGND_MODULE_ID="$SGND_MACHINE_CONFIG_MODULE_ID"
    SGND_MODULE_NAME="$SGND_MACHINE_CONFIG_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_MACHINE_CONFIG_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_MACHINE_CONFIG_MODULE_DESC"

# --- Public module actions --------------------------------------------------------
    # doc$ Public module action naming
        # Use clear action-style names for functions registered as menu handlers.
        # Registered handlers do not need a sgnd_ prefix; they belong to the module surface.
        #
        # Example:
        #   sample_show_message() { :; }
        #   sys_status() { :; }


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
    _generate_ssh_keys() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Skipping SSH host key generation."
            return 0
        fi

        sayinfo "Generating SSH host keys..."
        if ssh-keygen -A; then
            sayinfo "SSH host keys generated successfully. Restarting SSH service..."
            systemctl restart ssh
        else
            sayerror "Failed to generate SSH host keys."
            return 1
        fi
    }

    _set_identity() {
        _sgnd_run_module_script \
            "$SGND_MACHINE_CONFIG_MODULE_ID" \
            "set-identity.sh" \
            "$@"
    }

    _prep_template() {
        _sgnd_run_module_script \
            "$SGND_MACHINE_CONFIG_MODULE_ID" \
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
            iputils-ping \
            jq \
            krb5-user \
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

    # fn$ _install_samba_ad
        # . Purpose
        #   Install the packages required for a Samba Active Directory Domain Controller.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs the Samba AD/DC, Kerberos, and DNS diagnostic packages.
        #   - Disables the standalone Samba services used by file-server roles.
        #   - Enables the dedicated Samba AD/DC service without starting it.
        #   - Leaves domain provisioning to a separate configuration step.
        #
        # . Returns
        #   0 if the role packages were installed successfully, otherwise non-zero.
    _install_samba_ad() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Samba Active Directory Domain Controller packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing Samba Active Directory Domain Controller packages."
        sudo apt-get install -y \
            bind9-dnsutils \
            krb5-user \
            samba-ad-dc || return 1

        sayinfo "Preparing Samba services for later AD/DC provisioning."
        sudo systemctl disable --now smbd.service nmbd.service winbind.service || return 1
        sudo systemctl mask smbd.service nmbd.service winbind.service || return 1
        sudo systemctl unmask samba-ad-dc.service || return 1
        sudo systemctl enable samba-ad-dc.service || return 1

        sayinfo "Samba AD/DC packages installed; domain provisioning is still required."
    }

    # fn$ _install_samba_file
        # . Purpose
        #   Install the packages required for a standalone Samba file server.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs Samba and supporting ACL and extended-attribute tools.
        #   - Leaves share definitions and access-control configuration unchanged.
        #
        # . Returns
        #   0 if the role packages were installed successfully, otherwise non-zero.
    _install_samba_file() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Samba file-server packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing Samba file-server packages."
        sudo apt-get install -y \
            acl \
            attr \
            cifs-utils \
            samba \
            smbclient || return 1

        sayinfo "Samba file-server packages installed; share configuration is still required."
    }

    # fn$ _install_xrdp
        # . Purpose
        #   Install and enable XRDP on an Ubuntu desktop system.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs XRDP.
        #   - Enables and starts the XRDP service.
        #   - Does not install a desktop environment on Ubuntu Server.
        #
        # . Returns
        #   0 if XRDP was installed and enabled successfully, otherwise non-zero.
    _install_xrdp() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install and enable XRDP."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing XRDP."
        sudo apt-get install -y xrdp || return 1

        sayinfo "Enabling XRDP."
        sudo systemctl enable --now xrdp.service || return 1

        sayinfo "XRDP installed and enabled successfully."
    }

    # fn$ _install_docker
        # . Purpose
        #   Install Docker Engine from Docker's official Ubuntu repository.
        #
        # . Behavior
        #   - Refreshes the APT package index and installs repository prerequisites.
        #   - Installs Docker's official signing key and deb822 repository definition.
        #   - Installs Docker Engine, containerd, Buildx, and the Compose plugin.
        #   - Enables and starts the Docker service.
        #   - Does not add users to the privileged docker group.
        #
        # . Returns
        #   0 if Docker was installed and enabled successfully, otherwise non-zero.
    _install_docker() {
        local ubuntu_codename

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Docker Engine from Docker's official repository."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing Docker repository prerequisites."
        sudo apt-get install -y ca-certificates curl || return 1

        ubuntu_codename="$(. /etc/os-release && printf '%s' "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

        sudo install -m 0755 -d /etc/apt/keyrings || return 1
        sudo curl -fsSL \
            https://download.docker.com/linux/ubuntu/gpg \
            -o /etc/apt/keyrings/docker.asc || return 1
        sudo chmod a+r /etc/apt/keyrings/docker.asc || return 1

        printf '%s\n' \
            'Types: deb' \
            'URIs: https://download.docker.com/linux/ubuntu' \
            "Suites: ${ubuntu_codename}" \
            'Components: stable' \
            "Architectures: $(dpkg --print-architecture)" \
            'Signed-By: /etc/apt/keyrings/docker.asc' \
            | sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

        sayinfo "Installing Docker Engine."
        sudo apt-get update || return 1
        sudo apt-get install -y \
            containerd.io \
            docker-buildx-plugin \
            docker-ce \
            docker-ce-cli \
            docker-compose-plugin || return 1

        sayinfo "Enabling Docker Engine."
        sudo systemctl enable --now docker.service || return 1

        sayinfo "Docker Engine installed and enabled successfully."
    }



# --- Console registration ---------------------------------------------------------
    # doc$ Console registration
        # Allowed side effect:
        #   - On source, the module may register groups and items with sgnd-console.
        #
        # Example:
        #   sgnd_console_register_group "system" "System tools" "General system operations"
        #
        #   sgnd_console_register_item \
        #       "sys-status" \
        #       "system" \
        #       "System status" \
        #       "sys_status" \
        #       "Show system status" \
        #       0 \
        #       15
    sgnd_console_register_group \
        "$SGND_MACHINE_CONFIG_MODULE_ID" \
        "$SGND_MACHINE_CONFIG_MODULE_NAME" \
        "$SGND_MACHINE_CONFIG_MODULE_DESC" \
        0 1 800
    
    sgnd_console_register_item "machstat" "$SGND_MACHINE_CONFIG_MODULE_ID" "Show machine status" "_show_machine_status" "Show network configuration, machine ID and SSH status" 0 5 1
    sgnd_console_register_item "machid" "$SGND_MACHINE_CONFIG_MODULE_ID" "Generate Machine ID" "_init_machine" "Set up a new machine ID" 0 5 1
    sgnd_console_register_item "sshkeys" "$SGND_MACHINE_CONFIG_MODULE_ID" "Generate SSH Keys" "_generate_ssh_keys" "Generate SSH host keys" 0 5 1
    sgnd_console_register_item "setnetid" "$SGND_MACHINE_CONFIG_MODULE_ID" "Set network ID" "_set_identity" "Configure hostname and network ID" 0 5 1
    sgnd_console_register_item "prepclone" "$SGND_MACHINE_CONFIG_MODULE_ID" "Prepare for cloning" "_prep_template" "Prepare this VM to be used as a Template" 0 5 1

    sgnd_console_register_group \
        "pkghouse" \
        "Package Housekeeping" \
        "Update, upgrade and clean Ubuntu packages" \
        0 1 800

    sgnd_console_register_item "basepkg" "pkghouse" "Install base packages" "_install_basepackages" "Install Ubuntu baseline packages" 0 5 1
    sgnd_console_register_item "pkgindex" "pkghouse" "Update package index" "_update_package_index" "Refresh available package information" 0 5 1
    sgnd_console_register_item "pkgupgrade" "pkghouse" "Upgrade installed packages" "_upgrade_installed_packages" "Upgrade installed Ubuntu packages" 0 5 1
    sgnd_console_register_item "pkgclean" "pkghouse" "Clean unused packages" "_clean_unused_packages" "Remove unused packages and cached files" 0 5 1

    sgnd_console_register_group \
        "roles" \
        "Optional Roles and Services" \
        "Install optional server roles and desktop services" \
        0 1 800

    sgnd_console_register_item "sambaad" "roles" "Install Samba AD server" "_install_samba_ad" "Install Samba Active Directory Domain Controller packages" 0 5 1
    sgnd_console_register_item "sambafile" "roles" "Install Samba File Server" "_install_samba_file" "Install Samba file-server packages" 0 5 1
    sgnd_console_register_item "instxrdp" "roles" "Install XRDP" "_install_xrdp" "Install XRDP for Ubuntu Desktop" 0 5 1
    sgnd_console_register_item "instdocker" "roles" "Install Docker" "_install_docker" "Install Docker Engine" 0 5 1
