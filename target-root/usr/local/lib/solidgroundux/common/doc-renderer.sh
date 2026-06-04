# ==================================================================================
# SolidgroundUX - Documentation Renderer
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615500
#   Checksum    : -
#   Source      : doc-renderer.sh
#   Type        : library
#   Group       : Developer Tools
#   Purpose     : Prepare normalized parser data and invoke the documentation renderer
#
# Description:
#   Converts parser-owned documentation tables into renderer input files and delegates
#   final HTML generation to the Python documentation renderer.
#
# Design principles:
#   - Keep parsing, export preparation, and final rendering separate.
#   - Use explicit table-shaped arrays and PSV files as intermediate models.
#   - Preserve deterministic ordering and stable content references.
#   - Avoid hidden relational behavior or synthetic database-like machinery.
#
# Role in framework:
#   - Post-processing and hand-off layer between doc-processor and concrete renderers.
#   - Exports parser tables as the canonical input set for renderer implementations.
#   - Invokes the Python HTML renderer for the current documentation output.
#
# Non-goals:
#   - Parsing source files.
#   - Owning source comment grammar.
#   - Performing final format-specific rendering directly in Bash.
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
    # fn$: _sgnd_lib_guard - Prevent direct execution and repeated library initialization
        # Purpose:
        #   Apply the standard SGND library guard for source-only modules.
        #
        # Behavior:
        #   - Rejects direct execution of this file.
        #   - Derives a module-specific guard variable from the current filename.
        #   - Returns immediately when the library was already initialized.
        #   - Marks the library as loaded before module initialization continues.
        #
        # Returns:
        #   0 when the library may continue loading or was already loaded.
        #   Exits with status 2 when the file is executed directly.
        #
        # Usage:
        #   _sgnd_lib_guard
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
    # var: Render cache directory - Optional location for renderer cache data
        # Purpose:
        #   Reserve a shared variable for renderer cache location configuration.
        #
        # Behavior:
        #   - Defaults to an empty value.
        #   - May be populated by future renderer/cache logic.
        #
        # Notes:
        #   - The current renderer hand-off does not actively use this value.
        DOC_RENDER_CACHE_DIR=""

    # var: Postprocess datamodel - Renderer-side documentation indexes
        # Purpose:
        #   Define renderer-owned index tables derived from parser output.
        #
        # Behavior:
        #   - Stores attribution and function lookup data for documentation indexes.
        #   - Keeps post-processing output separate from parser-owned tables.
        #   - Uses schema strings as explicit table contracts for sgnd-datatable helpers.
        #
        # Tables:
        #   DOC_ATTRIBUTION_INDEX
        #     Groups attribution metadata by company, developer, license, module, product, and group.
        #
        #   DOC_FUNCTION_INDEX
        #     Lists documented functions by product, group, module, visibility, name, purpose, and anchor.
        #
        # Notes:
        #   - These tables are renderer indexes, not parser input contracts.
        #   - Concrete renderers may consume these indexes together with exported parser tables.
        DOC_ATTRIBUTION_INDEX_SCHEMA="company|developer|license|modulename|moduletitle|product|group"
        DOC_ATTRIBUTION_INDEX=()

        DOC_FUNCTION_INDEX_SCHEMA="product|group|modulename|itemvisibility|functionname|purpose|anchor"
        DOC_FUNCTION_INDEX=()

    # -- Arguments ------------------------------------------------------------------
        # var: Render options - Documentation output selection and ordering defaults
            # Purpose:
            #   Define default renderer options used by documentation generation.
            #
            # Behavior:
            #   - Controls whether internal items and empty sections are included.
            #   - Defines default grouping and sort expressions for indexes, sections, and items.
            #
            # Notes:
            #   - These values are configuration defaults, not parser-owned data.
            #   - Concrete renderers may interpret only the options they support.
        FLAG_INCLUDE_INTERNAL=0
        FLAG_INCLUDE_EMPTY_SECTIONS=1
        
        VAL_INDEX_GROUPBY="product,group,type"
        VAL_SECTION_SORTBY="modulename,parent,section,level"
        VAL_ITEM_SORTBY="modulename,section,itemvisibility,type,name"

    # -- Helpers --------------------------------------------------------------------
        # fn: _init_metadata - Initialize document-level render metadata
            # Purpose:
            #   Populate renderer metadata from document configuration values.
            #
            # Behavior:
            #   - Copies configured title, subtitle, version, and product values into DOC_* variables.
            #   - Records the render timestamp in UTC ISO-like format.
            #
            # Inputs (globals):
            #   VAL_DOCUMENT_TITLE, VAL_DOCUMENT_SUBTITLE, VAL_DOCUMENT_VERSION, VAL_DOCUMENT_PRODUCT
            #
            # Outputs (globals):
            #   DOC_TITLE, DOC_SUBTITLE, DOC_VERSION, DOC_PRODUCT, DOC_RENDER_DATE
            #
            # Returns:
            #   0 on successful initialization.
            #
            # Usage:
            #   _init_metadata
        _init_metadata() {
            DOC_TITLE="${VAL_DOCUMENT_TITLE:-}"
            DOC_SUBTITLE="${VAL_DOCUMENT_SUBTITLE:-}"
            DOC_VERSION="${VAL_DOCUMENT_VERSION:-}"
            DOC_PRODUCT="${VAL_DOCUMENT_PRODUCT:-}"
            DOC_RENDER_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        }

        # fn: _prepare_output_directory - Create and optionally clean the documentation output directory
            # Purpose:
            #   Ensure the configured output directory exists and is ready for rendering.
            #
            # Behavior:
            #   - Creates VAL_OUTDIR when it does not exist.
            #   - Cleans existing output when FLAG_CLEAN_OUTPUT is enabled.
            #   - Preserves an existing assets/theme.css file across clean output runs.
            #
            # Inputs (globals):
            #   VAL_OUTDIR, FLAG_CLEAN_OUTPUT
            #
            # Outputs:
            #   Creates or modifies files under VAL_OUTDIR.
            #
            # Returns:
            #   0 when the directory is ready.
            #   1 when creation, cleanup, or theme preservation fails.
            #
            # Usage:
            #   _prepare_output_directory
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

        # fn: _export_render_config - Export renderer configuration to a PSV file
            # Purpose:
            #   Write document-level render settings in the same table format used by exported parser data.
            #
            # Behavior:
            #   - Writes a key|value header.
            #   - Exports title, subtitle, version, product, clean-output behavior, and navigation width.
            #   - Forces FLAG_CLEAN_OUTPUT to 0 for the Python renderer hand-off to avoid recursive cleanup.
            #
            # Arguments:
            #   $1  Target render_config.psv file.
            #
            # Returns:
            #   0 when the file is written.
            #   Non-zero when the target file cannot be written.
            #
            # Usage:
            #   _export_render_config "$export_dir/render_config.psv"
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

        # fn: _export_render_tables - Export parser tables for the Python renderer
            # Purpose:
            #   Persist normalized documentation tables into a temporary render hand-off directory.
            #
            # Behavior:
            #   - Creates the export directory when needed.
            #   - Exports module, section, item, attribution, and content-line tables as PSV files.
            #   - Exports renderer configuration alongside parser data.
            #
            # Arguments:
            #   $1  Directory that receives the exported PSV files.
            #
            # Inputs (globals):
            #   MOD_TABLE, MOD_SECTIONS, MOD_ITEMS, MOD_ATTRIBUTION, DOC_CONTENT_LINES
            #   and their corresponding schema variables.
            #
            # Returns:
            #   0 when all tables and config are exported.
            #   1 when directory creation or any export step fails.
            #
            # Usage:
            #   _export_render_tables "$export_dir"
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
                "$MOD_ATTRIBUTION_SCHEMA" \
                MOD_ATTRIBUTION \
                "$export_dir/mod_attribution.psv" \
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
        #   - Prepares and optionally cleans the output directory.
        #   - Initializes document-level metadata.
        #   - Exports parser tables and renderer configuration to a temporary directory.
        #   - Invokes the Python HTML renderer.
        #   - Verifies that index.html was created.
        #
        # Arguments:
        #   $1  Output folder for generated documentation.
        #
        # Returns:
        #   0 when rendering completes and index.html exists.
        #   1 when validation, preparation, export, rendering, or output verification fails.
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
    


    
