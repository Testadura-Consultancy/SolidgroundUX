#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Untar It
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623316
#   Checksum    : 77f601831325b2ef0cf88131863e3b6ed5da697eed19dd8275e51947372b5c5f
#   Source      : untar-it.sh
#   Type        : script
#   Group       : SDK
#   Purpose     : Restore selected files from a SolidGroundUX framework archive
#
# Description:
#   Selects a .tar.gz archive, validates its entry paths, extracts it into a temporary
#   staging directory, and restores files matching an optional directory and filename
#   mask beneath a selected target root.
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
        # . Returns
        #   0 when the executable common library was loaded.
        #   126 or 127 when bootstrap configuration cannot be resolved.
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
            if [[ $EUID -eq 0 ]]; then cfg="$cfg_sys"; else cfg="$cfg_user"; fi

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

            case "$fw_root" in /*) ;; *) return 126 ;; esac
            case "$app_root" in /*) ;; *) return 126 ;; esac

            mkdir -p "$(dirname "$cfg")" || return 127
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
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

# --- Script metadata ----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Un-tar it"
    : "${SGND_SCRIPT_DESC:=Restore selected files from a SolidGroundUX framework archive.}"
    : "${SGND_SCRIPT_VERSION:=1.8}"
    : "${SGND_SCRIPT_BUILD:=2621604}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

# --- Framework integration -----------------------------------------------------------
    SGND_USING=()

    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Restore without prompting|0|"
        "archive|f|value|ARCHIVE_FILE|Archive filename or absolute path|"
        "archive-dir|d|value|ARCHIVE_DIRECTORY|Directory containing framework archives|"
        "target|t|value|RESTORE_TARGET_ROOT|Filesystem root beneath which files are restored|"
        "directory||value|RESTORE_DIRECTORY|Optional directory within the archive|"
        "match|m|value|RESTORE_MATCH|Filename or shell-style file mask|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Select an archive and restore interactively:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Restore all shell files beneath the common library:"
        "  $SGND_SCRIPT_NAME --archive solidgroundux-20260804T010000.tar.gz --directory usr/local/lib/solidgroundux/common --match '*.sh'"
    )

    SGND_SCRIPT_GLOBALS=(SGND_ARCHIVE_DIR)

    SGND_STATE_VARIABLES=(
        ARCHIVE_DIRECTORY
        RESTORE_TARGET_ROOT
        RESTORE_DIRECTORY
        RESTORE_MATCH
    )

    SGND_ON_EXIT_HANDLERS=()
    SGND_STATE_SAVE=0

# --- Local declarations --------------------------------------------------------------
    ARCHIVE_FILE="${ARCHIVE_FILE:-}"
    ARCHIVE_DIRECTORY="${ARCHIVE_DIRECTORY:-}"
    RESTORE_TARGET_ROOT="${RESTORE_TARGET_ROOT:-}"
    RESTORE_DIRECTORY="${RESTORE_DIRECTORY:-}"
    RESTORE_MATCH="${RESTORE_MATCH:-}"
    AVAILABLE_ARCHIVES=()

    CLI_ARCHIVE_FILE=0
    CLI_ARCHIVE_DIRECTORY=0
    CLI_RESTORE_TARGET_ROOT=0
    CLI_RESTORE_DIRECTORY=0
    CLI_RESTORE_MATCH=0

    RESOLVED_ARCHIVE=""
    STAGING_ROOT=""
    SELECTED_FILES=()

# --- Helpers -------------------------------------------------------------------------
    # fn: _scan_cli_args - Record which restore settings were supplied explicitly
        # . Arguments
        #   $@  Original command-line arguments.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _scan_cli_args "$@"
    _scan_cli_args() {
        local arg=""
        local expect=""

        for arg in "$@"; do
            if [[ -n "$expect" ]]; then
                printf -v "$expect" '%s' 1
                expect=""
                continue
            fi
            case "$arg" in
                --archive=*) CLI_ARCHIVE_FILE=1 ;;
                --archive|-f) expect="CLI_ARCHIVE_FILE" ;;
                --archive-dir=*) CLI_ARCHIVE_DIRECTORY=1 ;;
                --archive-dir|-d) expect="CLI_ARCHIVE_DIRECTORY" ;;
                --target=*) CLI_RESTORE_TARGET_ROOT=1 ;;
                --target|-t) expect="CLI_RESTORE_TARGET_ROOT" ;;
                --directory=*) CLI_RESTORE_DIRECTORY=1 ;;
                --directory) expect="CLI_RESTORE_DIRECTORY" ;;
                --match=*) CLI_RESTORE_MATCH=1 ;;
                --match|-m) expect="CLI_RESTORE_MATCH" ;;
            esac
        done
    }

    # fn: _cleanup_staging - Remove the temporary extraction directory
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _cleanup_staging
    _cleanup_staging() {
        [[ -n "$STAGING_ROOT" && -d "$STAGING_ROOT" ]] && rm -rf -- "$STAGING_ROOT"
        return 0
    }

    # fn: _resolve_archive - Resolve ARCHIVE_FILE against ARCHIVE_DIRECTORY
        # . Returns
        #   0 when a readable archive is resolved; 1 otherwise.
        #
        # . Usage
        #   _resolve_archive || return $?
    _resolve_archive() {
        if [[ "$ARCHIVE_FILE" == /* ]]; then
            RESOLVED_ARCHIVE="$ARCHIVE_FILE"
        else
            RESOLVED_ARCHIVE="${ARCHIVE_DIRECTORY%/}/$ARCHIVE_FILE"
        fi

        [[ -r "$RESOLVED_ARCHIVE" ]] || {
            sayfail "Archive not found or unreadable: $RESOLVED_ARCHIVE"
            return 1
        }
        return 0
    }

    # fn: _list_archives - Build the available archive list, newest first
        # . Purpose
        #   Find readable .tar.gz archives in ARCHIVE_DIRECTORY and store their basenames.
        #
        # Outputs (globals):
        #   AVAILABLE_ARCHIVES
        #
        # . Returns
        #   0 when at least one archive is available; 1 otherwise.
        #
        # . Usage
        #   _list_archives || return $?
    _list_archives() {
        AVAILABLE_ARCHIVES=()

        [[ -d "$ARCHIVE_DIRECTORY" ]] || {
            sayfail "Archive directory not found: $ARCHIVE_DIRECTORY"
            return 1
        }

        mapfile -t AVAILABLE_ARCHIVES < <(
            find "$ARCHIVE_DIRECTORY" \
                -maxdepth 1 \
                -type f \
                -readable \
                -name '*.tar.gz' \
                -printf '%T@|%f\n' 2>/dev/null | \
            sort -nr | \
            cut -d'|' -f2-
        )

        if (( ${#AVAILABLE_ARCHIVES[@]} == 0 )); then
            saywarning "No readable .tar.gz archives found in $ARCHIVE_DIRECTORY."
            return 1
        fi

        return 0
    }

    # fn: _select_archive - Select an archive from the numbered archive list
        # . Purpose
        #   Display available archives and resolve a numeric user selection.
        #
        # Outputs (globals):
        #   ARCHIVE_FILE
        #
        # . Returns
        #   0 after a valid selection; non-zero when no archives are available.
        #
        # . Usage
        #   _select_archive || return $?
    _select_archive() {
        local selection=""

        _list_archives || return $?

        ask_selection \
            --label "Available archives in $ARCHIVE_DIRECTORY" \
            --var selection \
            --items "${AVAILABLE_ARCHIVES[@]}" || return 1

        ARCHIVE_FILE="$selection"
        return 0
    }

    # fn: _validate_archive_entries - Reject unsafe archive entry paths
        # . Returns
        #   0 when every archive path is safe and relative; 1 otherwise.
        #
        # . Usage
        #   _validate_archive_entries || return $?
    _validate_archive_entries() {
        local entry=""

        while IFS= read -r entry; do
            entry="${entry#./}"
            [[ -z "$entry" || "$entry" == "." ]] && continue
            if [[ "$entry" == /* || "$entry" == ".." || "$entry" == ../* || "$entry" == */../* || "$entry" == */.. ]]; then
                sayfail "Unsafe archive entry: $entry"
                return 1
            fi
        done < <(tar -tzf "$RESOLVED_ARCHIVE")

        return 0
    }

    # fn: _validate_parameters - Validate restore settings
        # . Returns
        #   0 when settings and archive are usable; 1 otherwise.
        #
        # . Usage
        #   _validate_parameters || return $?
    _validate_parameters() {
        case "$ARCHIVE_DIRECTORY" in /*) ;; *) sayfail "Archive directory must be absolute."; return 1 ;; esac
        case "$RESTORE_TARGET_ROOT" in /*) ;; *) sayfail "Restore target root must be absolute."; return 1 ;; esac

        [[ -n "$ARCHIVE_FILE" ]] || {
            sayfail "An archive must be selected."
            return 1
        }

        if [[ -n "$RESTORE_DIRECTORY" ]]; then
            [[ "$RESTORE_DIRECTORY" != /* && "$RESTORE_DIRECTORY" != ".." && "$RESTORE_DIRECTORY" != ../* && "$RESTORE_DIRECTORY" != */../* ]] || {
                sayfail "Restore directory must be relative and remain inside the archive."
                return 1
            }
            RESTORE_DIRECTORY="${RESTORE_DIRECTORY#./}"
            RESTORE_DIRECTORY="${RESTORE_DIRECTORY%/}"
        fi

        : "${RESTORE_MATCH:=*}"
        _resolve_archive || return $?
        _validate_archive_entries
    }

    # fn: _getparameters - Resolve and confirm restore settings
        # . Returns
        #   0 when settings are valid and confirmed; 1 on cancellation.
        #
        # . Usage
        #   _getparameters || return $?
    _getparameters() {
        local reply=0

        : "${ARCHIVE_DIRECTORY:=$SGND_ARCHIVE_DIR}"
        : "${RESTORE_TARGET_ROOT:=$SGND_FRAMEWORK_ROOT}"
        : "${RESTORE_DIRECTORY:=}"
        : "${RESTORE_MATCH:=*}"

        if [[ "${FLAG_AUTO:-0}" -eq 1 ]]; then
            _validate_parameters
            return $?
        fi

        while true; do
            if [[ "$CLI_ARCHIVE_DIRECTORY" -eq 0 ]]; then
                sgnd_print "Enter the directory containing SolidGroundUX archives."
                ask --label "Archive directory" --var ARCHIVE_DIRECTORY --default "$ARCHIVE_DIRECTORY" --colorize both
            fi

            if [[ "$CLI_ARCHIVE_FILE" -eq 0 ]]; then
                sgnd_print "Select the archive to restore. Archives are listed newest first."
                _select_archive || {
                    saywarning "Choose another archive directory."
                    continue
                }
            fi

            if [[ "$CLI_RESTORE_TARGET_ROOT" -eq 0 ]]; then
                sgnd_print "Enter the filesystem root beneath which archived paths are restored."
                ask --label "Target root" --var RESTORE_TARGET_ROOT --default "$RESTORE_TARGET_ROOT" --colorize both
            fi

            if [[ "$CLI_RESTORE_DIRECTORY" -eq 0 ]]; then
                sgnd_print "Optionally restrict restoration to one directory inside the archive."
                sgnd_print "Leave empty to search the complete archive."
                ask --label "Directory" --var RESTORE_DIRECTORY --default "$RESTORE_DIRECTORY" --colorize both
            fi

            if [[ "$CLI_RESTORE_MATCH" -eq 0 ]]; then
                sgnd_print "Enter a filename or shell-style mask. Use * to restore all matching files."
                ask --label "File or mask" --var RESTORE_MATCH --default "$RESTORE_MATCH" --colorize both
            fi

            _validate_parameters || {
                saywarning "Please correct the restore settings."
                continue
            }

            ask_dlg_autocontinue --seconds 15 --message "Inspect and restore the matching files?" --redo --cancel
            reply=$?
            case "$reply" in
                0|1) return 0 ;;
                2) saycancel "Restore cancelled."; return 1 ;;
                3) continue ;;
                *) sayfail "Unexpected confirmation response: $reply"; return 1 ;;
            esac
        done
    }

    # fn: _extract_staging - Extract the validated archive into temporary staging
        # . Returns
        #   0 on success; non-zero on extraction failure.
        #
        # . Usage
        #   _extract_staging || return $?
    _extract_staging() {
        STAGING_ROOT="$(mktemp -d)" || return 1
        tar -xzf "$RESOLVED_ARCHIVE" -C "$STAGING_ROOT" --no-same-owner || {
            sayfail "Cannot extract archive into staging."
            return 1
        }
        return 0
    }

    # fn: _select_files - Select staged files using directory and filename mask
        # . Outputs (globals)
        #   SELECTED_FILES
        #
        # . Returns
        #   0 when one or more files match; 1 otherwise.
        #
        # . Usage
        #   _select_files || return $?
    _select_files() {
        local search_root="$STAGING_ROOT"
        local file=""
        local rel=""

        SELECTED_FILES=()
        [[ -n "$RESTORE_DIRECTORY" ]] && search_root="$STAGING_ROOT/$RESTORE_DIRECTORY"

        [[ -d "$search_root" ]] || {
            sayfail "Directory not present in archive: ${RESTORE_DIRECTORY:-.}"
            return 1
        }

        while IFS= read -r -d '' file; do
            rel="${file#"$STAGING_ROOT"/}"
            [[ "$(basename -- "$rel")" == $RESTORE_MATCH ]] || continue
            SELECTED_FILES+=("$rel")
        done < <(find "$search_root" \( -type f -o -type l \) -print0)

        if (( ${#SELECTED_FILES[@]} == 0 )); then
            saywarning "No archived files matched the restore selection."
            return 1
        fi

        mapfile -d '' -t SELECTED_FILES < <(printf '%s\0' "${SELECTED_FILES[@]}" | sort -zu)
        return 0
    }

    # fn: _restore_files - Restore selected staged files beneath the target root
        # . Returns
        #   0 after successful restoration; non-zero on failure.
        #
        # . Usage
        #   _restore_files
    _restore_files() {
        local rel=""
        local src=""
        local dst=""

        saystart "Restoring ${#SELECTED_FILES[@]} file(s) from $RESOLVED_ARCHIVE"

        for rel in "${SELECTED_FILES[@]}"; do
            src="$STAGING_ROOT/$rel"
            dst="${RESTORE_TARGET_ROOT%/}/$rel"

            if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
                sayinfo "Would restore $rel -> $dst"
                continue
            fi

            install -d -m 755 -- "$(dirname -- "$dst")" || {
                sayfail "Cannot create restore directory: $(dirname -- "$dst")"
                return 1
            }

            cp -a -- "$src" "$dst" || {
                sayfail "Cannot restore: $rel"
                return 1
            }
            sayinfo "Restored $rel"
        done

        [[ "${FLAG_DRYRUN:-0}" -eq 1 ]] || SGND_STATE_SAVE=1
        sayend "Restore complete."
        return 0
    }

# --- Main ----------------------------------------------------------------------------
    # fn: main - Run the selective restore workflow
        # . Arguments
        #   $@  Framework and script-specific arguments.
        #
        # . Returns
        #   Workflow exit status.
        #
        # . Usage
        #   main "$@"
    main() {
        _scan_cli_args "$@"
        _framework_locator || exit $?
        sgnd_exe_start --state -- "$@"

        SGND_ON_EXIT_HANDLERS+=( _cleanup_staging )

        _getparameters || return $?
        _extract_staging || return $?
        _select_files || return $?
        sgnd_print_titlebar
        _restore_files
    }

    main "$@"
