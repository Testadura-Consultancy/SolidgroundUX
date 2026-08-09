# ==================================================================================
# SolidGroundUX - Package Management
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2622101
#   Checksum    : 9806e668f825ed4ba2b367d212295e170ad52887ffdb0966f14cbd1fc94ca7de
#   Source      : 15-package-management.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Install and maintain operating-system and SolidGroundUX role packages
#
# Description:
#   Centralizes Ubuntu package maintenance and installation of packages required by
#   SolidGroundUX machine roles and optional services.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Library guard
        # . Returns
        #   0 when the module may continue loading or was already loaded.
        #   Exits with status 2 when executed directly.
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

# --- Module metadata ----------------------------------------------------------------
    SGND_PACKAGE_MANAGEMENT_MODULE_ID="package-management"
    SGND_PACKAGE_MANAGEMENT_MODULE_NAME="Package Management"
    SGND_PACKAGE_MANAGEMENT_MODULE_VERSION="1.0.0"
    SGND_PACKAGE_MANAGEMENT_MODULE_DESC="Install baseline, role, and optional-service packages and maintain Ubuntu packages"

    SGND_MODULE_NAME="${SGND_PACKAGE_MANAGEMENT_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_PACKAGE_MANAGEMENT_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_PACKAGE_MANAGEMENT_MODULE_DESC}"

# --- Package actions ----------------------------------------------------------------
    # fn: _install_basepackages
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

    # fn: _update_package_index
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

    # fn: _upgrade_installed_packages
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

    # fn: _clean_unused_packages
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

    # fn: _install_samba_ad
        # . Purpose
        #   Install the packages required for a Samba Active Directory Domain Controller.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs Samba AD/DC, Kerberos, and DNS diagnostic packages.
        #   - Stops, disables, and masks standalone Samba services.
        #   - Unmasks and enables the dedicated Samba AD/DC service.
        #   - Leaves domain creation to the separate provisioning action.
        #   - Honors dry-run mode without changing the system.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when installation and service preparation succeed.
        #   Non-zero when a required package or service operation fails.
        #
        # . Usage
        #   _install_samba_ad
    _install_samba_ad() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Samba Active Directory Domain Controller packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing Samba Active Directory Domain Controller packages."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            bind9-dnsutils \
            krb5-user \
            samba-ad-dc || return 1

        sayinfo "Preparing Samba services for AD/DC provisioning."
        sudo systemctl disable --now smbd.service nmbd.service winbind.service 2>/dev/null || true
        sudo systemctl mask smbd.service nmbd.service winbind.service 2>/dev/null || true
        sudo systemctl unmask samba-ad-dc.service || return 1
        sudo systemctl enable samba-ad-dc.service || return 1

        sayinfo "Samba AD/DC packages installed; domain provisioning is still required."
    }

    # fn: _install_ad_client - Install Active Directory client packages
        # . Returns
        #   0 on success; non-zero when package installation fails.
        #
        # . Usage
        #   _install_ad_client
    _install_ad_client() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Active Directory client packages."
            return 0
        fi
        sudo apt-get update || return 1
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            adcli krb5-user libnss-sss libpam-sss packagekit realmd \
            samba-common-bin sssd-ad sssd-tools || return 1
        sayok "Active Directory client packages installed."
    }

    # fn: _install_samba_file
        # . Purpose
        #   Install the packages required for a Samba file server.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs Samba server, client diagnostics, ACL, and xattr tooling.
        #   - Leaves storage and share definitions unchanged.
        #
        # . Returns
        #   0 if the role packages were installed successfully, otherwise non-zero.
        #
        # . Usage
        #   _install_samba_file
    _install_samba_file() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Samba file-server packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing Samba file-server packages."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            acl \
            attr \
            samba \
            smbclient || return 1

        sayinfo "Samba file-server packages installed; share configuration is still required."
    }

    # fn: _install_xrdp
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
        #
        # . Usage
        #   _install_xrdp
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

    # fn: _install_docker
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
        #
        # . Usage
        #   _install_docker
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

# --- Console registration ------------------------------------------------------------
    sgnd_console_register_group "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "$SGND_PACKAGE_MANAGEMENT_MODULE_NAME" "$SGND_PACKAGE_MANAGEMENT_MODULE_DESC" 0 1 110

    sgnd_console_register_item "basepkg" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Install base packages" "_install_basepackages" "Install the Ubuntu baseline packages" 0 5 1
    sgnd_console_register_item "pkgindex" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Update package index" "_update_package_index" "Refresh available package information" 0 5 1
    sgnd_console_register_item "pkgupgrade" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Upgrade installed packages" "_upgrade_installed_packages" "Upgrade installed Ubuntu packages" 0 5 1
    sgnd_console_register_item "pkgclean" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Clean unused packages" "_clean_unused_packages" "Remove unused packages and cached files" 0 5 1

    sgnd_console_register_item "ad-install" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Install AD server" "_install_samba_ad" "Install Samba Active Directory Domain Controller packages" 0 5 1
    sgnd_console_register_item "adc-install" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Install AD client" "_install_ad_client" "Install realmd and SSSD Active Directory client packages" 0 5 1
    sgnd_console_register_item "smb-install" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Install Samba File Server" "_install_samba_file" "Install Samba file-server packages" 0 5 1
    sgnd_console_register_item "instxrdp" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Install XRDP" "_install_xrdp" "Install XRDP for Ubuntu Desktop" 0 5 1
    sgnd_console_register_item "instdocker" "$SGND_PACKAGE_MANAGEMENT_MODULE_ID" "Install Docker" "_install_docker" "Install Docker Engine" 0 5 1
