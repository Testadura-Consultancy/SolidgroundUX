#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Manage Samba Shares
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623316
#   Checksum    : 9d3191d1e6dfb883be5a1f4a6ac6b16cae1c2ca52059d211f24a08c4c0912454
#   Source      : manage-samba-shares.sh
#   Type        : script
#   Group       : System Administration
#   Purpose     : Manage Active Directory access to SolidGroundUX Samba shares
#
# Description:
#   Provides interactive access management for existing SolidGroundUX Samba shares.
#   Share creation and removal remain owned by the Samba File Server console module.
#   This tool assigns AD/NSS groups read-only or read/write access by synchronizing
#   POSIX ACLs with Samba valid-users and write-list restrictions.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail

# --- Bootstrap ----------------------------------------------------------------------
    # fn: _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Returns
        #   0 when the executable common library was loaded.
        #   126 or 127 when bootstrap configuration cannot be resolved.
        #
        # . Usage
        #   _framework_locator || return $?
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="/"
        local reply=""
        local exe_common=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"

        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"
        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"
        else
            if [[ $EUID -eq 0 ]]; then cfg="$cfg_sys"; else cfg="$cfg_user"; fi

            if [[ -t 0 && -t 1 ]]; then
                printf '%s\n' "SolidGroundUX bootstrap configuration" >&2
                printf '%s\n' "No configuration file found." >&2
                printf '%s\n' "Creating: $cfg" >&2
                printf 'SGND_FRAMEWORK_ROOT [/] : ' > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"
                printf 'SGND_APPLICATION_ROOT [%s] : ' "$fw_root" > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in /*) ;; *) return 126 ;; esac
            case "$app_root" in /*) ;; *) return 126 ;; esac

            mkdir -p "$(dirname "$cfg")" || return 127
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127
        fi

        # shellcheck source=/dev/null
        source "$cfg" || return 126
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

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

# --- Script metadata ----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Manage Samba Shares"
    : "${SGND_SCRIPT_DESC:=Assign Active Directory groups and access rights to managed Samba shares.}"
    : "${SGND_SCRIPT_VERSION:=2.0}"
    : "${SGND_SCRIPT_BUILD:=2623211}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

# --- Framework integration -----------------------------------------------------------
    SGND_USING=()
    SGND_ARGS_SPEC=()
    SGND_SCRIPT_EXAMPLES=("  $SGND_SCRIPT_NAME")
    SGND_SCRIPT_GLOBALS=()
    SGND_STATE_VARIABLES=()
    SGND_ON_EXIT_HANDLERS=()
    SGND_STATE_SAVE=0

# --- Local declarations --------------------------------------------------------------
    SGND_SAMBA_CONFIG="/etc/samba/smb.conf"
    SGND_SAMBA_SHARE_ROOT="/srv/storage/shares"
    MANAGED_SHARES=()
    SELECTED_SHARES=()
    DISCOVERED_GROUPS=()

# --- Helpers -------------------------------------------------------------------------
    # fn: _share_path - Resolve the configured path for a Samba share
        # . Returns
        #   Writes the configured path to stdout.
        #
        # . Usage
        #   path="$(_share_path "Documents")"
    _share_path() {
        sudo testparm -s --section-name "$1" --parameter-name path 2>/dev/null || true
    }

    # fn: _list_managed_shares - Discover shares beneath the SolidGroundUX share root
        # . Outputs (globals)
        #   MANAGED_SHARES
        #
        # . Returns
        #   0 when at least one managed share exists; 1 otherwise.
        #
        # . Usage
        #   _list_managed_shares || return $?
    _list_managed_shares() {
        local share=""
        local path=""

        MANAGED_SHARES=()
        command -v testparm >/dev/null 2>&1 || {
            sayfail "Samba testparm is not available."
            return 1
        }

        while IFS= read -r share; do
            [[ -n "$share" ]] || continue
            case "${share,,}" in
                global|printers|print\$) continue ;;
            esac

            path="$(_share_path "$share")"
            [[ "$path" == "$SGND_SAMBA_SHARE_ROOT/"* ]] || continue
            MANAGED_SHARES+=("$share")
        done < <(
            sudo testparm -s 2>/dev/null | \
                awk '/^\[[^]]+\]$/ { name=$0; gsub(/^\[|\]$/, "", name); print name }'
        )

        if (( ${#MANAGED_SHARES[@]} == 0 )); then
            saywarning "No managed Samba shares found beneath $SGND_SAMBA_SHARE_ROOT."
            return 1
        fi

        return 0
    }

    # fn: _select_shares - Select one or more managed shares
        # . Outputs (globals)
        #   SELECTED_SHARES
        #
        # . Returns
        #   0 after selection; 1 when the user returns.
        #
        # . Usage
        #   _select_shares || return $?
    _select_shares() {
        _list_managed_shares || return $?
        SELECTED_SHARES=()
        ask_selection \
            --label "Select Samba share(s)" \
            --var SELECTED_SHARES \
            --multi \
            --items "${MANAGED_SHARES[@]}"
    }

    # fn: _acl_groups_for_share - Return named group ACL entries for one share
        # . Arguments
        #   $1 SHARE
        #
        # . Output
        #   Writes GROUP|PERMISSIONS records.
        #
        # . Usage
        #   _acl_groups_for_share "Documents"
    _acl_groups_for_share() {
        local path=""
        path="$(_share_path "$1")"
        [[ -d "$path" ]] || return 1

        sudo getfacl -cp -- "$path" 2>/dev/null | \
            awk -F: '$1 == "group" && $2 != "" { print $2 "|" $3 }'
    }

    # fn: _discover_ad_groups - Discover domain groups visible through NSS
        # . Purpose
        #   Prefer AD groups exposed by the existing realmd/SSSD identity stack and
        #   include groups already present on selected share ACLs.
        #
        # Outputs (globals):
        #   DISCOVERED_GROUPS
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _discover_ad_groups
    _discover_ad_groups() {
        local realm=""
        local group=""
        local share=""
        local acl_record=""
        local -A seen=()

        DISCOVERED_GROUPS=()
        realm="$(realm list --name-only 2>/dev/null | head -n 1 || true)"

        while IFS=: read -r group _; do
            [[ -n "$group" ]] || continue
            if [[ -n "$realm" ]]; then
                [[ "${group,,}" == *"@${realm,,}" || "${group,,}" == *"\\${realm,,}"* ]] || continue
            fi
            [[ -n "${seen[$group]-}" ]] && continue
            seen["$group"]=1
            DISCOVERED_GROUPS+=("$group")
        done < <(getent group 2>/dev/null || true)

        for share in "${SELECTED_SHARES[@]}"; do
            while IFS= read -r acl_record; do
                group="${acl_record%%|*}"
                [[ -n "$group" && -z "${seen[$group]-}" ]] || continue
                seen["$group"]=1
                DISCOVERED_GROUPS+=("$group")
            done < <(_acl_groups_for_share "$share" || true)
        done

        if (( ${#DISCOVERED_GROUPS[@]} > 1 )); then
            mapfile -t DISCOVERED_GROUPS < <(printf '%s\n' "${DISCOVERED_GROUPS[@]}" | LC_ALL=C sort -fu)
        fi
        return 0
    }

    # fn: _select_group - Select or enter an AD/NSS group
        # . Arguments
        #   $1 OUTPUT_VAR
        #
        # . Returns
        #   0 with a resolvable group; 1 on cancellation.
        #
        # . Usage
        #   _select_group group_name || return $?
    _select_group() {
        local output_var="$1"
        local selected=""
        local entered=""
        local -a choices=()

        _discover_ad_groups
        choices=("${DISCOVERED_GROUPS[@]}" "Enter group manually")

        ask_selection \
            --label "Select Active Directory group" \
            --var selected \
            --items "${choices[@]}" || return 1

        if [[ "$selected" == "Enter group manually" ]]; then
            ask --label "AD/NSS group" --var entered || return $?
            selected="$entered"
        fi

        if ! getent group "$selected" >/dev/null 2>&1; then
            sayfail "Group cannot be resolved through NSS: $selected"
            return 1
        fi

        printf -v "$output_var" '%s' "$selected"
        return 0
    }

    # fn: _samba_principal - Format an NSS group for a Samba user-list parameter
        # . Output
        #   Writes a quoted Samba group principal.
        #
        # . Usage
        #   _samba_principal "domain admins@testadura.hq"
    _samba_principal() {
        local group="${1//\"/}"
        printf '@"%s"' "$group"
    }

    # fn: _sync_share_samba_access - Synchronize Samba access lists from POSIX ACLs
        # . Arguments
        #   $1 SHARE
        #
        # . Returns
        #   0 when smb.conf validates and reload succeeds; non-zero otherwise.
        #
        # . Usage
        #   _sync_share_samba_access "Documents"
    _sync_share_samba_access() {
        local share="$1"
        local group=""
        local perms=""
        local principal=""
        local valid_users=""
        local write_list=""
        local temp_file=""
        local backup=""
        local have_groups=0

        while IFS='|' read -r group perms; do
            [[ -n "$group" ]] || continue
            principal="$(_samba_principal "$group")"
            [[ -n "$valid_users" ]] && valid_users+=" "
            valid_users+="$principal"
            have_groups=1

            if [[ "$perms" == *w* ]]; then
                [[ -n "$write_list" ]] && write_list+=" "
                write_list+="$principal"
            fi
        done < <(_acl_groups_for_share "$share")

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would synchronize Samba access for '$share'."
            return 0
        fi

        temp_file="$(mktemp)" || return 1
        backup="$SGND_SAMBA_CONFIG.pre-access.$(date +%Y%m%d%H%M%S)"
        sudo cp -a "$SGND_SAMBA_CONFIG" "$backup" || { rm -f "$temp_file"; return 1; }

        awk \
            -v target="$share" \
            -v valid="$valid_users" \
            -v writers="$write_list" \
            -v managed="$have_groups" '
            BEGIN { in_target=0 }
            /^\[[^]]+\][[:space:]]*$/ {
                name=$0
                gsub(/^\[|\][[:space:]]*$/, "", name)
                in_target=(tolower(name) == tolower(target))
                print
                if (in_target && managed) {
                    print "    read only = yes"
                    print "    valid users = " valid
                    if (writers != "") print "    write list = " writers
                }
                next
            }
            in_target && /^[[:space:]]*(valid users|write list)[[:space:]]*=/ { next }
            in_target && managed && /^[[:space:]]*read only[[:space:]]*=/ { next }
            { print }
        ' "$SGND_SAMBA_CONFIG" > "$temp_file" || { rm -f "$temp_file"; return 1; }

        sudo install -o root -g root -m 0644 "$temp_file" "$SGND_SAMBA_CONFIG" || {
            rm -f "$temp_file"
            return 1
        }
        rm -f "$temp_file"

        if ! sudo testparm -s >/dev/null 2>&1; then
            sudo cp -a "$backup" "$SGND_SAMBA_CONFIG"
            sayfail "Samba configuration validation failed; previous configuration restored."
            return 1
        fi

        sudo systemctl reload smbd.service 2>/dev/null || sudo systemctl restart smbd.service || {
            sudo cp -a "$backup" "$SGND_SAMBA_CONFIG"
            sayfail "Samba reload failed; previous configuration restored."
            return 1
        }

        return 0
    }

    # fn: _apply_group_access - Apply read or write ACLs to selected shares
        # . Arguments
        #   $1 MODE - read or write
        #
        # . Returns
        #   0 after all selected shares are updated; non-zero on failure.
        #
        # . Usage
        #   _apply_group_access write
    _apply_group_access() {
        local mode="$1"
        local group=""
        local share=""
        local path=""
        local perms="r-x"

        [[ "$mode" == "write" ]] && perms="rwx"
        _select_group group || return $?

        for share in "${SELECTED_SHARES[@]}"; do
            path="$(_share_path "$share")"
            [[ -d "$path" ]] || { sayfail "Share path not found: $path"; return 1; }

            if (( ${FLAG_DRYRUN:-0} == 1 )); then
                sayinfo "Dry run: Would grant $mode access to '$group' on '$share'."
                continue
            fi

            sudo setfacl -m "g:$group:$perms" -m "m::rwx" -- "$path" || return 1
            sudo setfacl -m "d:g:$group:$perms" -m "d:m::rwx" -- "$path" || return 1
            _sync_share_samba_access "$share" || return $?
            sayok "Granted $mode access to '$group' on '$share'."
        done

        return 0
    }

    # fn: _remove_group_access - Remove one AD/NSS group's access from selected shares
        # . Returns
        #   0 after all selected shares are updated; non-zero on failure.
        #
        # . Usage
        #   _remove_group_access
    _remove_group_access() {
        local group=""
        local share=""
        local path=""
        local group_count=0
        local group_present=0

        _select_group group || return $?

        for share in "${SELECTED_SHARES[@]}"; do
            path="$(_share_path "$share")"
            [[ -d "$path" ]] || { sayfail "Share path not found: $path"; return 1; }

            group_count=0
            group_present=0
            while IFS='|' read -r acl_group _; do
                [[ -n "$acl_group" ]] || continue
                group_count=$((group_count + 1))
                [[ "$acl_group" == "$group" ]] && group_present=1
            done < <(_acl_groups_for_share "$share" || true)

            (( group_present )) || {
                saywarning "Group '$group' is not assigned to '$share'."
                continue
            }

            if (( group_count <= 1 )); then
                saywarning "Cannot remove the last managed group from '$share'; assign a replacement group first."
                continue
            fi

            if (( ${FLAG_DRYRUN:-0} == 1 )); then
                sayinfo "Dry run: Would remove '$group' from '$share'."
                continue
            fi

            sudo setfacl -x "g:$group" -- "$path" 2>/dev/null || true
            sudo setfacl -x "d:g:$group" -- "$path" 2>/dev/null || true
            _sync_share_samba_access "$share" || return $?
            sayok "Removed '$group' access from '$share'."
        done

        return 0
    }

    # fn: _show_access - Display current share paths and named group ACLs
        # . Returns
        #   0 after displaying access state.
        #
        # . Usage
        #   _show_access
    _show_access() {
        local share=""
        local path=""
        local group=""
        local perms=""
        local role=""
        local count=0

        for share in "${SELECTED_SHARES[@]}"; do
            path="$(_share_path "$share")"
            sgnd_print
            sgnd_print_sectionheader --text "$share"
            sgnd_print_labeledvalue --label "Path" --value "$path" --labelwidth 20
            count=0

            while IFS='|' read -r group perms; do
                [[ -n "$group" ]] || continue
                role="Read only"
                [[ "$perms" == *w* ]] && role="Read / write"
                sgnd_print_labeledvalue --label "$group" --value "$role ($perms)" --labelwidth 30
                count=$((count + 1))
            done < <(_acl_groups_for_share "$share" || true)

            (( count > 0 )) || sgnd_print --text "No named group ACLs assigned." --pad 2
        done
        return 0
    }

    # fn: _validate_selected - Validate selected share paths, ACLs, and Samba configuration
        # . Returns
        #   0 when selected shares validate; 1 otherwise.
        #
        # . Usage
        #   _validate_selected
    _validate_selected() {
        local share=""
        local path=""
        local failures=0

        sudo testparm -s >/dev/null 2>&1 || { sayfail "Samba configuration is invalid."; failures=$((failures + 1)); }

        for share in "${SELECTED_SHARES[@]}"; do
            path="$(_share_path "$share")"
            if [[ "$path" == "$SGND_SAMBA_SHARE_ROOT/"* && -d "$path" ]]; then
                sayok "Share '$share' path is available."
            else
                sayfail "Share '$share' path is invalid: $path"
                failures=$((failures + 1))
            fi

            sudo getfacl -cp -- "$path" >/dev/null 2>&1 || {
                sayfail "ACL cannot be read for '$share'."
                failures=$((failures + 1))
            }
        done

        (( failures == 0 ))
    }

# --- Main ---------------------------------------------------------------------------
    # fn: main - Run interactive Samba share access management
        # . Returns
        #   0 after normal exit; non-zero when startup requirements fail.
        #
        # . Usage
        #   main "$@"
    main() {
        local action=""
        local -a actions=(
            "Show access"
            "Grant read-only access to AD group"
            "Grant read/write access to AD group"
            "Remove AD group access"
            "Validate selected shares"
            "Select different shares"
        )

        _framework_locator || return $?
        sgnd_exe_start -- "$@" || return $?

        command -v setfacl >/dev/null 2>&1 || { sayfail "setfacl is not installed."; return 1; }
        command -v getfacl >/dev/null 2>&1 || { sayfail "getfacl is not installed."; return 1; }
        [[ -r "$SGND_SAMBA_CONFIG" ]] || { sayfail "Samba configuration not found: $SGND_SAMBA_CONFIG"; return 1; }
        [[ -d "$SGND_SAMBA_SHARE_ROOT" ]] || { sayfail "Share root not found: $SGND_SAMBA_SHARE_ROOT"; return 1; }

        while :; do
            if (( ${#SELECTED_SHARES[@]} == 0 )); then
                _select_shares || return 0
            fi

            action=""
            ask_selection \
                --label "Manage selected Samba shares" \
                --var action \
                --items "${actions[@]}" || return 0

            case "$action" in
                "Show access")
                    _show_access
                    ;;
                "Grant read-only access to AD group")
                    _apply_group_access read || true
                    ;;
                "Grant read/write access to AD group")
                    _apply_group_access write || true
                    ;;
                "Remove AD group access")
                    _remove_group_access || true
                    ;;
                "Validate selected shares")
                    _validate_selected || true
                    ;;
                "Select different shares")
                    SELECTED_SHARES=()
                    ;;
            esac
        done
    }

    main "$@"
