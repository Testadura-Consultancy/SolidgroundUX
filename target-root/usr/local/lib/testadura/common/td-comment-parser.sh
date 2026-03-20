# ==================================================================================
# SolidgroundUX Comment parser
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 26079
#   Sourcefile  : td-comment-parser.sh
#   Type        : library
#   Purpose     : Library of helper functions to read and write data from script comments
#
# # Description:
#   Provides helper functions to read and update structured header comments
#   in SolidGroundUX/Testadura scripts and libraries.
#
#   Supports:
#     - detecting canonical header section lines
#     - reading full section content
#     - reading individual field values from a section
#     - loading section fields into a td-datatable
#     - updating an existing field value in place
#
# Design principles:
#   - Operates only on comment headers at the top of a file
#   - Treats section headers and field lines as structured text
#   - Keeps parsing rules simple and predictable
#   - Leaves policy and validation to the caller
#
# Role in framework:
#   - Shared parser/writer for script header metadata
#   - Supports tools such as metadata-editor and documentation extraction
#
# Non-goals:
#   - Parsing arbitrary comments throughout a file
#   - Inserting missing sections or fields
#   - Validating business meaning of metadata values
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        :
#   Copyright     : © 2025 Mark Fieten — Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
set -uo pipefail
# --- Library guard ---------------------------------------------------------------
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


# --- Internal helpers ------------------------------------------------------------
# --- Public API ------------------------------------------------------------------
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

    # td_header_set_field
        # Purpose:
        #   Replace the value of an existing field inside a named header section.
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
        local key=""
        local prefix=""

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
                prefix="${raw%%[![:space:]]*}"
                raw="${raw#"$prefix"}"

                if [[ "$raw" == *:* ]]; then
                    key="${raw%%:*}"
                    key="$(printf '%s' "$key" | sed 's/[[:space:]]*$//')"

                    if [[ "$key" == "$field" ]]; then
                        printf '#%s%s : %s\n' "$prefix" "$field" "$value" >> "$tmp_file"
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



