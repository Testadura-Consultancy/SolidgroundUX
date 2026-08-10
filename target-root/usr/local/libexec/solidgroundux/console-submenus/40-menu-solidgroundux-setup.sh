# =====================================================================================
# SolidGroundUX - SolidGroundUX Setup Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : d3113e5f3d1942974a99f3fb6c6fd78ebd438f99805749f438e5769c6256d458
#   Source      : 40-menu-solidgroundux-setup.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Compose the SolidGroundUX Setup submenu
#
# Description:
#   Loads the functional menu modules that belong to the SolidGroundUX Setup console area.
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

    _sgnd_console_profile_source_part "90-solidgroundux.sh" || return $?

    SGND_MODULE_NAME="SolidGroundUX Setup"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="SolidGroundUX framework setup, configuration, state, logging, and diagnostics"
