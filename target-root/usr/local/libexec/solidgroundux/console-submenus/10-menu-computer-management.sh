# =====================================================================================
# SolidGroundUX - Computer Management Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : d4d245f1cd3254618ec93157e8d1ec44c056ca478667bb50916bbf0a31d3116b
#   Source      : 10-menu-computer-management.sh
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

    _sgnd_console_profile_source_part() {
        local part="${1:?missing module part}"
        local part_path="${SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY%/}/../console-module-parts/$part"
        [[ -r "$part_path" ]] || { sayfail "Console module part not found: $part_path"; return 126; }
        source "$part_path"
    }

    _sgnd_console_profile_source_part "10-computer-setup.sh" || return $?
    _sgnd_console_profile_source_part "15-package-management.sh" || return $?

    SGND_MODULE_NAME="Computer Management"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Computer setup and package management"
