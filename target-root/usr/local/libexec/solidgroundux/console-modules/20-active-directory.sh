# =====================================================================================
# SolidGroundUX - Active Directory Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : a362020e0ccc350c6e6d98c328a90137bc98f8835b8d463ea6c4cef292af1bfc
#   Source      : 20-active-directory.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Compose the Active Directory submenu
#
# Description:
#   Loads the functional menu modules that belong to the Active Directory console area.
# =====================================================================================
set -uo pipefail

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
        [[ -n "${!guard-}" ]] && return 1
        printf -v "$guard" '1'
        return 0
    }
    _sgnd_lib_guard || return 0
    unset -f _sgnd_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

    _open_20_active_directory() {
        sgnd_console_open_submenu "20-menu-active-directory.sh" "Active Directory"
    }

    SGND_MODULE_NAME="Active Directory"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Active Directory server, DNS, users, groups, and client management"

    if ! _sgnd_console_group_exists "main"; then
        sgnd_console_register_group "main" "" "" 0 1 100
    fi
    sgnd_console_register_item "20" "main" "Active Directory" "_open_20_active_directory" "Active Directory server, DNS, users, groups, and client management" 0 0 1
