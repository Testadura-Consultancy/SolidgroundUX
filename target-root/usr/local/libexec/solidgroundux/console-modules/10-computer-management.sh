# =====================================================================================
# SolidGroundUX - Computer Management Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : acecac3d14eeb8f52adf72dfcdc65c366f01694362600f5145383f53a35b492e
#   Source      : 10-computer-management.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Compose the Computer Management submenu
#
# Description:
#   Loads the functional menu modules that belong to the Computer Management console area.
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

    _open_10_computer_management() {
        sgnd_console_open_submenu "10-menu-computer-management.sh" "Computer Management"
    }

    SGND_MODULE_NAME="Computer Management"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Computer setup and package management"

    if ! _sgnd_console_group_exists "main"; then
        sgnd_console_register_group "main" "" "" 0 1 100
    fi
    sgnd_console_register_item "10" "main" "Computer Management" "_open_10_computer_management" "Computer setup and package management" 0 0 1
