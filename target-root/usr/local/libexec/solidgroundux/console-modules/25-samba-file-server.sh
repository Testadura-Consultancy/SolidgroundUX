# ==================================================================================
# SolidGroundUX - Samba File Server
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621804
#   Checksum    : -
#   Source      : 25-samba-file-server-v2.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Install and manage Samba file services
#
# Description:
#   Owns Samba file-server installation and service status. Storage provisioning is
#   provided separately by the Storage module, while share and access-control
#   management remain part of this module.
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

# - Module metadata -------------------------------------------------------------
    SGND_SAMBA_FILE_MODULE_ID="samba-file-server"
    SGND_SAMBA_FILE_MODULE_NAME="Samba File Server"
    SGND_SAMBA_FILE_MODULE_VERSION="1.0.0"
    SGND_SAMBA_FILE_MODULE_DESC="Install and manage Samba file services"

    SGND_MODULE_ID="${SGND_SAMBA_FILE_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_SAMBA_FILE_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_SAMBA_FILE_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_SAMBA_FILE_MODULE_DESC}"

    SGND_SAMBA_SHARE_ROOT="/srv/storage/shares"
    SGND_SAMBA_CONFIG="/etc/samba/smb.conf"

# - Internal helpers -------------------------------------------------------------
    # fn$ _samba_validate_share_name
        # . Purpose
        #   Validate a Samba share name used for its directory and configuration section.
        #
        # Inputs:
        #   $1 - Proposed share name.
        #
        # . Returns
        #   0 for a safe share name, otherwise 1.
        #
        # . Usage
        #   _samba_validate_share_name "Public"
    _samba_validate_share_name() {
        local share_name="${1:-}"

        [[ "$share_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]
    }

    # fn$ _samba_require_share_root
        # . Purpose
        #   Require mounted SolidGroundUX storage and its standard shares directory.
        #
        # . Returns
        #   0 when the share root is ready, otherwise 1.
        #
        # . Usage
        #   _samba_require_share_root
    _samba_require_share_root() {
        if ! mountpoint -q /srv/storage; then
            sayfail "SolidGroundUX storage is not mounted at /srv/storage."
            return 1
        fi

        if [[ ! -d "$SGND_SAMBA_SHARE_ROOT" ]]; then
            sayfail "The Samba share root does not exist: $SGND_SAMBA_SHARE_ROOT"
            return 1
        fi

        return 0
    }

    # fn$ _samba_share_exists
        # . Purpose
        #   Determine whether a named share exists in the Samba configuration.
        #
        # Inputs:
        #   $1 - Share name.
        #
        # . Returns
        #   0 when the share exists, otherwise 1.
    _samba_share_exists() {
        local share_name="$1"

        [[ -r "$SGND_SAMBA_CONFIG" ]] || return 1
        grep -Eqi "^[[:space:]]*\\[$share_name\\][[:space:]]*$" "$SGND_SAMBA_CONFIG"
    }

    # fn$ _samba_reload_configuration
        # . Purpose
        #   Validate the Samba configuration and reload the file-server service.
        #
        # . Returns
        #   0 when validation and reload succeed, otherwise non-zero.
    _samba_reload_configuration() {
        sudo testparm -s >/dev/null 2>&1 || {
            sayfail "The generated Samba configuration is invalid."
            return 1
        }

        sudo systemctl reload smbd.service || sudo systemctl restart smbd.service
    }

# - Module actions --------------------------------------------------------------
    # fn$ _install_samba_file
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

    # fn$ samba_file_server_status
        # . Purpose
        #   Display Samba service, configuration, and storage readiness status.
        #
        # . Behavior
        #   - Checks whether the Samba server is installed and active.
        #   - Validates the current Samba configuration.
        #   - Reports whether the standard storage and share roots are available.
        #
        # Outputs (console):
        #   Samba service, configuration, and storage readiness status.
        #
        # . Returns
        #   0 after displaying available status information.
        #
        # . Usage
        #   samba_file_server_status
    samba_file_server_status() {
        local service_state="not installed"
        local config_state="unavailable"
        local storage_state="not configured"
        local share_root_state="not available"

        if command -v smbd >/dev/null 2>&1; then
            service_state="$(systemctl is-active smbd.service 2>/dev/null || true)"
            [[ -n "$service_state" ]] || service_state="inactive"

            if testparm -s >/dev/null 2>&1; then
                config_state="valid"
            else
                config_state="invalid"
            fi
        fi

        if mountpoint -q /srv/storage; then
            storage_state="mounted"
            [[ -d "$SGND_SAMBA_SHARE_ROOT" ]] && share_root_state="available"
        fi

        sgnd_print
        sgnd_print_sectionheader "Samba File Server"
        sgnd_print_labeledvalue --label "Service" --value "$service_state" --labelwidth 20
        sgnd_print_labeledvalue --label "Configuration" --value "$config_state" --labelwidth 20
        sgnd_print_labeledvalue --label "Storage" --value "$storage_state" --labelwidth 20
        sgnd_print_labeledvalue --label "Share root" --value "$share_root_state" --labelwidth 20
    }

    # fn$ samba_create_share
        # . Purpose
        #   Create a directory-backed Samba share beneath the standard share root.
        #
        # . Behavior
        #   - Requires mounted SolidGroundUX storage.
        #   - Asks for share name, description, browse visibility, and read-only mode.
        #   - Creates the backing directory.
        #   - Appends a SolidGroundUX-managed share section to smb.conf.
        #   - Validates and reloads Samba.
        #   - Honors console dry-run mode.
        #
        # . Returns
        #   0 when the share is created or cancelled, otherwise non-zero.
        #
        # . Usage
        #   samba_create_share
    samba_create_share() {
        local share_name=""
        local comment=""
        local browsable="YES"
        local read_only="NO"
        local decision="NO"
        local share_path=""
        local config_backup=""

        _samba_require_share_root || return 1
        command -v testparm >/dev/null 2>&1 || {
            sayfail "Samba is not installed."
            return 1
        }

        ask --label "Share name" --var share_name --validate _samba_validate_share_name || return $?
        _samba_share_exists "$share_name" && {
            sayfail "A Samba share named '$share_name' already exists."
            return 1
        }

        share_path="$SGND_SAMBA_SHARE_ROOT/$share_name"
        [[ ! -e "$share_path" ]] || {
            sayfail "The share directory already exists: $share_path"
            return 1
        }

        comment="$share_name share"
        ask --label "Description" --var comment --default "$comment" || return $?
        ask_decision --label "Browsable" --choices "YES|Y,NO|N" --default "YES" --var browsable || return $?
        ask_decision --label "Read only" --choices "YES|Y,NO|N" --default "NO" --var read_only || return $?

        sgnd_print
        sgnd_print_sectionheader "Create Samba share"
        sgnd_print_labeledvalue --label "Share" --value "$share_name" --labelwidth 20
        sgnd_print_labeledvalue --label "Path" --value "$share_path" --labelwidth 20
        sgnd_print_labeledvalue --label "Description" --value "$comment" --labelwidth 20
        sgnd_print_labeledvalue --label "Browsable" --value "$browsable" --labelwidth 20
        sgnd_print_labeledvalue --label "Read only" --value "$read_only" --labelwidth 20

        ask_decision --label "Create this share?" --choices "YES|Y,NO|N" --default "NO" --var decision || return $?
        [[ "$decision" == "YES" ]] || {
            sayinfo "Share creation cancelled."
            return 0
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would create Samba share '$share_name' at $share_path."
            return 0
        fi

        config_backup="$SGND_SAMBA_CONFIG.pre-share.$(date +%Y%m%d%H%M%S)"
        sudo cp -a "$SGND_SAMBA_CONFIG" "$config_backup" || return 1
        sudo install -d -m 0770 "$share_path" || return 1

        printf '%s\n' \
            '' \
            "# SolidGroundUX managed share: $share_name" \
            "[$share_name]" \
            "    path = $share_path" \
            "    comment = $comment" \
            "    browseable = ${browsable,,}" \
            "    read only = ${read_only,,}" \
            '    guest ok = no' \
            '    create mask = 0660' \
            '    directory mask = 0770' | \
            sudo tee -a "$SGND_SAMBA_CONFIG" >/dev/null || return 1

        if ! _samba_reload_configuration; then
            sudo cp -a "$config_backup" "$SGND_SAMBA_CONFIG"
            sudo rm -rf -- "$share_path"
            return 1
        fi

        sayok "Samba share '$share_name' created successfully."
    }

    # fn: samba_list_shares - List configured Samba shares
        # . Returns
        #   0 after listing configured shares, otherwise non-zero.
    samba_list_shares() {
        command -v testparm >/dev/null 2>&1 || {
            sayfail "Samba is not installed."
            return 1
        }

        sgnd_print
        sgnd_print_sectionheader "Configured Samba shares"
        sudo testparm -s 2>/dev/null | awk '/^\[[^]]+\]$/ { name=$0; gsub(/^\[|\]$/, "", name); if (tolower(name) != "global") print name }'
    }

    # fn$ samba_remove_share
        # . Purpose
        #   Remove a SolidGroundUX-managed Samba share definition.
        #
        # . Behavior
        #   - Removes the managed share section from smb.conf.
        #   - Optionally removes the backing directory and its contents.
        #   - Validates and reloads Samba after the change.
        #   - Honors console dry-run mode.
        #
        # . Returns
        #   0 when the share is removed or cancelled, otherwise non-zero.
        #
        # . Usage
        #   samba_remove_share
    samba_remove_share() {
        local share_name=""
        local remove_data="NO"
        local decision="NO"
        local share_path=""
        local config_backup=""
        local temp_file=""

        command -v testparm >/dev/null 2>&1 || {
            sayfail "Samba is not installed."
            return 1
        }

        ask --label "Share name" --var share_name --validate _samba_validate_share_name || return $?
        _samba_share_exists "$share_name" || {
            sayfail "No Samba share named '$share_name' exists."
            return 1
        }

        share_path="$(sudo testparm -s --section-name "$share_name" --parameter-name path 2>/dev/null || true)"
        [[ "$share_path" == "$SGND_SAMBA_SHARE_ROOT/"* ]] || {
            sayfail "The share is not managed beneath $SGND_SAMBA_SHARE_ROOT."
            return 1
        }

        ask_decision --label "Delete share data" --choices "YES|Y,NO|N" --default "NO" --var remove_data || return $?
        ask_decision --label "Remove share '$share_name'?" --choices "YES|Y,NO|N" --default "NO" --var decision || return $?
        [[ "$decision" == "YES" ]] || {
            sayinfo "Share removal cancelled."
            return 0
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would remove Samba share '$share_name'."
            return 0
        fi

        config_backup="$SGND_SAMBA_CONFIG.pre-remove.$(date +%Y%m%d%H%M%S)"
        temp_file="$(mktemp)" || return 1
        sudo cp -a "$SGND_SAMBA_CONFIG" "$config_backup" || { rm -f "$temp_file"; return 1; }

        sudo awk -v section="$share_name" '
            BEGIN { skip = 0 }
            /^\[[^]]+\][[:space:]]*$/ {
                current = $0
                gsub(/^\[|\][[:space:]]*$/, "", current)
                skip = (tolower(current) == tolower(section))
            }
            !skip { print }
        ' "$SGND_SAMBA_CONFIG" > "$temp_file" || { rm -f "$temp_file"; return 1; }

        sudo install -o root -g root -m 0644 "$temp_file" "$SGND_SAMBA_CONFIG" || { rm -f "$temp_file"; return 1; }
        rm -f "$temp_file"

        if ! _samba_reload_configuration; then
            sudo cp -a "$config_backup" "$SGND_SAMBA_CONFIG"
            return 1
        fi

        if [[ "$remove_data" == "YES" ]]; then
            sudo rm -rf -- "$share_path" || return 1
        fi

        sayok "Samba share '$share_name' removed successfully."
    }

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group \
        "$SGND_SAMBA_FILE_MODULE_ID" \
        "$SGND_SAMBA_FILE_MODULE_NAME" \
        "$SGND_SAMBA_FILE_MODULE_DESC" \
        0 \
        1 \
        250

    sgnd_console_register_item \
        "smb-install" \
        "$SGND_SAMBA_FILE_MODULE_ID" \
        "Install Samba File Server" \
        "_install_samba_file" \
        "Install Samba file-server packages" \
        0 \
        5 \
        1

    sgnd_console_register_item \
        "smb-share-create" \
        "$SGND_SAMBA_FILE_MODULE_ID" \
        "Create share" \
        "samba_create_share" \
        "Create and publish a directory beneath the storage share root" \
        0 \
        10 \
        1

    sgnd_console_register_item \
        "smb-share-list" \
        "$SGND_SAMBA_FILE_MODULE_ID" \
        "List shares" \
        "samba_list_shares" \
        "List configured Samba shares" \
        0 \
        15 \
        1

    sgnd_console_register_item \
        "smb-share-remove" \
        "$SGND_SAMBA_FILE_MODULE_ID" \
        "Remove share" \
        "samba_remove_share" \
        "Remove a managed Samba share and optionally its data" \
        0 \
        20 \
        1

    sgnd_console_register_item \
        "smb-status" \
        "$SGND_SAMBA_FILE_MODULE_ID" \
        "Show file-server status" \
        "samba_file_server_status" \
        "Show Samba service, configuration, and storage status" \
        0 \
        25 \
        1
