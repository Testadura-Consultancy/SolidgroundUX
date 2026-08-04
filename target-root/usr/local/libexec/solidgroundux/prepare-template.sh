#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Executable Script Template
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621201
#   Checksum    : 900dd08d724fe39cfa15e1a46356efe2b7d5b2f674d251e5729a920458c91756
#   Source      : prepare-template.sh
#   Type        : script
#   Group       : SolidGround Console
#   Purpose     : Prepares a VM for conversion to a reusable clone template.
#
# Description:
#   Prepares a VM for cloning by clearing transient state, resetting network configuration, and removing machine-specific identifiers.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# - Bootstrap -----------------------------------------------------------------------
    # fn$ _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
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
    _framework_locator (){
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply

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
            if [[ -t 0 && -t 1 ]]; then

                printf '%s\n' "SolidGroundUX bootstrap configuration"
                printf '%s\n'  "No configuration file found."
                printf '%s\n'  "Creating: $cfg"

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            # Validate paths (must be absolute)
            case "$fw_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_APPLICATION_ROOT must be an absolute path"; return 126 ;;
            esac

            # Create configuration file
            mkdir -p "$(dirname "$cfg")" || return 127

            # write cfg file 
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

           printf '%s\n' "Created bootstrap cfg: $cfg"
        fi

        # Load configuration
        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"

            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            printf '%s\n' "Cannot read bootstrap cfg: $cfg"
            return 126
        fi

        case "${SGND_LOG_LEVEL:-silent}" in
            silent|quiet)
                ;;
            *)
                printf '%s\n' "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT"
                ;;
        esac

        local exe_common=""

        exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# - Script identity ------------------------------------------------------------------
    # var: SGND_SCRIPT_FILE - Absolute path to the currently executing script
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"

    # var: SGND_SCRIPT_DIR - Directory containing the currently executing script
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"

    # var: SGND_SCRIPT_BASE - Filename of the currently executing script
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"

    # var: SGND_SCRIPT_NAME - Script basename without the .sh extension
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    # var$ SGND_SCRIPT_FILE
        # Absolute path to the currently executing script.
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"

    # var$ SGND_SCRIPT_DIR
        # Directory containing the currently executing script.
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"

    # var$ SGND_SCRIPT_BASE
        # Filename of the currently executing script, including extension.
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"

    # var$ SGND_SCRIPT_NAME
        # Script basename without the .sh extension; used for help and display text.
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# --- Framework integration ----------------------------------------------------------
    # var: SGND_USING - Optional framework libraries to source after core bootstrap
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
        #
        # Example:
        #   SGND_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    SGND_USING=(
    )

    # var: SGND_ARGS_SPEC - Script-specific command-line argument specification
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
    )

    # var: SGND_SCRIPT_EXAMPLES - Optional help examples for this script
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
        "Run in dry-run mode:"
        "  $SGND_SCRIPT_NAME --dryrun"
        ""
        "Show verbose logging"
        "  $SGND_SCRIPT_NAME --verbose"
    ) 

    # var: SGND_SCRIPT_GLOBALS - Script globals participating in configuration loading# var: SGND_SCRIPT_GLOBALS - Script globals participating in configuration loading
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

    # var: SGND_STATE_VARIABLES - Script variables participating in persistent state
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

    # var: SGND_ON_EXIT_HANDLERS - Script-specific exit handler list
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
    
    # var$ SGND_STATE_SAVE
        # State persistence toggle used by sgnd_bootstrap when state support is enabled.
        #
        # Scripts that want persistent state must:
        #   1) set SGND_STATE_SAVE=1
        #   2) call sgnd_bootstrap --state or --autostate
    SGND_STATE_SAVE=0

# - Local script declarations -------------------------------------------------------
    # doc$ Local script declarations
        # Put script-local constants and defaults here, not framework configuration.
        # Prefer local variables inside functions unless a value must be shared.

# - Local script functions ----------------------------------------------------------
    # doc$ Local script functions
        # Organize script-specific functions here.
        # These functions are not reusable framework behavior; they implement the
        # unique logic and features of the executable script.
        #
        # Suggested organization:
        #   - Initialization
        #   - Local script helpers
        #   - Layout and display helpers
        #   - Input handling
        #   - Business logic
        #   - Validation
        #   - Reporting
        #   - Cleanup

    # fn: _detect_primary_iface - Detect primary iface
        # . Purpose
        #   Detect primary iface.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _detect_primary_iface
    _detect_primary_iface() {
        local primary_iface

        primary_iface="$(ip -o -4 route show to default | awk '{print $5; exit}')"
        if [[ -z "$primary_iface" ]]; then
            primary_iface="$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' | grep -v '^lo$' | head -n 1)"
        fi

        if [[ -z "$primary_iface" ]]; then
            sayerror 'No network interface found.'
            return 1
        fi

        printf '%s\n' "$primary_iface"
    }

    # fn: _reset_network_for_template - Reset network for template
        # . Purpose
        #   Reset network for template.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _reset_network_for_template
    _reset_network_for_template() {
        local primary_iface
        local netplan_file='/etc/netplan/00-installer-config.yaml'

        primary_iface="$(_detect_primary_iface)" || return $?
        sayinfo "Resetting network configuration to DHCP on $primary_iface"

        rm -f /etc/netplan/*.yaml || return $?

        {
            printf '%s\n' 'network:'
            printf '%s\n' '  version: 2'
            printf '%s\n' '  renderer: networkd'
            printf '%s\n' '  ethernets:'
            printf '    %s:\n' "$primary_iface"
            printf '%s\n' '      dhcp4: true'
        } > "$netplan_file" || return $?

        chown root:root "$netplan_file" || return $?
        chmod 600 "$netplan_file" || return $?
        netplan generate || return $?
    }

    # fn: _prepare_template - Prepare template
        # . Purpose
        #   Prepare template.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _prepare_template
    _prepare_template() {
        sayinfo "Preparing VM for template conversion..."

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: would have:"
            sayinfo "- Cleaned package cache"
            sayinfo "- Removed unused packages"
            sayinfo "- Reset network configuration to DHCP"
            sayinfo "- Removed SSH host keys"
            sayinfo "- Cleaned systemd journal"
            sayinfo "- Cleaned temporary files"
            sayinfo "- Cleared machine-id"
            sayinfo "- Shut down the machine"
        else
            sayinfo "Cleaning package cache..."
            apt clean || return $?

            sayinfo "Removing unused packages..."
            apt autoremove -y || return $?

            _reset_network_for_template || return $?

            sayinfo "Removing SSH host keys..."
            rm -f /etc/ssh/ssh_host_* || return $?
            sayinfo "After cloning, regenerate SSH host keys from the Proxmox console before using SSH."

            sayinfo "Cleaning systemd journal..."
            journalctl --rotate || return $?
            journalctl --vacuum-time=1s || return $?

            sayinfo "Cleaning temporary files..."
            find /tmp -mindepth 1 -delete || return $?
            find /var/tmp -mindepth 1 -delete || return $?

            sayinfo "Clearing machine-id..."
            truncate -s 0 /etc/machine-id || return $?
            rm -f /var/lib/dbus/machine-id || return $?
            ln -sf /etc/machine-id /var/lib/dbus/machine-id || return $?

            sayinfo "Flushing filesystem buffers..."
            sync || return $?
        fi

        ask_dlg_autocontinue --seconds 10 --message "Shutting down system in " --redo --cancel --pause

        if (( ${FLAG_DRYRUN:-0} == 0 )); then
            shutdown now || return $?
        fi
    }

# - Main ----------------------------------------------------------------------------
    # fn: main - Run the executable main sequence
        # . Purpose
        #   Run the standard executable startup sequence and then execute
        #   script-specific logic.
        #
        # . Arguments
        #   $@  Command-line arguments.
        #
        # . Behavior
        #   - Locates the SolidGroundUX framework.
        #   - Loads executable runtime support.
        #   - Starts the framework runtime through sgnd_exe_start.
        #   - Continues with script-specific logic.
        #
        # . Returns
        #   Exits with the resulting status code from startup or script logic.
        #
        # . Usage
        #   main "$@"
    main() {     
        _framework_locator || exit $?
        sgnd_exe_start --needroot "$@"

        _prepare_template || exit $?
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
