# ==================================================================================
# SolidGroundUX - Console Helpers
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : ab3471db97fbd16baff98b1593b4b5778c48a5310ec910427cdf2b60fd8fc02e
#   Source      : console-helpers.sh
#   Type        : library
#   Group       : SolidGround Console
#   Purpose     : Provide shared helper functions used by multiple console modules
#
# Description:
#   Contains small operational helpers that are shared across otherwise independent
#   lazy-loaded console modules. Keeping these helpers in the common library avoids
#   cross-module load-order dependencies.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail

# - Library guard ------------------------------------------------------------------
    # _sgnd_lib_guard
        # Returns:
        #   0 when the library may continue loading; exits with 2 when executed directly.
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

        [[ -n "${!guard-}" ]] && return 1
        printf -v "$guard" '1'
        return 0
    }

    _sgnd_lib_guard || return 0
    unset -f _sgnd_lib_guard

# - Framework-internal API ---------------------------------------------------------
    # _sgnd_flag_is_on
        # Purpose:
        #   Evaluate whether a framework flag value represents a logical true state.
        #
        # Arguments:
        #   $1  Value to evaluate.
        #
        # Returns:
        #   0 for 1, true, yes, or on (case-insensitive variants currently supported).
        #   1 otherwise.
        #
        # Usage:
        #   _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"
    _sgnd_flag_is_on() {
        case "${1:-}" in
            1|true|TRUE|yes|YES|on|ON) return 0 ;;
            *) return 1 ;;
        esac
    }

# - Public API ---------------------------------------------------------------------
    # sgnd_console_set_dns_server
        # Purpose:
        #   Update only the configured DNS server through the canonical identity tool.
        #
        # Behavior:
        #   - Delegates DNS configuration to set-identity.sh.
        #   - Keeps Active Directory server/client modules independent from Computer Setup.
        #
        # Arguments:
        #   $1  DNS server IPv4 address.
        #
        # Returns:
        #   Exit status from the canonical identity workflow.
        #
        # Usage:
        #   sgnd_console_set_dns_server "192.168.0.15"
    sgnd_console_set_dns_server() {
        local dns_server="${1:-}"

        [[ -n "$dns_server" ]] || {
            sayfail "A DNS server IPv4 address is required."
            return 1
        }

        declare -F _sgnd_run_module_script >/dev/null 2>&1 || {
            sayfail "Console module-script runner is unavailable."
            return 1
        }

        _sgnd_run_module_script "set-identity.sh" --dns-only --DNS "$dns_server" --Auto
    }
