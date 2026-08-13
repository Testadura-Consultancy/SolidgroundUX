#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - SolidGround Management Console
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622402
#   Checksum    : 7dc9c3e56936daf73eabbeac4268689146a6f1ec3041e3bdc3210ce309b9aaf8
#   Source      : sgnd-console.sh
#   Type        : script
#   Group       : SolidGround Console
#   Purpose     : Provide a modular console interface for SolidGroundUX tooling
#
# Description:
#   Provides a generic, modular console host that dynamically loads modules
#   and presents their functionality through a structured menu interface.
#
#   The script:
#     - Loads console modules from a configured module directory
#     - Allows modules to register menu items dynamically
#     - Builds and renders interactive menus
#     - Handles user input and dispatches actions
#     - Supports navigation, paging, and toggle controls
#     - Persists console layout and framework UI/logging state
#
# Design principles:
#   - Modular architecture with clear separation of host and modules
#   - Convention-based module registration
#   - Minimal assumptions about module implementation
#   - Consistent user interaction patterns across all tools
#
# Role in framework:
#   - Generic console engine for module-defined interactive applications
#   - Hosts and orchestrates functionality provided by ordered console modules
#
# Non-goals:
#   - Implementing business logic directly in the console host
#   - Managing module-specific state beyond registration and dispatch
#   - Providing a widget-based or cursor-addressed full-screen TUI
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# --- Bootstrap ----------------------------------------------------------------------
    # fn: _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Purpose
        #   Locate, create, and load the SolidGroundUX bootstrap configuration, then
        #   load the executable runtime support library.
        #
        # . Behavior
        #   - Searches user and system bootstrap configuration locations.
        #   - Prefers the invoking user's config over the system config.
        #   - Creates a new bootstrap config when none exists.
        #   - Prompts for framework/application roots in interactive mode.
        #   - Applies default values when running non-interactively.
        #   - Sources the selected bootstrap configuration file.
        #   - Loads sgnd-exe-common.sh from the resolved framework root.
        #
        # . Globals (write)
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # . Output
        #   Writes primitive printf-based messages before the framework UI is available.
        #
        # . Returns
        #   0 when the bootstrap configuration and executable common library were loaded.
        #   126 when configuration or executable common library is unreadable or invalid.
        #   127 when the configuration directory or file could not be created.
        #
        # . Usage
        #   _framework_locator || return $?
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
        #   - This function intentionally uses printf rather than say* helpers because
        #     the executable common library has not been loaded yet.
    _framework_locator() {
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply=""

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
                printf '%s\n' "SolidGroundUX bootstrap configuration" >&2
                printf '%s\n' "No configuration file found." >&2
                printf '%s\n' "Creating: $cfg" >&2

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_FRAMEWORK_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_APPLICATION_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            printf '%s\n' "Created bootstrap cfg: $cfg" >&2
        fi

        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"

            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            printf '%s\n' "Cannot read bootstrap cfg: $cfg" >&2
            return 126
        fi

        case "${SGND_LOG_LEVEL:-silent}" in
            silent|quiet)
                ;;
            *)
                printf '%s\n' "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT" >&2
                ;;
        esac

        local exe_common=""

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        fi

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="SolidGround Management Console"
    : "${SGND_SCRIPT_DESC:=Collection of scripts and tools for managing SolidGroundUX environments}"
    : "${SGND_SCRIPT_VERSION:=1.0}"
    : "${SGND_SCRIPT_BUILD:=20260312}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

# --- Script metadata (framework integration) -----------------------------------------
    # SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
        #
        # Example:
        #   SGND_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    SGND_USING=(
        sgnd-datatable.sh
        sgnd-console-menu.sh
    )

    # SGND_ARGS_SPEC 
        # Optional: script-specific arguments
        # --- Example: Arguments
        # Each entry:
        #   "name|short|type|var|help|choices"
        #
        #   name    = long option name WITHOUT leading --
        #   short   - short option name WITHOUT leading -
        #   type    = flag | value | enum
        # var: = shell variable that will be set
        #   help    = help string for auto-generated --help output
        #   choices = for enum: comma-separated values (e.g. fast,slow,auto)
        #             for flag/value: leave empty
        #
        # Notes:
        #   - -h / --help is built in, you don't need to define it here.
        #   - After parsing you can use: FLAG_VERBOSE, VAL_CONFIG, ENUM_MODE, ...
    SGND_ARGS_SPEC=(
        "appcfg||value|VAL_APPCFG|Console module file or module directory|"
        "maxrows||value|VAL_MAXROWS|Maximum menu rows per page|"
        "title||value|VAL_TITLE|Override console title|"
        "submenu||flag|FLAG_SUBMENU|Run as a submenu console|0|"
    )

    # SGND_SCRIPT_EXAMPLES
        # Optional: examples for --help output.
        # Each entry is a string that will be printed verbatim.
        #
        # Example:
        #   SGND_SCRIPT_EXAMPLES=(
        #       "Example usage:"
        #       "  script.sh --verbose --mode fast"
        #       "  script.sh -v -m slow"
        #   )
        #
        # Leave empty if no examples are needed.
    SGND_SCRIPT_EXAMPLES=(
        "Examples:"
        "  sgnd-console.sh"
        "  sgnd-console.sh --appcfg ./10-sgnd-config.sh"
        "  sgnd-console.sh --appcfg ./20-machine-config.sh"
    ) 

    # SGND_SCRIPT_GLOBALS
        # Explicit declaration of global variables intentionally used by this script.
        #
        # . Purpose
        #   - Declares which globals are part of the script’s public/config contract.
        #   - Enables optional configuration loading when non-empty.
        #
        # . Behavior
        #   - If this array is non-empty, sgnd_bootstrap enables config integration.
        #   - Variables listed here may be populated from configuration files.
        #   - Unlisted globals will NOT be auto-populated.
        #
        # Use this to:
        #   - Document intentional globals
        #   - Prevent accidental namespace leakage
        #   - Make configuration behavior explicit and predictable
        #
        # Only list:
        #   - Variables that must be globally accessible
        #   - Variables that may be defined in config files
        #
        # Leave empty if:
        #   - The script does not use configuration-driven globals
    SGND_SCRIPT_GLOBALS=(
    )

    # SGND_STATE_VARIABLES
        # List of variables participating in persistent state.
        #
        # . Purpose
        #   - Declares which variables should be saved/restored when state is enabled.
        #
        # . Behavior
        #   - Only used when sgnd_bootstrap is invoked with --state.
        #   - Variables listed here are serialized on exit (if SGND_STATE_SAVE=1).
        #   - On startup, previously saved values are restored before main logic runs.
        #
        # Contract:
        #   - Variables must be simple scalars (no arrays/associatives unless explicitly supported).
        #   - Script remains fully functional when state is disabled.
        #
        # Leave empty if:
        #   - The script does not use persistent state.
    SGND_STATE_VARIABLES=(
        SGND_CONSOLE_ROLE_AWARE
        SGND_PAGE_MAX_ROWS
    )

    # SGND_ON_EXIT_HANDLERS
        # List of functions to be invoked on script termination.
        #
        # . Purpose
        #   - Allows scripts to register cleanup or finalization hooks.
        #
        # . Behavior
        #   - Functions listed here are executed during framework exit handling.
        #   - Execution order follows array order.
        #   - Handlers run regardless of normal exit or controlled termination.
        #
        # Contract:
        #   - Functions must exist before exit occurs.
        #   - Handlers must not call exit directly.
        #   - Handlers should be idempotent (safe if executed once).
        #
        # Typical uses:
        #   - Cleanup temporary files
        #   - Persist additional state
        #   - Release locks
        #
        # Leave empty if:
        #   - No custom exit behavior is required.
    SGND_ON_EXIT_HANDLERS=(
    )
    
    # State persistence is opt-in.
        # Scripts that want persistent state must:
        #   1) set SGND_STATE_SAVE=1
        #   2) call sgnd_bootstrap --state
    SGND_STATE_SAVE=1

# --- Local scripts and definitions ---------------------------------------------------
    # --- Console state
        SGND_GROUP_SCHEMA="key|label|desc|source|builtin|visible|ord"
        declare -ag SGND_GROUP_ROWS=()

        SGND_ITEM_SCHEMA="key|group|label|handler|desc|source|builtin|waitsecs|visible"
        declare -ag SGND_ITEM_ROWS=()

        SGND_MODULE_SCHEMA="id|name|version|desc|source"
        declare -ag SGND_MODULE_ROWS=()



        SGND_CONSOLE_TITLE="$SGND_SCRIPT_TITLE"
        SGND_CONSOLE_DESC="$SGND_SCRIPT_DESC"
        : "${SGND_CONSOLE_ROLE_AWARE:=1}"
        SGND_CONSOLE_BIN_DIRECTORY=""
        SGND_CONSOLE_SBIN_DIRECTORY=""
        SGND_CONSOLE_LIBEXEC_DIRECTORY=""
        SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY=""
        SGND_CONSOLE_MODULE_PATH=""
        SGND_CONSOLE_MODULE_STATE_FILE=""
        SGND_CURRENT_MODULE=""
        SGND_LAST_WAITSECS=15
        declare -ag SGND_CONSOLE_ORIGINAL_ARGS=()

        declare -ag SGND_VISIBLE_ITEM_INDEXES=()
        declare -ag SGND_GROUP_RENDER_INDEXES=()

        SGND_CONSOLE_MODEL_CACHE_GROUP_COUNT=-1
        SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT=-1
        SGND_CONSOLE_MODEL_CACHE_GENERATION=0
        SGND_CONSOLE_GROUP_INDEX_CACHE_GENERATION=-1
        SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION=-1
        SGND_CONSOLE_LABEL_WIDTH_CACHE_GENERATION=-1
        SGND_CONSOLE_LABEL_WIDTH_CACHE_VALUE=0
        declare -ag SGND_GROUP_CACHE_KEY=()
        declare -ag SGND_GROUP_CACHE_LABEL=()
        declare -ag SGND_GROUP_CACHE_BUILTIN=()
        declare -ag SGND_GROUP_CACHE_VISIBLE=()
        declare -ag SGND_GROUP_CACHE_ORD=()
        declare -Ag SGND_GROUP_CACHE_INDEX_BY_KEY=()
        declare -ag SGND_ITEM_CACHE_KEY=()
        declare -ag SGND_ITEM_CACHE_GROUP=()
        declare -ag SGND_ITEM_CACHE_LABEL=()
        declare -ag SGND_ITEM_CACHE_HANDLER=()
        declare -ag SGND_ITEM_CACHE_DESC=()
        declare -ag SGND_ITEM_CACHE_BUILTIN=()
        declare -ag SGND_ITEM_CACHE_WAITSECS=()
        declare -ag SGND_ITEM_CACHE_VISIBLE=()

        SGND_CLEAR_ONRENDER=1

        SGND_PAGE_INDEX=0
        declare -ag SGND_PAGE_STARTS=()
        declare -ag SGND_PAGE_ROW_OFFSETS=()
        declare -ag SGND_PAGE_ROW_COUNTS=()
        declare -ag SGND_PAGE_ROWS=()
        declare -ag SGND_PAGE_GROUP_OFFSETS=()
        declare -ag SGND_PAGE_GROUP_COUNTS=()
        declare -ag SGND_PAGE_GROUPS=()
        SGND_CONSOLE_LAYOUT_CACHE_KEY=""
        SGND_PAGE_HAS_PREV=0
        SGND_PAGE_HAS_NEXT=0
        : "${SGND_PAGE_MAX_ROWS:=25}"
            
    # --- Console paths ---------------------------------------------------------------
    # _sgnd_console_init_paths
        # . Purpose
        #   Derive console host paths from SGND_APPLICATION_ROOT.
        #
        # . Returns
        #   0 on success; 1 when SGND_APPLICATION_ROOT is unavailable.
        #
        # . Usage
        #   _sgnd_console_init_paths || return $?
    _sgnd_console_init_paths() {
        [[ -n "${SGND_APPLICATION_ROOT:-}" ]] || {
            sayfail "SGND_APPLICATION_ROOT is not initialized"
            return 1
        }

        SGND_CONSOLE_BIN_DIRECTORY="${SGND_APPLICATION_ROOT%/}/usr/local/bin"
        SGND_CONSOLE_SBIN_DIRECTORY="${SGND_APPLICATION_ROOT%/}/usr/local/sbin"
        SGND_CONSOLE_LIBEXEC_DIRECTORY="${SGND_APPLICATION_ROOT%/}/usr/local/libexec/solidgroundux"
        SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY="${SGND_CONSOLE_LIBEXEC_DIRECTORY%/}/console-modules"
        SGND_CONSOLE_MODULE_STATE_FILE="${SGND_STATE_DIR%/}/console-modules.state"
    }

    # --- Console configuration -------------------------------------------------------
    # fn: _sgnd_console_load_config - Resolve the console module source
        # . Purpose
        #   Resolve the module file or directory used by this console instance.
        #
        # . Behavior
        #   - Without --appcfg, loads the standard console-modules directory beside
        #     sgnd-console.sh.
        #   - With --appcfg pointing to a .sh file, loads only that module.
        #   - With --appcfg pointing to a directory, loads every .sh file in it.
        #   - Normalizes the selected path to an absolute path.
        #
        # Inputs (globals):
        #   VAL_APPCFG
        #   SGND_SCRIPT_DIR
        #
        # Outputs (globals):
        #   SGND_CONSOLE_MODULE_PATH
        #
        # . Returns
        #   0   success
        #   126 module source does not exist or is not a readable .sh file/directory
        #
        # . Usage
        #   _sgnd_console_load_config || return $?
    _sgnd_console_load_config() {
        local module_path="${VAL_APPCFG-}"

        : "${SGND_CONSOLE_TITLE:=${SGND_SCRIPT_TITLE}}"
        : "${SGND_CONSOLE_DESC:=${SGND_SCRIPT_DESC}}"
        : "${SGND_PAGE_MAX_ROWS:=25}"

        if [[ -n "${VAL_TITLE:-}" ]]; then
            SGND_CONSOLE_TITLE="$VAL_TITLE"
        fi

        if [[ -z "$module_path" ]]; then
            module_path="$SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY"
        fi

        module_path="$(readlink -f -- "$module_path" 2>/dev/null || printf '%s' "$module_path")"

        if [[ -d "$module_path" ]]; then
            [[ -r "$module_path" ]] || {
                sayfail "Module directory is not readable: $module_path"
                return 126
            }
        elif [[ -f "$module_path" && "$module_path" == *.sh ]]; then
            [[ -r "$module_path" ]] || {
                sayfail "Module file is not readable: $module_path"
                return 126
            }
        else
            sayfail "Module source must be a .sh file or directory: $module_path"
            return 126
        fi

        SGND_CONSOLE_MODULE_PATH="$module_path"

        saydebug "Console title      : $SGND_CONSOLE_TITLE"
        saydebug "Console desc       : $SGND_CONSOLE_DESC"
        saydebug "Module source      : $SGND_CONSOLE_MODULE_PATH"
        saydebug "Role-aware loading : $SGND_CONSOLE_ROLE_AWARE"
    }

    # --- Built-in menu registration -------------------------------------------------
    # _sgnd_console_register_builtin_items
        # . Purpose
        #   Register the console's builtin groups and builtin menu actions.
        #
        # . Behavior
        #   - Defines the builtin runtime and session group keys.
        #   - Registers builtin console groups.
        #   - Registers builtin menu items for runtime toggles and session actions.
        #   - Some builtin items may be hidden from the menu body while still
        #     remaining dispatchable by key.
        #
        # Outputs (globals):
        #   SGND_GROUP_RUNTIME
        #   SGND_GROUP_SESSION
        #
        # . Returns
        #   0 on success
        #   Non-zero if group or item registration fails
        #
        # . Usage
        #   _sgnd_console_register_builtin_items
        #
        # Examples:
        #   _sgnd_console_register_builtin_items || exit 1
        #   non-zero if group/item registration fails
    # fn: _sgnd_console_register_builtin_items - Register built-in console menu items
        # . Purpose
        #   Register built-in console menu items.
        #
        # . Behavior
        #   - Internal helper.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _sgnd_console_register_builtin_items
    _sgnd_console_register_builtin_items() {
        SGND_GROUP_NAVIGATION="navigation"

        # Navigation is framework-owned but intentionally hidden from the menu body.
        # Left/right arrow keys page; Q returns from submenus or exits the root console.
        sgnd_console_register_group "$SGND_GROUP_NAVIGATION" "Navigation" "" 1 0 990
        sgnd_console_register_item "<" "$SGND_GROUP_NAVIGATION" "Previous page" "_sgnd_console_prevpage" "Show previous menu page" 1 0 0
        sgnd_console_register_item ">" "$SGND_GROUP_NAVIGATION" "Next page" "_sgnd_console_nextpage" "Show next menu page" 1 0 0
        sgnd_console_register_item "Q" "$SGND_GROUP_NAVIGATION" "Return" "_sgnd_console_quit" "Return from the current console" 1 0 0
    }

    # sgnd_console_open_submenu
        # Purpose:
        #   Launch a nested SolidGroundUX console using one submenu module definition.
        #
        # Arguments:
        #   $1  PROFILE_FILE - Filename beneath console-submenus.
        #   $2  TITLE        - Console title shown by the nested menu.
        #
        # Returns:
        #   Exit status of the nested console process.
        #
        # Usage:
        #   sgnd_console_open_submenu "20-active-directory.sh" "Active Directory"
    sgnd_console_open_submenu() {
        local profile_file="${1:?missing submenu profile}"
        local title="${2:?missing submenu title}"
        local submenu_directory="${SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY%/}/../console-submenus"
        local profile_path="${submenu_directory%/}/$profile_file"
        local -a command_args=()

        [[ -r "$profile_path" ]] || {
            sayfail "Console submenu not found: $profile_path"
            return 126
        }

        _sgnd_build_command_args command_args \
            --appcfg "$profile_path" \
            --title "$title" \
            --submenu

        "$SGND_SCRIPT_FILE" "${command_args[@]}"
    }

    # fn: _sgnd_console_register_fallback_group - Register fallback console group
        # . Purpose
        #   Register a fallback group for an item that references an unknown group key.
        #
        # . Behavior
        #   - Uses "Other" as the default fallback label.
        #   - For keys of the form "module:<id>", attempts to resolve the module
        #     name from SGND_MODULE_ROWS and uses that as the group label.
        #   - Registers the derived group as a non-builtin visible group.
        #
        # . Arguments
        #   $1  GROUP_KEY
        #       Missing group key to register.
        #
        # . Returns
        #   0 on success
        #   Non-zero if registration fails
        #
        # . Usage
        #   _sgnd_console_register_fallback_group "module:devtools"
        #
        # Examples:
        #   _sgnd_console_register_fallback_group "module:devtools"
    _sgnd_console_register_fallback_group() {
        local key="${1:?missing group key}"
        local label="Other"
        local module_id=""
        local module_name=""
        local i
        local row_count=0

        case "$key" in
            module:*)
                module_id="${key#module:}"
                row_count="$(sgnd_dt_row_count SGND_MODULE_ROWS)"

                for (( i=0; i<row_count; i++ )); do
                    if [[ "$(sgnd_dt_get "$SGND_MODULE_SCHEMA" SGND_MODULE_ROWS "$i" id)" == "$module_id" ]]; then
                        module_name="$(sgnd_dt_get "$SGND_MODULE_SCHEMA" SGND_MODULE_ROWS "$i" name)"
                        break
                    fi
                done

                if [[ -n "${module_name//[[:space:]]/}" ]]; then
                    label="$module_name"
                else
                    label="$module_id"
                fi
                ;;
        esac

        sgnd_console_register_group "$key" "$label" "" 0 1 800
    }

    # fn: _sgnd_console_group_exists - Test whether a console group exists
        # . Purpose
        #   Test whether a group key already exists in the console group model.
        #
        # . Arguments
        #   $1  GROUP_KEY
        #       Group key to test.
        #
        # . Returns
        #   0 if the group exists
        #   1 if the group does not exist
        #
        # . Usage
        #   _sgnd_console_group_exists "runtime" && printf 'Group exists\n'
        #
        # Examples:
        #   _sgnd_console_group_exists "runtime"
    _sgnd_console_group_exists() {
        local key="${1:?missing group key}"

        sgnd_dt_has_row "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS key "$key"
    }

    # --- Module visibility ----------------------------------------------------------
    # fn$: _sgnd_console_module_id_from_filename - Derive module ID from filename
        # . Returns
        #   0 after writing the normalized module ID to stdout.
        #
        # . Usage
        #   _sgnd_console_module_id_from_filename "20-active-directory.sh"
    _sgnd_console_module_id_from_filename() {
        local module_name=""

        module_name="$(basename -- "${1:?missing module file}")"
        module_name="${module_name%.sh}"
        module_name="${module_name#[0-9][0-9]-}"
        printf '%s\n' "$module_name"
    }

    # fn$: _sgnd_console_module_state_get - Read module visibility state
        # . Returns
        #   Writes enabled or disabled. Missing entries default to enabled.
        #
        # . Usage
        #   _sgnd_console_module_state_get "active-directory"
    _sgnd_console_module_state_get() {
        local module_id="${1:?missing module ID}"
        local state=""

        if [[ -r "$SGND_CONSOLE_MODULE_STATE_FILE" ]]; then
            state="$(awk -F= -v id="$module_id" '$1 == id { value=$2 } END { print value }' "$SGND_CONSOLE_MODULE_STATE_FILE")"
        fi

        case "$state" in
            disabled) printf '%s\n' "disabled" ;;
            *)        printf '%s\n' "enabled" ;;
        esac
    }

    # fn$: _sgnd_console_module_enabled - Test whether a module is enabled
        # . Returns
        #   0 when enabled or unspecified; 1 when explicitly disabled.
        #
        # . Usage
        #   _sgnd_console_module_enabled "active-directory"
    _sgnd_console_module_enabled() {
        local module_id="${1:?missing module ID}"
        [[ "$module_id" == "console-settings" ]] && return 0
        [[ "$(_sgnd_console_module_state_get "$module_id")" == "enabled" ]]
    }

    # fn$: _sgnd_console_module_state_set - Persist module visibility state
        # . Returns
        #   0 when the state file was updated successfully.
        #
        # . Usage
        #   _sgnd_console_module_state_set "active-directory" "disabled"
    _sgnd_console_module_state_set() {
        local module_id="${1:?missing module ID}"
        local state="${2:?missing module state}"
        local state_dir=""
        local temp_file=""

        case "$state" in
            enabled|disabled) ;;
            *) return 2 ;;
        esac

        state_dir="$(dirname -- "$SGND_CONSOLE_MODULE_STATE_FILE")"
        mkdir -p -- "$state_dir" || return 1
        temp_file="$(mktemp "${SGND_CONSOLE_MODULE_STATE_FILE}.XXXXXX")" || return 1

        if [[ -r "$SGND_CONSOLE_MODULE_STATE_FILE" ]]; then
            awk -F= -v id="$module_id" '$1 != id { print }' "$SGND_CONSOLE_MODULE_STATE_FILE" > "$temp_file" || {
                rm -f -- "$temp_file"
                return 1
            }
        fi

        printf '%s=%s\n' "$module_id" "$state" >> "$temp_file" || {
            rm -f -- "$temp_file"
            return 1
        }

        mv -- "$temp_file" "$SGND_CONSOLE_MODULE_STATE_FILE"
    }

    # fn$: _sgnd_console_discover_module_files - Discover configured module files
        # . Returns
        #   Writes sorted module paths to stdout.
        #
        # . Usage
        #   mapfile -t modules < <(_sgnd_console_discover_module_files)
    _sgnd_console_discover_module_files() {
        local module_path="${SGND_CONSOLE_MODULE_PATH:?missing module source}"

        if [[ -f "$module_path" ]]; then
            printf '%s\n' "$module_path"
            return 0
        fi

        [[ -d "$module_path" ]] || return 126
        find "$module_path" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z | tr '\0' '\n'
    }

    # fn: _sgnd_console_manage_modules - Enable or disable console modules
        # . Purpose
        #   Edit persisted module visibility without loading disabled modules.
        #
        # . Behavior
        #   - Discovers modules from the configured module source.
        #   - Derives each module ID from its ordered filename.
        #   - Toggles enabled/disabled state in console-modules.state.
        #   - Applies changes on the next console start.
        #
        # . Returns
        #   0 when the user returns to the console; non-zero on state-write failure.
        #
        # . Usage
        #   _sgnd_console_manage_modules
    _sgnd_console_manage_modules() {
        local module_path="${1:-$SGND_CONSOLE_MODULE_PATH}"
        local choice=""
        local module=""
        local module_id=""
        local state=""
        local next_state=""
        local choices="Q"
        local i=0
        local -a module_files=()
        local -a module_ids=()

        local saved_module_path="$SGND_CONSOLE_MODULE_PATH"
        SGND_CONSOLE_MODULE_PATH="$module_path"
        mapfile -t module_files < <(_sgnd_console_discover_module_files) || { SGND_CONSOLE_MODULE_PATH="$saved_module_path"; return $?; }
        SGND_CONSOLE_MODULE_PATH="$saved_module_path"
        (( ${#module_files[@]} > 0 )) || {
            saywarning "No console modules were found."
            return 0
        }

        while true; do
            module_ids=()
            choices="Q"

            sgnd_print
            sgnd_print_sectionheader "Console Modules"
            sgnd_print "Select a module to toggle its visibility. Changes apply after restarting the console."
            sgnd_print

            for i in "${!module_files[@]}"; do
                module="${module_files[$i]}"
                module_id="$(_sgnd_console_module_id_from_filename "$module")"
                module_ids+=("$module_id")
                state="$(_sgnd_console_module_state_get "$module_id")"
                choices+=",$((i + 1))"
                sgnd_print_labeledvalue \
                    --label "$((i + 1))) $module_id" \
                    --value "${state^}" \
                    --labelwidth 34
            done

            sgnd_print
            sgnd_print "Q) Return"

            ask_choose_immediate \
                --label "Select module" \
                --choices "$choices" \
                --instantchoices "Q" \
                --displaychoices 0 \
                --keepasking 1 \
                --preservecase 1 \
                --var choice

            [[ "${choice^^}" != "Q" ]] || return 0
            [[ "$choice" =~ ^[0-9]+$ ]] || continue
            (( choice >= 1 && choice <= ${#module_ids[@]} )) || continue

            module_id="${module_ids[$((choice - 1))]}"
            if [[ "$module_id" == "console-settings" ]]; then
                sayinfo "Console Settings is always enabled."
                continue
            fi
            state="$(_sgnd_console_module_state_get "$module_id")"
            if [[ "$state" == "enabled" ]]; then
                next_state="disabled"
            else
                next_state="enabled"
            fi

            _sgnd_console_module_state_set "$module_id" "$next_state" || {
                sayfail "Could not update module visibility for $module_id"
                return 1
            }
        done
    }

    # fn: sgnd_console_package_installed - Test whether a Debian package is installed
        # . Purpose
        #   Evaluate a package-backed console role requirement.
        #
        # . Behavior
        #   - When SGND_CONSOLE_ROLE_AWARE is enabled, checks the actual Debian
        #     package installation state.
        #   - When SGND_CONSOLE_ROLE_AWARE is disabled, treats the role requirement
        #     as satisfied so development environments can expose all role-aware
        #     console functionality.
        #   - Does not affect persisted module enable/disable state.
        #
        # Inputs (globals):
        #   SGND_CONSOLE_ROLE_AWARE
        #
        # . Arguments
        #   $1  PACKAGE
        #       Debian package name used as the role-presence indicator.
        #
        # . Returns
        #   0 when role awareness is disabled or the package is installed.
        #   1 when role awareness is enabled and the package is not installed.
        #
        # . Usage
        #   sgnd_console_package_installed "samba-ad-dc"
    sgnd_console_package_installed() {
        local package="${1:?missing package name}"

        if ! _sgnd_flag_is_on "${SGND_CONSOLE_ROLE_AWARE:-1}"; then
            return 0
        fi

        [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" == "install ok installed" ]]
    }

    # --- Module loading -------------------------------------------------------------
    # fn: _sgnd_console_source_module - Source one console module
        # . Arguments
        #   $1  MODULE_FILE
        #       Readable .sh file to source.
        #
        # Outputs (globals):
        #   SGND_CURRENT_MODULE
        #   SGND_CURRENT_MODULE_DIR
        #
        # . Returns
        #   0 on success.
        #   126 when the module cannot be loaded.
        #
        # . Usage
        #   _sgnd_console_source_module "/usr/local/libexec/solidgroundux/console-modules/20-machine-config.sh"
    _sgnd_console_source_module() {
        local module_file="${1:?missing module file}"
        local module_id=""
        local module_name=""
        local module_version=""
        local module_desc=""
        local module_count=0

        unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
        unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
        SGND_CURRENT_MODULE="$(_sgnd_console_module_id_from_filename "$module_file")"
        SGND_CURRENT_MODULE_DIR="$(dirname "$module_file")"
        saydebug "Loading module: $module_file"

        # shellcheck source=/dev/null
        source "$module_file" || {
            sayfail "Failed to load module: $module_file"
            unset SGND_CURRENT_MODULE SGND_CURRENT_MODULE_DIR
            unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
            unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
            return 126
        }

        module_id="$(_sgnd_console_module_id_from_filename "$module_file")"
        module_name="${SGND_MODULE_NAME:-}"
        module_version="${SGND_MODULE_VERSION:-}"
        module_desc="${SGND_MODULE_DESC:-}"

        if [[ -z "$module_name" || -z "$module_version" || -z "$module_desc" ]]; then
            sayfail "Module metadata is incomplete: $module_file"
            unset SGND_CURRENT_MODULE SGND_CURRENT_MODULE_DIR
            unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
            unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
            return 126
        fi

        if sgnd_dt_has_row "$SGND_MODULE_SCHEMA" SGND_MODULE_ROWS id "$module_id"; then
            sayfail "Duplicate module ID rejected: $module_id"
            unset SGND_CURRENT_MODULE SGND_CURRENT_MODULE_DIR
            unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
            unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
            return 126
        fi

        module_count="$(sgnd_dt_row_count SGND_MODULE_ROWS)"
        if (( module_count == 0 )); then
            [[ -n "${SGND_CONSOLE_TITLE_OVERRIDE:-}" ]] && SGND_CONSOLE_TITLE="$SGND_CONSOLE_TITLE_OVERRIDE"
            [[ -n "${SGND_CONSOLE_DESC_OVERRIDE:-}" ]] && SGND_CONSOLE_DESC="$SGND_CONSOLE_DESC_OVERRIDE"
        fi

        sgnd_dt_append "$SGND_MODULE_SCHEMA" SGND_MODULE_ROWS \
            "$module_id" "$module_name" "$module_version" "$module_desc" "$module_file" || {
            sayfail "Failed to record module metadata: $module_id"
            unset SGND_CURRENT_MODULE SGND_CURRENT_MODULE_DIR
            unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
            unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
            return 126
        }

        unset SGND_CURRENT_MODULE SGND_CURRENT_MODULE_DIR
        unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
        unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
    }

    # fn: _sgnd_console_load_modules - Load configured console modules
        # . Purpose
        #   Load enabled modules from the configured module source.
        #
        # . Behavior
        #   - Derives module IDs from filenames before sourcing modules.
        #   - Treats missing visibility entries as enabled.
        #   - Skips modules explicitly marked disabled in console-modules.state.
        #   - Loads enabled modules in sorted filename order.
        #   - Shows transient progress while enabled modules are loaded.
        #
        # . Returns
        #   0 on success.
        #   126 when the module source is invalid or an enabled module fails to load.
        #
        # . Usage
        #   _sgnd_console_load_modules || return $?
    _sgnd_console_load_modules() {
        local module=""
        local module_id=""
        local module_count=0
        local module_index=0
        local module_name=""
        local -a discovered_files=()
        local -a module_files=()

        mapfile -t discovered_files < <(_sgnd_console_discover_module_files) || return $?

        for module in "${discovered_files[@]}"; do
            module_id="$(_sgnd_console_module_id_from_filename "$module")"
            if _sgnd_console_module_enabled "$module_id"; then
                module_files+=("$module")
            else
                saydebug "Skipping disabled console module: $module_id"
            fi
        done

        module_count="${#module_files[@]}"
        if (( module_count == 0 )); then
            saywarning "No enabled console modules found in: $SGND_CONSOLE_MODULE_PATH"
            return 0
        fi

        sayprogress_begin --slots 1

        for module in "${module_files[@]}"; do
            module_index=$((module_index + 1))
            module_name="$(basename -- "$module")"

            sayprogress \
                --slot 0 \
                --current "$module_index" \
                --total "$module_count" \
                --label "Initializing $module_name" \
                --type 7 \
                --padleft 0

            _sgnd_console_source_module "$module" || {
                sayprogress_done
                return 126
            }
        done

        sayprogress_done
        return 0
    }

# --- Script execution ----------------------------------------------------------------
    # _sgnd_build_command_args
        # . Returns
        #   0 after populating the requested argument array.
        #
        # . Usage
        #   _sgnd_build_command_args command_args "$@"
    _sgnd_build_command_args() {
        local -n result_ref="${1:?missing result array}"
        shift

        result_ref=()
        _sgnd_flag_is_on "${FLAG_DRYRUN:-0}" && result_ref+=("--dryrun")
        result_ref+=("$@")
    }

    # _sgnd_run_public_command
        # . Purpose
        #   Sgnd run public command.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _sgnd_run_public_command "framework-smoketest"
    _sgnd_run_public_command() {
        local command_name="${1:?missing command name}"
        shift || true
        local resolved=""
        local -a command_args=()

        if [[ -x "${SGND_CONSOLE_BIN_DIRECTORY%/}/$command_name" ]]; then
            resolved="${SGND_CONSOLE_BIN_DIRECTORY%/}/$command_name"
        elif [[ -x "${SGND_CONSOLE_SBIN_DIRECTORY%/}/$command_name" ]]; then
            resolved="${SGND_CONSOLE_SBIN_DIRECTORY%/}/$command_name"
        else
            resolved="$(command -v -- "$command_name" 2>/dev/null || true)"
        fi

        [[ -n "$resolved" && -x "$resolved" ]] || {
            sayfail "Public command not found or not executable: $command_name"
            return 1
        }

        _sgnd_build_command_args command_args "$@"
        saydebug "Executing public command: $resolved ${command_args[*]}"
        "$resolved" "${command_args[@]}"
    }

    # _sgnd_run_module_script
        # . Purpose
        #   Locates and executes a console helper script from the canonical
        #   SolidGroundUX executable or library directories.
        #
        # . Arguments
        #   $1  Script filename.
        #   $@  Optional arguments passed to the script.
        #
        # . Returns
        #   Returns the exit status of the executed script.
        #   Returns 1 when the script cannot be found or is not executable.
        #
        # . Usage
        #   _sgnd_run_module_script "set-identity.sh"
        #   _sgnd_run_module_script "prepare-template.sh" --dryrun
    _sgnd_run_module_script() {
        local script_name="${1:?missing script name}"
        shift

        local resolved=""
        local candidate=""
        local -a search_directories=(
            "$SGND_COMMON_EXE"
            "$SGND_COMMON_LIB"
        )
        local -a command_args=()

        [[ "$script_name" != */* ]] || {
            sayfail "Module script must be a filename: $script_name"
            return 1
        }

        for candidate in "${search_directories[@]}"; do
            [[ -n "$candidate" ]] || continue

            candidate="${candidate%/}/${script_name}"

            if [[ -f "$candidate" && -x "$candidate" ]]; then
                resolved="$candidate"
                break
            fi
        done

        if [[ -z "$resolved" ]]; then
            sayfail "Module script not found or not executable: $script_name"
            saydebug "Searched: ${search_directories[*]}"
            return 1
        fi

        _sgnd_build_command_args command_args "$@"

        saydebug "Executing module script: $resolved ${command_args[*]}"
        "$resolved" "${command_args[@]}"
    }

    # fn: _sgnd_flag_is_on - Interpret a console flag value
        # . Purpose
        #   Evaluate whether a value represents a logical "true".
        #
        # Accepted values:
        #   1, true, TRUE, yes, YES, on, ON
        #
        # . Arguments
        #   $1  VALUE
        #       Value to evaluate.
        #
        # . Returns
        #   0 if VALUE is considered on
        #   1 otherwise
        #
        # . Usage
        #   _sgnd_flag_is_on 1 && printf 'Flag is enabled\n'
        #
        # Examples:
        #   _sgnd_flag_is_on "${SGND_LOGFILE_ENABLED:-0}"
    _sgnd_flag_is_on() {
        case "${1:-}" in
            1|true|TRUE|yes|YES|on|ON) return 0 ;;
            *) return 1 ;;
        esac
    }


    # fn: _sgnd_console_set_role_awareness - Set role-aware console visibility
        # . Purpose
        #   Enable or disable package-backed role filtering for console modules.
        #
        # . Behavior
        #   - Prompts for the desired role-awareness state.
        #   - Stores the result in SGND_CONSOLE_ROLE_AWARE.
        #   - The value is persisted through sgnd-console state.
        #   - Changes take effect on the next console start because role-aware
        #     module registration has already completed in the current session.
        #
        # Outputs (globals):
        #   SGND_CONSOLE_ROLE_AWARE
        #
        # . Returns
        #   0 after the preference is updated or left unchanged.
        #
        # . Usage
        #   _sgnd_console_set_role_awareness
    _sgnd_console_set_role_awareness() {
        local decision="YES"

        if ! _sgnd_flag_is_on "${SGND_CONSOLE_ROLE_AWARE:-1}"; then
            decision="NO"
        fi

        ask_decision             --label "Role-aware console visibility"             --choices "YES|Y,NO|N"             --default "$decision"             --var decision

        case "$decision" in
            YES) SGND_CONSOLE_ROLE_AWARE=1 ;;
            NO)  SGND_CONSOLE_ROLE_AWARE=0 ;;
        esac

        if _sgnd_flag_is_on "$SGND_CONSOLE_ROLE_AWARE"; then
            sayok "Role-aware console visibility enabled."
        else
            saywarning "Role-aware console visibility disabled."
        fi

        sayinfo "The change will take effect after restarting the console."
        SGND_LAST_WAITSECS=0
        return 0
    }

    # _sgnd_console_toggle_role_awareness
        # Returns:
        #   0 after toggling role-aware console visibility for the current session.
        #
        # Usage:
        #   _sgnd_console_toggle_role_awareness
    _sgnd_console_toggle_role_awareness() {
        : "${SGND_CONSOLE_ROLE_AWARE:=1}"

        if _sgnd_flag_is_on "$SGND_CONSOLE_ROLE_AWARE"; then
            SGND_CONSOLE_ROLE_AWARE=0
            saywarning "Role-aware console visibility disabled."
        else
            SGND_CONSOLE_ROLE_AWARE=1
            sayok "Role-aware console visibility enabled."
        fi

        SGND_LAST_WAITSECS=0
        return 0
    }

    # fn: _sgnd_console_open_shell - Open an interactive child shell
        # . Purpose
        #   Open a new interactive shell and return to the Management Console on exit.
        #
        # . Behavior
        #   - Uses the current user's configured shell when available.
        #   - Falls back to /bin/bash.
        #   - Inherits the current console privilege level and environment.
        #   - Does not replace the console process.
        #
        # . Usage
        #   _sgnd_console_open_shell
    _sgnd_console_open_shell() {
        local shell_path="${SHELL:-/bin/bash}"

        [[ -x "$shell_path" ]] || shell_path="/bin/bash"
        [[ -x "$shell_path" ]] || {
            sayfail "No usable interactive shell was found."
            return 1
        }

        sgnd_print "$SGND_UI_TEXT Opening $shell_path. Type 'exit' to return to the Management Console."
        "$shell_path" -i
        SGND_LAST_WAITSECS=0
    }

    # fn: _sgnd_console_restart - Restart the current console instance
        # . Purpose
        #   Replace the current console process with a fresh instance using the
        #   current console invocation and run mode.
        #
        # . Behavior
        #   - Reuses the original console arguments.
        #   - Preserves the current dry-run or commit state.
        #   - Replaces the current process with exec instead of nesting a new console.
        #   - Reloads framework libraries, console modules, and runtime state.
        #
        # . Returns
        #   Does not return after a successful restart; returns 1 when restart fails.
        #
        # . Usage
        #   _sgnd_console_restart
    _sgnd_console_restart() {
        local arg=""
        local -a restart_args=()

        for arg in "${SGND_CONSOLE_ORIGINAL_ARGS[@]}"; do
            case "$arg" in
                --dryrun) ;;
                *) restart_args+=("$arg") ;;
            esac
        done

        _sgnd_flag_is_on "${FLAG_DRYRUN:-0}" && restart_args=("--dryrun" "${restart_args[@]}")

        saydebug "Restarting console: $SGND_SCRIPT_FILE ${restart_args[*]}"
        exec "$SGND_SCRIPT_FILE" "${restart_args[@]}"

        sayfail "Failed to restart console"
        return 1
    }

    # fn: _sgnd_console_toggle_access - Relaunch with the opposite privilege level
        # . Purpose
        #   Replace the current console process with a root or standard-access instance.
        #
        # . Behavior
        #   - Standard sessions relaunch through sudo.
        #   - Sessions started through sudo relaunch as the original SUDO_USER.
        #   - Direct root logins cannot infer a standard user and remain unchanged.
        #   - Preserves the current dry-run state and original console arguments.
        #
        # . Returns
        #   Does not return after a successful relaunch; returns 1 on failure.
        #
        # . Usage
        #   _sgnd_console_toggle_access
    _sgnd_console_toggle_access() {
        local arg=""
        local -a relaunch_args=()

        for arg in "${SGND_CONSOLE_ORIGINAL_ARGS[@]}"; do
            case "$arg" in
                --dryrun) ;;
                *) relaunch_args+=("$arg") ;;
            esac
        done

        _sgnd_flag_is_on "${FLAG_DRYRUN:-0}" && relaunch_args=("--dryrun" "${relaunch_args[@]}")

        if (( EUID != 0 )); then
            command -v sudo >/dev/null 2>&1 || {
                sayfail "sudo is unavailable; cannot switch to root access"
                return 1
            }

            sayinfo "Relaunching console with root access"
            sudo -k
            exec sudo --preserve-env=SGND_UI_STYLE,SGND_UI_PALETTE,SGND_CONSOLE_LOG_LEVEL,SGND_FILE_LOG_LEVEL \
                -- "$SGND_SCRIPT_FILE" "${relaunch_args[@]}"
        fi

        if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == "root" ]]; then
            saywarning "This is a direct root session; no original standard user is available"
            return 1
        fi

        local target_user="$SUDO_USER"
        local target_home=""

        target_home="$(getent passwd "$target_user" | cut -d: -f6)"
        [[ -n "$target_home" && -d "$target_home" ]] || {
            sayfail "Cannot resolve home directory for standard user: $target_user"
            return 1
        }

        sayinfo "Relaunching console with standard access as $target_user"
        exec sudo -H -u "$target_user" -- \
            env \
                -u SUDO_USER \
                -u SUDO_UID \
                -u SUDO_GID \
                HOME="$target_home" \
                USER="$target_user" \
                LOGNAME="$target_user" \
                "$SGND_SCRIPT_FILE" "${relaunch_args[@]}"
    }

# --- Console loop --------------------------------------------------------------------
    # fn: _sgnd_console_run - Run the console interaction loop
        # . Purpose
        #   Run the interactive console event loop.
        #
        # . Behavior
        #   - Renders the menu.
        #   - Builds the valid choice list for the current menu state.
        #   - Reads a choice via ask_choose_immediate.
        #   - Dispatches the selected handler.
        #   - Exits when a handler returns sentinel value 200.
        #   - Optionally pauses after actions according to SGND_LAST_WAITSECS.
        #
        # . Returns
        #   0 on normal console exit
        #   1 on input or dispatch failure
        #
        # . Usage
        #   _sgnd_console_run
        #
        # Examples:
        #   _sgnd_console_run
    _sgnd_console_run() {
        local choice=""
        local valid_choices=""
        local rc=0

        while true; do
            _sgnd_console_render_menu
            valid_choices="$(_sgnd_console_valid_choices_csv)"
            
            sgnd_print_sectionheader --border "$DL_H" --maxwidth "$(sgnd_terminal_width)"
            ask_choose_immediate \
                --label "Select option" \
                --choices "$valid_choices" \
                --instantchoices "Q,<,>,M,A,S,c,C,f,F,t,T,R,CTRL-R" \
                --displaychoices 0 \
                --keepasking 1 \
                --preservecase 1 \
                --var choice

            _sgnd_console_dispatch "$choice"
            rc=$?
            if (( rc == 200 )); then
                sayinfo "Exiting console"
                return 0
            fi

            saydebug "Calling ask_continue with $SGND_LAST_WAITSECS ?"
            if (( ${SGND_LAST_WAITSECS:-0} > 0 )); then
                saydebug "Calling ask_continue with $SGND_LAST_WAITSECS"
                ask_dlg_autocontinue --seconds "$SGND_LAST_WAITSECS" --message "" --cancel --pause
            fi
        done
    }

# --- Public API ----------------------------------------------------------------------
    # sgnd_console_register_item
        # . Purpose
        #   Register one menu item in the console item model.
        #
        # . Behavior
        #   - Validates key uniqueness.
        #   - Verifies that the handler function exists.
        #   - Assigns a default module-based group when GROUP is empty.
        #   - Auto-registers a fallback group when needed.
        #   - Captures source ownership from SGND_CURRENT_MODULE.
        #   - Appends the item row to SGND_ITEM_ROWS.
        #
        # . Arguments
        #   $1  KEY
        #       Unique item key.
        #   $2  GROUP
        #       Target group key (optional).
        #   $3  LABEL
        #       Display label.
        #   $4  HANDLER
        #       Function name to invoke.
        #   $5  DESC
        #       Optional description.
        #   $6  BUILTIN
        #       1 = builtin item, 0 = normal item.
        #   $7  WAITSECS
        #       Post-action wait duration.
        #   $8  VISIBLE
        #       0 = hidden, 1 = visible/enabled, 2 = visible/disabled.
        #
        # . Returns
        #   0 on success
        #   1 on validation or append failure
        #
        # . Usage
        #   sgnd_console_register_item "Q" "session" "Quit" "_sgnd_console_quit" "Exit console" 1 0 1
        #
        # Examples:
        #   sgnd_console_register_item "sys-status" "system" "System status" "sys_status" "Show system status" 0 15 1
    # fn: sgnd_console_register_item - Register a console menu item
        # . Purpose
        #   Register a console menu item.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sgnd_console_register_item
    sgnd_console_register_item() {
        local key="${1:?missing key}"
        local group="${2:-}"
        local label="${3:?missing label}"
        local handler="${4:?missing handler}"
        local desc="${5:-}"
        local builtin="${6:-0}"
        local waitsecs="${7:-15}"
        local visible="${8:-1}"
        local source="${SGND_CURRENT_MODULE:-}"

        if sgnd_dt_has_row "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS key "$key"; then
            sayfail "Duplicate menu key: $key"
            return 1
        fi

        declare -F "$handler" >/dev/null || {
            sayfail "Handler not defined for menu key '$key': $handler"
            return 1
        }

        if [[ -z "$group" ]]; then
            group="module:${SGND_CURRENT_MODULE:-default}"
        fi

        if ! _sgnd_console_group_exists "$group"; then
            _sgnd_console_register_fallback_group "$group"
        fi

        sgnd_dt_append "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS \
            "$key" "$group" "$label" "$handler" "$desc" "$source" "$builtin" "$waitsecs" "$visible" || {
            sayfail "Failed to register item: $key"
            return 1
        }
    }

    # sgnd_console_register_group
        # . Purpose
        #   Register one menu group in the console group model.
        #
        # . Behavior
        #   - Ignores duplicate group keys.
        #   - Captures source ownership from SGND_CURRENT_MODULE.
        #   - Appends a new group row to SGND_GROUP_ROWS when absent.
        #
        # . Arguments
        #   $1  KEY
        #       Unique group key.
        #   $2  LABEL
        #       Display label.
        #   $3  DESC
        #       Optional description.
        #   $4  BUILTIN
        #       1 = builtin group, 0 = normal group.
        #   $5  VISIBLE
        #       0 = hidden, 1 = visible/enabled, 2 = visible/disabled.
        #   $6  ORD
        #       Sort/order weight.
        #
        # . Returns
        #   0 on success
        #   1 on append failure
        #
        # . Usage
        #   sgnd_console_register_group "system" "System tools" "" 0 1 100
        #
        # Examples:
        #   sgnd_console_register_group "runtime" "Runtime toggles" "" 1 0 980
    # fn: sgnd_console_register_group - Register a console menu group
        # . Purpose
        #   Register a console menu group.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sgnd_console_register_group
    sgnd_console_register_group() {
        local key="${1:?missing group key}"
        local label="${2-}"
        local desc="${3:-}"
        local builtin="${4:-0}"
        local visible="${5:-1}"
        local ord="${6:-1000}"
        local source="${SGND_CURRENT_MODULE:-}"

        if sgnd_dt_has_row "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS key "$key"; then
            return 0
        fi

        sgnd_dt_append "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS \
            "$key" "$label" "$desc" "$source" "$builtin" "$visible" "$ord" || {
            sayfail "Failed to register group: $key"
            return 1
        }
    }
# --- Main ----------------------------------------------------------------------------
    # main
        # . Purpose
        #   Execute the sgnd-console startup and interactive runtime flow.
        #
        # . Behavior
        #   - Resolves and loads the framework bootstrap library.
        #   - Initializes framework runtime via sgnd_bootstrap.
        #   - Executes builtin framework argument handling.
        #   - Updates run-mode UI state.
        #   - Loads console configuration.
        #   - Registers builtin groups and items.
        #   - Loads console modules.
        #   - Starts the interactive console loop.
        #
        # . Arguments
        #   $@  Framework and script-specific command-line arguments.
        #
        # . Returns
        #   Exits with the resulting status from bootstrap or console logic.
        #
        # . Usage
        #   main "$@"
        #
        # Examples:
        #   main "$@"
    # fn: main - Run the executable main sequence
        # . Purpose
        #   Run the executable main sequence.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   main
    main() {
        SGND_CONSOLE_ORIGINAL_ARGS=("$@")

        # -- Startup
            _framework_locator || exit $?
            sgnd_exe_start --no-title --autostate -- "$@"

            sgnd_clear
            sgnd_print "Initializing SolidGroundUX Management Console"
            sgnd_print "Initializing paths" 
            _sgnd_console_init_paths || exit $?

        # -- Main script logic

        declare -F sgnd_dt_append >/dev/null || {
            sayfail "sgnd-datatable.sh did not load correctly"
            exit 126
        }

        sgnd_print "Loading console configuration"
        _sgnd_console_load_config || exit $?

        # Console preferences have already been restored from sgnd-console state.
        # An explicitly supplied command-line value has the highest precedence.
        if [[ -n "${VAL_MAXROWS:-}" ]]; then
            SGND_PAGE_MAX_ROWS="$VAL_MAXROWS"
        fi

        SGND_PAGE_INDEX=0

        sgnd_print "Registering builtin menu items"
        _sgnd_console_register_builtin_items || exit $?

        sgnd_print "Loading console modules"
        _sgnd_console_load_modules || exit $?

        if (( SGND_CLEAR_ONRENDER )); then
            sgnd_clear
        fi

        if (( $(sgnd_dt_row_count SGND_ITEM_ROWS) == 0 )); then
            saywarning "No menu items registered"
        fi

        sgnd_print "Starting interactive console"
        _sgnd_console_run
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
