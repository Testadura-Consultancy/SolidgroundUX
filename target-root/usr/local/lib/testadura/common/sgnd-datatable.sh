# =====================================================================================
# SolidgroundUX - Datatable
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608203
#   Checksum    : 8558c003868728dcc3faacf82fadaf4b5c989e3e4d500c472bdef082b7a9c42b
#   Source      : sgnd-datatable.sh
#   Type        : library
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

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# --- Internal helpers ---------------------------------------------------------------
    # sgnd__dt_array_length
        # Purpose:
        #   Return the length of an indexed array by name.
        #
        # Arguments:
        #   $1  ARRAY_NAME
        #
        # Outputs:
        #   Prints array length to stdout.
        #
        # Returns:
        #   0  success
        #
        # Usage:
        #   sgnd__dt_array_length ARRAY_NAME
        #
        # Examples:
        #   count="$(sgnd__dt_array_length MY_ROWS)"
    sgnd__dt_array_length() {
        local array_name="${1:?missing array name}"

        eval "printf '%s\n' \"\${#$array_name[@]}\""
    }

    # sgnd__dt_split_schema
        # Purpose:
        #   Split a schema string into positional column names.
        #
        # Arguments:
        #   $1  SCHEMA
        #
        # Outputs:
        #   Writes column names into global helper array SGND_DT_SPLIT.
        #
        # Returns:
        #   0  success
        #
        # Usage:
        #   sgnd__dt_split_schema "$SCHEMA"
        #
        # Examples:
        #   sgnd__dt_split_schema "id|name|desc"
        #   echo "${SGND_DT_SPLIT[1]}"   # name
        #   0  success
    sgnd__dt_split_schema() {
        local schema="${1:?missing schema}"

        IFS='|' read -r -a SGND_DT_SPLIT <<< "$schema"
    }

    # sgnd__dt_split_row
        # Purpose:
        #   Split a row string into positional field values.
        #
        # Behavior:
        #   - Splits on pipe ('|') delimiter
        #   - Preserves empty fields, including trailing empty values
        #   - Guarantees column count consistency with schema-based rows
        #
        # Arguments:
        #   $1  ROW
        #
        # Outputs:
        #   Writes field values into global helper array SGND_DT_SPLIT.
        #
        # Returns:
        #   0  success
        #
        # Usage:
        #   sgnd__dt_split_row "$ROW"
        #
        # Examples:
        #   sgnd__dt_split_row "1|Tools|Utility"
        #   echo "${SGND_DT_SPLIT[2]}"   # Utility
        #
        #   sgnd__dt_split_row "1|Tools|"
        #   echo "${SGND_DT_SPLIT[2]}"   # (empty string)
    sgnd__dt_split_row() {
        local row="${1-}"
        local tmp=""

        tmp="${row}|__SGND_SENTINEL__"
        IFS='|' read -r -a SGND_DT_SPLIT <<< "$tmp"

        unset 'SGND_DT_SPLIT[${#SGND_DT_SPLIT[@]}-1]'
    }

# --- Public API ---------------------------------------------------------------------
    # sgnd_dt_validate_value
        # Purpose:
        #   Validate whether a field value is supported by v1 storage rules.
        #
        # Rules:
        #   - value must not contain a literal pipe character
        #   - value must not contain a newline
        #
        # Arguments:
        #   $1  VALUE
        #
        # Returns:
        #   0  value is valid
        #   1  value contains unsupported characters
        #
        # Usage:
        #   sgnd_dt_validate_value VALUE
        #
        # Examples:
        #   if sgnd_dt_validate_value "$input"; then
        #       sayinfo "Value OK"
        #   fi
    sgnd_dt_validate_value() {
        local value="${1-}"

        [[ "$value" == *"|"* ]] && return 1
        [[ "$value" == *$'\n'* ]] && return 1
        return 0
    }

    # sgnd_dt_validate_schema
        # Purpose:
        #   Validate a schema string.
        #
        # Rules:
        #   - schema must not be empty
        #   - each column name must be non-empty
        #   - duplicate column names are not allowed
        #
        # Arguments:
        #   $1  SCHEMA
        #
        # Returns:
        #   0  schema is valid
        #   1  schema is invalid
        #
        # Usage:
        #   sgnd_dt_validate_schema "$SCHEMA"
        #
        # Examples:
        #   if ! sgnd_dt_validate_schema "$MY_SCHEMA"; then
        #       sayfail "Invalid schema"
        #   fi
    sgnd_dt_validate_schema() {
        local schema="${1-}"
        local i
        local j

        [[ -n "$schema" ]] || return 1

        sgnd__dt_split_schema "$schema"

        (( ${#SGND_DT_SPLIT[@]} > 0 )) || return 1

        for (( i=0; i<${#SGND_DT_SPLIT[@]}; i++ )); do
            [[ -n "${SGND_DT_SPLIT[i]}" ]] || return 1

            for (( j=i+1; j<${#SGND_DT_SPLIT[@]}; j++ )); do
                [[ "${SGND_DT_SPLIT[i]}" != "${SGND_DT_SPLIT[j]}" ]] || return 1
            done
        done

        return 0
    }

    # sgnd_dt_column_index
        # Purpose:
        #   Resolve a column name to its zero-based index within a schema.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  COLUMN_NAME
        #
        # Outputs:
        #   Prints the zero-based column index to stdout.
        #
        # Returns:
        #   0  column found
        #   1  column not found
        #
        # Usage:
        #   sgnd_dt_column_index "$SCHEMA" COLUMN
        #
        # Examples:
        #   idx="$(sgnd_dt_column_index "$MY_SCHEMA" "name")"
    sgnd_dt_column_index() {
        local schema="${1:?missing schema}"
        local column="${2:?missing column name}"
        local i

        sgnd__dt_split_schema "$schema"

        for (( i=0; i<${#SGND_DT_SPLIT[@]}; i++ )); do
            [[ "${SGND_DT_SPLIT[i]}" == "$column" ]] || continue
            printf '%s\n' "$i"
            return 0
        done

        return 1
    }

    # sgnd_dt_column_count
        # Purpose:
        #   Return the number of columns in a schema.
        #
        # Arguments:
        #   $1  SCHEMA
        #
        # Outputs:
        #   Prints column count to stdout.
        #
        # Returns:
        #   0  success
    sgnd_dt_column_count() {
        local schema="${1:?missing schema}"

        sgnd__dt_split_schema "$schema"
        printf '%s\n' "${#SGND_DT_SPLIT[@]}"
    }

    # sgnd_dt_make_row
        # Purpose:
        #   Build a row string from positional field values.
        #
        # Arguments:
        #   $1   SCHEMA
        #   $2+  VALUES matching schema order
        #
        # Outputs:
        #   Prints the constructed row string to stdout.
        #
        # Returns:
        #   0  success
        #   1  wrong field count or invalid field value
        #
        # Usage:
        #   sgnd_dt_make_row "$SCHEMA" VALUE1 VALUE2 ...
        #
        # Examples:
        #   row="$(sgnd_dt_make_row "$MY_SCHEMA" "1" "Tools" "Utility module")"
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

    # sgnd_dt_has_row
        # Purpose:
        #   Test whether a table contains at least one row where a given column
        #   equals the specified value.
        #
        # Behavior:
        #   - Performs a linear scan over the table rows.
        #   - Uses sgnd_dt_find_first internally.
        #   - Produces no output; success/failure is indicated by the return code.
        #
        # Arguments:
        #   $1  SCHEMA             Pipe-separated column definition string
        #   $2  TABLE_ARRAY_NAME   Name of the indexed array containing row strings
        #   $3  COLUMN_NAME        Column to test
        #   $4  VALUE              Value to match
        #
        # Returns:
        #   0  At least one matching row exists
        #   1  No matching row found or column does not exist
        #
        # Example:
        #   if sgnd_dt_has_row "$MY_SCHEMA" MY_ROWS key "Q"; then
        #       sayinfo "Quit item already registered"
        #   fi
    sgnd_dt_has_row() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local column="${3:?missing column name}"
        local value="${4-}"

        sgnd_dt_find_first "$schema" "$table_name" "$column" "$value" >/dev/null 2>&1
    }
    
    # sgnd_dt_row_get
        # Purpose:
        #   Get the value of one column from a row string.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  ROW
        #   $3  COLUMN_NAME
        #
        # Outputs:
        #   Prints the field value to stdout.
        #
        # Returns:
        #   0  success
        #   1  column not found
    sgnd_dt_row_get() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local index=0

        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1
        sgnd__dt_split_row "$row"

        printf '%s\n' "${SGND_DT_SPLIT[index]-}"
    }

    # sgnd_dt_row_set
        # Purpose:
        #   Set the value of one column within a row string.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  ROW
        #   $3  COLUMN_NAME
        #   $4  VALUE
        #
        # Outputs:
        #   Prints the updated row string to stdout.
        #
        # Returns:
        #   0  success
        #   1  invalid column or invalid value
    sgnd_dt_row_set() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local value="${4-}"
        local index=0
        local i
        local out=""

        sgnd_dt_validate_value "$value" || return 1
        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1

        sgnd__dt_split_schema "$schema"
        local column_count="${#SGND_DT_SPLIT[@]}"

        sgnd__dt_split_row "$row"

        for (( i=0; i<column_count; i++ )); do
            if (( i == index )); then
                [[ -z "$out" ]] || out+="|"
                out+="$value"
            else
                [[ -z "$out" ]] || out+="|"
                out+="${SGND_DT_SPLIT[i]-}"
            fi
        done

        printf '%s\n' "$out"
    }

    # sgnd_dt_row_count
        # Purpose:
        #   Return the number of rows in a table array.
        #
        # Arguments:
        #   $1  TABLE_ARRAY_NAME
        #
        # Outputs:
        #   Prints row count to stdout.
        #
        # Returns:
        #   0  success
    sgnd_dt_row_count() {
        local table_name="${1:?missing table name}"

        sgnd__dt_array_length "$table_name"
    }

    # sgnd_dt_insert
        # Purpose:
        #   Append a row string to a table array.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_ARRAY_NAME
        #   $3  ROW
        #
        # Returns:
        #   0  success
        #   1  invalid schema or row width mismatch
        #
        # Usage:
        #   sgnd_dt_insert "$SCHEMA" ARRAY_NAME ROW
        #
        # Examples:
        #   sgnd_dt_insert "$MY_SCHEMA" MY_ROWS "1|Tools|Utility module"
    sgnd_dt_insert() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row="${3-}"

        local expected=0

        sgnd_dt_validate_schema "$schema" || return 1

        expected="$(sgnd_dt_column_count "$schema")"

        sgnd__dt_split_row "$row"
        [[ "${#SGND_DT_SPLIT[@]}" -eq "$expected" ]] || return 1

        eval "$table_name+=(\"\$row\")"
    }

    # sgnd_dt_delete
        # Purpose:
        #   Delete one row from a table array by index.
        #
        # Arguments:
        #   $1  TABLE_ARRAY_NAME
        #   $2  ROW_INDEX
        #
        # Returns:
        #   0  success
        #   1  invalid row index
    sgnd_dt_delete() {
        local table_name="${1:?missing table name}"
        local row_index="${2:?missing row index}"
        local row_count=0

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        eval "unset '$table_name[$row_index]'"
        eval "$table_name=(\"\${$table_name[@]}\")"
    }

    # sgnd_dt_get
        # Purpose:
        #   Get one cell value from a table by row index and column name.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_ARRAY_NAME
        #   $3  ROW_INDEX
        #   $4  COLUMN_NAME
        #
        # Outputs:
        #   Prints the field value to stdout.
        #
        # Returns:
        #   0  success
        #   1  invalid row index or invalid column
        #
        # Usage:
        #   sgnd_dt_get "$SCHEMA" ARRAY INDEX COLUMN
        #
        # Examples:
        #   name="$(sgnd_dt_get "$MY_SCHEMA" MY_ROWS 0 name)"
    sgnd_dt_get() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row_index="${3:?missing row index}"
        local column="${4:?missing column name}"
        local row_count=0
        local row=""

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        eval "row=\${$table_name[$row_index]}"
        sgnd_dt_row_get "$schema" "$row" "$column"
    }

    # sgnd_dt_set
        # Purpose:
        #   Set one cell value in a table by row index and column name.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_ARRAY_NAME
        #   $3  ROW_INDEX
        #   $4  COLUMN_NAME
        #   $5  VALUE
        #
        # Returns:
        #   0  success
        #   1  invalid row index, invalid column, or invalid value
        #
        # Usage:
        #   sgnd_dt_set "$SCHEMA" ARRAY INDEX COLUMN VALUE
        #
        # Examples:
        #   sgnd_dt_set "$MY_SCHEMA" MY_ROWS 0 name "Updated"
    sgnd_dt_set() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row_index="${3:?missing row index}"
        local column="${4:?missing column name}"
        local value="${5-}"
        local row_count=0
        local row=""
        local updated=""

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        eval "row=\${$table_name[$row_index]}"
        updated="$(sgnd_dt_row_set "$schema" "$row" "$column" "$value")" || return 1
        eval "$table_name[$row_index]=\"\$updated\""
    }

    # sgnd_dt_find_first
        # Purpose:
        #   Find the first row index where COLUMN_NAME equals VALUE.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_ARRAY_NAME
        #   $3  COLUMN_NAME
        #   $4  VALUE
        #
        # Outputs:
        #   Prints the first matching row index to stdout.
        #
        # Returns:
        #   0  match found
        #   1  no match
        #
        # Usage:
        #   sgnd_dt_find_first "$SCHEMA" ARRAY COLUMN VALUE
        #
        # Examples:
        #   idx="$(sgnd_dt_find_first "$MY_SCHEMA" MY_ROWS key "Q")"
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

    # sgnd_dt_append
        # Purpose:
        #   Build and append a row from positional values.
        #
        # Arguments:
        #   $1   SCHEMA
        #   $2   TABLE_ARRAY_NAME
        #   $3+  VALUES
        #
        # Returns:
        #   0  success
        #   1  invalid values or width mismatch
        #
        # Usage:
        #   sgnd_dt_append "$SCHEMA" ARRAY VALUE1 VALUE2 ...
        #
        # Examples:
        #   sgnd_dt_append "$MY_SCHEMA" MY_ROWS "2" "Config" "Settings module"
    sgnd_dt_append() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        shift 2

        local row=""

        row="$(sgnd_dt_make_row "$schema" "$@")" || return 1
        sgnd_dt_insert "$schema" "$table_name" "$row"
    }

    # sgnd_dt_print_table
        # Purpose:
        #   Print a table in aligned column form.
        #
        # Arguments:
        #   $1  SCHEMA
        #   $2  TABLE_ARRAY_NAME
        #
        # Returns:
        #   0  success
        #   1  invalid schema
        #
        # Usage:
        #   sgnd_dt_print_table "$SCHEMA" ARRAY_NAME
        #
        # Examples:
        #   sgnd_dt_print_table "$MY_SCHEMA" MY_ROWS
    sgnd_dt_print_table() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"

        local row_count=0
        local col_count=0
        local i=0
        local j=0
        local cell=""
        local row=""
        local header=""
        local sep=""
        local -a widths=()
        local -a columns=()

        sgnd_dt_validate_schema "$schema" || return 1

        sgnd__dt_split_schema "$schema"
        columns=("${SGND_DT_SPLIT[@]}")
        col_count="${#columns[@]}"
        row_count="$(sgnd_dt_row_count "$table_name")"

        # Initialize widths from header names
        for (( j=0; j<col_count; j++ )); do
            widths[j]="${#columns[j]}"
        done

        # Determine max width per column from row data
        for (( i=0; i<row_count; i++ )); do
            eval "row=\${$table_name[$i]}"
            sgnd__dt_split_row "$row"

            for (( j=0; j<col_count; j++ )); do
                cell="${SGND_DT_SPLIT[j]-}"
                (( ${#cell} > widths[j] )) && widths[j]="${#cell}"
            done
        done

        # Print header
        for (( j=0; j<col_count; j++ )); do
            printf '%-*s' "${widths[j]}" "${columns[j]}"
            (( j < col_count - 1 )) && printf '  '
        done
        printf '\n'

        # Print separator
        for (( j=0; j<col_count; j++ )); do
            printf '%-*s' "${widths[j]}" ''
            (( j < col_count - 1 )) && printf '  '
        done | tr ' ' '-'
        printf '\n'

        # Print rows
        for (( i=0; i<row_count; i++ )); do
            eval "row=\${$table_name[$i]}"
            sgnd__dt_split_row "$row"

            for (( j=0; j<col_count; j++ )); do
                cell="${SGND_DT_SPLIT[j]-}"
                printf '%-*s' "${widths[j]}" "$cell"
                (( j < col_count - 1 )) && printf '  '
            done
            printf '\n'
        done
    }
