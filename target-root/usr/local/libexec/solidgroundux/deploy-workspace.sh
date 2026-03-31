#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Deploy Workspace
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : a2d4f9ae263c8a47930125f935dbb66f6632e2d58db07f1e502d9761be267a7e
#   Source      : deploy-workspace.sh
#   Type        : script
#   Purpose     : Deploy or remove a development workspace to or from a target root
#
# Description:
#   Provides a deployment utility that synchronizes a structured workspace
#   into a target filesystem root.
#
#   The script:
#     - Copies files from source to target while preserving structure
#     - Creates destination directories as required
#     - Applies permission policy based on PERMISSION_RULES
#     - Skips private, hidden, and non-deployable files by convention
#     - Records created files and directories in a deploy manifest
#     - Supports manifest-based undeploy operations
#
# Design principles:
#   - Deployment behavior is explicit and predictable
#   - Only created artifacts are tracked for undeploy
#   - Honors dry-run, verbose, and debug run modes
#   - Avoids destructive rollback behavior outside recorded manifests
#
# Role in framework:
#   - Entry point for deploying prepared workspaces into target roots
#   - Supports controlled install and removal workflows for SolidgroundUX assets
#
# Non-goals:
#   - Full rollback of all modified target files
#   - Generic backup or restore functionality
#   - Arbitrary synchronization outside the workspace deployment model
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail
# --- Bootstrap -----------------------------------------------------------------------
    # _framework_locator
        # Purpose:
        #   Locate, create, and load the SolidGroundUX bootstrap configuration.
        #
        # Behavior:
        #   - Searches user and system bootstrap configuration locations.
        #   - Prefers the invoking user's config over the system config.
        #   - Creates a new bootstrap config when none exists.
        #   - Prompts for framework/application roots in interactive mode.
        #   - Applies default values when running non-interactively.
        #   - Sources the selected configuration file.
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # Returns:
        #   0   success
        #   126 configuration unreadable or invalid
        #   127 configuration directory or file could not be created
        #
        # Usage:
        #   _framework_locator || return $?
        #
        # Examples:
        #   _framework_locator
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
        #   - SGND_FRAMEWORK_ROOT is treated as a filesystem root/prefix.
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local framework_root="/"
        local app_root="$framework_root"
        local reply=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
            [[ -n "$cfg_home" ]] || cfg_home="$HOME"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"

        # Determine existing configuration
        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"

        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"

        else
            # Determine creation location
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            # Interactive prompts (first run only)
            if [[ -r /dev/tty && -w /dev/tty ]]; then
                sayinfo "SolidGroundUX bootstrap configuration"
                sayinfo "No configuration file found."
                sayinfo "Creating: $cfg"

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                framework_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [%s] : " "$framework_root" > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$framework_root}"
            fi

            # Validate paths (must be absolute)
            case "$framework_root" in
                /*) ;;
                *)
                    sayfail "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"
                    return 126
                    ;;
            esac

            case "$app_root" in
                /*) ;;
                *)
                    sayfail "ERR: SGND_APPLICATION_ROOT must be an absolute path"
                    return 126
                    ;;
            esac

            # Create bootstrap configuration file
            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$framework_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            saydebug "Created bootstrap cfg: $cfg"
        fi

        # Load configuration
        [[ -r "$cfg" ]] || {
            sayfail "Cannot read bootstrap cfg: $cfg"
            return 126
        }

        # shellcheck source=/dev/null
        source "$cfg"

        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

        saydebug "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT"
    }

    # _load_bootstrapper
        # Purpose:
        #   Resolve and source the framework bootstrap library.
        #
        # Behavior:
        #   - Calls _framework_locator to establish framework roots.
        #   - Derives the sgnd-bootstrap.sh path from SGND_FRAMEWORK_ROOT.
        #   - Verifies that the bootstrap library is readable.
        #   - Sources sgnd-bootstrap.sh into the current shell.
        #
        # Inputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #
        # Returns:
        #   0   success
        #   126 bootstrap library unreadable
        #
        # Usage:
        #   _load_bootstrapper || return $?
        #
        # Examples:
        #   _load_bootstrapper
        #
        # Notes:
        #   - This is executable-level startup logic, not reusable framework behavior.
        #   - SGND_FRAMEWORK_ROOT is treated as a filesystem root/prefix.
    _load_bootstrapper() {
        local bootstrap=""

        _framework_locator || return $?

        bootstrap="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"

        [[ -r "$bootstrap" ]] || {
            printf "FATAL: Cannot read bootstrap: %s\n" "$bootstrap" >&2
            return 126
        }

        saydebug "Loading bootstrap: $bootstrap"

        # shellcheck source=/dev/null
        source "$bootstrap"
    }

    # Minimal colors
    MSG_CLR_INFO=$'\e[38;5;250m'
    MSG_CLR_STRT=$'\e[38;5;82m'
    MSG_CLR_OK=$'\e[38;5;82m'
    MSG_CLR_WARN=$'\e[1;38;5;208m'
    MSG_CLR_FAIL=$'\e[38;5;196m'
    MSG_CLR_CNCL=$'\e[0;33m'
    MSG_CLR_END=$'\e[38;5;82m'
    MSG_CLR_EMPTY=$'\e[2;38;5;250m'
    MSG_CLR_DEBUG=$'\e[1;35m'

    TUI_COMMIT=$'\e[2;37m'
    RESET=$'\e[0m'

    # Minimal UI
    saystart()   { printf '%sSTART%s\t%s\n' "${MSG_CLR_STRT-}" "${RESET-}" "$*" >&2; }
    sayinfo()    { 
        if (( ${FLAG_VERBOSE:-0} )); then
            printf '%sINFO%s \t%s\n' "${MSG_CLR_INFO-}" "${RESET-}" "$*" >&2; 
        fi
    }
    sayok()      { printf '%sOK%s   \t%s\n' "${MSG_CLR_OK-}"   "${RESET-}" "$*" >&2; }
    saywarning() { printf '%sWARN%s \t%s\n' "${MSG_CLR_WARN-}" "${RESET-}" "$*" >&2; }
    sayfail()    { printf '%sFAIL%s \t%s\n' "${MSG_CLR_FAIL-}" "${RESET-}" "$*" >&2; }
    saydebug() {
        if (( ${FLAG_DEBUG:-0} )); then
            printf '%sDEBUG%s \t%s\n' "${MSG_CLR_DEBUG-}" "${RESET-}" "$*" >&2;
        fi
    }
    saycancel() { printf '%sCANCEL%s\t%s\n' "${MSG_CLR_CNCL-}" "${RESET-}" "$*" >&2; }
    sayend() { printf '%sEND%s   \t%s\n' "${MSG_CLR_END-}" "${RESET-}" "$*" >&2; }
    


# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Deploy workspace"
    : "${SGND_SCRIPT_DESC:=Deploy a development workspace to a target root filesystem.}"
    : "${SGND_SCRIPT_VERSION:=1.0}"
    : "${SGND_SCRIPT_BUILD:=20250110}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 Mark Fieten — Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.0}"

    MANIFEST_BASE_DIR="/var/lib/solidgroundux/deploy-workspace"
    MANIFEST_SOURCE_ID=""
    MANIFEST_SOURCE_DIR=""
    MANIFEST_NAME=""
    MANIFEST_PATH=""
    MANIFEST_TMP=""

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
        #   var     = shell variable that will be set
        #   help    = help string for auto-generated --help output
        #   choices = for enum: comma-separated values (e.g. fast,slow,auto)
        #             for flag/value: leave empty
        #
        # Notes:
        #   - -h / --help is built in, you don't need to define it here.
        #   - After parsing you can use: FLAG_VERBOSE, VAL_CONFIG, ENUM_MODE, ...
    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Repeat with last settings|"
        "undeploy|u|flag|FLAG_UNDEPLOY|Remove files from main root|"
        "source|s|value|SRC_ROOT|Set Source directory|"
        "target|t|value|DEST_ROOT|Set Target directory|"
        "manifest|m|value|MANIFEST_NAME|Use a specific manifest name for undeploy|"
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
        "Deploy using defaults:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Undeploy everything:"
        "  $SGND_SCRIPT_NAME --undeploy"
        "  $SGND_SCRIPT_NAME -u"
    ) 

    # SGND_SCRIPT_GLOBALS
        # Explicit declaration of global variables intentionally used by this script.
        #
        # IMPORTANT:
        #   - If this array is non-empty, sgnd_bootstrap will enable config loading.
        #   - Variables listed here may be populated from configuration files.
        #   - This makes SGND_SCRIPT_GLOBALS part of the script’s configuration contract.
        #
        # Use this to:
        #   - Document intentional globals
        #   - Prevent accidental namespace leakage
        #   - Enable cfg integration in a predictable way
        #
        # Only list:
        #   - Variables that are meant to be globally accessible
        #   - Variables that may be set via config files
        #
        # Leave empty if:
        #   - The script does not use config-driven globals
        #
    SGND_SCRIPT_GLOBALS=(
    )

    # SGND_STATE_VARIABLES
        # List of variables participating in persistent state.
        #
        # Purpose:
        #   - Declares which variables should be saved/restored when state is enabled.
        #
        # Behavior:
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
        # Purpose:
        #   - Allows scripts to register cleanup or finalization hooks.
        #
        # Behavior:
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

# --- Local script Declarations -------------------------------------------------------
    # Put script-local constants and defaults here (NOT framework config).
    # Prefer local variables inside functions unless a value must be shared.

    # PERMISSION_RULES
    #   Declarative permission policy for installed paths.
    #
    # Format (pipe-delimited):
    #   "<prefix>|<file_mode>|<dir_mode>|<description>"
    #
    # Matching:
    #   - Longest prefix match wins.
    #   - A rule applies if abs path equals the prefix or is within the prefix folder.
    #
    # Modes:
    #   - file_mode is used for regular files (install -m).
    #   - dir_mode  is used for directories (install -d -m).
    #
    # Notes:
    #   - This is a policy table: keep it stable and predictable.
    #   - Description is informational only; not used in logic.
    PERMISSION_RULES=(
        "/usr/local/bin|755|755|User entry points"
        "/usr/local/sbin|755|755|Admin entry points"
        "/etc/update-motd.d|755|755|Executed by system"
        "/usr/local/lib/solidgroundux|644|755|Implementation only"
        "/usr/local/lib/solidgroundux/common/tools|755|755|Implementation only"
        "/etc/solidgroundux|640|750|Configuration"
        "/var/lib/solidgroundux|600|700|Application state"
    )

# --- local script functions ----------------------------------------------------------
 # -- Manifests
    # _manifest_source_id
        # Purpose:
        #   Derive a stable manifest namespace identifier from SRC_ROOT.
        #
        # Behavior:
        #   - Hashes SRC_ROOT using sha256
        #   - Prints the resulting identifier to stdout
        #
        # Inputs (globals):
        #   SRC_ROOT
        #
        # Output:
        #   Prints source-root identifier to stdout
        #
        # Returns:
        #   0 on success
        #
        # Usage:
        #   id="$(_manifest_source_id)"
        #
        # Notes:
        #   - Used to group manifests by source root
        #   - Keeps on-disk manifest paths safe and deterministic
    _manifest_source_id() {
        printf '%s' "$SRC_ROOT" | sha256sum | awk '{print $1}'
    }

    # _manifest_source_dir
        # Purpose:
        #   Resolve the manifest directory for the current SRC_ROOT.
        #
        # Behavior:
        #   - Derives a stable source-root identifier
        #   - Combines it with MANIFEST_BASE_DIR
        #   - Prints the directory path to stdout
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   MANIFEST_BASE_DIR
        #
        # Output:
        #   Prints manifest directory path to stdout
        #
        # Returns:
        #   0 on success
        #
        # Usage:
        #   dir="$(_manifest_source_dir)"
    _manifest_source_dir() {
        local id
        id="$(_manifest_source_id)"
        printf '%s/%s\n' "$MANIFEST_BASE_DIR" "$id"
    }

    # _manifest_init
        # Purpose:
        #   Initialize a new manifest for the current deployment run.
        #
        # Behavior:
        #   - Creates the source-root-specific manifest directory
        #   - Generates a manifest name if MANIFEST_NAME is not already set
        #   - Creates a temporary manifest file
        #   - Writes manifest header metadata
        #
        # Manifest model:
        #   - One manifest per deploy run
        #   - Manifests are grouped by source root
        #   - Only files and directories CREATED by this run are recorded
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   DEST_ROOT
        #   MANIFEST_BASE_DIR
        #   MANIFEST_NAME
        #   FLAG_DRYRUN
        #
        # Outputs (globals):
        #   MANIFEST_SOURCE_ID
        #   MANIFEST_SOURCE_DIR
        #   MANIFEST_NAME
        #   MANIFEST_PATH
        #   MANIFEST_TMP
        #
        # Returns:
        #   0 on success
        #   1 on failure
        #
        # Usage:
        #   _manifest_init || return $?
        #
        # Notes:
        #   - In dry-run mode, no manifest file is created
        #   - Caller must later invoke _manifest_commit or _manifest_discard
    _manifest_init() {
        local stamp

        MANIFEST_SOURCE_ID="$(_manifest_source_id)"
        MANIFEST_SOURCE_DIR="$(_manifest_source_dir)"

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            stamp="$(date +%Y%m%dT%H%M%S)"
            MANIFEST_NAME="${MANIFEST_NAME:-$stamp}"
            MANIFEST_PATH="${MANIFEST_SOURCE_DIR}/${MANIFEST_NAME}.manifest"
            MANIFEST_TMP="${MANIFEST_PATH}.tmp"
            sayinfo "Would initialize manifest: $MANIFEST_PATH"
            return 0
        fi

        stamp="$(date +%Y%m%dT%H%M%S)"
        MANIFEST_NAME="${MANIFEST_NAME:-$stamp}"
        MANIFEST_PATH="${MANIFEST_SOURCE_DIR}/${MANIFEST_NAME}.manifest"
        MANIFEST_TMP="${MANIFEST_PATH}.tmp"

        install -d -m 700 "$MANIFEST_SOURCE_DIR" || {
            sayfail "Cannot create manifest directory: $MANIFEST_SOURCE_DIR"
            return 1
        }

        {
            printf '%s\n' "# deploy-workspace manifest"
            printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
            printf 'source=%s\n' "$SRC_ROOT"
            printf 'target=%s\n' "${DEST_ROOT:-/}"
            printf 'name=%s\n' "$MANIFEST_NAME"
            printf '\n'
        } > "$MANIFEST_TMP" || {
            sayfail "Cannot create manifest temp file: $MANIFEST_TMP"
            return 1
        }

        saydebug "Initialized manifest temp file: $MANIFEST_TMP"
        return 0
    }

    # _manifest_add_file
        # Purpose:
        #   Record a file CREATED during the current deployment run.
        #
        # Arguments:
        #   $1  abs_rel   Absolute-style relative target path (e.g. "/usr/local/bin/foo")
        #
        # Behavior:
        #   - Appends a file entry to the current manifest temp file
        #   - Does nothing in dry-run mode
        #
        # Manifest entry format:
        #   F|/path/from/target/root
        #
        # Inputs (globals):
        #   MANIFEST_TMP
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0 on success
        #   1 on write failure
        #
        # Usage:
        #   _manifest_add_file "/usr/local/bin/foo"
        #
        # Notes:
        #   - Only call this when the target file did not exist prior to install
    _manifest_add_file() {
        local abs_rel="$1"

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Would record created file in manifest: $abs_rel"
            return 0
        fi

        printf 'F|%s\n' "$abs_rel" >> "$MANIFEST_TMP" || {
            sayfail "Cannot append file entry to manifest: $MANIFEST_TMP"
            return 1
        }
    }

    # _manifest_add_dir
        # Purpose:
        #   Record a directory CREATED during the current deployment run.
        #
        # Arguments:
        #   $1  abs_rel   Absolute-style relative target path (e.g. "/etc/solidgroundux")
        #
        # Behavior:
        #   - Appends a directory entry to the current manifest temp file
        #   - Does nothing in dry-run mode
        #
        # Manifest entry format:
        #   D|/path/from/target/root
        #
        # Inputs (globals):
        #   MANIFEST_TMP
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0 on success
        #   1 on write failure
        #
        # Usage:
        #   _manifest_add_dir "/etc/solidgroundux"
        #
        # Notes:
        #   - Only call this when the target directory did not exist prior to creation
    _manifest_add_dir() {
        local abs_rel="$1"

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Would record created directory in manifest: $abs_rel"
            return 0
        fi

        printf 'D|%s\n' "$abs_rel" >> "$MANIFEST_TMP" || {
            sayfail "Cannot append directory entry to manifest: $MANIFEST_TMP"
            return 1
        }
    }

    # _manifest_commit
        # Purpose:
        #   Finalize the current manifest after a successful deployment run.
        #
        # Behavior:
        #   - Renames the temporary manifest file into its final name
        #   - Does nothing in dry-run mode
        #
        # Inputs (globals):
        #   MANIFEST_TMP
        #   MANIFEST_PATH
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0 on success
        #   1 on failure
        #
        # Usage:
        #   _manifest_commit || return $?
        #
        # Notes:
        #   - Should only be called after deploy completed successfully
    _manifest_commit() {
        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Would commit manifest: $MANIFEST_PATH"
            return 0
        fi

        mv -f -- "$MANIFEST_TMP" "$MANIFEST_PATH" || {
            sayfail "Cannot commit manifest: $MANIFEST_PATH"
            return 1
        }

        saydebug "Committed manifest: $MANIFEST_PATH"
        return 0
    }

    # _manifest_discard
        # Purpose:
        #   Remove the temporary manifest after an interrupted or failed deployment run.
        #
        # Behavior:
        #   - Deletes MANIFEST_TMP if it exists
        #   - Does nothing in dry-run mode
        #
        # Inputs (globals):
        #   MANIFEST_TMP
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0 always
        #
        # Usage:
        #   _manifest_discard
        #
        # Notes:
        #   - Safe to call multiple times
    _manifest_discard() {
        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            return 0
        fi

        if [[ -n "${MANIFEST_TMP:-}" && -e "${MANIFEST_TMP:-}" ]]; then
            rm -f -- "$MANIFEST_TMP"
            saydebug "Discarded manifest temp file: $MANIFEST_TMP"
        fi

        return 0
    }

    # _manifest_resolve_for_undeploy
        # Purpose:
        #   Resolve which manifest should be used for undeploy.
        #
        # Behavior:
        #   - Uses MANIFEST_NAME when explicitly provided
        #   - Otherwise selects the latest manifest for the current SRC_ROOT
        #   - Populates MANIFEST_SOURCE_ID, MANIFEST_SOURCE_DIR, and MANIFEST_PATH
        #
        # Selection rules:
        #   - Explicit:  <source-dir>/<MANIFEST_NAME>.manifest
        #   - Implicit:  lexically latest *.manifest in the source-root manifest folder
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   MANIFEST_BASE_DIR
        #   MANIFEST_NAME
        #
        # Outputs (globals):
        #   MANIFEST_SOURCE_ID
        #   MANIFEST_SOURCE_DIR
        #   MANIFEST_PATH
        #
        # Returns:
        #   0 on success
        #   1 if no suitable manifest is found
        #
        # Usage:
        #   _manifest_resolve_for_undeploy || return $?
        #
        # Notes:
        #   - Assumes manifest names are time-sortable when auto-generated
    _manifest_resolve_for_undeploy() {
        local latest

        MANIFEST_SOURCE_ID="$(_manifest_source_id)"
        MANIFEST_SOURCE_DIR="$(_manifest_source_dir)"

        [[ -d "$MANIFEST_SOURCE_DIR" ]] || {
            sayfail "No manifest directory found for source root: $SRC_ROOT"
            return 1
        }

        if [[ -n "${MANIFEST_NAME:-}" ]]; then
            MANIFEST_PATH="${MANIFEST_SOURCE_DIR}/${MANIFEST_NAME}.manifest"
            [[ -r "$MANIFEST_PATH" ]] || {
                sayfail "Manifest not found: $MANIFEST_PATH"
                return 1
            }
            saydebug "Resolved explicit manifest: $MANIFEST_PATH"
            return 0
        fi

        latest="$(
            find "$MANIFEST_SOURCE_DIR" -maxdepth 1 -type f -name '*.manifest' -printf '%f\n' 2>/dev/null |
            sort |
            tail -n 1
        )"

        [[ -n "$latest" ]] || {
            sayfail "No manifests found for source root: $SRC_ROOT"
            return 1
        }

        MANIFEST_PATH="${MANIFEST_SOURCE_DIR}/${latest}"
        saydebug "Resolved latest manifest: $MANIFEST_PATH"
        return 0
    }

    # _manifest_list
        # Purpose:
        #   List available manifests for the current source root.
        #
        # Behavior:
        #   - Prints manifest filenames for the current SRC_ROOT namespace
        #   - Sorted lexically
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   MANIFEST_BASE_DIR
        #
        # Returns:
        #   0 on success
        #   1 if manifest directory does not exist
        #
        # Usage:
        #   _manifest_list
    _manifest_list() {
        local dir
        dir="$(_manifest_source_dir)"

        [[ -d "$dir" ]] || {
            sayfail "No manifest directory found for source root: $SRC_ROOT"
            return 1
        }

        find "$dir" -maxdepth 1 -type f -name '*.manifest' -printf '%f\n' | sort
        return 0
    }

    # _manifest_verify_target
        # Purpose:
        #   Verify that the resolved manifest belongs to the current DEST_ROOT.
        #
        # Behavior:
        #   - Reads the target= header from the resolved manifest
        #   - Compares it to the current DEST_ROOT
        #   - Fails when the two targets do not match
        #
        # Inputs (globals):
        #   MANIFEST_PATH
        #   DEST_ROOT
        #
        # Returns:
        #   0 when target matches
        #   1 when target differs or cannot be read
        #
        # Usage:
        #   _manifest_verify_target || return $?
        #
        # Notes:
        #   - Prevents undeploy from applying a manifest to the wrong target root
    _manifest_verify_target() {
        local manifest_target=""
        manifest_target="$(
            awk -F= '/^target=/{print substr($0,8); exit}' "$MANIFEST_PATH"
        )"

        [[ -n "$manifest_target" ]] || {
            sayfail "Cannot read target from manifest: $MANIFEST_PATH"
            return 1
        }

        if [[ "${DEST_ROOT:-/}" != "$manifest_target" ]]; then
            sayfail "Manifest target mismatch: manifest=$manifest_target current=${DEST_ROOT:-/}"
            return 1
        fi

        return 0
    }

 # -- Main sequence  
    # _perm_resolve
        # Purpose:
        #   Resolve the effective permission mode for a given path based on PERMISSION_RULES.
        #
        # Arguments:
        #   $1  abs_rel   Absolute path relative to root (e.g. "/usr/local/bin/foo")
        #   $2  kind      "file" or "dir"
        #
        # Behavior:
        #   - Applies longest-prefix match against PERMISSION_RULES
        #   - Returns file_mode or dir_mode depending on kind
        #   - Falls back to defaults when no rule matches
        #
        # Output:
        #   Prints the resolved mode to stdout (no newline)
        #
        # Returns:
        #   0 always
        #
        # Defaults:
        #   file → 644
        #   dir  → 755
        #
        # Usage:
        #   mode="$(_perm_resolve "/usr/local/bin/foo" "file")"
        #
        # Examples:
        #   dir_mode="$(_perm_resolve "/usr/local/bin" "dir")"
    _perm_resolve() {
        local abs_rel="$1"   # e.g. "/usr/local/sbin/td-foo"
        local kind="$2"      # "file" or "dir"

        local best_prefix=""
        local best_file="644"
        local best_dir="755"

        local entry prefix file_mode dir_mode desc

        for entry in "${PERMISSION_RULES[@]}"; do
            IFS='|' read -r prefix file_mode dir_mode desc <<< "$entry"

            if [[ "$abs_rel" == "$prefix" || "$abs_rel" == "$prefix/"* ]]; then
                if [[ ${#prefix} -gt ${#best_prefix} ]]; then
                    best_prefix="$prefix"
                    best_file="$file_mode"
                    best_dir="$dir_mode"
                fi
            fi
        done

        if [[ "$kind" == "dir" ]]; then
            echo "$best_dir"
        else
            echo "$best_file"
        fi
    }

    # _update_lastdeployinfo
        # Purpose:
        #   Persist metadata of the last deployment run for reuse (e.g. auto mode).
        #
        # Behavior:
        #   - Stores timestamp, source, and target in state for later reuse
        #   - Skips writes when FLAG_DRYRUN is enabled
        #
        # Writes:
        #   last_deploy_run
        #   last_deploy_source
        #   last_deploy_target
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   DEST_ROOT
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0 on success
        #
        # Usage:
        #   _update_lastdeployinfo
    _update_lastdeployinfo() {
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have saved lastdeployinfo"
        else
            saydebug "Saving last deploymentinfo"
            sgnd_state_set "last_deploy_run" "$(date --iso-8601=seconds)"
            sgnd_state_set "last_deploy_source" "$SRC_ROOT"
            sgnd_state_set "last_deploy_target" "${DEST_ROOT:-/}"
        fi
    }

    # _getparameters
        # Purpose:
        #   Collect deployment parameters (source and target roots).
        #
        # Behavior:
        #   - Auto mode:
        #       Uses last deployment settings when available
        #   - Interactive mode:
        #       Prompts for SRC_ROOT and DEST_ROOT
        #       Validates SRC_ROOT structure (advisory only)
        #       Asks for confirmation (OK/Redo/Quit)
        #
        # Validation:
        #   - SRC_ROOT is considered valid if it contains "etc/" or "usr/"
        #   - Validation is advisory only (does not block execution)
        #
        # Outputs (globals):
        #   SRC_ROOT
        #   DEST_ROOT
        #
        # Returns:
        #   0 → confirmed
        #   1 → aborted
        #
        # Usage:
        #   _getparameters || return $?
        #
        # Notes:
        #   - Uses ask and ask_ok_redo_quit
    _getparameters() {
        local default_src default_dst
        default_src="${last_deploy_source:-$HOME/dev}"
        default_dst="${last_deploy_target:-/}"

        # --- Auto mode --------------------------------------------------------------
        if [[ "${FLAG_AUTO:-0}" -eq 1 ]]; then
            if [[ -n "${last_deploy_source:-}" && -n "${last_deploy_target:-}" ]]; then
                sayinfo "Auto mode: using last deployment settings."
                SRC_ROOT="$last_deploy_source"
                DEST_ROOT="$last_deploy_target"
                sgnd_print_titlebar
                return 0
            fi
            saywarning "Auto mode requested, but no previous deployment settings found."
        fi

        # --- Interactive mode -------------------------------------------------------
        while true; do
            # --- Source root --------------------------------------------------------
            if [[ -z "${SRC_ROOT:-}" ]]; then
                ask --label "Workspace source root" \
                    --var SRC_ROOT \
                    --default "$default_src" \
                    --colorize both
            fi

            # Advisory validation
            if [[ -d "$SRC_ROOT/etc" || -d "$SRC_ROOT/usr" ]]; then
                sayinfo "Source root '$SRC_ROOT' looks valid."
            else
                saywarning "Source root '$SRC_ROOT' doesn't look valid; should contain 'etc/' and/or 'usr/'."
            fi

            # --- Target root --------------------------------------------------------
            if [[ -z "${DEST_ROOT:-}" ]]; then
                ask --label "Target root folder" \
                    --var DEST_ROOT \
                    --default "$default_dst" \
                    --colorize both
            fi
            DEST_ROOT="${DEST_ROOT:-/}"

            ask_dlg_autocontinue \
                --seconds 15 \
                --message "Continue with these settings?" \
                --redo \
                --cancel

            case $? in
                0|1) break ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                3) sayinfo "Redoing input"; continue ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac
        done

        sgnd_print_titlebar
        return 0
    }

    # _deploy
        # Purpose:
        #   Deploy workspace files from SRC_ROOT into DEST_ROOT.
        #
        # Behavior:
        #   - Recursively processes files under SRC_ROOT
        #   - Computes relative path and destination path
        #   - Skips:
        #       - top-level files
        #       - "_" prefixed files
        #       - ".old" files
        #       - hidden or "_" directories
        #
        # Update logic:
        #   - Installs when destination is missing or source is newer
        #
        # Manifest behavior:
        #   - Initializes a new manifest at start of deployment
        #   - Records only files CREATED by this run
        #   - Records only directories CREATED by this run
        #   - Updated pre-existing files are not recorded
        #   - Finalizes manifest only after successful completion
        #
        # Permissions:
        #   - File mode via _perm_resolve(abs_rel,"file")
        #   - Directory mode via _perm_resolve(abs_rel,"dir")
        #
        # Dry run:
        #   - When FLAG_DRYRUN=1, only reports actions
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   DEST_ROOT
        #   FLAG_DRYRUN
        #   PERMISSION_RULES
        #
        # Returns:
        #   0 on success
        #   1 on fatal deployment/manifest failure
        #
        # Usage:
        #   _deploy
        #
        # Notes:
        #   - Uses install for atomic writes and permission control
        #   - Manifest records created artifacts only; it is not full rollback state
    _deploy() {
        SRC_ROOT="${SRC_ROOT%/}"
        DEST_ROOT="${DEST_ROOT%/}"

        local file rel name abs_rel perms dst dst_dir dir_mode
        local dst_existed probe dir_abs_rel
        local -a missing_dirs=()
        local i

        saystart "Starting deployment from $SRC_ROOT to ${DEST_ROOT:-/}"

        _manifest_init || return $?

        while IFS= read -r file; do
            rel="${file#"$SRC_ROOT"/}"

            if [[ "$rel" == "$file" || "$rel" == /* ]]; then
                sayfail "Bad rel path: file='$file' SRC_ROOT='$SRC_ROOT' rel='$rel'"
                _manifest_discard
                return 1
            fi

            name="$(basename "$file")"
            abs_rel="/$rel"
            dst="${DEST_ROOT:-}/$rel"

            # Skip top-level files, hidden dirs, private dirs
            if [[ "$rel" != */* || "$name" == _* || "$name" == *.old || \
                "$rel" == .*/* || "$rel" == _*/* || \
                "$rel" == */.*/* || "$rel" == */_*/* ]]; then
                continue
            fi

            if [[ ! -e "$dst" || "$file" -nt "$dst" ]]; then
                perms="$(_perm_resolve "$abs_rel" "file")"
                dst_dir="$(dirname "$dst")"

                if [[ "${FLAG_DRYRUN:-0}" -eq 0 ]]; then
                    missing_dirs=()
                    probe="$dst_dir"

                    while [[ "$probe" != "${DEST_ROOT:-}" && "$probe" != "/" && ! -d "$probe" ]]; do
                        missing_dirs+=("$probe")
                        probe="$(dirname "$probe")"
                    done

                    for (( i=${#missing_dirs[@]}-1; i>=0; i-- )); do
                        dir_abs_rel="${missing_dirs[$i]#"${DEST_ROOT:-}"}"
                        dir_abs_rel="${dir_abs_rel:-/}"
                        dir_mode="$(_perm_resolve "$dir_abs_rel" "dir")"

                        install -d -m "$dir_mode" "${missing_dirs[$i]}" || {
                            sayfail "Failed to create directory: ${missing_dirs[$i]}"
                            _manifest_discard
                            return 1
                        }

                        _manifest_add_dir "$dir_abs_rel" || {
                            _manifest_discard
                            return 1
                        }
                    done

                    dst_existed=0
                    [[ -e "$dst" ]] && dst_existed=1

                    sayinfo "Installing $file --> $dst, with $perms permissions"
                    install -m "$perms" "$file" "$dst" || {
                        sayfail "Failed to install file: $file -> $dst"
                        _manifest_discard
                        return 1
                    }

                    if [[ "$dst_existed" -eq 0 ]]; then
                        _manifest_add_file "$abs_rel" || {
                            _manifest_discard
                            return 1
                        }
                    fi
                else
                    sayinfo "Would have installed $file --> $dst, with $perms permissions"
                fi
            else
                saydebug "Skipping $rel; destination is up-to-date."
            fi
        done < <(find "$SRC_ROOT" -type f)

        _manifest_commit || return $?

        sayend "End deployment complete."
        return 0
    }

    # _undeploy
        # Purpose:
        #   Remove previously deployed files and directories using a manifest.
        #
        # Behavior:
        #   - Resolves a manifest for the current SRC_ROOT
        #   - Uses MANIFEST_NAME when provided
        #   - Otherwise uses the latest manifest for the source root
        #   - Removes recorded files first
        #   - Removes recorded directories afterward in reverse-depth order
        #
        # Manifest rules:
        #   - Only files recorded as created by deploy are removed
        #   - Only directories recorded as created by deploy are considered
        #   - Directories are removed only if empty
        #
        # Dry run:
        #   - When FLAG_DRYRUN=1, only reports actions
        #
        # Inputs (globals):
        #   SRC_ROOT
        #   DEST_ROOT
        #   MANIFEST_NAME
        #   FLAG_DRYRUN
        #
        # Returns:
        #   0 on success
        #   1 if manifest resolution fails
        #
        # Usage:
        #   _undeploy
        #
        # Notes:
        #   - This is a manifest-based inverse of created artifacts only
        #   - Updated pre-existing files are not restored or removed
    _undeploy() {
        local kind path dst

        _manifest_resolve_for_undeploy || return $?
        _manifest_verify_target || return $?

        saystart "Starting UNINSTALL using manifest $MANIFEST_PATH"

        # Remove files first
        while IFS='|' read -r kind path; do
            [[ -z "$kind" || -z "$path" ]] && continue
            [[ "$kind" != "F" ]] && continue

            dst="${DEST_ROOT%/}$path"

            if [[ -e "$dst" ]]; then
                if [[ "${FLAG_DRYRUN:-0}" -eq 0 ]]; then
                    saywarning "Removing $dst"
                    rm -f -- "$dst"
                else
                    sayinfo "Would have removed $dst"
                fi
            else
                saydebug "Skipping missing file: $dst"
            fi
        done < <(grep '^F|' "$MANIFEST_PATH")

        # Remove directories deepest first
        grep '^D|' "$MANIFEST_PATH" |
        sed 's/^D|//' |
        awk '{ print length, $0 }' |
        sort -rn |
        cut -d' ' -f2- |
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            dst="${DEST_ROOT%/}$path"

            if [[ -d "$dst" ]]; then
                if [[ "${FLAG_DRYRUN:-0}" -eq 0 ]]; then
                    saywarning "Removing directory if empty: $dst"
                    rmdir --ignore-fail-on-non-empty -- "$dst" 2>/dev/null || true
                else
                    sayinfo "Would have removed directory if empty: $dst"
                fi
            else
                saydebug "Skipping missing directory: $dst"
            fi
        done

        sayend "End undeploy complete."
        return 0
    }

# --- Main ----------------------------------------------------------------------------
    # main
        # Purpose:
        #   Execute the workspace deployment workflow.
        #
        # Behavior:
        #   - Loads and initializes the framework bootstrap
        #   - Handles builtin arguments
        #   - Displays title bar
        #   - Collects parameters
        #   - Executes deploy or undeploy
        #   - Persists deployment metadata
        #
        # Arguments:
        #   $@  Framework and script-specific arguments
        #
        # Returns:
        #   Exit status from executed operations
        #
        # Usage:
        #   main "$@"
    main() {
        # -- Bootstrap
            local rc=0

            _load_bootstrapper || exit $?            

            # Recognized switches:
            #     --state      -> enable saving state variables 
            #     --autostate  -> enable state support and auto-save SGND_STATE_VARIABLES on exit
            #     --needroot   -> restart script if not root
            #     --cannotroot -> exit script if root
            #     --log        -> enable file logging
            #     --console    -> enable console logging
            # Example:
            #   sgnd_bootstrap --state --needroot -- "$@"
            sgnd_bootstrap -- "$@"
            rc=$?

            saydebug "After bootstrap: $rc"
            (( rc != 0 )) && exit "$rc"
                        
        # -- Handle builtin arguments
            saydebug "Calling builtinarg handler"
            sgnd_builtinarg_handler
            saydebug "Exited builtinarg handler"

        # -- UI
            sgnd_update_runmode
            sgnd_print_titlebar

        # -- Main script logic
            _getparameters || return $?

            # -- Deploy or undeploy                    
            if [[ "${FLAG_UNDEPLOY:-0}" -eq 0 ]]; then
                _deploy || return $?
                _update_lastdeployinfo
            else
                _undeploy
            fi
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
