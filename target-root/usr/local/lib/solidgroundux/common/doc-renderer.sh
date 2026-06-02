# ==================================================================================
# SolidgroundUX - Documentation Renderer
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2615311
#   Checksum    : 2210387a234ae326343c511a5525a642ebe66b6ed9a3e2d4a698eb1465ddd8ce
#   Source      : doc-renderer.sh
#   Type        : library
#   Group       : Developer Tools
#   Purpose     : Build documentation indexes and render output from normalized parser data
#
# Description:
#   Converts parsed documentation tables into a strict navigation hierarchy and
#   prepares renderer-friendly indexes.
#
# Design principles:
#   - Keep parsing, hierarchy construction, and rendering separate.
#   - Use explicit table-shaped arrays as intermediate models.
#   - Preserve deterministic ordering and stable content references.
#   - Avoid hidden relational behavior or synthetic database-like machinery.
#
# Role in framework:
#   - Post-processing layer between doc-processor and concrete renderers.
#   - Builds DOC_NAV as the canonical scaffold for documentation output.
#   - Provides shared hierarchy metadata for HTML, Markdown, PDF, or other targets.
#
# Non-goals:
#   - Parsing source files.
#   - Owning source comment grammar.
#   - Performing final format-specific rendering directly in hierarchy builders.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
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

# - Local definitions -------------------------------------------------------------
    DOC_RENDER_CACHE_DIR=""

    # var: Postprocess datamodel
        DOC_ATTRIBUTION_INDEX_SCHEMA="company|developer|license|modulename|moduletitle|product|group"
        DOC_ATTRIBUTION_INDEX=()

        DOC_FUNCTION_INDEX_SCHEMA="product|group|modulename|itemvisibility|functionname|purpose|anchor"
        DOC_FUNCTION_INDEX=()

    # -- Arguments ------------------------------------------------------------------
        FLAG_INCLUDE_INTERNAL=0
        FLAG_INCLUDE_EMPTY_SECTIONS=1
        
        VAL_INDEX_GROUPBY="product,group,type"
        VAL_SECTION_SORTBY="modulename,parent,section,level"
        VAL_ITEM_SORTBY="modulename,section,itemvisibility,type,name"

    # -- Helpers --------------------------------------------------------------------
        _init_metadata() {
            DOC_TITLE="${VAL_DOCUMENT_TITLE:-}"
            DOC_SUBTITLE="${VAL_DOCUMENT_SUBTITLE:-}"
            DOC_VERSION="${VAL_DOCUMENT_VERSION:-}"
            DOC_PRODUCT="${VAL_DOCUMENT_PRODUCT:-}"
            DOC_RENDER_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        }

        _prepare_output_directory() {
            if [[ -d "$VAL_OUTDIR" ]]; then
                sayinfo "Output directory already exists: $VAL_OUTDIR"
            else
                mkdir -p "$VAL_OUTDIR" && sayinfo "Created output directory: $VAL_OUTDIR" || {
                    sayerror "Failed to create output directory: $VAL_OUTDIR"
                    return 1
                }
            fi

           if (( FLAG_CLEAN_OUTPUT == 1 )); then
                sayinfo "Cleaning output directory: $VAL_OUTDIR"

                local preserved_theme=""
                if [[ -f "$VAL_OUTDIR/assets/theme.css" ]]; then
                    preserved_theme="$(mktemp /tmp/sgnd-doc-theme.XXXXXX.css)" || return 1
                    cp "$VAL_OUTDIR/assets/theme.css" "$preserved_theme" || return 1
                fi

                rm -rf "${VAL_OUTDIR:?}/"* && sayinfo "Cleaned output directory: $VAL_OUTDIR" || {
                    sayerror "Failed to clean output directory: $VAL_OUTDIR"
                    return 1
                }

                if [[ -n "$preserved_theme" && -f "$preserved_theme" ]]; then
                    mkdir -p "$VAL_OUTDIR/assets" || return 1
                    cp "$preserved_theme" "$VAL_OUTDIR/assets/theme.css" || return 1
                    rm -f "$preserved_theme"
                    sayinfo "Preserved existing theme.css"
                fi
            fi
        }

        _export_render_config() {

            local config_file="${1:?missing config file}"

            {
                printf '%s\n' 'key|value'
                printf 'VAL_DOCUMENT_TITLE|%s\n' "${VAL_DOCUMENT_TITLE:-}"
                printf 'VAL_DOCUMENT_SUBTITLE|%s\n' "${VAL_DOCUMENT_SUBTITLE:-}"
                printf 'VAL_DOCUMENT_VERSION|%s\n' "${VAL_DOCUMENT_VERSION:-}"
                printf 'VAL_DOCUMENT_PRODUCT|%s\n' "${VAL_DOCUMENT_PRODUCT:-}"
                printf 'FLAG_CLEAN_OUTPUT|0\n'
                printf 'VAL_NAV_WIDTH|%s\n' "${VAL_NAV_WIDTH:-320px}"

            } > "$config_file"
        }

        _export_render_tables() {
            local export_dir="${1:?missing export dir}"

            mkdir -p "$export_dir" || return 1

            sgnd_dt_export_psv \
                "$MOD_TABLE_SCHEMA" \
                MOD_TABLE \
                "$export_dir/mod_table.psv" \
                || return 1

            sgnd_dt_export_psv \
                "$MOD_SECTIONS_SCHEMA" \
                MOD_SECTIONS \
                "$export_dir/mod_sections.psv" \
                || return 1

            sgnd_dt_export_psv \
                "$MOD_ITEMS_SCHEMA" \
                MOD_ITEMS \
                "$export_dir/mod_items.psv" \
                || return 1

            sgnd_dt_export_psv \
                "$DOC_CONTENT_LINES_SCHEMA" \
                DOC_CONTENT_LINES \
                "$export_dir/doc_content_lines.psv" \
                || return 1

            _export_render_config \
                "$export_dir/render_config.psv" \
                || return 1
        }

# - Main sequence ----------------------------------------------------------
    # fn: _render_site - Render collected documentation data
        # Purpose:
        #   Provide the renderer hand-off point for collected documentation tables.
        #
        # Behavior:
        #   - Validates the output folder argument.
        #   - Logs the target output folder.
        #   - Placeholder for future HTML/PDF rendering implementation.
        #
        # Arguments:
        #   $1  Output folder for generated documentation.
        #
        # Returns:
        #   0 on successful hand-off.
        #   1 when no output folder is supplied.
        #
        # Usage:
        #   _render_site "$VAL_OUTDIR"
    _render_site(){
        local output_folder="${1:-}"
        [[ -z "$output_folder" ]] && {
            sayerror "No outputfolder was passed"
            return 1
        }
        saydebug "Rendering site to $output_folder"

        _prepare_output_directory || {
            sayerror "Failed to prepare output directory"
            return 1
        }

        _init_metadata || {
            sayerror "Failed to initialize documentation metadata"
            return 1
        }

        local export_dir=""
        export_dir="$(mktemp -d "/tmp/sgnd-doc-render.XXXXXX")" || {
            sayerror "Failed to create temporary export directory"
            return 1
        }

        _export_render_tables "$export_dir" || {
            sayerror "Failed to export render tables for Python renderer"
            return 1
        }

        sayinfo "Python renderer input : $export_dir"
        sayinfo "Python renderer output: $output_folder"
        sayinfo "Python renderer script: $SGND_PYTHON_DIR/sgnd_doc_renderer.py"

        python3 "$SGND_PYTHON_DIR/sgnd_doc_renderer.py" \
            "$export_dir" \
            "$output_folder" || {
                sayfail "Python documentation renderer failed"
                return 1
        }



        if [[ ! -f "$output_folder/index.html" ]]; then
            sayerror "Python renderer completed, but index.html was not created in: $output_folder"
            return 1
        fi
        sayinfo "Documentation rendering complete. Output available at: $output_folder"

        return 0
    } 
    


    
