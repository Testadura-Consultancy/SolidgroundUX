# =====================================================================================
# SolidGroundUX - Bootstrap Environment
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2620301
#   Checksum    : e339766a8d0b4dd7fe1e54f1954744363e74281742d42239efaf73dce086ecae
#   Source      : sgnd-bootstrap-env.sh
#   Type        : library
#   Group       : Bootstrap
#   Purpose     : Initialize framework environment variables and directory structure
#
# Description:
#   Establishes the runtime environment for SolidGroundUX scripts.
#
#   The library:
#     - Defines and initializes core framework directories
#     - Resolves system and user paths (config, state, logs, etc.)
#     - Ensures required directories exist with proper permissions
#     - Applies default values for environment variables when unset
#     - Normalizes environment behavior across different execution contexts
#
# Design principles:
#   - Deterministic environment setup regardless of execution context
#   - Clear separation between framework root and application root
#   - Safe defaults with minimal assumptions about host system
#   - Idempotent setup (safe to run multiple times)
#
# Role in framework:
#   - Core bootstrap layer responsible for environment initialization
#   - Runs early in the bootstrap process before other libraries depend on it
#   - Provides foundational paths and variables used across all modules
#
# Non-goals:
#   - Argument parsing (handled by sgnd-args.sh)
#   - Configuration loading (handled by sgnd-cfg.sh)
#   - UI or user interaction
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Library guard
        # . Purpose
        #   Prevent direct execution of a source-only module and avoid repeated initialization.
        #
        # . Behavior
        #   - Derives a module-specific guard variable from the current filename.
        #   - Exits with status 2 when the file is executed directly.
        #   - Returns immediately when the module has already been loaded.
        #   - Marks the module as loaded before normal initialization continues.
        #
        # . Returns
        #   0 when the module may continue loading or was already loaded.
        #   Exits with status 2 when executed directly.
        #
        # . Usage
        #   _sgnd_lib_guard
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

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# --- Framework identity --------------------------------------------------------------
    # var: Framework identity
        # . Purpose
        #   Define product, version, license, and documentation identity used by
        #   framework metadata, informational output, and license checks.
    SGND_PRODUCT="SolidGroundUX"
    SGND_VERSION="1.8"
    SGND_BUILD="2620308"
    SGND_COMPANY="Testadura Consultancy"
    SGND_COPYRIGHT="© 2025 - 2026 Testadura Consultancy"
    SGND_LICENSE="Testadura Non-Commercial License (TD-NC) v1.1."
    SGND_LICENSE_ACCEPTED=0
    SGND_RELEASE_URL="https://github.com/Testadura-Mark/SolidGroundUX/releases"    
    SGND_ONLINE_DOC="https://testadura-consultancy.github.io/SolidGroundUX/"
    
# --- Framework metadata --------------------------------------------------------------
    # var: SGND_FRAMEWORK_GLOBALS - Framework configuration variable registry
        # . Purpose
        #   Declare framework variables that may be managed through system and/or user
        #   configuration files.
        #
        # Format:
        #   audience|VARNAME|Description|extra
        #
        # Fields:
        #   audience    system, user, or both.
        #   VARNAME     Framework global variable name.
        #   Description Human-readable description for config/help output.
        #   extra       Reserved for future metadata.
    SGND_FRAMEWORK_GLOBALS=(
        "system|SGND_SYSCFG_DIR|Framework-wide system configuration directory|"
        "system|SGND_DOCS_DIR|Framework-wide documentation directory|"
        "both|SGND_CONSOLE_LOG_LEVEL|Controls console message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"
        "both|SGND_FILE_LOG_LEVEL|Controls file message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"
        "system|SGND_LOG_PATH|Primary log file or directory path|"
        "both|SGND_ALTLOG_PATH|Alternate log path override|"                    # <- both
        "system|SGND_LOG_MAX_BYTES|Maximum log file size before rotation|"
        "system|SGND_LOG_KEEP|Number of rotated log files to retain|"
        "system|SGND_LOG_COMPRESS|Compress rotated log files|"

        "user|SGND_STATE_DIR|User-specific persistent state directory|"
        "user|SGND_USRCFG_DIR|User-specific configuration directory|"

        "both|SGND_UI_STYLE|Default UI style file (basename or path)|"          # <- both
        "both|SGND_UI_PALETTE|Default UI palette file (basename or path)|"      # <- both

        "user|SAY_COLORIZE_DEFAULT|Default colorized console output setting|"
        "user|SAY_DATE_DEFAULT|Default timestamp visibility|"
        "user|SAY_SHOW_DEFAULT|Default console message visibility|"
        "user|SAY_DATE_FORMAT|Default date/time format for console output|"
    )

    # var: SGND_CORE_LIBS - Ordered core library list
        # . Purpose
        #   Define the core libraries that sgnd-bootstrap loads in fixed order.
        #
        # Notes:
        #   - Ordering is part of the bootstrap contract.
        #   - Earlier libraries may be required by later ones.
    SGND_CORE_LIBS=(
        sgnd-args.sh
        sgnd-info.sh
        sgnd-cfg.sh
        sgnd-system.sh
        sgnd-core.sh
        ui.sh
        ui-say.sh
        ui-ask.sh
        ui-glyphs.sh
    )

    # var: SGND_FRAMEWORK_DIRS - Framework directory specifications
        # . Purpose
        #   Hold the rebuilt path specification list consumed by sgnd_ensure_dirs.
        #
        # Format:
        #   s|/path   system-owned directory.
        #   u|/path   user-owned directory.
    SGND_FRAMEWORK_DIRS=(
    )

    SGND_RUNTIME_GLOBALS=(
        "both|SGND_FRAMEWORK_ROOT|Root path used as the base for framework filesystem locations.|"
        "both|SGND_APPLICATION_ROOT|Root path used as the base for application filesystem locations.|"
        "both|SGND_COMMON_LIB|Directory containing common SolidGroundUX library files.|"
        "system|SGND_SYSCFG_DIR|Directory containing system-level SolidGroundUX configuration files.|"
        "user|SGND_USRCFG_DIR|Directory containing user-level SolidGroundUX configuration files.|"
        "user|SGND_STATE_DIR|Directory containing user-level SolidGroundUX state files.|"
        "system|SGND_STYLE_DIR|Directory containing SolidGroundUX style and palette files.|"
        "system|SGND_DOCS_DIR|Directory containing SolidGroundUX documentation files.|"
        "system|SGND_LOG_PATH|Primary logfile path for framework or application logging.|"
        "user|SGND_ALTLOG_PATH|Fallback user-level logfile path for framework or application logging.|"

        "both|SGND_LOG_MAX_BYTES|Maximum logfile size before log rotation is attempted.|"
        "both|SGND_LOG_KEEP|Number of rotated logfile copies to retain.|"
        "both|SGND_LOG_COMPRESS|Controls whether rotated logfiles are compressed.|"
        "both|SGND_CONSOLE_LOG_LEVEL|Controls console message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"
        "both|SGND_FILE_LOG_LEVEL|Controls file message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"

        "user|SGND_USER_HOME|Effective user home directory, honoring SUDO_USER when present.|"

        "both|SGND_UI_STYLE|Selected SolidGroundUX UI style file.|"
        "both|SGND_UI_PALETTE|Selected SolidGroundUX UI palette file.|"

        "both|SAY_DATE_DEFAULT|Default setting controlling whether say output includes a timestamp.|"
        "both|SAY_SHOW_DEFAULT|Default say output prefix mode, such as label, icon, symbol, or combinations.|"
        "both|SAY_COLORIZE_DEFAULT|Default say colorization mode, such as none, label, msg, both, all, or date.|"
        "both|SAY_DATE_FORMAT|Date format used when say output includes timestamps.|"

        "both|SGND_FRAMEWORK_CFG_BASENAME|Basename of the framework globals configuration file.|"
        "user|SGND_FRAMEWORK_STATEFILE|User-specific framework runtime state file.|"
    )

    SGND_FRAMEWORK_STATE=(
        SGND_CONSOLE_LOG_LEVEL
        SGND_FILE_LOG_LEVEL
        SGND_UI_STYLE
        SGND_UI_PALETTE
        SAY_DATE_FORMAT
    )
    
# --- Helpers -------------------------------------------------------------------------
    # fn: _build_framework_dirs - Build framework directory specifications
        # . Purpose
        #   Rebuild the directory specification list used by sgnd_ensure_dirs.
        #
        # . Behavior
        #   - Uses the currently rebased framework path globals.
        #   - Marks framework-owned paths as system directories.
        #   - Marks user configuration, state, and alternate log paths as user directories.
        #
        # Inputs (globals):
        #   SGND_COMMON_LIB, SGND_SYSCFG_DIR, SGND_USRCFG_DIR, SGND_STATE_DIR,
        #   SGND_STYLE_DIR, SGND_DOCS_DIR, SGND_LOG_PATH, SGND_ALTLOG_PATH
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_DIRS
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _build_framework_dirs
    _build_framework_dirs(){
        SGND_FRAMEWORK_DIRS=(
            "s|$SGND_COMMON_LIB"
            "s|$SGND_SYSCFG_DIR"
            "u|$SGND_USRCFG_DIR"
            "u|$SGND_STATE_DIR"
            "s|$SGND_STYLE_DIR"
            "s|$SGND_DOCS_DIR"
            "s|$(dirname "$SGND_LOG_PATH")"
            "u|$(dirname "$SGND_ALTLOG_PATH")"
        )
    }
    # fn: sgnd_apply_defaults - Apply defaults
        # . Purpose
        #   Apply default framework path, metadata, runtime, UI, and logging globals when they are not already set.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_apply_defaults
    sgnd_apply_defaults() {
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

        : "${SGND_LOG_MAX_BYTES:=$((25 * 1024 * 1024))}"
        : "${SGND_LOG_KEEP:=20}"
        : "${SGND_LOG_COMPRESS:=1}"

        : "${SGND_CONSOLE_LOG_LEVEL:=silent}"
        : "${SGND_FILE_LOG_LEVEL:=verbose}"

        if [[ -n "${SUDO_USER:-}" ]]; then
            SGND_USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        else
            SGND_USER_HOME="$HOME"
        fi

        : "${SGND_UI_STYLE:=00-style-default.sh}"
        : "${SGND_UI_PALETTE:=default-ui-palette.sh}"

        : "${SAY_DATE_DEFAULT:=0}"
        : "${SAY_SHOW_DEFAULT:=label}"
        : "${SAY_COLORIZE_DEFAULT:=label}"
        : "${SAY_DATE_FORMAT:=%Y-%m-%d %H:%M:%S}"

        : "${SGND_FRAMEWORK_CFG_BASENAME:=sgnd_framework_globals.cfg}"

    }
    # fn: sgnd_defaults_reset - Defaults reset
        # . Purpose
        #   Reset default framework environment values so they can be rebuilt from the current root.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_defaults_reset
    sgnd_defaults_reset() {
        local spec audience var desc extra
        for spec in "${SGND_FRAMEWORK_GLOBALS[@]}"; do
            IFS='|' read -r audience var desc extra <<< "$spec"
            [[ -n "$var" ]] || continue
            unset "$var" || true
        done


        sgnd_apply_defaults
    }
    # fn: sgnd_rebase_directories - Rebase directories
        # . Purpose
        #   Recalculate framework directory globals from the current SGND_FRAMEWORK_ROOT.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_rebase_directories
    sgnd_rebase_directories() {
        local product=""

        saydebug "Rebasing directories"

        product="$(printf '%s' "${SGND_PRODUCT:-solidgroundux}" | tr '[:upper:]' '[:lower:]')"

        SGND_COMMON_LIB="$SGND_FRAMEWORK_ROOT/usr/local/lib/$product/common"
        SGND_SYSCFG_DIR="$SGND_APPLICATION_ROOT/etc/$product"
        SGND_USRCFG_DIR="$SGND_USER_HOME/.config/$product"
        SGND_STATE_DIR="$SGND_USER_HOME/.state/$product"
        SGND_FRAMEWORK_STATEFILE="$SGND_USRCFG_DIR/framework.state"
        SGND_STYLE_DIR="$SGND_FRAMEWORK_ROOT/usr/local/lib/$product/styles"

        SGND_DOCS_DIR="$SGND_FRAMEWORK_ROOT/usr/local/share/testadura/$product/doc"   # May be absent in dev/minimal installs
        SGND_LOCAL_DOC="$SGND_DOCS_DIR/$product/index.html"
        SGND_LICENSE_FILE="$SGND_FRAMEWORK_ROOT/usr/local/share/testadura/$product/LICENSE"   # May be absent in dev/minimal installs
        SGND_README_FILE="$SGND_FRAMEWORK_ROOT/usr/local/share/testadura/$product/README.md"

        SGND_PYTHON_DIR="$SGND_FRAMEWORK_ROOT/usr/local/lib/$product/py"   # May be absent in dev/minimal installs

        # logs (paths only)
        SGND_LOG_PATH="$SGND_FRAMEWORK_ROOT/var/log/$product.log"
        SGND_ALTLOG_PATH="$SGND_USER_HOME/.log/$product.log"

        # script-scoped paths
        if [[ -n "${SGND_SCRIPT_NAME:-}" ]]; then
            SGND_SYSCFG_FILE="$SGND_SYSCFG_DIR/$SGND_SCRIPT_NAME.cfg"
            SGND_USRCFG_FILE="$SGND_USRCFG_DIR/$SGND_SCRIPT_NAME.cfg"
            SGND_STATE_FILE="$SGND_STATE_DIR/$SGND_SCRIPT_NAME.state"
        fi

        _build_framework_dirs
    }
    # fn: sgnd_rebase_framework_cfg_paths - Rebase framework cfg paths
        # . Purpose
        #   Recalculate framework configuration file paths from the configured etc directory.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_rebase_framework_cfg_paths
    sgnd_rebase_framework_cfg_paths() {
        SGND_FRAMEWORK_SYSCFG_FILE="$SGND_SYSCFG_DIR/$SGND_FRAMEWORK_CFG_BASENAME"
        SGND_FRAMEWORK_USRCFG_FILE="$SGND_USRCFG_DIR/$SGND_FRAMEWORK_CFG_BASENAME"
    }
    # fn: sgnd_ensure_dirs - Ensure dirs
        # . Purpose
        #   Create the standard SolidGroundUX runtime, cache, log, state, and configuration directories.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_ensure_dirs
    sgnd_ensure_dirs() {
        local spec
        local kind
        local dir
        local owner=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            owner="$SUDO_USER"
        fi
        
        if [[ -n "$owner" ]]; then
            sayinfo "Creating directories for user-owned paths as $owner"
        else
            sayinfo "Creating framework directories"
        fi
        
        for spec in "$@"; do
            IFS='|' read -r kind dir <<< "$spec"
            [[ -z "$dir" ]] && continue

            sayinfo "Trying $dir"
            if [[ ! -d "$dir" ]]; then
                mkdir -p -- "$dir" || {
                    sayfail "Cannot create directory: $dir"
                    return 1
                }
            fi

            if [[ "$kind" == "u" ]]; then
                if [[ -n "$owner" ]]; then
                    sayinfo "Set owner"
                    chown "$owner:$owner" "$dir" 2>/dev/null || true
                fi
                sayinfo "Set user rights"

                chmod u+rwx "$dir" 2>/dev/null || true
            fi
        done
    }

