#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Install Release Package
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608802
#   Checksum    :
#   Source      : sgnd-install.sh
#   Type        : script
#   Purpose     : Install a packaged SolidgroundUX release into a target root
#
# Description:
#   Standalone installer for SolidgroundUX release archives.
#
#   The script:
#     - Scans a releases directory for .tar.gz release archives
#     - Selects the newest matching release automatically by build number
#     - Optionally allows manual package selection
#     - Verifies archive and manifest checksum files before installation
#     - Backs up existing files and directories affected by the manifest
#     - Extracts the selected archive into a target root
#     - Writes install metadata and an install manifest to the target system
#
# Design principles:
#   - Standalone first: no framework bootstrap or library dependency
#   - Safe by default: verify and back up before extracting
#   - Deterministic automatic package selection
#   - Explicit manual override when desired
#   - Suitable for first-time framework installation
# =====================================================================================

set -uo pipefail

# --- Defaults ------------------------------------------------------------------------
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
  --product NAME         Limit candidate packages to the given product
  --manual               Select a package manually from a list
  --package FILE         Install a specific package archive
  --releases-dir PATH    Releases directory to scan
  --target-root PATH     Target root to install into (default: /)
  --backup-root PATH     Backup root directory
  --state-root PATH      Installer state root directory
  --no-backup            Skip backup creation
  --force                Continue when some target paths do not yet exist
  --dryrun               Show actions without changing the filesystem
  --verbose              Show informational logging
  --debug                Show debug logging
  --help                 Show this help

Default locations:
  releases-dir : <target-root>/var/lib/solidgroundux/releases
  backup-root  : <target-root>/var/lib/solidgroundux/backups
  state-root   : <target-root>/var/lib/solidgroundux

Selection rules:
  - In automatic mode the newest package is selected by highest build number.
  - If --product is given, only matching product packages are considered.
  - If --manual is given, a menu is shown for selection.
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
    #   Resolve installer working paths from target root and options.
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

# release_base_from_archive
    # Purpose:
    #   Return the archive basename without .tar.gz.
release_base_from_archive() {
    local archive="${1:?missing archive}"
    local name=""

    name="$(basename -- "$archive")"
    name="${name%.tar.gz}"
    printf '%s\n' "$name"
}

# release_build_from_base
    # Purpose:
    #   Return trailing numeric build from a release basename.
release_build_from_base() {
    local base="${1:?missing base}"
    local build="${base##*.}"

    [[ "$build" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$build"
}

# release_product_from_base
    # Purpose:
    #   Return product name inferred from release basename.
release_product_from_base() {
    local base="${1:?missing base}"
    local product="${base%%-*}"
    printf '%s\n' "$product"
}

# find_candidate_archives
    # Purpose:
    #   Scan the releases directory for candidate package archives.
find_candidate_archives() {
    [[ -d "$VAL_RELEASES_DIR" ]] || {
        sayfail "Releases directory not found: $VAL_RELEASES_DIR"
        return 1
    }

    find "$VAL_RELEASES_DIR" -maxdepth 1 -type f -name '*.tar.gz' | sort
}

# build_package_table
    # Purpose:
    #   Create a tab-separated package table for candidate archives.
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

# select_latest_archive
    # Purpose:
    #   Select the newest archive by numeric build number.
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

# select_manual_archive
    # Purpose:
    #   Present matching archives and let the user choose one.
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

# resolve_selected_archive
    # Purpose:
    #   Resolve the archive to install.
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

# verify_sha256_file
    # Purpose:
    #   Verify one file using a companion .sha256 file.
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

# verify_release_set
    # Purpose:
    #   Verify archive, manifest, and companion checksum files.
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

# backup_affected_paths
    # Purpose:
    #   Back up existing manifest paths into a timestamped backup root.
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

# extract_release_archive
    # Purpose:
    #   Extract a release archive into the target root.
extract_release_archive() {
    local archive="${1:?missing archive}"

    run_cmd mkdir -p "$VAL_TARGET_ROOT" || return 1
    run_cmd tar -xzpf "$archive" -C "$VAL_TARGET_ROOT" --no-same-owner || return 1
    sayok "Archive extracted into $VAL_TARGET_ROOT"
}

# write_install_records
    # Purpose:
    #   Write install manifest and install metadata to target state storage.
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

    cat > "$meta_file" <<EOF
ARCHIVE=$(printf '%q' "$archive")
PACKAGE_MANIFEST=$(printf '%q' "$package_manifest")
INSTALL_MANIFEST=$(printf '%q' "$install_manifest")
BACKUP_DIR=$(printf '%q' "$backup_dir")
TARGET_ROOT=$(printf '%q' "$VAL_TARGET_ROOT")
INSTALLED_AT=$(printf '%q' "$(date -Is)")
PRODUCT=$(printf '%q' "$product")
BUILD=$(printf '%q' "$build")
RELEASE_BASE=$(printf '%q' "$base")
EOF

    printf '%s\n' "$base" > "${VAL_STATE_ROOT%/}/CURRENT"
    printf '%s\n' "$archive" > "${VAL_STATE_ROOT%/}/CURRENT.package"
    printf '%s\n' "$package_manifest" > "${VAL_STATE_ROOT%/}/CURRENT.package_manifest"
    printf '%s\n' "$install_manifest" > "${VAL_STATE_ROOT%/}/CURRENT.install_manifest"
    printf '%s\n' "$backup_dir" > "${VAL_STATE_ROOT%/}/CURRENT.backup"

    sayok "Recorded install metadata"
}

# main
    # Purpose:
    #   Execute the standalone package installation flow.
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
