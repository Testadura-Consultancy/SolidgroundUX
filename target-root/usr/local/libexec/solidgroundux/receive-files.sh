#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Receive Files
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621612
#   Checksum    : 1cbc241fc47849858cf869f18524f9e8ceef3c2520b6c08f8e593391c8d51d04
#   Source      : receive-files.sh
#   Type        : script
#   Group       : SDK Tools
#   Purpose     : Receive a workspace tar stream and extract it beneath a target root
#
# Description:
#   Receives a tar archive through standard input, validates that every archive entry
#   is a safe relative path, and extracts the streamed workspace files beneath the
#   requested target root.
#
# Design principles:
#   - File selection remains the responsibility of deploy-workspace.sh
#   - Archive entries always remain relative to the supplied target root
#   - Unsafe absolute paths and parent traversal are rejected before extraction
#   - The received stream is processed as one deployment operation
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail

# --- Bootstrap ----------------------------------------------------------------------
    # fn: _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Purpose
        #   Resolve the SolidGroundUX framework root and load executable runtime support.
        #
        # . Returns
        #   0 when the executable common library was loaded.
        #   126 when configuration or executable common library is unreadable.
        #   127 when a required configuration directory or file cannot be created.
        #
        # . Usage
        #   _framework_locator || return $?
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="/"
        local reply=""
        local exe_common=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"

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
                printf '%s\n' "SolidGroundUX bootstrap configuration" >&2
                printf '%s\n' "No configuration file found." >&2
                printf '%s\n' "Creating: $cfg" >&2

                printf 'SGND_FRAMEWORK_ROOT [/] : ' > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf 'SGND_APPLICATION_ROOT [%s] : ' "$fw_root" > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_FRAMEWORK_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_APPLICATION_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            mkdir -p "$(dirname "$cfg")" || return 127
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127
        fi

        # shellcheck source=/dev/null
        source "$cfg" || return 126
        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        fi

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Receive files"
    : "${SGND_SCRIPT_DESC:=Receive a tar stream and extract it beneath a target root.}"
    : "${SGND_SCRIPT_VERSION:=1.8}"
    : "${SGND_SCRIPT_BUILD:=2621602}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

# --- Script metadata (framework integration) -----------------------------------------
    SGND_USING=(
    )

    SGND_ARGS_SPEC=(
        "target|t|value|DEST_ROOT|Filesystem root beneath which received paths are extracted|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Receive files beneath the current system root:"
        "  tar -cf - usr/local/bin/example | sudo $SGND_SCRIPT_NAME --target /"
        ""
        "Preview a received stream without extracting it:"
        "  tar -cf - usr/local/bin/example | sudo $SGND_SCRIPT_NAME --target / --dryrun"
    )

    SGND_SCRIPT_GLOBALS=(
    )

    SGND_STATE_VARIABLES=(
    )

    SGND_ON_EXIT_HANDLERS=(
        _cleanup_archive
    )

    SGND_STATE_SAVE=0

# --- Local declarations ---------------------------------------------------------------
    DEST_ROOT="${DEST_ROOT:-}"
    RECEIVED_ARCHIVE=""
    RECEIVED_COUNT=0

# --- Receive helpers -----------------------------------------------------------------
    # fn: _cleanup_archive - Remove the temporary received archive
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _cleanup_archive
    _cleanup_archive() {
        if [[ -n "${RECEIVED_ARCHIVE:-}" && -f "$RECEIVED_ARCHIVE" ]]; then
            rm -f -- "$RECEIVED_ARCHIVE"
        fi
        return 0
    }

    # fn: _validate_target - Validate and prepare the destination root
        # . Purpose
        #   Ensure the destination is an absolute directory path suitable for extraction.
        #
        # . Returns
        #   0 when the target is valid or can be created.
        #   1 when the target is invalid or cannot be created.
        #
        # . Usage
        #   _validate_target || return $?
    _validate_target() {
        : "${DEST_ROOT:=/}"

        case "$DEST_ROOT" in
            /*) ;;
            *)
                sayfail "Destination root must be an absolute path: $DEST_ROOT"
                return 1
                ;;
        esac

        DEST_ROOT="${DEST_ROOT%/}"
        [[ -n "$DEST_ROOT" ]] || DEST_ROOT="/"

        if [[ -e "$DEST_ROOT" && ! -d "$DEST_ROOT" ]]; then
            sayfail "Destination root is not a directory: $DEST_ROOT"
            return 1
        fi

        if [[ ! -d "$DEST_ROOT" ]]; then
            if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
                sayinfo "Would create destination root: $DEST_ROOT"
            else
                mkdir -p -- "$DEST_ROOT" || {
                    sayfail "Cannot create destination root: $DEST_ROOT"
                    return 1
                }
            fi
        fi

        return 0
    }

    # fn: _receive_stream - Store the incoming tar stream in a temporary archive
        # . Purpose
        #   Capture standard input so the archive can be validated before extraction.
        #
        # . Returns
        #   0 when a non-empty archive stream was received.
        #   1 when the temporary file cannot be created or no data was received.
        #
        # . Usage
        #   _receive_stream || return $?
    _receive_stream() {
        RECEIVED_ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/sgnd-receive-files.XXXXXX.tar")" || {
            sayfail "Cannot create temporary receive archive."
            return 1
        }

        cat > "$RECEIVED_ARCHIVE" || {
            sayfail "Failed while receiving the archive stream."
            return 1
        }

        if [[ ! -s "$RECEIVED_ARCHIVE" ]]; then
            sayfail "No archive data was received on standard input."
            return 1
        fi

        return 0
    }

    # fn: _validate_archive - Validate all received archive entries
        # . Purpose
        #   Reject unsafe paths and non-regular archive entry types before extraction.
        #
        # . Behavior
        #   - Rejects absolute paths and parent-directory traversal.
        #   - Accepts regular files and directories only.
        #   - Counts the entries that will be processed.
        #
        # . Returns
        #   0 when every archive entry is safe.
        #   1 when the archive is unreadable, empty, or contains an unsafe entry.
        #
        # . Usage
        #   _validate_archive || return $?
    _validate_archive() {
        local entry=""
        local listing=""
        local type=""

        listing="$(mktemp "${TMPDIR:-/tmp}/sgnd-receive-list.XXXXXX")" || {
            sayfail "Cannot create temporary archive listing."
            return 1
        }

        if ! tar -tf "$RECEIVED_ARCHIVE" > "$listing"; then
            rm -f -- "$listing"
            sayfail "Received data is not a readable tar archive."
            return 1
        fi

        RECEIVED_COUNT=0
        while IFS= read -r entry; do
            [[ -n "$entry" ]] || continue

            case "$entry" in
                /*|../*|*/../*|*/..|..)
                    rm -f -- "$listing"
                    sayfail "Unsafe archive path rejected: $entry"
                    return 1
                    ;;
            esac

            (( RECEIVED_COUNT += 1 ))
        done < "$listing"

        if (( RECEIVED_COUNT == 0 )); then
            rm -f -- "$listing"
            sayfail "The received archive contains no entries."
            return 1
        fi

        while IFS= read -r type; do
            case "$type" in
                -|d) ;;
                *)
                    rm -f -- "$listing"
                    sayfail "Unsupported archive entry type rejected: $type"
                    return 1
                    ;;
            esac
        done < <(tar -tvf "$RECEIVED_ARCHIVE" | cut -c1)

        rm -f -- "$listing"
        return 0
    }

    # fn: _extract_archive - Extract the validated archive beneath DEST_ROOT
        # . Returns
        #   0 when extraction succeeds or dry-run reporting completes.
        #   1 when tar extraction fails.
        #
        # . Usage
        #   _extract_archive || return $?
    _extract_archive() {
        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Would extract $RECEIVED_COUNT archive entr$( (( RECEIVED_COUNT == 1 )) && printf 'y' || printf 'ies' ) beneath $DEST_ROOT"
            while IFS= read -r entry; do
                [[ -n "$entry" ]] && sgnd_print "$entry"
            done < <(tar -tf "$RECEIVED_ARCHIVE")
            return 0
        fi

        sayinfo "Extracting $RECEIVED_COUNT archive entr$( (( RECEIVED_COUNT == 1 )) && printf 'y' || printf 'ies' ) beneath $DEST_ROOT"

        tar \
            --extract \
            --file "$RECEIVED_ARCHIVE" \
            --directory "$DEST_ROOT" \
            --no-same-owner \
            --same-permissions \
            --overwrite || {
                sayfail "Failed to extract the received archive beneath: $DEST_ROOT"
                return 1
            }

        return 0
    }

# --- Main ----------------------------------------------------------------------------
    # fn: main - Receive, validate, and extract a streamed workspace archive
        # . Arguments
        #   $@  Framework and script-specific arguments.
        #
        # . Returns
        #   0 after successful validation and extraction.
        #   Non-zero when startup, validation, receiving, or extraction fails.
        #
        # . Usage
        #   main "$@"
    main() {
        _framework_locator || exit $?
        sgnd_exe_start -- "$@"

        _validate_target || return $?

        saystart "Receiving files for target root $DEST_ROOT"
        _receive_stream || return $?
        _validate_archive || return $?
        _extract_archive || return $?
        sayend "Received files were placed beneath $DEST_ROOT"
        return 0
    }

    main "$@"
