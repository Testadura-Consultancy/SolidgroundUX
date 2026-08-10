# =====================================================================================
# SolidGroundUX - File Services Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : 408ce6cff05e75aace7e7e3b5f4a9d602065837601d638b056cc87fc1a1d35b0
#   Source      : 30-file-services.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Compose the File Services submenu
#
# Description:
#   Loads the functional menu modules that belong to the File Services console area.
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

    _open_30_file_services() {
        sgnd_console_open_submenu "30-menu-file-services.sh" "File Services"
    }

    SGND_MODULE_NAME="File Services"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Storage and Samba file services"

    if ! _sgnd_console_group_exists "main"; then
        sgnd_console_register_group "main" "" "" 0 1 100
    fi
    sgnd_console_register_item "30" "main" "File Services" "_open_30_file_services" "Storage and Samba file services" 0 0 1
