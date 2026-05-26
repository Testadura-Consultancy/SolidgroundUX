# ==================================================================================
# SolidgroundUX - Documentation Renderer
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : none
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
    # var: Postprocess datamodel
        DOC_ATTRIBUTION_INDEX_SCHEMA="company|developer|license|modulename|moduletitle|product|group"
        DOC_ATTRIBUTION_INDEX=()

        DOC_FUNCTION_INDEX_SCHEMA="product|group|modulename|itemvisibility|functionname|purpose|anchor"
        DOC_FUNCTION_INDEX=()

        DOC_NAV_SCHEMA="nodeid|parentnodeid|nodetype|node_name|node_title|hierarchy_level|docindex|contentref|hasitems|isinternal|istemplate"
        DOC_NAV=()          
    
    # var: NAV row parameters
        _NAV_NODE_ID=""
        _NAV_PARENT_NODE_ID=""
        _NAV_NODE_TYPE=""
        _NAV_NODE_NAME=""
        _NAV_NODE_TITLE=""
        _NAV_HIERARCHY_LEVEL=""
        _NAV_DOC_INDEX=""
        _NAV_HAS_ITEMS=0
        _NAV_IS_INTERNAL=0
        _NAV_IS_TEMPLATE=0
        _NAV_CONTENT_REF=""
        
        _L1_INDEX=0
        _L2_INDEX=0
        _L3_INDEX=0
        _L4_INDEX=0
        _L5_INDEX=0

    # -- Arguments ------------------------------------------------------------------
        FLAG_INCLUDE_INTERNAL=0
        FLAG_INCLUDE_EMPTY_SECTIONS=1
        
        VAL_INDEX_GROUPBY="product,group,type"
        VAL_SECTION_SORTBY="modulename,parent,section,level"
        VAL_ITEM_SORTBY="modulename,section,itemvisibility,type,name"

    # -- Process helpers -----------------------------------------------------------
        # fn: _emit_doc_nav
            # Purpose:
            #   Append the currently prepared navigation node to DOC_NAV.
            #
            # Behavior:
            #   - Uses the active _NAV_* working variables.
            #   - Creates one normalized navigation row.
            #   - Stores hierarchy, index, content reference, and visibility flags.
            #
            # Outputs:
            #   DOC_NAV
            #
            # Returns:
            #   0 if the row is appended successfully.
            #
            # Usage:
            #   _emit_doc_nav
        _emit_doc_nav() {
            saydebug "Emitting doc nav node: ID='$_NAV_NODE_ID', ParentID='$_NAV_PARENT_NODE_ID', Type='$_NAV_NODE_TYPE', Name='$_NAV_NODE_NAME', Title='$_NAV_NODE_TITLE', HierarchyLevel='$_NAV_HIERARCHY_LEVEL', DocIndex='$_NAV_DOC_INDEX'"
            sgnd_dt_append \
                "$DOC_NAV_SCHEMA" \
                DOC_NAV \
                "${_NAV_NODE_ID}" \
                "${_NAV_PARENT_NODE_ID}" \
                "${_NAV_NODE_TYPE}" \
                "${_NAV_NODE_NAME}" \
                "${_NAV_NODE_TITLE}" \
                "${_NAV_HIERARCHY_LEVEL}" \
                "${_NAV_DOC_INDEX}"  \
                "${_NAV_CONTENT_REF}" \
                "${_NAV_HAS_ITEMS:-0}" \
                "${_NAV_IS_INTERNAL:-0}" \
                "${_NAV_IS_TEMPLATE:-0}"
        }

        # fn: _count_section_items
            # Purpose:
            #   Count documented items belonging to a specific module section.
            #
            # Behavior:
            #   - Scans MOD_ITEMS.
            #   - Matches rows by module, section, and parent section.
            #   - Prints the number of matching item rows.
            #
            # Arguments:
            #   $1  Module name.
            #   $2  Section name.
            #   $3  Parent section name.
            #
            # Outputs:
            #   Prints item count to stdout.
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   count="$(_count_section_items "$module_name" "$section_name" "$parent_section")"
        _count_section_items() {
            local module_name="$1"
            local section_name="$2"
            local parent_section="$3"
            local item_count=0
            local itm_row=""

            for itm_row in "${MOD_ITEMS[@]}"; do
                [[ "$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "modulename")" == "$module_name" ]] || continue
                [[ "$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "section")" == "$section_name" ]] || continue
                [[ "$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "parentsection")" == "$parent_section" ]] || continue

                ((item_count++))
            done

            printf '%s\n' "$item_count"
        }

        # fn: _set_doc_index
            # Purpose:
            #   Build the current dotted document index from active hierarchy counters.
            #
            # Behavior:
            #   - Uses _L1_INDEX through _L5_INDEX.
            #   - Skips zero-valued levels.
            #   - Stores the resulting dotted index in _NAV_DOC_INDEX.
            #
            # Inputs (globals):
            #   _L1_INDEX, _L2_INDEX, _L3_INDEX, _L4_INDEX, _L5_INDEX
            #
            # Outputs (globals):
            #   _NAV_DOC_INDEX
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   _set_doc_index
        _set_doc_index() {
            local worker=""

            (( _L1_INDEX > 0 )) && worker="${_L1_INDEX}"

            if (( _L2_INDEX > 0 )); then
                [[ -n "$worker" ]] && worker+="."
                worker+="${_L2_INDEX}"
            fi

            if (( _L3_INDEX > 0 )); then
                [[ -n "$worker" ]] && worker+="."
                worker+="${_L3_INDEX}"
            fi

            if (( _L4_INDEX > 0 )); then
                [[ -n "$worker" ]] && worker+="."
                worker+="${_L4_INDEX}"
            fi

            if (( _L5_INDEX > 0 )); then
                [[ -n "$worker" ]] && worker+="."
                worker+="${_L5_INDEX}"
            fi

            _NAV_DOC_INDEX="$worker"
        }

        # fn: _build_doc_hierarchy
            # Purpose:
            #   Build the canonical documentation navigation hierarchy.
            #
            # Behavior:
            #   - Clears DOC_NAV before rebuilding.
            #   - Iterates modules, sections, and documented items.
            #   - Assigns hierarchy levels and dotted document indexes.
            #   - Builds stable node IDs and parent node IDs.
            #   - Builds content references linking navigation nodes to DOC_CONTENT_LINES.
            #   - Marks internal and template items for optional rendering decisions.
            #
            # Inputs:
            #   MOD_TABLE
            #   MOD_SECTIONS
            #   MOD_ITEMS
            #
            # Outputs:
            #   DOC_NAV
            #
            # Returns:
            #   0 on successful hierarchy construction.
            #
            # Usage:
            #   _build_doc_hierarchy
        _build_doc_hierarchy() {
            local row=""
            local section_row=""
            local itm_row=""

            local cur_module=""
            local cur_section=""
            local cur_parent_section=""
            local cur_grandparent_section=""
            local cur_item=""

            local l1_node_id=""
            local l2_node_id=""
            local l3_node_id=""
            local l4_node_id=""
            local l5_node_id=""

            local section_module=""
            local item_module=""
            local item_access=""
            local item_role=""
            local item_typecode=""

            local total_modules="${#MOD_TABLE[@]}"

            DOC_NAV=()

            _L1_INDEX=0
            _L2_INDEX=0
            _L3_INDEX=0
            _L4_INDEX=0
            _L5_INDEX=0

            while IFS= read -r row; do
                ((_L1_INDEX++))
                _L2_INDEX=0
                _L3_INDEX=0
                _L4_INDEX=0
                _L5_INDEX=0

                sgnd_dt_row2var "$MOD_TABLE_SCHEMA" MOD_TABLE "$row"

                cur_module="$MOD_TABLE_name"
                cur_section=""
                cur_parent_section=""
                cur_grandparent_section=""
                cur_item=""

                _NAV_NODE_NAME="$MOD_TABLE_name"
                _NAV_NODE_TITLE="$MOD_TABLE_title"
                _NAV_NODE_TYPE="module"
                _NAV_NODE_ID="mod:${_NAV_NODE_NAME}"
                _NAV_PARENT_NODE_ID="root"
                _NAV_HIERARCHY_LEVEL=0
                _NAV_HAS_ITEMS=0
                _NAV_IS_INTERNAL=0
                _NAV_IS_TEMPLATE=0

                l1_node_id="$_NAV_NODE_ID"
                l2_node_id=""
                l3_node_id=""
                l4_node_id=""
                l5_node_id=""

                _set_doc_index
                _NAV_CONTENT_REF="$(_build_content_ref "$cur_module" "" "" "" "")"

                sayprogress \
                    --slot 1 \
                    --current "$_L1_INDEX" \
                    --total "$total_modules" \
                    --label "Building documentation hierarchy for module $_NAV_NODE_NAME" \
                    --type 5

                _emit_doc_nav

                while IFS= read -r section_row; do
                    section_module="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "modulename")"
                    [[ "$section_module" == "$cur_module" ]] || continue

                    sgnd_dt_row2var "$MOD_SECTIONS_SCHEMA" MOD_SECTIONS "$section_row"

                    _NAV_NODE_TYPE="section"
                    _NAV_NODE_NAME="$MOD_SECTIONS_section"
                    _NAV_NODE_TITLE="$MOD_SECTIONS_title"
                    _NAV_HIERARCHY_LEVEL="$MOD_SECTIONS_level"
                    _NAV_HAS_ITEMS=0
                    _NAV_IS_INTERNAL=0
                    _NAV_IS_TEMPLATE=0

                    (( _NAV_HIERARCHY_LEVEL >= 1 && _NAV_HIERARCHY_LEVEL <= 3 )) || {
                        saywarning "Unsupported section level '$_NAV_HIERARCHY_LEVEL' in $_NAV_NODE_NAME: $_NAV_NODE_TITLE"
                        continue
                    }

                    case "$_NAV_HIERARCHY_LEVEL" in
                        1)
                            ((_L2_INDEX++))
                            _L3_INDEX=0
                            _L4_INDEX=0
                            _L5_INDEX=0

                            cur_grandparent_section=""
                            cur_parent_section=""
                            cur_section="$_NAV_NODE_NAME"

                            _NAV_PARENT_NODE_ID="$l1_node_id"
                            _NAV_NODE_ID="sec:${cur_module}:${cur_section}"

                            l2_node_id="$_NAV_NODE_ID"
                            l3_node_id=""
                            l4_node_id=""
                            l5_node_id=""
                            ;;

                        2)
                            ((_L3_INDEX++))
                            _L4_INDEX=0
                            _L5_INDEX=0

                            cur_grandparent_section=""
                            cur_parent_section="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "parent")"
                            cur_section="$_NAV_NODE_NAME"

                            _NAV_PARENT_NODE_ID="$l2_node_id"
                            _NAV_NODE_ID="sec:${cur_module}:${cur_parent_section}:${cur_section}"

                            l3_node_id="$_NAV_NODE_ID"
                            l4_node_id=""
                            l5_node_id=""
                            ;;

                        3)
                            ((_L4_INDEX++))
                            _L5_INDEX=0

                            cur_grandparent_section="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "grandparent")"
                            cur_parent_section="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "parent")"
                            cur_section="$_NAV_NODE_NAME"

                            _NAV_PARENT_NODE_ID="$l3_node_id"
                            _NAV_NODE_ID="sec:${cur_module}:${cur_grandparent_section}:${cur_parent_section}:${cur_section}"

                            l4_node_id="$_NAV_NODE_ID"
                            l5_node_id=""
                            ;;
                    esac

                    _set_doc_index
                    _NAV_CONTENT_REF="$(_build_content_ref "$cur_module" "$cur_grandparent_section" "$cur_parent_section" "$cur_section" "")"

                    _emit_doc_nav

                    while IFS= read -r itm_row; do
                        sgnd_dt_row2var "$MOD_ITEMS_SCHEMA" MOD_ITEMS "$itm_row"

                        item_module="$MOD_ITEMS_modulename"
                        [[ "$item_module" == "$cur_module" ]] || continue
                        [[ "$MOD_ITEMS_section" == "$cur_section" ]] || continue
                        [[ "$MOD_ITEMS_parentsection" == "$cur_parent_section" ]] || continue

                        ((_L5_INDEX++))

                        _NAV_NODE_NAME="$MOD_ITEMS_name"
                        _NAV_NODE_TITLE="$MOD_ITEMS_title"
                        _NAV_NODE_TYPE="$MOD_ITEMS_type"
                        _NAV_HIERARCHY_LEVEL=4

                        cur_item="$_NAV_NODE_NAME"

                        item_access="$MOD_ITEMS_itemvisibility"
                        item_role="$MOD_ITEMS_itemrole"
                        item_typecode="$MOD_ITEMS_typecode"

                        _NAV_IS_INTERNAL=0
                        _NAV_IS_TEMPLATE=0

                        [[ "$item_access" == "internal" ]] && _NAV_IS_INTERNAL=1
                        [[ "$item_role" == "template" ]] && _NAV_IS_TEMPLATE=1

                        _NAV_NODE_ID="${item_typecode}:${cur_module}:${cur_section}:${cur_item}"
                        _NAV_PARENT_NODE_ID="${l4_node_id:-${l3_node_id:-${l2_node_id:-$l1_node_id}}}"
                        _NAV_HAS_ITEMS=0

                        l5_node_id="$_NAV_NODE_ID"

                        _set_doc_index
                        _NAV_CONTENT_REF="$(_build_content_ref "$cur_module" "$cur_grandparent_section" "$cur_parent_section" "$cur_section" "$cur_item")"

                        _emit_doc_nav

                    done < <(sgnd_dt_get_sorted_rows "$MOD_ITEMS_SCHEMA" MOD_ITEMS "$VAL_ITEM_SORTBY")

                done < <(sgnd_dt_get_sorted_rows "$MOD_SECTIONS_SCHEMA" MOD_SECTIONS "$VAL_SECTION_SORTBY")

            done < <(sgnd_dt_get_sorted_rows "$MOD_TABLE_SCHEMA" MOD_TABLE "$VAL_INDEX_GROUPBY")

            sgnd_print
        }
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
                rm -rf "${VAL_OUTDIR:?}/"* && sayinfo "Cleaned output directory: $VAL_OUTDIR" || {
                    sayerror "Failed to clean output directory: $VAL_OUTDIR"
                    return 1
                }
            fi
        }
    # -- Render helpers ------------------------------------------------------------
        _html_escape() {
            local value="${1-}"

            value="${value//&/&amp;}"
            value="${value//</&lt;}"
            value="${value//>/&gt;}"
            value="${value//\"/&quot;}"
            value="${value//\'/&#39;}"

            printf '%s\n' "$value"
        }

        _slugify() {
            local value="${1-}"

            value="${value,,}"
            value="$(sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' <<< "$value")"

            [[ -n "$value" ]] || value="page"
            printf '%s\n' "$value"
        }

        _is_item_node() {
            local node_type="${1-}"

            case "$node_type" in
                function|variable|"general documentation")
                    return 0
                    ;;
            esac

            return 1
        }

        _page_href_from_contentref() {
            local contentref="${1-}"
            local slug=""

            slug="$(_slugify "$contentref")"
            printf 'pages/%s.html\n' "$slug"
        }

        _breadcrumb_from_contentref() {
            local contentref="${1-}"
            local module_name=""
            local grandparent_section=""
            local parent_section=""
            local section_name=""
            local item_name=""
            local breadcrumb=""

            IFS=':' read -r module_name grandparent_section parent_section section_name item_name <<< "$contentref"

            for part in "$DOC_PRODUCT" "$module_name" "$grandparent_section" "$parent_section" "$section_name" "$item_name"; do
                [[ -n "$part" ]] || continue
                [[ -n "$breadcrumb" ]] && breadcrumb+=" / "
                breadcrumb+="$part"
            done

            printf '%s\n' "$breadcrumb"
        }

       
        _get_first_item_page() {
            local row=""
            local node_type=""
            local contentref=""

            for row in "${DOC_NAV[@]}"; do
                node_type="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "nodetype")"
                _is_item_node "$node_type" || continue

                contentref="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "contentref")"
                _page_href_from_contentref "$contentref"
                return 0
            done

            printf 'about:blank\n'
        }

    # -- Renderers -----------------------------------------------------------------
        _render_assets() {
            local output_folder="${1:?missing output folder}"
            local asset_dir="$output_folder/${VAL_RENDER_ASSET_DIR:-assets}"
            local css_file=""

            mkdir -p "$asset_dir" || return 1

            css_file="$asset_dir/doc.css"

            {
                printf '%s\n' 'html, body {'
                printf '%s\n' '    margin: 0;'
                printf '%s\n' '    padding: 0;'
                printf '%s\n' '    height: 100%;'
                printf '%s\n' '    font-family: Arial, sans-serif;'
                printf '%s\n' '    color: #222;'
                printf '%s\n' '    background: #ffffff;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' 'body {'
                printf '%s\n' '    border-top: 3px solid #222;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-shell {'
                printf '%s\n' '    display: grid;'
                printf '    grid-template-columns: %s 1fr;\n' "${VAL_NAV_WIDTH:-320px}"
                printf '%s\n' '    height: 100vh;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav {'
                printf '%s\n' '    border-right: 1px solid #d0d0d0;'
                printf '%s\n' '    background: #f6f6f6;'
                printf '%s\n' '    overflow: auto;'
                printf '%s\n' '    padding: 36px 20px 14px 20px;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-title {'
                printf '%s\n' '    font-size: 12pt;'
                printf '%s\n' '    font-weight: bold;'
                printf '%s\n' '    margin: 0 0 14px 0;'
                printf '%s\n' '    padding-bottom: 6px;'
                printf '%s\n' '    border-bottom: 1px solid #c0c0c0;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-node {'
                printf '%s\n' '    margin-top: 4px;'
                printf '%s\n' '    margin-bottom: 4px;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-static {'
                printf '%s\n' '    margin-left: 22px;'
                printf '%s\n' '    font-size: 9.5pt;'
                printf '%s\n' '    font-weight: 600;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-node summary {'
                printf '%s\n' '    cursor: pointer;'
                printf '%s\n' '    font-weight: bold;'
                printf '%s\n' '    line-height: 1.25;'
                printf '%s\n' '}'
                printf '\n'
                
                printf '%s\n' '.doc-nav-node.level-0 > summary {'
                printf '%s\n' '    font-size: 11pt;'
                printf '%s\n' '    font-weight: bold;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-node.level-1 > summary {'
                printf '%s\n' '    font-size: 10pt;'
                printf '%s\n' '    font-weight: 600;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-node.level-2 > summary,'
                printf '%s\n' '.doc-nav-node.level-3 > summary,'
                printf '%s\n' '.doc-nav-node.level-4 > summary {'
                printf '%s\n' '    font-size: 9.5pt;'
                printf '%s\n' '    font-weight: 600;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-item {'
                printf '%s\n' '    display: block;'
                printf '%s\n' '    color: #204a87;'
                printf '%s\n' '    text-decoration: none;'
                printf '%s\n' '    font-size: 10pt;'
                printf '%s\n' '    line-height: 1.2;'
                printf '%s\n' '    margin-top: 3px;'
                printf '%s\n' '    margin-bottom: 3px;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-item:hover {'
                printf '%s\n' '    text-decoration: underline;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-nav-item.level-0 { margin-left: 12px; }'
                printf '%s\n' '.doc-nav-item.level-1 { margin-left: 20px; }'
                printf '%s\n' '.doc-nav-item.level-2 { margin-left: 28px; }'
                printf '%s\n' '.doc-nav-item.level-3 { margin-left: 36px; }'
                printf '%s\n' '.doc-nav-item.level-4 { margin-left: 44px; }'
                printf '%s\n' '.doc-nav-item.level-5 { margin-left: 52px; }'
                printf '\n'

                printf '%s\n' '.doc-comment-indent {'
                printf '%s\n' '    margin-left: 22px;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-content-frame {'
                printf '%s\n' '    width: 100%;'
                printf '%s\n' '    height: 100vh;'
                printf '%s\n' '    border: 0;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-page {'
                printf '%s\n' '    padding: 24px 36px;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-page-header {'
                printf '%s\n' '    border-bottom: 1px solid #d0d0d0;'
                printf '%s\n' '    margin-bottom: 22px;'
                printf '%s\n' '    padding-bottom: 12px;'
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-title {'
                printf '    %s\n' "$_docstyle_documentheader"
                printf '%s\n' '}'
                printf '\n'

                printf '%s\n' '.doc-breadcrumb {'
                printf '%s\n' '    font-style: italic;'
                printf '%s\n' '    color: #666;'
                printf '%s\n' '    font-size: 10pt;'
                printf '%s\n' '}'
                printf '\n'

                printf '.ct-moduleheader { %s }\n' "$_docstyle_moduleheader"
                printf '.ct-modulebody { %s }\n' "$_docstyle_modulebody"
                printf '\n'

                printf '.ct-L1Sectionheader { %s }\n' "$_docstyle_L1Sectionheader"
                printf '.ct-L1Sectionbody { %s }\n' "$_docstyle_L1Sectionbody"
                printf '\n'

                printf '.ct-L2Sectionheader { %s }\n' "$_docstyle_L2Sectionheader"
                printf '.ct-L2Sectionbody { %s }\n' "$_docstyle_L2Sectionbody"
                printf '\n'

                printf '.ct-L3Sectionheader { %s }\n' "$_docstyle_L3Sectionheader"
                printf '.ct-L3Sectionbody { %s }\n' "$_docstyle_L3Sectionbody"
                printf '\n'

                printf '.ct-functionheader { %s }\n' "$_docstyle_functionheader"
                printf '.ct-functionbody { %s }\n' "$_docstyle_functionbody"
                printf '\n'

                printf '.ct-variableheader { %s }\n' "$_docstyle_variableheader"
                printf '.ct-variablebody { %s }\n' "$_docstyle_variablebody"
                printf '\n'

                printf '.ct-gendocheader { %s }\n' "$_docstyle_gendocheader"
                printf '.ct-gendocbody { %s }\n' "$_docstyle_gendocbody"
                printf '\n'

                printf '.ct-commentsectionheader { %s }\n' "$_docstyle_commentsectionheader"
                printf '.ct-commentsectionbody { %s }\n' "$_docstyle_commentsectionbody"
                printf '\n'

                printf '.ct-documentbody { %s }\n' "$_docstyle_documentbody"
            } > "$css_file"

            sayok "Rendered assets: $css_file"
        }

        _render_navigation() {
            local row=""
            local node_type=""
            local node_name=""
            local node_title=""
            local hierarchy_level=""
            local contentref=""
            local href=""
            local label=""
            local current_level=0
            local module_open=0

            for row in "${DOC_NAV[@]}"; do
                node_type="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "nodetype")"
                node_name="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "node_name")"
                node_title="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "node_title")"
                hierarchy_level="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "hierarchy_level")"
                contentref="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "contentref")"

                label="$node_name"
                [[ -n "$node_title" ]] && label="$node_title"

                current_level="$hierarchy_level"

                if (( current_level == 0 )); then
                    if (( module_open )); then
                        printf '%s\n' '</details>'
                    fi

                    printf '<details class="doc-nav-node level-0">\n'
                    printf '<summary>%s</summary>\n' "$(_html_escape "$label")"
                    module_open=1
                    continue
                fi

                if _is_item_node "$node_type"; then
                    href="$(_page_href_from_contentref "$contentref")"

                    printf '<a class="doc-nav-item level-%s type-%s" href="%s" target="docframe">%s</a>\n' \
                        "$current_level" \
                        "$(_slugify "$node_type")" \
                        "$(_html_escape "$href")" \
                        "$(_html_escape "$label")"
                else
                    printf '<div class="doc-nav-section level-%s">%s</div>\n' \
                        "$current_level" \
                        "$(_html_escape "$label")"
                fi
            done

            if (( module_open )); then
                printf '%s\n' '</details>'
            fi
        }

        _render_index_page() {
            local output_folder="${1:?missing output folder}"
            local index_file="$output_folder/index.html"
            local first_page=""

            first_page="$(_get_first_item_page)"

            {
                printf '%s\n' '<!doctype html>'
                printf '%s\n' '<html>'
                printf '%s\n' '<head>'
                printf '%s\n' '  <meta charset="utf-8">'
                printf '  <title>%s</title>\n' "$(_html_escape "$DOC_TITLE")"
                printf '%s\n' '  <link rel="stylesheet" href="assets/doc.css">'
                printf '%s\n' '</head>'
                printf '%s\n' '<body>'
                printf '%s\n' '<div class="doc-shell">'
                printf '%s\n' '<nav class="doc-nav">'
                printf '%s\n' '  <div class="doc-nav-title">Index by module</div>'
                _render_navigation
                printf '%s\n' '</nav>'
                printf '<iframe class="doc-content-frame" name="docframe" src="%s"></iframe>\n' "$(_html_escape "$first_page")"
                printf '%s\n' '</div>'
                printf '%s\n' '</body>'
                printf '%s\n' '</html>'
            } > "$index_file"

            sayok "Rendered index: $index_file"
        }

        _render_item_pages() {
            local output_folder="${1:?missing output folder}"
            local page_dir="$output_folder/${VAL_RENDER_PAGE_DIR:-pages}"
            local row=""
            local node_type=""

            mkdir -p "$page_dir" || return 1

            for row in "${DOC_NAV[@]}"; do
                node_type="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$row" "nodetype")"
                _is_item_node "$node_type" || continue

                _render_item_page "$output_folder" "$row"
            done
        }

        _render_item_page() {
            local output_folder="${1:?missing output folder}"
            local nav_row="${2:?missing nav row}"

            local node_name=""
            local node_title=""
            local contentref=""
            local href=""
            local output_file=""
            local breadcrumb=""

            node_name="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$nav_row" "node_name")"
            node_title="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$nav_row" "node_title")"
            contentref="$(sgnd_dt_row_get "$DOC_NAV_SCHEMA" "$nav_row" "contentref")"

            [[ -n "$node_title" ]] || node_title="$node_name"

            href="$(_page_href_from_contentref "$contentref")"
            output_file="$output_folder/$href"
            breadcrumb="$(_breadcrumb_from_contentref "$contentref")"

            {
                printf '%s\n' '<!doctype html>'
                printf '%s\n' '<html>'
                printf '%s\n' '<head>'
                printf '%s\n' '  <meta charset="utf-8">'
                printf '  <title>%s</title>\n' "$(_html_escape "$node_title")"
                printf '%s\n' '  <link rel="stylesheet" href="../assets/doc.css">'
                printf '%s\n' '</head>'
                printf '%s\n' '<body>'
                printf '%s\n' '<main class="doc-page">'
                printf '%s\n' '<header class="doc-page-header">'
                printf '  <div class="doc-title">%s</div>\n' "$(_html_escape "$DOC_TITLE")"
                printf '  <div class="doc-breadcrumb">%s</div>\n' "$(_html_escape "$breadcrumb")"
                printf '%s\n' '</header>'

                _render_content_for_ref "$contentref"

                printf '%s\n' '</main>'
                printf '%s\n' '</body>'
                printf '%s\n' '</html>'
            } > "$output_file"

            saydebug "Rendered item page: $output_file"
        }

        _render_content_for_ref() {
            local contentref="${1:?missing content reference}"
            local row=""
            local row_ref=""
            local content_type=""
            local content=""
            local css_class=""
            local extra_class=""
            local in_comment_section=0

            for row in "${DOC_CONTENT_LINES[@]}"; do
                row_ref="$(sgnd_dt_row_get "$DOC_CONTENT_LINES_SCHEMA" "$row" "contentref")"
                [[ "$row_ref" == "$contentref" ]] || continue

                content_type="$(sgnd_dt_row_get "$DOC_CONTENT_LINES_SCHEMA" "$row" "contenttype")"
                content="$(sgnd_dt_row_get "$DOC_CONTENT_LINES_SCHEMA" "$row" "content")"

                css_class="ct-${content_type:-documentbody}"
                extra_class=""

                if [[ "$content_type" == "commentsectionheader" ]]; then
                    in_comment_section=1

                    printf '<div class="%s">%s</div>\n' \
                        "$(_html_escape "$css_class")" \
                        "$(_html_escape "$content")"

                    continue
                fi

                if [[ -z "$content" ]]; then
                    in_comment_section=0
                fi

                if (( in_comment_section )); then
                    extra_class=" doc-comment-indent"
                fi

                printf '<div class="%s%s">%s</div>\n' \
                    "$(_html_escape "$css_class")" \
                    "$extra_class" \
                    "$(_html_escape "$content")"
            done
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
        saystart "Rendering site to $output_folder"

        _prepare_output_directory
        _build_doc_hierarchy
        _init_metadata

        saydebug "Documentation navigation hierarchy built with ${#DOC_NAV[@]} nodes. Ready for rendering."
        sayinfo " Rendering: Title='$DOC_TITLE', Subtitle='$DOC_SUBTITLE', Version='$DOC_VERSION', Product='$DOC_PRODUCT', RenderDate='$DOC_RENDER_DATE'"

        _render_assets "$output_folder" || return 1
        _render_item_pages "$output_folder" || return 1
        _render_index_page "$output_folder" || return 1

        sayend "Documentation rendering complete. Output available at: $output_folder"

        return 0
    } 
    


    