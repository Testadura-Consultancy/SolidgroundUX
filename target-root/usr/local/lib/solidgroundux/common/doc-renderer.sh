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

# - Postprocess documentation data ------------------------------------------------
# - Local definitions -------------------------------------------------------------
    # var: Postprocess datamodel
    DOC_ATTRIBUTION_INDEX_SCHEMA="company|developer|license|modulename|moduletitle|product|group"
    DOC_ATTRIBUTION_INDEX=()

    DOC_FUNCTION_INDEX_SCHEMA="product|group|modulename|itemaccess|functionname|purpose|anchor"
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

    # -- Flags ---------------------------------------------------------------------
        FLAG_INCLUDE_INTERNAL=0
        FLAG_INCLUDE_EMPTY_SECTIONS=1
        
        VAL_INDEX_GROUPBY="product,group,type"
        VAL_SECTION_SORTBY="modulename,parentsection,section,hierarchy_level"
        VAL_ITEM_SORTBY="modulename,section,itemaccess,type,name"

    # -- Process helpers -----------------------------------------------------------
        # fn: _emit_doc_nav
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
        _count_section_items() {
            local module_name="$1"
            local section_name="$2"
            local item_count=0
            local itm_row=""
            local item_module=""
            local item_section=""

            for itm_row in "${MOD_ITEMS[@]}"; do
                item_module="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "modulename")"
                [[ "$item_module" == "$module_name" ]] || continue

                item_section="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "section")"
                [[ "$item_section" == "$section_name" ]] || continue

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
        _build_doc_hierarchy() {
            local row=""
            
            local cur_module=""
            local cur_section=""
            local cur_parent_section=""
            local cur_grandparent_section=""

            local l1_node_id=""
            local l2_node_id=""
            local l3_node_id=""
            local l4_node_id=""
            local l5_node_id=""

            local node_depth=0
            local cur_item=""
            local cur_line=0

            DOC_NAV=()

            # Count workflow: Count total lines for progress tracking
            local total_modules="${#MOD_TABLE[@]}"
            local total_sections=0
            local total_items=0
            local total_work=0
            local count_module=""
            local count_row=""

            total_work=$((${#MOD_TABLE[@]} + ${#MOD_SECTIONS[@]} + ${#MOD_ITEMS[@]}))

            # Main loop to build documentation navigation hierarchy, by module
            while IFS= read -r row; do
                ((_L1_INDEX++))
                ((cur_line++))
                _L2_INDEX=0
                _L3_INDEX=0
                _L4_INDEX=0
                _L5_INDEX=0

                _NAV_NODE_NAME="$(sgnd_dt_row_get "$MOD_TABLE_SCHEMA" "$row" "name")"
                _NAV_NODE_TITLE="$(sgnd_dt_row_get "$MOD_TABLE_SCHEMA" "$row" "title")"
                _NAV_NODE_TYPE="$(sgnd_dt_row_get "$MOD_TABLE_SCHEMA" "$row" "type")"
                _NAV_NODE_ID="mod:${_NAV_NODE_NAME}"

                _NAV_PARENT_NODE_ID="root"
                _NAV_HIERARCHY_LEVEL=0

                cur_module="$_NAV_NODE_NAME"
                l1_node_id="$_NAV_NODE_ID"

                cur_section=""
                l2_node_id=""
                l3_node_id=""
                l4_node_id=""
                l5_node_id=""

                sayprogress \
                     --slot 1 \
                     --current "$cur_line" \
                     --total "$total_work" \
                     --label "Building documentation hierarchy for module $_NAV_NODE_NAME ($_L1_INDEX/$total_modules)" \
                     --type 5

                saydebug "Module: $_NAV_NODE_NAME, Title: $_NAV_NODE_TITLE, Type: $_NAV_NODE_TYPE, $_NAV_DOC_INDEX \n
                , Chapter: $_L1_INDEX, $_L2_INDEX, $_L3_INDEX, $_L4_INDEX, Node ID: $_NAV_NODE_ID, Parent ID: $_NAV_PARENT_NODE_ID \n
                , currentSection: $cur_section, $l1_node_id, $l2_node_id, $l3_node_id, $l4_node_id, $l5_node_id" 

                # Insert module rootnode
                _NAV_HAS_ITEMS=0

                _set_doc_index

                 _NAV_CONTENT_REF="$(_build_content_ref "$cur_module" "$cur_grandparent_section" "$cur_parent_section" "$cur_section" "$cur_item")"
                _emit_doc_nav

                # Section loop, by module
                for section_row in "${MOD_SECTIONS[@]}"; do
                    section_module="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "modulename")"

                    # Only scan section rows for the current module, as sections are module-specific and not shared across modules
                    [[ "$section_module" == "$cur_module" ]] || continue                    
                    ((cur_line++))

                    _NAV_NODE_TYPE="section"
                    _NAV_NODE_NAME="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "section")"
                    _NAV_NODE_TITLE="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "title")"
                    _NAV_HIERARCHY_LEVEL="$(sgnd_dt_row_get "$MOD_SECTIONS_SCHEMA" "$section_row" "level")"
                    _NAV_HAS_ITEMS=0

                    if (( ${FLAG_INCLUDE_EMPTY_SECTIONS:-1} == 0 && _NAV_ITEM_COUNT == 0 )); then
                        saydebug "Skipping empty section: $cur_module / $_NAV_NODE_NAME"
                        continue
                    fi

                    (( _NAV_HIERARCHY_LEVEL >= 1 && _NAV_HIERARCHY_LEVEL <= 3 )) || {
                        saywarning "Unsupported section level '$_NAV_HIERARCHY_LEVEL' in $_NAV_NODE_NAME: $_NAV_NODE_TITLE"
                        continue
                    }

                    _NAV_NODE_ID="sec:${_NAV_NODE_NAME}"

                    case "$_NAV_HIERARCHY_LEVEL" in
                        1)  
                            _NAV_PARENT_NODE_ID="${l1_node_id}"
                            cur_parent_section=""
                            cur_grandparent_section=""

                            ((_L2_INDEX++))
                            _L3_INDEX=0
                            _L4_INDEX=0
                            _L5_INDEX=0

                            l2_node_id="$_NAV_NODE_ID"
                            l3_node_id=""
                            l4_node_id=""
                            l5_node_id=""
                            ;;

                        2)
                            _NAV_PARENT_NODE_ID="${l2_node_id}"
                            cur_grandparent_section="$cur_parent_section"
                            cur_parent_section="$cur_section"

                            ((_L3_INDEX++))
                            _L4_INDEX=0
                            _L5_INDEX=0

                            l3_node_id="$_NAV_NODE_ID"
                            l4_node_id=""
                            l5_node_id=""
                            ;;
                        3)
                            _NAV_PARENT_NODE_ID="${l3_node_id}"
                            cur_grandparent_section="$cur_parent_section"
                            cur_parent_section="$cur_section"

                            ((_L4_INDEX++))
                            _L5_INDEX=0

                            l4_node_id="$_NAV_NODE_ID"
                            l5_node_id=""
                            ;;
                    esac                    
                    cur_section="$_NAV_NODE_NAME"
                    cur_item=""
                    cur_section_node_id="$_NAV_NODE_ID"

                    saydebug "Section $_NAV_NODE_ID, Title: $_NAV_NODE_TITLE, Name: $_NAV_NODE_NAME, Chapter: $_NAV_DOC_INDEX \
                            , Parent: $_NAV_PARENT_NODE_ID"

                    _set_doc_index
                    _NAV_CONTENT_REF="$(_build_content_ref "$cur_module" "$cur_grandparent_section" "$cur_parent_section" "$cur_section" "$cur_item")"

                    _emit_doc_nav

                    saydebug "Node $_NAV_NODE_NAME, Title: $_NAV_NODE_TITLE, Type: $_NAV_NODE_TYPE, $_NAV_DOC_INDEX \n
                        , Chapter: $_L1_INDEX, $_L2_INDEX, $_L3_INDEX, $_L4_INDEX, Node ID: $_NAV_NODE_ID, Parent ID: $_NAV_PARENT_NODE_ID \n
                        , currentSection: $cur_section, $l1_node_id, $l2_node_id, $l3_node_id, $l4_node_id, $l5_node_id" 

                    # Item loop, by section
                    for itm_row in "${MOD_ITEMS[@]}"; do
                        item_module="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "modulename")"

                        # Only scan item rows for the current module and section, as items are specific to both a module and a section, and not shared across modules or sections
                        [[ "$item_module" == "$cur_module" ]] || continue  
                        [[ "$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "section")" == "$cur_section" ]] || continue

                        ((_L5_INDEX++))                     
                        ((cur_line++))

                        _NAV_NODE_NAME="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "name")"
                        _NAV_NODE_TITLE="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "title")"
                        _NAV_NODE_TYPE="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "type")"

                        cur_item="$_NAV_NODE_NAME"
                        item_access="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "itemvisibility")"
                        item_role="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "itemrole")"
                        item_typecode="$(sgnd_dt_row_get "$MOD_ITEMS_SCHEMA" "$itm_row" "typecode")"

                        _NAV_IS_INTERNAL=0
                        _NAV_IS_TEMPLATE=0

                        [[ "$item_access" == "internal" ]] && _NAV_IS_INTERNAL=1
                        [[ "$item_role" == "template" ]] && _NAV_IS_TEMPLATE=1
                        
                        _NAV_NODE_ID="${item_typecode}:${_NAV_NODE_NAME}"
                        l5_node_id="$_NAV_NODE_ID"
                        _NAV_PARENT_NODE_ID="${cur_section_node_id}"

                        _set_doc_index
                        _NAV_CONTENT_REF="$(_build_content_ref "$cur_module" "$cur_grandparent_section" "$cur_parent_section" "$cur_section" "$cur_item")"
                        
                        _emit_doc_nav 

                        saydebug "Node $_NAV_NODE_NAME, Title: $_NAV_NODE_TITLE, Type: $_NAV_NODE_TYPE, $_NAV_DOC_INDEX \n
                        , Chapter: $_L1_INDEX, $_L2_INDEX, $_L3_INDEX, $_L4_INDEX, Node ID: $_NAV_NODE_ID, Parent ID: $_NAV_PARENT_NODE_ID \n
                        , currentSection: $cur_section, $l1_node_id, $l2_node_id, $l3_node_id, $l4_node_id, $l5_node_id" 
                    done  < <(sgnd_dt_get_sorted_rows "$MOD_ITEMS_SCHEMA" MOD_ITEMS "$VAL_ITEM_SORTBY")  
                done < <(sgnd_dt_get_sorted_rows "$MOD_SECTIONS_SCHEMA" MOD_SECTIONS "$VAL_SECTION_SORTBY")
            done < <(sgnd_dt_get_sorted_rows "$MOD_TABLE_SCHEMA" MOD_TABLE "$VAL_INDEX_GROUPBY")
            sgnd_print
        }
        
# - Render documentation -----------------------------------------------------------
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
        sayinfo "Rendering site to $output_folder"
        return 0
    } 
    


