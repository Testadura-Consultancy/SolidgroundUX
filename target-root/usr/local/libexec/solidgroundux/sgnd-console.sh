#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Console Host
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2620501
#   Checksum    : 28484360a95d1a50dd0e375ca38ca3a87b2d21ccc66b31023e1ece3c20709295
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
    SGND_SCRIPT_TITLE="sgnd-console"
    : "${SGND_SCRIPT_DESC:=Generic SolidGroundUX console host}"
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
        "maxrows||value|VAL_MAXROWS|Maximum menu rows per page||"
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
        SGND_CONSOLE_BIN_DIRECTORY=""
        SGND_CONSOLE_SBIN_DIRECTORY=""
        SGND_CONSOLE_LIBEXEC_DIRECTORY=""
        SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY=""
        SGND_CONSOLE_MODULE_PATH=""
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
        SGND_PAGE_MAX_ROWS=15
            
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
        : "${SGND_PAGE_MAX_ROWS:=15}"

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

        saydebug "Console title : $SGND_CONSOLE_TITLE"
        saydebug "Console desc  : $SGND_CONSOLE_DESC"
        saydebug "Module source : $SGND_CONSOLE_MODULE_PATH"
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
        SGND_GROUP_RUNTIME="runtime"
        SGND_GROUP_SESSION="session"

        sgnd_console_register_group "$SGND_GROUP_RUNTIME" "Runtime toggles" "" 1 0 980
        sgnd_console_register_group "$SGND_GROUP_SESSION" "Console Session" "" 1 1 990

        sgnd_console_register_item "A" "$SGND_GROUP_RUNTIME" "Access" "_sgnd_console_toggle_access" "Relaunch with root or standard access" 1 0 0
        sgnd_console_register_item "D" "$SGND_GROUP_RUNTIME" "Dry-run / Commit" "_sgnd_console_toggle_dryrun" "Toggle dry-run mode" 1 0 0
        sgnd_console_register_item "c" "$SGND_GROUP_RUNTIME" "Console log level" "_sgnd_console_cycle_console_loglevel" "Cycle console log level" 1 0 0
        sgnd_console_register_item "f" "$SGND_GROUP_RUNTIME" "File log level" "_sgnd_console_cycle_file_loglevel" "Cycle file log level" 1 0 0
        sgnd_console_register_item "t" "$SGND_GROUP_RUNTIME" "Theme" "_sgnd_console_cycle_theme" "Cycle installed themes" 1 0 0

        sgnd_console_register_item "L" "$SGND_GROUP_SESSION" "Set lines per page" "_sgnd_console_set_lines_per_page" "Set the maximum number of menu lines per page" 1 0 1
        sgnd_console_register_item "<" "$SGND_GROUP_SESSION" "Previous page" "_sgnd_console_prevpage" "Show previous menu page" 1 0 0
        sgnd_console_register_item ">" "$SGND_GROUP_SESSION" "Next page" "_sgnd_console_nextpage" "Show next menu page" 1 0 0
        sgnd_console_register_item "R" "$SGND_GROUP_SESSION" "Redraw menu" "_sgnd_console_redraw" "Refresh console display" 1 0 1
        sgnd_console_register_item "Q" "$SGND_GROUP_SESSION" "Quit" "_sgnd_console_quit" "Exit console" 1 0 1
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
        #   _sgnd_console_register_fallback_group "$group_key"
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
        #   if _sgnd_console_group_exists "$group"; then ...
        #
        # Examples:
        #   _sgnd_console_group_exists "runtime"
    _sgnd_console_group_exists() {
        local key="${1:?missing group key}"

        sgnd_dt_has_row "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS key "$key"
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
        #   _sgnd_console_source_module "$module"
    _sgnd_console_source_module() {
        local module_file="${1:?missing module file}"
        local module_id=""
        local module_name=""
        local module_version=""
        local module_desc=""
        local module_count=0

        unset SGND_MODULE_ID SGND_MODULE_NAME SGND_MODULE_VERSION SGND_MODULE_DESC
        unset SGND_CONSOLE_TITLE_OVERRIDE SGND_CONSOLE_DESC_OVERRIDE
        SGND_CURRENT_MODULE="$(basename "${module_file%.sh}")"
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

        module_id="${SGND_MODULE_ID:-}"
        module_name="${SGND_MODULE_NAME:-}"
        module_version="${SGND_MODULE_VERSION:-}"
        module_desc="${SGND_MODULE_DESC:-}"

        if [[ -z "$module_id" || -z "$module_name" || -z "$module_version" || -z "$module_desc" ]]; then
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
        #   Load one module file or all modules in a configured directory.
        #
        # . Behavior
        #   - Sources SGND_CONSOLE_MODULE_PATH directly when it is a .sh file.
        #   - Sources every top-level .sh file when it is a directory.
        #   - Loads directory modules in sorted filename order.
        #   - Warns when a directory contains no modules.
        #
        # Inputs (globals):
        #   SGND_CONSOLE_MODULE_PATH
        #
        # . Returns
        #   0   success
        #   126 module source missing or module load failed
        #
        # . Usage
        #   _sgnd_console_load_modules || return $?
    _sgnd_console_load_modules() {
        local module_path="${SGND_CONSOLE_MODULE_PATH:?missing module source}"
        local module=""
        local -a module_files=()

        if [[ -f "$module_path" ]]; then
            _sgnd_console_source_module "$module_path"
            return $?
        fi

        [[ -d "$module_path" ]] || {
            sayfail "Module source not found: $module_path"
            return 126
        }

        mapfile -t module_files < <(
            find "$module_path" -maxdepth 1 -type f -name '*.sh' -print0 |
                sort -z |
                while IFS= read -r -d '' module; do
                    printf '%s\n' "$module"
                done
        )

        if (( ${#module_files[@]} == 0 )); then
            saywarning "No modules found in: $module_path"
            return 0
        fi

        for module in "${module_files[@]}"; do
            _sgnd_console_source_module "$module" || return 126
        done
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

    _sgnd_run_module_script() {
        local module_id="${1:?missing module ID}"
        local script_name="${2:?missing script name}"
        shift 2
        local resolved="${SGND_CONSOLE_DEFAULT_MODULE_DIRECTORY%/}/${module_id}/${script_name}"
        local -a command_args=()

        [[ "$script_name" != */* ]] || {
            sayfail "Module script must be a filename: $script_name"
            return 1
        }
        [[ -f "$resolved" && -x "$resolved" ]] || {
            sayfail "Module script not found or not executable: $resolved"
            return 1
        }

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
        #   if _sgnd_flag_is_on "${FLAG_DEBUG:-0}"; then ...
        #
        # Examples:
        #   _sgnd_flag_is_on "${SGND_LOGFILE_ENABLED:-0}"
    _sgnd_flag_is_on() {
        case "${1:-}" in
            1|true|TRUE|yes|YES|on|ON) return 0 ;;
            *) return 1 ;;
        esac
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
                --instantchoices "A,C,D,F,T,L,R,Q,<,>" \
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
        local label="${2:?missing group label}"
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
            sgnd_exe_start --state -- "$@"
            _sgnd_console_init_paths || exit $?

        # -- Main script logic

        declare -F sgnd_dt_append >/dev/null || {
            sayfail "sgnd-datatable.sh did not load correctly"
            exit 126
        }

        _sgnd_console_load_config || exit $?

        # Script state has already been restored by sgnd_exe_start --state.
        # An explicitly supplied command-line value has the highest precedence.
        if [[ -n "${VAL_MAXROWS:-}" ]]; then
            SGND_PAGE_MAX_ROWS="$VAL_MAXROWS"
        fi

        SGND_PAGE_INDEX=0

        _sgnd_console_register_builtin_items || exit $?
        _sgnd_console_load_modules || exit $?

        if (( $(sgnd_dt_row_count SGND_ITEM_ROWS) == 0 )); then
            saywarning "No menu items registered"
        fi

            _sgnd_console_run
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
