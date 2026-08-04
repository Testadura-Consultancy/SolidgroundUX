# ==================================================================================
# SolidGroundUX - Optional Roles and Services
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621612
#   Checksum    : c8e9a11e5590ae0c2510204aa2b40a807f14c8da5bcb0bbcdda08e2ad26051b5
#   Source      : 30-optional-roles.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Install optional roles and services
#
# Description:
#   Provides optional, independent services that do not belong to the computer baseline or a dedicated role module.
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
    SGND_OPTIONAL_ROLES_MODULE_ID="optional-roles"
    SGND_OPTIONAL_ROLES_MODULE_NAME="Optional Roles and Services"
    SGND_OPTIONAL_ROLES_MODULE_VERSION="1.0.0"
    SGND_OPTIONAL_ROLES_MODULE_DESC="Install optional server roles and desktop services"

    SGND_MODULE_ID="${SGND_OPTIONAL_ROLES_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_OPTIONAL_ROLES_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_OPTIONAL_ROLES_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_OPTIONAL_ROLES_MODULE_DESC}"

# - Module actions --------------------------------------------------------------
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

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group "$SGND_OPTIONAL_ROLES_MODULE_ID" "$SGND_OPTIONAL_ROLES_MODULE_NAME" "$SGND_OPTIONAL_ROLES_MODULE_DESC" 0 1 300
    sgnd_console_register_item "instxrdp" "$SGND_OPTIONAL_ROLES_MODULE_ID" "Install XRDP" "_install_xrdp" "Install XRDP for Ubuntu Desktop" 0 5 1
    sgnd_console_register_item "instdocker" "$SGND_OPTIONAL_ROLES_MODULE_ID" "Install Docker" "_install_docker" "Install Docker Engine" 0 5 1
