# =====================================================================================
# SolidGroundUX - Development Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : db9040809a88eed5ff03bec4296e8bc8e3e27a2349bca6c6f8346bc371acb521
#   Source      : 50-development.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Compose the Development submenu
#
# Description:
#   Loads the functional menu modules that belong to the Development console area.
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

    _open_50_development() {
        sgnd_console_open_submenu "50-menu-development.sh" "Development"
    }

    SGND_MODULE_NAME="Development"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Development, workspace, release, and documentation tools"

    if ! _sgnd_console_group_exists "main"; then
        sgnd_console_register_group "main" "" "" 0 1 100
    fi
    sgnd_console_register_item "50" "main" "Development" "_open_50_development" "Development, workspace, release, and documentation tools" 0 0 1
