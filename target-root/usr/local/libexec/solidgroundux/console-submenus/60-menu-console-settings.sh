# =====================================================================================
# SolidGroundUX - Console Settings Console Menu
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Checksum    : 451b42f5d5e3f81af41068103c1d82d71921a79257b513ea3760ce3d5648fbc1
#   Source      : 60-menu-console-settings.sh
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

    _settings_cycle_theme() { _sgnd_console_cycle_theme 1; }
    _settings_cycle_console_log() { _sgnd_console_cycle_console_loglevel 1; }
    _settings_cycle_file_log() { _sgnd_console_cycle_file_loglevel 1; }
    _settings_manage_modules() { _sgnd_console_manage_modules "$SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY"; }

    SGND_MODULE_NAME="Console Settings"
    SGND_MODULE_VERSION="1.0.0"
    SGND_MODULE_DESC="Configure SolidGroundUX console behavior and session actions"

    sgnd_console_register_group "console-config" "Console Configuration" "Framework-level console settings" 0 1 100
    sgnd_console_register_item "access" "console-config" "Access mode" "_sgnd_console_toggle_access" "Relaunch with root or standard access" 0 0 1
    sgnd_console_register_item "dryrun" "console-config" "Dry-run / Commit" "_sgnd_console_toggle_dryrun" "Toggle safe simulation versus committed changes" 0 0 1
    sgnd_console_register_item "theme" "console-config" "Cycle theme" "_settings_cycle_theme" "Select the next installed console theme" 0 0 1
    sgnd_console_register_item "console-log" "console-config" "Console log level" "_settings_cycle_console_log" "Cycle the console log level" 0 0 1
    sgnd_console_register_item "file-log" "console-config" "File log level" "_settings_cycle_file_log" "Cycle the file log level" 0 0 1
    sgnd_console_register_item "lines" "console-config" "Lines per page" "_sgnd_console_set_lines_per_page" "Set the maximum number of menu lines per page" 0 0 1
    sgnd_console_register_item "roles" "console-config" "Role awareness" "_sgnd_console_set_role_awareness" "Enable or disable role-aware menu visibility" 0 0 1
    sgnd_console_register_item "modules" "console-config" "Manage modules" "_settings_manage_modules" "Enable or disable top-level console modules" 0 0 1

    sgnd_console_register_group "console-actions" "Console Actions" "Immediate console utilities" 0 1 200
    sgnd_console_register_item "shell" "console-actions" "Open shell" "_sgnd_console_open_shell" "Open an interactive shell; exit returns to the console" 0 0 1
    sgnd_console_register_item "redraw" "console-actions" "Redraw menu" "_sgnd_console_redraw" "Refresh the console display" 0 0 1
