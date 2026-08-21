# ==================================================================================
# SolidGroundUX - SQL Server
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623316
#   Checksum    : c587da3e773b8706d64f6a3be505581179598f64b2684f3de75319336464c46b
#   Source      : 60-sqlserver.sh
#   Type        : module
#   Group       : SolidGround Console
#   Subgroup    : Console Modules
#   Purpose     : Install, configure, validate, and inspect Microsoft SQL Server
#
# Description:
#   Provides a Microsoft SQL Server role for supported Ubuntu hosts. The module
#   configures the Microsoft package repositories, installs SQL Server 2025,
#   launches the canonical mssql-conf setup workflow, and reports/validates the
#   resulting database-engine service.
# ==================================================================================
set -uo pipefail

# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the module is sourced and initialized only once.
        #
        # . Returns
        #   0 when loading may continue; exits with 2 when executed directly.
        #
        # . Usage
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

# - Module metadata ----------------------------------------------------------------
    SGND_SQLSERVER_MODULE_ID="sql-server"
    SGND_SQLSERVER_MODULE_NAME="SQL Server"
    SGND_SQLSERVER_MODULE_VERSION="1.0.0"
    SGND_SQLSERVER_MODULE_DESC="Install, configure, validate, and inspect Microsoft SQL Server"

    SGND_MODULE_ID="$SGND_SQLSERVER_MODULE_ID"
    SGND_MODULE_NAME="$SGND_SQLSERVER_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_SQLSERVER_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_SQLSERVER_MODULE_DESC"

    SGND_SQLSERVER_MAJOR="2025"
    SGND_SQLSERVER_SERVICE="mssql-server.service"

# - Internal helpers ---------------------------------------------------------------
    # fn$ _sqlserver_ubuntu_version
        # . Purpose
        #   Return the current Ubuntu VERSION_ID when the host is supported.
        #
        # . Output
        #   Writes 22.04 or 24.04 to stdout.
        #
        # . Returns
        #   0 for a supported Ubuntu release; 1 otherwise.
        #
        # . Usage
        #   ubuntu_version="$(_sqlserver_ubuntu_version)"
    _sqlserver_ubuntu_version() {
        local os_id=""
        local version_id=""

        [[ -r /etc/os-release ]] || return 1
        # shellcheck disable=SC1091
        source /etc/os-release
        os_id="${ID:-}"
        version_id="${VERSION_ID:-}"

        [[ "$os_id" == "ubuntu" ]] || return 1
        case "$version_id" in
            22.04|24.04)
                printf '%s\n' "$version_id"
                return 0
                ;;
        esac

        return 1
    }

    # fn$ _sqlserver_engine_installed
        # . Returns
        #   0 when the mssql-server package is installed; 1 otherwise.
        #
        # . Usage
        #   _sqlserver_engine_installed
    _sqlserver_engine_installed() {
        dpkg-query -W -f='${Status}' mssql-server 2>/dev/null | grep -q '^install ok installed$'
    }

    # fn$ _sqlserver_tools_installed
        # . Returns
        #   0 when sqlcmd from mssql-tools18 is installed; 1 otherwise.
        #
        # . Usage
        #   _sqlserver_tools_installed
    _sqlserver_tools_installed() {
        [[ -x /opt/mssql-tools18/bin/sqlcmd ]]
    }

    # fn$ _sqlserver_tcp_port
        # . Purpose
        #   Return the configured SQL Server TCP port, defaulting to 1433.
        #
        # . Output
        #   Writes the port number to stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   port="$(_sqlserver_tcp_port)"
    _sqlserver_tcp_port() {
        local port=""

        if [[ -x /opt/mssql/bin/mssql-conf ]]; then
            port="$(sudo /opt/mssql/bin/mssql-conf get network.tcpport 2>/dev/null | awk -F: '/tcpport/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
        fi

        [[ "$port" =~ ^[0-9]+$ ]] || port=1433
        printf '%s\n' "$port"
    }

# - Role preparation ---------------------------------------------------------------
    # fn: _sqlserver_step_repository - Configure Microsoft SQL Server repositories
        # . Returns
        #   0 on success or dry-run; non-zero for unsupported hosts or repository failures.
        #
        # . Usage
        #   _sqlserver_step_repository
    _sqlserver_step_repository() {
        local ubuntu_version=""
        local engine_list="/etc/apt/sources.list.d/mssql-server-2025.list"
        local keyring="/usr/share/keyrings/microsoft-prod.gpg"
        local repo_url=""
        local tools_deb=""
        local temp_deb=""

        ubuntu_version="$(_sqlserver_ubuntu_version)" || {
            sayfail "SQL Server 2025 role supports Ubuntu 22.04 and 24.04 only."
            return 1
        }

        repo_url="https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/mssql-server-2025.list"
        tools_deb="https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb"

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would configure Microsoft SQL Server 2025 repositories for Ubuntu $ubuntu_version."
            return 0
        fi

        sudo apt-get update || return 1
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg || return 1

        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
            gpg --dearmor | sudo tee "$keyring" >/dev/null || return 1

        curl -fsSL "$repo_url" | sudo tee "$engine_list" >/dev/null || return 1

        temp_deb="$(mktemp "${TMPDIR:-/tmp}/packages-microsoft-prod.XXXXXX.deb")" || return 1
        curl -fsSL "$tools_deb" -o "$temp_deb" || {
            rm -f -- "$temp_deb"
            return 1
        }
        sudo dpkg -i "$temp_deb" >/dev/null || {
            rm -f -- "$temp_deb"
            return 1
        }
        rm -f -- "$temp_deb"

        sudo apt-get update || return 1
        sayok "Microsoft SQL Server repositories configured for Ubuntu $ubuntu_version."
    }

    # fn: _sqlserver_step_install_engine - Install Microsoft SQL Server 2025
        # . Returns
        #   0 on success or dry-run; non-zero on package failure.
        #
        # . Usage
        #   _sqlserver_step_install_engine
    _sqlserver_step_install_engine() {
        _sqlserver_ubuntu_version >/dev/null || {
            sayfail "SQL Server 2025 role supports Ubuntu 22.04 and 24.04 only."
            return 1
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Microsoft SQL Server 2025."
            return 0
        fi

        sudo apt-get update || return 1
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y mssql-server || return 1

        [[ -x /opt/mssql/bin/mssql-conf ]] || {
            sayfail "SQL Server package installed but mssql-conf is unavailable."
            return 1
        }

        sayok "Microsoft SQL Server engine installed."
    }

    # fn: _sqlserver_step_configure - Run the canonical SQL Server setup workflow
        # . Behavior
        #   - Runs Microsoft's interactive mssql-conf setup command.
        #   - Allows the operator to select edition and set the sa password.
        #
        # . Returns
        #   Exit status from mssql-conf setup, or 1 when the engine is not installed.
        #
        # . Usage
        #   _sqlserver_step_configure
    _sqlserver_step_configure() {
        [[ -x /opt/mssql/bin/mssql-conf ]] || {
            sayfail "SQL Server is not installed."
            return 1
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would run mssql-conf setup."
            return 0
        fi

        sudo /opt/mssql/bin/mssql-conf setup || return $?
        systemctl is-active --quiet "$SGND_SQLSERVER_SERVICE" || {
            sayfail "$SGND_SQLSERVER_SERVICE is not active after setup."
            return 1
        }

        sayok "Microsoft SQL Server configured and running."
    }

    # fn: _sqlserver_step_install_tools - Install sqlcmd and bcp
        # . Returns
        #   0 on success or dry-run; non-zero on package failure.
        #
        # . Usage
        #   _sqlserver_step_install_tools
    _sqlserver_step_install_tools() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install mssql-tools18 and unixODBC development libraries."
            return 0
        fi

        sudo apt-get update || return 1
        sudo env ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get install -y mssql-tools18 unixodbc-dev || return 1

        _sqlserver_tools_installed || {
            sayfail "mssql-tools18 installed but sqlcmd is unavailable."
            return 1
        }

        sayok "SQL Server command-line tools installed."
    }

    # fn: _sqlserver_prepare - Run the tracked SQL Server preparation sequence
        # . Returns
        #   0 when all preparation steps succeed; otherwise the failing status.
        #
        # . Usage
        #   _sqlserver_prepare
    _sqlserver_prepare() {
        sgnd_console_run_tracked "sql-repo" _sqlserver_step_repository || return $?
        sgnd_console_run_tracked "sql-install" _sqlserver_step_install_engine || return $?
        sgnd_console_run_tracked "sql-configure" _sqlserver_step_configure || return $?
        sgnd_console_run_tracked "sql-tools" _sqlserver_step_install_tools || return $?

        sayok "SQL Server preparation completed successfully."
        return 0
    }

# - Status / validation ------------------------------------------------------------
    # fn: _sqlserver_status - Show Microsoft SQL Server role status
        # . Returns
        #   0 after displaying status.
        #
        # . Usage
        #   _sqlserver_status
    _sqlserver_status() {
        local ubuntu_version="unsupported"
        local package_state="not installed"
        local package_version="-"
        local service_state="unavailable"
        local enabled_state="No"
        local tools_state="not installed"
        local port=1433
        local listener_state="No"

        ubuntu_version="$(_sqlserver_ubuntu_version 2>/dev/null || printf 'unsupported')"

        if _sqlserver_engine_installed; then
            package_state="installed"
            package_version="$(dpkg-query -W -f='${Version}' mssql-server 2>/dev/null || printf '-')"
            service_state="$(systemctl is-active "$SGND_SQLSERVER_SERVICE" 2>/dev/null || true)"
            [[ -n "$service_state" ]] || service_state="inactive"
            systemctl is-enabled --quiet "$SGND_SQLSERVER_SERVICE" 2>/dev/null && enabled_state="Yes"
        fi

        _sqlserver_tools_installed && tools_state="installed"
        port="$(_sqlserver_tcp_port)"
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$" && listener_state="Yes"

        sgnd_print
        sgnd_print_sectionheader "Microsoft SQL Server"
        sgnd_print_labeledvalue --label "Ubuntu" --value "$ubuntu_version" --labelwidth 22
        sgnd_print_labeledvalue --label "SQL Server" --value "$package_state" --labelwidth 22
        sgnd_print_labeledvalue --label "Package version" --value "$package_version" --labelwidth 22
        sgnd_print_labeledvalue --label "Service" --value "$service_state" --labelwidth 22
        sgnd_print_labeledvalue --label "Enabled at boot" --value "$enabled_state" --labelwidth 22
        sgnd_print_labeledvalue --label "TCP port" --value "$port" --labelwidth 22
        sgnd_print_labeledvalue --label "TCP listener" --value "$listener_state" --labelwidth 22
        sgnd_print_labeledvalue --label "sqlcmd tools" --value "$tools_state" --labelwidth 22
    }

    # fn: _sqlserver_validate - Validate the Microsoft SQL Server role
        # . Returns
        #   0 when all required checks pass; 1 otherwise.
        #
        # . Usage
        #   _sqlserver_validate
    _sqlserver_validate() {
        local failures=0
        local result=""
        local port=1433

        sgnd_print
        sgnd_print_sectionheader "Validate Microsoft SQL Server"

        if _sqlserver_ubuntu_version >/dev/null; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Supported Ubuntu" --value "$result" --labelwidth 24

        if _sqlserver_engine_installed && [[ -x /opt/mssql/bin/sqlservr ]]; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Database engine" --value "$result" --labelwidth 24

        if systemctl is-enabled --quiet "$SGND_SQLSERVER_SERVICE" 2>/dev/null; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Enabled at boot" --value "$result" --labelwidth 24

        if systemctl is-active --quiet "$SGND_SQLSERVER_SERVICE" 2>/dev/null; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Service active" --value "$result" --labelwidth 24

        port="$(_sqlserver_tcp_port)"
        if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "TCP listener" --value "$result ($port)" --labelwidth 24

        if _sqlserver_tools_installed; then
            result="Passed"
        else
            result="Warning (optional tools missing)"
        fi
        sgnd_print_labeledvalue --label "sqlcmd tools" --value "$result" --labelwidth 24

        sgnd_print
        if (( failures == 0 )); then
            sayok "SQL Server validation passed."
            return 0
        fi

        sayfail "$failures SQL Server validation check(s) failed."
        return 1
    }

# - Console registration -----------------------------------------------------------
    sgnd_menu_register_group \
        "$SGND_SQLSERVER_MODULE_ID" \
        "$SGND_SQLSERVER_MODULE_NAME" \
        "$SGND_SQLSERVER_MODULE_DESC" \
        0 1 600

    sgnd_menu_register_item "sql-prepare" "$SGND_SQLSERVER_MODULE_ID" "Prepare SQL Server" "_sqlserver_prepare" "Configure repositories, install and configure SQL Server, and install tools" 0 15 1 0
    sgnd_menu_register_item "sql-repo" "$SGND_SQLSERVER_MODULE_ID" "Configure Microsoft repositories" "_sqlserver_step_repository" "Configure SQL Server 2025 and Microsoft package repositories" 0 15 1 1
    sgnd_menu_register_item "sql-install" "$SGND_SQLSERVER_MODULE_ID" "Install SQL Server engine" "_sqlserver_step_install_engine" "Install the Microsoft SQL Server 2025 database engine" 0 15 1 1
    sgnd_menu_register_item "sql-configure" "$SGND_SQLSERVER_MODULE_ID" "Configure SQL Server" "_sqlserver_step_configure" "Run the interactive mssql-conf setup workflow" 0 15 1 1
    sgnd_menu_register_item "sql-tools" "$SGND_SQLSERVER_MODULE_ID" "Install SQL Server tools" "_sqlserver_step_install_tools" "Install sqlcmd, bcp, and unixODBC development libraries" 0 15 1 1
    sgnd_menu_register_item "sql-validate" "$SGND_SQLSERVER_MODULE_ID" "Validate SQL Server" "_sqlserver_validate" "Validate platform, engine, service, listener, and tools" 0 15 1 0
    sgnd_menu_register_item "sql-status" "$SGND_SQLSERVER_MODULE_ID" "Show SQL Server status" "_sqlserver_status" "Show package, service, port, listener, and sqlcmd status" 0 15 1 0

    sayinfo "SQL Server module registered with the console."
