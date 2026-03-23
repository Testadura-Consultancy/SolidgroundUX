# =====================================================================================
# SolidgroundUX - Comment Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608211
#   Checksum    : 8b41be36113a0f9f4195607b0389d8fd2a36082eaccb2bf4f2397fa0c866587f
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
  # Load and info
    # td_header_read
        # Purpose:
        #   Read the canonical header comment block from the top of a script file.
        #
        # Behavior:
        #   - Starts at the top of the file.
        #   - Collects consecutive comment lines that belong to the header block.
        #   - Skips the first line if it is a shebang.
        #   - Stops at the first non-comment, non-blank line after the header begins.
        #   - Preserves original comment markers and line formatting.
        #
        # Arguments:
        #   $1  FILE
        #
        # Output:
        #   Writes the full header block to stdout.
        #
        # Returns:
        #   0  success
        #   1  file missing or unreadable
        #
        # Usage:
        #   td_header_read "$file"
        #
        # Examples:
        #   header_text="$(td_header_read "$TD_SCRIPT_FILE")"
    td_header_read() {
        local file="${1:?missing file}"
        local line=""
        local started=0
        local result=""

        [[ -r "$file" ]] || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            if (( ! started )); then
                [[ "$line" == '#!'* ]] && continue
                [[ -z "$line" ]] && continue
            fi

            if [[ "$line" == \#* ]]; then
                started=1
                result+="$line"$'\n'
                continue
            fi

            if (( started )); then
                break
            fi

            [[ -z "$line" ]] || break
        done < "$file"

        printf '%s' "${result%$'\n'}"
    }

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

    # td_header_buffer_load
        # Purpose:
        #   Load a script header into the shared header buffer.
        #
        # Arguments:
        #   $1  FILE
        #
        # Returns:
        #   0  success
        #   1  failure
    td_header_buffer_load() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        TD_HEADER_BUFFER_FILE="$file"
        TD_HEADER_BUFFER_TEXT="$(td_header_read "$file")" || return 1
    }

    # td_header_buffer_get_section
        # Purpose:
        #   Extract a named section from the current header buffer.
        #
        # Arguments:
        #   $1  SECTION
        #   $2  OUTVAR
        #
        # Returns:
        #   0  section found
        #   1  section not found or buffer empty
    td_header_buffer_get_section() {
        local section="${1:?missing section}"
        local __outvar="${2:?missing outvar}"

        [[ -n "${TD_HEADER_BUFFER_TEXT:-}" ]] || return 1
        td_header_get_section_from_text "$TD_HEADER_BUFFER_TEXT" "$section" "$__outvar"
    }

  # Version control
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
        #   - Calculates the normalized checksum for the file.
        #   - Ensures a Checksum field exists in the Metadata section.
        #   - Compares stored and current checksum values.
        #   - If file content changed, refreshes Build and Checksum.
        #   - If a major or minor version bump is requested, updates Version and then
        #     refreshes Build and Checksum.
        #   - Sets TD_HEADER_BUMP_CHANGED=1 only when header metadata was actually changed.
        #
        # Arguments:
        #   $1  FILE   readable script file
        #   $2  MODE   none | major | minor
        #
        # Outputs:
        #   Sets global variable TD_HEADER_BUMP_CHANGED:
        #     0 = no header changes were needed
        #     1 = header metadata was updated
        #
        # Returns:
        #   0  success
        #   1  failure
        #
        # Usage:
        #   td_header_bump_version "$file"
        #   td_header_bump_version "$file" "minor"
        #   td_header_bump_version "$file" "major"
        #
        # Examples:
        #   td_header_bump_version "./my-script.sh" "none"
        #   td_header_bump_version "./my-script.sh" "minor"
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

        TD_HEADER_BUMP_CHANGED=0

        [[ -r "$file" ]] || return 1

        case "$mode" in
            none|major|minor) ;;
            *) return 1 ;;
        esac

        current_checksum="$(td_header_calc_checksum "$file")" || return 1

        if ! td_header_get_field "$file" "Metadata" "Checksum" stored_checksum; then
            stored_checksum=""
            td_header_add_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
            TD_HEADER_BUMP_CHANGED=1
        fi

        saydebug "stored checksum : $stored_checksum"
        saydebug "current checksum: $current_checksum"
        saydebug "mode            : $mode"

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

            if ! td_header_get_field "$file" "Metadata" "Version" version || [[ "$version" != "$new_version" ]]; then
                td_header_upsert_field "$file" "Metadata" "Version" "$new_version" || return 1
                TD_HEADER_BUMP_CHANGED=1
            fi

            needs_update=1
            current_checksum="$(td_header_calc_checksum "$file")" || return 1
        fi

        if (( needs_update )); then
            new_build="$(date +%y%j%H)"

            td_header_upsert_field "$file" "Metadata" "Build" "$new_build" || return 1
            td_header_upsert_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
            TD_HEADER_BUMP_CHANGED=1
        fi

        return 0
    }

  # Header CRUD
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

    # td_header_get_section_from_text
        # Purpose:
        #   Extract the body of a named header section from buffered header text.
        #
        # Behavior:
        #   - Scans the supplied text line by line.
        #   - Starts capturing after the requested section header.
        #   - Stops when the next section header is encountered.
        #   - Returns only the body lines of the section.
        #
        # Arguments:
        #   $1  HEADER_TEXT
        #   $2  SECTION
        #   $3  OUTVAR
        #
        # Returns:
        #   0  section found
        #   1  section not found
    td_header_get_section_from_text() {
        local text="${1-}"
        local section="${2:?missing section}"
        local __outvar="${3:?missing outvar}"

        local line=""
        local found=0
        local in_section=0
        local result=""

        while IFS= read -r line; do
            if [[ "$line" == "# $section:" ]]; then
                found=1
                in_section=1
                continue
            fi

            if (( in_section )) && td_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line#"${line%%[![:space:]]*}"}"
                result+="$line"$'\n'
            fi
        done <<< "$text"

        printf -v "$__outvar" '%s' "${result%$'\n'}"
        (( found ))
    }

    # td_header_get_banner_parts_from_text
        # Purpose:
        #   Extract product and title from the banner line in buffered header text.
        #
        # Behavior:
        #   - Scans the supplied header text line by line.
        #   - Skips separator lines (==== / ----).
        #   - Looks for the first line matching the pattern:
        #       "# <Product> - <Title>"
        #   - Splits the line into:
        #       Product (left of " - ")
        #       Title   (right of " - ")
        #
        # Arguments:
        #   $1  HEADER_TEXT
        #   $2  PRODUCT_VAR
        #   $3  TITLE_VAR
        #
        # Output:
        #   PRODUCT_VAR contains the extracted product name.
        #   TITLE_VAR   contains the extracted title.
        #
        # Returns:
        #   0  banner found and parsed
        #   1  no valid banner line found
    td_header_get_banner_parts_from_text() {
        local text="${1-}"
        local __product_var="${2:?missing product var}"
        local __title_var="${3:?missing title var}"

        local line=""
        local content=""
        local product=""
        local title=""

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || continue
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            content="${line#\# }"

            if [[ "$content" == *" - "* ]]; then
                product="${content%% - *}"
                title="${content#* - }"

                printf -v "$__product_var" '%s' "$product"
                printf -v "$__title_var" '%s' "$title"
                return 0
            fi
        done <<< "$text"

        printf -v "$__product_var" '%s' ""
        printf -v "$__title_var" '%s' ""
        return 1
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

    # td_header_get_banner_parts
        # Purpose:
        #   Extract product and title from the script banner line.
        #
        # Behavior:
        #   - Scans the header comment from the top of the file.
        #   - Skips separator lines (==== / ----).
        #   - Looks for the first line matching the pattern:
        #       "# <Product> - <Title>"
        #   - Splits the line into:
        #       Product (left of " - ")
        #       Title   (right of " - ")
        #   - Stops scanning at first non-comment line.
        #
        # Arguments:
        #   $1  FILE
        #   $2  PRODUCT_VAR (name of variable to receive product)
        #   $3  TITLE_VAR   (name of variable to receive title)
        #
        # Output:
        #   PRODUCT_VAR contains the extracted product name
        #   TITLE_VAR   contains the extracted title
        #
        # Returns:
        #   0  banner found and parsed
        #   1  no valid banner line found
        #
        # Usage:
        #   td_header_get_banner_parts "$TD_SCRIPT_FILE" TD_SCRIPT_PRODUCT TD_SCRIPT_TITLE
        #
        # Examples:
        #   # SolidgroundUX - Comment Parser
        #   → Product = SolidgroundUX
        #   → Title   = Comment Parser
        #
        # Notes:
        #   - Assumes canonical banner format "<Product> - <Title>".
        #   - Leading "# " is stripped before parsing.
        #   - Does not validate content beyond delimiter presence.
    td_header_get_banner_parts() {
        local file="${1:?missing file}"
        local __product_var="${2:?missing product var}"
        local __title_var="${3:?missing title var}"

        local line=""
        local content=""
        local product=""
        local title=""

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            content="${line#\# }"

            if [[ "$content" == *" - "* ]]; then
                product="${content%% - *}"
                title="${content#* - }"

                printf -v "$__product_var" '%s' "$product"
                printf -v "$__title_var" '%s' "$title"
                return 0
            fi
        done < "$file"

        printf -v "$__product_var" '%s' ""
        printf -v "$__title_var" '%s' ""
        return 1
    }

     # td_section_get_field_value
        # Purpose:
        #   Extract a field value from a section string.
        #
        # Behavior:
        #   - Scans the supplied section text line by line.
        #   - Splits each line at the first colon.
        #   - Trims surrounding whitespace from key and value.
        #   - Returns the first matching field value.
        #
        # Arguments:
        #   $1  SECTION_TEXT
        #   $2  FIELD
        #
        # Output:
        #   Writes field value to stdout.
        #
        # Returns:
        #   0  always (empty if not found)
    td_section_get_field_value() {
        local section="${1-}"
        local field="${2:?missing field}"
        local line=""
        local key=""
        local value=""

        while IFS= read -r line; do
            [[ "$line" == *:* ]] || continue

            key="${line%%:*}"
            value="${line#*:}"

            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"

            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"

            if [[ "$key" == "$field" ]]; then
                printf '%s' "$value"
                return 0
            fi
        done <<< "$section"

        printf ''
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
            td_safe_replace_file "$tmp_file" "$file" || {
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

            td_safe_replace_file "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 2
    }

    # td_module_init_metadata
        # Purpose:
        #   Define module-scoped metadata variables for a sourced library and
        #   populate them from the library header comment.
        #
        # Behavior:
        #   - Derives a canonical module prefix from the library filename.
        #       e.g. td-comment-parser.sh → TD_COMMENT_PARSER
        #   - Defines structural variables:
        #       TD_<MODULE>_FILE
        #       TD_<MODULE>_DIR
        #       TD_<MODULE>_BASE
        #       TD_<MODULE>_NAME
        #       TD_<MODULE>_KEY
        #   - Loads the script header into the shared header buffer once.
        #   - Extracts banner metadata:
        #       TD_<MODULE>_PRODUCT
        #       TD_<MODULE>_TITLE
        #   - Extracts Description section:
        #       TD_<MODULE>_DESC
        #   - Extracts common metadata and attribution fields from buffered section text:
        #       Version, Build, Checksum, Source, Type, Purpose
        #       Developers, Company, Client, Copyright, License
        #   - Preserves existing values (allows developer override).
        #
        # Arguments:
        #   $1  FILE   (optional; defaults to BASH_SOURCE[1])
        #
        # Outputs (globals):
        #   TD_<MODULE>_*
        #
        # Returns:
        #   0  success
        #   1  file missing or unreadable
        #
        # Usage:
        #   td_module_init_metadata "${BASH_SOURCE[0]}"
        #
        # Notes:
        #   - Intended for libraries only.
        #   - Uses buffered header parsing to reduce repeated file reads.
    td_module_init_metadata() {
        local file="${1:-${BASH_SOURCE[1]}}"
        local abs_file=""
        local dir=""
        local base=""
        local name=""
        local key=""
        local prefix=""
        local var_name=""

        local product=""
        local title=""
        local desc=""
        local metadata=""
        local attribution=""
        local value=""

        [[ -n "$file" && -r "$file" ]] || return 1

        abs_file="$(readlink -f "$file")" || return 1
        dir="$(cd -- "$(dirname -- "$abs_file")" && pwd)" || return 1
        base="$(basename -- "$abs_file")"
        name="${base%.sh}"
        key="${name//-/_}"
        prefix="TD_${key^^}"

        # --- Structural variables ----------------------------------------------------
        var_name="${prefix}_FILE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$abs_file"
        var_name="${prefix}_DIR";  [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$dir"
        var_name="${prefix}_BASE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$base"
        var_name="${prefix}_NAME"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$name"
        var_name="${prefix}_KEY";  [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$prefix"

        # --- Load header buffer once -------------------------------------------------
        td_header_buffer_load "$abs_file" || return 1

        # --- Banner (Product / Title) ------------------------------------------------
        if td_header_get_banner_parts_from_text "$TD_HEADER_BUFFER_TEXT" product title; then
            var_name="${prefix}_PRODUCT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$product"
            var_name="${prefix}_TITLE";   [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$title"
        else
            var_name="${prefix}_PRODUCT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' ""
            var_name="${prefix}_TITLE";   [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' ""
        fi

        # --- Load sections once ------------------------------------------------------
        td_header_buffer_get_section "Description" desc || desc=""
        td_header_buffer_get_section "Metadata" metadata || metadata=""
        td_header_buffer_get_section "Attribution" attribution || attribution=""

        # --- Description (multiline section) -----------------------------------------
        var_name="${prefix}_DESC"
        if [[ -z "${!var_name-}" ]]; then
            printf -v "$var_name" '%s' "$desc"
        fi

        # --- Metadata fields ---------------------------------------------------------
        value="$(td_section_get_field_value "$metadata" "Version")"
        var_name="${prefix}_VERSION"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$metadata" "Build")"
        var_name="${prefix}_BUILD"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$metadata" "Checksum")"
        var_name="${prefix}_CHECKSUM"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$metadata" "Source")"
        var_name="${prefix}_SOURCE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$metadata" "Type")"
        var_name="${prefix}_TYPE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$metadata" "Purpose")"
        var_name="${prefix}_PURPOSE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        # --- Attribution fields ------------------------------------------------------
        value="$(td_section_get_field_value "$attribution" "Developers")"
        var_name="${prefix}_DEVELOPERS"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$attribution" "Company")"
        var_name="${prefix}_COMPANY"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$attribution" "Client")"
        var_name="${prefix}_CLIENT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$attribution" "Copyright")"
        var_name="${prefix}_COPYRIGHT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(td_section_get_field_value "$attribution" "License")"
        var_name="${prefix}_LICENSE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        return 0
    }


