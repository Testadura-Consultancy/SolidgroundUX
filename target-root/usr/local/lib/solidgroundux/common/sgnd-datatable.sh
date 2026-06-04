# =====================================================================================
# SolidgroundUX - Datatable
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : sgnd-datatable.sh
#   Type        : library
#   Group       : Common Extensions
#   Purpose     : Provide lightweight tabular data structures and utilities
#
# Description:
#   Provides a lightweight, schema-driven datatable abstraction for handling
#   structured data within shell scripts.
#
#   The library:
#     - Defines schema-based row structures using delimited fields
#     - Stores and manages tabular data in indexed arrays
#     - Supports row insertion, retrieval, and iteration
#     - Enables field-based access using schema definitions
#     - Provides helper functions for filtering and transformation
#
# Design principles:
#   - Minimal abstraction on top of native shell arrays
#   - Schema-driven access for readability and consistency
#   - Predictable and explicit data handling
#   - Lightweight implementation without external dependencies
#
# Role in framework:
#   - Core data structure used across SolidgroundUX tooling
#   - Backbone for metadata parsing, UI rendering, and data exchange
#
# Non-goals:
#   - Full relational data modeling or query capabilities
#   - Persistent storage or database functionality
#   - Replacement for external data processing tools
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail

# --- Library guard ------------------------------------------------------------------
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

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# --- Internal helpers ---------------------------------------------------------------
    # fn: sgnd_dt_array_length - Dt array length
        # Purpose:
        #   Return the number of entries in a named datatable array.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_array_length ...
    sgnd_dt_array_length() {
        local array_name="${1:?missing array name}"
        local -n array_ref="$array_name"

        printf '%s\n' "${#array_ref[@]}"
    }

    # fn: sgnd_dt_split_schema - Dt split schema
        # Purpose:
        #   Split a pipe-delimited datatable schema into fields.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_split_schema ...
    sgnd_dt_split_schema() {
        local schema="${1:?missing schema}"

        IFS='|' read -r -a SGND_DT_SPLIT <<< "$schema"
    }

    # fn: sgnd_dt_split_row - Dt split row
        # Purpose:
        #   Split a pipe-delimited datatable row into fields.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_split_row ...
    sgnd_dt_split_row() {
        local row="${1-}"
        local tmp

        tmp="${row}|_SGND_SENTINEL_"
        IFS='|' read -r -a SGND_DT_SPLIT <<< "$tmp"

        unset 'SGND_DT_SPLIT[${#SGND_DT_SPLIT[@]}-1]'
    }

    # fn: _dt_build_sortkey - Dt build sortkey
        # Purpose:
        #   Build a composite sort key for a datatable row.
        #
        # Behavior:
        #   - Acts as a internal helper within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   _dt_build_sortkey ...
    _dt_build_sortkey() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local sort_fields="${3:?missing sort fields}"
        local field=""
        local value=""
        local sortkey=""
        local -a fields=()

        IFS=',' read -r -a fields <<< "$sort_fields"

        for field in "${fields[@]}"; do
            field="${field//[[:space:]]/}"
            [[ -n "$field" ]] || continue

            value="$(sgnd_dt_row_get "$schema" "$row" "$field")" || return 1

            [[ -z "$sortkey" ]] || sortkey+="|"
            sortkey+="${value,,}"
        done

        printf '%s\n' "$sortkey"
    }
# --- Public API ---------------------------------------------------------------------
    # fn: sgnd_dt_validate_value - Dt validate value
        # Purpose:
        #   Validate a single datatable field value.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_validate_value ...
    sgnd_dt_validate_value() {
        local value="${1-}"

        [[ "$value" == *"|"* ]] && return 1
        [[ "$value" == *$'\n'* ]] && return 1
        return 0
    }

    # fn: sgnd_dt_validate_schema - Dt validate schema
        # Purpose:
        #   Validate a datatable schema string.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_validate_schema ...
    sgnd_dt_validate_schema() {
        local schema="${1-}"
        local i
        local j

        [[ -n "$schema" ]] || return 1

        sgnd_dt_split_schema "$schema"
        (( ${#SGND_DT_SPLIT[@]} > 0 )) || return 1

        for (( i=0; i<${#SGND_DT_SPLIT[@]}; i++ )); do
            [[ -n "${SGND_DT_SPLIT[i]}" ]] || return 1

            for (( j=i+1; j<${#SGND_DT_SPLIT[@]}; j++ )); do
                [[ "${SGND_DT_SPLIT[i]}" != "${SGND_DT_SPLIT[j]}" ]] || return 1
            done
        done

        return 0
    }

    # fn: sgnd_dt_column_index - Dt column index
        # Purpose:
        #   Return the zero-based index for a named schema column.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_column_index ...
    sgnd_dt_column_index() {
        local schema="${1:?missing schema}"
        local column="${2:?missing column name}"
        local i

        sgnd_dt_split_schema "$schema"

        for (( i=0; i<${#SGND_DT_SPLIT[@]}; i++ )); do
            [[ "${SGND_DT_SPLIT[i]}" == "$column" ]] || continue
            printf '%s\n' "$i"
            return 0
        done

        return 1
    }

    # fn: sgnd_dt_column_count - Dt column count
        # Purpose:
        #   Return the number of columns in a datatable schema.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_column_count ...
    sgnd_dt_column_count() {
        local schema="${1:?missing schema}"

        sgnd_dt_split_schema "$schema"
        printf '%s\n' "${#SGND_DT_SPLIT[@]}"
    }

    # fn: sgnd_dt_make_row - Dt make row
        # Purpose:
        #   Build one pipe-delimited datatable row from field values.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_make_row ...
    sgnd_dt_make_row() {
        local schema="${1:?missing schema}"
        shift

        local expected=0
        local actual=$#
        local field=""
        local row=""
        local i

        expected="$(sgnd_dt_column_count "$schema")"
        [[ "$actual" -eq "$expected" ]] || return 1

        for (( i=1; i<=actual; i++ )); do
            field="${!i}"
            sgnd_dt_validate_value "$field" || return 1

            [[ -z "$row" ]] || row+="|"
            row+="$field"
        done

        printf '%s\n' "$row"
    }

    # fn: sgnd_dt_has_row - Dt has row
        # Purpose:
        #   Test whether a datatable contains a row index.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_has_row ...
    sgnd_dt_has_row() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local column="${3:?missing column name}"
        local value="${4-}"

        sgnd_dt_find_first "$schema" "$table_name" "$column" "$value" >/dev/null 2>&1
    }

    # fn: sgnd_dt_row_get - Dt row get
        # Purpose:
        #   Return one complete datatable row by row index.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_row_get ...
    sgnd_dt_row_get() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local index=0

        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1
        sgnd_dt_split_row "$row"

        printf '%s\n' "${SGND_DT_SPLIT[index]-}"
    }

    # fn: sgnd_dt_row_set - Dt row set
        # Purpose:
        #   Replace one complete datatable row by row index.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_row_set ...
    sgnd_dt_row_set() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local value="${4-}"
        local index=0
        local i
        local out=""
        local column_count=0

        sgnd_dt_validate_value "$value" || return 1
        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1

        sgnd_dt_split_schema "$schema"
        column_count="${#SGND_DT_SPLIT[@]}"

        sgnd_dt_split_row "$row"

        for (( i=0; i<column_count; i++ )); do
            [[ -z "$out" ]] || out+="|"

            if (( i == index )); then
                out+="$value"
            else
                out+="${SGND_DT_SPLIT[i]-}"
            fi
        done

        printf '%s\n' "$out"
    }

    # fn: sgnd_dt_row_count - Dt row count
        # Purpose:
        #   Return the number of rows in a datatable.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_row_count ...
    sgnd_dt_row_count() {
        local table_name="${1:?missing table name}"

        sgnd_dt_array_length "$table_name"
    }

    # fn: sgnd_dt_insert - Dt insert
        # Purpose:
        #   Insert a row into a datatable.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_insert ...
    sgnd_dt_insert() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row="${3-}"
        local expected=0
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1
        expected="$(sgnd_dt_column_count "$schema")"

        sgnd_dt_split_row "$row"
        [[ "${#SGND_DT_SPLIT[@]}" -eq "$expected" ]] || return 1

        table_ref+=("$row")
    }

    # fn: sgnd_dt_delete - Dt delete
        # Purpose:
        #   Delete a row from a datatable.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_delete ...
    sgnd_dt_delete() {
        local table_name="${1:?missing table name}"
        local row_index="${2:?missing row index}"
        local row_count=0
        local -n table_ref="$table_name"

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        unset 'table_ref[row_index]'
        table_ref=("${table_ref[@]}")
    }

    # fn: sgnd_dt_get - Dt get
        # Purpose:
        #   Read one field value from a datatable row.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_get ...
    sgnd_dt_get() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row_index="${3:?missing row index}"
        local column="${4:?missing column name}"
        local row_count=0
        local -n table_ref="$table_name"

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        sgnd_dt_row_get "$schema" "${table_ref[row_index]}" "$column"
    }

    # fn: sgnd_dt_set - Dt set
        # Purpose:
        #   Set one field value in a datatable row.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_set ...
    sgnd_dt_set() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row_index="${3:?missing row index}"
        local column="${4:?missing column name}"
        local value="${5-}"
        local row_count=0
        local updated=""
        local -n table_ref="$table_name"

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        updated="$(sgnd_dt_row_set "$schema" "${table_ref[row_index]}" "$column" "$value")" || return 1
        table_ref[row_index]="$updated"
    }

    # fn: sgnd_dt_find_first - Dt find first
        # Purpose:
        #   Find the first row where a field matches a value.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_find_first ...
    sgnd_dt_find_first() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local column="${3:?missing column name}"
        local value="${4-}"
        local row_count=0
        local i
        local cell=""

        row_count="$(sgnd_dt_row_count "$table_name")"

        for (( i=0; i<row_count; i++ )); do
            cell="$(sgnd_dt_get "$schema" "$table_name" "$i" "$column")" || return 1
            [[ "$cell" == "$value" ]] || continue
            printf '%s\n' "$i"
            return 0
        done

        return 1
    }

    # fn: sgnd_dt_append - Dt append
        # Purpose:
        #   Append a row to a datatable.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_append ...
    sgnd_dt_append() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row=""

        shift 2

        row="$(sgnd_dt_make_row "$schema" "$@")" || return 1
        saydebug "Appending row to $schema $table_name: $row"
        sgnd_dt_insert "$schema" "$table_name" "$row"
    }

    # fn: sgnd_dt_print_table - Dt print table
        # Purpose:
        #   Print a datatable as formatted console output.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_print_table ...
    sgnd_dt_print_table() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local prettyprint="${3:-0}"
        local headercolor="${4:-}"
        local datacolor="${5:-}"
        local top_n="${6:-}"

        local row_count=0
        local print_count=0
        local col_count=0
        local i=0
        local j=0
        local k=0
        local cell=""
        local row=""
        local color_reset="${RESET:-}"
        local color_header=""
        local color_data=""
        local -a widths=()
        local -a columns=()
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        if [[ -n "$headercolor" || -n "$datacolor" ]]; then
            prettyprint=1
        fi

        if (( prettyprint )); then
            color_header="$(sgnd_sgr "${headercolor:-${CYAN:-}}" "" "$FX_BOLD")"
            color_data="${datacolor:-${SILVER:-}}"
        else
            color_header="${WHITE:-}"
            color_data="${SILVER:-}"
        fi

        sgnd_dt_split_schema "$schema"
        columns=("${SGND_DT_SPLIT[@]}")
        col_count="${#columns[@]}"
        row_count="${#table_ref[@]}"

        print_count="$row_count"

        if [[ -n "$top_n" && "$top_n" =~ ^[0-9]+$ ]]; then
            if (( top_n > 0 && top_n < row_count )); then
                print_count="$top_n"
            fi
        fi

        for (( j=0; j<col_count; j++ )); do
            widths[j]="${#columns[j]}"
        done

        for (( i=0; i<print_count; i++ )); do
            row="${table_ref[i]}"
            sgnd_dt_split_row "$row"

            for (( j=0; j<col_count; j++ )); do
                cell="${SGND_DT_SPLIT[j]-}"
                (( ${#cell} > widths[j] )) && widths[j]="${#cell}"
            done
        done

        if (( print_count < row_count )); then
            printf '\n%sTable: %s%s (%s of %s rows)%s\n' \
                "$color_header" \
                "$color_data" \
                "$table_name" \
                "$print_count" \
                "$row_count" \
                "$color_reset"
        else
            printf '\n%sTable: %s%s (%s rows)%s\n' \
                "$color_header" \
                "$color_data" \
                "$table_name" \
                "$row_count" \
                "$color_reset"
        fi

        # print top border
        printf '%s' "$color_header"

        for (( j=0; j<col_count; j++ )); do
            for (( k=0; k<widths[j]; k++ )); do
                printf "${LN_H:-─}"
            done

            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        # print column names
        printf '%s' "$color_header"

        for (( j=0; j<col_count; j++ )); do
            printf '%-*s' "${widths[j]}" "${columns[j]}"
            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        # print bottom border
        printf '%s' "$color_header"

        for (( j=0; j<col_count; j++ )); do
            for (( k=0; k<widths[j]; k++ )); do
                printf "${LN_H:-─}"
            done

            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        printf '%s' "$color_data"

        for (( i=0; i<print_count; i++ )); do
            row="${table_ref[i]}"
            sgnd_dt_split_row "$row"

            for (( j=0; j<col_count; j++ )); do
                cell="${SGND_DT_SPLIT[j]-}"
                printf '%-*s' "${widths[j]}" "$cell"
                (( j < col_count - 1 )) && printf '  '
            done

            printf '\n'
        done

        printf '%s' "$color_reset"
    }

    # fn: sgnd_dt_get_sorted_rows - Dt get sorted rows
        # Purpose:
        #   Return datatable rows sorted by one or more schema fields.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_get_sorted_rows ...
    sgnd_dt_get_sorted_rows() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local sort_fields="${3:?missing sort fields}"
        local row=""
        local sortkey=""
        local row_count=0
        local i=0
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"

        for (( i=0; i<row_count; i++ )); do
            row="${table_ref[i]}"
            sortkey="$(_dt_build_sortkey "$schema" "$row" "$sort_fields")" || return 1

            printf '%s\t%s\n' "$sortkey" "$row"
        done | sort -t $'\t' -k1,1 | cut -f2-
    }

    # fn: sgnd_dt_row2var - Dt row2var
        # Purpose:
        #   Assign datatable row values to shell variables.
        #
        # Behavior:
        #   - Acts as a public API function within this module.
        #   - Uses framework conventions for return codes and diagnostic output.
        #
        # Returns:
        #   0 on success unless otherwise noted by the called command.
        #
        # Usage:
        #   sgnd_dt_row2var ...
    sgnd_dt_row2var() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row="${3-}"

        local i
        local field_name
        local var_name
        local -a columns=()

        sgnd_dt_validate_schema "$schema" || return 1

        sgnd_dt_split_schema "$schema"
        columns=("${SGND_DT_SPLIT[@]}")

        sgnd_dt_split_row "$row"

        for (( i=0; i<${#columns[@]}; i++ )); do
            field_name="${columns[i]}"

            field_name="${field_name,,}"
            field_name="${field_name//-/_}"

            var_name="${table_name}_${field_name}"

            printf -v "$var_name" '%s' "${SGND_DT_SPLIT[i]-}"
        done
    }

    # fn: sgnd_dt_export_psv
        # Purpose:
        #   Export a datatable array to a pipe-separated value file.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_ARRAY_NAME
        #   $3  OUTPUT_FILE
        #
        # Returns:
        #   0 on success.
        #   1 on invalid input or write failure.
    sgnd_dt_export_psv() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local output_file="${3:?missing output file}"

        local output_dir=""
        local row=""
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        output_dir="$(dirname "$output_file")"
        mkdir -p "$output_dir" || return 1

        {
            printf '%s\n' "$schema"

            for row in "${table_ref[@]}"; do
                printf '%s\n' "$row"
            done
        } > "$output_file" || return 1

        return 0
    }
