#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Uninstall Installed Release
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608802
#   Checksum    :
#   Source      : sgnd-uninstall.sh
#   Type        : script
#   Purpose     : Uninstall a previously installed SolidgroundUX release from a target root
#
# Description:
#   Standalone uninstaller for SolidgroundUX installed release records.
#
#   The script:
#     - Reads installed release metadata from the target system
#     - Selects the current or a specific installed release
#     - Removes files and directories listed in the install manifest
#     - Restores backed-up files when a backup snapshot exists
#     - Moves uninstall records to a history directory
#
# Design principles:
#   - Standalone first: no framework bootstrap or library dependency
#   - Operates from install records stored on the target system
#   - Safe by default: restore backup after removal when available
#   - Explicit selection for manual or specific uninstall
# =====================================================================================

set -uo pipefail

# --- Defaults ------------------------------------------------------------------------
FLAG_MANUAL=0
FLAG_VERBOSE=0
FLAG_DEBUG=0
FLAG_DRYRUN=0

VAL_TARGET_ROOT="/"
VAL_STATE_ROOT=""
VAL_RELEASE_BASE=""

SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_BASE="$(basename -- "$SCRIPT_FILE")"
SCRIPT_NAME="${SCRIPT_BASE%.sh}"

# --- Minimal UI ----------------------------------------------------------------------
CLR_INFO=$'\e[38;5;250m'
CLR_OK=$'\e[38;5;82m'
CLR_WARN=$'\e[1;38;5;208m'
CLR_FAIL=$'\e[38;5;196m'
CLR_DEBUG=$'\e[1;35m'
CLR_RESET=$'\e[0m'

sayinfo() {
    if (( FLAG_VERBOSE )); then
        printf '%sINFO%s  %s\n' "$CLR_INFO" "$CLR_RESET" "$*" >&2
    fi
}

sayok() {
    printf '%sOK%s    %s\n' "$CLR_OK" "$CLR_RESET" "$*" >&2
}

saywarning() {
    printf '%sWARN%s  %s\n' "$CLR_WARN" "$CLR_RESET" "$*" >&2
}

sayfail() {
    printf '%sFAIL%s  %s\n' "$CLR_FAIL" "$CLR_RESET" "$*" >&2
}

saydebug() {
    if (( FLAG_DEBUG )); then
        printf '%sDEBUG%s %s\n' "$CLR_DEBUG" "$CLR_RESET" "$*" >&2
    fi
}

# print_usage
    # Purpose:
    #   Print command usage and supported options.
print_usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME [options]

Options:
  --release NAME         Uninstall the specified installed release base
  --manual               Select installed release manually
  --target-root PATH     Target root to uninstall from (default: /)
  --state-root PATH      Installer state root directory
  --dryrun               Show actions without changing the filesystem
  --verbose              Show informational logging
  --debug                Show debug logging
  --help                 Show this help

Default locations:
  state-root : <target-root>/var/lib/solidgroundux

Selection rules:
  - Without --release or --manual, the CURRENT installed release is used.
  - With --manual, a menu of installed releases is shown.
EOF
}

# run_cmd
    # Purpose:
    #   Execute a command or echo it in dry-run mode.
run_cmd() {
    if (( FLAG_DRYRUN )); then
        printf '[DRYRUN]'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi

    "$@"
}

# require_command
    # Purpose:
    #   Ensure an external command is available.
require_command() {
    local cmd="${1:?missing command}"

    command -v "$cmd" >/dev/null 2>&1 || {
        sayfail "Required command not found: $cmd"
        return 1
    }
}

# parse_args
    # Purpose:
    #   Parse script arguments into global option variables.
parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --release)
                shift
                VAL_RELEASE_BASE="${1:-}"
                [[ -n "$VAL_RELEASE_BASE" ]] || { sayfail "--release requires a value"; return 1; }
                ;;
            --manual)
                FLAG_MANUAL=1
                ;;
            --target-root)
                shift
                VAL_TARGET_ROOT="${1:-}"
                [[ -n "$VAL_TARGET_ROOT" ]] || { sayfail "--target-root requires a value"; return 1; }
                ;;
            --state-root)
                shift
                VAL_STATE_ROOT="${1:-}"
                [[ -n "$VAL_STATE_ROOT" ]] || { sayfail "--state-root requires a value"; return 1; }
                ;;
            --verbose)
                FLAG_VERBOSE=1
                ;;
            --debug)
                FLAG_DEBUG=1
                ;;
            --dryrun)
                FLAG_DRYRUN=1
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                sayfail "Unknown argument: $1"
                return 1
                ;;
        esac
        shift
    done

    return 0
}

# normalize_rooted_path
    # Purpose:
    #   Join a target root with an absolute-style path.
normalize_rooted_path() {
    local root="${1:?missing root}"
    local rel="${2:?missing relative path}"

    root="${root%/}"
    [[ -n "$root" ]] || root="/"

    if [[ "$rel" == "/" ]]; then
        printf '%s\n' "$root"
    else
        printf '%s/%s\n' "$root" "${rel#/}"
    fi
}

# init_paths
    # Purpose:
    #   Resolve working paths from target root and options.
init_paths() {
    VAL_TARGET_ROOT="${VAL_TARGET_ROOT%/}"
    [[ -n "$VAL_TARGET_ROOT" ]] || VAL_TARGET_ROOT="/"

    if [[ -z "$VAL_STATE_ROOT" ]]; then
        VAL_STATE_ROOT="$(normalize_rooted_path "$VAL_TARGET_ROOT" "/var/lib/solidgroundux")"
    fi
}

# list_installed_releases
    # Purpose:
    #   List installed release bases from install metadata.
list_installed_releases() {
    local installs_dir="${VAL_STATE_ROOT%/}/installed"
    local file=""

    [[ -d "$installs_dir" ]] || return 1

    find "$installs_dir" -maxdepth 1 -type f -name '*.install.meta' | sort | while IFS= read -r file; do
        basename -- "$file" | sed 's/\.install\.meta$//'
    done
}

# select_manual_release
    # Purpose:
    #   Present installed releases and let the user choose one.
select_manual_release() {
    local entries=()
    local entry=""
    local index=0
    local choice=""

    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        entries+=("$entry")
    done < <(list_installed_releases)

    (( ${#entries[@]} > 0 )) || return 1

    printf 'Installed releases:\n' >&2
    for index in "${!entries[@]}"; do
        printf '  %2d) %s\n' "$((index + 1))" "${entries[$index]}" >&2
    done

    while true; do
        printf 'Select installed release [1-%d, q=quit]: ' "${#entries[@]}" > /dev/tty
        IFS= read -r choice < /dev/tty || return 1

        case "$choice" in
            q|Q)
                return 1
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#entries[@]} )); then
                    printf '%s\n' "${entries[$((choice - 1))]}"
                    return 0
                fi
                ;;
        esac

        saywarning "Invalid selection"
    done
}

# resolve_release_base
    # Purpose:
    #   Resolve which installed release base to uninstall.
resolve_release_base() {
    local current_file=""

    if [[ -n "$VAL_RELEASE_BASE" ]]; then
        printf '%s\n' "$VAL_RELEASE_BASE"
        return 0
    fi

    if (( FLAG_MANUAL )); then
        select_manual_release
        return $?
    fi

    current_file="${VAL_STATE_ROOT%/}/CURRENT"
    [[ -f "$current_file" ]] || {
        sayfail "Current install marker not found: $current_file"
        return 1
    }

    read -r VAL_RELEASE_BASE < "$current_file" || return 1
    [[ -n "$VAL_RELEASE_BASE" ]] || return 1
    printf '%s\n' "$VAL_RELEASE_BASE"
}

# load_release_meta
    # Purpose:
    #   Load install metadata for the selected release.
load_release_meta() {
    local release_base="${1:?missing release base}"
    local meta_file="${VAL_STATE_ROOT%/}/installed/${release_base}.install.meta"

    [[ -f "$meta_file" ]] || {
        sayfail "Install metadata not found: $meta_file"
        return 1
    }

    # shellcheck source=/dev/null
    source "$meta_file"

    [[ -n "${INSTALL_MANIFEST:-}" ]] || {
        sayfail "INSTALL_MANIFEST missing in metadata"
        return 1
    }

    [[ -f "$INSTALL_MANIFEST" ]] || {
        sayfail "Install manifest not found: $INSTALL_MANIFEST"
        return 1
    }

    return 0
}

# manifest_paths
    # Purpose:
    #   Extract installed paths from a manifest.
manifest_paths() {
    local manifest="${1:?missing manifest}"
    local raw=""
    local first=""

    while IFS= read -r raw || [[ -n "$raw" ]]; do
        [[ -n "${raw//[[:space:]]/}" ]] || continue
        [[ "$raw" =~ ^[[:space:]]*# ]] && continue

        first="${raw%%[[:space:]]*}"
        [[ -n "$first" ]] || continue

        case "$first" in
            .) continue ;;
            /*)  printf '%s\n' "$first" ;;
            ./*) printf '/%s\n' "${first#./}" ;;
            *)   printf '/%s\n' "$first" ;;
        esac
    done < "$manifest"
}

# remove_installed_paths
    # Purpose:
    #   Remove paths listed in the install manifest.
remove_installed_paths() {
    local manifest="${1:?missing manifest}"
    local rel_path=""
    local target_path=""

    manifest_paths "$manifest" | awk '{ print length($0), $0 }' | sort -rn | cut -d' ' -f2- | while IFS= read -r rel_path; do
        [[ -n "$rel_path" ]] || continue

        target_path="$(normalize_rooted_path "$VAL_TARGET_ROOT" "$rel_path")"

        if [[ -L "$target_path" || -f "$target_path" ]]; then
            run_cmd rm -f -- "$target_path" || return 1
            sayinfo "Removed file: $rel_path"
        elif [[ -d "$target_path" ]]; then
            run_cmd rmdir --ignore-fail-on-non-empty -- "$target_path" || return 1
            saydebug "Tried directory remove: $rel_path"
        else
            saydebug "Path already absent: $rel_path"
        fi
    done
}

# restore_backup
    # Purpose:
    #   Restore backed-up files into the target root.
restore_backup() {
    local backup_dir="${1:-}"

    if [[ -z "$backup_dir" ]]; then
        saywarning "No backup directory recorded"
        return 0
    fi

    if [[ ! -d "$backup_dir" ]]; then
        saywarning "Recorded backup directory not found: $backup_dir"
        return 0
    fi

    if (( FLAG_DRYRUN )); then
        printf '[DRYRUN] restore backup from %s to %s\n' "$backup_dir" "$VAL_TARGET_ROOT"
        return 0
    fi

    cp -a "${backup_dir%/}/." "$VAL_TARGET_ROOT/" || return 1
    sayok "Restored backup from $backup_dir"
}

# archive_uninstall_records
    # Purpose:
    #   Move install records to uninstall history and update current markers.
archive_uninstall_records() {
    local release_base="${1:?missing release base}"
    local history_dir="${VAL_STATE_ROOT%/}/history"
    local installs_dir="${VAL_STATE_ROOT%/}/installed"
    local manifest_file="${installs_dir%/}/${release_base}.install.manifest"
    local meta_file="${installs_dir%/}/${release_base}.install.meta"
    local stamp
    local history_prefix
    local current_name=""

    stamp="$(date +%Y%m%d-%H%M%S)"
    history_prefix="${history_dir%/}/${stamp}-${release_base}"

    run_cmd mkdir -p "$history_dir" || return 1
    run_cmd mv "$manifest_file" "${history_prefix}.install.manifest" || return 1
    run_cmd mv "$meta_file" "${history_prefix}.install.meta" || return 1

    if [[ -f "${VAL_STATE_ROOT%/}/CURRENT" ]]; then
        read -r current_name < "${VAL_STATE_ROOT%/}/CURRENT" || true
        if [[ "$current_name" == "$release_base" ]]; then
            if (( FLAG_DRYRUN )); then
                printf '[DRYRUN] clear current install markers under %s\n' "$VAL_STATE_ROOT"
            else
                : > "${VAL_STATE_ROOT%/}/CURRENT"
                rm -f \
                    "${VAL_STATE_ROOT%/}/CURRENT.package" \
                    "${VAL_STATE_ROOT%/}/CURRENT.package_manifest" \
                    "${VAL_STATE_ROOT%/}/CURRENT.install_manifest" \
                    "${VAL_STATE_ROOT%/}/CURRENT.backup"
            fi
        fi
    fi

    sayok "Archived uninstall records"
}

# main
    # Purpose:
    #   Execute the uninstall flow.
main() {
    local release_base=""

    require_command find || return 1
    require_command cp || return 1
    require_command awk || return 1
    require_command sort || return 1
    require_command cut || return 1
    require_command sed || return 1
    require_command rm || return 1
    require_command rmdir || return 1
    require_command mv || return 1

    parse_args "$@" || return 1
    init_paths

    saydebug "Target root : $VAL_TARGET_ROOT"
    saydebug "State root  : $VAL_STATE_ROOT"

    release_base="$(resolve_release_base)" || {
        sayfail "No installed release could be selected"
        return 1
    }

    sayok "Selected installed release: $release_base"
    load_release_meta "$release_base" || return 1

    remove_installed_paths "$INSTALL_MANIFEST" || return 1
    restore_backup "${BACKUP_DIR:-}" || return 1
    archive_uninstall_records "$release_base" || return 1

    sayok "Uninstall completed"
}

main "$@"
