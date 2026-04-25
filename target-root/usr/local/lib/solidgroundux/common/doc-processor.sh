# ==================================================================================
# SolidgroundUX - Library Template
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : none
#   Source      : doc-processor.sh
#   Type        : library
#   Group       : Templates
#   Purpose     : Parse source files for comments and assemble documentation
#
# Description:
#
# Design principles:
#
# Role in framework:
#
# Non-goals:
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # $tfn: _sgnd_lib_guard
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

# - Internal Definitions ---------------------------------------------------------
    # Naming:
    #   - Prefix internal-only helpers with "_" (never "sgnd_")
    # Example:
    #   __<libname>_helper() { :; }
# - Internal API ----------------------------------------------------------------
    # $fn _parse_module_file
    _parse_module_file(){
        local file="${1:-}"
        [[ -z "$file" ]] && {
            sayerror "No filename was passed"
            return 1
        }
        sayinfo "Parsing file $file"

        local total_lines
        local linenr=0
        local line

        total_lines=$(wc -l < "$file")

        while IFS= read -r line || [[ -n "$line" ]]; do
            ((linenr++))

            sayprogress \
                --slot 1 \
                --current "$linenr" \
                --total "$total_lines" \
                --label "Parsing $(basename "$file")" \
                --type 5

            # parsing logic...

        done < "$file"

        return 0
    }   

    _render_site(){
        local output_folder="${1:-}"
        [[ -z "$output_folder" ]] && {
            sayerror "No outputfolder was passed"
            return 1
        }
        sayinfo "Rendering site to $output_folder"
        return 0
    } 


