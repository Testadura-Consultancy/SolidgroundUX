#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Release Manager
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : 5d274fce24ffe3f41cd15e2ab08b26a7f47f68e2d2265cb8d11134721ab6d4f3
#   Source      : release-manager.sh
#   Type        : script
#   Group       : Deployment
#   Purpose     : Standalone SolidGroundUX release acquisition, installation, rollback, and removal.
#
# Description:
#   Provides a framework-independent release manager for SolidGroundUX.
#
#   The script:
#     - Discovers pending releases under /var/lib/solidgroundux/releases
#     - Treats versioned directories under /var/lib/solidgroundux/archive as install history
#     - Installs a first release by verifying and extracting its complete tar archive
#     - Updates an existing installation and applies the incoming .removed manifest
#     - Rolls back by making the installed filesystem match a selected archived release
#     - Removes SolidGroundUX while preserving release packages for later reinstall
#     - Queries GitHub for the latest published release and downloads it only when needed
#     - Bootstraps a clean machine from release-manager.sh plus an adjacent release bundle
#     - Installs a canonical manager copy under /var/lib/solidgroundux for future recovery
#     - Uses a small self-contained UI without depending on the SolidGroundUX framework
#
# Design principles:
#   - Standalone operation even when SolidGroundUX is absent or damaged
#   - Filesystem-as-state: releases = available, archive = installed/history
#   - Complete release archives; no incremental binary patching
#   - Conservative removal: files/symlinks are removed, directories only when empty
#   - Transactional acquisition through a temporary directory before release admission
#   - Bootstrap cleanup is limited to known release-manager bundle files under /tmp
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

set -uo pipefail

# --- Defaults -----------------------------------------------------------------------
    SGND_RELEASE_PRODUCT="SolidGroundUX"
    SGND_RELEASE_GITHUB_REPO="Testadura-Mark/SolidGroundUX"

    FLAG_AUTO=0
    FLAG_DRYRUN=0
    FLAG_VERBOSE=0

    ACTION=""
    VAL_RELEASE=""
    VAL_SOURCE=""
    VAL_TARGET_ROOT="/"
    VAL_STATE_ROOT=""
    VAL_RELEASES_DIR=""
    VAL_ARCHIVE_ROOT=""
    VAL_GITHUB_REPO="$SGND_RELEASE_GITHUB_REPO"

    SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_FILE")" && pwd)"
    SCRIPT_BASE="$(basename -- "$SCRIPT_FILE")"
    SCRIPT_NAME="${SCRIPT_BASE%.sh}"
    CANONICAL_MANAGER_PATH=""

    BOOTSTRAP_RELEASE_BASE=""
    BOOTSTRAP_SOURCE_DIR=""

# --- Standalone UI ------------------------------------------------------------------
    # Default-theme-compatible standalone palette.
    # Kept local so the release manager remains framework-independent.
    _RL_RESET=$'\033[0m'
    _RL_BOLD=$'\033[1m'
    _RL_FAINT=$'\033[2m'
    _RL_ITALIC=$'\033[3m'

    _RL_SILVER=$'\033[38;5;250m'
    _RL_YELLOW=$'\033[38;5;226m'
    _RL_BRIGHT_CYAN=$'\033[96m'
    _RL_BRIGHT_GREEN=$'\033[92m'
    _RL_BRIGHT_ORANGE=$'\033[38;5;208m'
    _RL_BRIGHT_RED=$'\033[91m'
    _RL_DARK_WHITE=$'\e[38;5;250m'  
    _RL_WHITE=$'\e[0;37m'
    _RL_BRIGHT_WHITE=$'\e[38;5;15m'

    _RL_UI_LABEL="$_RL_SILVER"
    _RL_UI_VALUE="$_RL_YELLOW"
    _RL_UI_TEXT="$_RL_SILVER"
    _RL_UI_INPUT="$_RL_YELLOW"
    _RL_UI_PROMPT="$_RL_BRIGHT_CYAN"

    _RL_MSG_INFO="$_RL_SILVER"
    _RL_MSG_START="$_RL_BRIGHT_GREEN"
    _RL_MSG_OK="$_RL_BRIGHT_GREEN"
    _RL_MSG_WARN="$_RL_BRIGHT_ORANGE"
    _RL_MSG_FAIL="$_RL_BRIGHT_RED"
    _RL_MSG_CANCEL="$_RL_YELLOW"
    _RL_MSG_END="$_RL_BRIGHT_GREEN"

    if [[ ! -t 1 || "${TERM:-}" == "dumb" ]]; then
        _RL_RESET=""
        _RL_BOLD=""
        _RL_FAINT=""
        _RL_ITALIC=""
        _RL_SILVER=""
        _RL_YELLOW=""
        _RL_BRIGHT_CYAN=""
        _RL_BRIGHT_GREEN=""
        _RL_BRIGHT_ORANGE=""
        _RL_BRIGHT_RED=""
        _RL_UI_LABEL=""
        _RL_UI_VALUE=""
        _RL_UI_TEXT=""
        _RL_UI_INPUT=""
        _RL_UI_PROMPT=""
        _RL_MSG_INFO=""
        _RL_MSG_START=""
        _RL_MSG_OK=""
        _RL_MSG_WARN=""
        _RL_MSG_FAIL=""
        _RL_MSG_CANCEL=""
        _RL_MSG_END=""
    fi

    # fn: _release_terminal_width - Return the usable terminal width
        # Returns:
        #   Prints a terminal width between 40 and 140 columns.
        # Usage:
        #   width="$(_release_terminal_width)"
    _release_terminal_width() {
        local width=80

        if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
            width="$(tput cols 2>/dev/null || printf '80')"
        fi

        [[ "$width" =~ ^[0-9]+$ ]] || width=80
        (( width < 40 )) && width=40
        (( width > 140 )) && width=140
        printf '%s\n' "$width"
    }

    # fn: _release_clear - Clear the active terminal reliably
        # Returns:
        #   0 always.
        # Usage:
        #   _release_clear
    _release_clear() {
        [[ -t 1 ]] || return 0
        printf '\033[2J\033[H'
    }

    # fn: _release_line - Print a repeated border character
        # Returns:
        #   0 always.
        # Usage:
        #   _release_line "═"
    _release_line() {
        local char="${1:-─}"
        local width=80
        local line=""

        width="$(_release_terminal_width)"
        printf -v line '%*s' "$width" ''
        line="${line// /$char}"

        printf '%s%s%s\n' "$_RL_BRIGHT_CYAN" "$line" "$_RL_RESET"
    }

    # fn: _release_metadata_field - Read a field from this script's Metadata header
        # . Purpose
        #   Read one value from the canonical script Metadata block without depending on
        #   SolidGroundUX framework libraries.
        # . Arguments
        #   $1  Metadata field name, for example Version or Build.
        # . Returns
        #   0 and the trimmed field value when found; 1 otherwise.
        # . Usage
        #   version="$(_release_metadata_field "Version")"
    _release_metadata_field() {
        local field="${1:-}"
        local value=""

        [[ -n "$field" ]] || return 1

        value="$(
            sed -n -E \
                "s/^#[[:space:]]*${field}[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$/\1/p" \
                "$SCRIPT_FILE" \
                | head -n 1
        )"

        [[ -n "$value" ]] || return 1
        printf '%s\n' "$value"
    }

    # fn: _release_title - Render the standalone release-manager title
        # . Purpose
        #   Display the release-manager identity and current hostname without using framework UI libraries.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_title
    _release_title() {
        local width=80
        local manager_version=""
        local manager_build=""
        local title="SolidGroundUX Release Manager"
        local desc="Standalone installation, update, rollback and removal"
        local host=""
        local pad=4
        local right_pad=4
        local gap=2
        local available=0

        manager_version="$(_release_metadata_field "Version" 2>/dev/null || true)"
        manager_build="$(_release_metadata_field "Build" 2>/dev/null || true)"

        if [[ -n "$manager_version" && -n "$manager_build" ]]; then
            title+=" (v. ${manager_version}.${manager_build})"
        elif [[ -n "$manager_version" ]]; then
            title+=" (v. ${manager_version})"
        fi

        width="$(_release_terminal_width)"
        host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
        
        printf '\n'
        _release_line "═"
        
        available=$(( width - pad - right_pad - ${#title} - gap ))
        if (( available > ${#host} )); then
            printf '%*s%s%s%s%s%*s%s%s%s%s\n' \
                "$pad" '' "$_RL_BRIGHT_WHITE" "$_RL_BOLD" "$title" "$_RL_RESET" \
                "$(( available - ${#host} ))" '' \
                "$_RL_UI_VALUE" "$_RL_ITALIC" "$host" "$_RL_RESET"
        else
            printf '%*s%s%s%s%s\n' "$pad" '' "$_RL_BRIGHT_WHITE" "$_RL_BOLD" "$title" "$_RL_RESET"
        fi

        printf '%*s%s%s%s%s\n' "$pad" '' "$_RL_UI_TEXT" "$_RL_ITALIC" "$desc" "$_RL_RESET"
        _release_line "═"
    }

    # fn: _release_labeled_value - Print one aligned label/value pair
        # Returns:
        #   0 always.
        # Usage:
        #   _release_labeled_value "Installed version" "$current"
    _release_labeled_value() {
        local label="${1:-}"
        local value="${2:-}"
        local width="${3:-24}"
        printf '    %s%-*s%s : %s%s%s\n' \
            "$_RL_UI_PROMPT" "$width" "$label" "$_RL_RESET" \
            "$_RL_UI_VALUE" "$value" "$_RL_RESET"
    }

    # fn: _release_info - Write verbose informational output
        # . Purpose
        #   Write verbose informational output.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_info "message"
    _release_info() {
        (( FLAG_VERBOSE )) || return 0
        printf '%sINFO%s  %s\n' "$_RL_MSG_INFO" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_ok - Write a successful-operation message
        # . Purpose
        #   Write a successful-operation message.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_ok "message"
    _release_ok() {
        printf '%sOK%s    %s\n' "$_RL_MSG_OK" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_warn - Write a warning message
        # . Purpose
        #   Write a warning message.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_warn "message"
    _release_warn() {
        printf '%sWARN%s  %s\n' "$_RL_MSG_WARN" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_fail - Write a failure message
        # . Purpose
        #   Write a failure message.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_fail "message"
    _release_fail() {
        printf '%sFAIL%s  %s\n' "$_RL_MSG_FAIL" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_run - Execute a command or report it in dry-run mode
        # . Purpose
        #   Execute a command or report it in dry-run mode.
        # . Returns
        #   The executed command status, or 0 in dry-run mode.
        # . Usage
        #   _release_run mkdir -p /tmp/example
    _release_run() {
        if (( FLAG_DRYRUN )); then
            printf '[DRYRUN]'
            printf ' %q' "$@"
            printf '\n'
            return 0
        fi
        "$@"
    }

# --- Arguments and paths ------------------------------------------------------------
    # fn: print_usage - Display standalone release-manager command-line help
        # . Purpose
        #   Display standalone release-manager command-line help.
        # . Returns
        #   0 always.
        # . Usage
        #   print_usage
    print_usage() {
        printf '%s\n' \
            'Usage:' \
            "  $SCRIPT_NAME [action] [options]" \
            '' \
            'Actions:' \
            '  --check                Ask GitHub for the latest release and report status' \
            '  --download             Download the latest GitHub release when not already local/installed' \
            '  --update               Check, download if required, and install the latest GitHub release' \
            '  --install              Install the newest pending local release' \
            '  --rollback             Install the previous archived release, or --release NAME' \
            '  --remove               Remove the active SolidGroundUX installation' \
            '' \
            'Options:' \
            '  --release NAME         Operate on a specific release base or version' \
            '  --auto                 Do not ask for confirmations or selections' \
            '  --repo OWNER/REPO      GitHub repository used for latest-release discovery' \
            '  --source URL|FILE      Direct release ZIP source instead of GitHub asset discovery' \
            '  --target-root PATH     Installation root (default: /)' \
            '  --state-root PATH      Release-manager state root' \
            '  --releases-dir PATH    Pending/downloaded releases directory' \
            '  --archive-root PATH    Installed release history directory' \
            '  --dryrun               Show filesystem actions without changing anything' \
            '  --verbose              Show informational diagnostics' \
            '  --help                 Show this help' \
            '' \
            'Filesystem state:' \
            '  releases/              Downloaded or rolled-back release sets available for install' \
            '  archive/<release>/     Installed release history; highest version is current'
    }

    # fn: _set_action - Set and validate the requested release-manager action
        # . Purpose
        #   Set and validate the requested release-manager action.
        # . Returns
        #   0 on success; 1 when conflicting actions are supplied.
        # . Usage
        #   _set_action update
    _set_action() {
        local requested="${1:?missing action}"
        if [[ -n "$ACTION" && "$ACTION" != "$requested" ]]; then
            _release_fail "Choose only one action: $ACTION or $requested"
            return 1
        fi
        ACTION="$requested"
    }

    # fn: parse_args - Parse release-manager command-line arguments
        # . Purpose
        #   Parse release-manager command-line arguments.
        # . Returns
        #   0 on success; non-zero on invalid arguments.
        # . Usage
        #   parse_args "$@"
    parse_args() {
        while (( $# > 0 )); do
            case "$1" in
                --check) _set_action check || return 1 ;;
                --download) _set_action download || return 1 ;;
                --update) _set_action update || return 1 ;;
                --install) _set_action install || return 1 ;;
                --rollback) _set_action rollback || return 1 ;;
                --remove) _set_action remove || return 1 ;;
                --release)
                    shift
                    VAL_RELEASE="${1:-}"
                    [[ -n "$VAL_RELEASE" ]] || { _release_fail "--release requires a value"; return 1; }
                    ;;
                --auto) FLAG_AUTO=1 ;;
                --repo)
                    shift
                    VAL_GITHUB_REPO="${1:-}"
                    [[ -n "$VAL_GITHUB_REPO" ]] || { _release_fail "--repo requires a value"; return 1; }
                    ;;
                --source)
                    shift
                    VAL_SOURCE="${1:-}"
                    [[ -n "$VAL_SOURCE" ]] || { _release_fail "--source requires a value"; return 1; }
                    ;;
                --target-root)
                    shift
                    VAL_TARGET_ROOT="${1:-}"
                    [[ -n "$VAL_TARGET_ROOT" ]] || { _release_fail "--target-root requires a value"; return 1; }
                    ;;
                --state-root)
                    shift
                    VAL_STATE_ROOT="${1:-}"
                    [[ -n "$VAL_STATE_ROOT" ]] || { _release_fail "--state-root requires a value"; return 1; }
                    ;;
                --releases-dir)
                    shift
                    VAL_RELEASES_DIR="${1:-}"
                    [[ -n "$VAL_RELEASES_DIR" ]] || { _release_fail "--releases-dir requires a value"; return 1; }
                    ;;
                --archive-root)
                    shift
                    VAL_ARCHIVE_ROOT="${1:-}"
                    [[ -n "$VAL_ARCHIVE_ROOT" ]] || { _release_fail "--archive-root requires a value"; return 1; }
                    ;;
                --dryrun) FLAG_DRYRUN=1 ;;
                --verbose) FLAG_VERBOSE=1 ;;
                --help|-h) print_usage; exit 0 ;;
                *) _release_fail "Unknown argument: $1"; return 1 ;;
            esac
            shift
        done
    }

    # fn: _normalize_root - Normalize an absolute filesystem root
        # . Purpose
        #   Normalize an absolute filesystem root.
        # . Returns
        #   0 when the root is absolute; 1 otherwise.
        # . Usage
        #   root="$(_normalize_root "/")"
    _normalize_root() {
        local root="${1:-/}"
        [[ "$root" == /* ]] || return 1
        root="${root%/}"
        [[ -n "$root" ]] || root="/"
        printf '%s\n' "$root"
    }

    # fn: init_paths - Resolve target, state, release, and archive directories
        # . Purpose
        #   Resolve target, state, release, and archive directories.
        # . Returns
        #   0 on success; 1 when the target root is invalid.
        # . Usage
        #   init_paths
    init_paths() {
        VAL_TARGET_ROOT="$(_normalize_root "$VAL_TARGET_ROOT")" || {
            _release_fail "Target root must be absolute: $VAL_TARGET_ROOT"
            return 1
        }

        if [[ -z "$VAL_STATE_ROOT" ]]; then
            if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
                VAL_STATE_ROOT="/var/lib/solidgroundux"
            else
                VAL_STATE_ROOT="${VAL_TARGET_ROOT%/}/var/lib/solidgroundux"
            fi
        fi

        : "${VAL_RELEASES_DIR:=${VAL_STATE_ROOT%/}/releases}"
        : "${VAL_ARCHIVE_ROOT:=${VAL_STATE_ROOT%/}/archive}"
        CANONICAL_MANAGER_PATH="${VAL_STATE_ROOT%/}/release-manager.sh"
    }

    # fn: _require_command - Verify that a required system command is available
        # . Purpose
        #   Verify that a required system command is available.
        # . Returns
        #   0 when available; 1 otherwise.
        # . Usage
        #   _require_command tar
    _require_command() {
        local command_name="${1:?missing command}"
        command -v "$command_name" >/dev/null 2>&1 || {
            _release_fail "Required command not found: $command_name"
            return 1
        }
    }

# --- Bootstrap housekeeping ----------------------------------------------------------
    # fn: _ensure_manager_directories - Ensure standalone release-manager directories exist
        # . Purpose
        #   Create the state, pending-release, and archive directories required by the
        #   standalone release manager.
        # . Returns
        #   0 on success; non-zero when a required directory cannot be created.
        # . Usage
        #   _ensure_manager_directories
    _ensure_manager_directories() {
        _release_run mkdir -p -- "$VAL_STATE_ROOT" "$VAL_RELEASES_DIR" "$VAL_ARCHIVE_ROOT"
    }

    # fn: _install_release_manager - Install the standalone manager at its canonical path
        # . Purpose
        #   Copy the currently running release manager to the machine-local state root so
        #   future update, rollback, repair, and removal operations do not depend on a
        #   temporary bootstrap copy.
        # . Returns
        #   0 on success; non-zero when the manager cannot be copied or made executable.
        # . Usage
        #   _install_release_manager
    _install_release_manager() {
        [[ -n "$CANONICAL_MANAGER_PATH" ]] || return 1

        if [[ "$SCRIPT_FILE" == "$CANONICAL_MANAGER_PATH" ]]; then
            return 0
        fi

        _release_run cp -f -- "$SCRIPT_FILE" "$CANONICAL_MANAGER_PATH" || return 1
        _release_run chmod 0755 -- "$CANONICAL_MANAGER_PATH" || return 1
        _release_info "Installed release manager: $CANONICAL_MANAGER_PATH"
    }

    # fn: _detect_bootstrap_release - Detect one complete release set beside the running script
        # . Purpose
        #   Detect the release payload supplied in a first-install bootstrap bundle without
        #   depending on the current working directory.
        # . Outputs
        #   BOOTSTRAP_RELEASE_BASE
        #   BOOTSTRAP_SOURCE_DIR
        # . Returns
        #   0 when exactly one adjacent release archive is found; 1 when none is present;
        #   2 when multiple release archives make the bundle ambiguous.
        # . Usage
        #   _detect_bootstrap_release
    _detect_bootstrap_release() {
        local archive=""
        local -a candidates=()

        BOOTSTRAP_RELEASE_BASE=""
        BOOTSTRAP_SOURCE_DIR=""

        mapfile -t candidates < <(
            find "$SCRIPT_DIR" -maxdepth 1 -type f -name "${SGND_RELEASE_PRODUCT}-*.tar.gz" -print 2>/dev/null
        )

        (( ${#candidates[@]} > 0 )) || return 1
        if (( ${#candidates[@]} != 1 )); then
            _release_fail "Bootstrap directory must contain exactly one SolidGroundUX tar.gz archive"
            return 2
        fi

        archive="${candidates[0]}"
        BOOTSTRAP_RELEASE_BASE="$(_release_base_from_archive "$archive")" || return 2
        BOOTSTRAP_SOURCE_DIR="$SCRIPT_DIR"
        return 0
    }

    # fn: _admit_bootstrap_release - Validate and move an adjacent bootstrap release into releases/
        # . Purpose
        #   Validate the release set shipped beside release-manager.sh and move its known
        #   artifacts into the canonical pending-release directory.
        # . Returns
        #   0 when no bootstrap release is present or admission succeeds; non-zero on
        #   ambiguity, validation failure, or filesystem failure.
        # . Usage
        #   _admit_bootstrap_release
    _admit_bootstrap_release() {
        local detect_rc=0
        local archive=""
        local base=""
        local artifact=""
        local -a artifacts=()

        _detect_bootstrap_release || detect_rc=$?
        case "$detect_rc" in
            0) ;;
            1) return 0 ;;
            *) return "$detect_rc" ;;
        esac

        base="$BOOTSTRAP_RELEASE_BASE"

        if _release_is_local_or_installed "$base"; then
            _release_info "Bootstrap release is already local or installed: $base"
            return 0
        fi

        archive="${BOOTSTRAP_SOURCE_DIR%/}/${base}.tar.gz"
        _verify_release_set "$archive" || return 1

        artifacts=(
            "${base}.tar.gz"
            "${base}.tar.gz.sha256"
            "${base}.manifest"
            "${base}.manifest.sha256"
            "${base}.removed"
            "${base}.removed.sha256"
        )

        for artifact in "${artifacts[@]}"; do
            [[ -f "${BOOTSTRAP_SOURCE_DIR%/}/${artifact}" ]] || {
                _release_fail "Bootstrap bundle is missing: $artifact"
                return 1
            }
        done

        _release_run mkdir -p -- "$VAL_RELEASES_DIR" || return 1
        for artifact in "${artifacts[@]}"; do
            _release_run mv -f -- "${BOOTSTRAP_SOURCE_DIR%/}/${artifact}" "$VAL_RELEASES_DIR/" || return 1
        done

        if [[ -f "${BOOTSTRAP_SOURCE_DIR%/}/SHA256SUMS" ]]; then
            _release_run rm -f -- "${BOOTSTRAP_SOURCE_DIR%/}/SHA256SUMS" || return 1
        fi

        _release_ok "Bootstrap release admitted: $base"
        return 0
    }

    # fn: _cleanup_bootstrap_files - Remove known temporary bootstrap files after first install
        # . Purpose
        #   Clean only the known release-manager bootstrap files when the manager was run
        #   from /tmp, leaving unrelated temporary files untouched.
        # . Returns
        #   0 always unless removal of a known bootstrap file fails.
        # . Usage
        #   _cleanup_bootstrap_files
    _cleanup_bootstrap_files() {
        local base="${BOOTSTRAP_RELEASE_BASE:-}"
        local source_dir="${BOOTSTRAP_SOURCE_DIR:-$SCRIPT_DIR}"
        local artifact=""
        local -a artifacts=()

        case "$source_dir" in
            /tmp|/tmp/*) ;;
            *) return 0 ;;
        esac

        [[ "$SCRIPT_FILE" != "$CANONICAL_MANAGER_PATH" ]] || return 0

        if [[ -n "$base" ]]; then
            artifacts=(
                "${base}.tar.gz"
                "${base}.tar.gz.sha256"
                "${base}.manifest"
                "${base}.manifest.sha256"
                "${base}.removed"
                "${base}.removed.sha256"
                "SHA256SUMS"
            )

            for artifact in "${artifacts[@]}"; do
                [[ -e "${source_dir%/}/${artifact}" ]] || continue
                _release_run rm -f -- "${source_dir%/}/${artifact}" || return 1
            done
        fi

        # The running script may safely unlink its temporary pathname after the canonical
        # copy has been written; the current process continues from the already-open file.
        [[ -e "$SCRIPT_FILE" ]] && _release_run rm -f -- "$SCRIPT_FILE" || true

        if [[ "$source_dir" != "/tmp" ]]; then
            if (( FLAG_DRYRUN )); then
                printf '[DRYRUN] rmdir -- %q\n' "$source_dir"
            else
                rmdir -- "$source_dir" 2>/dev/null || true
            fi
        fi

        return 0
    }

    # fn: _bootstrap_first_install - Bootstrap and install an adjacent release on a clean machine
        # . Purpose
        #   Complete the zero-framework first-install path when release-manager.sh is
        #   executed from a GitHub bootstrap bundle: ensure directories, admit the bundled
        #   release, install it when no version is installed, persist the manager, and clean
        #   the temporary bundle.
        # . Returns
        #   0 when no first-install bootstrap is required or when it completes successfully;
        #   non-zero on admission, verification, installation, or persistence failure.
        # . Usage
        #   _bootstrap_first_install
    _bootstrap_first_install() {
        local current=""
        local archive=""
        local base=""

        current="$(_current_release 2>/dev/null || true)"
        [[ -z "$current" ]] || return 0

        [[ -n "${BOOTSTRAP_RELEASE_BASE:-}" ]] || return 0

        base="$BOOTSTRAP_RELEASE_BASE"
        archive="$(_newest_pending_archive "$base" 2>/dev/null || true)"
        [[ -n "$archive" ]] || {
            _release_fail "Bootstrap release was admitted but cannot be found in releases/: $base"
            return 1
        }

        _release_info "Performing first install from bootstrap bundle: $base"
        _install_pending_archive "$archive" || return 1
        _install_release_manager || return 1
        _cleanup_bootstrap_files || return 1
        return 0
    }

# --- Release identity and discovery -------------------------------------------------
    # fn: _release_base_from_archive - Derive a release base name from a tar.gz archive path
        # . Purpose
        #   Derive a release base name from a tar.gz archive path.
        # . Returns
        #   0 for a tar.gz archive; 1 otherwise.
        # . Usage
        #   base="$(_release_base_from_archive "$archive")"
    _release_base_from_archive() {
        local archive="${1:?missing archive}"
        local name="$(basename -- "$archive")"
        [[ "$name" == *.tar.gz ]] || return 1
        printf '%s\n' "${name%.tar.gz}"
    }

    # fn: _release_matches - Test whether a release base matches an optional selector
        # . Purpose
        #   Test whether a release base matches an optional selector.
        # . Returns
        #   0 when it matches; 1 otherwise.
        # . Usage
        #   _release_matches "$base" "$VAL_RELEASE"
    _release_matches() {
        local base="${1:?missing base}"
        local requested="${2:-}"
        [[ -z "$requested" ]] && return 0
        [[ "$base" == "$requested" ]] && return 0
        [[ "$base" == "${SGND_RELEASE_PRODUCT}-${requested}" ]] && return 0
        return 1
    }

    # fn: _release_sort - Sort release identifiers by version
        # . Purpose
        #   Sort release identifiers by version.
        # . Returns
        #   Status returned by sort.
        # . Usage
        #   printf "%s\n" "$release" | _release_sort
    _release_sort() {
        LC_ALL=C sort -V
    }

    # fn: _current_release - Return the highest archived release as the current version
        # . Purpose
        #   Return the highest archived release as the current version.
        # . Returns
        #   0 when an archived release exists; non-zero otherwise.
        # . Usage
        #   current="$(_current_release)"
    _current_release() {
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 1
        find "$VAL_ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -name "${SGND_RELEASE_PRODUCT}-*" -printf '%f\n' 2>/dev/null \
            | _release_sort \
            | tail -n 1
    }

    # fn: _previous_release - Return the archived release immediately preceding current
        # . Purpose
        #   Return the archived release immediately preceding current.
        # . Returns
        #   0 when a previous release exists; non-zero otherwise.
        # . Usage
        #   previous="$(_previous_release)"
    _previous_release() {
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 1
        find "$VAL_ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -name "${SGND_RELEASE_PRODUCT}-*" -printf '%f\n' 2>/dev/null \
            | _release_sort \
            | tail -n 2 \
            | head -n 1
    }

    # fn: _list_archived_releases - List archived releases in ascending version order
        # . Purpose
        #   List archived releases in ascending version order.
        # . Returns
        #   0 always.
        # . Usage
        #   _list_archived_releases
    _list_archived_releases() {
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 0
        find "$VAL_ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -name "${SGND_RELEASE_PRODUCT}-*" -printf '%f\n' 2>/dev/null | _release_sort
    }

    # fn: _find_pending_archives - List pending release tarballs under the releases directory
        # . Purpose
        #   List pending release tarballs under the releases directory.
        # . Returns
        #   0 always.
        # . Usage
        #   _find_pending_archives
    _find_pending_archives() {
        [[ -d "$VAL_RELEASES_DIR" ]] || return 0
        find "$VAL_RELEASES_DIR" -maxdepth 2 -type f -name "${SGND_RELEASE_PRODUCT}-*.tar.gz" -print 2>/dev/null
    }

    # fn: _newest_pending_archive - Find the newest pending archive matching an optional release selector
        # . Purpose
        #   Find the newest pending archive matching an optional release selector.
        # . Returns
        #   0 when found; 1 otherwise.
        # . Usage
        #   archive="$(_newest_pending_archive "$VAL_RELEASE")"
    _newest_pending_archive() {
        local archive=""
        local base=""
        local requested="${1:-}"
        local -a rows=()

        while IFS= read -r archive; do
            [[ -n "$archive" ]] || continue
            base="$(_release_base_from_archive "$archive")" || continue
            _release_matches "$base" "$requested" || continue
            rows+=("${base}|${archive}")
        done < <(_find_pending_archives)

        (( ${#rows[@]} > 0 )) || return 1
        printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t '|' -k1,1V | tail -n 1 | cut -d '|' -f2-
    }

    # fn: _find_archived_archive - Find the tarball belonging to an archived release
        # . Purpose
        #   Find the tarball belonging to an archived release.
        # . Returns
        #   0 when found; 1 otherwise.
        # . Usage
        #   _find_archived_archive "$release"
    _find_archived_archive() {
        local requested="${1:?missing release}"
        local base=""
        local dir=""

        while IFS= read -r base; do
            _release_matches "$base" "$requested" || continue
            dir="${VAL_ARCHIVE_ROOT%/}/${base}"
            [[ -f "$dir/${base}.tar.gz" ]] && { printf '%s\n' "$dir/${base}.tar.gz"; return 0; }
        done < <(_list_archived_releases)
        return 1
    }

    # fn: _release_location - Resolve a release tarball from pending or archived storage
        # . Purpose
        #   Resolve a release tarball from pending or archived storage.
        # . Returns
        #   0 when found; non-zero otherwise.
        # . Usage
        #   _release_location "$release"
    _release_location() {
        local requested="${1:?missing release}"
        local archive=""

        archive="$(_newest_pending_archive "$requested" 2>/dev/null || true)"
        if [[ -n "$archive" ]]; then
            printf '%s\n' "$archive"
            return 0
        fi

        _find_archived_archive "$requested"
    }

    # fn: _pending_release_base_exists - Test whether a release is available in releases/
        # . Purpose
        #   Test whether a release is available in releases/.
        # . Returns
        #   0 when present; 1 otherwise.
        # . Usage
        #   _pending_release_base_exists "$release"
    _pending_release_base_exists() {
        local requested="${1:?missing release}"
        local archive=""
        archive="$(_newest_pending_archive "$requested" 2>/dev/null || true)"
        [[ -n "$archive" ]]
    }

    # fn: _archived_release_base_exists - Test whether a release is present in archive/
        # . Purpose
        #   Test whether a release is present in archive/.
        # . Returns
        #   0 when present; 1 otherwise.
        # . Usage
        #   _archived_release_base_exists "$release"
    _archived_release_base_exists() {
        local requested="${1:?missing release}"
        _find_archived_archive "$requested" >/dev/null 2>&1
    }

# --- Release verification -----------------------------------------------------------
    # fn: _verify_sha256_sidecar - Verify one release artifact against its SHA256 sidecar
        # . Purpose
        #   Verify one release artifact against its SHA256 sidecar.
        # . Returns
        #   0 when valid; 1 on missing or mismatched data.
        # . Usage
        #   _verify_sha256_sidecar "$file" "$file.sha256"
    _verify_sha256_sidecar() {
        local file_path="${1:?missing file}"
        local sha_file="${2:?missing checksum}"
        local expected=""
        local actual=""

        [[ -f "$file_path" ]] || { _release_fail "Missing release file: $file_path"; return 1; }
        [[ -f "$sha_file" ]] || { _release_fail "Missing checksum file: $sha_file"; return 1; }

        expected="$(awk 'NF {print $1; exit}' "$sha_file")"
        [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || {
            _release_fail "Invalid checksum file: $sha_file"
            return 1
        }

        actual="$(sha256sum "$file_path" | awk '{print $1}')" || return 1
        [[ "${actual,,}" == "${expected,,}" ]] || {
            _release_fail "Checksum mismatch: $(basename -- "$file_path")"
            return 1
        }

        _release_info "Verified checksum: $(basename -- "$file_path")"
    }

    # fn: _safe_relative_path - Validate and normalize a release-relative path
        # . Purpose
        #   Validate and normalize a release-relative path.
        # . Returns
        #   0 when safe; 1 for absolute or traversing paths.
        # . Usage
        #   path="$(_safe_relative_path "$raw")"
    _safe_relative_path() {
        local path="${1:-}"
        path="${path#./}"
        path="${path%/}"
        [[ -n "$path" ]] || return 1
        [[ "$path" != /* ]] || return 1
        [[ "$path" != ".." && "$path" != ../* && "$path" != */../* && "$path" != */.. ]] || return 1
        printf '%s\n' "$path"
    }

    # fn: _validate_tar_paths - Reject unsafe paths contained in a release tarball
        # . Purpose
        #   Reject unsafe paths contained in a release tarball.
        # . Returns
        #   0 when all paths are safe; 1 otherwise.
        # . Usage
        #   _validate_tar_paths "$archive"
    _validate_tar_paths() {
        local archive="${1:?missing archive}"
        local entry=""

        while IFS= read -r entry; do
            [[ "$entry" == "./" || -z "$entry" ]] && continue
            _safe_relative_path "$entry" >/dev/null || {
                _release_fail "Unsafe archive path rejected: $entry"
                return 1
            }
        done < <(tar -tzf "$archive")
    }

    # fn: _validate_manifest_paths - Reject unsafe paths contained in a release manifest
        # . Purpose
        #   Reject unsafe paths contained in a release manifest.
        # . Returns
        #   0 when all paths are safe; 1 otherwise.
        # . Usage
        #   _validate_manifest_paths "$manifest"
    _validate_manifest_paths() {
        local manifest="${1:?missing manifest}"
        local raw=""
        local path=""

        while IFS= read -r raw || [[ -n "$raw" ]]; do
            [[ -n "${raw//[[:space:]]/}" ]] || continue
            [[ "$raw" =~ ^[[:space:]]*# ]] && continue
            path="${raw%%[[:space:]]*}"
            [[ "$path" == "." || "$path" == "./" ]] && continue
            _safe_relative_path "$path" >/dev/null || {
                _release_fail "Unsafe manifest path rejected: $path"
                return 1
            }
        done < "$manifest"
    }

    # fn: _verify_release_set - Verify checksums and path safety for a complete release set
        # . Purpose
        #   Verify checksums and path safety for a complete release set.
        # . Returns
        #   0 when the release set is valid; 1 otherwise.
        # . Usage
        #   _verify_release_set "$archive"
    _verify_release_set() {
        local archive="${1:?missing archive}"
        local base=""
        local dir=""
        local manifest=""
        local removed=""

        _require_command tar || return 1
        _require_command sha256sum || return 1

        base="$(_release_base_from_archive "$archive")" || return 1
        dir="$(dirname -- "$archive")"
        manifest="$dir/${base}.manifest"
        removed="$dir/${base}.removed"

        _verify_sha256_sidecar "$archive" "${archive}.sha256" || return 1
        _verify_sha256_sidecar "$manifest" "${manifest}.sha256" || return 1
        _verify_sha256_sidecar "$removed" "${removed}.sha256" || return 1
        _validate_tar_paths "$archive" || return 1
        _validate_manifest_paths "$manifest" || return 1
        _validate_manifest_paths "$removed" || return 1

        return 0
    }

# --- Manifest operations ------------------------------------------------------------
    # fn: _manifest_paths - Emit normalized paths from a release manifest
        # . Purpose
        #   Emit normalized paths from a release manifest.
        # . Returns
        #   0 after reading the manifest.
        # . Usage
        #   _manifest_paths "$manifest"
    _manifest_paths() {
        local manifest="${1:?missing manifest}"
        local raw=""
        local path=""

        while IFS= read -r raw || [[ -n "$raw" ]]; do
            [[ -n "${raw//[[:space:]]/}" ]] || continue
            [[ "$raw" =~ ^[[:space:]]*# ]] && continue
            path="${raw%%[[:space:]]*}"
            [[ "$path" == "." || "$path" == "./" ]] && continue
            path="$(_safe_relative_path "$path")" || continue
            printf '%s\n' "$path"
        done < "$manifest"
    }

    # fn: _target_path - Map a release-relative path beneath the configured target root
        # . Purpose
        #   Map a release-relative path beneath the configured target root.
        # . Returns
        #   0 always.
        # . Usage
        #   target="$(_target_path "$rel")"
    _target_path() {
        local rel="${1:?missing relative path}"
        if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
            printf '/%s\n' "$rel"
        else
            printf '%s/%s\n' "${VAL_TARGET_ROOT%/}" "$rel"
        fi
    }

    # fn: _remove_paths_from_stream - Remove streamed release paths conservatively from the target
        # . Purpose
        #   Remove streamed release paths conservatively from the target.
        # . Returns
        #   0 on success; non-zero when file removal fails.
        # . Usage
        #   _manifest_paths "$manifest" | _remove_paths_from_stream
    _remove_paths_from_stream() {
        local rel=""
        local target=""
        local -a paths=()
        local i=0

        while IFS= read -r rel; do
            [[ -n "$rel" ]] || continue
            paths+=("$rel")
        done

        # Deepest paths first so directories can be removed after their children.
        if (( ${#paths[@]} > 0 )); then
            mapfile -t paths < <(printf '%s\n' "${paths[@]}" | awk '{ print gsub("/", "/"), $0 }' | sort -k1,1nr -k2,2r | cut -d' ' -f2-)
        fi

        for (( i=0; i<${#paths[@]}; i++ )); do
            rel="${paths[$i]}"
            target="$(_target_path "$rel")"

            if [[ -L "$target" || -f "$target" ]]; then
                _release_run rm -f -- "$target" || return 1
                _release_info "Removed obsolete file: /$rel"
            elif [[ -d "$target" ]]; then
                if (( FLAG_DRYRUN )); then
                    printf '[DRYRUN] rmdir -- %q\n' "$target"
                else
                    rmdir -- "$target" 2>/dev/null || true
                fi
            fi
        done
    }

    # fn: _apply_removed_manifest - Apply the incoming release removal manifest
        # . Purpose
        #   Apply the incoming release removal manifest.
        # . Returns
        #   0 when complete; non-zero on removal failure.
        # . Usage
        #   _apply_removed_manifest "$removed"
    _apply_removed_manifest() {
        local removed="${1:?missing removed manifest}"
        [[ -s "$removed" ]] || return 0
        _manifest_paths "$removed" | _remove_paths_from_stream
    }

    # fn: _remove_release_difference - Remove paths present in one release manifest but absent from another
        # . Purpose
        #   Remove paths present in one release manifest but absent from another.
        # . Returns
        #   0 on success; non-zero on comparison/removal failure.
        # . Usage
        #   _remove_release_difference "$current_manifest" "$target_manifest"
    _remove_release_difference() {
        local from_manifest="${1:?missing from manifest}"
        local to_manifest="${2:?missing to manifest}"
        local old_sorted=""
        local new_sorted=""
        local diff_file=""

        old_sorted="$(mktemp)" || return 1
        new_sorted="$(mktemp)" || { rm -f "$old_sorted"; return 1; }
        diff_file="$(mktemp)" || { rm -f "$old_sorted" "$new_sorted"; return 1; }

        _manifest_paths "$from_manifest" | LC_ALL=C sort -u > "$old_sorted"
        _manifest_paths "$to_manifest" | LC_ALL=C sort -u > "$new_sorted"
        LC_ALL=C comm -23 "$old_sorted" "$new_sorted" > "$diff_file"

        _remove_paths_from_stream < "$diff_file"
        local rc=$?
        rm -f -- "$old_sorted" "$new_sorted" "$diff_file"
        return "$rc"
    }

# --- Archive/release movement -------------------------------------------------------
    # fn: _archive_release_set - Move an installed pending release set into versioned archive history
        # . Purpose
        #   Move an installed pending release set into versioned archive history.
        # . Returns
        #   0 on success; non-zero on filesystem failure.
        # . Usage
        #   _archive_release_set "$archive"
    _archive_release_set() {
        local archive="${1:?missing archive}"
        local base=""
        local source_dir=""
        local dest_dir=""
        local artifact=""
        local -a artifacts=()

        base="$(_release_base_from_archive "$archive")" || return 1
        source_dir="$(dirname -- "$archive")"
        dest_dir="${VAL_ARCHIVE_ROOT%/}/${base}"

        # Already archived: no movement required.
        if [[ "$source_dir" == "$dest_dir" ]]; then
            return 0
        fi

        artifacts=(
            "${base}.tar.gz"
            "${base}.tar.gz.sha256"
            "${base}.manifest"
            "${base}.manifest.sha256"
            "${base}.removed"
            "${base}.removed.sha256"
        )

        _release_run mkdir -p -- "$dest_dir" || return 1

        for artifact in "${artifacts[@]}"; do
            [[ -e "${source_dir%/}/${artifact}" ]] || continue
            _release_run mv -f -- "${source_dir%/}/${artifact}" "$dest_dir/" || return 1
        done

        if (( ! FLAG_DRYRUN )); then
            {
                for artifact in "${base}.tar.gz" "${base}.manifest" "${base}.removed"; do
                    if [[ -f "$dest_dir/$artifact" ]]; then
                        sha256sum "$dest_dir/$artifact" | sed "s|  $dest_dir/|  |"
                    fi
                done
            } > "$dest_dir/SHA256SUMS"
        fi

        # Remove release-local checksum residue and the empty versioned pending directory.
        if [[ "$source_dir" != "$VAL_RELEASES_DIR" && "$source_dir" == "$VAL_RELEASES_DIR"/* ]]; then
            if [[ -f "$source_dir/SHA256SUMS" ]]; then
                _release_run rm -f -- "$source_dir/SHA256SUMS" || return 1
            fi
            if (( FLAG_DRYRUN )); then
                printf '[DRYRUN] rmdir -- %q\n' "$source_dir"
            else
                rmdir -- "$source_dir" 2>/dev/null || true
            fi
        fi
    }

    # fn: _move_archive_dir_to_releases - Return one archived release directory to releases/
        # . Purpose
        #   Return one archived release directory to releases/.
        # . Returns
        #   0 on success; 1 when the destination exists or movement fails.
        # . Usage
        #   _move_archive_dir_to_releases "$base"
    _move_archive_dir_to_releases() {
        local base="${1:?missing release base}"
        local source="${VAL_ARCHIVE_ROOT%/}/${base}"
        local dest="${VAL_RELEASES_DIR%/}/${base}"

        [[ -d "$source" ]] || return 0
        [[ ! -e "$dest" ]] || {
            _release_fail "Cannot move archived release back to releases; destination exists: $dest"
            return 1
        }

        _release_run mkdir -p -- "$VAL_RELEASES_DIR" || return 1
        _release_run mv -- "$source" "$dest"
    }

    # fn: _move_newer_archives_to_releases - Return archived versions newer than a rollback target to releases/
        # . Purpose
        #   Return archived versions newer than a rollback target to releases/.
        # . Returns
        #   0 on success; non-zero on movement failure.
        # . Usage
        #   _move_newer_archives_to_releases "$target_base"
    _move_newer_archives_to_releases() {
        local target_base="${1:?missing target release}"
        local base=""
        local newer=0

        while IFS= read -r base; do
            [[ "$base" == "$target_base" ]] && { newer=1; continue; }
            (( newer )) || continue
            _move_archive_dir_to_releases "$base" || return 1
        done < <(_list_archived_releases)
    }

    # fn: _move_all_archives_to_releases - Return all archived releases to releases/
        # . Purpose
        #   Return all archived releases to releases/.
        # . Returns
        #   0 on success; non-zero on movement failure.
        # . Usage
        #   _move_all_archives_to_releases
    _move_all_archives_to_releases() {
        local base=""
        while IFS= read -r base; do
            [[ -n "$base" ]] || continue
            _move_archive_dir_to_releases "$base" || return 1
        done < <(_list_archived_releases)
    }

# --- Installation engine ------------------------------------------------------------
    # fn: _extract_release - Extract a complete SolidGroundUX release beneath the target root
        # . Purpose
        #   Extract a complete SolidGroundUX release beneath the target root.
        # . Returns
        #   0 on success; non-zero when extraction fails.
        # . Usage
        #   _extract_release "$archive"
    _extract_release() {
        local archive="${1:?missing archive}"
        _release_run mkdir -p -- "$VAL_TARGET_ROOT" || return 1
        _release_run tar -xzpf "$archive" -C "$VAL_TARGET_ROOT" --no-same-owner --no-overwrite-dir || return 1
        _release_ok "Installed $(_release_base_from_archive "$archive")"
    }

    # fn: _install_pending_archive - Install, update, or roll back to a pending release archive
        # . Purpose
        #   Install, update, or roll back to a pending release archive.
        # . Returns
        #   0 on success; non-zero on verification or deployment failure.
        # . Usage
        #   _install_pending_archive "$archive"
    _install_pending_archive() {
        local archive="${1:?missing archive}"
        local base=""
        local current=""
        local removed=""
        local current_manifest=""
        local target_manifest=""

        base="$(_release_base_from_archive "$archive")" || return 1
        current="$(_current_release 2>/dev/null || true)"

        _verify_release_set "$archive" || return 1

        if [[ -z "$current" ]]; then
            _release_info "Clean install: $base"
            _extract_release "$archive" || return 1
            _archive_release_set "$archive" || return 1
            return 0
        fi

        if [[ "$base" == "$current" ]]; then
            _release_info "Reinstalling current release: $base"
            _extract_release "$archive" || return 1
            _archive_release_set "$archive" || return 1
            return 0
        fi

        if [[ "$(printf '%s\n%s\n' "$current" "$base" | _release_sort | tail -n 1)" == "$base" ]]; then
            removed="$(dirname -- "$archive")/${base}.removed"
            _release_info "Updating $current -> $base"
            _apply_removed_manifest "$removed" || return 1
            _extract_release "$archive" || return 1
            _archive_release_set "$archive" || return 1
            return 0
        fi

        # A specifically selected older pending release is treated as a rollback target.
        current_manifest="${VAL_ARCHIVE_ROOT%/}/${current}/${current}.manifest"
        target_manifest="$(dirname -- "$archive")/${base}.manifest"
        _release_info "Rolling back $current -> $base"
        _remove_release_difference "$current_manifest" "$target_manifest" || return 1
        _extract_release "$archive" || return 1
        _archive_release_set "$archive" || return 1
        _move_newer_archives_to_releases "$base" || return 1
    }

    # fn: _rollback_to_archived_release - Make the installed framework match a selected archived release
        # . Purpose
        #   Make the installed framework match a selected archived release.
        # . Returns
        #   0 on success; non-zero when rollback cannot be completed.
        # . Usage
        #   _rollback_to_archived_release "$target_base"
    _rollback_to_archived_release() {
        local target_base="${1:?missing target release}"
        local current=""
        local archive=""
        local current_manifest=""
        local target_manifest=""

        current="$(_current_release 2>/dev/null || true)"
        [[ -n "$current" ]] || { _release_fail "SolidGroundUX is not currently installed"; return 1; }
        [[ "$target_base" != "$current" ]] || { _release_ok "Already running $current"; return 0; }

        archive="$(_find_archived_archive "$target_base")" || {
            _release_fail "Archived release not found: $target_base"
            return 1
        }

        _verify_release_set "$archive" || return 1
        current_manifest="${VAL_ARCHIVE_ROOT%/}/${current}/${current}.manifest"
        target_manifest="$(dirname -- "$archive")/${target_base}.manifest"

        _release_info "Rolling back $current -> $target_base"
        _remove_release_difference "$current_manifest" "$target_manifest" || return 1
        _extract_release "$archive" || return 1
        _move_newer_archives_to_releases "$target_base" || return 1
        _release_ok "Rollback complete: $target_base"
    }

    # fn: _remove_installation - Remove the active SolidGroundUX installation while retaining release packages
        # . Purpose
        #   Remove the active SolidGroundUX installation while retaining release packages.
        # . Returns
        #   0 on success; non-zero when removal or release movement fails.
        # . Usage
        #   _remove_installation
    _remove_installation() {
        local current=""
        local manifest=""

        current="$(_current_release 2>/dev/null || true)"
        [[ -n "$current" ]] || {
            _release_ok "SolidGroundUX is not installed"
            return 0
        }

        manifest="${VAL_ARCHIVE_ROOT%/}/${current}/${current}.manifest"
        [[ -f "$manifest" ]] || {
            _release_fail "Current release manifest is missing: $manifest"
            return 1
        }

        _release_info "Removing installed release: $current"
        _manifest_paths "$manifest" | _remove_paths_from_stream || return 1
        _move_all_archives_to_releases || return 1
        _release_ok "SolidGroundUX removed; archived releases returned to the releases directory"
    }

# --- GitHub/source acquisition ------------------------------------------------------
    # fn: _download_to - Download or copy a release source to a destination file
        # . Purpose
        #   Download or copy a release source to a destination file.
        # . Returns
        #   0 on success; non-zero on transfer failure.
        # . Usage
        #   _download_to "$source" "$destination"
    _download_to() {
        local source="${1:?missing source}"
        local dest="${2:?missing destination}"

        if [[ "$source" == http://* || "$source" == https://* ]]; then
            if command -v curl >/dev/null 2>&1; then
                curl -fL --retry 2 --connect-timeout 15 -o "$dest" "$source"
                return $?
            fi
            if command -v wget >/dev/null 2>&1; then
                wget -O "$dest" "$source"
                return $?
            fi
            _release_fail "Neither curl nor wget is available for HTTP downloads"
            return 1
        fi

        source="${source#file://}"
        [[ -f "$source" ]] || { _release_fail "Release source not found: $source"; return 1; }
        cp -f -- "$source" "$dest"
    }

    # fn: _github_latest_tag - Resolve the latest GitHub release tag
        # . Purpose
        #   Resolve the latest GitHub release tag.
        # . Returns
        #   0 when a tag is resolved; non-zero otherwise.
        # . Usage
        #   _github_latest_tag "$VAL_GITHUB_REPO"
    _github_latest_tag() {
        local repo="${1:?missing repository}"
        local latest_url="https://github.com/${repo}/releases/latest"
        local effective=""
        local json=""
        local tag=""

        if command -v curl >/dev/null 2>&1; then
            effective="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$latest_url")" || return 1
            tag="${effective##*/}"
            [[ -n "$tag" && "$tag" != "latest" ]] || return 1
            printf '%s\n' "$tag"
            return 0
        fi

        if command -v wget >/dev/null 2>&1; then
            json="$(wget -qO- "https://api.github.com/repos/${repo}/releases/latest")" || return 1
            tag="$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
            [[ -n "$tag" ]] || return 1
            printf '%s\n' "$tag"
            return 0
        fi

        _release_fail "Neither curl nor wget is available for GitHub checks"
        return 1
    }

    # fn: _base_from_tag - Convert a GitHub tag into a canonical SolidGroundUX release base
        # . Purpose
        #   Convert a GitHub tag into a canonical SolidGroundUX release base.
        # . Returns
        #   0 always.
        # . Usage
        #   _base_from_tag "$tag"
    _base_from_tag() {
        local tag="${1:?missing tag}"
        local version="$tag"

        case "$version" in
            "${SGND_RELEASE_PRODUCT}-"*) printf '%s\n' "$version"; return 0 ;;
        esac

        version="${version#v}"
        printf '%s-%s\n' "$SGND_RELEASE_PRODUCT" "$version"
    }

    # fn: _github_release_asset_url - Build the versioned GitHub release ZIP asset URL
        # . Purpose
        #   Build the versioned GitHub release ZIP asset URL.
        # . Returns
        #   0 always.
        # . Usage
        #   _github_release_asset_url "$tag" "$base"
    _github_release_asset_url() {
        local tag="${1:?missing tag}"
        local base="${2:?missing base}"
        printf 'https://github.com/%s/releases/download/%s/%s-release.zip\n' "$VAL_GITHUB_REPO" "$tag" "$base"
    }

    # fn: _latest_online_release - Resolve the canonical base name of the latest GitHub release
        # . Purpose
        #   Resolve the canonical base name of the latest GitHub release.
        # . Returns
        #   0 on success; non-zero when GitHub lookup fails.
        # . Usage
        #   _latest_online_release
    _latest_online_release() {
        local tag=""
        tag="$(_github_latest_tag "$VAL_GITHUB_REPO")" || {
            _release_fail "Could not determine the latest GitHub release"
            return 1
        }
        _base_from_tag "$tag"
    }

    # fn: _release_is_local_or_installed - Test whether a release is already downloaded or archived
        # . Purpose
        #   Test whether a release is already downloaded or archived.
        # . Returns
        #   0 when present locally; 1 otherwise.
        # . Usage
        #   _release_is_local_or_installed "$base"
    _release_is_local_or_installed() {
        local base="${1:?missing base}"
        _archived_release_base_exists "$base" && return 0
        _pending_release_base_exists "$base" && return 0
        return 1
    }

    # fn: _admit_extracted_release - Validate an extracted release ZIP and admit its artifacts to releases/
        # . Purpose
        #   Validate an extracted release ZIP and admit its artifacts to releases/.
        # . Returns
        #   0 on success; non-zero when validation or movement fails.
        # . Usage
        #   _admit_extracted_release "$root" "$expected_base"
    _admit_extracted_release() {
        local extracted_root="${1:?missing extraction root}"
        local expected_base="${2:-}"
        local archive=""
        local base=""
        local source_dir=""
        local artifact=""
        local -a candidates=()
        local -a artifacts=()

        mapfile -t candidates < <(find "$extracted_root" -type f -name "${SGND_RELEASE_PRODUCT}-*.tar.gz" -print)
        (( ${#candidates[@]} == 1 )) || {
            _release_fail "Release ZIP must contain exactly one SolidGroundUX tar.gz archive"
            return 1
        }

        archive="${candidates[0]}"
        base="$(_release_base_from_archive "$archive")" || return 1
        if [[ -n "$expected_base" && "$base" != "$expected_base" ]]; then
            _release_fail "Downloaded release identity mismatch: expected $expected_base, found $base"
            return 1
        fi

        _verify_release_set "$archive" || return 1
        source_dir="$(dirname -- "$archive")"
        artifacts=(
            "${base}.tar.gz"
            "${base}.tar.gz.sha256"
            "${base}.manifest"
            "${base}.manifest.sha256"
            "${base}.removed"
            "${base}.removed.sha256"
        )

        _release_run mkdir -p -- "$VAL_RELEASES_DIR" || return 1
        for artifact in "${artifacts[@]}"; do
            [[ -f "$source_dir/$artifact" ]] || {
                _release_fail "Release ZIP is missing: $artifact"
                return 1
            }
            _release_run mv -f -- "$source_dir/$artifact" "$VAL_RELEASES_DIR/" || return 1
        done

        _release_ok "Release admitted: $base"
        printf '%s\n' "$base"
    }

    # fn: _acquire_release - Acquire, stage, validate, and admit a release ZIP
        # . Purpose
        #   Acquire, stage, validate, and admit a release ZIP.
        # . Returns
        #   0 on success; non-zero on discovery, transfer, extraction, or validation failure.
        # . Usage
        #   _acquire_release "$expected_base" "$source"
    _acquire_release() {
        local expected_base="${1:-}"
        local source="${2:-}"
        local tag=""
        local temp_dir=""
        local zip_path=""
        local base=""

        _require_command unzip || return 1
        _require_command mktemp || return 1

        if [[ -z "$source" ]]; then
            tag="$(_github_latest_tag "$VAL_GITHUB_REPO")" || {
                _release_fail "Could not determine latest GitHub release"
                return 1
            }
            base="$(_base_from_tag "$tag")"
            [[ -n "$expected_base" ]] || expected_base="$base"
            source="$(_github_release_asset_url "$tag" "$base")"
        fi

        if [[ -n "$expected_base" ]] && _release_is_local_or_installed "$expected_base"; then
            _release_ok "$expected_base is already installed or available locally"
            printf '%s\n' "$expected_base"
            return 0
        fi

        temp_dir="$(mktemp -d)" || return 1
        zip_path="$temp_dir/release.zip"

        _release_info "Downloading release to temporary staging: $source"
        if (( FLAG_DRYRUN )); then
            printf '[DRYRUN] acquire %q -> %q\n' "$source" "$zip_path"
            rm -rf -- "$temp_dir"
            [[ -n "$expected_base" ]] && printf '%s\n' "$expected_base"
            return 0
        fi

        _download_to "$source" "$zip_path" || { rm -rf -- "$temp_dir"; return 1; }
        unzip -q "$zip_path" -d "$temp_dir/extracted" || {
            _release_fail "Could not extract downloaded release ZIP"
            rm -rf -- "$temp_dir"
            return 1
        }

        base="$(_admit_extracted_release "$temp_dir/extracted" "$expected_base")" || {
            rm -rf -- "$temp_dir"
            return 1
        }

        rm -rf -- "$temp_dir"
        printf '%s\n' "$base"
    }

# --- Interactive helpers ------------------------------------------------------------
    # fn: _confirm - Request a standalone yes/no confirmation
        # . Purpose
        #   Request a standalone yes/no confirmation.
        # . Returns
        #   0 for confirmation; 1 for rejection or unavailable interaction.
        # . Usage
        #   _confirm "Continue?"
    _confirm() {
        local prompt="${1:-Continue?}"
        local reply=""

        (( FLAG_AUTO )) && return 0
        [[ -t 0 && -t 1 ]] || {
            _release_fail "Confirmation required; use --auto for non-interactive operation"
            return 1
        }

        printf '%s%s [Y/n] %s' "$_RL_UI_PROMPT" "$prompt" "$_RL_UI_INPUT" > /dev/tty
        read -r reply < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
        case "${reply^^}" in
            ""|Y|YES) return 0 ;;
            *) return 1 ;;
        esac
    }

    # fn: _select_archived_release - Select an archived release or the remove operation from a submenu
        # . Purpose
        #   Select an archived release or the remove operation from a submenu.
        # . Returns
        #   0 with the selected target on stdout; 1 when returning/cancelling.
        # . Usage
        #   target="$(_select_archived_release)"
    _select_archived_release() {
        local current=""
        local base=""
        local choice=""
        local i=0
        local -a releases=()

        current="$(_current_release 2>/dev/null || true)"
        mapfile -t releases < <(_list_archived_releases)
        (( ${#releases[@]} > 0 )) || { _release_fail "No archived releases found"; return 1; }

        local remove_choice=$(( ${#releases[@]} + 1 ))

        printf '\n%sArchived releases%s\n' "$_RL_BRIGHT_WHITE" "$_RL_RESET" > /dev/tty
        
        _release_line "─" > /dev/tty
        printf "${_RL_ITALIC}  Versions listed from new to old. Buildnr concatenates year,day-of-year,hour\n${_RL_RESET}" > /dev/tty
        printf "${_RL_ITALIC}  Selected version will be installed over the current one.\n${_RL_RESET}" > /dev/tty
        printf "\n" > /dev/tty
        for (( i=${#releases[@]}-1; i>=0; i-- )); do
            base="${releases[$i]}"
            if [[ "$base" == "$current" ]]; then
                printf '  %s%d)%s %s%s%s %s(current)%s\n' "$_RL_UI_PROMPT" "$(( ${#releases[@]} - i ))" "$_RL_RESET" "$_RL_BRIGHT_WHITE" "$base" "$_RL_RESET" "$_RL_BRIGHT_WHITE" "$_RL_RESET" > /dev/tty
            else
                printf '  %s%d)%s %s%s%s\n' "$_RL_UI_PROMPT" "$(( ${#releases[@]} - i ))" "$_RL_RESET" "$_RL_DARK_WHITE" "$base" "$_RL_RESET" > /dev/tty
            fi
        done
        printf '  %s%d)%s %sRemove SolidGroundUX%s\n' "$_RL_MSG_FAIL" "$remove_choice" "$_RL_RESET" "$_RL_MSG_FAIL" "$_RL_RESET" > /dev/tty
        printf '  %sQ)%s %sReturn%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '\n' > /dev/tty
        _release_line "─" > /dev/tty
        printf '%sSelect target: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty

        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
        case "${choice^^}" in
            Q|"") return 1 ;;
        esac

        [[ "$choice" =~ ^[0-9]+$ ]] || return 1
        if (( choice == remove_choice )); then
            printf '%s\n' '__REMOVE__'
            return 0
        fi

        (( choice >= 1 && choice <= ${#releases[@]} )) || return 1
        i=$(( ${#releases[@]} - choice ))
        printf '%s\n' "${releases[$i]}"
    }

    # fn: _print_status - Display current installed and locally available release state
        # . Purpose
        #   Display current installed and locally available release state.
        # . Returns
        #   0 always.
        # . Usage
        #   _print_status
    _print_status() {
        local current=""
        local pending=""
        local pending_base=""

        current="$(_current_release 2>/dev/null || true)"
        pending="$(_newest_pending_archive 2>/dev/null || true)"
        [[ -n "$pending" ]] && pending_base="$(_release_base_from_archive "$pending")"

        _release_labeled_value "Installed version" "${current:-Not installed}"
        _release_labeled_value "Available locally" "${pending_base:-None}"
        _release_labeled_value "Releases directory" "$VAL_RELEASES_DIR"
        _release_labeled_value "Archive directory" "$VAL_ARCHIVE_ROOT"
    }

    # fn: _interactive_menu - Run the standalone interactive release-manager menu
        # . Purpose
        #   Run the standalone interactive release-manager menu.
        # . Returns
        #   0 on normal exit.
        # . Usage
        #   _interactive_menu
    _interactive_menu() {
        local choice=""
        local target=""

        while true; do
            _release_clear
            _release_title
            _print_status
            _release_line "─"
            printf '\n'
            printf '    %s1)%s %sCheck GitHub for latest release%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s2)%s %sDownload latest release%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s3)%s %sUpdate to latest GitHub release%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s4)%s %sInstall newest local release%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s5)%s %sInstall archived version / remove%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %sQ)%s %sQuit%s\n\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            
            _release_line "─"
            printf '%sSelect option: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
            read -r choice < /dev/tty
            printf '%s' "$_RL_RESET" > /dev/tty

            case "${choice^^}" in
                1) ACTION=check; _action_check; _pause ;;
                2) ACTION=download; _action_download; _pause ;;
                3) ACTION=update; _action_update; _pause ;;
                4) ACTION=install; _action_install; _pause ;;
                5)
                    target="$(_select_archived_release 2>/dev/tty)" || continue
                    if [[ "$target" == '__REMOVE__' ]]; then
                        _confirm "Remove SolidGroundUX?" && _remove_installation
                    else
                        _confirm "Install $target?" && _rollback_to_archived_release "$target"
                    fi
                    _pause
                    ;;
                Q) return 0 ;;
            esac
        done
    }

    # fn: _pause - Wait for Enter after an interactive operation
        # . Purpose
        #   Wait for Enter after an interactive operation.
        # . Returns
        #   0 always.
        # . Usage
        #   _pause
    _pause() {
        [[ -t 0 && -t 1 ]] || return 0
        printf '\n%sPress Enter to continue...%s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r _ < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
    }

# --- Action dispatch ----------------------------------------------------------------
    # fn: _action_check - Report the latest GitHub release and its local state
        # . Purpose
        #   Report the latest GitHub release and its local state.
        # . Returns
        #   0 on success; non-zero when online discovery fails.
        # . Usage
        #   _action_check
    _action_check() {
        local latest=""
        local current=""
        local local_state="Not downloaded"

        latest="$(_latest_online_release)" || return 1
        current="$(_current_release 2>/dev/null || true)"

        if _archived_release_base_exists "$latest"; then
            local_state="Installed"
        elif _pending_release_base_exists "$latest"; then
            local_state="Downloaded"
        fi

        printf '\n'
        _release_labeled_value "Latest GitHub release" "$latest"
        _release_labeled_value "Installed version" "${current:-Not installed}"
        _release_labeled_value "Latest release state" "$local_state"

        if [[ "$local_state" == "Installed" ]]; then
            _release_ok "Already current"
        elif [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$latest" | _release_sort | tail -n 1)" == "$current" ]]; then
            _release_ok "Installed version is current or newer"
        else
            _release_warn "Update available: $latest"
        fi
    }

    # fn: _action_download - Acquire the latest or explicitly sourced release without installing it
        # . Purpose
        #   Acquire the latest or explicitly sourced release without installing it.
        # . Returns
        #   0 on success; non-zero on acquisition failure.
        # . Usage
        #   _action_download
    _action_download() {
        local latest=""

        if [[ -n "$VAL_SOURCE" ]]; then
            _acquire_release "" "$VAL_SOURCE" >/dev/null
            return $?
        fi

        latest="$(_latest_online_release)" || return 1
        _acquire_release "$latest" "" >/dev/null
    }

    # fn: _action_update - Acquire if needed and install the latest available release
        # . Purpose
        #   Acquire if needed and install the latest available release.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_update
    _action_update() {
        local latest=""
        local current=""
        local archive=""

        current="$(_current_release 2>/dev/null || true)"

        if [[ -n "$VAL_SOURCE" ]]; then
            _acquire_release "" "$VAL_SOURCE" >/dev/null || return 1
            archive="$(_newest_pending_archive)" || {
                _release_fail "No pending release was found after acquisition"
                return 1
            }
            latest="$(_release_base_from_archive "$archive")"
        else
            latest="$(_latest_online_release)" || return 1

            if _archived_release_base_exists "$latest"; then
                _release_ok "Latest GitHub release is already installed: $latest"
                return 0
            fi

            if [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$latest" | _release_sort | tail -n 1)" == "$current" ]]; then
                _release_ok "Installed version is current or newer: $current"
                return 0
            fi

            if ! _pending_release_base_exists "$latest"; then
                _acquire_release "$latest" "" >/dev/null || return 1
            fi

            archive="$(_newest_pending_archive "$latest")" || {
                _release_fail "Latest release was not found after acquisition: $latest"
                return 1
            }
        fi

        if [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$latest" | _release_sort | tail -n 1)" == "$current" && "$current" != "$latest" ]]; then
            _release_ok "Installed version is current or newer: $current"
            return 0
        fi

        _confirm "Install $latest?" || return 2
        _install_pending_archive "$archive"
    }

    # fn: _action_install - Install the newest matching pending local release
        # . Purpose
        #   Install the newest matching pending local release.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_install
    _action_install() {
        local archive=""
        archive="$(_newest_pending_archive "$VAL_RELEASE" 2>/dev/null || true)"
        [[ -n "$archive" ]] || {
            _release_fail "No matching pending release found"
            return 1
        }
        _confirm "Install $(_release_base_from_archive "$archive")?" || return 2
        _install_pending_archive "$archive"
    }

    # fn: _action_rollback - Install the previous or explicitly selected archived release
        # . Purpose
        #   Install the previous or explicitly selected archived release.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_rollback
    _action_rollback() {
        local target="$VAL_RELEASE"
        local previous=""

        if [[ -z "$target" ]]; then
            previous="$(_previous_release 2>/dev/null || true)"
            [[ -n "$previous" ]] || {
                _release_fail "No previous archived release is available"
                return 1
            }
            target="$previous"
        fi

        _confirm "Install archived release $target?" || return 2
        _rollback_to_archived_release "$target"
    }

    # fn: _action_remove - Remove the active SolidGroundUX installation after confirmation
        # . Purpose
        #   Remove the active SolidGroundUX installation after confirmation.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_remove
    _action_remove() {
        _confirm "Remove SolidGroundUX from $VAL_TARGET_ROOT?" || return 2
        _remove_installation
    }

# --- Main ----------------------------------------------------------------------------
    # fn: main - Run standalone release-manager initialization and dispatch
        # . Purpose
        #   Run standalone release-manager initialization and dispatch.
        # . Returns
        #   Exit status of the selected interactive or command-line action.
        # . Usage
        #   main "$@"
    main() {
        parse_args "$@" || return $?
        init_paths || return $?

        _require_command find || return 1
        _require_command sort || return 1
        _require_command tar || return 1
        _require_command sha256sum || return 1
        _require_command awk || return 1
        _require_command sed || return 1
        _require_command comm || return 1
        _require_command mktemp || return 1

        _ensure_manager_directories || return 1
        _admit_bootstrap_release || return $?
        _install_release_manager || return 1

        if [[ -z "$ACTION" && -n "${BOOTSTRAP_RELEASE_BASE:-}" ]]; then
            # A clean machine started from a release bundle bootstraps itself immediately.
            _bootstrap_first_install || return $?
        fi

        if [[ -z "$ACTION" ]]; then
            [[ -t 0 && -t 1 ]] || {
                _release_fail "No action specified in non-interactive mode"
                print_usage
                return 1
            }
            _interactive_menu
            return $?
        fi

        local rc=0
        case "$ACTION" in
            check) _action_check || rc=$? ;;
            download) _action_download || rc=$? ;;
            update) _action_update || rc=$? ;;
            install) _action_install || rc=$? ;;
            rollback) _action_rollback || rc=$? ;;
            remove) _action_remove || rc=$? ;;
            *) _release_fail "Unknown action: $ACTION"; rc=1 ;;
        esac

        if (( rc == 0 )) && [[ -n "${BOOTSTRAP_RELEASE_BASE:-}" ]]; then
            _cleanup_bootstrap_files || return 1
        fi

        return "$rc"
    }

    main "$@"
