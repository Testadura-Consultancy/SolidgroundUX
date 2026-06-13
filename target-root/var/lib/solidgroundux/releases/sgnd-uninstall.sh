#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Uninstall Installed Release
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608802
#   Checksum    : -
#   Source      : sgnd-uninstall.sh
#   Type        : script
#   Group       : Deployment
#   Purpose     : Remove a previously installed SolidGroundUX release from a target root.
#
# Description:
#   Standalone uninstaller for SolidGroundUX install records.
#
#   The uninstaller reads install metadata from the selected target root, resolves
#   the release to remove, removes framework-owned files listed in the install
#   manifest, restores recorded backup content when available, and archives the
#   uninstall records for traceability.
#
# Design:
#   - Standalone: does not depend on an installed SolidGroundUX runtime.
#   - Manifest-driven: removes files based on recorded install manifests.
#   - Conservative: targets framework-owned files and preserves unrelated user data.
#   - Traceable: moves uninstall records into history instead of silently discarding them.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

set -uo pipefail

# var: Uninstaller runtime state - Command-line flags, selected paths, and display constants
    # . Purpose
    #   Defines mutable uninstaller state initialized before argument parsing.
    #
    # . Variables
    #   FLAG_MANUAL
    #       Enables manual installed-release selection.
    #
    #   FLAG_VERBOSE
    #       Enables informational logging.
    #
    #   FLAG_DEBUG
    #       Enables debug logging.
    #
    #   FLAG_DRYRUN
    #       Prints filesystem actions without executing them.
    #
    #   VAL_TARGET_ROOT
    #       Root path from which the release is uninstalled.
    #
    #   VAL_STATE_ROOT
    #       Directory used for installer state records.
    #
    #   VAL_RELEASE_BASE
    #       Explicit release base selected through --release.
    #
    #   SCRIPT_FILE, SCRIPT_BASE, SCRIPT_NAME
    #       Resolved script identity values used by usage output.
    #
    #   CLR_INFO, CLR_OK, CLR_WARN, CLR_FAIL, CLR_DEBUG, CLR_RESET
    #       Terminal color escape sequences used by status output.
    #
    # . Notes
    #   These values are intentionally global because this script is a standalone
    #   executable and does not depend on the SolidGroundUX runtime.

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

CLR_INFO=$'\e[38;5;250m'
CLR_OK=$'\e[38;5;82m'
CLR_WARN=$'\e[1;38;5;208m'
CLR_FAIL=$'\e[38;5;196m'
CLR_DEBUG=$'\e[1;35m'
CLR_RESET=$'\e[0m'

# fn: sayinfo - Write an informational message
    # . Purpose
    #   Writes an informational message to stderr when verbose logging is enabled.
    #
    # . Arguments
    #   $@  Message text to write.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   sayinfo "message"
sayinfo() {
    if (( FLAG_VERBOSE )); then
        printf '%sINFO%s  %s\n' "$CLR_INFO" "$CLR_RESET" "$*" >&2
    fi
}

# fn: sayok - Write a success message
    # . Purpose
    #   Writes a success message to stderr.
    #
    # . Arguments
    #   $@  Message text to write.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   sayok "message"
sayok() {
    printf '%sOK%s    %s\n' "$CLR_OK" "$CLR_RESET" "$*" >&2
}

# fn: saywarning - Write a warning message
    # . Purpose
    #   Writes a warning message to stderr.
    #
    # . Arguments
    #   $@  Message text to write.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   saywarning "message"
saywarning() {
    printf '%sWARN%s  %s\n' "$CLR_WARN" "$CLR_RESET" "$*" >&2
}

# fn: sayfail - Write a failure message
    # . Purpose
    #   Writes a failure message to stderr.
    #
    # . Arguments
    #   $@  Message text to write.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   sayfail "message"
sayfail() {
    printf '%sFAIL%s  %s\n' "$CLR_FAIL" "$CLR_RESET" "$*" >&2
}

# fn: saydebug - Write a debug message
    # . Purpose
    #   Writes a debug message to stderr when debug logging is enabled.
    #
    # . Arguments
    #   $@  Message text to write.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   saydebug "message"
saydebug() {
    if (( FLAG_DEBUG )); then
        printf '%sDEBUG%s %s\n' "$CLR_DEBUG" "$CLR_RESET" "$*" >&2
    fi
}

# fn: print_usage - Print uninstaller usage
    # . Purpose
    #   Prints uninstaller usage, options, default paths, and release selection rules.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   print_usage
print_usage() {
    printf '%s\n' \
        'Usage:' \
        "  $SCRIPT_NAME [options]" \
        '' \
        'Options:' \
        '  --release NAME         Uninstall the specified installed release base' \
        '  --manual               Select installed release manually' \
        '  --target-root PATH     Target root to uninstall from (default: /)' \
        '  --state-root PATH      Installer state root directory' \
        '  --dryrun               Show actions without changing the filesystem' \
        '  --verbose              Show informational logging' \
        '  --debug                Show debug logging' \
        '  --help                 Show this help' \
        '' \
        'Default locations:' \
        '  state-root : <target-root>/var/lib/solidgroundux' \
        '' \
        'Selection rules:' \
        '  - Without --release or --manual, the CURRENT installed release is used.' \
        '  - With --manual, a menu of installed releases is shown.'
}

# fn: run_cmd - Run a command with dry-run support
    # . Purpose
    #   Executes a command, or prints the command when dry-run mode is enabled.
    #
    # . Arguments
    #   $@  Command name followed by command arguments.
    #
    # . Returns
    #   Command exit status, or 0 in dry-run mode.
    #
    # . Usage
    #   run_cmd mkdir -p "$target_dir"
run_cmd() {
    if (( FLAG_DRYRUN )); then
        printf '[DRYRUN]'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi

    "$@"
}

# fn: require_command - Require an external command
    # . Purpose
    #   Verifies that a required external command is available on PATH.
    #
    # . Arguments
    #   $1  Command name to check.
    #
    # . Returns
    #   0 when available; non-zero when missing.
    #
    # . Usage
    #   require_command tar
require_command() {
    local cmd="${1:?missing command}"

    command -v "$cmd" >/dev/null 2>&1 || {
        sayfail "Required command not found: $cmd"
        return 1
    }
}

# fn: parse_args - Parse uninstaller arguments
    # . Purpose
    #   Parses uninstaller command-line options into global flags and value variables.
    #
    # . Arguments
    #   $@  Uninstaller command-line arguments.
    #
    # . Returns
    #   0 when parsing succeeds; non-zero on invalid or incomplete options.
    #
    # . Usage
    #   parse_args "$@"
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

# fn: normalize_rooted_path - Normalize a path below a target root
    # . Purpose
    #   Combines a target root and relative path into a normalized absolute target path.
    #
    # . Arguments
    #   $1  Target root path.
    #   $2  Path below the target root.
    #
    # . Returns
    #   Prints the normalized path.
    #
    # . Usage
    #   normalize_rooted_path "$VAL_TARGET_ROOT" "/var/lib/solidgroundux"
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

# fn: init_paths - Initialize uninstaller paths
    # . Purpose
    #   Initializes the default installer state path below the selected target root.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   init_paths
init_paths() {
    VAL_TARGET_ROOT="${VAL_TARGET_ROOT%/}"
    [[ -n "$VAL_TARGET_ROOT" ]] || VAL_TARGET_ROOT="/"

    if [[ -z "$VAL_STATE_ROOT" ]]; then
        VAL_STATE_ROOT="$(normalize_rooted_path "$VAL_TARGET_ROOT" "/var/lib/solidgroundux")"
    fi
}

# fn: list_installed_releases - List installed releases
    # . Purpose
    #   Lists installed release records from the installer state directory.
    #
    # . Returns
    #   Installed release base names on stdout.
    #
    # . Usage
    #   list_installed_releases
list_installed_releases() {
    local installs_dir="${VAL_STATE_ROOT%/}/installed"
    local file=""

    [[ -d "$installs_dir" ]] || return 1

    find "$installs_dir" -maxdepth 1 -type f -name '*.install.meta' | sort | while IFS= read -r file; do
        basename -- "$file" | sed 's/\.install\.meta$//'
    done
}

# fn: select_manual_release - Select installed release manually
    # . Purpose
    #   Prompts for manual selection from installed release records.
    #
    # . Returns
    #   Selected release base name on stdout; non-zero when selection fails.
    #
    # . Usage
    #   select_manual_release
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

# fn: resolve_release_base - Resolve release to uninstall
    # . Purpose
    #   Resolves the installed release to uninstall from explicit, manual, or CURRENT state.
    #
    # . Returns
    #   Selected release base name on stdout; non-zero when none can be selected.
    #
    # . Usage
    #   resolve_release_base
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

# fn: load_release_meta - Load installed release metadata
    # . Purpose
    #   Loads uninstall-relevant metadata for the selected installed release.
    #
    # . Arguments
    #   $1  Release base name.
    #
    # . Returns
    #   0 when metadata and install manifest are available.
    #
    # . Usage
    #   load_release_meta "$release_base"
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

# fn: manifest_paths - Read normalized manifest paths
    # . Purpose
    #   Reads normalized installable or removable paths from a manifest file.
    #
    # . Arguments
    #   $1  Manifest path to read.
    #
    # . Returns
    #   Prints normalized manifest paths on stdout.
    #
    # . Usage
    #   manifest_paths "$manifest"
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

# fn: remove_installed_paths - Remove installed paths
    # . Purpose
    #   Removes files and empty directories listed in the install manifest from the target root.
    #
    # . Arguments
    #   $1  Install manifest path.
    #
    # . Returns
    #   0 when the removal pass completes.
    #
    # . Usage
    #   remove_installed_paths "$INSTALL_MANIFEST"
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

# fn: restore_backup - Restore recorded backup
    # . Purpose
    #   Restores files from the recorded backup directory when one is available.
    #
    # . Arguments
    #   $1  Optional backup directory path.
    #
    # . Returns
    #   0 when no restore is needed or restore succeeds.
    #
    # . Usage
    #   restore_backup "$BACKUP_DIR"
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

# fn: archive_uninstall_records - Archive uninstall records
    # . Purpose
    #   Moves install records for the uninstalled release into uninstall history.
    #
    # . Arguments
    #   $1  Release base name.
    #
    # . Returns
    #   0 when records are archived or dry-run reports the intended action.
    #
    # . Usage
    #   archive_uninstall_records "$release_base"
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

# fn: main - Run uninstaller
    # . Purpose
    #   Runs uninstaller validation, release selection, metadata loading, removal, optional restore, and record archiving.
    #
    # . Arguments
    #   $@  Uninstaller command-line arguments.
    #
    # . Returns
    #   Process exit status.
    #
    # . Usage
    #   main "$@"
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
