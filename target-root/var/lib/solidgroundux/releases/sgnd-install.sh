#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Install Release Package
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608802
#   Checksum    : -
#   Source      : sgnd-install.sh
#   Type        : script
#   Group       : Deployment
#   Purpose     : Install or update a packaged SolidGroundUX release in a target root.
#
# Description:
#   Standalone installer for SolidGroundUX release archives.
#
#   The installer scans or accepts a release archive, validates the matching archive
#   and manifest checksums, backs up existing affected files, extracts the package
#   into the selected target root, and records install state for later updates and
#   uninstallation.
#
# Design:
#   - Standalone: does not depend on an installed SolidGroundUX runtime.
#   - Version-aware: selects the newest matching package by parsed build number.
#   - Safe by default: validates release artifacts and creates backups before install.
#   - Repeatable: records manifest and metadata under the installer state root.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

set -uo pipefail

# var: Installer runtime state - Command-line flags, selected paths, and display constants
    # . Purpose
    #   Defines mutable installer state initialized before argument parsing.
    #
    # . Variables
    #   FLAG_MANUAL
    #       Enables manual package selection.
    #
    #   FLAG_FORCE
    #       Reserved reinstall or downgrade override flag.
    #
    #   FLAG_NO_BACKUP
    #       Disables backup creation when set.
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
    #   VAL_PRODUCT
    #       Optional product filter for package selection.
    #
    #   VAL_RELEASES_DIR
    #       Directory containing release archives and manifests.
    #
    #   VAL_TARGET_ROOT
    #       Root path into which the package is installed.
    #
    #   VAL_BACKUP_ROOT
    #       Directory used for install backups.
    #
    #   VAL_STATE_ROOT
    #       Directory used for installer state records.
    #
    #   VAL_SELECTED_PACKAGE
    #       Explicit package selected through --package.
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
FLAG_FORCE=0
FLAG_NO_BACKUP=0
FLAG_VERBOSE=0
FLAG_DEBUG=0
FLAG_DRYRUN=0

VAL_PRODUCT=""
VAL_RELEASES_DIR=""
VAL_TARGET_ROOT="/"
VAL_BACKUP_ROOT=""
VAL_STATE_ROOT=""
VAL_SELECTED_PACKAGE=""

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

# fn: print_usage - Print installer usage
    # . Purpose
    #   Prints installer usage, options, default paths, and package selection rules.
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
        '  --product NAME         Limit candidate packages to the given product' \
        '  --manual               Select a package manually from a list' \
        '  --package FILE         Install a specific package archive' \
        '  --releases-dir PATH    Releases directory to scan' \
        '  --target-root PATH     Target root to install into (default: /)' \
        '  --backup-root PATH     Backup root directory' \
        '  --state-root PATH      Installer state root directory' \
        '  --no-backup            Skip backup creation' \
        '  --force                Accepted for future reinstall or downgrade handling; currently reserved' \
        '  --dryrun               Show actions without changing the filesystem' \
        '  --verbose              Show informational logging' \
        '  --debug                Show debug logging' \
        '  --help                 Show this help' \
        '' \
        'Default locations:' \
        '  releases-dir : <target-root>/var/lib/solidgroundux/releases' \
        '  backup-root  : <target-root>/var/lib/solidgroundux/backups' \
        '  state-root   : <target-root>/var/lib/solidgroundux' \
        '' \
        'Selection rules:' \
        '  - In automatic mode the newest package is selected by highest build number.' \
        '  - If --product is given, only matching product packages are considered.' \
        '  - If --manual is given, a menu is shown for selection.'
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

# fn: parse_args - Parse installer arguments
    # . Purpose
    #   Parses installer command-line options into global flags and value variables.
    #
    # . Arguments
    #   $@  Installer command-line arguments.
    #
    # . Returns
    #   0 when parsing succeeds; non-zero on invalid or incomplete options.
    #
    # . Usage
    #   parse_args "$@"
parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --product)
                shift
                VAL_PRODUCT="${1:-}"
                [[ -n "$VAL_PRODUCT" ]] || { sayfail "--product requires a value"; return 1; }
                ;;
            --manual)
                FLAG_MANUAL=1
                ;;
            --package)
                shift
                VAL_SELECTED_PACKAGE="${1:-}"
                [[ -n "$VAL_SELECTED_PACKAGE" ]] || { sayfail "--package requires a value"; return 1; }
                ;;
            --releases-dir)
                shift
                VAL_RELEASES_DIR="${1:-}"
                [[ -n "$VAL_RELEASES_DIR" ]] || { sayfail "--releases-dir requires a value"; return 1; }
                ;;
            --target-root)
                shift
                VAL_TARGET_ROOT="${1:-}"
                [[ -n "$VAL_TARGET_ROOT" ]] || { sayfail "--target-root requires a value"; return 1; }
                ;;
            --backup-root)
                shift
                VAL_BACKUP_ROOT="${1:-}"
                [[ -n "$VAL_BACKUP_ROOT" ]] || { sayfail "--backup-root requires a value"; return 1; }
                ;;
            --state-root)
                shift
                VAL_STATE_ROOT="${1:-}"
                [[ -n "$VAL_STATE_ROOT" ]] || { sayfail "--state-root requires a value"; return 1; }
                ;;
            --no-backup)
                FLAG_NO_BACKUP=1
                ;;
            --force)
                FLAG_FORCE=1
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

# fn: init_paths - Initialize installer paths
    # . Purpose
    #   Initializes default releases, backup, and state paths below the selected target root.
    #
    # . Returns
    #   0.
    #
    # . Usage
    #   init_paths
init_paths() {
    VAL_TARGET_ROOT="${VAL_TARGET_ROOT%/}"
    [[ -n "$VAL_TARGET_ROOT" ]] || VAL_TARGET_ROOT="/"

    if [[ -z "$VAL_RELEASES_DIR" ]]; then
        VAL_RELEASES_DIR="$(normalize_rooted_path "$VAL_TARGET_ROOT" "/var/lib/solidgroundux/releases")"
    fi

    if [[ -z "$VAL_BACKUP_ROOT" ]]; then
        VAL_BACKUP_ROOT="$(normalize_rooted_path "$VAL_TARGET_ROOT" "/var/lib/solidgroundux/backups")"
    fi

    if [[ -z "$VAL_STATE_ROOT" ]]; then
        VAL_STATE_ROOT="$(normalize_rooted_path "$VAL_TARGET_ROOT" "/var/lib/solidgroundux")"
    fi
}

# fn: release_base_from_archive - Derive release base from archive
    # . Purpose
    #   Derives the release base name from a .tar.gz archive path.
    #
    # . Arguments
    #   $1  Archive path.
    #
    # . Returns
    #   Prints the release base name.
    #
    # . Usage
    #   release_base_from_archive "$archive"
release_base_from_archive() {
    local archive="${1:?missing archive}"
    local name=""

    name="$(basename -- "$archive")"
    name="${name%.tar.gz}"
    printf '%s\n' "$name"
}

# fn: release_build_from_base - Extract release build number
    # . Purpose
    #   Extracts the numeric build component from a release base name.
    #
    # . Arguments
    #   $1  Release base name.
    #
    # . Returns
    #   Prints the build number; returns non-zero when no build component is found.
    #
    # . Usage
    #   release_build_from_base "$base"
release_build_from_base() {
    local base="${1:?missing base}"
    local build="${base##*.}"

    [[ "$build" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$build"
}

# fn: release_product_from_base - Extract release product name
    # . Purpose
    #   Extracts the product name from a release base name.
    #
    # . Arguments
    #   $1  Release base name.
    #
    # . Returns
    #   Prints the product name before the first dash.
    #
    # . Usage
    #   release_product_from_base "$base"
release_product_from_base() {
    local base="${1:?missing base}"
    local product="${base%%-*}"
    printf '%s\n' "$product"
}

# fn: find_candidate_archives - Find candidate release archives
    # . Purpose
    #   Lists candidate .tar.gz release archives from the configured releases directory.
    #
    # . Returns
    #   Matching archive paths on stdout.
    #
    # . Usage
    #   find_candidate_archives
find_candidate_archives() {
    [[ -d "$VAL_RELEASES_DIR" ]] || {
        sayfail "Releases directory not found: $VAL_RELEASES_DIR"
        return 1
    }

    find "$VAL_RELEASES_DIR" -maxdepth 1 -type f -name '*.tar.gz' | sort
}

# fn: build_package_table - Build package selection table
    # . Purpose
    #   Builds sortable package table rows from candidate release archives.
    #
    # . Returns
    #   Tab-separated product, build, base, and archive rows on stdout.
    #
    # . Usage
    #   build_package_table
build_package_table() {
    local archive=""
    local base=""
    local build=""
    local product=""

    while IFS= read -r archive; do
        [[ -n "$archive" ]] || continue

        base="$(release_base_from_archive "$archive")"
        build="$(release_build_from_base "$base" 2>/dev/null || true)"
        [[ -n "$build" ]] || {
            saywarning "Skipping archive without parseable build number: $(basename -- "$archive")"
            continue
        }

        product="$(release_product_from_base "$base")"

        if [[ -n "$VAL_PRODUCT" && "$product" != "$VAL_PRODUCT" ]]; then
            continue
        fi

        printf '%s\t%s\t%s\t%s\n' "$product" "$build" "$base" "$archive"
    done < <(find_candidate_archives)
}

# fn: select_latest_archive - Select newest release archive
    # . Purpose
    #   Selects the newest available package by highest parsed build number.
    #
    # . Returns
    #   Prints the selected archive path; non-zero when no package is available.
    #
    # . Usage
    #   select_latest_archive
select_latest_archive() {
    local product=""
    local build=""
    local base=""
    local archive=""
    local best_build=""
    local best_archive=""

    while IFS=$'\t' read -r product build base archive; do
        [[ -n "$archive" ]] || continue

        if [[ -z "$best_build" || 10#$build -gt 10#$best_build ]]; then
            best_build="$build"
            best_archive="$archive"
        fi
    done < <(build_package_table)

    [[ -n "$best_archive" ]] || return 1
    printf '%s\n' "$best_archive"
}

# fn: select_manual_archive - Select release archive manually
    # . Purpose
    #   Prompts for manual selection from available release packages.
    #
    # . Returns
    #   Prints the selected archive path; non-zero when selection fails.
    #
    # . Usage
    #   select_manual_archive
select_manual_archive() {
    local entries=()
    local display=()
    local product=""
    local build=""
    local base=""
    local archive=""
    local index=0
    local choice=""

    while IFS=$'\t' read -r product build base archive; do
        [[ -n "$archive" ]] || continue
        entries+=("$archive")
        display+=("$product | build $build | $(basename -- "$archive")")
    done < <(build_package_table | sort -t $'\t' -k2,2nr -k1,1)

    (( ${#entries[@]} > 0 )) || return 1

    printf 'Available packages:\n' >&2
    for index in "${!entries[@]}"; do
        printf '  %2d) %s\n' "$((index + 1))" "${display[$index]}" >&2
    done

    while true; do
        printf 'Select package number [1-%d, q=quit]: ' "${#entries[@]}" > /dev/tty
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

# fn: resolve_selected_archive - Resolve selected release archive
    # . Purpose
    #   Resolves the package archive to install from explicit, manual, or automatic selection.
    #
    # . Returns
    #   Prints the selected archive path; non-zero when no valid archive is selected.
    #
    # . Usage
    #   resolve_selected_archive
resolve_selected_archive() {
    local candidate=""

    if [[ -n "$VAL_SELECTED_PACKAGE" ]]; then
        if [[ -f "$VAL_SELECTED_PACKAGE" ]]; then
            printf '%s\n' "$(readlink -f "$VAL_SELECTED_PACKAGE")"
            return 0
        fi

        candidate="${VAL_RELEASES_DIR%/}/$VAL_SELECTED_PACKAGE"
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$(readlink -f "$candidate")"
            return 0
        fi

        sayfail "Selected package not found: $VAL_SELECTED_PACKAGE"
        return 1
    fi

    if (( FLAG_MANUAL )); then
        select_manual_archive
        return $?
    fi

    select_latest_archive
}

# fn: verify_sha256_file - Verify a file checksum
    # . Purpose
    #   Verifies one file using its checksum file.
    #
    # . Arguments
    #   $1  File path to verify.
    #   $2  Checksum file path.
    #
    # . Returns
    #   0 when verification succeeds; non-zero when checksum validation fails.
    #
    # . Usage
    #   verify_sha256_file "$archive" "$archive_sha"
verify_sha256_file() {
    local file_path="${1:?missing file}"
    local sha_file="${2:?missing sha file}"

    [[ -f "$file_path" ]] || { sayfail "File not found: $file_path"; return 1; }
    [[ -f "$sha_file" ]] || { sayfail "Checksum file not found: $sha_file"; return 1; }

    (
        cd -- "$(dirname -- "$file_path")" || exit 1
        sha256sum -c -- "$(basename -- "$sha_file")"
    ) >/dev/null 2>&1 || {
        sayfail "Checksum verification failed: $(basename -- "$file_path")"
        return 1
    }

    sayok "Verified checksum: $(basename -- "$file_path")"
}

# fn: verify_release_set - Verify release artifact set
    # . Purpose
    #   Verifies the selected archive and matching manifest using their checksum files.
    #
    # . Arguments
    #   $1  Archive path.
    #
    # . Returns
    #   Prints the manifest path when all required release artifacts validate.
    #
    # . Usage
    #   verify_release_set "$archive"
verify_release_set() {
    local archive="${1:?missing archive}"
    local base=""
    local manifest=""
    local archive_sha=""
    local manifest_sha=""

    base="$(release_base_from_archive "$archive")"
    manifest="$(dirname -- "$archive")/${base}.manifest"
    archive_sha="${archive}.sha256"
    manifest_sha="${manifest}.sha256"

    [[ -f "$manifest" ]] || { sayfail "Manifest not found: $manifest"; return 1; }
    [[ -f "$archive_sha" ]] || { sayfail "Archive checksum file not found: $archive_sha"; return 1; }
    [[ -f "$manifest_sha" ]] || { sayfail "Manifest checksum file not found: $manifest_sha"; return 1; }

    verify_sha256_file "$archive" "$archive_sha" || return 1
    verify_sha256_file "$manifest" "$manifest_sha" || return 1

    printf '%s\n' "$manifest"
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

# fn: backup_affected_paths - Back up affected target paths
    # . Purpose
    #   Creates a timestamped backup of target paths affected by the selected manifest.
    #
    # . Arguments
    #   $1  Manifest path.
    #   $2  Release base name.
    #
    # . Returns
    #   Prints the backup directory path, or an empty value when backups are skipped.
    #
    # . Usage
    #   backup_affected_paths "$manifest" "$base"
backup_affected_paths() {
    local manifest="${1:?missing manifest}"
    local release_base="${2:?missing release base}"
    local stamp=""
    local backup_dir=""
    local rel_path=""
    local source_path=""
    local dest_path=""
    local touched=0

    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="${VAL_BACKUP_ROOT%/}/${stamp}-${release_base}"

    run_cmd mkdir -p "$backup_dir" || return 1

    while IFS= read -r rel_path; do
        [[ -n "$rel_path" ]] || continue

        source_path="$(normalize_rooted_path "$VAL_TARGET_ROOT" "$rel_path")"
        if [[ -e "$source_path" || -L "$source_path" ]]; then
            dest_path="${backup_dir%/}${rel_path}"
            run_cmd mkdir -p "$(dirname -- "$dest_path")" || return 1
            run_cmd cp -a "$source_path" "$dest_path" || return 1
            sayinfo "Backed up: $rel_path"
            touched=1
        else
            saydebug "Backup skip (missing): $rel_path"
        fi
    done < <(manifest_paths "$manifest")

    if (( touched == 0 )); then
        sayinfo "No existing files required backup"
    fi

    printf '%s\n' "$backup_dir"
}

# fn: extract_release_archive - Extract release archive
    # . Purpose
    #   Extracts the selected release archive into the configured target root.
    #
    # . Arguments
    #   $1  Archive path.
    #
    # . Returns
    #   0 when extraction succeeds.
    #
    # . Usage
    #   extract_release_archive "$archive"
extract_release_archive() {
    local archive="${1:?missing archive}"

    run_cmd mkdir -p "$VAL_TARGET_ROOT" || return 1
    run_cmd tar -xzpf "$archive" -C "$VAL_TARGET_ROOT" --no-same-owner || return 1
    sayok "Archive extracted into $VAL_TARGET_ROOT"
}

# fn: write_install_records - Write install records
    # . Purpose
    #   Stores the install manifest, install metadata, and current-install marker files.
    #
    # . Arguments
    #   $1  Archive path.
    #   $2  Package manifest path.
    #   $3  Optional backup directory path.
    #
    # . Returns
    #   0 when install records are written.
    #
    # . Usage
    #   write_install_records "$archive" "$manifest" "$backup_dir"
write_install_records() {
    local archive="${1:?missing archive}"
    local package_manifest="${2:?missing manifest}"
    local backup_dir="${3:-}"
    local base=""
    local installs_dir=""
    local install_manifest=""
    local meta_file=""
    local product=""
    local build=""

    base="$(release_base_from_archive "$archive")"
    product="$(release_product_from_base "$base")"
    build="$(release_build_from_base "$base")"

    installs_dir="${VAL_STATE_ROOT%/}/installed"
    install_manifest="${installs_dir%/}/${base}.install.manifest"
    meta_file="${installs_dir%/}/${base}.install.meta"

    run_cmd mkdir -p "$installs_dir" || return 1
    run_cmd mkdir -p "$VAL_STATE_ROOT" || return 1

    if (( FLAG_DRYRUN )); then
        printf '[DRYRUN] copy install manifest to: %s\n' "$install_manifest"
        printf '[DRYRUN] write install metadata to: %s\n' "$meta_file"
        printf '[DRYRUN] update current install markers under: %s\n' "$VAL_STATE_ROOT"
        return 0
    fi

    cp -f "$package_manifest" "$install_manifest" || return 1

    {
        printf 'ARCHIVE=%q
' "$archive"
        printf 'PACKAGE_MANIFEST=%q
' "$package_manifest"
        printf 'INSTALL_MANIFEST=%q
' "$install_manifest"
        printf 'BACKUP_DIR=%q
' "$backup_dir"
        printf 'TARGET_ROOT=%q
' "$VAL_TARGET_ROOT"
        printf 'INSTALLED_AT=%q
' "$(date -Is)"
        printf 'PRODUCT=%q
' "$product"
        printf 'BUILD=%q
' "$build"
        printf 'RELEASE_BASE=%q
' "$base"
    } > "$meta_file"

    printf '%s\n' "$base" > "${VAL_STATE_ROOT%/}/CURRENT"
    printf '%s\n' "$archive" > "${VAL_STATE_ROOT%/}/CURRENT.package"
    printf '%s\n' "$package_manifest" > "${VAL_STATE_ROOT%/}/CURRENT.package_manifest"
    printf '%s\n' "$install_manifest" > "${VAL_STATE_ROOT%/}/CURRENT.install_manifest"
    printf '%s\n' "$backup_dir" > "${VAL_STATE_ROOT%/}/CURRENT.backup"

    sayok "Recorded install metadata"
}

# fn: main - Run installer
    # . Purpose
    #   Runs installer validation, package selection, verification, backup, extraction, and state recording.
    #
    # . Arguments
    #   $@  Installer command-line arguments.
    #
    # . Returns
    #   Process exit status.
    #
    # . Usage
    #   main "$@"
main() {
    local archive=""
    local manifest=""
    local base=""
    local backup_dir=""

    require_command find || return 1
    require_command tar || return 1
    require_command sha256sum || return 1
    require_command cp || return 1
    require_command dirname || return 1
    require_command readlink || return 1

    parse_args "$@" || return 1
    init_paths

    saydebug "Target root   : $VAL_TARGET_ROOT"
    saydebug "Releases dir  : $VAL_RELEASES_DIR"
    saydebug "Backup root   : $VAL_BACKUP_ROOT"
    saydebug "State root    : $VAL_STATE_ROOT"
    saydebug "Product filter: ${VAL_PRODUCT:-<none>}"

    archive="$(resolve_selected_archive)" || {
        sayfail "No installable package could be selected"
        return 1
    }

    base="$(release_base_from_archive "$archive")"
    sayok "Selected package: $(basename -- "$archive")"

    manifest="$(verify_release_set "$archive")" || return 1
    sayok "Using manifest: $(basename -- "$manifest")"

    if (( ! FLAG_NO_BACKUP )); then
        backup_dir="$(backup_affected_paths "$manifest" "$base")" || return 1
        sayok "Backup created: $backup_dir"
    else
        saywarning "Backup disabled by --no-backup"
    fi

    extract_release_archive "$archive" || return 1
    write_install_records "$archive" "$manifest" "$backup_dir" || return 1

    sayok "Installation completed"
}

main "$@"
