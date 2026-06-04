# =====================================================================================
# SolidgroundUX - Header Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : sgnd-comment-header-parser.sh
#   Type        : library
#   Group       : Developer Tools
#   Purpose     : Read, parse, and update canonical script header comments in SolidgroundUX files
#
# Description:
#   Provides parsing, lookup, and update utilities for canonical script header comments
#   used throughout the SolidgroundUX framework.
#
#   The library:
#     - Detects top-level canonical header sections
#     - Loads header section fields into sgnd-datatable structures
#     - Extracts banner information such as product and title
#     - Reads individual header field values from structured sections
#     - Updates existing header fields while preserving formatting
#     - Adds missing fields where required
#     - Supports checksum, build, and semantic version metadata workflows
#
# Design principles:
#   - Header comments are treated as structured, machine-readable data
#   - Header parsing and header mutation are kept predictable and convention-based
#   - Existing field formatting is preserved wherever possible
#   - Metadata workflows remain independent from higher-level UI logic
#
# Role in framework:
#   - Core header metadata parsing and update layer for script tooling
#   - Supports metadata-editor, release preparation, and other header-aware utilities
#   - Provides the canonical API for header field inspection and mutation
#
# Non-goals:
#   - Parsing arbitrary inline documentation blocks in source bodies
#   - Rendering documentation output
#   - Acting as a general-purpose text processing library
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================

set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Lib guard
        # Purpose:
        #   Prevent direct execution of a source-only library and avoid repeated initialization when the file is sourced more than once.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 when the library may continue loading; exits with 2 when executed directly.
        #
        # Usage:
        #   _sgnd_lib_guard ...
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
    # fn: sgnd_header_read - Header read
        # Purpose:
        #   Read the canonical header block from a source file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_read ...
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

    # fn: sgnd_header_load_section_to_dt - Header load section to dt
        # Purpose:
        #   Load a named header section into a datatable-compatible array.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_load_section_to_dt ...
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

    # fn: sgnd_header_is_section_header - Header is section header
        # Purpose:
        #   Test whether a header line declares a named header section.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_is_section_header ...
    sgnd_header_is_section_header() {
        local line="${1-}"

        [[ "$line" =~ ^\#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]] || return 1
        [[ "$line" == "#   "* ]] && return 1
        return 0
    }

    # fn: sgnd_header_buffer_load - Header buffer load
        # Purpose:
        #   Load a source-file header into the shared header buffer.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_buffer_load ...
    sgnd_header_buffer_load() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        SGND_HEADER_BUFFER_FILE="$file"
        SGND_HEADER_BUFFER_TEXT="$(sgnd_header_read "$file")" || return 1
    }

    # fn: sgnd_header_buffer_get_section - Header buffer get section
        # Purpose:
        #   Extract a named section from the shared header buffer.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_buffer_get_section ...
    sgnd_header_buffer_get_section() {
        local section="${1:?missing section}"
        local _outvar="${2:?missing outvar}"

        [[ -n "${SGND_HEADER_BUFFER_TEXT:-}" ]] || return 1
        sgnd_header_get_section_from_text "$SGND_HEADER_BUFFER_TEXT" "$section" "$_outvar"
    }
# -- Version control
    # fn: sgnd_header_calc_checksum - Header calc checksum
        # Purpose:
        #   Calculate a checksum for a source file while ignoring checksum field content.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_calc_checksum ...
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

    # fn: sgnd_header_bump_version - Header bump version
        # Purpose:
        #   Update version, build, checksum, and related header metadata fields.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_bump_version ...
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
    # fn: sgnd_header_get_section - Header get section
        # Purpose:
        #   Extract a named header section from a source file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_get_section ...
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

    # fn: sgnd_header_get_section_from_text - Header get section from text
        # Purpose:
        #   Extract a named header section from an in-memory header text block.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_get_section_from_text ...
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

    # fn: sgnd_header_get_banner_parts_from_text - Header get banner parts from text
        # Purpose:
        #   Extract product and title from a canonical header banner in text.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_get_banner_parts_from_text ...
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

    # fn: sgnd_header_parse_banner_line - Header parse banner line
        # Purpose:
        #   Parse one canonical header banner line into product and title parts.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_parse_banner_line ...
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

    # fn: sgnd_header_get_field_value
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

    # fn: sgnd_header_get_field_value - Header get field value
        # Purpose:
        #   Read a field value from a named header section.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_get_field_value ...
    sgnd_header_get_field_value() {
        local file="$1"
        local section="$2"
        local field="$3"
        local value=""

        sgnd_header_get_field "$file" "$section" "$field" value
        printf '%s' "$value"
    }

    # fn: sgnd_header_get_banner_parts - Header get banner parts
        # Purpose:
        #   Extract product and title from a source-file header.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_get_banner_parts ...
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
    # fn: sgnd_section_get_field_value - Section get field value
        # Purpose:
        #   Read a field value from an already extracted header section.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_section_get_field_value ...
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

    # fn: sgnd_header_add_field - Header add field
        # Purpose:
        #   Insert a field into an existing header section.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_add_field ...
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

    # fn: sgnd_header_upsert_field - Header upsert field
        # Purpose:
        #   Update an existing header field or insert it when missing.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_upsert_field ...
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
   
    # fn: sgnd_header_set_field - Header set field
        # Purpose:
        #   Set one header field value in a source file.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_header_set_field ...
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
    




