# ==================================================================================
# SolidgroundUX - Documentation Renderer
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 0.2
#   Build       : 2602110
#   Checksum    : none
#   Source      : doc-renderer.sh
#   Type        : library
#   Group       : Developer Tools
#   Purpose     : Render collected documentation tables into a prototype HTML site
#
# Description:
#   Provides a first HTML rendering layer for the documentation collector.
#
#   The library:
#     - Renders one HTML page per module using collected documentation tables
#     - Renders one HTML page per group with module overviews and function glossaries
#     - Renders a home page linking to all groups
#     - Computes section and item numbering during rendering
#     - Applies visibility rules for private and template-only items
#     - Suppresses empty sections and empty header blocks
#     - Formats collected content rows by content type
#
# Design principles:
#   - Rendering remains separate from collection and parsing
#   - Numbering is derived during rendering, not stored during parsing
#   - Structural tables drive layout; content tables supply body text only
#   - HTML output is intentionally simple and easy to evolve
#
# Role in framework:
#   - Prototype publishing layer for doc-generator output
#   - Bridges normalized collector tables and browsable HTML documentation
#
# Non-goals:
#   - Parsing source comments directly
#   - Full template engine support
#   - Final site design or theming system
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      :
#   Copyright   : © 2026 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
set -uo pipefail

# - Library guard ------------------------------------------------------------------
    # tmp: _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
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

    if declare -F sgnd_module_init_metadata >/dev/null 2>&1; then
        sgnd_module_init_metadata "${BASH_SOURCE[0]}"
    fi

# - Internal helpers --------------------------------------------------------------
    # fn: _sgnd_doc_html_escape
        # Purpose:
        #   Escape one text value for safe inclusion in HTML.
    _sgnd_doc_html_escape() {
        local text="${1-}"

        text="${text//&/&amp;}"
        text="${text//</&lt;}"
        text="${text//>/&gt;}"
        text="${text//\"/&quot;}"
        text="${text//\'/&#39;}"

        printf '%s' "$text"
    }

    # fn: _sgnd_doc_slugify
        # Purpose:
        #   Convert text to a filesystem- and anchor-friendly slug.
    _sgnd_doc_slugify() {
        local text="${1,,}"

        text="${text//&/ and }"
        text="${text// /-}"
        text="${text//[^a-z0-9._-]/-}"

        while [[ "$text" == *--* ]]; do
            text="${text//--/-}"
        done

        text="${text#-}"
        text="${text%-}"
        [[ -n "$text" ]] || text="item"

        printf '%s' "$text"
    }

    # fn: _sgnd_doc_get_module_row
        # Purpose:
        #   Retrieve one module metadata row by filename.
    _sgnd_doc_get_module_row() {
        local file="$1"
        local row=""
        local row_file=""

        for row in "${MODULE_TABLE[@]}"; do
            IFS='|' read -r row_file _ <<< "$row"
            [[ "$row_file" == "$file" ]] || continue
            printf '%s\n' "$row"
            return 0
        done

        return 1
    }

    # fn: _sgnd_doc_get_unique_groups
        # Purpose:
        #   Emit unique module group names in alphabetical order.
    _sgnd_doc_get_unique_groups() {
        local row=""
        local file=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local tmp_file=""

        tmp_file="$(mktemp)" || return 1

        for row in "${MODULE_TABLE[@]}"; do
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"
            [[ -n "$group" ]] || group="Ungrouped"
            printf '%s\n' "$group" >> "$tmp_file"
        done

        sort -fu "$tmp_file"
        rm -f "$tmp_file"
        return 0
    }

    # fn: _sgnd_doc_should_render_item
        # Purpose:
        #   Apply renderer visibility rules to one item.
    _sgnd_doc_should_render_item() {
        local file="$1"
        local item_type="$2"
        local access="$3"

        if [[ "$access" == "private" ]] && (( ${SGND_DOC_SHOW_PRIVATE_ITEMS:-1} == 0 )); then
            return 1
        fi

        if [[ "$item_type" == "tmp" ]]; then
            (( ${SGND_DOC_SHOW_TEMPLATE_ITEMS:-0} != 0 )) || return 1
            [[ "$file" == *-template.sh ]] || return 1
        fi

        return 0
    }

    # fn: _sgnd_doc_get_module_index_within_group
        # Purpose:
        #   Resolve the 1-based module number within one group in alphabetical title order.
    _sgnd_doc_get_module_index_within_group() {
        local target_group="$1"
        local target_file="$2"
        local row=""
        local file=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local tmp_file=""
        local current_file=""
        local index=0

        tmp_file="$(mktemp)" || return 1

        for row in "${MODULE_TABLE[@]}"; do
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"
            [[ -n "$group" ]] || group="Ungrouped"
            [[ "$group" == "$target_group" ]] || continue
            printf '%s|%s\n' "$title" "$file" >> "$tmp_file"
        done

        while IFS='|' read -r title current_file; do
            (( index++ ))
            [[ "$current_file" == "$target_file" ]] || continue
            printf '%s' "$index"
            rm -f "$tmp_file"
            return 0
        done < <(sort -t '|' -k1,1f "$tmp_file")

        rm -f "$tmp_file"
        return 1
    }

    # fn: _sgnd_doc_get_section_number
        # Purpose:
        #   Compute hierarchical numbering for one section within one module in alphabetical order.
    _sgnd_doc_get_section_number() {
        local target_file="$1"
        local target_section="$2"
        local target_level=""
        local target_parent=""
        local target_grandparent=""
        local row=""
        local file=""
        local section=""
        local level=""
        local parent=""
        local grandparent=""
        local line_nr=""
        local tmp_file=""
        local index=0
        local lvl1=""
        local lvl2=""
        local lvl3=""

        for row in "${DOC_SECTIONS[@]}"; do
            IFS='|' read -r file section level parent grandparent line_nr <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue
            target_level="$level"
            target_parent="$parent"
            target_grandparent="$grandparent"
            break
        done

        [[ -n "$target_level" ]] || return 1

        case "$target_level" in
            1)
                tmp_file="$(mktemp)" || return 1
                for row in "${DOC_SECTIONS[@]}"; do
                    IFS='|' read -r file section level parent grandparent line_nr <<< "$row"
                    [[ "$file" == "$target_file" ]] || continue
                    [[ "$level" == "1" ]] || continue
                    printf '%s\n' "$section" >> "$tmp_file"
                done

                while IFS= read -r section; do
                    (( index++ ))
                    [[ "$section" == "$target_section" ]] || continue
                    printf '%s' "$index"
                    rm -f "$tmp_file"
                    return 0
                done < <(sort -fu "$tmp_file")
                rm -f "$tmp_file"
                ;;
            2)
                lvl1="$(_sgnd_doc_get_section_number "$target_file" "$target_parent")" || return 1
                tmp_file="$(mktemp)" || return 1
                for row in "${DOC_SECTIONS[@]}"; do
                    IFS='|' read -r file section level parent grandparent line_nr <<< "$row"
                    [[ "$file" == "$target_file" ]] || continue
                    [[ "$level" == "2" ]] || continue
                    [[ "$parent" == "$target_parent" ]] || continue
                    printf '%s\n' "$section" >> "$tmp_file"
                done

                while IFS= read -r section; do
                    (( index++ ))
                    [[ "$section" == "$target_section" ]] || continue
                    printf '%s.%s' "$lvl1" "$index"
                    rm -f "$tmp_file"
                    return 0
                done < <(sort -fu "$tmp_file")
                rm -f "$tmp_file"
                ;;
            3)
                lvl2="$(_sgnd_doc_get_section_number "$target_file" "$target_parent")" || return 1
                tmp_file="$(mktemp)" || return 1
                for row in "${DOC_SECTIONS[@]}"; do
                    IFS='|' read -r file section level parent grandparent line_nr <<< "$row"
                    [[ "$file" == "$target_file" ]] || continue
                    [[ "$level" == "3" ]] || continue
                    [[ "$parent" == "$target_parent" ]] || continue
                    printf '%s\n' "$section" >> "$tmp_file"
                done

                while IFS= read -r section; do
                    (( index++ ))
                    [[ "$section" == "$target_section" ]] || continue
                    printf '%s.%s' "$lvl2" "$index"
                    rm -f "$tmp_file"
                    return 0
                done < <(sort -fu "$tmp_file")
                rm -f "$tmp_file"
                ;;
        esac

        return 1
    }

    # fn: _sgnd_doc_get_item_number
        # Purpose:
        #   Compute numbering for one item within its parent section in alphabetical order.
    _sgnd_doc_get_item_number() {
        local target_file="$1"
        local target_section="$2"
        local target_item="$3"
        local section_number=""
        local row=""
        local file=""
        local line_nr=""
        local access=""
        local item_type=""
        local section=""
        local name=""
        local tmp_file=""
        local current_name=""
        local item_index=0

        section_number="$(_sgnd_doc_get_section_number "$target_file" "$target_section")" || return 1
        tmp_file="$(mktemp)" || return 1

        for row in "${DOC_ITEMS[@]}"; do
            IFS='|' read -r file line_nr access item_type section name <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue

            _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue
            _sgnd_doc_item_has_content "$file" "$section" "$name" || continue

            printf '%s\n' "$name" >> "$tmp_file"
        done

        while IFS= read -r current_name; do
            (( item_index++ ))
            [[ "$current_name" == "$target_item" ]] || continue
            printf '%s.%s' "$section_number" "$item_index"
            rm -f "$tmp_file"
            return 0
        done < <(sort -fu "$tmp_file")

        rm -f "$tmp_file"
        return 1
    }

    # fn: _sgnd_doc_get_item_purpose
        # Purpose:
        #   Extract the first Purpose body line for one documented item.
    _sgnd_doc_get_item_purpose() {
        local target_file="$1"
        local target_item="$2"
        local row=""
        local file=""
        local line_nr=""
        local section=""
        local item_name=""
        local content_ord=""
        local content_type=""
        local content=""
        local in_purpose=0

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$item_name" == "$target_item" ]] || continue

            if [[ "$content_type" == "comment_section" ]]; then
                if [[ "$content" == "Purpose:" || "$content" == "Purpose" ]]; then
                    in_purpose=1
                else
                    in_purpose=0
                fi
                continue
            fi

            (( in_purpose )) || continue
            [[ "$content_type" == "content" ]] || continue
            [[ -n "$content" ]] || continue

            printf '%s' "$content"
            return 0
        done

        return 1
    }

    # fn: _sgnd_doc_list_module_header_blocks
        # Purpose:
        #   Emit unique module header block names in alphabetical order.
    _sgnd_doc_list_module_header_blocks() {
        local target_file="$1"
        local row=""
        local file=""
        local line_nr=""
        local section=""
        local item_name=""
        local content_ord=""
        local content_type=""
        local content=""
        local tmp_file=""

        tmp_file="$(mktemp)" || return 1

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ -n "$section" ]] || continue
            [[ -z "$item_name" ]] || continue

            printf '%s\n' "$section" >> "$tmp_file"
        done

        sort -fu "$tmp_file"
        rm -f "$tmp_file"
        return 0
    }

    # fn: _sgnd_doc_section_has_direct_content
        # Purpose:
        #   Test whether one section has direct body content.
    _sgnd_doc_section_has_direct_content() {
        local target_file="$1"
        local target_section="$2"
        local row=""
        local file=""
        local line_nr=""
        local section=""
        local item_name=""
        local content_ord=""
        local content_type=""
        local content=""

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue
            [[ -z "$item_name" ]] || continue

            return 1
        done

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue
            [[ -n "$item_name" ]] && continue

            case "$content_type" in
                comment_section)
                    [[ -n "$content" ]] && return 0
                    ;;
                content)
                    [[ -n "$content" ]] && return 0
                    ;;
            esac
        done

        return 1
    }

    # fn: _sgnd_doc_module_header_block_has_content
        # Purpose:
        #   Test whether one module header block has content.
    _sgnd_doc_module_header_block_has_content() {
        local target_file="$1"
        local target_block="$2"
        local row=""
        local file=""
        local line_nr=""
        local section=""
        local item_name=""
        local content_ord=""
        local content_type=""
        local content=""

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_block" ]] || continue
            [[ -z "$item_name" ]] || continue

            case "$content_type" in
                comment_section)
                    [[ -n "$content" ]] && return 0
                    ;;
                content)
                    [[ -n "$content" ]] && return 0
                    ;;
            esac
        done

        return 1
    }

    # fn: _sgnd_doc_item_has_content
        # Purpose:
        #   Test whether one documented item has any non-empty content.
    _sgnd_doc_item_has_content() {
        local target_file="$1"
        local target_section="$2"
        local target_item="$3"
        local row=""
        local file=""
        local line_nr=""
        local section=""
        local item_name=""
        local content_ord=""
        local content_type=""
        local content=""

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue
            [[ "$item_name" == "$target_item" ]] || continue

            case "$content_type" in
                comment_section)
                    [[ -n "$content" ]] && return 0
                    ;;
                content)
                    [[ -n "$content" ]] && return 0
                    ;;
            esac
        done

        return 1
    }

    # fn: _sgnd_doc_section_has_visible_content
        # Purpose:
        #   Test whether one section should be rendered.
    _sgnd_doc_section_has_visible_content() {
        local target_file="$1"
        local target_section="$2"
        local row=""
        local file=""
        local line_nr=""
        local access=""
        local item_type=""
        local section=""
        local name=""

        _sgnd_doc_section_has_direct_content "$target_file" "$target_section" && return 0

        for row in "${DOC_ITEMS[@]}"; do
            IFS='|' read -r file line_nr access item_type section name <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue

            _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue
            _sgnd_doc_item_has_content "$file" "$section" "$name" || continue

            return 0
        done

        return 1
    }

    # fn: _sgnd_doc_write_html_header
        # Purpose:
        #   Emit the opening HTML document shell and shared inline CSS.
    _sgnd_doc_write_html_header() {
        local esc_title="$1"

        printf '%s\n' \
            '<!DOCTYPE html>' \
            '<html lang="en">' \
            '<head>' \
            '<meta charset="utf-8">' \
            '<meta name="viewport" content="width=device-width, initial-scale=1">' \
            "<title>${esc_title}</title>" \
            '<style>' \
            'body { font-family: Arial, Helvetica, sans-serif; margin: 2rem auto; max-width: 1100px; line-height: 1.45; color: #222; }' \
            'a { color: #0a58ca; text-decoration: none; }' \
            'a:hover { text-decoration: underline; }' \
            'header, main, nav, section, article, details, summary { display: block; }' \
            '.site-header { border-bottom: 1px solid #ddd; margin-bottom: 1.5rem; padding-bottom: 0.75rem; }' \
            '.site-nav { margin-bottom: 0.75rem; }' \
            '.home-button { display: inline-block; padding: 0.35rem 0.7rem; border: 1px solid #cfcfcf; background: #f7f7f8; border-radius: 0.35rem; font-size: 0.95rem; }' \
            '.home-button:hover { background: #efeff1; text-decoration: none; }' \
            '.meta-block, .attr-block, .glossary-block, .header-block { background: #f7f7f8; border: 1px solid #e2e2e2; padding: 0.9rem 1rem; margin: 1rem 0; }' \
            '.meta-block p, .attr-block p, .header-block p { margin: 0.2rem 0; }' \
            '.chapter-title { margin-bottom: 0.2rem; }' \
            '.section-block { margin-top: 2rem; }' \
            '.section-title { border-bottom: 1px solid #e1e1e1; padding-bottom: 0.2rem; }' \
            '.item-block { margin: 1rem 0 1.2rem 1rem; padding-left: 1rem; border-left: 3px solid #e1e1e1; }' \
            '.item-header { margin-bottom: 0.45rem; }' \
            '.item-title-row { font-size: 1.15rem; line-height: 1.35; }' \
            '.item-title { font-size: 1.15em; }' \
            '.item-type { font-weight: 700; text-transform: uppercase; font-size: 0.9rem; color: #666; margin-right: 0.45rem; }' \
            '.item-access-private { color: #8b0000; }' \
            '.item-access-public { color: #006400; }' \
            '.content-comment-section { font-weight: 700; margin-top: 0.8rem; }' \
            '.content-body { margin: 0.25rem 0; white-space: pre-wrap; }' \
            '.small-note { color: #666; font-size: 0.9rem; }' \
            '.nav-group, .group-module { margin: 0.65rem 0; }' \
            '.nav-group summary, .group-module summary { cursor: pointer; font-weight: 700; }' \
            '.group-module-glossary { margin: 0.5rem 0 0.5rem 1.25rem; }' \
            '.group-module-glossary ul, .group-module-glossary li, .group-list, .group-list li { margin-top: 0.2rem; }' \
            '.header-block-title { margin: 0 0 0.5rem 0; }' \
            '</style>' \
            '</head>' \
            '<body>'
    }

    # fn: _sgnd_doc_write_html_footer
        # Purpose:
        #   Emit the closing HTML document shell.
    _sgnd_doc_write_html_footer() {
        printf '%s\n' \
            '</body>' \
            '</html>'
    }

    # fn: _sgnd_doc_write_home_link
        # Purpose:
        #   Emit a reusable home navigation link.
    _sgnd_doc_write_home_link() {
        printf '<div class="site-nav"><a class="home-button" href="index.html">Home</a></div>\n'
    }

    # fn: _sgnd_doc_render_content_rows
        # Purpose:
        #   Render body content for one section or item.
    _sgnd_doc_render_content_rows() {
        local target_file="$1"
        local target_section="$2"
        local target_item="$3"
        local row=""
        local file=""
        local line_nr=""
        local section=""
        local item_name=""
        local content_ord=""
        local content_type=""
        local content=""
        local esc_content=""

        for row in "${DOC_CONTENT[@]}"; do
            IFS='|' read -r file line_nr section item_name content_ord content_type content <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue
            [[ "$item_name" == "$target_item" ]] || continue

            esc_content="$(_sgnd_doc_html_escape "$content")"

            case "$content_type" in
                comment_section)
                    [[ -n "$content" ]] || continue
                    printf '<div class="content-comment-section">%s</div>\n' "$esc_content"
                    ;;
                content)
                    [[ -n "$content" ]] || continue
                    printf '<p class="content-body">%s</p>\n' "$esc_content"
                    ;;
            esac
        done
    }

    # fn: _sgnd_doc_render_module_header_blocks
        # Purpose:
        #   Render non-empty module header blocks except Metadata and Attribution.
    _sgnd_doc_render_module_header_blocks() {
        local target_file="$1"
        local block_name=""

        while IFS= read -r block_name; do
            [[ -n "$block_name" ]] || continue
            [[ "$block_name" == "Metadata" ]] && continue
            [[ "$block_name" == "Attribution" ]] && continue

            _sgnd_doc_module_header_block_has_content "$target_file" "$block_name" || continue

            printf '<section class="header-block">\n'
            printf '<h2 class="header-block-title">%s</h2>\n' "$(_sgnd_doc_html_escape "$block_name")"
            _sgnd_doc_render_content_rows "$target_file" "$block_name" ""
            printf '</section>\n'
        done < <(_sgnd_doc_list_module_header_blocks "$target_file")
    }

    # fn: _sgnd_doc_render_function_glossary_list
        # Purpose:
        #   Render an alphabetical function glossary list for one module.
    _sgnd_doc_render_function_glossary_list() {
        local target_file="$1"
        local row=""
        local file=""
        local line_nr=""
        local access=""
        local item_type=""
        local section=""
        local name=""
        local purpose=""
        local item_anchor=""
        local module_slug=""
        local tmp_file=""

        tmp_file="$(mktemp)" || return 1
        module_slug="$(_sgnd_doc_slugify "$target_file")"

        for row in "${DOC_ITEMS[@]}"; do
            IFS='|' read -r file line_nr access item_type section name <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$item_type" == "fn" ]] || continue
            _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue
            _sgnd_doc_item_has_content "$file" "$section" "$name" || continue

            purpose="$(_sgnd_doc_get_item_purpose "$file" "$name" 2>/dev/null || true)"
            printf '%s|%s|%s\n' "$name" "$purpose" "$access" >> "$tmp_file"
        done

        if [[ ! -s "$tmp_file" ]]; then
            rm -f "$tmp_file"
            return 1
        fi

        printf '<div class="group-module-glossary">\n'
        printf '<ul>\n'
        sort -t '|' -k1,1f "$tmp_file" | while IFS='|' read -r name purpose access; do
            item_anchor="item-$(_sgnd_doc_slugify "$name")"
            printf '<li><a href="%s.html#%s"><strong>%s</strong></a>' \
                "$module_slug" \
                "$item_anchor" \
                "$(_sgnd_doc_html_escape "$name")"
            if [[ -n "$purpose" ]]; then
                printf ' — %s' "$(_sgnd_doc_html_escape "$purpose")"
            fi
            printf ' <span class="small-note">[%s]</span></li>\n' "$(_sgnd_doc_html_escape "$access")"
        done
        printf '</ul>\n'
        printf '</div>\n'

        rm -f "$tmp_file"
        return 0
    }

    # fn: _sgnd_doc_render_appendix_links
        # Purpose:
        #   Render the appendix link list for the home page.
    _sgnd_doc_render_appendix_links() {
        printf '<section class="meta-block">\n'
        printf '<strong>Appendix</strong>\n'
        printf '<ul>\n'
        printf '<li><a href="appendix-a-attribution-data.html">Appendix A — Attribution data</a></li>\n'
        printf '<li><a href="appendix-b-function-glossary.html">Appendix B — Function glossary</a></li>\n'
        printf '</ul>\n'
        printf '</section>\n'
    }

    # fn: _sgnd_doc_render_attribution_dimension
        # Purpose:
        #   Render one attribution appendix section grouped by a selected metadata field.
    _sgnd_doc_render_attribution_dimension() {
        local field_name="$1"
        local field_index="$2"
        local row=""
        local file=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local key=""
        local tmp_file=""
        local module_file=""
        local module_title=""
        local last_key=""

        tmp_file="$(mktemp)" || return 1

        for row in "${MODULE_TABLE[@]}"; do
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"

            case "$field_index" in
                10) key="$company" ;;
                13) key="$license" ;;
                9)  key="$developers" ;;
                *)  key="" ;;
            esac

            [[ -n "$key" ]] || key="Unspecified"
            printf '%s|%s|%s\n' "$key" "$title" "$file" >> "$tmp_file"
        done

        printf '<section class="meta-block">\n'
        printf '<h2>%s</h2>\n' "$(_sgnd_doc_html_escape "$field_name")"

        last_key=""
        while IFS='|' read -r key module_title module_file; do
            if [[ "$key" != "$last_key" ]]; then
                [[ -n "$last_key" ]] && printf '</ul>\n'
                printf '<h3>%s</h3>\n' "$(_sgnd_doc_html_escape "$key")"
                printf '<ul>\n'
                last_key="$key"
            fi

            printf '<li><a href="%s.html">%s</a></li>\n' \
                "$(_sgnd_doc_slugify "$module_file")" \
                "$(_sgnd_doc_html_escape "$module_title")"
        done < <(sort -t '|' -k1,1f -k2,2f "$tmp_file")

        [[ -n "$last_key" ]] && printf '</ul>\n'
        printf '</section>\n'

        rm -f "$tmp_file"
        return 0
    }
        # fn: _sgnd_doc_render_appendix_b_glossary
        # Purpose:
        #   Render the appendix function glossary grouped by module group.
    _sgnd_doc_render_appendix_b_glossary() {
        local row=""
        local file=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local item_row=""
        local file_ref=""
        local line_nr=""
        local access=""
        local item_type=""
        local section=""
        local name=""
        local fn_purpose=""
        local tmp_file=""
        local last_group=""
        local last_module=""
        local modules_ttl=0
        local modules_proc=0

        tmp_file="$(mktemp)" || return 1
        modules_ttl="${#MODULE_TABLE[@]}"

        sayinfo "Building Appendix B function glossary for %s modules..." "$modules_ttl"

        for row in "${MODULE_TABLE[@]}"; do
            (( modules_proc++ ))
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"
            [[ -n "$group" ]] || group="Ungrouped"

            sayprogress \
                --current "$modules_proc" \
                --total "$modules_ttl" \
                --label "Appendix B: ${title:-$file}" \
                --type 5 \
                --padleft 0

            for item_row in "${DOC_ITEMS[@]}"; do
                IFS='|' read -r file_ref line_nr access item_type section name <<< "$item_row"
                [[ "$file_ref" == "$file" ]] || continue
                [[ "$item_type" == "fn" ]] || continue

                _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue
                _sgnd_doc_item_has_content "$file" "$section" "$name" || continue

                fn_purpose="$(_sgnd_doc_get_item_purpose "$file" "$name" 2>/dev/null || true)"
                printf '%s|%s|%s|%s|%s\n' \
                    "$group" \
                    "$title" \
                    "$file" \
                    "$name" \
                    "$fn_purpose" >> "$tmp_file"
            done
        done

        sayprogress_done

        printf '<section class="meta-block">\n'
        printf '<h2>Function glossary by module group</h2>\n'

        last_group=""
        last_module=""
        while IFS='|' read -r group title file name fn_purpose; do
            if [[ "$group" != "$last_group" ]]; then
                [[ -n "$last_module" ]] && printf '</ul>\n'
                printf '<h3>%s</h3>\n' "$(_sgnd_doc_html_escape "$group")"
                last_group="$group"
                last_module=""
            fi

            if [[ "$title" != "$last_module" ]]; then
                [[ -n "$last_module" ]] && printf '</ul>\n'
                printf '<h4><a href="%s.html">%s</a></h4>\n' \
                    "$(_sgnd_doc_slugify "$file")" \
                    "$(_sgnd_doc_html_escape "$title")"
                printf '<ul>\n'
                last_module="$title"
            fi

            printf '<li><strong>%s</strong>' "$(_sgnd_doc_html_escape "$name")"
            if [[ -n "$fn_purpose" ]]; then
                printf ' — %s' "$(_sgnd_doc_html_escape "$fn_purpose")"
            fi
            printf '</li>\n'
        done < <(sort -t '|' -k1,1f -k2,2f -k4,4f "$tmp_file")

        [[ -n "$last_module" ]] && printf '</ul>\n'
        printf '</section>\n'

        rm -f "$tmp_file"
        return 0
    }
# - Public API --------------------------------------------------------------------
    # fn: sgnd_doc_render_home_page
        # Purpose:
        #   Render the root home page listing groups and appendices.
    sgnd_doc_render_home_page() {
        local output_dir="$1"
        local output_path="${output_dir%/}/index.html"
        local first_row=""
        local product="Documentation"
        local file=""
        local group=""
        local title=""
        local type=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local current_group=""

        mkdir -p "$output_dir" || return 1

        if (( ${#MODULE_TABLE[@]} > 0 )); then
            first_row="${MODULE_TABLE[0]}"
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$first_row"
            [[ -n "$product" ]] || product="Documentation"
        fi

        {
            _sgnd_doc_write_html_header "$product"

            printf '<header class="site-header">\n'
            _sgnd_doc_write_home_link
            printf '<h1 class="chapter-title">%s</h1>\n' "$(_sgnd_doc_html_escape "$product")"
            printf '<p class="small-note">Documentation groups</p>\n'
            printf '</header>\n'

            printf '<main>\n'

            printf '<section class="meta-block">\n'
            printf '<strong>Groups</strong>\n'

            while IFS= read -r current_group; do
                [[ -n "$current_group" ]] || continue
                printf '<details class="nav-group" open>\n'
                printf '<summary><a href="%s.html">%s</a></summary>\n' \
                    "$(_sgnd_doc_slugify "group-${current_group}")" \
                    "$(_sgnd_doc_html_escape "$current_group")"
                printf '</details>\n'
            done < <(_sgnd_doc_get_unique_groups)

            printf '</section>\n'

            _sgnd_doc_render_appendix_links

            printf '</main>\n'
            _sgnd_doc_write_html_footer
        } > "$output_path"

        return 0
    }

    # fn: sgnd_doc_render_group_page
        # Purpose:
        #   Render one group page with modules and function glossaries.
    sgnd_doc_render_group_page() {
        local group_name="$1"
        local output_dir="$2"
        local output_path="${output_dir%/}/$(_sgnd_doc_slugify "group-${group_name}").html"
        local row=""
        local file=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local module_index=""
        local tmp_file=""
        local module_file=""
        local module_title=""
        local module_purpose=""

        mkdir -p "$output_dir" || return 1
        tmp_file="$(mktemp)" || return 1

        for row in "${MODULE_TABLE[@]}"; do
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"
            [[ -n "$group" ]] || group="Ungrouped"
            [[ "$group" == "$group_name" ]] || continue
            printf '%s|%s|%s\n' "$title" "$file" "$purpose" >> "$tmp_file"
        done

        {
            _sgnd_doc_write_html_header "$group_name"

            printf '<header class="site-header">\n'
            _sgnd_doc_write_home_link
            printf '<h1 class="chapter-title">%s</h1>\n' "$(_sgnd_doc_html_escape "$group_name")"
            printf '<p class="small-note">Modules and function glossaries</p>\n'
            printf '</header>\n'

            printf '<main>\n'
            printf '<section class="meta-block">\n'
            printf '<strong>Modules</strong>\n'

            while IFS='|' read -r module_title module_file module_purpose; do
                module_index="$(_sgnd_doc_get_module_index_within_group "$group_name" "$module_file")" || continue

                printf '<details class="group-module" open>\n'
                printf '<summary><a href="%s.html"><strong>%s %s</strong></a>' \
                    "$(_sgnd_doc_slugify "$module_file")" \
                    "$(_sgnd_doc_html_escape "$module_index")" \
                    "$(_sgnd_doc_html_escape "$module_title")"
                if [[ -n "$module_purpose" ]]; then
                    printf ' — %s' "$(_sgnd_doc_html_escape "$module_purpose")"
                fi
                printf '</summary>\n'

                _sgnd_doc_render_function_glossary_list "$module_file" || true

                printf '</details>\n'
            done < <(sort -t '|' -k1,1f "$tmp_file")

            printf '</section>\n'
            printf '</main>\n'

            _sgnd_doc_write_html_footer
        } > "$output_path"

        rm -f "$tmp_file"
        return 0
    }

    # fn: sgnd_doc_render_module_page
        # Purpose:
        #   Render one module page to HTML.
    sgnd_doc_render_module_page() {
        local file="$1"
        local output_path="$2"
        local module_row=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local row=""
        local section_file=""
        local section=""
        local level=""
        local parent=""
        local grandparent=""
        local line_nr=""
        local sec_number=""
        local sec_anchor=""
        local item_row=""
        local access=""
        local item_type=""
        local section_name=""
        local name=""
        local item_number=""
        local item_anchor=""
        local section_tmp=""
        local item_tmp=""
        local current_section=""
        local current_item=""

        module_row="$(_sgnd_doc_get_module_row "$file")" || return 1

        IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$module_row"

        mkdir -p "$(dirname "$output_path")" || return 1
        section_tmp="$(mktemp)" || return 1

        for row in "${DOC_SECTIONS[@]}"; do
            IFS='|' read -r section_file section level parent grandparent line_nr <<< "$row"
            [[ "$section_file" == "$file" ]] || continue
            _sgnd_doc_section_has_visible_content "$file" "$section" || continue
            printf '%s|%s|%s|%s\n' "$section" "$level" "$parent" "$grandparent" >> "$section_tmp"
        done

        {
            _sgnd_doc_write_html_header "$title"

            printf '<header class="site-header">\n'
            _sgnd_doc_write_home_link
            printf '<h1 class="chapter-title">%s</h1>\n' "$(_sgnd_doc_html_escape "$title")"
            printf '<p class="small-note">%s</p>\n' "$(_sgnd_doc_html_escape "$file")"
            printf '</header>\n'

            printf '<main>\n'

            printf '<section class="meta-block">\n'
            printf '<strong>Metadata</strong>\n'
            printf '<p><strong>Script:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$file")"
            [[ -n "$purpose" ]] && printf '<p><strong>Purpose:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$purpose")"
            [[ -n "$version" ]] && printf '<p><strong>Version:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$version")"
            [[ -n "$type" ]] && printf '<p><strong>Type:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$type")"
            [[ -n "$group" ]] && printf '<p><strong>Group:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$group")"
            printf '</section>\n'

            _sgnd_doc_render_module_header_blocks "$file"

            while IFS='|' read -r current_section level parent grandparent; do
                sec_number="$(_sgnd_doc_get_section_number "$file" "$current_section")" || continue
                sec_anchor="section-$(_sgnd_doc_slugify "$current_section")"

                printf '<section class="section-block" id="%s">\n' "$sec_anchor"
                case "$level" in
                    1) printf '<h2 class="section-title">%s %s</h2>\n' "$sec_number" "$(_sgnd_doc_html_escape "$current_section")" ;;
                    2) printf '<h3 class="section-title">%s %s</h3>\n' "$sec_number" "$(_sgnd_doc_html_escape "$current_section")" ;;
                    3) printf '<h4 class="section-title">%s %s</h4>\n' "$sec_number" "$(_sgnd_doc_html_escape "$current_section")" ;;
                    *) printf '<h2 class="section-title">%s %s</h2>\n' "$sec_number" "$(_sgnd_doc_html_escape "$current_section")" ;;
                esac

                _sgnd_doc_render_content_rows "$file" "$current_section" ""

                item_tmp="$(mktemp)" || continue
                for item_row in "${DOC_ITEMS[@]}"; do
                    IFS='|' read -r section_file line_nr access item_type section_name name <<< "$item_row"
                    [[ "$section_file" == "$file" ]] || continue
                    [[ "$section_name" == "$current_section" ]] || continue

                    _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue
                    _sgnd_doc_item_has_content "$file" "$section_name" "$name" || continue

                    printf '%s|%s|%s\n' "$name" "$item_type" "$access" >> "$item_tmp"
                done

                while IFS='|' read -r current_item item_type access; do
                    item_number="$(_sgnd_doc_get_item_number "$file" "$current_section" "$current_item")" || continue
                    item_anchor="item-$(_sgnd_doc_slugify "$current_item")"

                    printf '<article class="item-block" id="%s">\n' "$item_anchor"
                    printf '<div class="item-header">\n'
                    printf '<div class="item-title-row">'
                    printf '<span class="item-type">%s</span>' "$(_sgnd_doc_html_escape "$item_type")"
                    printf '<strong class="item-title">%s %s</strong> ' "$item_number" "$(_sgnd_doc_html_escape "$current_item")"
                    printf '<span class="item-access-%s">[%s]</span>' "$(_sgnd_doc_html_escape "$access")" "$(_sgnd_doc_html_escape "$access")"
                    printf '</div>\n'
                    printf '</div>\n'

                    _sgnd_doc_render_content_rows "$file" "$current_section" "$current_item"
                    printf '</article>\n'
                done < <(sort -t '|' -k1,1f "$item_tmp")

                rm -f "$item_tmp"
                printf '</section>\n'
            done < <(sort -t '|' -k1,1f "$section_tmp")

            printf '</main>\n'
            _sgnd_doc_write_html_footer
        } > "$output_path"

        rm -f "$section_tmp"
        return 0
    }

    # fn: sgnd_doc_render_appendix_a_page
        # Purpose:
        #   Render Appendix A with attribution data grouped by Company, License, and Developers.
    sgnd_doc_render_appendix_a_page() {
        local output_dir="$1"
        local output_path="${output_dir%/}/appendix-a-attribution-data.html"

        mkdir -p "$output_dir" || return 1

        {
            _sgnd_doc_write_html_header "Appendix A - Attribution data"

            printf '<header class="site-header">\n'
            _sgnd_doc_write_home_link
            printf '<h1 class="chapter-title">Appendix A — Attribution data</h1>\n'
            printf '<p class="small-note">Grouped by Company, License, and Developers</p>\n'
            printf '</header>\n'

            printf '<main>\n'
            _sgnd_doc_render_attribution_dimension "Company" 10
            _sgnd_doc_render_attribution_dimension "License" 13
            _sgnd_doc_render_attribution_dimension "Developers" 9
            printf '</main>\n'

            _sgnd_doc_write_html_footer
        } > "$output_path"

        return 0
    }

    # fn: sgnd_doc_render_appendix_b_page
        # Purpose:
        #   Render Appendix B with function glossary grouped by module group.
    sgnd_doc_render_appendix_b_page() {
        local output_dir="$1"
        local output_path="${output_dir%/}/appendix-b-function-glossary.html"

        mkdir -p "$output_dir" || return 1

        {
            _sgnd_doc_write_html_header "Appendix B - Function glossary"

            printf '<header class="site-header">\n'
            _sgnd_doc_write_home_link
            printf '<h1 class="chapter-title">Appendix B — Function glossary</h1>\n'
            printf '<p class="small-note">Function names and purposes by module group</p>\n'
            printf '</header>\n'

            printf '<main>\n'
            _sgnd_doc_render_appendix_b_glossary
            printf '</main>\n'

            _sgnd_doc_write_html_footer
        } > "$output_path"

        return 0
    }

    # fn: sgnd_doc_render_site
        # Purpose:
        #   Render a prototype HTML documentation site from collected tables.
    sgnd_doc_render_site() {
        local output_dir="$1"
        local row=""
        local file=""
        local product=""
        local title=""
        local type=""
        local group=""
        local purpose=""
        local version=""
        local build=""
        local checksum=""
        local developers=""
        local company=""
        local client=""
        local copyright=""
        local license=""
        local group_name=""
        local module_slug=""
        local modules_ttl=0
        local modules_proc=0
        local groups_ttl=0
        local groups_proc=0

        [[ -n "$output_dir" ]] || return 1
        mkdir -p "$output_dir" || return 1

        : "${SGND_DOC_SHOW_PRIVATE_ITEMS:=1}"
        : "${SGND_DOC_SHOW_TEMPLATE_ITEMS:=0}"

        modules_ttl="${#MODULE_TABLE[@]}"
        groups_ttl=0
        while IFS= read -r group_name; do
            [[ -n "$group_name" ]] || continue
            (( groups_ttl++ ))
        done < <(_sgnd_doc_get_unique_groups)

        saystart "Rendering documentation site to: ${output_dir%/}/index.html"

        sayinfo "Rendering home page..."
        sgnd_doc_render_home_page "$output_dir" || return 1

        sayinfo "Rendering appendix A"
        sgnd_doc_render_appendix_a_page "$output_dir" || return 1
        sayinfo "Rendering appendix B"
        sgnd_doc_render_appendix_b_page "$output_dir" || return 1

        sayinfo "Rendering %s group pages..." "$groups_ttl"
        while IFS= read -r group_name; do
            [[ -n "$group_name" ]] || continue
            (( groups_proc++ ))

            sayprogress \
                --current "$groups_proc" \
                --total "$groups_ttl" \
                --label "Rendering group: ${group_name}" \
                --type 5 \
                --padleft 0

            sgnd_doc_render_group_page "$group_name" "$output_dir" || return 1
        done < <(_sgnd_doc_get_unique_groups)

        sayprogress_done

         sgnd_print "[$(date '+%Y-%m-%d %H:%M:%S')] Rendering start"
        for row in "${MODULE_TABLE[@]}"; do
            (( modules_proc++ ))
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"

            sayprogress \
                --current "$modules_proc" \
                --total "$modules_ttl" \
                --label "Rendering module: ${title:-$file}" \
                --type 5 \
                --padleft 0

            module_slug="$(_sgnd_doc_slugify "$file")"
            sgnd_doc_render_module_page "$file" "${output_dir%/}/${module_slug}.html" || return 1
        done

        sayprogress_done
        sgnd_print "[$(date '+%Y-%m-%d %H:%M:%S')] Rendering complete"
        sayok "Documentation site rendering complete: ${groups_ttl} groups and ${modules_ttl} modules rendered to ${output_dir%/}/index.html"
        return 0
    }