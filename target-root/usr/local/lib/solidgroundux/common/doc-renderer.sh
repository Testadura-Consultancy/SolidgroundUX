# ==================================================================================
# SolidgroundUX - Documentation Renderer
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 0.1
#   Build       : 2601110
#   Checksum    : none
#   Source      : doc-renderer.sh
#   Type        : library
#   Group       : Developer tools
#   Purpose     : Render collected documentation tables into a prototype HTML site
#
# Description:
#   Provides a first HTML rendering layer for the documentation collector.
#
#   The library:
#     - Renders one HTML page per module using collected documentation tables
#     - Renders a product index page linking to all module pages
#     - Computes chapter, paragraph, and subparagraph numbering during rendering
#     - Applies visibility rules for private and template-only items
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

# - Internal helpers -------------------------------------------------------------
    # _sgnd_doc_html_escape
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

    # _sgnd_doc_slugify
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

    # _sgnd_doc_get_module_row
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

    # _sgnd_doc_should_render_item
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

    # _sgnd_doc_get_chapter_number
        # Purpose:
        #   Resolve the 1-based chapter number for one module.
    _sgnd_doc_get_chapter_number() {
        local file="$1"
        local row=""
        local current_file=""
        local index=0

        for row in "${MODULE_TABLE[@]}"; do
            IFS='|' read -r current_file _ <<< "$row"
            (( index++ ))
            [[ "$current_file" == "$file" ]] || continue
            printf '%s' "$index"
            return 0
        done

        return 1
    }

    # _sgnd_doc_get_section_number
        # Purpose:
        #   Compute hierarchical numbering for one section within one module.
    _sgnd_doc_get_section_number() {
        local target_file="$1"
        local target_section="$2"
        local row=""
        local file=""
        local section=""
        local level=""
        local parent=""
        local grandparent=""
        local line_nr=""
        local lvl1=0
        local lvl2=0
        local lvl3=0

        for row in "${DOC_SECTIONS[@]}"; do
            IFS='|' read -r file section level parent grandparent line_nr <<< "$row"
            [[ "$file" == "$target_file" ]] || continue

            case "$level" in
                1)
                    (( lvl1++ ))
                    lvl2=0
                    lvl3=0
                    ;;
                2)
                    (( lvl2++ ))
                    lvl3=0
                    ;;
                3)
                    (( lvl3++ ))
                    ;;
            esac

            [[ "$section" == "$target_section" ]] || continue

            case "$level" in
                1) printf '%s' "$lvl1" ;;
                2) printf '%s.%s' "$lvl1" "$lvl2" ;;
                3) printf '%s.%s.%s' "$lvl1" "$lvl2" "$lvl3" ;;
                *) return 1 ;;
            esac
            return 0
        done

        return 1
    }

    # _sgnd_doc_get_item_number
        # Purpose:
        #   Compute numbering for one item within its parent section.
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
        local item_index=0

        section_number="$(_sgnd_doc_get_section_number "$target_file" "$target_section")" || return 1

        for row in "${DOC_ITEMS[@]}"; do
            IFS='|' read -r file line_nr access item_type section name <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$section" == "$target_section" ]] || continue

            _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue

            (( item_index++ ))
            [[ "$name" == "$target_item" ]] || continue
            printf '%s.%s' "$section_number" "$item_index"
            return 0
        done

        return 1
    }

    # _sgnd_doc_get_item_purpose
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

    # _sgnd_doc_write_html_header
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
            'header, main, nav, section, article { display: block; }' \
            '.site-header { border-bottom: 1px solid #ddd; margin-bottom: 1.5rem; padding-bottom: 0.75rem; }' \
            '.meta-block, .attr-block, .toc-block, .glossary-block { background: #f7f7f8; border: 1px solid #e2e2e2; padding: 0.9rem 1rem; margin: 1rem 0; }' \
            '.meta-block p, .attr-block p { margin: 0.2rem 0; }' \
            '.chapter-title { margin-bottom: 0.2rem; }' \
            '.section-block { margin-top: 2rem; }' \
            '.section-title { border-bottom: 1px solid #e1e1e1; padding-bottom: 0.2rem; }' \
            '.item-block { margin: 1rem 0 1.2rem 1rem; padding-left: 1rem; border-left: 3px solid #e1e1e1; }' \
            '.item-header { margin-bottom: 0.35rem; }' \
            '.item-type { font-weight: 700; text-transform: uppercase; font-size: 0.8rem; color: #666; margin-right: 0.45rem; }' \
            '.item-access-private { color: #8b0000; }' \
            '.item-access-public { color: #006400; }' \
            '.content-comment-section { font-weight: 700; margin-top: 0.8rem; }' \
            '.content-body { margin: 0.25rem 0; white-space: pre-wrap; }' \
            '.content-empty { height: 0.4rem; }' \
            '.toc-block ul, .glossary-block ul { margin: 0.35rem 0 0 1.25rem; }' \
            '.toc-block li, .glossary-block li { margin: 0.15rem 0; }' \
            '.small-note { color: #666; font-size: 0.9rem; }' \
            '</style>' \
            '</head>' \
            '<body>'
    }

    # _sgnd_doc_write_html_footer
        # Purpose:
        #   Emit the closing HTML document shell.
    _sgnd_doc_write_html_footer() {
        printf '%s\n' \
            '</body>' \
            '</html>'
    }

    # _sgnd_doc_render_content_rows
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
                    if [[ -z "$content" ]]; then
                        printf '<div class="content-empty"></div>\n'
                    else
                        printf '<p class="content-body">%s</p>\n' "$esc_content"
                    fi
                    ;;
            esac
        done
    }

    # _sgnd_doc_render_module_toc
        # Purpose:
        #   Render a module-local table of contents.
    _sgnd_doc_render_module_toc() {
        local target_file="$1"
        local section_row=""
        local item_row=""
        local file=""
        local section=""
        local level=""
        local parent=""
        local grandparent=""
        local line_nr=""
        local sec_number=""
        local sec_anchor=""
        local access=""
        local item_type=""
        local name=""
        local item_number=""
        local item_anchor=""
        local section_name=""

        printf '<nav class="toc-block">\n'
        printf '<strong>Contents</strong>\n'
        printf '<ul>\n'

        for section_row in "${DOC_SECTIONS[@]}"; do
            IFS='|' read -r file section level parent grandparent line_nr <<< "$section_row"
            [[ "$file" == "$target_file" ]] || continue

            sec_number="$(_sgnd_doc_get_section_number "$target_file" "$section")" || continue
            sec_anchor="section-$(_sgnd_doc_slugify "$section")"
            printf '<li><a href="#%s">%s %s</a>\n' "$sec_anchor" "$sec_number" "$(_sgnd_doc_html_escape "$section")"

            printf '<ul>\n'
            for item_row in "${DOC_ITEMS[@]}"; do
                IFS='|' read -r file line_nr access item_type section_name name <<< "$item_row"
                [[ "$file" == "$target_file" ]] || continue
                [[ "$section_name" == "$section" ]] || continue

                _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue

                item_number="$(_sgnd_doc_get_item_number "$target_file" "$section_name" "$name")" || continue
                item_anchor="item-$(_sgnd_doc_slugify "$name")"
                printf '<li><a href="#%s">%s %s: %s</a></li>\n' \
                    "$item_anchor" \
                    "$item_number" \
                    "$(_sgnd_doc_html_escape "$item_type")" \
                    "$(_sgnd_doc_html_escape "$name")"
            done
            printf '</ul>\n'
            printf '</li>\n'
        done

        printf '</ul>\n'
        printf '</nav>\n'
    }

    # _sgnd_doc_render_function_glossary
        # Purpose:
        #   Render an alphabetical module-local function glossary.
    _sgnd_doc_render_function_glossary() {
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
        local tmp_file=""

        tmp_file="$(mktemp)" || return 1

        for row in "${DOC_ITEMS[@]}"; do
            IFS='|' read -r file line_nr access item_type section name <<< "$row"
            [[ "$file" == "$target_file" ]] || continue
            [[ "$item_type" == "fn" ]] || continue
            _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue

            purpose="$(_sgnd_doc_get_item_purpose "$file" "$name" 2>/dev/null || true)"
            printf '%s|%s|%s|%s\n' "$name" "$purpose" "$section" "$access" >> "$tmp_file"
        done

        printf '<section class="glossary-block">\n'
        printf '<strong>Function glossary</strong>\n'
        printf '<ul>\n'
        sort -t '|' -k1,1f "$tmp_file" | while IFS='|' read -r name purpose section access; do
            item_anchor="item-$(_sgnd_doc_slugify "$name")"
            printf '<li><a href="#%s"><strong>%s</strong></a>' \
                "$item_anchor" \
                "$(_sgnd_doc_html_escape "$name")"
            if [[ -n "$purpose" ]]; then
                printf ' — %s' "$(_sgnd_doc_html_escape "$purpose")"
            fi
            printf ' <span class="small-note">[%s]</span></li>\n' "$(_sgnd_doc_html_escape "$access")"
        done
        printf '</ul>\n'
        printf '</section>\n'

        rm -f "$tmp_file"
        return 0
    }

# - Public API -------------------------------------------------------------------
    # sgnd_doc_render_module_page
        # Purpose:
        #   Render one module page to HTML.
    sgnd_doc_render_module_page() {
        local file="$1"
        local output_path="$2"
        local module_row=""
        local chapter_number=""
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

        module_row="$(_sgnd_doc_get_module_row "$file")" || return 1
        chapter_number="$(_sgnd_doc_get_chapter_number "$file")" || return 1

        IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$module_row"

        mkdir -p "$(dirname "$output_path")" || return 1

        {
            _sgnd_doc_write_html_header "$title"

            printf '<header class="site-header">\n'
            printf '<p class="small-note">Chapter %s</p>\n' "$(_sgnd_doc_html_escape "$chapter_number")"
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

            printf '<section class="attr-block">\n'
            printf '<strong>Attribution</strong>\n'
            [[ -n "$developers" ]] && printf '<p><strong>Developers:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$developers")"
            [[ -n "$company" ]] && printf '<p><strong>Company:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$company")"
            [[ -n "$copyright" ]] && printf '<p><strong>Copyright:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$copyright")"
            [[ -n "$license" ]] && printf '<p><strong>License:</strong> %s</p>\n' "$(_sgnd_doc_html_escape "$license")"
            printf '</section>\n'

            _sgnd_doc_render_module_toc "$file"
            _sgnd_doc_render_function_glossary "$file"

            for row in "${DOC_SECTIONS[@]}"; do
                IFS='|' read -r section_file section level parent grandparent line_nr <<< "$row"
                [[ "$section_file" == "$file" ]] || continue

                sec_number="$(_sgnd_doc_get_section_number "$file" "$section")" || continue
                sec_anchor="section-$(_sgnd_doc_slugify "$section")"

                printf '<section class="section-block" id="%s">\n' "$sec_anchor"
                case "$level" in
                    1) printf '<h2 class="section-title">%s %s</h2>\n' "$sec_number" "$(_sgnd_doc_html_escape "$section")" ;;
                    2) printf '<h3 class="section-title">%s %s</h3>\n' "$sec_number" "$(_sgnd_doc_html_escape "$section")" ;;
                    3) printf '<h4 class="section-title">%s %s</h4>\n' "$sec_number" "$(_sgnd_doc_html_escape "$section")" ;;
                    *) printf '<h2 class="section-title">%s %s</h2>\n' "$sec_number" "$(_sgnd_doc_html_escape "$section")" ;;
                esac

                _sgnd_doc_render_content_rows "$file" "$section" ""

                for item_row in "${DOC_ITEMS[@]}"; do
                    IFS='|' read -r section_file line_nr access item_type section_name name <<< "$item_row"
                    [[ "$section_file" == "$file" ]] || continue
                    [[ "$section_name" == "$section" ]] || continue

                    _sgnd_doc_should_render_item "$file" "$item_type" "$access" || continue

                    item_number="$(_sgnd_doc_get_item_number "$file" "$section_name" "$name")" || continue
                    item_anchor="item-$(_sgnd_doc_slugify "$name")"

                    printf '<article class="item-block" id="%s">\n' "$item_anchor"
                    printf '<div class="item-header">'
                    printf '<span class="item-type">%s</span>' "$(_sgnd_doc_html_escape "$item_type")"
                    printf '<strong>%s %s</strong> ' "$item_number" "$(_sgnd_doc_html_escape "$name")"
                    printf '<span class="item-access-%s">[%s]</span>' "$(_sgnd_doc_html_escape "$access")" "$(_sgnd_doc_html_escape "$access")"
                    printf '</div>\n'

                    _sgnd_doc_render_content_rows "$file" "$section_name" "$name"
                    printf '</article>\n'
                done

                printf '</section>\n'
            done

            printf '</main>\n'
            _sgnd_doc_write_html_footer
        } > "$output_path"

        return 0
    }

    # sgnd_doc_render_index_page
        # Purpose:
        #   Render the root product index page.
    sgnd_doc_render_index_page() {
        local output_dir="$1"
        local output_path="${output_dir%/}/index.html"
        local first_row=""
        local product="Documentation"
        local row=""
        local file=""
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
        local chapter_number=""
        local module_slug=""

        mkdir -p "$output_dir" || return 1

        if (( ${#MODULE_TABLE[@]} > 0 )); then
            first_row="${MODULE_TABLE[0]}"
            IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$first_row"
            [[ -n "$product" ]] || product="Documentation"
        fi

        {
            _sgnd_doc_write_html_header "$product"
            printf '<header class="site-header">\n'
            printf '<h1 class="chapter-title">%s</h1>\n' "$(_sgnd_doc_html_escape "$product")"
            printf '<p class="small-note">Generated documentation index</p>\n'
            printf '</header>\n'
            printf '<main>\n'
            printf '<section class="meta-block">\n'
            printf '<strong>Modules</strong>\n'
            printf '<ul>\n'

            for row in "${MODULE_TABLE[@]}"; do
                IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"
                chapter_number="$(_sgnd_doc_get_chapter_number "$file")" || continue
                module_slug="$(_sgnd_doc_slugify "$file")"

                printf '<li><a href="%s.html">%s %s</a>' \
                    "$module_slug" \
                    "$(_sgnd_doc_html_escape "$chapter_number")" \
                    "$(_sgnd_doc_html_escape "$title")"
                if [[ -n "$purpose" ]]; then
                    printf ' — %s' "$(_sgnd_doc_html_escape "$purpose")"
                fi
                printf '</li>\n'
            done

            printf '</ul>\n'
            printf '</section>\n'
            printf '</main>\n'
            _sgnd_doc_write_html_footer
        } > "$output_path"

        return 0
    }

    # sgnd_doc_render_site
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
    local module_slug=""
    local modules_ttl=0
    local modules_proc=0

    [[ -n "$output_dir" ]] || return 1
    mkdir -p "$output_dir" || return 1

    : "${SGND_DOC_SHOW_PRIVATE_ITEMS:=1}"
    : "${SGND_DOC_SHOW_TEMPLATE_ITEMS:=0}"

    modules_ttl="${#MODULE_TABLE[@]}"

    sayinfo "Rendering documentation site to: ${output_dir%/}/index.html"
    sayinfo "Rendering index page for %s modules..." "$modules_ttl"
    sgnd_doc_render_index_page "$output_dir" || return 1

    for row in "${MODULE_TABLE[@]}"; do
        ((modules_proc++))
        sayinfo "Rendering module %s of %s..." "$modules_proc" "$modules_ttl"
        IFS='|' read -r file product title type group purpose version build checksum developers company client copyright license <<< "$row"

        sayprogress \
            --current "$modules_proc" \
            --total "$modules_ttl" \
            --label "Rendering module: ${title:-$file}" \
            --type 5 \
            --padleft 0

        module_slug="$(_sgnd_doc_slugify "$file")"
        sayinfo "Rendering module page: %s.html" "$module_slug"
        sgnd_doc_render_module_page "$file" "${output_dir%/}/${module_slug}.html" || return 1
    done

    sayprogress_done
    return 0
}
