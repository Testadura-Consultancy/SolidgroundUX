# =====================================================================================
# SolidgroundUX - System Utilities
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608701
#   Checksum    : 1f4b7393c901338947a2c681f7723616731ca63103957513c838c479587b1cd3
#   Source      : sgnd-system.sh
#   Type        : library
#   Purpose     : Provide host, runtime, and operating-system utility helpers
#
# Description:
#   Contains environment-aware helpers that sit above sgnd-core.
#
#   The library:
#     - Provides root/sudo/runtime guards
#     - Exposes OS, network, and service-state helpers
#     - Includes ownership and permission normalization helpers
#     - Keeps operational/debug output close to procedural system actions
#
# Design principles:
#   - Keep system behavior out of sgnd-core
#   - Depend on framework bootstrap guarantees for minimal say* functions
#   - Prefer explicit operational helpers over mixing host logic into generic primitives
#   - Keep behavior predictable and side effects documented
#
# Role in framework:
#   - System/runtime layer above sgnd-core
#   - Used by installers, setup routines, and host-aware modules
#   - Centralizes platform and privilege helpers
#
# Non-goals:
#   - Business logic or application-specific behavior
#   - Interactive UI rendering or menu behavior
#   - Generic string/array/text helpers (handled in sgnd-core)
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
        # Inputs (globals):
        #   BASH_SOURCE
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

# --- Requirement checks -------------------------------------------------------------
    # sgnd_need_root
        # Purpose:
        #   Require the script to run as root, re-executing through sudo when needed.
        #
        # Arguments:
        #   $@  Original script arguments forwarded to the re-exec call.
        #
        # Inputs (globals):
        #   SGND_ALREADY_ROOT
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #   PATH
        #
        # Returns:
        #   0 when already running as root and execution may continue.
        #   Does not return when re-exec succeeds.
        #
        # Usage:
        #   sgnd_need_root "$@"
    sgnd_need_root() {
        sayinfo "Script requires root permissions"

        if [[ ${EUID:-$(id -u)} -ne 0 && -z "${SGND_ALREADY_ROOT:-}" ]]; then
            saydebug "Restarting as root"
            exec sudo \
                --preserve-env=SGND_FRAMEWORK_ROOT,SGND_APPLICATION_ROOT,PATH \
                -- env SGND_ALREADY_ROOT=1 "$0" "$@"
        fi

        saydebug "Already root, no restart required"
        return 0
    }

    # sgnd_cannot_root
        # Returns:
        #   0 when not running as root; exits 1 otherwise.
        #
        # Usage:
        #   sgnd_cannot_root
    sgnd_cannot_root() {
        sayinfo "Script requires NOT having root permissions"

        if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
            sayfail "Do not run this script as root. Exiting..."
            exit 1
        fi
    }

    # sgnd_need_systemd
        # Returns:
        #   0 when systemctl is available; exits 1 otherwise.
        #
        # Usage:
        #   sgnd_need_systemd
    sgnd_need_systemd() { sgnd_have systemctl || { sayfail "Systemd not available."; exit 1; }; }

    # sgnd_need_writable
        # Returns:
        #   0 when the path is writable; exits 1 otherwise.
        #
        # Usage:
        #   sgnd_need_writable PATH
    sgnd_need_writable() { [[ -w "$1" ]] || { sayfail "Not writable: $1"; exit 1; }; }

    # sgnd_is_active
        # Returns:
        #   0 if the systemd unit is active; non-zero otherwise.
        #
        # Usage:
        #   sgnd_is_active UNIT
    sgnd_is_active() { systemctl is-active --quiet "$1"; }

    # --- Filesystem helpers -------------------------------------------------------------
    # sgnd_ensure_writable_dir
        # Purpose:
        #   Ensure a directory exists and is suitable for user-scoped writing.
        #
        # Arguments:
        #   $1  DIR
        #
        # Inputs (globals):
        #   SUDO_USER
        #
        # Returns:
        #   0 on success.
        #   2 if DIR is missing or empty.
        #   3 if mkdir -p fails.
        #   4 if the directory still does not exist afterward.
        #
        # Usage:
        #   sgnd_ensure_writable_dir DIR
    sgnd_ensure_writable_dir() {
        local dir="${1:-}"
        local created=0
        local grp

        [[ -n "$dir" ]] || return 2

        if [[ ! -d "$dir" ]]; then
            mkdir -p -- "$dir" || return 3
            created=1
        fi

        if [[ -n "${SUDO_USER:-}" ]]; then
            grp="$(id -gn "$SUDO_USER" 2>/dev/null || printf '%s' "$SUDO_USER")"
            if (( created )); then
                chown "$SUDO_USER:$grp" "$dir" 2>/dev/null || true
            fi
        fi

        [[ -d "$dir" ]] || return 4
        return 0
    }

# --- System helpers -----------------------------------------------------------------
    # sgnd_get_primary_nic
        # Returns:
        #   0 always; output may be empty on failure.
        #
        # Usage:
        #   sgnd_get_primary_nic
    sgnd_get_primary_nic() { ip route show default 2>/dev/null | awk 'NR==1 {print $5}'; }

    # sgnd_ping_ok
        # Returns:
        #   0 if the host responds to a single ICMP ping; non-zero otherwise.
        #
        # Usage:
        #   sgnd_ping_ok HOST
    sgnd_ping_ok() { ping -c1 -W1 "$1" &>/dev/null; }

    # sgnd_port_open
        # Returns:
        #   0 if a TCP connection succeeds; non-zero otherwise.
        #
        # Usage:
        #   sgnd_port_open HOST PORT
    sgnd_port_open() {
        local h="$1"
        local p="$2"

        if sgnd_have nc; then
            nc -z "$h" "$p" &>/dev/null
        else
            (exec 3<>"/dev/tcp/$h/$p") &>/dev/null
        fi
    }

    # sgnd_get_ip
        # Returns:
        #   0 always; output may be empty on failure.
        #
        # Usage:
        #   sgnd_get_ip
    sgnd_get_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }

    # sgnd_real_user
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_real_user
    sgnd_real_user() {
        if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
            printf '%s\n' "${SUDO_USER}"
        else
            id -un
        fi
    }

    # sgnd_real_home
        # Returns:
        #   0 on success; non-zero if the account lookup fails.
        #
        # Usage:
        #   sgnd_real_home
    sgnd_real_home() {
        local user
        user="$(sgnd_real_user)"
        getent passwd "${user}" | cut -d: -f6
    }

    # sgnd_run_as_real_user
        # Returns:
        #   The executed command's exit status.
        #
        # Usage:
        #   sgnd_run_as_real_user COMMAND [ARG ...]
    sgnd_run_as_real_user() {
        local user
        user="$(sgnd_real_user)"

        if (( EUID == 0 )) && [[ "${user}" != "root" ]]; then
            sudo -u "${user}" -H -- "$@"
        else
            "$@"
        fi
    }

    # sgnd_fix_ownership
        # Returns:
        #   0 on success; non-zero on failure.
        #
        # Usage:
        #   sgnd_fix_ownership PATH
    sgnd_fix_ownership() {
        local path="$1"
        local user
        local group

        user="$(sgnd_real_user)"
        group="$(id -gn "${user}")"
        chown -R "${user}:${group}" "${path}"
    }

    # sgnd_fix_permissions
        # Returns:
        #   0 on success; non-zero on failure.
        #
        # Usage:
        #   sgnd_fix_permissions PATH
    sgnd_fix_permissions() {
        local path="$1"

        find "${path}" -type d -exec chmod 755 {} +
        find "${path}" -type f -exec chmod 644 {} +
    }

    # sgnd_get_os
        # Returns:
        #   0 on success; non-zero if /etc/os-release cannot be read.
        #
        # Usage:
        #   sgnd_get_os
    sgnd_get_os() { grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'; }

    # sgnd_get_os_version
        # Returns:
        #   0 on success; non-zero if /etc/os-release cannot be read.
        #
        # Usage:
        #   sgnd_get_os_version
    sgnd_get_os_version() { grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"'; }

# --- Error handlers -----------------------------------------------------------------
    # sgnd_die
        # Purpose:
        #   Terminate the script with a formatted fatal error message.
        #
        # Arguments:
        #   $1  MESSAGE
        #   $2  RC
        #
        # Inputs (globals):
        #   FLAG_VERBOSE
        #
        # Returns:
        #   Does not return.
        #
        # Usage:
        #   sgnd_die [MESSAGE] [RC]
    sgnd_die() {
        local msg="${1-}"
        local rc="${2-1}"

        if (( ${FLAG_VERBOSE:-0} )); then
            sayfail "$rc ${msg:-Fatal error}"
            sgnd_stack_trace
        else
            sayfail "$rc ${msg:-Fatal error} ($(sgnd_caller_id 2))"
        fi

        exit "$rc"
    }

    # sgnd_require
        # Returns:
        #   The executed command's exit status.
        #
        # Usage:
        #   sgnd_require COMMAND [ARG ...]
    sgnd_require() {
        "$@"
        local rc=$?

        if (( rc != 0 )); then
            sayfail "Command failed (rc=$rc): $* ($(sgnd_caller_id 2))"
        fi

        return "$rc"
    }

    # sgnd_must
        # Returns:
        #   0 if the command succeeds; does not return on failure.
        #
        # Usage:
        #   sgnd_must COMMAND [ARG ...]
    sgnd_must() {
        "$@"
        local rc=$?

        (( rc == 0 )) && return 0
        sgnd_die "Fatal: $* (rc=$rc)" "$rc"
    }
