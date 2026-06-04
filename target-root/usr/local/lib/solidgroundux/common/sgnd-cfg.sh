# =====================================================================================
# SolidgroundUX - Configuration Management
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
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
#   Client      : -
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Library guard
        # Purpose:
        #   Prevent direct execution of a source-only module and avoid repeated initialization.
        #
        # Behavior:
        #   - Derives a module-specific guard variable from the current filename.
        #   - Exits with status 2 when the file is executed directly.
        #   - Returns immediately when the module has already been loaded.
        #   - Marks the module as loaded before normal initialization continues.
        #
        # Returns:
        #   0 when the module may continue loading or was already loaded.
        #   Exits with status 2 when executed directly.
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

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# --- Internal: file and value manipulation -------------------------------------------
    # fn: _sgnd_is_ident - Is ident
        # Purpose:
        #   Validate that a string is a safe shell identifier for dynamic variable access.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_is_ident ...
    _sgnd_is_ident() {
            [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
    }
   
    # fn: _sgnd_kv_load_file - Kv load file
        # Purpose:
        #   Load key-value assignments from a configuration file into shell variables.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_kv_load_file ...
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

    # fn: _sgnd_kv_set - Kv set
        # Purpose:
        #   Set or update a key-value entry in a configuration file.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_kv_set ...
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

    # fn: _sgnd_kv_unset - Kv unset
        # Purpose:
        #   Remove a key-value entry from a configuration file.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_kv_unset ...
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

    # fn: _sgnd_kv_get - Kv get
        # Purpose:
        #   Read a key-value entry from a configuration file.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_kv_get ...
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

    # fn: _sgnd_kv_list_keys - Kv list keys
        # Purpose:
        #   List all keys found in a configuration file.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_kv_list_keys ...
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
    # fn: sgnd_cfg_load - Cfg load
        # Purpose:
        #   Load a framework or script configuration file into the active shell environment.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_load ...
    sgnd_cfg_load() {
        local file="${1:-$SGND_CFG_FILE}"
        _sgnd_kv_load_file "$file"
    }

    # fn: sgnd_cfg_set - Cfg set
        # Purpose:
        #   Persist a configuration value in the user configuration file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_set ...
    sgnd_cfg_set() {
        local key="$1" val="$2"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_set "$file" "$key" "$val"
        printf -v "$key" '%s' "$val"
    }

    # fn: sgnd_cfg_unset - Cfg unset
        # Purpose:
        #   Remove a configuration value from the user configuration file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_unset ...
    sgnd_cfg_unset() {
        local key="$1"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_unset "$file" "$key"
        unset "$key" || true
    }

    # fn: sgnd_cfg_reset - Cfg reset
        # Purpose:
        #   Reset the user configuration file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_reset ...
    sgnd_cfg_reset() {
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_reset_file "$file"
    }

    # fn: sgnd_cfg_get - Cfg get
        # Purpose:
        #   Read an effective configuration value.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_get ...
    sgnd_cfg_get() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_get "$SGND_CFG_FILE" "$key"
    }

    # fn: sgnd_cfg_has - Cfg has
        # Purpose:
        #   Test whether an effective configuration value exists.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_has ...
    sgnd_cfg_has() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_has "$SGND_CFG_FILE" "$key"
    }
    
    # fn: sgnd_cfg_show_keys - Cfg show keys
        # Purpose:
        #   Print configuration keys and values for inspection.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_show_keys ...
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

    # fn: sgnd_cfg_has_audience - Cfg has audience
        # Purpose:
        #   Test whether a configuration variable applies to a requested audience.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_has_audience ...
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

    # fn: _sgnd_cfg_write_template_header - Cfg write template header
        # Purpose:
        #   Write a generated configuration-template header.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _sgnd_cfg_write_template_header ...
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

    # fn: sgnd_cfg_create_missing_domain_files - Cfg create missing domain files
        # Purpose:
        #   Create missing system and user configuration files for a configuration domain.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_create_missing_domain_files ...
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

    # fn: sgnd_cfg_write_skeleton_filtered - Cfg write skeleton filtered
        # Purpose:
        #   Write a filtered configuration skeleton for selected variables and audience.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_write_skeleton_filtered ...
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

    # fn: sgnd_cfg_load_file - Cfg load file
        # Purpose:
        #   Load one configuration file and apply values to the current environment.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_load_file ...
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

    # fn: sgnd_cfg_domain_apply - Cfg domain apply
        # Purpose:
        #   Apply system and user configuration files for a named configuration domain.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_cfg_domain_apply ...
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
    # fn: sgnd_state_load - State load
        # Purpose:
        #   Load the current script state file into the active shell environment.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_load ...
    sgnd_state_load() {
        saydebug "Loading state from file ${SGND_STATE_FILE}"
        _sgnd_kv_load_file "$SGND_STATE_FILE"
    }

    # fn: sgnd_state_set - State set
        # Purpose:
        #   Persist a state variable in the script state file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_set ...
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

    # fn: sgnd_state_unset - State unset
        # Purpose:
        #   Remove a state variable from the script state file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_unset ...
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

    # fn: sgnd_state_reset - State reset
        # Purpose:
        #   Reset the script state file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_reset ...
    sgnd_state_reset() {
        [[ -n "$SGND_STATE_FILE" ]] || return 0
        saydebug "Deleting statefile $SGND_STATE_FILE"
        _sgnd_kv_reset_file "$SGND_STATE_FILE"
    }

    # fn: sgnd_state_get - State get
        # Purpose:
        #   Read a persisted state value.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_get ...
    sgnd_state_get() {
        local key="$1"
        _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                return 1
        }
        _sgnd_kv_get "$SGND_STATE_FILE" "$key"
    }

    # fn: sgnd_state_has - State has
        # Purpose:
        #   Test whether a persisted state value exists.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_has ...
    sgnd_state_has() {
        local key="$1"
        _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                return 1
        }
        
        _sgnd_kv_has "$SGND_STATE_FILE" "$key"
    }

    # fn: sgnd_state_save_keys - State save keys
        # Purpose:
        #   Persist a selected set of shell variables to the script state file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_save_keys ...
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

    # fn: sgnd_state_load_keys - State load keys
        # Purpose:
        #   Load a selected set of state values into shell variables.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_load_keys ...
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

    # fn: sgnd_state_list_keys - State list keys
        # Purpose:
        #   List all keys stored in the script state file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_state_list_keys ...
    sgnd_state_list_keys() {
        [[ -r "${SGND_STATE_FILE:-}" ]] || return 0
        _sgnd_kv_list_keys "$SGND_STATE_FILE"
    }
