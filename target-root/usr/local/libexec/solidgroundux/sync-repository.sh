#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Repository Synchronizer
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : 660d6df839027bd27635633a2a073f2d2f36918a7adda3c39c725e9094c03a14
#   Source      : sync-repository.sh
#   Type        : script
#   Group       : Development Tools
#   Purpose     : Mirror a development repository to a remote workstation over SSH/SCP.
#
# Description:
#   Copies a repository from the development machine to a remote workstation. The
#   destination connection settings and source directory are stored as persistent
#   SolidGroundUX state so repeated synchronization requires no re-entry.
#
# Design principles:
#   - The development tree remains authoritative.
#   - SSH connectivity is verified before any destination is replaced.
#   - Files are copied to a temporary destination first.
#   - The existing destination is replaced only after a successful copy.
#   - An unchanged source tree is skipped unless --force is specified.
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
    _framework_locator() {
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply=""

        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"
        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"
        else
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            if [[ -t 0 && -t 1 ]]; then
                printf '%s\n' "SolidGroundUX bootstrap configuration"
                printf '%s\n' "No configuration file found."
                printf '%s\n' "Creating: $cfg"

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_APPLICATION_ROOT must be an absolute path"; return 126 ;;
            esac

            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            printf '%s\n' "Created bootstrap cfg: $cfg"
        fi

        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"
            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            printf '%s\n' "Cannot read bootstrap cfg: $cfg"
            return 126
        fi

        local exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# - Script identity ------------------------------------------------------------------
    # var$ SGND_SCRIPT_FILE
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"

    # var$ SGND_SCRIPT_DIR
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"

    # var$ SGND_SCRIPT_BASE
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"

    # var$ SGND_SCRIPT_NAME
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# - Framework integration ------------------------------------------------------------
    SGND_USING=(
    )

    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Synchronize immediately using saved settings|0|"
        "source|s|value|VAL_SOURCE_DIR|Repository source directory|"
        "host|m|value|VAL_DEST_HOST|Destination machine name or IP address|"
        "user|u|value|VAL_DEST_USER|Destination SSH user|"
        "directory|d|value|VAL_DEST_DIR|Destination directory on the remote machine|"
        "force|f|flag|FLAG_FORCE|Synchronize even when the source tree is unchanged|0|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Configure and synchronize interactively:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Synchronize immediately using saved settings:"
        "  $SGND_SCRIPT_NAME --auto"
        ""
        "Force synchronization even when unchanged:"
        "  $SGND_SCRIPT_NAME --auto --force"
    )

    SGND_SCRIPT_GLOBALS=(
    )

    SGND_STATE_VARIABLES=(
        "VAL_SOURCE_DIR|Source directory||"
        "VAL_DEST_HOST|Destination machine||"
        "VAL_DEST_USER|Destination user||"
        "VAL_DEST_DIR|Destination directory||"
        "VAL_LAST_SYNC_SIGNATURE|Last successful source signature||"
        "VAL_LAST_SYNC_AT|Last successful synchronization time||"
    )

    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=1

# - Local script declarations --------------------------------------------------------
    VAL_SOURCE_DIR="${VAL_SOURCE_DIR:-}"
    VAL_DEST_HOST="${VAL_DEST_HOST:-192.168.0.101}"
    VAL_DEST_USER="${VAL_DEST_USER:-Mark}"
    VAL_DEST_DIR="${VAL_DEST_DIR:-D:/Users/Mark/Files/Development/SolidGroundUX}"
    FLAG_AUTO="${FLAG_AUTO:-0}"
    FLAG_FORCE="${FLAG_FORCE:-0}"
    VAL_LAST_SYNC_SIGNATURE="${VAL_LAST_SYNC_SIGNATURE:-}"
    VAL_LAST_SYNC_AT="${VAL_LAST_SYNC_AT:-}"

# - Local script functions -----------------------------------------------------------
    # fn: _detect_source_default - Determine a useful default repository source path
        # . Output
        #   Writes the detected repository root, or the current directory when no
        #   enclosing Git repository can be detected.
    _detect_source_default() {
        local repo_root=""

        if command -v git >/dev/null 2>&1; then
            repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
        fi

        if [[ -n "$repo_root" ]]; then
            printf '%s\n' "$repo_root"
        else
            printf '%s\n' "$PWD"
        fi
    }

    # fn: _get_userinput - Ask for synchronization settings
        # . Behavior
        #   Uses saved state values as defaults and updates the persistent state on exit.
    _get_userinput() {
        [[ -n "$VAL_SOURCE_DIR" ]] || VAL_SOURCE_DIR="$(_detect_source_default)"

        sgnd_print
        sgnd_print_sectionheader --text "Repository synchronization"

        ask_prompt_form --autoalign --pad 2 -- \
            "VAL_SOURCE_DIR|Source directory|$VAL_SOURCE_DIR|sgnd_validate_text" \
            "VAL_DEST_HOST|Destination machine|$VAL_DEST_HOST|sgnd_validate_text" \
            "VAL_DEST_USER|Destination user|$VAL_DEST_USER|sgnd_validate_text" \
            "VAL_DEST_DIR|Destination directory|$VAL_DEST_DIR|sgnd_validate_text" || return $?
    }

    # fn: _validate_settings - Validate source and destination settings
    _validate_settings() {
        [[ -d "$VAL_SOURCE_DIR" ]] || {
            sayfail "Source directory does not exist: $VAL_SOURCE_DIR"
            return 1
        }

        [[ -n "$VAL_DEST_HOST" ]] || { sayfail "Destination machine is required."; return 1; }
        [[ -n "$VAL_DEST_USER" ]] || { sayfail "Destination user is required."; return 1; }
        [[ -n "$VAL_DEST_DIR" ]] || { sayfail "Destination directory is required."; return 1; }

        case "$VAL_DEST_DIR" in
            [A-Za-z]:/*) ;;
            *)
                sayfail "Destination directory must use a Windows drive path such as D:/Users/Mark/Files/Development/SolidGroundUX"
                return 1
                ;;
        esac

        return 0
    }


    # fn: _source_signature - Calculate a metadata signature for the source tree
        # . Purpose
        #   Detect whether the repository tree has changed since the last successful sync
        #   without reading and hashing the complete contents of every file.
        #
        # . Behavior
        #   Includes relative path, object type, size and modification timestamp for files,
        #   directories and links. Directory metadata is included so file removals are also
        #   detected.
        #
        # . Output
        #   Writes a SHA-256 signature for the current source tree.
    _source_signature() {
        find "$VAL_SOURCE_DIR" -mindepth 1 \
            -printf '%P\0%y\0%s\0%T@\0' 2>/dev/null | \
            sort -z | sha256sum | cut -d' ' -f1
    }

    # fn: _powershell_quote - Escape a string for a PowerShell single-quoted literal
        # . Arguments
        #   $1  Value to escape.
        # . Output
        #   Writes the escaped value without surrounding quotes.
    _powershell_quote() {
        local value="$1"
        value="${value//\'/\'\'}"
        printf '%s' "$value"
    }

    # fn: _remote_powershell - Execute a PowerShell command on the destination machine
        # . Arguments
        #   $1  PowerShell command string.
    _remote_powershell() {
        local command="$1"
        ssh "${VAL_DEST_USER}@${VAL_DEST_HOST}" \
            "powershell.exe -NoProfile -NonInteractive -Command \"$command\""
    }

    # fn: _sync_repository - Copy the repository and atomically replace the destination
        # . Behavior
        #   - Verifies SSH connectivity before touching the destination.
        #   - Copies into a sibling .sync-tmp directory.
        #   - Replaces the existing destination only after SCP succeeds.
    _sync_repository() {
        local remote="${VAL_DEST_USER}@${VAL_DEST_HOST}"
        local temp_dir="${VAL_DEST_DIR}.sync-tmp"
        local dest_ps=""
        local temp_ps=""
        local current_signature=""

        dest_ps="$(_powershell_quote "$VAL_DEST_DIR")"
        temp_ps="$(_powershell_quote "$temp_dir")"

        saystart "Checking source tree for changes"
        current_signature="$(_source_signature)" || {
            sayfail "Could not calculate source tree signature."
            return 1
        }

        if (( ! FLAG_FORCE )) && [[ -n "$VAL_LAST_SYNC_SIGNATURE" ]] && \
           [[ "$current_signature" == "$VAL_LAST_SYNC_SIGNATURE" ]]; then
            sayok "Source tree is unchanged; synchronization not required"
            [[ -n "$VAL_LAST_SYNC_AT" ]] && sayinfo "Last synchronized: $VAL_LAST_SYNC_AT"
            return 0
        fi

        saystart "Checking connection to $remote"
        ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote" "exit" >/dev/null 2>&1 || {
            sayfail "Cannot connect to $remote without interactive authentication."
            sayinfo "Test the connection with: ssh $remote"
            return 1
        }
        sayok "Connection available"

        saystart "Preparing temporary destination"
        _remote_powershell \
            "Remove-Item -LiteralPath '$temp_ps' -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Path '$temp_ps' -Force | Out-Null" || {
            sayfail "Could not prepare temporary destination: $temp_dir"
            return 1
        }

        saystart "Copying repository to $remote:$temp_dir"
        scp -r "${VAL_SOURCE_DIR}/." "${remote}:${temp_dir}/" || {
            sayfail "Repository copy failed. Existing destination was not changed."
            _remote_powershell "Remove-Item -LiteralPath '$temp_ps' -Recurse -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1 || true
            return 1
        }

        saystart "Replacing destination copy"
        _remote_powershell \
            "Remove-Item -LiteralPath '$dest_ps' -Recurse -Force -ErrorAction SilentlyContinue; Move-Item -LiteralPath '$temp_ps' -Destination '$dest_ps'" || {
            sayfail "Copy succeeded, but destination replacement failed."
            sayinfo "Temporary copy remains at: $temp_dir"
            return 1
        }

        VAL_LAST_SYNC_SIGNATURE="$current_signature"
        VAL_LAST_SYNC_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"

        sayok "Repository synchronized to $remote:$VAL_DEST_DIR"
        sayinfo "Synchronization state updated: $VAL_LAST_SYNC_AT"
        return 0
    }

# - Main ----------------------------------------------------------------------------
    # fn: main - Run the repository synchronization sequence
    main() {
        _framework_locator || exit $?
        sgnd_exe_start --autostate -- "$@"

        [[ -n "$VAL_SOURCE_DIR" ]] || VAL_SOURCE_DIR="$(_detect_source_default)"

        if (( ! FLAG_AUTO )); then
            _get_userinput || return $?
        fi

        _validate_settings || return $?
        _sync_repository
    }

    main "$@"
