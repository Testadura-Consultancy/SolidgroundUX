#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Console Host
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2617512
#   Checksum    : 68212cfab6cde6deee86061b6a9244bc52d79950730f3293fdd46c48e5096a17
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
#     - Persists runtime flags such as debug, verbose, and dry-run
#
# Design principles:
#   - Modular architecture with clear separation of host and modules
#   - Convention-based module registration
#   - Minimal assumptions about module implementation
#   - Consistent user interaction patterns across all tools
#
# Role in framework:
#   - Central entry point for interactive SolidGroundUX tooling
#   - Hosts and orchestrates functionality provided by console modules
#
# Non-goals:
#   - Implementing business logic directly in the console host
#   - Managing module-specific state beyond registration and dispatch
#   - Providing a full TUI framework beyond structured menu interaction
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
    SGND_SCRIPT_TITLE="Solidground Console"
    : "${SGND_SCRIPT_DESC:=Interactive console module host}"
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
        "appcfg||value|VAL_APPCFG|Path to console app config file|"
        "maxrows||value|VAL_MAXROWS|Maximum menu rows per page|10|"
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
        "  sgnd-console.sh --appcfg ./my-console.cfg"
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
    SGND_STATE_SAVE=0

# --- Local scripts and definitions ---------------------------------------------------
    # --- Console state
        SGND_GROUP_SCHEMA="key|label|desc|source|builtin|visible|ord"
        declare -ag SGND_GROUP_ROWS=()

        SGND_ITEM_SCHEMA="key|group|label|handler|desc|source|builtin|waitsecs|visible"
        declare -ag SGND_ITEM_ROWS=()

        SGND_MODULE_SCHEMA="id|name|desc|source"
        declare -ag SGND_MODULE_ROWS=()



        SGND_CONSOLE_TITLE="Solidground Console"
        SGND_CONSOLE_DESC="Interactive scalable console module host"
        SGND_CONSOLE_MODULE_DIR=""
        SGND_CURRENT_MODULE=""
        SGND_LAST_WAITSECS=15

        declare -ag SGND_VISIBLE_ITEM_INDEXES=()
        declare -ag SGND_GROUP_RENDER_INDEXES=()

        SGND_CLEAR_ONRENDER=1

        SGND_PAGE_INDEX=0
        declare -ag SGND_PAGE_STARTS=()
        SGND_PAGE_HAS_PREV=0
        SGND_PAGE_HAS_NEXT=0
        SGND_PAGE_MAX_ROWS=15
            
    # --- Console configuration -------------------------------------------------------
    # _sgnd_console_load_config
        # . Purpose
        #   Load console-specific configuration and resolve the module directory.
        #
        # . Behavior
        #   - Applies built-in defaults for title, description, module directory,
        #     and page size.
        #   - Applies --maxrows when provided.
        #   - If --appcfg was provided and the file does not exist, creates it.
        #   - Sources the appcfg when present.
        #   - Resolves a relative module directory against the appcfg directory.
        #   - Normalizes SGND_CONSOLE_MODULE_DIR to an absolute path.
        #
        # Configuration variables:
        #   SGND_CONSOLE_TITLE
        #   SGND_CONSOLE_DESC
        #   SGND_CONSOLE_MODULE_DIR
        #   SGND_PAGE_MAX_ROWS
        #
        # Inputs (globals):
        #   VAL_APPCFG
        #   VAL_MAXROWS
        #
        # Outputs (globals):
        #   SGND_CONSOLE_TITLE
        #   SGND_CONSOLE_DESC
        #   SGND_CONSOLE_MODULE_DIR
        #   SGND_PAGE_MAX_ROWS
        #
        # . Returns
        #   0   success
        #   126 unreadable config
        #   127 config could not be created or written
        #
        # . Usage
        #   _sgnd_console_load_config || return $?
        #
        # Examples:
        #   _sgnd_console_load_config
    # fn: _sgnd_console_load_config - Load console configuration
        # . Purpose
        #   Load console configuration.
        #
        # . Behavior
        #   - Internal helper.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _sgnd_console_load_config
    _sgnd_console_load_config() {
        local cfg="${VAL_APPCFG-}"
        local cfg_dir

        : "${SGND_CONSOLE_TITLE:=${SGND_SCRIPT_TITLE}}"
        : "${SGND_CONSOLE_DESC:=${SGND_SCRIPT_DESC}}"
        : "${SGND_CONSOLE_MODULE_DIR:=./console-modules}"
        : "${SGND_PAGE_MAX_ROWS:=15}"

        if [[ -n "${VAL_MAXROWS:-}" ]]; then
            SGND_PAGE_MAX_ROWS="$VAL_MAXROWS"
        fi

        if [[ -n "$cfg" ]]; then
            if [[ ! -e "$cfg" ]]; then
                _sgnd_console_create_appcfg "$cfg" || return $?
            fi

            [[ -r "$cfg" ]] || {
                sayfail "Cannot read appcfg: $cfg"
                return 126
            }

            cfg="$(readlink -f -- "$cfg")"
            cfg_dir="$(dirname -- "$cfg")"

            # shellcheck source=/dev/null
            source "$cfg"

            : "${SGND_CONSOLE_TITLE:=${SGND_SCRIPT_TITLE}}"
            : "${SGND_CONSOLE_DESC:=${SGND_SCRIPT_DESC}}"
            : "${SGND_CONSOLE_MODULE_DIR:=./console-modules}"

            case "$SGND_CONSOLE_MODULE_DIR" in
                /*) ;;
                *) SGND_CONSOLE_MODULE_DIR="${cfg_dir}/${SGND_CONSOLE_MODULE_DIR}" ;;
            esac
        fi

        SGND_CONSOLE_MODULE_DIR="$(readlink -f -- "$SGND_CONSOLE_MODULE_DIR")"

        saydebug "Console title: $SGND_CONSOLE_TITLE"
        saydebug "Console desc : $SGND_CONSOLE_DESC"
        saydebug "Module dir    : $SGND_CONSOLE_MODULE_DIR"
    }

    # fn: _sgnd_console_create_appcfg - Create console application configuration
        # . Purpose
        #   Create a new console app configuration file with sensible defaults.
        #
        # . Behavior
        #   - Prompts interactively for title, description, and module directory
        #     when running on a TTY.
        #   - Uses defaults automatically in non-interactive mode.
        #   - Creates the parent directory if needed.
        #   - Writes a minimal shell-style config file.
        #
        # . Arguments
        #   $1  CFG_PATH
        #       Path of the appcfg file to create.
        #
        # . Returns
        #   0   success
        #   127 config directory or file could not be created
        #
        # . Usage
        #   _sgnd_console_create_appcfg "$cfg"
        #
        # Examples:
        #   _sgnd_console_create_appcfg "./my-console.cfg"
    _sgnd_console_create_appcfg() {
        local cfg="${1:?missing cfg path}"
        local cfg_dir
        local cfg_title="Solidground Console"
        local cfg_desc="Interactive host for console modules"
        local cfg_moddir="./console-modules"

        cfg_dir="$(cd -- "$(dirname -- "$cfg")" && pwd -P 2>/dev/null || dirname -- "$cfg")"

        sayinfo "Console appcfg not found; creating: $cfg"

        if [[ -t 0 && -t 1 ]]; then
            ask --label "Title" \
                --default "$cfg_title" \
                --var cfg_title

            ask --label "Description" \
                --default "$cfg_desc" \
                --var cfg_desc

            ask --label "Module directory" \
                --default "$cfg_moddir" \
                --var cfg_moddir
        fi

        mkdir -p -- "$(dirname -- "$cfg")" || {
            sayfail "Cannot create config directory for: $cfg"
            return 127
        }

        {
            printf "SGND_CONSOLE_TITLE=%q\n" "$cfg_title"
            printf "SGND_CONSOLE_DESC=%q\n" "$cfg_desc"
            printf "SGND_CONSOLE_MODULE_DIR=%q\n" "$cfg_moddir"
        } > "$cfg" || {
            sayfail "Cannot write appcfg: $cfg"
            return 127
        }

        sayok "Created appcfg: $cfg"
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

        sgnd_console_register_item "B" "$SGND_GROUP_RUNTIME" "$(_sgnd_console_label_debug)" "_sgnd_console_toggle_debug" "Toggle debug output" 1 0 0
        sgnd_console_register_item "D" "$SGND_GROUP_RUNTIME" "$(_sgnd_console_label_dryrun)" "_sgnd_console_toggle_dryrun" "Toggle dry-run mode" 1 0 0
        sgnd_console_register_item "L" "$SGND_GROUP_RUNTIME" "$(_sgnd_console_label_logfile)" "_sgnd_console_toggle_logfile" "Toggle logfile output" 1 0 0
        sgnd_console_register_item "V" "$SGND_GROUP_RUNTIME" "$(_sgnd_console_label_verbose)" "_sgnd_console_toggle_verbose" "Toggle verbose output" 1 0 1

        sgnd_console_register_item "C" "$SGND_GROUP_SESSION" "$(_sgnd_console_label_clearonrender)" "_sgnd_console_toggle_clearonrender" "Toggle clear screen before rendering" 1 0 0
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
    # _sgnd_console_load_modules
        # . Purpose
        #   Source all console module scripts from the configured module directory.
        #
        # . Behavior
        #   - Verifies that the module directory exists.
        #   - Sources each "*.sh" module file found in that directory.
        #   - Sets SGND_CURRENT_MODULE while loading each module so registration
        #     APIs can attribute source ownership correctly.
        #   - Warns when no modules are found.
        #
        # Inputs (globals):
        #   SGND_CONSOLE_MODULE_DIR
        #
        # Outputs (globals):
        #   SGND_CURRENT_MODULE
        #
        # . Returns
        #   0   success
        #   126 module directory missing or module load failed
        #
        # . Usage
        #   _sgnd_console_load_modules || return $?
        #
        # Examples:
        #   _sgnd_console_load_modules
    # fn: _sgnd_console_load_modules - Load console modules
        # . Purpose
        #   Load console modules.
        #
        # . Behavior
        #   - Internal helper.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _sgnd_console_load_modules
    _sgnd_console_load_modules() {
        local mod_dir="${SGND_CONSOLE_MODULE_DIR:?missing module dir}"
        local mod
        local found=0

        [[ -d "$mod_dir" ]] || {
            sayfail "Module directory not found: $mod_dir"
            return 126
        }

        shopt -s nullglob
        for mod in "$mod_dir"/*.sh; do
            found=1
            SGND_CURRENT_MODULE="$(basename "${mod%.sh}")"
            saydebug "Loading module: $mod"

            # shellcheck source=/dev/null
            source "$mod" || {
                sayfail "Failed to load module: $mod"
                unset SGND_CURRENT_MODULE
                shopt -u nullglob
                return 126
            }
        done
        shopt -u nullglob
        unset SGND_CURRENT_MODULE

        (( found )) || saywarning "No modules found in: $mod_dir"
    }

# --- Script execution ----------------------------------------------------------------
    # _sgnd_run_script
        # . Purpose
        #   Resolve and execute a script within the sgnd-console environment.
        #
        # . Behavior
        #   - Resolves relative script paths against SGND_SCRIPT_DIR.
        #   - Normalizes the resolved path when readlink is available.
        #   - Verifies that the script exists and is executable.
        #   - Forwards active framework flags to the target script.
        #   - Executes the script with all original remaining arguments preserved.
        #
        # . Arguments
        #   $1  SCRIPT
        #       Script path, absolute or relative to SGND_SCRIPT_DIR.
        #   $@  ARGS
        #       Additional arguments passed to the target script.
        #
        # Forwarded flags:
        #   FLAG_DRYRUN         -> --dryrun
        #   FLAG_VERBOSE        -> --verbose
        #   FLAG_DEBUG          -> --debug
        #   SGND_LOGFILE_ENABLED  -> --logfile <file>
        #
        # . Returns
        #   Exit code of the executed script
        #   1 if validation fails
        #
        # . Usage
        #   _sgnd_run_script "jobs/import.sh" --customer 42
        #
        # Examples:
        #   _sgnd_run_script "./tools/build.sh" --release
        #
        # Notes:
        #   - Uses argument arrays to preserve proper quoting.
    # fn: _sgnd_run_script - Run a tool script from the console
        # . Purpose
        #   Run a tool script from the console.
        #
        # . Behavior
        #   - Internal helper.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _sgnd_run_script
    _sgnd_run_script() {
        local script="${1:?missing script}"
        shift || true

        local resolved="$script"
        local -a script_args=()

        case "$script" in
            /*) ;;
            *)
                resolved="${SGND_SCRIPT_DIR%/}/$script"
                ;;
        esac

        if command -v readlink >/dev/null 2>&1; then
            resolved="$(readlink -f -- "$resolved" 2>/dev/null || printf '%s' "$resolved")"
        fi

        [[ -f "$resolved" ]] || {
            sayfail "Script not found: $resolved"
            return 1
        }

        [[ -x "$resolved" ]] || {
            sayfail "Script not executable: $resolved"
            return 1
        }

        _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"        && script_args+=("--dryrun")
        _sgnd_flag_is_on "${FLAG_VERBOSE:-0}"       && script_args+=("--verbose")
        _sgnd_flag_is_on "${FLAG_DEBUG:-0}"         && script_args+=("--debug")
        _sgnd_flag_is_on "${SGND_LOGFILE_ENABLED:-0}" && [[ -n "${LOG_FILE:-}" ]] && script_args+=("--logfile" "$LOG_FILE")

        script_args+=("$@")

        saydebug "Executing script: $resolved ${script_args[*]}"

        "$resolved" "${script_args[@]}"
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
                --instantchoices "B,D,L,V,C,<,>" \
                --displaychoices 0 \
                --keepasking 1 \
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
                ask_continue "" "${SGND_LAST_WAITSECS}"
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
        # -- Startup
            _framework_locator || exit $?
            sgnd_exe_start -- "$@"

        # -- Main script logic

        declare -F sgnd_dt_append >/dev/null || {
            sayfail "sgnd-datatable.sh did not load correctly"
            exit 126
        }
        _sgnd_console_load_config || exit $?
        _sgnd_console_register_builtin_items || exit $?
        _sgnd_console_load_modules || exit $?

        if (( $(sgnd_dt_row_count SGND_ITEM_ROWS) == 0 )); then
            saywarning "No menu items registered"
        fi

            _sgnd_console_run
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
