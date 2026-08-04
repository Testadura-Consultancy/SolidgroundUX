# ==================================================================================
# SolidGroundUX - Samba File Server
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621612
#   Checksum    : 0cf4c1b0a4c26ce8f7d277110c21df210fea5afa8a2404bf19e4dc677c10df4d
#   Source      : 25-samba-file-server.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Install and manage standalone Samba file services
#
# Description:
#   Owns standalone Samba file-server installation and status, separate from Active Directory.
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
    SGND_SAMBA_FILE_MODULE_ID="samba-file-server"
    SGND_SAMBA_FILE_MODULE_NAME="Samba File Server"
    SGND_SAMBA_FILE_MODULE_VERSION="1.0.0"
    SGND_SAMBA_FILE_MODULE_DESC="Install and manage a standalone Samba file server"

    SGND_MODULE_ID="${SGND_SAMBA_FILE_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_SAMBA_FILE_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_SAMBA_FILE_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_SAMBA_FILE_MODULE_DESC}"

# - Module actions --------------------------------------------------------------
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
        sudo apt-get install -y \
            acl \
            attr \
            cifs-utils \
            samba \
            smbclient || return 1

        sayinfo "Samba file-server packages installed; share configuration is still required."
    }

    # fn: samba_file_server_status - Show standalone Samba file-server status
        # . Returns
        #   0 after displaying available service and configuration status.
        #
        # . Usage
        #   samba_file_server_status
    samba_file_server_status() {
        local service_state="not installed"
        local config_state="unavailable"

        if command -v smbd >/dev/null 2>&1; then
            service_state="$(systemctl is-active smbd.service 2>/dev/null || true)"
            [[ -n "$service_state" ]] || service_state="inactive"
            if testparm -s >/dev/null 2>&1; then
                config_state="valid"
            else
                config_state="invalid"
            fi
        fi

        sgnd_print
        sgnd_print_sectionheader "Samba File Server"
        sgnd_print_labeledvalue --label "Service" --value "$service_state" --labelwidth 20
        sgnd_print_labeledvalue --label "Configuration" --value "$config_state" --labelwidth 20
    }

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group "$SGND_SAMBA_FILE_MODULE_ID" "$SGND_SAMBA_FILE_MODULE_NAME" "$SGND_SAMBA_FILE_MODULE_DESC" 0 1 250
    sgnd_console_register_item "smb-install" "$SGND_SAMBA_FILE_MODULE_ID" "Install Samba File Server" "_install_samba_file" "Install standalone Samba file-server packages" 0 5 1
    sgnd_console_register_item "smb-status" "$SGND_SAMBA_FILE_MODULE_ID" "Show file-server status" "samba_file_server_status" "Show Samba service and configuration status" 0 15 1
