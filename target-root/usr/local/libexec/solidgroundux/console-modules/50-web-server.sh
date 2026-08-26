# ==================================================================================
# SolidGroundUX - Web Server
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623702
#   Source      : 50-web-server.sh
#   Type        : module
#   Group       : SolidGround Console
#   Subgroup    : Console Modules
#   Purpose     : Install, configure, manage, validate, and inspect an Nginx web server
# ==================================================================================
set -uo pipefail

# - Library guard ------------------------------------------------------------------
    # fn: _sgnd_lib_guard - Ensure the module is sourced only once
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
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
    SGND_WEB_SERVER_MODULE_VERSION="1.1.0"
    SGND_WEB_SERVER_MODULE_DESC="Install, configure, manage, validate, and inspect an Nginx web server"

    SGND_MODULE_ID="$SGND_WEB_SERVER_MODULE_ID"
    SGND_MODULE_NAME="$SGND_WEB_SERVER_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_WEB_SERVER_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_WEB_SERVER_MODULE_DESC"

    SGND_WEB_SERVER_CONFIG_FILE="${SGND_SYSCFG_DIR:-/etc/solidgroundux}/web-server.cfg"
    SGND_WEB_SERVER_DEFAULT_STORAGE_ROOT="/srv/storage"

# - Internal helpers ---------------------------------------------------------------
    # fn: _web_server_package_installed - Test whether Nginx is installed
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_package_installed
    _web_server_package_installed() {
        dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -q '^install ok installed$'
    }

    # fn: _web_server_storage_root - Resolve the configured SolidGroundUX storage root
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_storage_root
    _web_server_storage_root() {
        local configured=""
        local storage_cfg="${SGND_SYSCFG_DIR:-/etc/solidgroundux}/storage.cfg"

        if [[ -r "$storage_cfg" ]]; then
            configured="$(awk -F= '$1 == "SGND_STORAGE_MOUNTPOINT" {sub(/^[^=]*=/, ""); print; exit}' "$storage_cfg" 2>/dev/null || true)"
        fi

        [[ -n "$configured" ]] || configured="$SGND_WEB_SERVER_DEFAULT_STORAGE_ROOT"
        printf '%s\n' "$configured"
    }

    # fn: _web_server_root - Resolve the configured web content root
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_root
    _web_server_root() {
        local configured=""

        if [[ -r "$SGND_WEB_SERVER_CONFIG_FILE" ]]; then
            configured="$(awk -F= '$1 == "SGND_WEB_ROOT" {sub(/^[^=]*=/, ""); print; exit}' "$SGND_WEB_SERVER_CONFIG_FILE" 2>/dev/null || true)"
        fi

        [[ -n "$configured" ]] || configured="$(_web_server_storage_root)/www"
        printf '%s\n' "$configured"
    }

    # fn: _web_server_save_root - Persist the configured web content root
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_save_root
    _web_server_save_root() {
        local root="$1"
        local config_dir=""

        config_dir="$(dirname "$SGND_WEB_SERVER_CONFIG_FILE")"
        sudo mkdir -p "$config_dir" || return 1
        printf 'SGND_WEB_ROOT=%s\n' "$root" | sudo tee "$SGND_WEB_SERVER_CONFIG_FILE" >/dev/null || return 1
        sudo chmod 0644 "$SGND_WEB_SERVER_CONFIG_FILE" || return 1
    }

    # fn: _web_server_enabled_sites - List enabled Nginx sites
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_enabled_sites
    _web_server_enabled_sites() {
        local entry=""
        [[ -d /etc/nginx/sites-enabled ]] || return 1
        while IFS= read -r -d '' entry; do
            basename -- "$entry"
        done < <(find /etc/nginx/sites-enabled -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
    }

    # fn: _web_server_available_sites - List available Nginx sites
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_available_sites
    _web_server_available_sites() {
        local entry=""
        [[ -d /etc/nginx/sites-available ]] || return 1
        while IFS= read -r -d '' entry; do
            basename -- "$entry"
        done < <(find /etc/nginx/sites-available -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
    }

    # fn: _web_server_validate_site_name - Validate an Nginx site name
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_validate_site_name
    _web_server_validate_site_name() {
        [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
    }

    # fn: _web_server_ensure_directory - Create and prepare a web content directory when needed
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_ensure_directory
    _web_server_ensure_directory() {
        local path="$1"
        local owner="${2:-www-data:www-data}"
        local decision="YES"

        if [[ ! -d "$path" ]]; then
            ask_decision --label "Directory does not exist. Create it" --choices "YES|Y,NO|N" --default "YES" --var decision
            [[ "$decision" == "YES" ]] || return 1

            if (( ${FLAG_DRYRUN:-0} == 1 )); then
                sayinfo "Dry run: Would create directory $path."
                return 0
            fi
            sudo mkdir -p "$path" || return 1
        fi

        if (( ${FLAG_DRYRUN:-0} == 0 )); then
            sudo chown "$owner" "$path" || return 1
            sudo chmod 0755 "$path" || return 1
        fi
    }

    # fn: _web_server_reload - Validate and reload Nginx
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_reload
    _web_server_reload() {
        sudo nginx -t || return 1
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would reload nginx.service."
            return 0
        fi
        sudo systemctl reload nginx.service || return 1
    }

# - Role preparation ---------------------------------------------------------------
    # fn: _web_server_step_install_packages - Install Nginx and publishing prerequisites
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_step_install_packages
    _web_server_step_install_packages() {
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would install Nginx web-server prerequisites."
            return 0
        fi

        sudo apt-get update || return 1
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl rsync || return 1
        command -v nginx >/dev/null 2>&1 || {
            sayfail "Nginx was installed but the nginx command is unavailable."
            return 1
        }
        sayok "Nginx web-server prerequisites installed."
    }

    # fn: _web_server_step_start - Enable and start Nginx
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_step_start
    _web_server_step_start() {
        command -v nginx >/dev/null 2>&1 || { sayfail "Nginx is not installed."; return 1; }
        sudo nginx -t >/dev/null 2>&1 || { sayfail "Nginx configuration validation failed."; return 1; }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would enable and start nginx.service."
            return 0
        fi

        sudo systemctl enable --now nginx.service || return 1
        systemctl is-active --quiet nginx.service || { sayfail "nginx.service is not active."; return 1; }
        sayok "Nginx web server is active."
    }

    # fn: _web_server_prepare - Run the tracked web-server preparation workflow
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_prepare
    _web_server_prepare() {
        sgnd_console_run_tracked "web-install" _web_server_step_install_packages || return $?
        sgnd_console_run_tracked "web-start" _web_server_step_start || return $?
        sayok "Web-server preparation completed successfully."
    }

# - Configuration ------------------------------------------------------------------
    # fn: _web_server_configure_root - Select or create the web content root
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_configure_root
    _web_server_configure_root() {
        local storage_root=""
        local current_root=""
        local selected=""
        local manual=""
        local -a options=()
        local path=""

        storage_root="$(_web_server_storage_root)"
        current_root="$(_web_server_root)"
        options+=("$current_root")

        if [[ -d "$storage_root" ]]; then
            while IFS= read -r path; do
                [[ -n "$path" && "$path" != "$current_root" ]] && options+=("$path")
            done < <(find "$storage_root" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | sort)
        fi
        options+=("Enter path manually")

        ask_selection --label "Select web content root" --var selected --items "${options[@]}" || return 0
        if [[ "$selected" == "Enter path manually" ]]; then
            ask --label "Web content root" --var manual --default "$current_root" || return 0
            selected="$manual"
        fi

        [[ "$selected" == /* ]] || selected="$storage_root/$selected"
        _web_server_ensure_directory "$selected" "www-data:www-data" || return 1

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would configure web content root as $selected."
            return 0
        fi

        _web_server_save_root "$selected" || return 1
        sayok "Web content root configured: $selected"
    }

    # fn: _web_server_manage_service - Manage nginx.service state and startup behavior
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_manage_service
    _web_server_manage_service() {
        local action=""
        ask_selection --label "Web service action" --var action --items "Start" "Stop" "Restart" "Enable at boot" "Disable at boot" || return 0

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would perform web service action: $action."
            return 0
        fi

        case "$action" in
            Start) sudo systemctl start nginx.service ;;
            Stop) sudo systemctl stop nginx.service ;;
            Restart) sudo nginx -t && sudo systemctl restart nginx.service ;;
            "Enable at boot") sudo systemctl enable nginx.service ;;
            "Disable at boot") sudo systemctl disable nginx.service ;;
        esac
    }

    # fn: _web_server_configure_firewall - Allow HTTP and HTTPS through UFW
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_configure_firewall
    _web_server_configure_firewall() {
        command -v ufw >/dev/null 2>&1 || { saywarning "UFW is not installed."; return 0; }
        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would allow the Nginx Full firewall profile."
            return 0
        fi
        sudo ufw allow 'Nginx Full' || return 1
        sayok "HTTP and HTTPS allowed through UFW."
    }

# - Site management ----------------------------------------------------------------
    # fn: _web_server_create_site - Create and enable an Nginx site
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_create_site
    _web_server_create_site() {
        local site_name=""
        local server_name=""
        local document_root=""
        local web_root=""
        local config_file=""

        _web_server_package_installed || { sayfail "Nginx is not installed."; return 1; }
        web_root="$(_web_server_root)"

        ask --label "Site name" --var site_name --validate _web_server_validate_site_name --back || return 0
        ask --label "Server name" --var server_name --default "$site_name" --back || return 0
        ask --label "Document root" --var document_root --default "$web_root/$site_name" --back || return 0
        [[ "$document_root" == /* ]] || document_root="$web_root/$document_root"
        config_file="/etc/nginx/sites-available/$site_name"

        [[ ! -e "$config_file" ]] || { sayfail "Site configuration already exists: $site_name"; return 1; }
        _web_server_ensure_directory "$document_root" "www-data:www-data" || return 1

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would create Nginx site $site_name using $document_root."
            return 0
        fi

        sudo tee "$config_file" >/dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $server_name;
    root $document_root;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        sudo ln -s "$config_file" "/etc/nginx/sites-enabled/$site_name" || return 1
        _web_server_reload || {
            sudo rm -f "/etc/nginx/sites-enabled/$site_name"
            sudo rm -f "$config_file"
            return 1
        }
        sayok "Nginx site created and enabled: $site_name"
    }

    # fn: _web_server_enable_site - Enable an available Nginx site
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_enable_site
    _web_server_enable_site() {
        local site=""
        local -a sites=()
        mapfile -t sites < <(_web_server_available_sites 2>/dev/null || true)
        (( ${#sites[@]} > 0 )) || { saywarning "No Nginx sites are available."; return 0; }
        ask_selection --label "Enable Nginx site" --var site --items "${sites[@]}" || return 0
        [[ -e "/etc/nginx/sites-enabled/$site" ]] && { sayok "Site is already enabled: $site"; return 0; }
        if (( ${FLAG_DRYRUN:-0} == 1 )); then sayinfo "Dry run: Would enable $site."; return 0; fi
        sudo ln -s "/etc/nginx/sites-available/$site" "/etc/nginx/sites-enabled/$site" || return 1
        _web_server_reload || return 1
        sayok "Site enabled: $site"
    }

    # fn: _web_server_disable_site - Disable an enabled Nginx site
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_disable_site
    _web_server_disable_site() {
        local site=""
        local -a sites=()
        mapfile -t sites < <(_web_server_enabled_sites 2>/dev/null || true)
        (( ${#sites[@]} > 0 )) || { saywarning "No enabled Nginx sites found."; return 0; }
        ask_selection --label "Disable Nginx site" --var site --items "${sites[@]}" || return 0
        if (( ${FLAG_DRYRUN:-0} == 1 )); then sayinfo "Dry run: Would disable $site."; return 0; fi
        sudo rm -f "/etc/nginx/sites-enabled/$site" || return 1
        _web_server_reload || return 1
        sayok "Site disabled: $site"
    }

    # fn: _web_server_remove_site - Remove an Nginx site configuration
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_remove_site
    _web_server_remove_site() {
        local site=""
        local decision="NO"
        local -a sites=()
        mapfile -t sites < <(_web_server_available_sites 2>/dev/null || true)
        (( ${#sites[@]} > 0 )) || { saywarning "No Nginx sites are available."; return 0; }
        ask_selection --label "Remove Nginx site configuration" --var site --items "${sites[@]}" || return 0
        ask_decision --label "Remove site configuration '$site'" --choices "YES|Y,NO|N" --default "NO" --var decision
        [[ "$decision" == "YES" ]] || return 0
        if (( ${FLAG_DRYRUN:-0} == 1 )); then sayinfo "Dry run: Would remove site configuration $site."; return 0; fi
        sudo rm -f "/etc/nginx/sites-enabled/$site" "/etc/nginx/sites-available/$site" || return 1
        _web_server_reload || return 1
        sayok "Site configuration removed: $site"
        sayinfo "Document content was left untouched."
    }

    # fn: _web_server_list_sites - List Nginx sites and document roots
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_list_sites
    _web_server_list_sites() {
        local -a sites=()
        local site=""
        local state=""
        local root=""

        _web_server_package_installed || { sayfail "Nginx is not installed."; return 1; }
        mapfile -t sites < <(_web_server_available_sites 2>/dev/null || true)

        sgnd_print
        sgnd_print_sectionheader "Nginx sites"
        if (( ${#sites[@]} == 0 )); then
            sgnd_print_labeledvalue --label "Sites" --value "None" --labelwidth 20
            return 0
        fi

        for site in "${sites[@]}"; do
            state="Disabled"
            [[ -e "/etc/nginx/sites-enabled/$site" ]] && state="Enabled"
            root="$(awk '$1 == "root" {gsub(/;/, "", $2); print $2; exit}' "/etc/nginx/sites-available/$site" 2>/dev/null || true)"
            sgnd_print_labeledvalue --label "$site" --value "$state${root:+ - $root}" --labelwidth 24
        done
    }

    # fn: _web_server_manage_sites - Open the site-management workflow
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_manage_sites
    _web_server_manage_sites() {
        local action=""
        ask_selection --label "Site management" --var action --items "Create site" "Enable site" "Disable site" "Remove site" "List sites" || return 0
        case "$action" in
            "Create site") _web_server_create_site ;;
            "Enable site") _web_server_enable_site ;;
            "Disable site") _web_server_disable_site ;;
            "Remove site") _web_server_remove_site ;;
            "List sites") _web_server_list_sites ;;
        esac
    }

    # fn: _web_server_publish_site - Publish a directory into a site document root
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_publish_site
    _web_server_publish_site() {
        local site=""
        local source_dir=""
        local document_root=""
        local decision="YES"
        local -a sites=()

        command -v rsync >/dev/null 2>&1 || { sayfail "rsync is required for publishing."; return 1; }
        mapfile -t sites < <(_web_server_available_sites 2>/dev/null || true)
        (( ${#sites[@]} > 0 )) || { saywarning "No Nginx sites are available."; return 0; }
        ask_selection --label "Publish to site" --var site --items "${sites[@]}" || return 0
        ask --label "Source directory" --var source_dir --back || return 0
        [[ -d "$source_dir" ]] || { sayfail "Source directory does not exist: $source_dir"; return 1; }

        document_root="$(awk '$1 == "root" {gsub(/;/, "", $2); print $2; exit}' "/etc/nginx/sites-available/$site" 2>/dev/null || true)"
        [[ -n "$document_root" ]] || { sayfail "Could not determine document root for $site."; return 1; }
        _web_server_ensure_directory "$document_root" "www-data:www-data" || return 1
        ask_decision --label "Synchronize source into $document_root" --choices "YES|Y,NO|N" --default "YES" --var decision
        [[ "$decision" == "YES" ]] || return 0

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would synchronize $source_dir/ to $document_root/."
            return 0
        fi

        sudo rsync -a --delete "$source_dir/" "$document_root/" || return 1
        sudo chown -R www-data:www-data "$document_root" || return 1
        sayok "Published $source_dir to $site."
    }

# - Status / validation ------------------------------------------------------------
    # fn: _web_server_status - Show web-server status and configuration
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
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
        local web_root=""
        local site_count=0
        local -a sites=()

        web_root="$(_web_server_root)"
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
        sgnd_print_labeledvalue --label "Web content root" --value "$web_root" --labelwidth 22
        sgnd_print_labeledvalue --label "HTTP listener" --value "$http_listener" --labelwidth 22
        sgnd_print_labeledvalue --label "HTTPS listener" --value "$https_listener" --labelwidth 22
        sgnd_print_labeledvalue --label "Enabled sites" --value "$site_count" --labelwidth 22
    }

    # fn: _web_server_validate - Validate the web-server role
        # . Returns
        #   0 on success; non-zero when the operation cannot be completed.
        # . Usage
        #   _web_server_validate
    _web_server_validate() {
        local failures=0
        local result=""
        local web_root=""

        web_root="$(_web_server_root)"
        sgnd_print
        sgnd_print_sectionheader "Validate Web Server"

        if _web_server_package_installed && command -v nginx >/dev/null 2>&1; then result="Passed"; else result="Failed"; failures=$((failures + 1)); fi
        sgnd_print_labeledvalue --label "Nginx package" --value "$result" --labelwidth 24

        if command -v nginx >/dev/null 2>&1 && sudo nginx -t >/dev/null 2>&1; then result="Passed"; else result="Failed"; failures=$((failures + 1)); fi
        sgnd_print_labeledvalue --label "Configuration" --value "$result" --labelwidth 24

        if systemctl is-enabled --quiet nginx.service 2>/dev/null; then result="Passed"; else result="Failed"; failures=$((failures + 1)); fi
        sgnd_print_labeledvalue --label "Enabled at boot" --value "$result" --labelwidth 24

        if systemctl is-active --quiet nginx.service 2>/dev/null; then result="Passed"; else result="Failed"; failures=$((failures + 1)); fi
        sgnd_print_labeledvalue --label "Service active" --value "$result" --labelwidth 24

        if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)80$|(^|:)443$'; then result="Passed"; else result="Failed"; failures=$((failures + 1)); fi
        sgnd_print_labeledvalue --label "HTTP/HTTPS listener" --value "$result" --labelwidth 24

        if [[ -d "$web_root" && -x "$web_root" ]]; then result="Passed ($web_root)"; else result="Failed ($web_root)"; failures=$((failures + 1)); fi
        sgnd_print_labeledvalue --label "Web content root" --value "$result" --labelwidth 24

        sgnd_print
        if (( failures == 0 )); then sayok "Web-server validation passed."; return 0; fi
        sayfail "$failures web-server validation check(s) failed."
        return 1
    }

# - Console registration -----------------------------------------------------------
    # Provides basic Nginx host management: installation, content-root selection,
    # site lifecycle, publishing, service and firewall control, status, and
    # validation. Application-specific site administration remains out of scope.
    #
    # . Menu items
    # ! Prepare web server
    #   > Install, validate, enable, and start Nginx.
    #   > Handler: _web_server_prepare
    #
    # ! Install Nginx
    #   > Install Nginx and basic web-server utilities.
    #   > Handler: _web_server_step_install_packages
    #
    # ! Configure web content root
    #   > Select or create the storage location used for web content.
    #   > Handler: _web_server_configure_root
    #
    # ! Manage sites
    #   > Create, enable, disable, remove, and list Nginx sites.
    #   > Handler: _web_server_manage_sites
    #
    # ! Publish site content
    #   > Synchronize a source directory into a site's document root.
    #   > Handler: _web_server_publish_site
    #
    # ! Manage web service
    #   > Start, stop, restart, enable, or disable nginx.service.
    #   > Handler: _web_server_manage_service
    #
    # ! Configure web firewall
    #   > Allow HTTP and HTTPS through UFW.
    #   > Handler: _web_server_configure_firewall
    #
    # ! Validate web server
    #   > Validate package, configuration, service, listeners, and web root.
    #   > Handler: _web_server_validate
    #
    # ! Show web-server status
    #   > Show package, service, storage, listener, and site status.
    #   > Handler: _web_server_status
    sgnd_menu_register_group \
        "$SGND_WEB_SERVER_MODULE_ID" \
        "$SGND_WEB_SERVER_MODULE_NAME" \
        "$SGND_WEB_SERVER_MODULE_DESC" \
        0 1 500

    sgnd_menu_register_item "web-prepare" "$SGND_WEB_SERVER_MODULE_ID" "Prepare web server" "_web_server_prepare" "Install, validate, enable, and start Nginx" 0 15 1 0
    sgnd_menu_register_item "web-install" "$SGND_WEB_SERVER_MODULE_ID" "Install Nginx" "_web_server_step_install_packages" "Install Nginx and basic web-server utilities" 0 15 1 1
    sgnd_menu_register_item "web-root" "$SGND_WEB_SERVER_MODULE_ID" "Configure web content root" "_web_server_configure_root" "Select or create the storage location used for web content" 0 15 1 0
    sgnd_menu_register_item "web-sites" "$SGND_WEB_SERVER_MODULE_ID" "Manage sites" "_web_server_manage_sites" "Create, enable, disable, remove, and list Nginx sites" 0 15 1 0
    sgnd_menu_register_item "web-publish" "$SGND_WEB_SERVER_MODULE_ID" "Publish site content" "_web_server_publish_site" "Synchronize a source directory into a site's document root" 0 15 1 0
    sgnd_menu_register_item "web-service" "$SGND_WEB_SERVER_MODULE_ID" "Manage web service" "_web_server_manage_service" "Start, stop, restart, enable, or disable nginx.service" 0 15 1 0
    sgnd_menu_register_item "web-firewall" "$SGND_WEB_SERVER_MODULE_ID" "Configure web firewall" "_web_server_configure_firewall" "Allow HTTP and HTTPS through UFW" 0 15 1 0
    sgnd_menu_register_item "web-validate" "$SGND_WEB_SERVER_MODULE_ID" "Validate web server" "_web_server_validate" "Validate package, configuration, service, listeners, and web root" 0 15 1 0
    sgnd_menu_register_item "web-status" "$SGND_WEB_SERVER_MODULE_ID" "Show web-server status" "_web_server_status" "Show package, service, storage, listener, and site status" 0 15 1 0

    sayinfo "Web Server module registered with the console."
#   Checksum : dcafabda3ecc9f30f9b35336bc546a8c9eb3fc390a597f0e6561ef27ce583759
