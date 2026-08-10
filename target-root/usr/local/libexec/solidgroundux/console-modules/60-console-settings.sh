# =====================================================================================
# SolidGroundUX - Console Settings Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : 607c694720319647b5f280494cf5baabe2d7fbaf90e63d795b5d3a70bdb2f7da
#   Source      : 60-console-settings.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Compose the Console Settings submenu
#
# Description:
#   Loads the functional menu modules that belong to the Console Settings console area.
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

    _open_60_console_settings() {
        sgnd_console_open_submenu "60-menu-console-settings.sh" "Console Settings"
    }

    SGND_MODULE_NAME="Console Settings"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Console configuration and session actions"

    if ! _sgnd_console_group_exists "main"; then
        sgnd_console_register_group "main" "" "" 0 1 100
    fi
    sgnd_console_register_item "60" "main" "Console Settings" "_open_60_console_settings" "Console configuration and session actions" 0 0 1
