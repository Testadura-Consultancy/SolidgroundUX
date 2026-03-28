# =====================================================================================
# SolidgroundUX - Bootstrap Environment
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : bb68d813d8375b2a46f23c1d752f923ff78a9576235ead0c684328aaa6647120
#   Source      : sgnd-bootstrap-env.sh
#   Type        : library
#   Purpose     : Initialize framework environment variables and directory structure
#
# Description:
#   Establishes the runtime environment for SolidgroundUX scripts.
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
#   - Argument parsing (handled by args.sh)
#   - Configuration loading (handled by cfg.sh)
#   - UI or user interaction
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Behavior:
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
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
    # Product/branding metadata used by framework-info, logging headers, and about text.
    SGND_PRODUCT="SolidgroundUX"
    SGND_VERSION="1.0-R2-beta"
    SGND_VERSION_DATE="2026-01-08"
    SGND_COMPANY="Testadura Consultancy"
    SGND_COPYRIGHT="© 2025 Mark Fieten — Testadura Consultancy"
    SGND_LICENSE="Testadura Non-Commercial License (TD-NC) v1.0"
    SGND_LICENSE_FILE="LICENSE"
    SGND_LICENSE_ACCEPTED=0
    SGND_README_FILE="README.md"

# --- Framework metadata --------------------------------------------------------------
    # SGND_FRAMEWORK_GLOBALS spec format:
        #   audience|VARNAME|Human-readable description|extra
        #   - audience: system | user | both
        #   - extra: reserved for future metadata (currently unused)
    SGND_FRAMEWORK_GLOBALS=(
        "system|SGND_SYSCFG_DIR|Framework-wide system configuration directory|"
        "system|SGND_DOCS_DIR|Framework-wide documentation directory|"
        "system|SGND_LOGFILE_ENABLED|Enable or disable logfile output|"
        "both|SGND_LOG_TO_CONSOLE|Enable or disable console logging|"
        "both|SGND_CONSOLE_MSGTYPES|Console message types to display|"          # <- both
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

    # SGND_CORE_LIBS:
        #   Core libraries sourced by td-bootstrap in this exact order.
        #   Ordering is part of the bootstrap contract.
    SGND_CORE_LIBS=(
        sgnd-args.sh
        sgnd-info.sh
        sgnd-cfg.sh
        sgnd-core.sh
        ui.sh
        ui-say.sh
        ui-ask.sh
        ui-glyphs.sh
    )

    SGND_FRAMEWORK_DIRS=(
    )
# --- Helpers -------------------------------------------------------------------------
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
    # sgnd_apply_defaults
        # Purpose:
        #   Apply default values for bootstrap globals if currently unset.
        #
        # Behavior:
        #   - Initializes root variables (SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT).
        #   - Sets logging and UI defaults.
        #   - Resolves SGND_USER_HOME (prefers SUDO_USER when present).
        #   - Establishes framework cfg basename.
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT
        #   SGND_USER_HOME
        #   SGND_LOG_*, SGND_LOGFILE_ENABLED, SGND_LOG_TO_CONSOLE, SGND_CONSOLE_MSGTYPES
        #   SGND_UI_STYLE, SGND_UI_PALETTE
        #   SAY_* defaults
        #   SGND_FRAMEWORK_CFG_BASENAME
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_apply_defaults
        #
        # Examples:
        #   sgnd_apply_defaults
        #
        #   # Override before applying defaults
        #   SGND_LOGFILE_ENABLED=1
        #   sgnd_apply_defaults
    sgnd_apply_defaults() {
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

        : "${SGND_LOG_MAX_BYTES:=$((25 * 1024 * 1024))}"
        : "${SGND_LOG_KEEP:=20}"
        : "${SGND_LOG_COMPRESS:=1}"

        : "${SGND_LOGFILE_ENABLED:=0}"
        : "${SGND_LOG_TO_CONSOLE:=1}"
        : "${SGND_CONSOLE_MSGTYPES:=STRT|WARN|FAIL|INFO|END}"

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

    # sgnd_defaults_reset
        # Purpose:
        #   Reset all framework-global configuration variables to their default state.
        #
        # Behavior:
        #   - Iterates over SGND_FRAMEWORK_GLOBALS specifications.
        #   - Extracts each declared variable name.
        #   - Unsets those variables (ignores unset failures).
        #   - Re-applies defaults via sgnd_defaults_apply().
        #
        # Inputs (globals):
        #   SGND_FRAMEWORK_GLOBALS
        #
        # Side effects:
        #   - Unsets variables declared in SGND_FRAMEWORK_GLOBALS.
        #   - Reinitializes them according to sgnd_defaults_apply().
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_defaults_reset
        #
        # Examples:
        #   sgnd_defaults_reset
        #
        # Notes:
        #   - Intended for development/testing and controlled reinitialization.
        #   - SGND_FRAMEWORK_GLOBALS is the authoritative list of resettable globals.
    sgnd_defaults_reset() {
        local spec audience var desc extra
        for spec in "${SGND_FRAMEWORK_GLOBALS[@]}"; do
            IFS='|' read -r audience var desc extra <<< "$spec"
            [[ -n "$var" ]] || continue
            unset "$var" || true
        done


        sgnd_defaults_apply
    }

    # sgnd_rebase_directories
        # Purpose:
        #   Derive standard framework directory and file paths from current root settings.
        #
        # Behavior:
        #   - Computes framework-scoped directories from:
        #       SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT, SGND_USER_HOME
        #   - Derives logging paths.
        #   - Optionally derives script-scoped cfg/state paths when SGND_SCRIPT_NAME is set.
        #   - Rebuilds SGND_FRAMEWORK_DIRS via _build_framework_dirs.
        #
        # Inputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #   SGND_USER_HOME
        #   SGND_SCRIPT_NAME (optional)
        #
        # Outputs (globals):
        #   SGND_COMMON_LIB, SGND_SYSCFG_DIR, SGND_USRCFG_DIR, SGND_STATE_DIR
        #   SGND_STYLE_DIR, SGND_DOCS_DIR
        #   SGND_LOG_PATH, SGND_ALTLOG_PATH
        #   SGND_SYSCFG_FILE, SGND_USRCFG_FILE, SGND_STATE_FILE (optional)
        #   SGND_FRAMEWORK_DIRS
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_rebase_directories
        #
        # Examples:
        #   sgnd_apply_defaults
        #   sgnd_rebase_directories
        #
        #   SGND_SCRIPT_NAME="install"
        #   sgnd_rebase_directories
    sgnd_rebase_directories() {
        saydebug "Rebasing directories"
        SGND_COMMON_LIB="$SGND_FRAMEWORK_ROOT/usr/local/lib/testadura/common"
        SGND_SYSCFG_DIR="$SGND_APPLICATION_ROOT/etc/testadura"
        SGND_USRCFG_DIR="$SGND_USER_HOME/.config/testadura"
        SGND_STATE_DIR="$SGND_USER_HOME/.state/testadura"
        SGND_STYLE_DIR="$SGND_FRAMEWORK_ROOT/usr/local/lib/testadura/styles"
        SGND_DOCS_DIR="$SGND_FRAMEWORK_ROOT/usr/local/share/doc/solidgroundux"   # May be absent in dev/minimal installs

        # logs (paths only)
        SGND_LOG_PATH="$SGND_FRAMEWORK_ROOT/var/log/testadura/solidgroundux.log"
        SGND_ALTLOG_PATH="$SGND_USER_HOME/.log/testadura/solidgroundux.log"

        # script-scoped paths
        if [[ -n "${SGND_SCRIPT_NAME:-}" ]]; then
            SGND_SYSCFG_FILE="$SGND_SYSCFG_DIR/$SGND_SCRIPT_NAME.cfg"
            SGND_USRCFG_FILE="$SGND_USRCFG_DIR/$SGND_SCRIPT_NAME.cfg"
            SGND_STATE_FILE="$SGND_STATE_DIR/$SGND_SCRIPT_NAME.state"
        fi

        _build_framework_dirs
    }

    # sgnd_rebase_framework_cfg_paths
        # Purpose:
        #   Derive framework-global cfg file paths from current cfg directories.
        #
        # Behavior:
        #   - Uses SGND_FRAMEWORK_CFG_BASENAME as the filename.
        #   - Produces system and user cfg paths.
        #
        # Inputs (globals):
        #   SGND_SYSCFG_DIR
        #   SGND_USRCFG_DIR
        #   SGND_FRAMEWORK_CFG_BASENAME
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_SYSCFG_FILE
        #   SGND_FRAMEWORK_USRCFG_FILE
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_rebase_framework_cfg_paths
        #
        # Examples:
        #   sgnd_rebase_directories
        #   sgnd_rebase_framework_cfg_paths
    sgnd_rebase_framework_cfg_paths() {
        SGND_FRAMEWORK_SYSCFG_FILE="$SGND_SYSCFG_DIR/$SGND_FRAMEWORK_CFG_BASENAME"
        SGND_FRAMEWORK_USRCFG_FILE="$SGND_USRCFG_DIR/$SGND_FRAMEWORK_CFG_BASENAME"
    }

    # sgnd_ensure_dirs
        # Purpose:
        #   Ensure that framework directories exist and have appropriate ownership.
        #
        # Arguments:
        #   One or more directory specifications:
        #       "s|/path"  system directory
        #       "u|/path"  user directory
        #
        # Behavior:
        #   - Creates directories using mkdir -p.
        #   - For user directories:
        #       - Assigns ownership to SUDO_USER when running under sudo.
        #       - Ensures user has read/write/execute permissions.
        #   - Ignores malformed entries.
        #
        # Inputs (globals):
        #   SUDO_USER
        #   EUID
        #
        # Returns:
        #   0   success
        #   1   failure creating one or more directories
        #
        # Usage:
        #   sgnd_ensure_dirs "s|/path" "u|/path"
        #
        # Examples:
        #   sgnd_ensure_dirs \
        #       "s|$SGND_COMMON_LIB" \
        #       "s|$SGND_SYSCFG_DIR" \
        #       "u|$SGND_USRCFG_DIR" \
        #       "u|$SGND_STATE_DIR"
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

