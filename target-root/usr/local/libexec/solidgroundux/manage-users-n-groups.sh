#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Manage Users and Groups
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : 0a1bb3592537414435e4c3cd26c92b766ab2f7f1cec25149d041bfc7fb4deb2e
#   Source      : manage-users-n-groups.sh
#   Type        : script
#   Group       : System Administration
#   Purpose     : Interactively manage Samba Active Directory users and groups
#
# Description:
#   Provides one selection-oriented workflow for creating, inspecting, and changing
#   Samba Active Directory users and groups. It supports bulk selection, membership
#   management in either direction, and a local crossover report showing POSIX ACL
#   access to SolidGroundUX-managed Samba shares when those shares are present.
#
# Design principles:
#   - Users and groups are discovered from the provisioned Samba directory
#   - Numbered selections accept individual values, ranges, or all entries
#   - Membership changes use one shared implementation from either workflow
#   - Destructive operations require explicit confirmation
#   - Share permission reporting is local and evidence-based; no remote server is assumed
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# - Bootstrap -----------------------------------------------------------------------
    # fn$ _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Purpose
        #   Locate or create the bootstrap configuration and load the executable runtime.
        #
        # . Returns
        #   0 when the runtime was loaded; 126 or 127 on bootstrap failure.
        #
        # . Usage
        #   _framework_locator || exit $?
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="/"
        local reply=""
        local exe_common=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"
        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"
        else
            [[ $EUID -eq 0 ]] && cfg="$cfg_sys" || cfg="$cfg_user"
            if [[ -t 0 && -t 1 ]]; then
                printf '%s\n' "SolidGroundUX bootstrap configuration" "No configuration file found." "Creating: $cfg"
                printf 'SGND_FRAMEWORK_ROOT [/] : ' >/dev/tty
                read -r reply </dev/tty
                fw_root="${reply:-/}"
                printf 'SGND_APPLICATION_ROOT [%s] : ' "$fw_root" >/dev/tty
                read -r reply </dev/tty
                app_root="${reply:-$fw_root}"
            fi
            [[ "$fw_root" == /* && "$app_root" == /* ]] || return 126
            mkdir -p "$(dirname "$cfg")" || return 127
            printf '%s\n%s\n\nSGND_FRAMEWORK_ROOT=%q\nSGND_APPLICATION_ROOT=%q\n' \
                '# SolidGroundUX bootstrap configuration' '# Auto-generated on first run' \
                "$fw_root" "$app_root" >"$cfg" || return 127
        fi

        # shellcheck source=/dev/null
        source "$cfg" || return 126
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        [[ -r "$exe_common" ]] || { printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2; return 126; }
        # shellcheck source=/dev/null
        source "$exe_common"
    }

# - Script identity -----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Manage Users and Groups"
    SGND_SCRIPT_DESC="Manage Samba Active Directory accounts, memberships, and local share access."

# - Framework integration -----------------------------------------------------------
    SGND_USING=()
    SGND_ARGS_SPEC=()
    SGND_SCRIPT_EXAMPLES=(
        "Start the interactive account manager:" "  $SGND_SCRIPT_NAME" ""
        "Preview changes without applying them:" "  $SGND_SCRIPT_NAME --dryrun"
    )
    SGND_SCRIPT_GLOBALS=()
    SGND_STATE_VARIABLES=()
    SGND_ON_EXIT_HANDLERS=()
    SGND_STATE_SAVE=0

# - Local script declarations -------------------------------------------------------
    SGND_SAMBA_SHARE_ROOT="/srv/storage/shares"
    USERS=()
    # GROUPS is a Bash special array containing the current process group IDs.
    # Use AD_GROUPS for Active Directory group names to avoid clobbering it.
    AD_GROUPS=()
    SELECTED_USERS=()
    SELECTED_GROUPS=()

# - Discovery and selection ---------------------------------------------------------
    # fn: _require_directory - Require a provisioned Samba Active Directory
        # . Returns
        #   0 when samba-tool can query users and groups; otherwise 1.
    _require_directory() {
        command -v samba-tool >/dev/null 2>&1 || { sayfail "samba-tool is unavailable."; return 1; }
        sudo samba-tool user list >/dev/null 2>&1 || { sayfail "A queryable Samba Active Directory domain was not found."; return 1; }
    }

    # fn: _refresh_accounts - Refresh the available users and groups
        # . Outputs (globals)
        #   USERS, AD_GROUPS
    _refresh_accounts() {
        mapfile -t USERS < <(sudo samba-tool user list 2>/dev/null | LC_ALL=C sort -f)
        mapfile -t AD_GROUPS < <(sudo samba-tool group list 2>/dev/null | LC_ALL=C sort -f)
    }

    # fn: _parse_selection - Parse numbers, ranges, or A into zero-based indexes
        # . Arguments
        #   $1 selection expression; $2 item count; $3 output array name.
    _parse_selection() {
        local expression="${1//[[:space:]]/}"
        local count="$2"
        local output_name="$3"
        local part="" start=0 end=0 value=0
        local -a parts=() result=()
        local -A seen=()

        if [[ "${expression^^}" == "A" ]]; then
            for ((value=0; value<count; value++)); do result+=("$value"); done
            eval "$output_name=(\"\${result[@]}\")"
            return 0
        fi

        IFS=',' read -r -a parts <<<"$expression"
        for part in "${parts[@]}"; do
            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start="${BASH_REMATCH[1]}"; end="${BASH_REMATCH[2]}"
                (( start >= 1 && end >= start && end <= count )) || return 1
                for ((value=start; value<=end; value++)); do seen[$((value-1))]=1; done
            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                value="$part"; (( value >= 1 && value <= count )) || return 1
                seen[$((value-1))]=1
            else
                return 1
            fi
        done
        for ((value=0; value<count; value++)); do [[ -n "${seen[$value]:-}" ]] && result+=("$value"); done
        (( ${#result[@]} > 0 )) || return 1
        eval "$output_name=(\"\${result[@]}\")"
    }

    # fn: _select_items - Display and select users or groups
        # . Arguments
        #   $1 title; $2 source array name; $3 output array name.
    _select_items() {
        local title="$1" source_name="$2" output_name="$3" selection="" index=0
        local -a source=()
        eval 'source=("${'"$source_name"'[@]}")'
        (( ${#source[@]} > 0 )) || { saywarning "No $title are available."; return 1; }
        while true; do
            sgnd_print
            sgnd_print_sectionheader "Available $title"
            for index in "${!source[@]}"; do printf '  %3d) %s\n' "$((index+1))" "${source[$index]}"; done
            sgnd_print "Enter numbers, comma-separated values, ranges such as 2-5, A for all, or Q to return."
            ask --label "Select $title" --var selection --colorize both

            if [[ "${selection^^}" == "Q" ]]; then
                return 2
            fi

            _parse_selection "$selection" "${#source[@]}" "$output_name" && return 0
            saywarning "Invalid selection: $selection"
        done
    }

    # fn: _selected_names - Resolve selected indexes to names
        # . Arguments
        #   $1 source array name; $2 index array name; $3 output array name.
    _selected_names() {
        local source_name="$1" indexes_name="$2" output_name="$3" index=0
        local -a source=() indexes=() result=()
        eval 'source=("${'"$source_name"'[@]}")'
        eval 'indexes=("${'"$indexes_name"'[@]}")'
        for index in "${indexes[@]}"; do result+=("${source[$index]}"); done
        eval "$output_name=(\"\${result[@]}\")"
    }

    # fn: _show_current_selection - Display the active user or group selection
        # . Arguments
        #   $1 label; $2 source array name; $3 selected-index array name.
        #
        # . Returns
        #   0 after rendering the active selection.
    _show_current_selection() {
        local label="$1"
        local source_name="$2"
        local indexes_name="$3"
        local -a names=()

        _selected_names "$source_name" "$indexes_name" names
        sgnd_print_labeledmultivalue             --label "$label"             --labelwidth 20             --items "${names[@]}"
    }

# - Information ---------------------------------------------------------------------
    # fn: _show_user_info - Show selected users, memberships, and local share ACLs
    _show_user_info() {
        local -a names=() groups=() shares=()
        local user="" share="" acl_line=""
        _selected_names USERS SELECTED_USERS names
        for user in "${names[@]}"; do
            mapfile -t groups < <(sudo samba-tool user getgroups "$user" 2>/dev/null | LC_ALL=C sort -f)
            sgnd_print; sgnd_print_sectionheader "User: $user"
            sgnd_print_labeledmultivalue --label "Groups" --labelwidth 20 --items "${groups[@]:-None}"
            shares=()
            if [[ -d "$SGND_SAMBA_SHARE_ROOT" ]] && command -v getfacl >/dev/null 2>&1; then
                while IFS= read -r share; do
                    acl_line="$(getfacl -cp "$share" 2>/dev/null | awk -F: -v u="$user" '$1=="user" && tolower($2)==tolower(u) {print $3; exit}')"
                    [[ -n "$acl_line" ]] && shares+=("$(basename "$share") ($acl_line)")
                done < <(find "$SGND_SAMBA_SHARE_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | LC_ALL=C sort)
            fi
            sgnd_print_labeledmultivalue --label "Local share ACLs" --labelwidth 20 --items "${shares[@]:-None detected}"
        done
    }

    # fn: _show_group_info - Show selected groups, members, and local share ACLs
    _show_group_info() {
        local -a names=() members=() shares=()
        local group="" share="" acl_line=""
        _selected_names AD_GROUPS SELECTED_GROUPS names
        for group in "${names[@]}"; do
            mapfile -t members < <(sudo samba-tool group listmembers "$group" 2>/dev/null | LC_ALL=C sort -f)
            sgnd_print; sgnd_print_sectionheader "Group: $group"
            sgnd_print_labeledmultivalue --label "Members" --labelwidth 20 --items "${members[@]:-None}"
            shares=()
            if [[ -d "$SGND_SAMBA_SHARE_ROOT" ]] && command -v getfacl >/dev/null 2>&1; then
                while IFS= read -r share; do
                    acl_line="$(getfacl -cp "$share" 2>/dev/null | awk -F: -v g="$group" '$1=="group" && tolower($2)==tolower(g) {print $3; exit}')"
                    [[ -n "$acl_line" ]] && shares+=("$(basename "$share") ($acl_line)")
                done < <(find "$SGND_SAMBA_SHARE_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | LC_ALL=C sort)
            fi
            sgnd_print_labeledmultivalue --label "Local share ACLs" --labelwidth 20 --items "${shares[@]:-None detected}"
        done
    }

# - Creation and user actions -------------------------------------------------------
    # fn: _create_user - Create an Active Directory user
    _create_user() {
        local name="" decision="NO"
        ask --label "User name" --var name --validate sgnd_validate_text || return $?
        ask_decision --label "Create user '$name'?" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0
        (( ${FLAG_DRYRUN:-0} )) && { sayinfo "Dry run: Would create user $name."; return 0; }
        sudo samba-tool user create "$name" </dev/tty && sayok "Created user $name."
        _refresh_accounts
    }

    # fn: _create_group - Create an Active Directory group
    _create_group() {
        local name="" decision="NO"
        ask --label "Group name" --var name --validate sgnd_validate_text || return $?
        ask_decision --label "Create group '$name'?" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0
        (( ${FLAG_DRYRUN:-0} )) && { sayinfo "Dry run: Would create group $name."; return 0; }
        sudo samba-tool group add "$name" && sayok "Created group $name."
        _refresh_accounts
    }

    # fn: _apply_user_command - Apply a samba-tool user command to selected users
        # . Arguments
        #   $1 command; $2 description.
    _apply_user_command() {
        local command="$1" description="$2" decision="NO" user=""
        local -a names=()
        _selected_names USERS SELECTED_USERS names
        ask_decision --label "$description selected users?" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0
        for user in "${names[@]}"; do
            if (( ${FLAG_DRYRUN:-0} )); then sayinfo "Dry run: Would $command user $user."; continue; fi
            case "$command" in
                enable) sudo samba-tool user enable "$user" ;;
                disable) sudo samba-tool user disable "$user" ;;
                noexpiry) sudo samba-tool user setexpiry "$user" --noexpiry ;;
                delete) sudo samba-tool user delete "$user" ;;
            esac || return 1
            sayok "$description: $user"
        done
        _refresh_accounts
    }

    # fn: _change_passwords - Change passwords for selected users one at a time
    _change_passwords() {
        local user=""
        local -a names=()
        _selected_names USERS SELECTED_USERS names
        for user in "${names[@]}"; do
            (( ${FLAG_DRYRUN:-0} )) && { sayinfo "Dry run: Would change password for $user."; continue; }
            sayinfo "Enter the new password for $user."
            sudo samba-tool user setpassword "$user" </dev/tty || return 1
        done
    }

# - Membership management -----------------------------------------------------------
    # fn: _change_membership - Add or remove selected users from selected groups
        # . Arguments
        #   $1 add|remove.
    _change_membership() {
        local operation="$1" decision="NO" user="" group=""
        local -a user_names=() group_names=()
        _selected_names USERS SELECTED_USERS user_names
        _selected_names AD_GROUPS SELECTED_GROUPS group_names
        local prompt="Add selected users to selected groups?"
        [[ "$operation" == "remove" ]] && prompt="Remove selected users from selected groups?"
        ask_decision --label "$prompt" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0
        for group in "${group_names[@]}"; do
            for user in "${user_names[@]}"; do
                if (( ${FLAG_DRYRUN:-0} )); then
                    if [[ "$operation" == "add" ]]; then
                        sayinfo "Dry run: Would add $user to group $group."
                    else
                        sayinfo "Dry run: Would remove $user from group $group."
                    fi
                elif [[ "$operation" == "add" ]]; then
                    sudo samba-tool group addmembers "$group" "$user" || return 1
                    sayok "Added $user to $group."
                else
                    sudo samba-tool group removemembers "$group" "$user" || return 1
                    sayok "Removed $user from $group."
                fi
            done
        done
    }

    # fn: _select_users_and_groups - Select both sides of a membership operation
    _select_users_and_groups() {
        _refresh_accounts
        _select_items "users" USERS SELECTED_USERS || return 1
        _select_items "groups" AD_GROUPS SELECTED_GROUPS || return 1
    }

# - Workflows -----------------------------------------------------------------------
    # fn: _user_workflow - Manage a persistent selection of users
    _user_workflow() {
        local action=""
        _refresh_accounts
        _select_items "users" USERS SELECTED_USERS || return 0
        while true; do
            sgnd_print
            sgnd_print_sectionheader "User Management" --padend 0

            sgnd_print
            sgnd_print_sectionheader "Current selection" --padleft 2 --padend 0
            _show_current_selection "Users" USERS SELECTED_USERS

            sgnd_print
            sgnd_print_sectionheader "Actions" --padleft 2 --padend 0
            sgnd_print_labeledvalue --label "1" --value "Show user information" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "2" --value "Change password" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "3" --value "Enable users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "4" --value "Disable users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "5" --value "Set password never expires" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "6" --value "Add users to groups" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "7" --value "Remove users from groups" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "8" --value "Delete users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "R" --value "Reselect users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "Q" --value "Return" --labelwidth 4 --pad 3
            sgnd_print
            ask_choose_immediate --label "Select action" --choices "1-8,R,Q" --instantchoices "1-8,R,Q" --var action
            case "${action^^}" in
                1) _show_user_info ;;
                2) _change_passwords ;;
                3) _apply_user_command enable "Enable" ;;
                4) _apply_user_command disable "Disable" ;;
                5) _apply_user_command noexpiry "Set no-expiry for" ;;
                6) _refresh_accounts; _select_items "groups" AD_GROUPS SELECTED_GROUPS && _change_membership add ;;
                7) _refresh_accounts; _select_items "groups" AD_GROUPS SELECTED_GROUPS && _change_membership remove ;;
                8) _apply_user_command delete "Delete"; return 0 ;;
                R) _refresh_accounts; _select_items "users" USERS SELECTED_USERS || return 0 ;;
                Q) return 0 ;;
            esac
        done
    }

    # fn: _group_workflow - Manage a persistent selection of groups
    _group_workflow() {
        local action=""
        _refresh_accounts
        _select_items "groups" AD_GROUPS SELECTED_GROUPS || return 0
        while true; do
            sgnd_print
            sgnd_print_sectionheader "Group Management" --padend 0

            sgnd_print
            sgnd_print_sectionheader "Current selection" --padleft 2 --padend 0
            _show_current_selection "Groups" AD_GROUPS SELECTED_GROUPS

            sgnd_print
            sgnd_print_sectionheader "Actions" --padleft 2 --padend 0
            sgnd_print_labeledvalue --label "1" --value "Show group information" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "2" --value "Add users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "3" --value "Remove users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "4" --value "Delete groups" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "R" --value "Reselect groups" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "Q" --value "Return" --labelwidth 4 --pad 3
            sgnd_print
            ask_choose_immediate --label "Select action" --choices "1-4,R,Q" --instantchoices "1-4,R,Q" --var action
            case "${action^^}" in
                1) _show_group_info ;;
                2) _refresh_accounts; _select_items "users" USERS SELECTED_USERS && _change_membership add ;;
                3) _refresh_accounts; _select_items "users" USERS SELECTED_USERS && _change_membership remove ;;
                4)
                    local group="" decision="NO"; local -a names=()
                    _selected_names AD_GROUPS SELECTED_GROUPS names
                    ask_decision --label "Delete selected groups?" --choices "YES|Y,NO|N" --default "NO" --var decision
                    if [[ "$decision" == "YES" ]]; then
                        for group in "${names[@]}"; do
                            (( ${FLAG_DRYRUN:-0} )) && sayinfo "Dry run: Would delete group $group." || sudo samba-tool group delete "$group"
                        done
                    fi
                    return 0
                    ;;
                R) _refresh_accounts; _select_items "groups" AD_GROUPS SELECTED_GROUPS || return 0 ;;
                Q) return 0 ;;
            esac
        done
    }

    # fn: _main_menu - Run the top-level account management workflow
    _main_menu() {
        local action=""
        while true; do
            sgnd_print
            sgnd_print_sectionheader "AD User and Group Management" --padend 0

            sgnd_print
            sgnd_print_sectionheader "Actions" --padleft 2 --padend 0
            sgnd_print_labeledvalue --label "1" --value "Create user" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "2" --value "Create group" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "3" --value "Manage users" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "4" --value "Manage groups" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "5" --value "Manage memberships" --labelwidth 4 --pad 3
            sgnd_print_labeledvalue --label "Q" --value "Return" --labelwidth 4 --pad 3
            sgnd_print
            ask_choose_immediate --label "Select action" --choices "1-5,Q" --instantchoices "1-5,Q" --var action
            case "${action^^}" in
                1) _create_user ;;
                2) _create_group ;;
                3) _user_workflow ;;
                4) _group_workflow ;;
                5)
                    _select_users_and_groups || continue
                    sgnd_print
                    sgnd_print_sectionheader "Membership action" --padleft 2 --padend 0
                    _show_current_selection "Users" USERS SELECTED_USERS
                    _show_current_selection "Groups" AD_GROUPS SELECTED_GROUPS
                    sgnd_print
                    sgnd_print_labeledvalue --label "1" --value "Add selected users to selected groups" --labelwidth 4 --pad 3
                    sgnd_print_labeledvalue --label "2" --value "Remove selected users from selected groups" --labelwidth 4 --pad 3
                    sgnd_print_labeledvalue --label "Q" --value "Return" --labelwidth 4 --pad 3
                    sgnd_print
                    ask_choose_immediate --label "Membership action" --choices "1-2,Q" --instantchoices "1-2,Q" --var action
                    [[ "$action" == "1" ]] && _change_membership add
                    [[ "$action" == "2" ]] && _change_membership remove
                    ;;
                Q) return 0 ;;
            esac
        done
    }

# - Main ----------------------------------------------------------------------------
    # fn: main - Run the Active Directory account management workflow
    main() {
        _framework_locator || exit $?
        sgnd_exe_start -- "$@"
        _require_directory || return $?
        _refresh_accounts
        _main_menu
    }

    main "$@"
