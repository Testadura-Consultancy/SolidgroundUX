#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Executable Script Template
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : -
#   Checksum    : -
#   Source      : set-identity.sh
#   Type        : script
#   Group       : VMConfig
#   Purpose     : Sets the hostname and IP v4 address for a VM
#
# Description:
# 
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
        "Ipv4|i|value|TARGET_IPV4|Target IPv4 address with CIDR (leave empty for DHCP)|"
        "DNS|d|value|TARGET_DNS|Target DNS server IP address|"
        "Gateway|g|value|TARGET_GATEWAY|Target gateway IP address|"
        "Hostname|n|value|TARGET_HOSTNAME|Target hostname for the VM|"
        "Netplan|p|value|NETPLAN_FILE|Path to the netplan configuration file|"
        "Auto|a|flag|FLAG_AUTO|Run in non-interactive mode, using defaults or provided values|"
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
        TARGET_IPV4
        TARGET_HOSTNAME
        TARGET_GATEWAY
        TARGET_DNS
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
    _set_defaults() {
        TARGET_HOSTNAME="td-ubuntuserver"
        TARGET_IPV4="192.168.0.9X/24"
        TARGET_GATEWAY="192.168.0.1"
        TARGET_DNS="192.168.0.1"
        NETPLAN_FILE="/etc/netplan/01-td-headquarters.yaml"

        PRIMARY_IFACE="ens18"
    }

    _get_usr_input() {
        local mxw=80
        local lw=35

        if [[ "$FLAG_AUTO" -eq 1 && -n "$TARGET_IPV4" && -n "$TARGET_HOSTNAME" ]]; then
            return 0
        fi
        
        sgnd_print_sectionheader "Enter identifying information for this host" --maxwidth "$mxw"
        ask --label "Hostname" --var TARGET_HOSTNAME --default "$TARGET_HOSTNAME" --labelwidth "$lw"
        ask --label "Ipv4 address (leave blank for DHCP)" --var TARGET_IPV4 --default "$TARGET_IPV4" --labelwidth "$lw"
        ask --label "Netplan file" --var NETPLAN_FILE --default "$NETPLAN_FILE" --labelwidth "$lw"
        
        if [[ -n "$TARGET_IPV4" ]]; then
            ask --label "Gateway" --var TARGET_GATEWAY --default "$TARGET_GATEWAY" --labelwidth "$lw"
            ask --label "DNS" --var TARGET_DNS --default "$TARGET_DNS" --labelwidth "$lw"
        fi

    }

    _reset_machine_id() {
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo 'Dry-run mode: skipping machine-id reset'
            return 0
        fi

        sayinfo 'Resetting machine-id\n'
        rm -f /etc/machine-id
        rm -f /var/lib/dbus/machine-id
        systemd-machine-id-setup
    }

    _reset_ssh() {
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo 'Dry-run mode: skipping SSH host key regeneration'
            return 0
        fi

        sayinfo 'Regenerating SSH host keys\n'
        rm -f /etc/ssh/ssh_host_*key /etc/ssh/ssh_host_*key.pub
        ssh-keygen -A

        sayinfo 'Enabling SSH service\n'
        systemctl enable ssh
        systemctl restart ssh
    }

    _set_hostname() {
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Dry-run mode: would set hostname to $TARGET_HOSTNAME"
            return 0
        fi

        sayinfo "Setting hostname to $TARGET_HOSTNAME"
        hostnamectl set-hostname "$TARGET_HOSTNAME"

        if grep -q '^127\.0\.1\.1' /etc/hosts; then
            sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $TARGET_HOSTNAME/" /etc/hosts
        else
            printf '127.0.1.1 %s\n' "$TARGET_HOSTNAME" >> /etc/hosts
        fi
    }

    _detect_primary_iface() {
        sayinfo 'Detecting primary network interface'

        PRIMARY_IFACE="$(ip -o -4 route show to default | awk '{print $5; exit}')"
        if [[ -z "${PRIMARY_IFACE}" ]]; then
            PRIMARY_IFACE="$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' | grep -v '^lo$' | head -n 1)"
        fi

        if [[ -z "${PRIMARY_IFACE}" ]]; then
            sayfail 'No network interface found.'
            return 1
        fi

        sayinfo "Primary network interface: $PRIMARY_IFACE"
    }

    _network_config() {
        _detect_primary_iface || return $?

        if [[ -z "$TARGET_IPV4" ]]; then
            sayinfo "No IPv4 address provided, switching to DHCP mode on $PRIMARY_IFACE"
            _set_dhcp
        else
            sayinfo "Configuring static IPv4 $TARGET_IPV4 on $PRIMARY_IFACE"
            _set_static_ip
        fi
    }
        
    _set_static_ip() {
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo 'Dry-run mode: skipping static IP configuration'
            return 0
        fi
        
        sayinfo "Writing static netplan config: $NETPLAN_FILE"

        mkdir -p "$(dirname "$NETPLAN_FILE")"
        _write_netplan_static
        chmod 600 "$NETPLAN_FILE"

        netplan generate
        netplan apply

    }

    _set_dhcp() {
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo 'Dry-run mode: skipping DHCP configuration'
            return 0
        fi

        sayinfo "Writing DHCP netplan config: $NETPLAN_FILE"

        mkdir -p "$(dirname "$NETPLAN_FILE")"
        _write_netplan_dhcp
        chmod 600 "$NETPLAN_FILE"

        netplan generate
        netplan apply
    }

    _write_netplan_static() {
        {
            printf '%s\n' 'network:'
            printf '%s\n' '  version: 2'
            printf '%s\n' '  renderer: networkd'
            printf '%s\n' '  ethernets:'
            printf '    %s:\n' "$PRIMARY_IFACE"
            printf '%s\n' '      dhcp4: false'
            printf '%s\n' '      addresses:'
            printf '        - %s\n' "$TARGET_IPV4"
            printf '%s\n' '      routes:'
            printf '%s\n' '        - to: default'
            printf '          via: %s\n' "$TARGET_GATEWAY"
            printf '%s\n' '      nameservers:'
            printf '%s\n' '        addresses:'
            printf '          - %s\n' "$TARGET_DNS"
        } > "$NETPLAN_FILE"
    }

    _write_netplan_dhcp() {
        {
            printf '%s\n' 'network:'
            printf '%s\n' '  version: 2'
            printf '%s\n' '  renderer: networkd'
            printf '%s\n' '  ethernets:'
            printf '    %s:\n' "$PRIMARY_IFACE"
            printf '%s\n' '      dhcp4: true'
        } > "$NETPLAN_FILE"
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
        
        sgnd_exe_start  --needroot "$@"

        # script logic
        _set_defaults
        _get_usr_input
        
        _reset_machine_id
        _reset_ssh
        _set_hostname
        _network_config


    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
