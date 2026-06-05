# =====================================================================================
# SolidGroundUX - Bootstrap Environment
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
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
        # Purpose:
        #   Prevent direct execution of a source-only module and avoid repeated initialization.
        #
        # Behavior:
        #   - Derives a module-specific guard variable from the current filename.
        #   - Exits with status 2 when the file is executed directly.
        #   - Returns immediately when the module has already been loaded.
        #   - Marks the module as loaded before normal initialization continues.
        #
        # Returns:
        #   0 when the module may continue loading or was already loaded.
        #   Exits with status 2 when executed directly.
        #
        # Usage:
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
        # Purpose:
        #   Define product, version, license, and documentation identity used by
        #   framework metadata, informational output, and license checks.
    SGND_PRODUCT="SolidGroundUX"
    SGND_VERSION="1.5"
    SGND_VERSION_DATE="2026-01-08"
    SGND_COMPANY="Testadura Consultancy"
    SGND_COPYRIGHT="© 2025 - 2026 Testadura Consultancy"
    SGND_LICENSE="Testadura Non-Commercial License (TD-NC) v1.1."
    SGND_LICENSE_FILE="LICENSE"
    SGND_LICENSE_ACCEPTED=0
    SGND_README_FILE="README.md"

# --- Framework metadata --------------------------------------------------------------
    # var: SGND_FRAMEWORK_GLOBALS - Framework configuration variable registry
        # Purpose:
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
        "system|SGND_LOGFILE_ENABLED|Enable or disable logfile output|"
        "both|SGND_LOG_LEVEL|Console output level (off, quiet, normal, debug)|"
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
        # Purpose:
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
        # Purpose:
        #   Hold the rebuilt path specification list consumed by sgnd_ensure_dirs.
        #
        # Format:
        #   s|/path   system-owned directory.
        #   u|/path   user-owned directory.
    SGND_FRAMEWORK_DIRS=(
    )

# --- Helpers -------------------------------------------------------------------------
    # fn: _build_framework_dirs - Build framework directory specifications
        # Purpose:
        #   Rebuild the directory specification list used by sgnd_ensure_dirs.
        #
        # Behavior:
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
        # Returns:
        #   0 always.
        #
        # Usage:
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
# --- Public API ----------------------------------------------------------------------
    # fn: sgnd_apply_defaults - Apply framework default values
        # Purpose:
        #   Initialize default framework environment values without overwriting explicit settings.
        #
        # Behavior:
        #   - Sets default framework and application roots.
        #   - Sets logging, UI style, UI palette, and console-output defaults.
        #   - Resolves the effective user home, honoring SUDO_USER when present.
        #   - Sets the framework configuration basename.
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT, SGND_LOG_* values, SGND_USER_HOME,
        #   SGND_UI_STYLE, SGND_UI_PALETTE, SAY_* defaults, SGND_FRAMEWORK_CFG_BASENAME
        #
        # Returns:
        #   0 always unless a command substitution fails under caller error policy.
        #
        # Usage:
        #   sgnd_apply_defaults
    sgnd_apply_defaults() {
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

        : "${SGND_LOG_MAX_BYTES:=$((25 * 1024 * 1024))}"
        : "${SGND_LOG_KEEP:=20}"
        : "${SGND_LOG_COMPRESS:=1}"

        : "${SGND_LOGFILE_ENABLED:=0}"
        : "${SGND_LOG_LEVEL:=normal}"

        if [[ -n "${SUDO_USER:-}" ]]; then
            SGND_USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        else
            SGND_USER_HOME="$HOME"
        fi

        : "${SGND_UI_STYLE:=default-ui-style.sh}"
        : "${SGND_UI_PALETTE:=default-ui-palette.sh}"

        : "${SAY_DATE_DEFAULT:=0}"
        : "${SAY_SHOW_DEFAULT:=label}"
        : "${SAY_COLORIZE_DEFAULT:=label}"
        : "${SAY_DATE_FORMAT:=%Y-%m-%d %H:%M:%S}"

        : "${SGND_FRAMEWORK_CFG_BASENAME:=sgnd_framework_globals.cfg}"

    }

    # fn: sgnd_defaults_reset - Reset framework defaults
        # Purpose:
        #   Clear configurable framework globals and reapply default values.
        #
        # Behavior:
        #   - Iterates SGND_FRAMEWORK_GLOBALS.
        #   - Unsets each listed framework global variable.
        #   - Calls sgnd_apply_defaults to restore default values.
        #
        # Inputs (globals):
        #   SGND_FRAMEWORK_GLOBALS
        #
        # Outputs (globals):
        #   Framework globals reset by sgnd_apply_defaults.
        #
        # Returns:
        #   0 when defaults are reset successfully.
        #
        # Usage:
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

    # fn: sgnd_rebase_directories - Recalculate framework paths
        # Purpose:
        #   Derive all framework and script path globals from the current roots and product name.
        #
        # Behavior:
        #   - Lowercases SGND_PRODUCT for filesystem path construction.
        #   - Rebuilds common library, configuration, state, style, documentation, Python, and log paths.
        #   - Rebuilds script-specific config and state paths when SGND_SCRIPT_NAME is known.
        #   - Rebuilds SGND_FRAMEWORK_DIRS after path recalculation.
        #
        # Inputs (globals):
        #   SGND_PRODUCT, SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT, SGND_USER_HOME,
        #   SGND_SCRIPT_NAME
        #
        # Outputs (globals):
        #   SGND_COMMON_LIB, SGND_SYSCFG_DIR, SGND_USRCFG_DIR, SGND_STATE_DIR,
        #   SGND_STYLE_DIR, SGND_DOCS_DIR, SGND_PYTHON_DIR, SGND_LOG_PATH,
        #   SGND_ALTLOG_PATH, SGND_SYSCFG_FILE, SGND_USRCFG_FILE, SGND_STATE_FILE,
        #   SGND_FRAMEWORK_DIRS
        #
        # Returns:
        #   0 always unless path helper commands fail under caller error policy.
        #
        # Usage:
        #   sgnd_rebase_directories
    sgnd_rebase_directories() {
        local product=""

        saydebug "Rebasing directories"

        product="$(printf '%s' "${SGND_PRODUCT:-solidgroundux}" | tr '[:upper:]' '[:lower:]')"

        SGND_COMMON_LIB="$SGND_FRAMEWORK_ROOT/usr/local/lib/$product/common"
        SGND_SYSCFG_DIR="$SGND_APPLICATION_ROOT/etc/$product"
        SGND_USRCFG_DIR="$SGND_USER_HOME/.config/$product"
        SGND_STATE_DIR="$SGND_USER_HOME/.state/$product"
        SGND_STYLE_DIR="$SGND_FRAMEWORK_ROOT/usr/local/lib/$product/styles"
        SGND_DOCS_DIR="$SGND_FRAMEWORK_ROOT/usr/local/share/doc/$product"   # May be absent in dev/minimal installs
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

    # fn: sgnd_rebase_framework_cfg_paths - Recalculate framework config file paths
        # Purpose:
        #   Build system and user framework configuration file paths from current directories.
        #
        # Behavior:
        #   - Combines SGND_SYSCFG_DIR and SGND_USRCFG_DIR with SGND_FRAMEWORK_CFG_BASENAME.
        #
        # Inputs (globals):
        #   SGND_SYSCFG_DIR, SGND_USRCFG_DIR, SGND_FRAMEWORK_CFG_BASENAME
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_SYSCFG_FILE, SGND_FRAMEWORK_USRCFG_FILE
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_rebase_framework_cfg_paths
    sgnd_rebase_framework_cfg_paths() {
        SGND_FRAMEWORK_SYSCFG_FILE="$SGND_SYSCFG_DIR/$SGND_FRAMEWORK_CFG_BASENAME"
        SGND_FRAMEWORK_USRCFG_FILE="$SGND_USRCFG_DIR/$SGND_FRAMEWORK_CFG_BASENAME"
    }

    # fn: sgnd_ensure_dirs - Ensure framework directories exist
        # Purpose:
        #   Create framework system and user directories declared in path specifications.
        #
        # Behavior:
        #   - Accepts entries in kind|directory format.
        #   - Creates missing directories with mkdir -p.
        #   - For user directories, applies user ownership when running through sudo.
        #   - Grants user read/write/execute permissions on user directories.
        #
        # Arguments:
        #   $@  Directory specifications in s|/path or u|/path format.
        #
        # Returns:
        #   0 when all required directories exist or were created.
        #   1 when a directory cannot be created.
        #
        # Usage:
        #   sgnd_ensure_dirs "${SGND_FRAMEWORK_DIRS[@]}"
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

