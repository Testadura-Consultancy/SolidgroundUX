# ==================================================================================
# SolidGroundUX - Web Server
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : 750fdb47a3c8a374051dee1ead4bfc97f757935bab69dfeef69a2625462c05a6
#   Source      : 50-web-server.sh
#   Type        : module
#   Group       : SolidGround Console
#   Subgroup    : Console Modules
#   Purpose     : Install, prepare, validate, and inspect an Nginx web server
#
# Description:
#   Provides a lightweight web-server role built around the distribution Nginx
#   package. The module prepares the service, validates the active configuration,
#   reports listener/site state, and leaves application/site deployment to the
#   applications that own that content.
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
    SGND_WEB_SERVER_MODULE_ID="web-server"
    SGND_WEB_SERVER_MODULE_NAME="Web Server"
    SGND_WEB_SERVER_MODULE_VERSION="1.0.0"
    SGND_WEB_SERVER_MODULE_DESC="Install, prepare, validate, and inspect an Nginx web server"

    SGND_MODULE_ID="$SGND_WEB_SERVER_MODULE_ID"
    SGND_MODULE_NAME="$SGND_WEB_SERVER_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_WEB_SERVER_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_WEB_SERVER_MODULE_DESC"

# - Internal helpers ---------------------------------------------------------------
    # fn$ _web_server_package_installed
        # . Purpose
        #   Test whether the Nginx package is installed.
        #
        # . Returns
        #   0 when nginx is installed; 1 otherwise.
        #
        # . Usage
        #   _web_server_package_installed
    _web_server_package_installed() {
        dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -q '^install ok installed$'
    }

    # fn$ _web_server_enabled_sites
        # . Purpose
        #   List enabled Nginx site configuration names.
        #
        # . Output
        #   Writes one enabled site name per line.
        #
        # . Returns
        #   0 after listing; 1 when the sites-enabled directory is unavailable.
        #
        # . Usage
        #   mapfile -t sites < <(_web_server_enabled_sites)
    _web_server_enabled_sites() {
        local entry=""

        [[ -d /etc/nginx/sites-enabled ]] || return 1

        while IFS= read -r -d '' entry; do
            basename -- "$entry"
        done < <(find /etc/nginx/sites-enabled -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
    }

# - Role preparation ---------------------------------------------------------------
    # fn: _web_server_step_install_packages - Install Nginx
        # . Returns
        #   0 on success or dry-run; non-zero on package failure.
        #
        # . Usage
        #   _web_server_step_install_packages
    _web_server_step_install_packages() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Nginx web-server prerequisites."
            return 0
        fi

        sudo apt-get update || return 1
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl || return 1

        command -v nginx >/dev/null 2>&1 || {
            sayfail "Nginx was installed but the nginx command is unavailable."
            return 1
        }

        sayok "Nginx web-server prerequisites installed."
    }

    # fn: _web_server_step_start - Enable and start Nginx
        # . Returns
        #   0 when nginx.service is active; non-zero otherwise.
        #
        # . Usage
        #   _web_server_step_start
    _web_server_step_start() {
        command -v nginx >/dev/null 2>&1 || {
            sayfail "Nginx is not installed."
            return 1
        }

        sudo nginx -t >/dev/null 2>&1 || {
            sayfail "Nginx configuration validation failed."
            return 1
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would enable and start nginx.service."
            return 0
        fi

        sudo systemctl enable --now nginx.service || return 1
        systemctl is-active --quiet nginx.service || {
            sayfail "nginx.service is not active."
            return 1
        }

        sayok "Nginx web server is active."
    }

    # fn: _web_server_prepare - Run the tracked web-server preparation sequence
        # . Returns
        #   0 when all preparation steps succeed; otherwise the failing status.
        #
        # . Usage
        #   _web_server_prepare
    _web_server_prepare() {
        sgnd_console_run_tracked "web-install" _web_server_step_install_packages || return $?
        sgnd_console_run_tracked "web-start" _web_server_step_start || return $?

        sayok "Web-server preparation completed successfully."
        return 0
    }

# - Status / validation ------------------------------------------------------------
    # fn: _web_server_list_sites - List enabled Nginx sites
        # . Returns
        #   0 after listing sites; 1 when Nginx is unavailable.
        #
        # . Usage
        #   _web_server_list_sites
    _web_server_list_sites() {
        local -a sites=()

        _web_server_package_installed || {
            sayfail "Nginx is not installed."
            return 1
        }

        mapfile -t sites < <(_web_server_enabled_sites 2>/dev/null || true)

        sgnd_print
        sgnd_print_sectionheader "Enabled Nginx sites"

        if (( ${#sites[@]} == 0 )); then
            sgnd_print_labeledvalue --label "Sites" --value "None" --labelwidth 20
            return 0
        fi

        sgnd_print_labeledmultivalue \
            --label "Sites" \
            --labelwidth 20 \
            --items "${sites[@]}"
    }

    # fn: _web_server_status - Show Nginx role status
        # . Returns
        #   0 after displaying status.
        #
        # . Usage
        #   _web_server_status
    _web_server_status() {
        local package_state="not installed"
        local package_version="-"
        local service_state="unavailable"
        local enabled_state="No"
        local config_state="unavailable"
        local http_listener="No"
        local https_listener="No"
        local site_count=0
        local -a sites=()

        if _web_server_package_installed; then
            package_state="installed"
            package_version="$(dpkg-query -W -f='${Version}' nginx 2>/dev/null || printf '-')"
            service_state="$(systemctl is-active nginx.service 2>/dev/null || true)"
            [[ -n "$service_state" ]] || service_state="inactive"
            systemctl is-enabled --quiet nginx.service 2>/dev/null && enabled_state="Yes"
            sudo nginx -t >/dev/null 2>&1 && config_state="valid" || config_state="invalid"
        fi

        ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)80$' && http_listener="Yes"
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)443$' && https_listener="Yes"

        mapfile -t sites < <(_web_server_enabled_sites 2>/dev/null || true)
        site_count="${#sites[@]}"

        sgnd_print
        sgnd_print_sectionheader "Web Server"
        sgnd_print_labeledvalue --label "Package" --value "$package_state" --labelwidth 22
        sgnd_print_labeledvalue --label "Version" --value "$package_version" --labelwidth 22
        sgnd_print_labeledvalue --label "Service" --value "$service_state" --labelwidth 22
        sgnd_print_labeledvalue --label "Enabled at boot" --value "$enabled_state" --labelwidth 22
        sgnd_print_labeledvalue --label "Configuration" --value "$config_state" --labelwidth 22
        sgnd_print_labeledvalue --label "HTTP listener" --value "$http_listener" --labelwidth 22
        sgnd_print_labeledvalue --label "HTTPS listener" --value "$https_listener" --labelwidth 22
        sgnd_print_labeledvalue --label "Enabled sites" --value "$site_count" --labelwidth 22
    }

    # fn: _web_server_validate - Validate the Nginx web-server role
        # . Returns
        #   0 when all required checks pass; 1 otherwise.
        #
        # . Usage
        #   _web_server_validate
    _web_server_validate() {
        local failures=0
        local result=""

        sgnd_print
        sgnd_print_sectionheader "Validate Web Server"

        if _web_server_package_installed && command -v nginx >/dev/null 2>&1; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Nginx package" --value "$result" --labelwidth 24

        if command -v nginx >/dev/null 2>&1 && sudo nginx -t >/dev/null 2>&1; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Configuration" --value "$result" --labelwidth 24

        if systemctl is-enabled --quiet nginx.service 2>/dev/null; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Enabled at boot" --value "$result" --labelwidth 24

        if systemctl is-active --quiet nginx.service 2>/dev/null; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "Service active" --value "$result" --labelwidth 24

        if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)80$|(^|:)443$'; then
            result="Passed"
        else
            result="Failed"
            failures=$((failures + 1))
        fi
        sgnd_print_labeledvalue --label "HTTP/HTTPS listener" --value "$result" --labelwidth 24

        sgnd_print
        if (( failures == 0 )); then
            sayok "Web-server validation passed."
            return 0
        fi

        sayfail "$failures web-server validation check(s) failed."
        return 1
    }

# - Console registration -----------------------------------------------------------
    sgnd_menu_register_group \
        "$SGND_WEB_SERVER_MODULE_ID" \
        "$SGND_WEB_SERVER_MODULE_NAME" \
        "$SGND_WEB_SERVER_MODULE_DESC" \
        0 1 500

    sgnd_menu_register_item "web-prepare" "$SGND_WEB_SERVER_MODULE_ID" "Prepare web server" "_web_server_prepare" "Install, validate, enable, and start Nginx" 0 15 1 0
    sgnd_menu_register_item "web-install" "$SGND_WEB_SERVER_MODULE_ID" "Install Nginx" "_web_server_step_install_packages" "Install Nginx and basic web-server utilities" 0 15 1 1
    sgnd_menu_register_item "web-start" "$SGND_WEB_SERVER_MODULE_ID" "Start web server" "_web_server_step_start" "Validate configuration and enable/start nginx.service" 0 15 1 1
    sgnd_menu_register_item "web-validate" "$SGND_WEB_SERVER_MODULE_ID" "Validate web server" "_web_server_validate" "Validate package, configuration, service, and listeners" 0 15 1 0
    sgnd_menu_register_item "web-status" "$SGND_WEB_SERVER_MODULE_ID" "Show web-server status" "_web_server_status" "Show package, service, listener, and site status" 0 15 1 0
    sgnd_menu_register_item "web-sites" "$SGND_WEB_SERVER_MODULE_ID" "List enabled sites" "_web_server_list_sites" "List Nginx site configurations enabled on this host" 0 15 1 0

    sayinfo "Web Server module registered with the console."
