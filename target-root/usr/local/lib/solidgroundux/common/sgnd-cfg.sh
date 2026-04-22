# =====================================================================================
# SolidgroundUX - Configuration Management
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : 9caaefc2f13eb7acf0f9168a51c38e0a481aa9e1dee10dde1471cffa876d9fec
#   Source      : sgnd-cfg.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Load, manage, and persist configuration settings
#
# Description:
#   Provides configuration handling for the SolidgroundUX framework.
#
#   The library:
#     - Loads configuration from system and user locations
#     - Resolves effective configuration using precedence rules
#     - Supports reading and writing key-value configuration files
#     - Ensures required configuration values are present
#     - Provides helper functions for accessing configuration values
#     - Integrates with bootstrap and runtime state handling
#
# Design principles:
#   - Clear separation between system-level and user-level configuration
#   - Deterministic resolution of configuration values
#   - Minimal and transparent configuration format
#   - Safe defaults with optional overrides
#
# Role in framework:
#   - Central configuration layer used during bootstrap and runtime
#   - Supplies paths, settings, and environment-specific values
#   - Supports scripts and modules requiring persistent configuration
#
# Non-goals:
#   - Complex hierarchical configuration systems
#   - External configuration formats (JSON, YAML, etc.)
#   - Runtime hot-reloading of configuration
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
    # tmp: _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Behavior:
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

# --- Internal: file and value manipulation -------------------------------------------
    # fn: _sgnd_is_ident
        # Purpose:
        #   Test whether a string is a valid shell identifier.
        #
        # Behavior:
        #   - Validates the input against shell variable naming rules.
        #   - Accepts names starting with a letter or underscore.
        #   - Allows alphanumeric characters and underscores thereafter.
        #
        # Arguments:
        #   $1  NAME
        #       Candidate identifier.
        #
        # Returns:
        #   0 if NAME is a valid identifier.
        #   1 otherwise.
        #
        # Usage:
        #   _sgnd_is_ident NAME
        #
        # Examples:
        #   if _sgnd_is_ident "APP_TITLE"; then
        #       printf 'valid\n'
        #   fi
    _sgnd_is_ident() {
            [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
    }
   
    # fn: _sgnd_kv_load_file
        # Purpose:
        #   Load KEY=VALUE pairs from a file into shell variables.
        #
        # Behavior:
        #   - Reads plain KEY=VALUE lines from the target file.
        #   - Ignores blank lines and comment lines.
        #   - Validates keys as shell identifiers.
        #   - Assigns values literally without unquoting or escape processing.
        #
        # Arguments:
        #   $1  FILE
        #       Path to the KEY=VALUE file.
        #
        # Outputs (globals):
        #   Sets variables defined in the file.
        #
        # Side effects:
        #   - May emit warnings for invalid keys.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_kv_load_file FILE
        #
        # Examples:
        #   _sgnd_kv_load_file "$SGND_CFG_FILE"
        #
        #   [[ -r "$file" ]] && _sgnd_kv_load_file "$file"
    _sgnd_kv_load_file() {
        local file="$1"
        [[ -f "$file" ]] || return 0

        local line key val
        while IFS= read -r line || [[ -n "$line" ]]; do
            # strip leading/trailing whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"

            # skip blanks / comments
            [[ -z "$line" ]] && continue
            [[ "$line" == \#* ]] && continue

            # accept KEY=VALUE only
            [[ "$line" == *"="* ]] || continue

            key="${line%%=*}"
            val="${line#*=}"

            # trim whitespace around key only
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"

            # validate key name
            if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                continue
            fi

            # If value starts with a space, keep it; we store exactly after '='.
            printf -v "$key" '%s' "$val"
        done < "$file"
    }

    # fn: _sgnd_kv_set
        # Purpose:
        #   Write or update a KEY=VALUE entry in a file.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Replaces an existing KEY=VALUE entry when present.
        #   - Appends a new entry when the key does not exist.
        #   - Preserves the rest of the file content.
        #
        # Arguments:
        #   $1  FILE
        #       Path to the KEY=VALUE file.
        #   $2  KEY
        #       Key to write.
        #   $3  VALUE
        #       Value to assign.
        #
        # Side effects:
        #   - Modifies the target file.
        #   - May emit warnings for invalid keys.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid key or write failure.
        #
        # Usage:
        #   _sgnd_kv_set FILE KEY VALUE
        #
        # Examples:
        #   _sgnd_kv_set "$SGND_CFG_FILE" "APP_TITLE" "SolidGround"
        #
        #   _sgnd_kv_set "$SGND_STATE_FILE" "CURRENT_PAGE" "2"
    _sgnd_kv_set() {
        local file="$1" key="$2" val="$3"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1

        local dir
        dir="$(dirname -- "$file")" || return 1

        # Decide who should own the file
        local uid gid
        if [[ ${EUID:-0} -eq 0 && -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
            uid="$SUDO_UID"
            gid="$SUDO_GID"
        else
            uid="$(id -u)"
            gid="$(id -g)"
        fi

        # Ensure directory exists (state dir should typically be private)
        mkdir -p -- "$dir" || return 1

        local tmp
        tmp="$(mktemp)" || return 1

        if [[ -f "$file" ]]; then
            grep -v -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" > "$tmp" || true
        fi

        printf "%s=%s\n" "$key" "$val" >> "$tmp" || { rm -f -- "$tmp"; return 1; }

        if [[ ${EUID:-0} -eq 0 && -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
            # Create final file with correct owner/group/mode immediately
            install -o "$uid" -g "$gid" -m 600 -T -- "$tmp" "$file" || { rm -f -- "$tmp"; return 1; }
            # Also ensure directory is owned by the user (optional but usually desired)
            chown "$uid:$gid" -- "$dir" || true
            chmod 700 -- "$dir" || true
        else
            # Normal user path
            install -m 600 -T -- "$tmp" "$file" || { rm -f -- "$tmp"; return 1; }
            chmod 700 -- "$dir" || true
        fi

        rm -f -- "$tmp"
        return 0
    }

    # fn: _sgnd_kv_unset
        # Purpose:
        #   Remove a KEY=VALUE entry from a file.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Removes matching KEY=VALUE lines from the file.
        #   - Leaves the rest of the file unchanged.
        #
        # Arguments:
        #   $1  FILE
        #       Path to the KEY=VALUE file.
        #   $2  KEY
        #       Key to remove.
        #
        # Side effects:
        #   - Modifies the target file.
        #   - May emit warnings for invalid keys.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid key or write failure.
        #
        # Usage:
        #   _sgnd_kv_unset FILE KEY
        #
        # Examples:
        #   _sgnd_kv_unset "$SGND_CFG_FILE" "APP_TITLE"
        #
        #   _sgnd_kv_unset "$SGND_STATE_FILE" "CURRENT_PAGE"
    _sgnd_kv_unset() {
        local file="$1" key="$2"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
        [[ -f "$file" ]] || return 0

        local tmp
        tmp="$(mktemp)"
        grep -v -E "^[[:space:]]*${key}[[:space:]]*=" "$file" > "$tmp" || true

        # If file becomes empty (or only whitespace/comments were removed earlier), keep it simple:
        if [[ ! -s "$tmp" ]]; then
            rm -f "$tmp"
            rm -f "$file"
            return 0
        fi

        cat -- "$tmp" > "$file"
        rm -f -- "$tmp"
    }

    # fn: _sgnd_kv_reset_file
        # Purpose:
        #   Hard-delete a KEY=VALUE file.
        #
        # Arguments:
        #   $1  File path.
        #
        # Side effects:
        #   Removes the file if present.
        #
        # Returns:
        #   0 always (rm -f semantics).
    _sgnd_kv_reset_file() {
        local file="$1"
        rm -f "$file"
    }

    # fn: _sgnd_kv_get
        # Purpose:
        #   Read a value for a key from a KEY=VALUE file.
        #
        # Behavior:
        #   - Searches the file for a matching KEY=VALUE entry.
        #   - Returns the last matching occurrence when duplicates exist.
        #   - Does not read from the current shell variable.
        #
        # Arguments:
        #   $1  FILE
        #       Path to the KEY=VALUE file.
        #   $2  KEY
        #       Key to retrieve.
        #
        # Output:
        #   Prints the value to stdout without a trailing newline.
        #
        # Returns:
        #   0 if the key is found.
        #   1 if the key is not present.
        #
        # Usage:
        #   _sgnd_kv_get FILE KEY
        #
        # Examples:
        #   value="$(_sgnd_kv_get "$SGND_CFG_FILE" "APP_TITLE")" || value=""
        #
        #   _sgnd_kv_get "$SGND_STATE_FILE" "CURRENT_PAGE"
    _sgnd_kv_get() {
        local file="$1" key="$2"

        [[ -n "$file" && -n "$key" ]] || return 2
        _sgnd_is_ident "$key"        || return 2
        [[ -r "$file" ]]            || return 2

        local line
        line="$(grep -m1 -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" 2>/dev/null)" || true
        [[ -n "$line" ]] || return 1

        printf '%s' "${line#*=}"
        return 0
    }

    # fn: _sgnd_kv_has
        # Purpose:
        #   Test whether a KEY exists in a KEY=VALUE file (even if empty).
        #
        # Arguments:
        #   $1  File path.
        #   $2  Key (must be a valid identifier).
        #
        # Returns:
        #   0 if present,
        #   1 if not present,
        #   2 on argument/read error.
    _sgnd_kv_has() {
        local file="$1" key="$2"

        [[ -n "$file" && -n "$key" ]] || return 2
        _sgnd_is_ident "$key" || return 2
        [[ -r "$file" ]] || return 2

        grep -q -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" 2>/dev/null
    }

    # fn: _sgnd_kv_list_keys
        # Purpose:
        #   Emit file contents as 'key|value' lines (order preserved).
        #
        # Arguments:
        #   $1  File path.
        #
        # Output:
        #   Prints one line per KEY=VALUE entry as: key|value
        #
        # Returns:
        #   0 on success; non-zero if file is unreadable.
        #
        # Notes:
        #   - Intended for display/debug; not a stable interchange format.
    _sgnd_kv_list_keys() {
        local file="$1"
        [[ -r "$file" ]] || return 1

        local line key val

        while IFS= read -r line || [[ -n "$line" ]]; do
            # skip blanks and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            # split on first '=' only
            key="${line%%=*}"
            val="${line#*=}"

            # trim surrounding whitespace from key
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"

            # basic identifier sanity (optional but recommended)
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

            printf '%s|%s\n' "$key" "$val"
        done < "$file"
    }

# --- Public API: Config management ---------------------------------------------------
    # fn: sgnd_cfg_load
        # Purpose:
        #   Load a config file into shell variables.
        #
        # Behavior:
        #   - Loads KEY=VALUE pairs from the selected config file.
        #   - Ignores missing files.
        #   - Accepts only valid shell identifiers as keys.
        #
        # Arguments:
        #   $1  FILE
        #       Optional config file path.
        #       Defaults to SGND_CFG_FILE when omitted.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Outputs (globals):
        #   Sets variables defined in the loaded file.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_cfg_load
        #
        # Examples:
        #   sgnd_cfg_load
        #
        #   sgnd_cfg_load "/etc/solidgroundux/myapp.cfg"
        #
        # Notes:
        #   - Missing files are not treated as an error.
    sgnd_cfg_load() {
        local file="${1:-$SGND_CFG_FILE}"
        _sgnd_kv_load_file "$file"
    }

    # fn: sgnd_cfg_set
        # Purpose:
        #   Persist a config KEY=VALUE pair and update the current shell variable.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Writes or replaces the KEY=VALUE entry in SGND_CFG_FILE.
        #   - Updates the in-memory shell variable to the same value.
        #
        # Arguments:
        #   $1  KEY
        #       Config variable name.
        #   $2  VALUE
        #       Value to persist.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Outputs (globals):
        #   Sets $KEY in the current shell.
        #
        # Side effects:
        #   - Updates SGND_CFG_FILE on disk.
        #   - May emit a warning for invalid keys.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid key or write failure.
        #
        # Usage:
        #   sgnd_cfg_set KEY VALUE
        #
        # Examples:
        #   sgnd_cfg_set "APP_TITLE" "SolidGround Console"
        #
        #   sgnd_cfg_set "SGND_PAGE_MAX_ROWS" "15"
    sgnd_cfg_set() {
        local key="$1" val="$2"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_set "$file" "$key" "$val"
        printf -v "$key" '%s' "$val"
    }

    # fn: sgnd_cfg_unset
        # Purpose:
        #   Remove a config key from the file and unset it in the current shell.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Removes the KEY=VALUE entry from SGND_CFG_FILE.
        #   - Unsets the variable in the current shell (best effort).
        #
        # Arguments:
        #   $1  KEY
        #       Config variable name.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Outputs (globals):
        #   Unsets $KEY in the current shell.
        #
        # Side effects:
        #   - Updates SGND_CFG_FILE on disk.
        #   - May emit a warning for invalid keys.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid key or write failure.
        #
        # Usage:
        #   sgnd_cfg_unset KEY
        #
        # Examples:
        #   sgnd_cfg_unset "APP_TITLE"
        #
        #   sgnd_cfg_unset "SGND_PAGE_MAX_ROWS"
    sgnd_cfg_unset() {
        local key="$1"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_unset "$file" "$key"
        unset "$key" || true
    }

    # fn: sgnd_cfg_reset
        # Purpose:
        #   Hard-reset the config file by deleting it.
        #
        # Behavior:
        #   - Resolves the target file from SGND_CFG_FILE.
        #   - Removes the file if present.
        #   - Does not recreate a skeleton or defaults.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Side effects:
        #   - Deletes SGND_CFG_FILE.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_cfg_reset
        #
        # Examples:
        #   sgnd_cfg_reset
        #
        # Notes:
        #   - Skeleton recreation is the responsibility of bootstrap/domain logic.
    sgnd_cfg_reset() {
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_reset_file "$file"
    }

    # fn: sgnd_cfg_get
        # Purpose:
        #   Read a config value from the config file.
        #
        # Behavior:
        #   - Validates the requested key.
        #   - Reads the value directly from SGND_CFG_FILE.
        #   - Does not read from the current shell variable.
        #
        # Arguments:
        #   $1  KEY
        #       Config variable name.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Output:
        #   Prints the value to stdout without a trailing newline.
        #
        # Side effects:
        #   - May emit a warning for invalid keys.
        #
        # Returns:
        #   0 if found.
        #   1 if missing or invalid.
        #
        # Usage:
        #   sgnd_cfg_get KEY
        #
        # Examples:
        #   value="$(sgnd_cfg_get "APP_TITLE")" || value=""
        #
        #   sgnd_cfg_get "SGND_PAGE_MAX_ROWS"
    sgnd_cfg_get() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_get "$SGND_CFG_FILE" "$key"
    }

    # fn: sgnd_cfg_has
        # Purpose:
        #   Test whether a config key exists in the config file.
        #
        # Behavior:
        #   - Validates the requested key.
        #   - Checks SGND_CFG_FILE for a matching KEY=VALUE entry.
        #   - Treats empty values as present when the key exists.
        #
        # Arguments:
        #   $1  KEY
        #       Config variable name.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Side effects:
        #   - May emit a warning for invalid keys.
        #
        # Returns:
        #   0 if present.
        #   1 if missing or invalid.
        #
        # Usage:
        #   sgnd_cfg_has KEY
        #
        # Examples:
        #   if sgnd_cfg_has "APP_TITLE"; then
        #       printf 'configured\n'
        #   fi
        #
        #   sgnd_cfg_has "SGND_PAGE_MAX_ROWS"
    sgnd_cfg_has() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_has "$SGND_CFG_FILE" "$key"
    }
    
    # fn: sgnd_cfg_show_keys
        # Purpose:
        #   Display selected config keys and their stored values.
        #
        # Behavior:
        #   - Reads values from SGND_CFG_FILE, not from in-memory shell variables.
        #   - Renders a formatted section using sgnd_print_* helpers.
        #   - Shows empty values as "" and missing values as <unset>.
        #
        # Arguments:
        #   $@  KEYS
        #       Config keys to display.
        #
        # Inputs (globals):
        #   SGND_CFG_FILE
        #
        # Side effects:
        #   - Writes formatted output to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_cfg_show_keys KEY [KEY ...]
        #
        # Examples:
        #   sgnd_cfg_show_keys APP_TITLE SGND_PAGE_MAX_ROWS
        #
        #   sgnd_cfg_show_keys SGND_FRAMEWORK_ROOT SGND_USRCFG_FILE
    sgnd_cfg_show_keys() {
        local key val

        sgnd_print_sectionheader --text "CFG" --pad 2 --padend 1

        for key in "$@"; do
            if sgnd_cfg_has "$key"; then
                val="$(sgnd_cfg_get "$key")" || val=""
                if [[ -z "$val" ]]; then
                    sgnd_print_fill --left "$key" --right '""' --pad 2
                else
                    sgnd_print_fill --left "$key" --right "$val" --pad 2
                fi
            else
                sgnd_print_fill --left "$key" --right "<unset>" --pad 2
            fi
        done

        sgnd_print
    }

# --- Bootstrap/advanced: cfg domain loading ------------------------------------------
    # These helpers implement "system + user cfg" behavior driven by a specs array.
    # Intended for bootstrap; stable but not part of the minimal surface area.

    # fn: sgnd_cfg_has_audience
        # Purpose:
        #   Test whether a cfg spec array contains entries for a requested audience.
        #
        # Behavior:
        #   - Scans the supplied spec array.
        #   - Matches entries marked for the requested audience.
        #   - Treats "both" entries as matching either "system" or "user".
        #
        # Arguments:
        #   $1  SPEC_ARRAY_NAME
        #       Name of the specs array variable.
        #   $2  AUDIENCE
        #       Requested audience: "system" or "user".
        #
        # Returns:
        #   0 if at least one matching spec exists.
        #   1 otherwise.
        #
        # Usage:
        #   sgnd_cfg_has_audience SPEC_ARRAY_NAME system
        #
        # Examples:
        #   if sgnd_cfg_has_audience SGND_CFG_SPECS "user"; then
        #       printf 'user cfg supported\n'
        #   fi
        #
        #   sgnd_cfg_has_audience SGND_CFG_SPECS "system"
    sgnd_cfg_has_audience() {
        local spec_array_name="${1:-}"
        local want="${2:-}"          # "system" or "user"
        [[ -n "$spec_array_name" && -n "$want" ]] || return 1

        local -n specs="$spec_array_name"

        local spec audience var desc extra
        for spec in "${specs[@]}"; do
            IFS='|' read -r audience var desc extra <<< "$spec"
            case "$audience" in
                "$want"|both) return 0 ;;
            esac
        done

        return 1
    }

    # fn: _sgnd_cfg_write_template_header
        # Purpose:
        #   Write a standard auto-generated header for a cfg template file.
        #
        # Arguments:
        #   $1  DOMAIN
        #       Logical config domain name.
        #   $2  AUDIENCE
        #       Config audience: system or user.
        #
        # Output:
        #   Prints header text to stdout.
        #
        # Returns:
        #   0 always.
    _sgnd_cfg_write_template_header() {
        local domain="${1:-configuration}"
        local audience="${2:-user}"
        local generated=""

        generated="$(date '+%Y-%m-%d %H:%M:%S')"

        printf '# =====================================================================================
'
        printf '# SolidgroundUX - %s configuration (%s)
' "$domain" "$audience"
        printf '# -------------------------------------------------------------------------------------
'
        printf '# Generated   : %s
' "$generated"
        printf '#
'
        printf '# Description:
'
        printf '#   Auto-generated configuration template based on current defaults.
'
        printf '#
'
        printf '# Precedence:
'
        printf '#   - System configuration is loaded first when present
'
        printf '#   - User configuration is loaded after system configuration
'
        printf '#   - User values override system values
'
        printf '#
'
        printf '# Notes:
'
        printf '#   - This file may be edited safely
'
        printf '#   - Only KEY=VALUE lines are processed
'
        printf '#   - Missing values fall back to in-memory defaults
'
        printf '# =====================================================================================

'
    }

    # fn: sgnd_cfg_create_missing_domain_files
        # Purpose:
        #   Create missing cfg files for a domain from the active defaults/specs.
        #
        # Behavior:
        #   - Creates a system cfg when system-audience specs exist and the caller is root.
        #   - Creates a user cfg when user-audience specs exist.
        #   - In framework mode under sudo/root, creates both files when missing.
        #   - Uses current in-memory variable values as the template defaults.
        #   - Emits informative messages instead of missing-file warnings.
        #
        # Arguments:
        #   $1  DOMAIN
        #   $2  SYSCFG
        #   $3  USRCFG
        #   $4  SPEC_ARRAY_NAME
        #   $5  MODE
        #       Optional mode: framework or script.
        #       Default: script
        #
        # Side effects:
        #   - Creates parent directories as needed.
        #   - Creates cfg files when required.
        #   - Writes informational output.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid arguments or file creation failure.
    sgnd_cfg_create_missing_domain_files() {
        local domain="${1:-}"
        local syscfg="${2:-}"
        local usrcfg="${3:-}"
        local spec_array_name="${4:-}"
        local mode="${5:-script}"

        [[ -n "$domain" && -n "$spec_array_name" ]] || return 1

        local is_root=0
        (( EUID == 0 )) && is_root=1

        if sgnd_cfg_has_audience "$spec_array_name" "system"; then
            if (( is_root )) && [[ -n "$syscfg" && ! -f "$syscfg" ]]; then
                sgnd_ensure_writable_dir "$(dirname -- "$syscfg")" || return 1
                sgnd_cfg_write_skeleton_filtered "$syscfg" "system" "$spec_array_name" "$domain" || return 1
                sayinfo "[$domain] created system cfg: $syscfg"
            fi
        fi

        if sgnd_cfg_has_audience "$spec_array_name" "user"; then
            if [[ -n "$usrcfg" && ! -f "$usrcfg" ]]; then
                sgnd_ensure_writable_dir "$(dirname -- "$usrcfg")" || return 1
                sgnd_cfg_write_skeleton_filtered "$usrcfg" "user" "$spec_array_name" "$domain" || return 1
                sayinfo "[$domain] created user cfg: $usrcfg"
            fi
        fi

        if sgnd_cfg_has_audience "$spec_array_name" "system" && [[ -n "$syscfg" && ! -f "$syscfg" ]] && (( ! is_root )); then
            saydebug "[$domain] system cfg missing but not created because current session is not root"
        fi

        return 0
    }

    # fn: sgnd_cfg_write_skeleton_filtered
        # Purpose:
        #   Write an auto-generated cfg skeleton filtered by audience.
        #
        # Behavior:
        #   - Writes a commented KEY=VALUE config template.
        #   - Includes only specs matching the requested audience.
        #   - Includes specs marked "both" for either audience.
        #   - Uses current shell values as initial defaults where available.
        #   - Adds a standard auto-generated file header.
        #
        # Arguments:
        #   $1  FILE
        #       Target cfg file path.
        #   $2  AUDIENCE
        #       Audience filter: "system" or "user".
        #   $3  SPEC_ARRAY_NAME
        #       Name of the cfg specs array.
        #   $4  DOMAIN
        #       Optional logical domain name for header text.
        #       Default: configuration
        #
        # Side effects:
        #   - Creates or overwrites the target file.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid arguments.
        #
        # Usage:
        #   sgnd_cfg_write_skeleton_filtered FILE AUDIENCE SPEC_ARRAY_NAME [DOMAIN]
        #
        # Examples:
        #   sgnd_cfg_write_skeleton_filtered "$SGND_USRCFG_FILE" "user" SGND_FRAMEWORK_GLOBALS "Framework"
        #
        #   sgnd_cfg_write_skeleton_filtered "$SGND_SYSCFG_FILE" "system" SGND_SCRIPT_GLOBALS "Script"
    sgnd_cfg_write_skeleton_filtered() {
        local file="${1:-}"
        local audience_want="${2:-}"
        local spec_array_name="${3:-}"
        local domain="${4:-configuration}"

        [[ -n "$file" && -n "$audience_want" && -n "$spec_array_name" ]] || return 1

        local -n specs="$spec_array_name"

        {
            _sgnd_cfg_write_template_header "$domain" "$audience_want"

            local spec audience var desc extra val
            for spec in "${specs[@]}"; do
                IFS='|' read -r audience var desc extra <<< "$spec"
                [[ -n "$var" ]] || continue

                case "$audience" in
                    "$audience_want"|both)
                        printf '# %s
' "${desc:-$var}"
                        val="${!var:-}"
                        printf '%s=%s

' "$var" "$val"
                        ;;
                esac
            done
        } > "$file"

        return 0
    }

    # fn: sgnd_cfg_load_file
        # Purpose:
        #   Load a specific cfg file into shell variables for domain-level processing.
        #
        # Behavior:
        #   - Reads plain KEY=VALUE lines from the target file.
        #   - Ignores blank lines and comments.
        #   - Accepts only valid shell identifiers as keys.
        #   - Stores values literally without unquoting or escape processing.
        #
        # Arguments:
        #   $1  FILE
        #       Config file path to load.
        #
        # Outputs (globals):
        #   Sets variables defined in the file.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_cfg_load_file FILE
        #
        # Examples:
        #   sgnd_cfg_load_file "$SGND_SYSCFG_FILE"
        #
        #   [[ -r "$SGND_USRCFG_FILE" ]] && sgnd_cfg_load_file "$SGND_USRCFG_FILE"
        #
        # Notes:
        #   - Intended for domain/bootstrap flow readability.
    sgnd_cfg_load_file() {
        local file="${1:-}"
        [[ -r "$file" ]] || return 0

        local line key value
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Trim leading/trailing whitespace (basic)
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"

            [[ -n "$line" ]] || continue
            [[ "${line:0:1}" == "#" ]] && continue

            # Must contain '=' and a non-empty key
            [[ "$line" == *"="* ]] || continue
            key="${line%%=*}"
            value="${line#*=}"

            # Trim key whitespace
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            [[ -n "$key" ]] || continue

            # Validate key is a shell variable name
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

            # Set variable (value can be anything; keep literal)
            printf -v "$key" '%s' "$value"
        done < "$file"

        return 0
    }

    # fn: sgnd_cfg_domain_apply
        # Purpose:
        #   Apply configuration for a domain from system and user cfg files.
        #
        # Behavior:
        #   - Ensures required cfg files exist for the domain.
        #   - Loads system cfg first when applicable.
        #   - Loads user cfg after system cfg so user values override system values.
        #   - Creates missing cfg files from defaults when possible.
        #
        # Arguments:
        #   $1  DOMAIN
        #       Logical config domain name.
        #   $2  SYSCFG
        #       System cfg file path.
        #   $3  USRCFG
        #       User cfg file path.
        #   $4  SPEC_ARRAY_NAME
        #       Name of the cfg specs array.
        #   $5  MODE
        #       Optional mode: "framework" or "script".
        #       Default: script
        #
        # Side effects:
        #   - May create cfg files.
        #   - Loads cfg values into shell variables.
        #   - May create cfg templates from current defaults.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid arguments or setup failure.
        #
        # Usage:
        #   sgnd_cfg_domain_apply DOMAIN SYSCFG USRCFG SPEC_ARRAY_NAME [MODE]
        #
        # Examples:
        #   sgnd_cfg_domain_apply "framework" "$SGND_FRAMEWORK_SYSCFG" "$SGND_FRAMEWORK_USRCFG" SGND_FRAMEWORK_CFG_SPECS "framework"
        #
        #   sgnd_cfg_domain_apply "script" "$SGND_SYSCFG_FILE" "$SGND_USRCFG_FILE" SGND_SCRIPT_CFG_SPECS
    sgnd_cfg_domain_apply() {
        local domain="${1:-}"
        local syscfg="${2:-}"
        local usrcfg="${3:-}"
        local spec_array_name="${4:-}"
        local mode="${5:-script}"   # "framework" or "script"

        [[ -n "$domain" && -n "$spec_array_name" ]] || return 1

        sgnd_cfg_create_missing_domain_files "$domain" "$syscfg" "$usrcfg" "$spec_array_name" "$mode" || return 1

        if sgnd_cfg_has_audience "$spec_array_name" "system"; then
            [[ -r "$syscfg" ]] && sgnd_cfg_load_file "$syscfg"
        fi

        if sgnd_cfg_has_audience "$spec_array_name" "user"; then
            [[ -r "$usrcfg" ]] && sgnd_cfg_load_file "$usrcfg"
        fi

        return 0
    }

# --- Bootstrap/advanced: State loading -----------------------------------------------
    # fn: sgnd_state_load
        # Purpose:
        #   Load the state file into shell variables.
        #
        # Behavior:
        #   - Reads KEY=VALUE pairs from SGND_STATE_FILE.
        #   - Ignores missing files.
        #   - Emits a debug message before loading.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Outputs (globals):
        #   Sets variables found in the file.
        #
        # Side effects:
        #   - May write a debug message.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_state_load
        #
        # Examples:
        #   sgnd_state_load
    sgnd_state_load() {
        saydebug "Loading state from file ${SGND_STATE_FILE}"
        _sgnd_kv_load_file "$SGND_STATE_FILE"
    }

    # fn: sgnd_state_set
        # Purpose:
        #   Persist a state KEY=VALUE pair and update the current shell variable.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Writes or replaces the KEY=VALUE entry in SGND_STATE_FILE.
        #   - Updates the in-memory shell variable to the same value.
        #   - Emits a debug message describing the change.
        #
        # Arguments:
        #   $1  KEY
        #       State variable name.
        #   $2  VALUE
        #       Value to persist.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Outputs (globals):
        #   Sets $KEY in the current shell.
        #
        # Side effects:
        #   - Updates SGND_STATE_FILE on disk.
        #   - May emit debug or warning output.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid key or write failure.
        #
        # Usage:
        #   sgnd_state_set KEY VALUE
        #
        # Examples:
        #   sgnd_state_set "CURRENT_PAGE" "2"
        #
        #   sgnd_state_set "LAST_MODULE" "devtools"
    sgnd_state_set() {
        local key="$1" val="$2"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid state key: '$key'"
            return 1
        }   

        saydebug "Setting state key '$key' to '$val' in file ${SGND_STATE_FILE}"

        _sgnd_kv_set "$SGND_STATE_FILE" "$key" "$val"
        printf -v "$key" '%s' "$val"
    }

    # fn: sgnd_state_unset
        # Purpose:
        #   Remove a state key from the file and unset it in the current shell.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Removes the KEY=VALUE entry from SGND_STATE_FILE.
        #   - Unsets the variable in the current shell.
        #   - Emits a debug message describing the change.
        #
        # Arguments:
        #   $1  KEY
        #       State variable name.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Outputs (globals):
        #   Unsets $KEY in the current shell.
        #
        # Side effects:
        #   - Updates SGND_STATE_FILE on disk.
        #   - May emit debug or warning output.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid key or write failure.
        #
        # Usage:
        #   sgnd_state_unset KEY
        #
        # Examples:
        #   sgnd_state_unset "CURRENT_PAGE"
        #
        #   sgnd_state_unset "LAST_MODULE"
    sgnd_state_unset() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid state key: '$key'"
            return 1
        }   

        saydebug "Unsetting state key '$key' in file ${SGND_STATE_FILE}"

        _sgnd_kv_unset "$SGND_STATE_FILE" "$key"
        unset "$key" || true
    }

    # fn: sgnd_state_reset
        # Purpose:
        #   Hard-reset the state file by deleting it.
        #
        # Behavior:
        #   - Returns quietly when SGND_STATE_FILE is empty.
        #   - Emits a debug message before deletion.
        #   - Removes the state file if present.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Side effects:
        #   - Deletes SGND_STATE_FILE.
        #   - May emit a debug message.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_state_reset
        #
        # Examples:
        #   sgnd_state_reset
    sgnd_state_reset() {
        [[ -n "$SGND_STATE_FILE" ]] || return 0
        saydebug "Deleting statefile $SGND_STATE_FILE"
        _sgnd_kv_reset_file "$SGND_STATE_FILE"
    }

    # fn: sgnd_state_get
        # Purpose:
        #   Read a state value from the state file.
        #
        # Behavior:
        #   - Validates the requested key.
        #   - Reads the value directly from SGND_STATE_FILE.
        #   - Does not read from the current shell variable.
        #
        # Arguments:
        #   $1  KEY
        #       State variable name.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Output:
        #   Prints the value to stdout without a trailing newline.
        #
        # Side effects:
        #   - May emit a warning for invalid keys.
        #
        # Returns:
        #   0 if found.
        #   1 if missing or invalid.
        #
        # Usage:
        #   sgnd_state_get KEY
        #
        # Examples:
        #   page="$(sgnd_state_get "CURRENT_PAGE")" || page="1"
        #
        #   sgnd_state_get "LAST_MODULE"
    sgnd_state_get() {
        local key="$1"
        _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                return 1
        }
        _sgnd_kv_get "$SGND_STATE_FILE" "$key"
    }

    # fn: sgnd_state_has
        # Purpose:
        #   Test whether a state key exists in the state file.
        #
        # Behavior:
        #   - Validates the requested key.
        #   - Checks SGND_STATE_FILE for a matching KEY=VALUE entry.
        #   - Treats empty values as present when the key exists.
        #
        # Arguments:
        #   $1  KEY
        #       State variable name.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Side effects:
        #   - May emit a warning for invalid keys.
        #
        # Returns:
        #   0 if present.
        #   1 if missing or invalid.
        #
        # Usage:
        #   sgnd_state_has KEY
        #
        # Examples:
        #   if sgnd_state_has "CURRENT_PAGE"; then
        #       printf 'page stored\n'
        #   fi
        #
        #   sgnd_state_has "LAST_MODULE"
    sgnd_state_has() {
        local key="$1"
        _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                return 1
        }
        
        _sgnd_kv_has "$SGND_STATE_FILE" "$key"
    }

    # fn: sgnd_state_save_keys
        # Purpose:
        #   Persist a list of shell variables to the state store.
        #
        # Behavior:
        #   - Iterates over the supplied variable names.
        #   - Reads each current value using safe indirect expansion.
        #   - Persists each value via sgnd_state_set.
        #   - Skips invalid identifiers with a warning.
        #
        # Arguments:
        #   $@  KEYS
        #       Variable names to save.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Side effects:
        #   - Updates SGND_STATE_FILE on disk.
        #   - May emit debug or warning output through sgnd_state_set.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_state_save_keys KEY [KEY ...]
        #
        # Examples:
        #   sgnd_state_save_keys CURRENT_PAGE LAST_MODULE
        #
        #   sgnd_state_save_keys FLAG_DEBUG FLAG_VERBOSE FLAG_DRYRUN
    sgnd_state_save_keys() {
        local key val
        for key in "$@"; do
            _sgnd_is_ident "$key" || { saywarning "Skipping invalid state key: '$key'"; continue; }

            # Safe under set -u
            val="${!key-}"

            # Optional: skip unset keys instead of saving empty
            # [[ -z "${!key+x}" ]] && continue

            sgnd_state_set "$key" "$val"
        done
    }

    # fn: sgnd_state_load_keys
        # Purpose:
        #   Load selected state keys from the state store into shell variables.
        #
        # Behavior:
        #   - Iterates over the supplied variable names.
        #   - Reads each value from SGND_STATE_FILE.
        #   - Assigns only keys that exist in the state store.
        #   - Skips invalid identifiers with a warning.
        #
        # Arguments:
        #   $@  KEYS
        #       Variable names to load.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Outputs (globals):
        #   Sets variables for keys found in the state store.
        #
        # Side effects:
        #   - May emit warnings for invalid keys.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_state_load_keys KEY [KEY ...]
        #
        # Examples:
        #   sgnd_state_load_keys CURRENT_PAGE LAST_MODULE
        #
        #   sgnd_state_load_keys FLAG_DEBUG FLAG_VERBOSE FLAG_DRYRUN
    sgnd_state_load_keys() {
        local key val
        for key in "$@"; do
             _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                continue
            }

            if val="$(sgnd_state_get "$key")"; then
                printf -v "$key" '%s' "$val"
            fi
        done
    }

    # fn: sgnd_state_list_keys
        # Purpose:
        #   List keys currently present in the state file.
        #
        # Behavior:
        #   - Reads SGND_STATE_FILE when it is readable.
        #   - Emits one key/value pair per line in preserved file order.
        #   - Treats a missing or unreadable state file as non-fatal.
        #
        # Inputs (globals):
        #   SGND_STATE_FILE
        #
        # Output:
        #   Prints lines in the format: key|value
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_state_list_keys
        #
        # Examples:
        #   sgnd_state_list_keys
    sgnd_state_list_keys() {
        [[ -r "${SGND_STATE_FILE:-}" ]] || return 0
        _sgnd_kv_list_keys "$SGND_STATE_FILE"
    }
