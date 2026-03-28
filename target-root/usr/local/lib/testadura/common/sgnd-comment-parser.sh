# =====================================================================================
# SolidgroundUX - Comment Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : 519f67b85e1fc628e7bc74d5737ce5512035683e71b52d8913b0840b95406116
#   Source      : sgnd-comment-parser.sh
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
    # _sgnd_lib_guard
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
        #   SGND_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
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

# --- Internal helpers ---------------------------------------------------------------
# --- Public API ---------------------------------------------------------------------
  # Load and info
    # sgnd_header_read
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
        #   sgnd_header_read "$file"
        #
        # Examples:
        #   header_text="$(sgnd_header_read "$SGND_SCRIPT_FILE")"
    sgnd_header_read() {
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

    # _sgnd_header_load_section_to_dt
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
            #   1  failure (e.g. sgnd_dt_append error)
    sgnd_header_load_section_to_dt() {
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

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
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

                sgnd_dt_append "$schema" "$table_name" "$section" "$key" "$value" || return 1
            fi
        done < "$file"
    }

    # sgnd_header_is_section_header
        # Purpose:
        #   Determine whether a line is a top-level script header section marker.
        #
        # Arguments:
        #   $1  LINE
        #
        # Returns:
        #   0  line is a section header
        #   1  line is not a section header
    sgnd_header_is_section_header() {
        local line="${1-}"

        [[ "$line" =~ ^\#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]] || return 1
        [[ "$line" == "#   "* ]] && return 1
        return 0
    }

    # sgnd_header_buffer_load
        # Purpose:
        #   Load a script header into the shared header buffer.
        #
        # Arguments:
        #   $1  FILE
        #
        # Returns:
        #   0  success
        #   1  failure
    sgnd_header_buffer_load() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        SGND_HEADER_BUFFER_FILE="$file"
        SGND_HEADER_BUFFER_TEXT="$(sgnd_header_read "$file")" || return 1
    }

    # sgnd_header_buffer_get_section
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
    sgnd_header_buffer_get_section() {
        local section="${1:?missing section}"
        local _outvar="${2:?missing outvar}"

        [[ -n "${SGND_HEADER_BUFFER_TEXT:-}" ]] || return 1
        sgnd_header_get_section_from_text "$SGND_HEADER_BUFFER_TEXT" "$section" "$_outvar"
    }

  # Version control
    # sgnd_header_calc_checksum
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
    sgnd_header_calc_checksum() {
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

    # sgnd_header_bump_version
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
        #   - Sets SGND_HEADER_BUMP_CHANGED=1 only when header metadata was actually changed.
        #
        # Arguments:
        #   $1  FILE   readable script file
        #   $2  MODE   none | major | minor
        #
        # Outputs:
        #   Sets global variable SGND_HEADER_BUMP_CHANGED:
        #     0 = no header changes were needed
        #     1 = header metadata was updated
        #
        # Returns:
        #   0  success
        #   1  failure
        #
        # Usage:
        #   sgnd_header_bump_version "$file"
        #   sgnd_header_bump_version "$file" "minor"
        #   sgnd_header_bump_version "$file" "major"
        #
        # Examples:
        #   sgnd_header_bump_version "./my-script.sh" "none"
        #   sgnd_header_bump_version "./my-script.sh" "minor"
    sgnd_header_bump_version() {
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

        SGND_HEADER_BUMP_CHANGED=0

        [[ -r "$file" ]] || return 1

        case "$mode" in
            none|major|minor) ;;
            *) return 1 ;;
        esac

        current_checksum="$(sgnd_header_calc_checksum "$file")" || return 1

        if ! sgnd_header_get_field "$file" "Metadata" "Checksum" stored_checksum; then
            stored_checksum=""
            sgnd_header_add_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
            SGND_HEADER_BUMP_CHANGED=1
        fi

        saydebug "stored checksum : $stored_checksum"
        saydebug "current checksum: $current_checksum"
        saydebug "mode            : $mode"

        if [[ "$stored_checksum" != "$current_checksum" ]]; then
            needs_update=1
        fi

        if [[ "$mode" != "none" ]]; then
            sgnd_header_get_field "$file" "Metadata" "Version" version || version="1.0"

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

            if ! sgnd_header_get_field "$file" "Metadata" "Version" version || [[ "$version" != "$new_version" ]]; then
                sgnd_header_upsert_field "$file" "Metadata" "Version" "$new_version" || return 1
                SGND_HEADER_BUMP_CHANGED=1
            fi

            needs_update=1
            current_checksum="$(sgnd_header_calc_checksum "$file")" || return 1
        fi

        if (( needs_update )); then
            new_build="$(date +%y%j%H)"

            sgnd_header_upsert_field "$file" "Metadata" "Build" "$new_build" || return 1
            sgnd_header_upsert_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
            SGND_HEADER_BUMP_CHANGED=1
        fi

        return 0
    }

  # Header CRUD
    # sgnd_header_get_section
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
    sgnd_header_get_section() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local _resultvar="${3:?missing result var}"

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

            if (( capture )) && sgnd_header_is_section_header "$line"; then
                break
            fi

            if (( capture )); then
                line="${line#\#}"
                [[ "$line" == " "* ]] && line="${line# }"
                result+="$line"$'\n'
            fi
        done < "$file"

        result="${result%$'\n'}"
        printf -v "$_resultvar" '%s' "$result"
    }

    # sgnd_header_get_section_from_text
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
    sgnd_header_get_section_from_text() {
        local text="${1-}"
        local section="${2:?missing section}"
        local _outvar="${3:?missing outvar}"

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

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line#"${line%%[![:space:]]*}"}"
                result+="$line"$'\n'
            fi
        done <<< "$text"

        printf -v "$_outvar" '%s' "${result%$'\n'}"
        (( found ))
    }

    # sgnd_header_get_banner_parts_from_text
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
    sgnd_header_get_banner_parts_from_text() {
        local text="${1-}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

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

                printf -v "$_product_var" '%s' "$product"
                printf -v "$_title_var" '%s' "$title"
                return 0
            fi
        done <<< "$text"

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }

    # sgnd_header_get_field
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
    sgnd_header_get_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local _resultvar="${4:?missing result var}"

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

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
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
                    printf -v "$_resultvar" '%s' "$value"
                    return 0
                fi
            fi
        done < "$file"

        printf -v "$_resultvar" '%s' ""
        return 1
    }

    # sgnd_header_get_field_value
        # Purpose:
        #   Convenience wrapper to retrieve a field value and print it to stdout.
        #
        # Behavior:
        #   - Calls sgnd_header_get_field internally.
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
    sgnd_header_get_field_value() {
        local file="$1"
        local section="$2"
        local field="$3"
        local value=""

        sgnd_header_get_field "$file" "$section" "$field" value
        printf '%s' "$value"
    }

    # sgnd_header_get_banner_parts
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
        #   sgnd_header_get_banner_parts "$SGND_SCRIPT_FILE" SGND_SCRIPT_PRODUCT SGND_SCRIPT_TITLE
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
    sgnd_header_get_banner_parts() {
        local file="${1:?missing file}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

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

                printf -v "$_product_var" '%s' "$product"
                printf -v "$_title_var" '%s' "$title"
                return 0
            fi
        done < "$file"

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }

     # sgnd_section_get_field_value
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
    sgnd_section_get_field_value() {
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

    # sgnd_header_add_field
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
    sgnd_header_add_field() {
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

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
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
            sgnd_safe_replace_file "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 1
    }

    # sgnd_header_upsert_field
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
    sgnd_header_upsert_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"
        local rc=0

        sgnd_header_set_field "$file" "$section" "$field" "$value"
        rc=$?

        case "$rc" in
            0) return 0 ;;
            2) sgnd_header_add_field "$file" "$section" "$field" "$value"; return $? ;;
            *) return "$rc" ;;
        esac
    }
   
    # sgnd_header_set_field
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
    sgnd_header_set_field() {
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

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
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

            sgnd_safe_replace_file "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 2
    }



