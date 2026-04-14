# =====================================================================================
# SolidgroundUX - Comment Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : 7af1dfc30947c5549b1735208d53a4e7295a3b2acfdbf911c333450b06804b5c
#   Source      : sgnd-comment-parser.sh
#   Type        : library
#   Group       : Developer tools
#   Purpose     : Parse and update structured header comments in SolidgroundUX scripts
#
# Description:
#   Provides parsing and update utilities for structured script header comments
#   used throughout the SolidgroundUX framework.
#
#   The library:
#     - Detects and reads canonical header sections
#     - Extracts field/value pairs from structured comment blocks
#     - Loads header data into sgnd-datatable structures
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
# - Library guard ------------------------------------------------------------------
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

# - Public API ---------------------------------------------------------------------
# -- Load and info
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

    # sgnd_header_load_section_to_dt
        # Purpose:
        #   Load all key/value pairs from a header section into an sgnd-datatable.
        #
        # Behavior:
        #   - Scans the requested section from the file header.
        #   - Stops at the next top-level section header.
        #   - Trims surrounding whitespace from keys and values.
        #   - Appends one row per field to the target datatable.
        #
        # Arguments:
        #   $1  FILE
        #       Script file to read.
        #   $2  SECTION
        #       Header section name to scan.
        #   $3  SCHEMA
        #       Datatable schema name.
        #   $4  TABLE_NAME
        #       Datatable variable name.
        #
        # Side effects:
        #   - Appends rows through sgnd_dt_append.
        #
        # Returns:
        #   0 on success.
        #   1 if row append fails.
        #
        # Usage:
        #   sgnd_header_load_section_to_dt "$file" "Metadata" "$schema" "$table_name"
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
        #   Determine whether a line is a top-level structured header section marker.
        #
        # Behavior:
        #   - Matches canonical section lines such as "# Metadata:".
        #   - Rejects indented field lines within sections.
        #
        # Arguments:
        #   $1  LINE
        #       Raw header line to test.
        #
        # Returns:
        #   0 if LINE is a section header.
        #   1 otherwise.
        #
        # Usage:
        #   sgnd_header_is_section_header "$line"
    sgnd_header_is_section_header() {
        local line="${1-}"

        [[ "$line" =~ ^\#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]] || return 1
        [[ "$line" == "#   "* ]] && return 1
        return 0
    }

    # sgnd_header_buffer_load
        # Purpose:
        #   Load a script header into the shared in-memory header buffer.
        #
        # Behavior:
        #   - Verifies that the target file is readable.
        #   - Stores the file path in SGND_HEADER_BUFFER_FILE.
        #   - Stores the canonical header text in SGND_HEADER_BUFFER_TEXT.
        #
        # Arguments:
        #   $1  FILE
        #       Script file to buffer.
        #
        # Outputs (globals):
        #   SGND_HEADER_BUFFER_FILE
        #   SGND_HEADER_BUFFER_TEXT
        #
        # Returns:
        #   0 on success.
        #   1 if the file is unreadable or the header cannot be read.
        #
        # Usage:
        #   sgnd_header_buffer_load "$file"
    sgnd_header_buffer_load() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        SGND_HEADER_BUFFER_FILE="$file"
        SGND_HEADER_BUFFER_TEXT="$(sgnd_header_read "$file")" || return 1
    }

    # sgnd_header_buffer_get_section
        # Purpose:
        #   Extract a named section from the current shared header buffer.
        #
        # Behavior:
        #   - Reads from SGND_HEADER_BUFFER_TEXT.
        #   - Delegates parsing to sgnd_header_get_section_from_text.
        #   - Writes the extracted section body to the requested output variable.
        #
        # Arguments:
        #   $1  SECTION
        #       Header section name.
        #   $2  OUTVAR
        #       Variable name that receives the section body.
        #
        # Inputs (globals):
        #   SGND_HEADER_BUFFER_TEXT
        #
        # Returns:
        #   0 if the section is found.
        #   1 if the buffer is empty or the section is not found.
        #
        # Usage:
        #   sgnd_header_buffer_get_section "Metadata" metadata
    sgnd_header_buffer_get_section() {
        local section="${1:?missing section}"
        local _outvar="${2:?missing outvar}"

        [[ -n "${SGND_HEADER_BUFFER_TEXT:-}" ]] || return 1
        sgnd_header_get_section_from_text "$SGND_HEADER_BUFFER_TEXT" "$section" "$_outvar"
    }
# -- Version control
    # sgnd_header_calc_checksum
        # Purpose:
        #   Calculate a stable checksum for a script while ignoring self-updating metadata fields.
        #
        # Behavior:
        #   - Reads the full file content.
        #   - Excludes Metadata lines for Version, Build, and Checksum.
        #   - Hashes the normalized content with SHA-256.
        #   - Prints the resulting checksum to stdout.
        #
        # Arguments:
        #   $1  FILE
        #       Script file to hash.
        #
        # Output:
        #   Writes the checksum to stdout.
        #
        # Returns:
        #   0 on success.
        #   1 if the file is unreadable or hashing fails.
        #
        # Usage:
        #   sgnd_header_calc_checksum "$file"
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
# -- Header CRUD
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
        #   - Scans the supplied header text line by line.
        #   - Starts capturing after the requested section header.
        #   - Stops when the next top-level section header is encountered.
        #   - Writes only the section body lines to the requested output variable.
        #
        # Arguments:
        #   $1  HEADER_TEXT
        #       Buffered header text.
        #   $2  SECTION
        #       Header section name.
        #   $3  OUTVAR
        #       Variable name that receives the section body.
        #
        # Returns:
        #   0 if the section is found.
        #   1 if the section is not found.
        #
        # Usage:
        #   sgnd_header_get_section_from_text "$text" "Metadata" metadata
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
        local banner_line=""
        local found_sep=0
        local product=""
        local title=""

        while IFS= read -r line; do
            if (( ! found_sep )); then
                if [[ "$line" =~ ^\#[[:space:]]*={3,}[[:space:]]*$ ]]; then
                    found_sep=1
                fi
                continue
            fi

            banner_line="$line"
            break
        done <<< "$text"

        if [[ "$banner_line" =~ ^\#[[:space:]]*(.+)[[:space:]]-[[:space:]](.+)[[:space:]]*$ ]]; then
            product="${BASH_REMATCH[1]}"
            title="${BASH_REMATCH[2]}"

            product="${product%"${product##*[![:space:]]}"}"
            title="${title#"${title%%[![:space:]]*}"}"
            title="${title%"${title##*[![:space:]]}"}"

            printf -v "$_product_var" '%s' "$product"
            printf -v "$_title_var" '%s' "$title"
            return 0
        fi

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }

    # sgnd_header_parse_banner_line
        # Purpose:
        #   Extract product and title from a single header banner line.
        #
        # Arguments:
        #   $1  LINE
        #   $2  PRODUCT_VAR
        #   $3  TITLE_VAR
        #
        # Returns:
        #   0 if parsed
        #   1 otherwise
        #
    sgnd_header_parse_banner_line() {
        local line="${1-}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

        local product=""
        local title=""

        if [[ "$line" =~ ^\#[[:space:]]*(.+)[[:space:]]-[[:space:]](.+)[[:space:]]*$ ]]; then
            product="${BASH_REMATCH[1]}"
            title="${BASH_REMATCH[2]}"

            product="${product%"${product##*[![:space:]]}"}"
            title="${title#"${title%%[![:space:]]*}"}"
            title="${title%"${title##*[![:space:]]}"}"

            printf -v "$_product_var" '%s' "$product"
            printf -v "$_title_var" '%s' "$title"
            return 0
        fi

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }

    # sgnd_header_get_field_value
        # Returns:
        #   Prints the requested field value to stdout, or an empty string if not found.
        #
        # Usage:
        #   sgnd_header_get_field_value "$file" "Metadata" "Version"
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
        #   Extract product and title from the banner line.
        #
        # Behavior:
        #   - Finds the first header separator line.
        #   - Reads the first comment line directly below it as the banner line.
        #   - Expects canonical format:
        #       # <Product> - <Title>
        #
        # Arguments:
        #   $1  FILE
        #   $2  PRODUCT_VAR
        #   $3  TITLE_VAR
        #
        # Returns:
        #   0 if banner found and parsed
        #   1 otherwise
    sgnd_header_get_banner_parts() {
        local file="${1:?missing file}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

        local line=""
        local banner_line=""
        local found_sep=0
        local product=""
        local title=""

        while IFS= read -r line; do
            if (( ! found_sep )); then
                if [[ "$line" =~ ^\#[[:space:]]*={3,}[[:space:]]*$ ]]; then
                    found_sep=1
                fi
                continue
            fi

            banner_line="$line"
            break
        done < "$file"

        if [[ "$banner_line" =~ ^\#[[:space:]]*(.+)[[:space:]]-[[:space:]](.+)[[:space:]]*$ ]]; then
            product="${BASH_REMATCH[1]}"
            title="${BASH_REMATCH[2]}"

            product="${product%"${product##*[![:space:]]}"}"
            title="${title#"${title%%[![:space:]]*}"}"
            title="${title%"${title##*[![:space:]]}"}"

            printf -v "$_product_var" '%s' "$product"
            printf -v "$_title_var" '%s' "$title"
            return 0
        fi

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
        # Behavior:
        #   - Scans the file until the requested section is found.
        #   - Inserts the new field before the next section header,
        #     or at the end of the section when it is the final section.
        #   - Honors FLAG_DRYRUN by reporting the intended change without writing.
        #
        # Arguments:
        #   $1  FILE
        #       Target script file.
        #   $2  SECTION
        #       Header section name.
        #   $3  FIELD
        #       Field name to insert.
        #   $4  VALUE
        #       Field value to write.
        #
        # Side effects:
        #   - May rewrite the target file.
        #   - May emit informational output in dry-run mode.
        #
        # Returns:
        #   0 if the field was inserted.
        #   1 on write or temp-file failure.
        #   2 if the section does not exist.
        #
        # Usage:
        #   sgnd_header_add_field "$file" "Metadata" "Checksum" "$checksum"
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
        # Behavior:
        #   - Attempts to update the field in place first.
        #   - Falls back to inserting the field when it does not yet exist.
        #   - Propagates other write failures unchanged.
        #
        # Arguments:
        #   $1  FILE
        #       Target script file.
        #   $2  SECTION
        #       Header section name.
        #   $3  FIELD
        #       Field name to update or insert.
        #   $4  VALUE
        #       Value to write.
        #
        # Returns:
        #   0 if the field was updated or inserted.
        #   1 on write or temp-file failure.
        #   2 if the section does not exist.
        #
        # Usage:
        #   sgnd_header_upsert_field "$file" "Metadata" "Build" "$build"
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
        #   Replace the value of an existing field inside a named header section
        #   while preserving the original line formatting.
        #
        # Behavior:
        #   - Scans only the requested header section.
        #   - Matches the requested field by trimmed key name.
        #   - Preserves original indentation, label spacing, and separator spacing.
        #   - Replaces only the value portion of the matched field line.
        #   - Honors FLAG_DRYRUN by reporting the intended change without writing.
        #
        # Arguments:
        #   $1  FILE
        #       Target script file.
        #   $2  SECTION
        #       Header section name.
        #   $3  FIELD
        #       Field name to update.
        #   $4  VALUE
        #       Replacement value.
        #
        # Returns:
        #   0 if the field was updated.
        #   1 on write or temp-file failure.
        #   2 if the field is not found.
        #
        # Usage:
        #   sgnd_header_set_field "$file" "Metadata" "Version" "1.2"
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
    
# -- Comment parsing
    # Comment header marker line (e.g. "# ======")
        # =~ regex explanation:
        #   ^           : start of line
        #   \#          : literal #
        #   [[:space:]] : at least one whitespace character
        #   =+          : one or more literal = characters
        #   [[:space:]] : at least one whitespace character
        #   $           : end of line
    RGX_HEADER_MARKER='^\#[[:space:]]*=+[[:space:]]*$'
    # Comment field marker line (e.g. "# Field : Value")
    RGX_COMMENT_FIELD='^\#[[:space:]]*([A-Za-z]+)[[:space:]]*:[[:space:]]*(.*)$'
    # Comment section marker (e.g. "# --- SectionName")
    RGX_SECTION_HEADER='^#[[:space:]]*(---|--|-)[[:space:]](.*[^[:space:]-])[[:space:]-]*$'

    # Current section tracking
    _current_section="maindoc"
    _current_parentsection=""
    _current_grandparentsection=""
    _current_section_level=0 # 0 = maindoc, 1 = first-level section, etc.

 
    # fn: sgnd_get_comment_fieldvalue
        # Purpose:
        #   Parse a canonical comment field line and assign the value to a prefixed variable.
        #
        # Behavior:
        #   - Matches comment lines of the form: "#   Field : Value"
        #   - Extracts field name and value from the line
        #   - Normalizes the field name to lowercase
        #   - Assigns the value to the corresponding "<prefix><field>" variable
        #   - Ignores lines that do not match the canonical field format
        #
        # Arguments:
        #   $1  LINE
        #   $2  PREFIX
        #
        # Returns:
        #   0 if a field was parsed and assigned.
        #   1 if the line is not a recognized field line.
        #
        # Usage:
        #   sgnd_get_comment_fieldvalue "$line" "_parsed_"
        #
        # Examples:
        #   sgnd_get_comment_fieldvalue "#   Version     : 1.1" "_parsed_"
        #   sgnd_get_comment_fieldvalue "#   Purpose     : Generate documentation" "meta_"
        #
    sgnd_get_comment_fieldvalue() {
        local line="$1"
        local field="$2"
        local prefix="$3"
        local found_field=""
        local value=""
        local var_name=""

        [[ "$line" =~ $RGX_COMMENT_FIELD ]] || return 1

        found_field="${BASH_REMATCH[1],,}"
        value="${BASH_REMATCH[2]}"
        field="${field,,}"

        [[ "$found_field" == "$field" ]] || return 1

        var_name="${prefix}_${field}"
        printf -v "$var_name" '%s' "$value"
        return 0
    }

    # fn: sgnd_get_current_section
        # Purpose:
        #   Detect and register the current section header for one parsed line.
        #
        # Arguments:
        #   $1  LINE
        #
        # Returns:
        #   0 if a section header was detected.
        #   1 otherwise.
        #
        # Usage:
        #   sgnd_get_current_section "$line"
    sgnd_get_current_section() {
        local line="$1"
        local marker=""
        local title=""

        [[ "$line" =~ $RGX_SECTION_HEADER ]] || return 1

        marker="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
        # Normalize title by trimming '-' and spaces from both ends
        title="${title##[-[:space:]]}"
        title="${title%%[-[:space:]]}"

        case "$marker" in
            -)
                # First-level section
                # Start a new top-level branch under maindoc.
                _current_section="$title"
                _current_parentsection="maindoc"
                _current_grandparentsection=""
                _current_section_index="$title"
                _current_section_level=1
                ;;

            --)
                # Second-level section
                case "${_current_section_level:-0}" in
                    1)
                        # Coming from level 1:
                        # current section becomes parent of new level-2 section.
                        _current_grandparentsection="maindoc"
                        _current_parentsection="$_current_section"
                        ;;
                    2)
                        # Staying on level 2:
                        # keep existing parent/grandparent, just replace current section.
                        ;;
                    3)
                        # Coming from level 3:
                        # step one level up, so grandparent becomes parent.
                        _current_parentsection="$_current_grandparentsection"
                        _current_grandparentsection="maindoc"
                        ;;
                    *)
                        # No prior section context:
                        # treat as child of maindoc.
                        _current_grandparentsection=""
                        _current_parentsection="maindoc"
                        ;;
                esac

                _current_section="$title"
                _current_section_level=2
                ;;

            ---)
                # Third-level section
                case "${_current_section_level:-0}" in
                    1)
                        # Coming straight from level 1:
                        # current section becomes parent, maindoc becomes grandparent.
                        _current_grandparentsection="maindoc"
                        _current_parentsection="$_current_section"
                        ;;
                    2|3)
                        # Coming from level 2 or staying on level 3:
                        # current parent becomes grandparent, current section becomes parent.
                        _current_grandparentsection="$_current_parentsection"
                        _current_parentsection="$_current_section"
                        ;;
                    *)
                        # No prior section context:
                        # treat as nested under maindoc.
                        _current_grandparentsection=""
                        _current_parentsection="maindoc"
                        ;;
                esac

                _current_section="$title"
                _current_section_level=3
                ;;

            *)
                return 1
                ;;
        esac

        return 0
    }

    # fn: sgnd_parse_module_file
        # Purpose:
        #   Parse one source file and initialize parser state for line-by-line processing.
        #
        # Behavior:
        #   - Normalizes the input file path
        #   - Resets parsed metadata and parser state variables
        #   - Stores the current filename for downstream parsing logic
        #   - Iterates through the file line by line
        #   - Delegates line handling to sgnd_parse_module_line
        #
        # Arguments:
        #   $1  FILE
        #
        # Outputs (globals):
        #   _parsed_filename
        #   _line_nr
        #   _line_parse_index
        #   _parsing_header
        #   _current_section
        #   _current_parentsection
        #
        # Returns:
        #   0 on success.
        #   1 if FILE is unreadable.
        #
        # Usage:
        #   sgnd_parse_module_file "$file"
    sgnd_parse_module_file() {
        local file="$1"
        local line_ttl
        local line=""

        [[ -r "$file" ]] || return 1

        file="${file%/}"
        _parsed_filename="${file##*/}"

        _init_module_metadata

        saydebug "Parsing source file: $file"
        _line_nr=0
        _line_parse_index=0
        _parsing_header=0

        _current_section="header"
        _current_parentsection=""

        line_ttl=$(awk 'END {print NR}' "$file")

        while IFS= read -r line || [[ -n "$line" ]]; do
            ((_line_nr++))
            sgnd_parse_module_line "$line" "$file" "$_line_nr"
        done < "$file"

        return 0
    }
    
    # fn: sgnd_parse_module_line
        # Purpose:
        #   Process one source line and detect structural markers for documentation parsing.
        #
        # Behavior:
        #   - Detects the start of the canonical module header comment
        #   - Extracts product and title from the banner line
        #   - Detects the end of the canonical module header comment
        #   - Parses metadata fields while header parsing is active
        #   - Leaves section detection to later parser stages
        #
        # Arguments:
        #   $1  LINE
        #   $2  FILE
        #   $3  LINENR
        #
        # Returns:
        #   0
        #
        # Usage:
        #   sgnd_parse_module_line "$line" "$file" "$linenr"
        #
        # Examples:
        #   sgnd_parse_module_line "#   Version     : 1.0" "module.sh" 12
    sgnd_parse_module_line() {
        local line="$1"
        local file="${2:-}"
        local linenr="${3:-}"

        _line_parse_index=$(( _line_parse_index + 1 ))

        # Detect start of module header ----------------------------------------
        if (( !_parsing_header )) && [[ "$line" =~ $RGX_HEADER_MARKER ]]; then
            _parsing_header=1
            sayinfo "Detected header start at line $linenr in $file"
            return 0
        fi

        # Extract product and title from header banner -------------------------
        if (( _parsing_header && _line_parse_index == 2 )); then
            sgnd_header_parse_banner_line "$line" "_parsed_product" "_parsed_title" || {
                saywarning "Failed to parse product and title from header banner in $_parsed_filename: $line"
            }
            sayinfo "Parsed product: $_parsed_product, title: $_parsed_title from header in $_parsed_filename"
            return 0
        fi

        # Detect end of module header ------------------------------------------
        if (( _parsing_header )) && [[ "$line" =~ $RGX_HEADER_MARKER ]]; then
            _parsing_header=0
            sayinfo "Detected header end at line $linenr in $file"
            return 0
        fi

        # Gather module metadata fields while parsing header -------------------
        if (( _parsing_header )); then
            _assemble_module_metadata "$line" && return 0
        fi

        # Detect section -------------------------------------------------------
        sgnd_get_current_section "$line" && {
            sayinfo "Section level $_current_section_level: $_current_section (parent: $_current_parentsection, grandparent: $_current_grandparentsection) at line $linenr"
            return 0
        }

    }      




