# ==================================================================================
# SolidGroundUX - Console Helpers
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2625813
#   Checksum    : f95932c864c08bc67274b3de8133309d10f1f54a31070b4eec751cec5208540d
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
    # fn$ _sgnd_lib_guard - Enforce source-only, single-load library initialization
        # . Purpose
        #   Ensure the file is sourced as a library and initialized only once.
        #
        # . Behavior
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution when the file is run directly instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Returns immediately when the library was already loaded.
        #
        # Inputs
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals)
        #   SGND_<MODULE>_LOADED
        #
        # . Returns
        #   0 when already loaded or successfully initialized.
        #   Exits with code 2 when executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard
    _sgnd_lib_guard() {
        local lib_base=""
        local guard=""

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

    if declare -F sgnd_module_init_metadata >/dev/null 2>&1 \
        && declare -F sgnd_header_buffer_load >/dev/null 2>&1; then
        sgnd_module_init_metadata "${BASH_SOURCE[0]}"
    fi
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
