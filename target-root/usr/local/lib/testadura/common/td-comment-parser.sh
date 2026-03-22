# =====================================================================================
# SolidgroundUX - Comment Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2602607900
#   Checksum    :
#   Source      : td-comment-parser.sh
#   Type        : library
#   Purpose     : Parse and update structured header comments in SolidgroundUX scripts
#
# Description:
#   Provides parsing and update utilities for structured script header comments
#   used throughout the SolidgroundUX framework.
#
#   The library:
#     - Detects and reads canonical header sections
#     - Extracts field/value pairs from structured comment blocks
#     - Loads header data into td-datatable structures
#     - Updates existing metadata field values while preserving formatting
#     - Adds missing fields where required
#     - Supports version, build, and checksum metadata workflows
#
# Design principles:
#   - Header comments are treated as structured, machine-readable data
#   - Parsing logic is independent from higher-level UI workflows
#   - Existing formatting is preserved when updating field values
#   - Header manipulation remains predictable and convention-based
#
# Role in framework:
#   - Core metadata parsing and update layer for script tooling
#   - Supports metadata-editor and other header-aware utilities
#
# Non-goals:
#   - Parsing arbitrary free-form comments outside canonical header sections
#   - Acting as a general-purpose text processing library
#   - Defining project policy beyond header comment conventions
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
    # __td_lib_guard
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
        #   TD_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
        #
        # Usage:
        #   __td_lib_guard
        #
        # Examples:
        #   # Typical usage at top of library file
        #   __td_lib_guard
        #   unset -f __td_lib_guard
        #
        # Notes:
        #   - Guard variable is derived dynamically (e.g. ui-glyphs.sh → TD_UI_GLYPHS_LOADED).
        #   - Safe under `set -u` due to indirect expansion with default.
    __td_lib_guard() {
        local lib_base
        local guard

        lib_base="$(basename "${BASH_SOURCE[0]}")"
        lib_base="${lib_base%.sh}"
        lib_base="${lib_base//-/_}"
        guard="TD_${lib_base^^}_LOADED"

        # Refuse to execute (library only)
        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            echo "This is a library; source it, do not execute it: ${BASH_SOURCE[0]}" >&2
            exit 2
        }

        # Load guard (safe under set -u)
        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    __td_lib_guard
    unset -f __td_lib_guard


# --- Internal helpers ---------------------------------------------------------------
# --- Public API ---------------------------------------------------------------------
    # __td_header_load_section_to_dt
            # Purpose:
            #   Load all key/value pairs from a header section into a td-datatable.
            #
            # Arguments:
            #   $1  FILE
            #   $2  SECTION
            #   $3  SCHEMA
            #   $4  TABLE_NAME
            #
            # Returns:
            #   0  success
            #   1  failure (e.g. td_dt_append error)
    td_header_load_section_to_dt() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local schema="${3:?missing schema}"
        local table_name="${4:?missing table name}"

        local line=""
        local key=""
        local value=""
        local in_section=0

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                continue
            fi

            if (( in_section )) && td_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line# }"

                key="${line%%:*}"
                value="${line#*:}"

                key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

                [[ -n "$key" ]] || continue

                td_dt_append "$schema" "$table_name" "$section" "$key" "$value" || return 1
            fi
        done < "$file"
    }
    # td_header_is_section_header
        # Purpose:
        #   Determine whether a line is a top-level script header section marker.
        #
        # Arguments:
        #   $1  LINE
        #
        # Returns:
        #   0  line is a section header
        #   1  line is not a section header
    td_header_is_section_header() {
        local line="${1-}"

        [[ "$line" =~ ^\#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]] || return 1
        [[ "$line" == "#   "* ]] && return 1
        return 0
    }

    # td_header_get_section
        # Purpose:
        #   Retrieve the full contents of a header section from a file.
        #
        # Behavior:
        #   - Scans the file from the top until non-comment content.
        #   - Locates the requested section header ("# Section:").
        #   - Collects all lines until the next section header.
        #   - Strips leading '#' and one space from each line.
        #
        # Arguments:
        #   $1  FILE
        #   $2  SECTION
        #   $3  RESULT_VAR (name of variable to receive output)
        #
        # Output:
        #   RESULT_VAR contains the section content as a multi-line string.
        #
        # Returns:
        #   0  section processed (may be empty)
        #   1  error reading file
    td_header_get_section() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local __resultvar="${3:?missing result var}"

        local line=""
        local capture=0
        local result=""

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            if [[ "$line" == "# $section:" ]]; then
                capture=1
                continue
            fi

            if (( capture )) && td_header_is_section_header "$line"; then
                break
            fi

            if (( capture )); then
                line="${line#\#}"
                [[ "$line" == " "* ]] && line="${line# }"
                result+="$line"$'\n'
            fi
        done < "$file"

        result="${result%$'\n'}"
        printf -v "$__resultvar" '%s' "$result"
    }

    # td_header_get_field
        # Purpose:
        #   Retrieve the value of a specific field within a header section.
        #
        # Behavior:
        #   - Scans the file header for the given section.
        #   - Parses lines in "Key : Value" format.
        #   - Trims surrounding whitespace from key and value.
        #   - Stops at the next section header.
        #
        # Arguments:
        #   $1  FILE
        #   $2  SECTION
        #   $3  FIELD
        #   $4  RESULT_VAR (name of variable to receive value)
        #
        # Output:
        #   RESULT_VAR contains the field value (empty if not found).
        #
        # Returns:
        #   0  field found
        #   1  field not found or not in section
    td_header_get_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local __resultvar="${4:?missing result var}"

        local line=""
        local key=""
        local value=""
        local in_section=0

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                continue
            fi

            if (( in_section )) && td_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line# }"

                key="${line%%:*}"
                value="${line#*:}"

                key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

                if [[ "$key" == "$field" ]]; then
                    printf -v "$__resultvar" '%s' "$value"
                    return 0
                fi
            fi
        done < "$file"

        printf -v "$__resultvar" '%s' ""
        return 1
    }

    # td_header_get_field_value
        # Purpose:
        #   Convenience wrapper to retrieve a field value and print it to stdout.
        #
        # Behavior:
        #   - Calls td_header_get_field internally.
        #   - Prints the resulting value to stdout.
        #
        # Arguments:
        #   $1  FILE
        #   $2  SECTION
        #   $3  FIELD
        #
        # Output:
        #   Writes the field value to stdout.
        #
        # Returns:
        #   0  always (empty output if field not found)
    td_header_get_field_value() {
        local file="$1"
        local section="$2"
        local field="$3"
        local value=""

        td_header_get_field "$file" "$section" "$field" value
        printf '%s' "$value"
    }



    # td_header_add_field
        # Purpose:
        #   Insert a new field into an existing named header section.
        #
        # Arguments:
        #   $1  FILE
        #   $2  SECTION
        #   $3  FIELD
        #   $4  VALUE
        #
        # Returns:
        #   0  field inserted
        #   1  write or temp-file failure
        #   2  section not found
    td_header_add_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"

        local tmp_file=""
        local line=""
        local in_section=0
        local inserted=0
        local saw_section=0

        tmp_file="$(mktemp)" || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                saw_section=1
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if (( in_section )) && td_header_is_section_header "$line"; then
                printf '#   %s : %s\n' "$field" "$value" >> "$tmp_file"
                printf '%s\n' "$line" >> "$tmp_file"
                inserted=1
                in_section=0
                continue
            fi

            printf '%s\n' "$line" >> "$tmp_file"
        done < "$file"

        if (( in_section && saw_section && ! inserted )); then
            printf '#   %s : %s\n' "$field" "$value" >> "$tmp_file"
            inserted=1
        fi

        if (( ! saw_section )); then
            rm -f "$tmp_file"
            return 2
        fi

        if (( ${FLAG_DRYRUN:-0} )); then
            sayinfo "Would have inserted [$section] $field in $file to: $value"
            rm -f "$tmp_file"
            return 0
        fi

        if (( inserted )); then
            mv "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 1
    }

    # td_header_upsert_field
        # Purpose:
        #   Update a field when present or insert it when missing from an existing section.
        #
        # Arguments:
        #   $1  FILE
        #   $2  SECTION
        #   $3  FIELD
        #   $4  VALUE
        #
        # Returns:
        #   0  field updated or inserted
        #   1  write or temp-file failure
        #   2  section not found
    td_header_upsert_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"
        local rc=0

        td_header_set_field "$file" "$section" "$field" "$value"
        rc=$?

        case "$rc" in
            0) return 0 ;;
            2) td_header_add_field "$file" "$section" "$field" "$value"; return $? ;;
            *) return "$rc" ;;
        esac
    }

    # td_header_calc_checksum
        # Purpose:
        #   Calculate a stable checksum for a script while ignoring self-updating metadata fields.
        #
        # Behavior:
        #   - Hashes the full file content.
        #   - Excludes Metadata lines for Version, Build, and Checksum from the hash input.
        #   - Prints the SHA256 checksum to stdout.
        #
        # Arguments:
        #   $1  FILE
        #
        # Returns:
        #   0  success
        #   1  file missing or checksum tool failed
    td_header_calc_checksum() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        awk '
            BEGIN { in_metadata = 0 }
            /^# Metadata:$/ { in_metadata = 1; print; next }
            in_metadata && /^#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$/ { in_metadata = 0 }
            in_metadata && /^#[[:space:]]+Version[[:space:]]*:/ { next }
            in_metadata && /^#[[:space:]]+Build[[:space:]]*:/ { next }
            in_metadata && /^#[[:space:]]+Checksum[[:space:]]*:/ { next }
            { print }
        ' "$file" | sha256sum | awk '{print $1}'
    }

    # td_header_bump_version
        # Purpose:
        #   Refresh header checksum/build metadata and optionally bump semantic version fields.
        #
        # Behavior:
        #   - Ensures a Checksum field exists in the Metadata section.
        #   - Compares the stored checksum to the current normalized checksum.
        #   - If the checksum differs, always updates Build and Checksum.
        #   - Optionally bumps major or minor version numbers.
        #   - A version bump also updates Build and Checksum.
        #   - Build format is yydddHH (year, day-of-year, hour).
        #
        # Arguments:
        #   $1  FILE
        #   $2  MODE   none | major | minor
        #
        # Returns:
        #   0  success
        #   1  failure
    td_header_bump_version() {
        local file="${1:?missing file}"
        local mode="${2:-none}"
        local stored_checksum=""
        local current_checksum=""
        local version=""
        local major="0"
        local minor="0"
        local new_version=""
        local new_build=""
        local needs_update=0

        current_checksum="$(td_header_calc_checksum "$file")" || return 1

        if ! td_header_get_field "$file" "Metadata" "Checksum" stored_checksum; then
            stored_checksum=""
            td_header_add_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
        fi

        case "$mode" in
            major|minor|none) ;;
            *) return 1 ;;
        esac

        # Any content change must always refresh Build + Checksum.
        if [[ "$stored_checksum" != "$current_checksum" ]]; then
            needs_update=1
        fi

        if [[ "$mode" != "none" ]]; then
            td_header_get_field "$file" "Metadata" "Version" version || version="1.0"
            if [[ "$version" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
                major="${BASH_REMATCH[1]}"
                minor="${BASH_REMATCH[2]}"
            else
                major="1"
                minor="0"
            fi

            case "$mode" in
                major)
                    major=$((major + 1))
                    minor=0
                    ;;
                minor)
                    minor=$((minor + 1))
                    ;;
            esac

            new_version="${major}.${minor}"
            td_header_upsert_field "$file" "Metadata" "Version" "$new_version" || return 1

            # Version change changes content, so refresh checksum and build too.
            needs_update=1
            current_checksum="$(td_header_calc_checksum "$file")" || return 1
        fi

        if (( needs_update )); then
            new_build="$(date +%y%j%H)"
            td_header_upsert_field "$file" "Metadata" "Build" "$new_build" || return 1
            td_header_upsert_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
        fi

        return 0
    }

    # td_header_set_field
        # Purpose:
        #   Replace the value of an existing field inside a named header section,
        #   while preserving the original line formatting.
        #
        # Behavior:
        #   - Scans only the requested header section.
        #   - Matches the requested field by trimmed key name.
        #   - Preserves the original indentation, label spacing, and separator spacing.
        #   - Replaces only the field value.
        #
        # Arguments:
        #   $1  FILE
        #   $2  SECTION
        #   $3  FIELD
        #   $4  VALUE
        #
        # Returns:
        #   0  field updated
        #   1  write or temp-file failure
        #   2  field not found
    td_header_set_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"

        local tmp_file=""
        local line=""
        local in_section=0
        local replaced=0

        local raw=""
        local lead_ws=""
        local label_part=""
        local sep_part=""
        local value_part=""
        local key=""

        tmp_file="$(mktemp)" || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" != \#* ]]; then
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if (( in_section )) && td_header_is_section_header "$line"; then
                in_section=0
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if (( in_section )); then
                raw="${line#\#}"

                # Preserve exact formatting:
                #   group 1 = leading whitespace after '#'
                #   group 2 = label part exactly as written (including spaces before ':')
                #   group 3 = separator part beginning with ':' and including spaces/tabs after it
                #   group 4 = existing value part
                if [[ "$raw" =~ ^([[:space:]]*)([^:]+)(:[[:space:]]*)(.*)$ ]]; then
                    lead_ws="${BASH_REMATCH[1]}"
                    label_part="${BASH_REMATCH[2]}"
                    sep_part="${BASH_REMATCH[3]}"
                    value_part="${BASH_REMATCH[4]}"

                    key="$(printf '%s' "$label_part" | sed 's/[[:space:]]*$//')"

                    if [[ "$key" == "$field" ]]; then
                        printf '#%s%s%s%s\n' \
                            "$lead_ws" \
                            "$label_part" \
                            "$sep_part" \
                            "$value" >> "$tmp_file"
                        replaced=1
                        continue
                    fi
                fi
            fi

            printf '%s\n' "$line" >> "$tmp_file"
        done < "$file"

        if (( replaced )); then
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "Would have updated [$section] $field in $file to: $value"
                rm -f "$tmp_file"
                return 0
            fi

            mv "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 2
    }



