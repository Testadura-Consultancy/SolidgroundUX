# ==================================================================================
# SolidGroundUX - Active Directory
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621612
#   Checksum    : 95e1bfcba80f89a7139011f563ddcc425789ffc6ba1314fda732f2f2e6060725
#   Source      : 20-active-directory.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Install and manage Active Directory server and client roles
#
# Description:
#   Provides Samba Active Directory server provisioning, account management, and client domain membership actions.
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : -
#   Copyright     : © 2025 - 2026 Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # . Behavior
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
        # . Returns
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard "example-0"
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
    
# - Module metadata -------------------------------------------------------------
    SGND_ACTIVE_DIRECTORY_MODULE_ID="active-directory"
    SGND_ACTIVE_DIRECTORY_MODULE_NAME="Active Directory"
    SGND_ACTIVE_DIRECTORY_MODULE_VERSION="1.0.0"
    SGND_ACTIVE_DIRECTORY_MODULE_DESC="Manage Active Directory server and client roles"

    SGND_MODULE_ID="${SGND_ACTIVE_DIRECTORY_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_ACTIVE_DIRECTORY_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_ACTIVE_DIRECTORY_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_ACTIVE_DIRECTORY_MODULE_DESC}"

# - Active Directory server ------------------------------------------------------
    # fn$ _samba_validate_realm
        # . Purpose
        #   Validate a Kerberos realm or DNS domain name.
        #
        # . Behavior
        #   - Requires at least two DNS labels separated by dots.
        #   - Accepts letters, digits, and internal hyphens in each label.
        #   - Rejects labels that begin or end with a hyphen.
        #
        # Inputs:
        #   $1 - Realm or DNS domain name to validate.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   _samba_validate_realm "2026-07-31" && printf 'Success\n' || printf 'Failed\n'
    _samba_validate_realm() {
        [[ "${1-}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]
    }

    # fn$ _samba_validate_netbios
        # . Purpose
        #   Validate a Samba NetBIOS domain name.
        #
        # . Behavior
        #   - Requires the name to begin with a letter.
        #   - Accepts letters, digits, underscores, and hyphens.
        #   - Limits the value to fifteen characters.
        #
        # Inputs:
        #   $1 - NetBIOS domain name to validate.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   _samba_validate_netbios "2026-07-31" && printf 'Success\n' || printf 'Failed\n'
    _samba_validate_netbios() {
        [[ "${1-}" =~ ^[A-Za-z][A-Za-z0-9_-]{0,14}$ ]]
    }

    # fn$ _samba_validate_account_name
        # . Purpose
        #   Validate a basic Samba account or group name.
        #
        # . Behavior
        #   - Requires an alphanumeric first character.
        #   - Accepts letters, digits, periods, underscores, and hyphens.
        #   - Limits the value to sixty-four characters.
        #
        # Inputs:
        #   $1 - Account or group name to validate.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   _samba_validate_account_name "2026-07-31" && printf 'Success\n' || printf 'Failed\n'
    _samba_validate_account_name() {
        [[ "${1-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]
    }

    # fn$ _samba_default_gateway
        # . Purpose
        #   Determine the first configured IPv4 default gateway.
        #
        # . Behavior
        #   - Reads the IPv4 routing table.
        #   - Returns the gateway from the first default route.
        #
        # Outputs (stdout):
        #   IPv4 address of the default gateway, or an empty value when unavailable.
        #
        # . Returns
        #   The exit status of the routing-table pipeline.
        #
        # . Usage
        #   _samba_default_gateway "example-3"
    _samba_default_gateway() {
        ip -4 route show default 2>/dev/null | awk 'NR == 1 { print $3 }'
    }

    # fn$ _samba_domain_is_provisioned
        # . Purpose
        #   Determine whether this machine contains a provisioned Samba AD domain.
        #
        # . Behavior
        #   - Verifies that the Samba directory database exists and is non-empty.
        #   - Confirms that Samba reports the Active Directory domain controller role.
        #
        # . Returns
        #   0 when a provisioned Samba AD domain is present.
        #   1 otherwise.
        #
        # . Usage
        #   _samba_domain_is_provisioned && printf 'Success\n' || printf 'Failed\n'
    _samba_domain_is_provisioned() {
        [[ -s /var/lib/samba/private/sam.ldb ]] && \
            sudo testparm -s --parameter-name='server role' 2>/dev/null | \
                grep -qi '^active directory domain controller$'
    }

    # fn$ _samba_require_provisioned_domain
        # . Purpose
        #   Guard actions that require an existing Samba AD domain.
        #
        # . Behavior
        #   - Tests whether a Samba AD domain has been provisioned.
        #   - Reports a framework failure message when no domain is present.
        #
        # . Returns
        #   0 when a provisioned domain is available.
        #   1 when no provisioned domain was found.
        #
        # . Usage
        #   _samba_require_provisioned_domain
    _samba_require_provisioned_domain() {
        if _samba_domain_is_provisioned; then
            return 0
        fi

        sayfail "No provisioned Samba Active Directory domain was found."
        return 1
    }

    # fn$ _install_samba_ad
        # . Purpose
        #   Install the packages required for a Samba Active Directory Domain Controller.
        #
        # . Behavior
        #   - Refreshes the APT package index.
        #   - Installs Samba AD/DC, Kerberos, and DNS diagnostic packages.
        #   - Stops, disables, and masks standalone Samba services.
        #   - Unmasks and enables the dedicated Samba AD/DC service.
        #   - Leaves domain creation to the separate provisioning action.
        #   - Honors dry-run mode without changing the system.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when installation and service preparation succeed.
        #   Non-zero when a required package or service operation fails.
        #
        # . Usage
        #   _install_samba_ad
    _install_samba_ad() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Samba Active Directory Domain Controller packages."
            return 0
        fi

        sayinfo "Updating Ubuntu package index."
        sudo apt-get update || return 1

        sayinfo "Installing Samba Active Directory Domain Controller packages."
        sudo apt-get install -y \
            bind9-dnsutils \
            krb5-user \
            samba-ad-dc || return 1

        sayinfo "Preparing Samba services for AD/DC provisioning."
        sudo systemctl disable --now smbd.service nmbd.service winbind.service 2>/dev/null || true
        sudo systemctl mask smbd.service nmbd.service winbind.service 2>/dev/null || true
        sudo systemctl unmask samba-ad-dc.service || return 1
        sudo systemctl enable samba-ad-dc.service || return 1

        sayinfo "Samba AD/DC packages installed; domain provisioning is still required."
    }

    # fn$ _samba_configure_resolver
        # . Purpose
        #   Prepare systemd-resolved to coexist with Samba's internal DNS server.
        #
        # . Behavior
        #   - Creates a SolidGroundUX systemd-resolved drop-in.
        #   - Disables the local DNS stub listener on port 53.
        #   - Points /etc/resolv.conf at the non-stub resolver file.
        #   - Restarts systemd-resolved to apply the configuration.
        #
        # Outputs (files):
        #   /etc/systemd/resolved.conf.d/solidgroundux-samba-ad.conf
        #   /etc/resolv.conf
        #
        # . Returns
        #   0 when resolver configuration succeeds.
        #   Non-zero when a filesystem or service operation fails.
        #
        # . Usage
        #   _samba_configure_resolver
    _samba_configure_resolver() {
        local dropin_dir="/etc/systemd/resolved.conf.d"
        local dropin_file="$dropin_dir/solidgroundux-samba-ad.conf"

        sudo install -d -m 0755 "$dropin_dir" || return 1
        printf '%s\n' \
            '[Resolve]' \
            'DNSStubListener=no' | \
            sudo tee "$dropin_file" >/dev/null || return 1

        sudo ln -sfn /run/systemd/resolve/resolv.conf /etc/resolv.conf || return 1
        sudo systemctl restart systemd-resolved.service || return 1
    }

    # fn$ _samba_set_dns_forwarder
        # . Purpose
        #   Set or replace Samba's DNS forwarder in the global configuration section.
        #
        # . Behavior
        #   - Rewrites an existing dns forwarder directive when present.
        #   - Inserts the directive before the next section when absent.
        #   - Preserves the remaining Samba configuration.
        #   - Installs the resulting file with root ownership and mode 0644.
        #
        # Inputs:
        #   $1 - Upstream DNS server IPv4 address.
        #
        # Outputs (files):
        #   /etc/samba/smb.conf
        #
        # . Returns
        #   0 when the configuration is updated successfully.
        #   Non-zero when temporary-file creation, rewriting, or installation fails.
        #
        # . Usage
        #   _samba_set_dns_forwarder "example"
    _samba_set_dns_forwarder() {
        local forwarder="$1"
        local smb_conf="/etc/samba/smb.conf"
        local tmp_file

        tmp_file="$(mktemp)" || return 1

        awk -v forwarder="$forwarder" '
            BEGIN { in_global = 0; written = 0 }
            /^\[global\][[:space:]]*$/ {
                in_global = 1
                print
                next
            }
            /^\[/ {
                if (in_global && !written) {
                    printf "\tdns forwarder = %s\n", forwarder
                    written = 1
                }
                in_global = 0
            }
            in_global && /^[[:space:]]*dns forwarder[[:space:]]*=/ {
                if (!written) {
                    printf "\tdns forwarder = %s\n", forwarder
                    written = 1
                }
                next
            }
            { print }
            END {
                if (in_global && !written) {
                    printf "\tdns forwarder = %s\n", forwarder
                }
            }
        ' "$smb_conf" > "$tmp_file" || {
            rm -f "$tmp_file"
            return 1
        }

        sudo install -o root -g root -m 0644 "$tmp_file" "$smb_conf" || {
            rm -f "$tmp_file"
            return 1
        }

        rm -f "$tmp_file"
    }

    # fn$ samba_create_domain
        # . Purpose
        #   Interactively provision a new Samba Active Directory domain.
        #
        # . Behavior
        #   - Verifies that Samba tooling is installed and no domain already exists.
        #   - Derives sensible defaults from the hostname, DNS suffix, and gateway.
        #   - Asks for the Kerberos realm, NetBIOS domain, and DNS forwarder.
        #   - Displays the resolved configuration and requests confirmation.
        #   - Stops conflicting Samba services and preserves an existing smb.conf.
        #   - Provisions an RFC2307-enabled AD domain with Samba internal DNS.
        #   - Configures the DNS forwarder and system resolver.
        #   - Installs Samba's generated Kerberos configuration.
        #   - Enables the Samba AD/DC service and performs DNS registration.
        #   - Verifies the domain SOA and Kerberos SRV records.
        #   - Honors dry-run mode without changing the system.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # Outputs (files/services):
        #   /etc/samba/smb.conf
        #   /etc/krb5.conf
        #   systemd-resolved.service
        #   samba-ad-dc.service
        #
        # . Returns
        #   0 when provisioning succeeds or is cancelled by the user.
        #   1 when validation, provisioning, configuration, or verification fails.
        #
        # . Usage
        #   samba_create_domain
    samba_create_domain() {
        local hostname_short
        local current_domain
        local realm
        local dns_domain
        local netbios_domain
        local dns_forwarder
        local decision
        local smb_backup=""

        command -v samba-tool >/dev/null 2>&1 || {
            sayfail "samba-tool is unavailable; install the Samba AD server role first."
            return 1
        }

        if _samba_domain_is_provisioned; then
            saywarning "This machine already contains a provisioned Samba AD domain."
            return 1
        fi

        hostname_short="$(hostname -s)"
        current_domain="$(hostname -d 2>/dev/null || true)"
        [[ -n "$current_domain" ]] || current_domain="testadura.hq"

        realm="${current_domain^^}"
        netbios_domain="${current_domain%%.*}"
        netbios_domain="${netbios_domain^^}"
        dns_forwarder="$(_samba_default_gateway)"
        [[ -n "$dns_forwarder" ]] || dns_forwarder="192.168.0.1"

        sgnd_print
        sgnd_print_sectionheader "Create Samba Active Directory domain"

        ask \
            --label "Kerberos realm" \
            --var realm \
            --default "$realm" \
            --validate _samba_validate_realm
        realm="${realm^^}"
        dns_domain="${realm,,}"

        ask \
            --label "NetBIOS domain" \
            --var netbios_domain \
            --default "$netbios_domain" \
            --validate _samba_validate_netbios
        netbios_domain="${netbios_domain^^}"

        ask \
            --label "DNS forwarder" \
            --var dns_forwarder \
            --default "$dns_forwarder" \
            --validate sgnd_validate_ipv4

        sgnd_print
        sgnd_print_labeledvalue --label "Hostname" --value "$hostname_short"
        sgnd_print_labeledvalue --label "DNS domain" --value "$dns_domain"
        sgnd_print_labeledvalue --label "Kerberos realm" --value "$realm"
        sgnd_print_labeledvalue --label "NetBIOS domain" --value "$netbios_domain"
        sgnd_print_labeledvalue --label "DNS forwarder" --value "$dns_forwarder"
        sgnd_print_labeledvalue --label "DNS backend" --value "SAMBA_INTERNAL"
        sgnd_print

        ask_decision \
            --label "Provision this domain?" \
            --choices "YES|Y,NO|N" \
            --default "NO" \
            --var decision

        [[ "$decision" == "YES" ]] || {
            sayinfo "Domain provisioning cancelled."
            return 0
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would provision $realm on $hostname_short."
            return 0
        fi

        sayinfo "Stopping Samba services before provisioning."
        sudo systemctl stop samba-ad-dc.service 2>/dev/null || true
        sudo systemctl disable --now smbd.service nmbd.service winbind.service 2>/dev/null || true
        sudo systemctl mask smbd.service nmbd.service winbind.service 2>/dev/null || true

        if [[ -e /etc/samba/smb.conf ]]; then
            smb_backup="/etc/samba/smb.conf.pre-ad.$(date +%Y%m%d%H%M%S)"
            sayinfo "Saving the existing Samba configuration as $smb_backup."
            sudo mv /etc/samba/smb.conf "$smb_backup" || return 1
        fi

        sayinfo "Provisioning Samba Active Directory."
        sayinfo "Samba will now ask for the domain Administrator password."
        if ! sudo samba-tool domain provision \
            --use-rfc2307 \
            --realm="$realm" \
            --domain="$netbios_domain" \
            --server-role=dc \
            --dns-backend=SAMBA_INTERNAL \
            </dev/tty; then
            sayfail "Samba AD domain provisioning failed."
            [[ -n "$smb_backup" && ! -e /etc/samba/smb.conf ]] && \
                sudo mv "$smb_backup" /etc/samba/smb.conf
            return 1
        fi

        sayinfo "Configuring the DNS forwarder."
        _samba_set_dns_forwarder "$dns_forwarder" || return 1

        sayinfo "Disabling the systemd-resolved DNS stub listener."
        _samba_configure_resolver || return 1

        if [[ -s /var/lib/samba/private/krb5.conf ]]; then
            sayinfo "Installing Samba's generated Kerberos configuration."
            sudo install -o root -g root -m 0644 \
                /var/lib/samba/private/krb5.conf \
                /etc/krb5.conf || return 1
        fi

        sayinfo "Starting the Samba Active Directory Domain Controller."
        sudo systemctl unmask samba-ad-dc.service || return 1
        sudo systemctl enable --now samba-ad-dc.service || return 1

        sayinfo "Running Samba DNS registration."
        sudo samba_dnsupdate --verbose || {
            saywarning "Samba DNS registration reported an error; review AD status."
        }

        if host -t SOA "$dns_domain" 127.0.0.1 >/dev/null 2>&1 && \
           host -t SRV "_kerberos._tcp.$dns_domain" 127.0.0.1 >/dev/null 2>&1; then
            sayinfo "Samba Active Directory domain $realm was provisioned successfully."
        else
            saywarning "Provisioning completed, but one or more DNS verification checks failed."
            return 1
        fi
    }

    # fn$ samba_ad_status
        # . Purpose
        #   Display the operational status of the local Samba AD Domain Controller.
        #
        # . Behavior
        #   - Reads the configured Samba server role and Kerberos realm.
        #   - Checks the AD/DC service and DNS listener.
        #   - Tests the domain SOA, Kerberos SRV, and LDAP SRV records.
        #   - Counts domain users and groups when the domain is provisioned.
        #   - Displays the configured domain and forest functional levels.
        #
        # Outputs (console):
        #   Samba role, realm, service, DNS, Kerberos, LDAP, user, group, and level status.
        #
        # . Returns
        #   0 after displaying status.
        #   1 when Samba is not installed.
        #
        # . Usage
        #   samba_ad_status
    samba_ad_status() {
        local realm=""
        local role=""
        local dns_domain=""
        local service_state="inactive"
        local dns_listener="No"
        local soa_state="Unavailable"
        local kerberos_state="Unavailable"
        local ldap_state="Unavailable"
        local user_count="-"
        local group_count="-"

        command -v testparm >/dev/null 2>&1 || {
            sayfail "Samba is not installed."
            return 1
        }

        role="$(sudo testparm -s --parameter-name='server role' 2>/dev/null || true)"
        realm="$(sudo testparm -s --parameter-name='realm' 2>/dev/null || true)"
        dns_domain="${realm,,}"

        systemctl is-active --quiet samba-ad-dc.service && service_state="active"
        sudo ss -lntup 2>/dev/null | grep -qE '(^|[[:space:]])(0\.0\.0\.0|127\.0\.0\.1|\[::\]):53[[:space:]]' && dns_listener="Yes"

        if [[ -n "$dns_domain" ]]; then
            host -t SOA "$dns_domain" 127.0.0.1 >/dev/null 2>&1 && soa_state="Available"
            host -t SRV "_kerberos._tcp.$dns_domain" 127.0.0.1 >/dev/null 2>&1 && kerberos_state="Available"
            host -t SRV "_ldap._tcp.$dns_domain" 127.0.0.1 >/dev/null 2>&1 && ldap_state="Available"
        fi

        if _samba_domain_is_provisioned; then
            user_count="$(sudo samba-tool user list 2>/dev/null | wc -l)"
            group_count="$(sudo samba-tool group list 2>/dev/null | wc -l)"
        fi

        sgnd_print
        sgnd_print_sectionheader "Samba Active Directory status"
        sgnd_print_labeledvalue --label "Server role" --value "${role:-Not configured}"
        sgnd_print_labeledvalue --label "Realm" --value "${realm:-Not configured}"
        sgnd_print_labeledvalue --label "AD/DC service" --value "$service_state"
        sgnd_print_labeledvalue --label "DNS port 53" --value "$dns_listener"
        sgnd_print_labeledvalue --label "DNS zone" --value "$soa_state"
        sgnd_print_labeledvalue --label "Kerberos SRV" --value "$kerberos_state"
        sgnd_print_labeledvalue --label "LDAP SRV" --value "$ldap_state"
        sgnd_print_labeledvalue --label "Users" --value "$user_count"
        sgnd_print_labeledvalue --label "Groups" --value "$group_count"

        if _samba_domain_is_provisioned; then
            sgnd_print
            sudo samba-tool domain level show
        fi
    }

    # fn$ samba_add_user
        # . Purpose
        #   Create a user account in the provisioned Samba AD domain.
        #
        # . Behavior
        #   - Requires an existing provisioned domain.
        #   - Asks for and validates the account name.
        #   - Requests confirmation before creation.
        #   - Lets samba-tool securely prompt for the new account password.
        #   - Honors dry-run mode without changing the directory.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when the user is created, cancelled, or handled in dry-run mode.
        #   1 when no domain exists or samba-tool fails.
        #
        # . Usage
        #   samba_add_user
    samba_add_user() {
        local account_name=""
        local decision=""

        _samba_require_provisioned_domain || return 1

        ask \
            --label "AD user name" \
            --var account_name \
            --validate _samba_validate_account_name

        ask_decision \
            --label "Create user '$account_name'?" \
            --choices "YES|Y,NO|N" \
            --default "YES" \
            --var decision

        [[ "$decision" == "YES" ]] || return 0

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would create AD user $account_name."
            return 0
        fi

        sayinfo "Samba will now ask for the new user's password."
        sudo samba-tool user create "$account_name" </dev/tty || return 1
        sayinfo "AD user $account_name created."
    }

    # fn$ samba_add_group
        # . Purpose
        #   Create a group in the provisioned Samba AD domain.
        #
        # . Behavior
        #   - Requires an existing provisioned domain.
        #   - Asks for and validates the group name.
        #   - Requests confirmation before creation.
        #   - Creates the group with samba-tool.
        #   - Honors dry-run mode without changing the directory.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when the group is created, cancelled, or handled in dry-run mode.
        #   1 when no domain exists or samba-tool fails.
        #
        # . Usage
        #   samba_add_group
    samba_add_group() {
        local group_name=""
        local decision=""

        _samba_require_provisioned_domain || return 1

        ask \
            --label "AD group name" \
            --var group_name \
            --validate _samba_validate_account_name

        ask_decision \
            --label "Create group '$group_name'?" \
            --choices "YES|Y,NO|N" \
            --default "YES" \
            --var decision

        [[ "$decision" == "YES" ]] || return 0

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would create AD group $group_name."
            return 0
        fi

        sudo samba-tool group add "$group_name" || return 1
        sayinfo "AD group $group_name created."
    }

# - Server account management ---------------------------------------------------
    # fn: samba_list_users - List Active Directory users
        # . Returns
        #   Exit status from samba-tool.
        #
        # . Usage
        #   samba_list_users
    samba_list_users() {
        _samba_require_provisioned_domain || return 1
        sudo samba-tool user list
    }

    # fn: samba_list_groups - List Active Directory groups
        # . Returns
        #   Exit status from samba-tool.
        #
        # . Usage
        #   samba_list_groups
    samba_list_groups() {
        _samba_require_provisioned_domain || return 1
        sudo samba-tool group list
    }

    # fn: _samba_ask_user - Ask for and validate an Active Directory user name
        # . Arguments
        #   $1  Output variable name.
        #
        # . Returns
        #   Status returned by ask.
        #
        # . Usage
        #   _samba_ask_user account_name
    _samba_ask_user() {
        local output_var="$1"
        local account_name=""
        ask --label "AD user name" --var account_name --validate _samba_validate_account_name || return $?
        printf -v "$output_var" '%s' "$account_name"
    }

    # fn: samba_change_user_password - Change an Active Directory user password
        # . Returns
        #   Exit status from samba-tool.
        #
        # . Usage
        #   samba_change_user_password
    samba_change_user_password() {
        local account_name=""
        _samba_require_provisioned_domain || return 1
        _samba_ask_user account_name || return $?
        (( ${FLAG_DRYRUN:-0} == 1 )) && { sayinfo "Dry run: Would change the password for $account_name."; return 0; }
        sudo samba-tool user setpassword "$account_name" </dev/tty
    }

    # fn: samba_enable_user - Enable an Active Directory user
        # . Returns
        #   Exit status from samba-tool.
        #
        # . Usage
        #   samba_enable_user
    samba_enable_user() {
        local account_name=""
        _samba_require_provisioned_domain || return 1
        _samba_ask_user account_name || return $?
        (( ${FLAG_DRYRUN:-0} == 1 )) && { sayinfo "Dry run: Would enable $account_name."; return 0; }
        sudo samba-tool user enable "$account_name"
    }

    # fn: samba_disable_user - Disable an Active Directory user
        # . Returns
        #   Exit status from samba-tool.
        #
        # . Usage
        #   samba_disable_user
    samba_disable_user() {
        local account_name=""
        _samba_require_provisioned_domain || return 1
        _samba_ask_user account_name || return $?
        (( ${FLAG_DRYRUN:-0} == 1 )) && { sayinfo "Dry run: Would disable $account_name."; return 0; }
        sudo samba-tool user disable "$account_name"
    }

    # fn: samba_set_user_no_expiry - Prevent an Active Directory user password from expiring
        # . Returns
        #   Exit status from samba-tool.
        #
        # . Usage
        #   samba_set_user_no_expiry
    samba_set_user_no_expiry() {
        local account_name=""
        _samba_require_provisioned_domain || return 1
        _samba_ask_user account_name || return $?
        (( ${FLAG_DRYRUN:-0} == 1 )) && { sayinfo "Dry run: Would set no expiry for $account_name."; return 0; }
        sudo samba-tool user setexpiry "$account_name" --noexpiry
    }

# - Active Directory client ------------------------------------------------------
    # fn: _install_ad_client - Install Active Directory client packages
        # . Returns
        #   0 on success; non-zero when package installation fails.
        #
        # . Usage
        #   _install_ad_client
    _install_ad_client() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Active Directory client packages."
            return 0
        fi
        sudo apt-get update || return 1
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            adcli krb5-user libnss-sss libpam-sss packagekit realmd \
            samba-common-bin sssd-ad sssd-tools || return 1
        sayok "Active Directory client packages installed."
    }

    # fn: ad_client_status - Show current realm membership
        # . Returns
        #   Exit status from realm list.
        #
        # . Usage
        #   ad_client_status
    ad_client_status() {
        command -v realm >/dev/null 2>&1 || { saywarning "realmd is not installed."; return 1; }
        realm list
    }

    # fn: ad_client_join - Join this computer to an Active Directory realm
        # . Returns
        #   Exit status from realm join.
        #
        # . Usage
        #   ad_client_join
    ad_client_join() {
        local realm_name="$(hostname -d 2>/dev/null || true)"
        ask --label "AD realm" --var realm_name --default "$realm_name" --validate _samba_validate_realm || return $?
        (( ${FLAG_DRYRUN:-0} == 1 )) && { sayinfo "Dry run: Would join $realm_name."; return 0; }
        sudo realm join "$realm_name" </dev/tty
    }

    # fn: ad_client_leave - Leave an Active Directory realm
        # . Returns
        #   Exit status from realm leave.
        #
        # . Usage
        #   ad_client_leave
    ad_client_leave() {
        local realm_name=""
        realm_name="$(realm list --name-only 2>/dev/null | head -n 1)"
        ask --label "AD realm" --var realm_name --default "$realm_name" --validate _samba_validate_realm || return $?
        (( ${FLAG_DRYRUN:-0} == 1 )) && { sayinfo "Dry run: Would leave $realm_name."; return 0; }
        sudo realm leave "$realm_name"
    }

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group "ad-server" "Active Directory Server" "Install, provision, and inspect a Samba Active Directory Domain Controller" 0 1 200
    sgnd_console_register_item "ad-install" "ad-server" "Install server packages" "_install_samba_ad" "Install Samba Active Directory Domain Controller packages" 0 5 1
    sgnd_console_register_item "ad-domain" "ad-server" "Create domain" "samba_create_domain" "Provision a new Samba Active Directory domain" 0 5 1
    sgnd_console_register_item "ad-status" "ad-server" "Show AD status" "samba_ad_status" "Show service, DNS, Kerberos, and domain status" 0 15 1

    sgnd_console_register_group "ad-accounts" "AD Users and Groups" "Create, list, and manage Active Directory users and groups" 0 1 210
    sgnd_console_register_item "ad-user-add" "ad-accounts" "Create user" "samba_add_user" "Create an Active Directory user" 0 5 1
    sgnd_console_register_item "ad-group-add" "ad-accounts" "Create group" "samba_add_group" "Create an Active Directory group" 0 5 1
    sgnd_console_register_item "ad-users" "ad-accounts" "List users" "samba_list_users" "List Active Directory users" 0 15 1
    sgnd_console_register_item "ad-groups" "ad-accounts" "List groups" "samba_list_groups" "List Active Directory groups" 0 15 1
    sgnd_console_register_item "ad-passwd" "ad-accounts" "Change user password" "samba_change_user_password" "Set a new Active Directory user password" 0 5 1
    sgnd_console_register_item "ad-enable" "ad-accounts" "Enable user" "samba_enable_user" "Enable an Active Directory user" 0 5 1
    sgnd_console_register_item "ad-disable" "ad-accounts" "Disable user" "samba_disable_user" "Disable an Active Directory user" 0 5 1
    sgnd_console_register_item "ad-noexpiry" "ad-accounts" "Set password never expires" "samba_set_user_no_expiry" "Prevent an Active Directory user password from expiring" 0 5 1

    sgnd_console_register_group "ad-client" "Active Directory Client" "Install, join, leave, and inspect Active Directory client membership" 0 1 220
    sgnd_console_register_item "adc-install" "ad-client" "Install client packages" "_install_ad_client" "Install realmd and SSSD Active Directory client packages" 0 5 1
    sgnd_console_register_item "adc-join" "ad-client" "Join domain" "ad_client_join" "Join this computer to an Active Directory realm" 0 5 1
    sgnd_console_register_item "adc-leave" "ad-client" "Leave domain" "ad_client_leave" "Leave the current Active Directory realm" 0 5 1
    sgnd_console_register_item "adc-status" "ad-client" "Show membership" "ad_client_status" "Show current realm membership" 0 15 1
