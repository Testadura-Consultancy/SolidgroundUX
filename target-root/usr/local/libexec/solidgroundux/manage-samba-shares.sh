#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Manage Samba Shares
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621816
#   Checksum    : -
#   Source      : manage-samba-shares.sh
#   Type        : script
#   Group       : SDK Tools
#   Purpose     : Select and manage one or more SolidGroundUX Samba shares
#
# Description:
#   Provides an interactive bulk-management console for Samba shares configured below
#   the SolidGroundUX share root. The operator selects one or more configured shares and
#   may inspect, validate, or update their Unix ownership and permissions.
#
# Design principles:
#   - Share discovery is derived from Samba's effective configuration
#   - All mutable operations are restricted to managed paths below /srv/storage/shares
#   - A selected collection remains active until the operator chooses to reselect
#   - Bulk changes require explicit confirmation and honor framework dry-run mode
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
        #   Locate and load the SolidGroundUX bootstrap configuration and executable runtime.
        #
        # . Behavior
        #   - Prefers the invoking user's bootstrap configuration over the system file.
        #   - Creates a bootstrap configuration interactively when none exists.
        #   - Loads sgnd-exe-common.sh from the resolved framework root.
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # . Returns
        #   0 when the framework runtime was loaded.
        #   126 or 127 when configuration or runtime loading fails.
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
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            if [[ -t 0 && -t 1 ]]; then
                printf '%s\n' "SolidGroundUX bootstrap configuration"
                printf '%s\n' "No configuration file found."
                printf '%s\n' "Creating: $cfg"

                printf 'SGND_FRAMEWORK_ROOT [/] : ' >/dev/tty
                read -r reply </dev/tty
                fw_root="${reply:-/}"

                printf 'SGND_APPLICATION_ROOT [%s] : ' "$fw_root" >/dev/tty
                read -r reply </dev/tty
                app_root="${reply:-$fw_root}"
            fi

            [[ "$fw_root" == /* ]] || return 126
            [[ "$app_root" == /* ]] || return 126

            mkdir -p "$(dirname "$cfg")" || return 127
            printf '%s\n%s\n\nSGND_FRAMEWORK_ROOT=%q\nSGND_APPLICATION_ROOT=%q\n' \
                '# SolidGroundUX bootstrap configuration' \
                '# Auto-generated on first run' \
                "$fw_root" \
                "$app_root" >"$cfg" || return 127
        fi

        # shellcheck source=/dev/null
        source "$cfg" || return 126
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

        exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# - Script identity -----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Manage Samba Shares"
    SGND_SCRIPT_DESC="Select and manage one or more configured SolidGroundUX Samba shares."

# - Framework integration -----------------------------------------------------------
    SGND_USING=(
    )

    SGND_ARGS_SPEC=(
    )

    SGND_SCRIPT_EXAMPLES=(
        "Start the interactive share manager:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Preview changes without applying them:"
        "  $SGND_SCRIPT_NAME --dryrun"
    )

    SGND_SCRIPT_GLOBALS=(
    )

    SGND_STATE_VARIABLES=(
    )

    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=0

# - Local script declarations -------------------------------------------------------
    SGND_SAMBA_SHARE_ROOT="/srv/storage/shares"
    SGND_SAMBA_CONFIG="/etc/samba/smb.conf"

    SAMBA_SHARE_NAMES=()
    SAMBA_SHARE_PATHS=()
    SELECTED_SHARE_INDEXES=()

# - Share discovery and selection ---------------------------------------------------
    # fn: _samba_discover_managed_shares - Load configured managed Samba shares
        # . Purpose
        #   Discover configured Samba shares whose backing paths are below the managed root.
        #
        # Outputs (globals):
        #   SAMBA_SHARE_NAMES
        #   SAMBA_SHARE_PATHS
        #
        # . Returns
        #   0 when at least one managed share was found.
        #   1 when Samba is unavailable, configuration is invalid, or no shares were found.
        #
        # . Usage
        #   _samba_discover_managed_shares || return $?
    _samba_discover_managed_shares() {
        local share_name=""
        local share_path=""

        SAMBA_SHARE_NAMES=()
        SAMBA_SHARE_PATHS=()

        command -v testparm >/dev/null 2>&1 || {
            sayfail "Samba is not installed."
            return 1
        }

        sudo testparm -s >/dev/null 2>&1 || {
            sayfail "The Samba configuration is invalid."
            return 1
        }

        while IFS= read -r share_name; do
            [[ -n "$share_name" ]] || continue
            share_path="$(sudo testparm -s --section-name "$share_name" --parameter-name path 2>/dev/null || true)"
            [[ "$share_path" == "$SGND_SAMBA_SHARE_ROOT/"* ]] || continue
            SAMBA_SHARE_NAMES+=("$share_name")
            SAMBA_SHARE_PATHS+=("$share_path")
        done < <(
            sudo testparm -s 2>/dev/null |
                awk '/^\[[^]]+\]$/ { name=$0; gsub(/^\[|\]$/, "", name); if (tolower(name) != "global") print name }'
        )

        if (( ${#SAMBA_SHARE_NAMES[@]} == 0 )); then
            saywarning "No managed Samba shares were found below $SGND_SAMBA_SHARE_ROOT."
            return 1
        fi

        return 0
    }

    # fn: _samba_show_available_shares - Display numbered managed shares
        # . Purpose
        #   Display all discovered shares with their backing paths.
        #
        # . Returns
        #   0 after rendering the list.
        #
        # . Usage
        #   _samba_show_available_shares
    _samba_show_available_shares() {
        local index=0

        sgnd_print
        sgnd_print_sectionheader "Available Samba shares"
        for index in "${!SAMBA_SHARE_NAMES[@]}"; do
            printf '  %2d) %-24s %s\n' \
                "$((index + 1))" \
                "${SAMBA_SHARE_NAMES[$index]}" \
                "${SAMBA_SHARE_PATHS[$index]}"
        done
    }

    # fn: _samba_parse_selection - Parse a numbered share selection
        # . Purpose
        #   Convert comma-separated numbers and ranges into unique zero-based indexes.
        #
        # . Arguments
        #   $1 - Selection such as 1,3-5 or A for all shares.
        #
        # Outputs (globals):
        #   SELECTED_SHARE_INDEXES
        #
        # . Returns
        #   0 when the selection is valid and non-empty.
        #   1 when an item or range is invalid.
        #
        # . Usage
        #   _samba_parse_selection "1,3-4"
    _samba_parse_selection() {
        local selection="${1//[[:space:]]/}"
        local part=""
        local start=0
        local end=0
        local value=0
        local max="${#SAMBA_SHARE_NAMES[@]}"
        local -A seen=()
        local -a parts=()

        SELECTED_SHARE_INDEXES=()

        if [[ "${selection^^}" == "A" ]]; then
            for (( value=0; value<max; value++ )); do
                SELECTED_SHARE_INDEXES+=("$value")
            done
            return 0
        fi

        IFS=',' read -r -a parts <<<"$selection"
        for part in "${parts[@]}"; do
            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start="${BASH_REMATCH[1]}"
                end="${BASH_REMATCH[2]}"
                (( start >= 1 && end >= start && end <= max )) || return 1
                for (( value=start; value<=end; value++ )); do
                    seen[$((value - 1))]=1
                done
            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                value="$part"
                (( value >= 1 && value <= max )) || return 1
                seen[$((value - 1))]=1
            else
                return 1
            fi
        done

        for value in "${!SAMBA_SHARE_NAMES[@]}"; do
            [[ -n "${seen[$value]:-}" ]] && SELECTED_SHARE_INDEXES+=("$value")
        done

        (( ${#SELECTED_SHARE_INDEXES[@]} > 0 ))
    }

    # fn: _samba_select_shares - Ask the operator to select managed shares
        # . Purpose
        #   Display managed shares and collect a valid multi-selection.
        #
        # Outputs (globals):
        #   SELECTED_SHARE_INDEXES
        #
        # . Returns
        #   0 when a selection was accepted.
        #   1 when share discovery fails.
        #
        # . Usage
        #   _samba_select_shares || return $?
    _samba_select_shares() {
        local selection=""

        _samba_discover_managed_shares || return 1

        while true; do
            _samba_show_available_shares
            sgnd_print "Enter comma-separated numbers, ranges such as 2-4, or A for all shares."
            ask --label "Select shares" --var selection --colorize both

            if _samba_parse_selection "$selection"; then
                return 0
            fi

            saywarning "Invalid share selection: $selection"
        done
    }

    # fn: _samba_show_selected_shares - Display the active share collection
        # . Purpose
        #   Render the names of all currently selected shares.
        #
        # . Returns
        #   0 after rendering the selected collection.
        #
        # . Usage
        #   _samba_show_selected_shares
    _samba_show_selected_shares() {
        local index=0
        local -a selected_names=()

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            selected_names+=("${SAMBA_SHARE_NAMES[$index]}")
        done

        sgnd_print_labeledmultivalue \
            --label "Selected shares" \
            --labelwidth 20 \
            --items "${selected_names[@]}"
    }

# - Share management actions --------------------------------------------------------
    # fn: _samba_validate_account - Validate a local or domain user/group name
        # . Arguments
        #   $1 - Account name.
        #
        # . Returns
        #   0 for a non-empty safe account name; otherwise 1.
        #
        # . Usage
        #   _samba_validate_account "root"
    _samba_validate_account() {
        [[ "${1:-}" =~ ^[^[:cntrl:]/:]+$ ]]
    }

    # fn: _samba_validate_mode - Validate a four-digit Unix mode
        # . Arguments
        #   $1 - Octal mode such as 0770.
        #
        # . Returns
        #   0 when valid; otherwise 1.
        #
        # . Usage
        #   _samba_validate_mode "0770"
    _samba_validate_mode() {
        [[ "${1:-}" =~ ^0[0-7]{3}$ ]]
    }

    # fn: _samba_show_details - Show details for selected shares
        # . Purpose
        #   Display Samba settings, ownership, mode, and ACL state for each selection.
        #
        # . Returns
        #   0 after rendering all selected shares.
        #
        # . Usage
        #   _samba_show_details
    _samba_show_details() {
        local index=0
        local name=""
        local path=""
        local owner="-"
        local group="-"
        local mode="-"
        local acl="No"
        local browseable="-"
        local read_only="-"

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            name="${SAMBA_SHARE_NAMES[$index]}"
            path="${SAMBA_SHARE_PATHS[$index]}"
            owner="$(stat -c '%U' "$path" 2>/dev/null || printf '-')"
            group="$(stat -c '%G' "$path" 2>/dev/null || printf '-')"
            mode="$(stat -c '%a' "$path" 2>/dev/null || printf '-')"
            browseable="$(sudo testparm -s --section-name "$name" --parameter-name browseable 2>/dev/null || printf '-')"
            read_only="$(sudo testparm -s --section-name "$name" --parameter-name 'read only' 2>/dev/null || printf '-')"
            acl="No"
            command -v getfacl >/dev/null 2>&1 && getfacl -cp "$path" 2>/dev/null | grep -q '^default:' && acl="Yes"

            sgnd_print
            sgnd_print_sectionheader "$name"
            sgnd_print_labeledvalue --label "Path" --value "$path" --labelwidth 20
            sgnd_print_labeledvalue --label "Owner" --value "$owner" --labelwidth 20
            sgnd_print_labeledvalue --label "Group" --value "$group" --labelwidth 20
            sgnd_print_labeledvalue --label "Mode" --value "$mode" --labelwidth 20
            sgnd_print_labeledvalue --label "Default ACL" --value "$acl" --labelwidth 20
            sgnd_print_labeledvalue --label "Browsable" --value "$browseable" --labelwidth 20
            sgnd_print_labeledvalue --label "Read only" --value "$read_only" --labelwidth 20
        done
    }

    # fn: _samba_set_owner - Set one owner on all selected shares
        # . Returns
        #   0 after applying or cancelling the operation.
        #   1 when validation or a filesystem change fails.
        #
        # . Usage
        #   _samba_set_owner
    _samba_set_owner() {
        local owner=""
        local decision="NO"
        local index=0

        ask --label "New owner" --var owner --validate _samba_validate_account || return $?
        getent passwd "$owner" >/dev/null 2>&1 || {
            sayfail "User could not be resolved: $owner"
            return 1
        }

        ask_decision --label "Apply owner '$owner' to selected shares?" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "Dry run: Would set owner $owner on ${SAMBA_SHARE_PATHS[$index]}."
            else
                sudo chown "$owner" "${SAMBA_SHARE_PATHS[$index]}" || return 1
                sayok "Set owner $owner on ${SAMBA_SHARE_NAMES[$index]}."
            fi
        done
    }

    # fn: _samba_set_group - Set one group on all selected shares
        # . Returns
        #   0 after applying or cancelling the operation.
        #   1 when validation or a filesystem change fails.
        #
        # . Usage
        #   _samba_set_group
    _samba_set_group() {
        local group=""
        local decision="NO"
        local index=0

        ask --label "New group" --var group --validate _samba_validate_account || return $?
        getent group "$group" >/dev/null 2>&1 || {
            sayfail "Group could not be resolved: $group"
            return 1
        }

        ask_decision --label "Apply group '$group' to selected shares?" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "Dry run: Would set group $group on ${SAMBA_SHARE_PATHS[$index]}."
            else
                sudo chgrp "$group" "${SAMBA_SHARE_PATHS[$index]}" || return 1
                sayok "Set group $group on ${SAMBA_SHARE_NAMES[$index]}."
            fi
        done
    }

    # fn: _samba_set_permissions - Set one Unix mode on all selected shares
        # . Returns
        #   0 after applying or cancelling the operation.
        #   1 when validation or chmod fails.
        #
        # . Usage
        #   _samba_set_permissions
    _samba_set_permissions() {
        local mode="0770"
        local decision="NO"
        local index=0

        ask --label "Unix mode" --var mode --default "$mode" --validate _samba_validate_mode || return $?
        ask_decision --label "Apply mode '$mode' to selected shares?" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "Dry run: Would set mode $mode on ${SAMBA_SHARE_PATHS[$index]}."
            else
                sudo chmod "$mode" "${SAMBA_SHARE_PATHS[$index]}" || return 1
                sayok "Set mode $mode on ${SAMBA_SHARE_NAMES[$index]}."
            fi
        done
    }

    # fn: _samba_restore_defaults - Restore canonical ownership and mode
        # . Purpose
        #   Restore root:root ownership and mode 0770 on every selected share directory.
        #
        # . Returns
        #   0 after applying or cancelling the operation.
        #   1 when chown or chmod fails.
        #
        # . Usage
        #   _samba_restore_defaults
    _samba_restore_defaults() {
        local decision="NO"
        local index=0

        ask_decision \
            --label "Restore root:root and 0770 on selected shares?" \
            --choices "YES|Y,NO|N" \
            --default "NO" \
            --var decision
        [[ "$decision" == "YES" ]] || return 0

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "Dry run: Would restore root:root and 0770 on ${SAMBA_SHARE_PATHS[$index]}."
            else
                sudo chown root:root "${SAMBA_SHARE_PATHS[$index]}" || return 1
                sudo chmod 0770 "${SAMBA_SHARE_PATHS[$index]}" || return 1
                sayok "Restored defaults on ${SAMBA_SHARE_NAMES[$index]}."
            fi
        done
    }

    # fn: _samba_validate_selected - Validate selected share definitions and directories
        # . Purpose
        #   Verify paths, directory existence, Samba configuration, and basic permissions.
        #
        # . Returns
        #   0 when every selected share passes.
        #   1 when one or more checks fail.
        #
        # . Usage
        #   _samba_validate_selected
    _samba_validate_selected() {
        local index=0
        local name=""
        local path=""
        local result="Passed"
        local failures=0

        for index in "${SELECTED_SHARE_INDEXES[@]}"; do
            name="${SAMBA_SHARE_NAMES[$index]}"
            path="${SAMBA_SHARE_PATHS[$index]}"
            result="Passed"

            [[ "$path" == "$SGND_SAMBA_SHARE_ROOT/"* ]] || result="Failed"
            [[ -d "$path" ]] || result="Failed"
            sudo testparm -s --section-name "$name" >/dev/null 2>&1 || result="Failed"

            sgnd_print_labeledvalue --label "$name" --value "$result" --labelwidth 24
            if [[ "$result" == "Failed" ]]; then
                failures=$((failures + 1))
            fi
        done

        if (( failures == 0 )); then
            sayok "All selected Samba shares passed validation."
            return 0
        fi

        sayfail "$failures selected Samba share(s) failed validation."
        return 1
    }

# - Interactive management loop -----------------------------------------------------
    # fn: _samba_manage_selected - Run actions against the active share collection
        # . Purpose
        #   Keep the selected collection active while the operator performs actions.
        #
        # . Returns
        #   0 when the operator returns or requests reselection.
        #
        # . Usage
        #   _samba_manage_selected
    _samba_manage_selected() {
        local action=""

        while true; do
            sgnd_print
            sgnd_print_sectionheader "Samba Share Management"
            _samba_show_selected_shares
            sgnd_print
            sgnd_print "  1) Show details"
            sgnd_print "  2) Set owner"
            sgnd_print "  3) Set group"
            sgnd_print "  4) Set permissions"
            sgnd_print "  5) Restore default permissions"
            sgnd_print "  6) Validate shares"
            sgnd_print "  R) Reselect shares"
            sgnd_print "  Q) Return"

            ask_choose_immediate \
                --label "Select action" \
                --choices "1-6,R,Q" \
                --instantchoices "1-6,R,Q" \
                --var action

            case "${action^^}" in
                1) _samba_show_details ;;
                2) _samba_set_owner ;;
                3) _samba_set_group ;;
                4) _samba_set_permissions ;;
                5) _samba_restore_defaults ;;
                6) _samba_validate_selected || true ;;
                R) return 2 ;;
                Q) return 0 ;;
            esac
        done
    }

# - Main -----------------------------------------------------------------------------
    # fn: main - Run the Samba share management workflow
        # . Purpose
        #   Initialize SolidGroundUX, select managed shares, and run the action loop.
        #
        # . Arguments
        #   $@ - Framework and script-specific command-line arguments.
        #
        # . Returns
        #   0 after the operator leaves the manager.
        #   Non-zero when framework startup or share discovery fails.
        #
        # . Usage
        #   main "$@"
    main() {
        local manage_rc=0

        _framework_locator || exit $?
        sgnd_exe_start -- "$@"

        while true; do
            _samba_select_shares || return $?
            _samba_manage_selected
            manage_rc=$?
            [[ "$manage_rc" -eq 2 ]] || break
        done

        return 0
    }

    main "$@"
