# ==================================================================================
# SolidgroundUX - Documentation Renderer
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.2
#   Build       : 2609101
#   Checksum    : none
#   Source      : doc-renderer.sh
#   Type        : library
#   Group       : Developer Tools
#   Purpose     : Render documentation from parser-produced render facts
#
# Description:
#   Provides the rendering layer for SolidGroundUX documentation tooling.
#
#   The library:
#     - Consumes DOC_MODULE, DOC_RENDER, and DOC_MASTER_INDEX rows produced by the parser
#     - Keeps rendering independent from source parsing and table reconstruction
#     - Generates a small static HTML site with an index and one page per module
#     - Leaves room for later user-editable templates and richer page types
#
# Design principles:
#   - Parser emits facts
#   - Renderer consumes facts
#   - No repeated joins over parser source tables during rendering
#   - Page generation is separated from line rendering
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
    # tmp: _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
    _sgnd_lib_guard() {
        local lib_base
        local guard

        lib_base="$(basename "${BASH_SOURCE[0]}" .sh)"
        lib_base="${lib_base//-/_}"
        lib_base="$(printf '%s' "$lib_base" | tr -c 'A-Za-z0-9_' '_')"
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

# - Datamodel ----------------------------------------------------------------------
    # RENDER_STREAM is now a renderer-side alias/snapshot of DOC_RENDER.
    # It is retained so review/debug output can keep using a render-stream name.
    RENDER_STREAM_SCHEMA="module_file|module_group|module_title|access|source_linenr|section|section_level|parent|grandparent|item_type|item_name|line_type|comment_section|content_ord|content"
    RENDER_STREAM=()

    DOC_PAGE_SCHEMA="page_id|page_type|module_file|section|item_type|item_name|title|outfile|template"
    DOC_PAGE=()

# - Internal helpers ---------------------------------------------------------------
# -- Text helpers ------------------------------------------------------------------
    # _sgnd_doc_html_escape
        # Returns:
        #   HTML-escaped text.
        # Usage:
        #   _sgnd_doc_html_escape "$text"
    _sgnd_doc_html_escape() {
        local text="${1:-}"

        text="${text//&/&amp;}"
        text="${text//</&lt;}"
        text="${text//>/&gt;}"
        text="${text//\"/&quot;}"
        text="${text//\'/&#39;}"

        printf '%s' "$text"
    }

    # _sgnd_doc_slug
        # Returns:
        #   A filesystem-safe slug for generated page filenames.
        # Usage:
        #   _sgnd_doc_slug "$value"
    _sgnd_doc_slug() {
        local value="${1:-page}"

        value="${value,,}"
        value="${value// /-}"
        value="${value//_/-}"
        value="$(printf '%s' "$value" | tr -cd 'a-z0-9.-')"
        value="${value//../.}"
        value="${value#.}"
        value="${value%.}"

        [[ -n "$value" ]] || value="page"
        printf '%s' "$value"
    }

    # _sgnd_doc_module_outfile
        # Returns:
        #   Output filename for one module page.
        # Usage:
        #   _sgnd_doc_module_outfile "$module_file"
    _sgnd_doc_module_outfile() {
        local module_file="${1:-module}"
        local base=""

        base="${module_file##*/}"
        base="${base%.sh}"
        printf '%s.html' "$(_sgnd_doc_slug "$base")"
    }

# -- Stream preparation ------------------------------------------------------------
    # fn: _sgnd_doc_build_render_stream
        # Purpose:
        #   Prepare the renderer-side stream from parser-produced DOC_RENDER rows.
        #
        # Behavior:
        #   - Resets RENDER_STREAM.
        #   - Copies DOC_RENDER rows without rejoining parser source tables.
        #   - Uses DOC_RENDER_SCHEMA when available.
        #
        # Inputs (globals):
        #   DOC_RENDER_SCHEMA
        #   DOC_RENDER
        #
        # Outputs (globals):
        #   RENDER_STREAM_SCHEMA
        #   RENDER_STREAM
        #
        # Returns:
        #   0 on success.
        #   1 if DOC_RENDER is unavailable.
        #
        # Usage:
        #   _sgnd_doc_build_render_stream
    _sgnd_doc_build_render_stream() {
        [[ "$(declare -p DOC_RENDER 2>/dev/null)" =~ "declare -a" ]] || return 1

        if [[ -n "${DOC_RENDER_SCHEMA:-}" ]]; then
            RENDER_STREAM_SCHEMA="$DOC_RENDER_SCHEMA"
        fi

        declare -g RENDER_STREAM=()
        RENDER_STREAM+=("${DOC_RENDER[@]}")

        return 0
    }

# -- Page preparation --------------------------------------------------------------
    # fn: _sgnd_doc_page_add
        # Purpose:
        #   Append one generated page definition.
        #
        # Arguments:
        #   $1  PAGE_ID
        #   $2  PAGE_TYPE
        #   $3  MODULE_FILE
        #   $4  SECTION
        #   $5  ITEM_TYPE
        #   $6  ITEM_NAME
        #   $7  TITLE
        #   $8  OUTFILE
        #   $9  TEMPLATE
        #
        # Outputs (globals):
        #   DOC_PAGE
        #
        # Returns:
        #   0 on success.
        #   1 on invalid required values.
        #
        # Usage:
        #   _sgnd_doc_page_add "index" "index" "" "" "" "" "Index" "index.html" "index"
    _sgnd_doc_page_add() {
        local page_id="${1:-}"
        local page_type="${2:-}"
        local module_file="${3:-}"
        local section="${4:-}"
        local item_type="${5:-}"
        local item_name="${6:-}"
        local title="${7:-}"
        local outfile="${8:-}"
        local template="${9:-}"

        [[ -n "$page_id" ]] || return 1
        [[ -n "$page_type" ]] || return 1
        [[ -n "$outfile" ]] || return 1

        DOC_PAGE+=("$page_id|$page_type|$module_file|$section|$item_type|$item_name|$title|$outfile|$template")
    }

    # fn: _sgnd_doc_build_pages
        # Purpose:
        #   Build the page list from DOC_MODULE and DOC_MASTER_INDEX.
        #
        # Behavior:
        #   - Always adds a site index page.
        #   - Adds one module page per DOC_MODULE row.
        #   - Adds item page definitions for later template work, but does not render them yet.
        #
        # Inputs (globals):
        #   DOC_MODULE
        #   DOC_MASTER_INDEX
        #
        # Outputs (globals):
        #   DOC_PAGE
        #
        # Returns:
        #   0 on success.
        #
        # Usage:
        #   _sgnd_doc_build_pages
    _sgnd_doc_build_pages() {
        declare -g DOC_PAGE=()

        local row=""
        local file="" product="" title="" type="" group="" purpose="" version="" build="" checksum="" developers="" company="" client="" copyright="" license=""
        local outfile=""
        local page_id=""

        _sgnd_doc_page_add "index" "index" "" "" "" "" "Documentation Index" "index.html" "index" || return 1

        for row in "${DOC_MODULE[@]:-}"; do
            IFS='|' read -r \
                file product title type group purpose version build checksum \
                developers company client copyright license <<< "$row"

            [[ -n "$file" ]] || continue

            outfile="$(_sgnd_doc_module_outfile "$file")"
            page_id="module:$file"

            _sgnd_doc_page_add "$page_id" "module" "$file" "" "" "" "$title" "$outfile" "module" || return 1
        done

        if [[ "$(declare -p DOC_MASTER_INDEX 2>/dev/null)" =~ "declare -a" ]]; then
            local index_type="" module_group="" module_title="" module_file="" access="" item_type="" item_name="" section="" source_linenr="" item_title=""
            for row in "${DOC_MASTER_INDEX[@]}"; do
                IFS='|' read -r index_type module_group module_title module_file access item_type item_name section source_linenr item_title <<< "$row"
                [[ "$index_type" == "item" ]] || continue
                [[ -n "$module_file" && -n "$item_name" ]] || continue

                outfile="$(_sgnd_doc_slug "${module_file%.sh}-${item_type}-${item_name}").html"
                page_id="item:$module_file:$item_type:$item_name"

                _sgnd_doc_page_add "$page_id" "item_${item_type}" "$module_file" "$section" "$item_type" "$item_name" "$item_title" "$outfile" "item_${item_type}" || return 1
            done
        fi

        return 0
    }

# -- HTML rendering ----------------------------------------------------------------
    # _sgnd_doc_write_css
        # Returns:
        #   0 on success.
        # Usage:
        #   _sgnd_doc_write_css "$outdir"
    _sgnd_doc_write_css() {
        local outdir="${1:-}"
        local css_file=""

        [[ -n "$outdir" ]] || return 1
        css_file="${outdir%/}/style.css"

        {
            printf '%s\n' ':root {'
            printf '%s\n' '    --sgnd-bg: #111318;'
            printf '%s\n' '    --sgnd-panel: #181b22;'
            printf '%s\n' '    --sgnd-panel-soft: #20242d;'
            printf '%s\n' '    --sgnd-text: #e8e8e8;'
            printf '%s\n' '    --sgnd-muted: #a8adb7;'
            printf '%s\n' '    --sgnd-accent: #7fb4ff;'
            printf '%s\n' '    --sgnd-border: #333946;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '* {'
            printf '%s\n' '    box-sizing: border-box;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' 'body {'
            printf '%s\n' '    margin: 0;'
            printf '%s\n' '    background: var(--sgnd-bg);'
            printf '%s\n' '    color: var(--sgnd-text);'
            printf '%s\n' '    font-family: Arial, Helvetica, sans-serif;'
            printf '%s\n' '    font-size: 15px;'
            printf '%s\n' '    line-height: 1.55;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' 'a {'
            printf '%s\n' '    color: var(--sgnd-accent);'
            printf '%s\n' '    text-decoration: none;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' 'a:hover {'
            printf '%s\n' '    text-decoration: underline;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.page {'
            printf '%s\n' '    max-width: 1100px;'
            printf '%s\n' '    margin: 0 auto;'
            printf '%s\n' '    padding: 32px;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.site-header,'
            printf '%s\n' '.module-header,'
            printf '%s\n' '.card {'
            printf '%s\n' '    background: var(--sgnd-panel);'
            printf '%s\n' '    border: 1px solid var(--sgnd-border);'
            printf '%s\n' '    border-radius: 14px;'
            printf '%s\n' '    padding: 20px 24px;'
            printf '%s\n' '    margin-bottom: 18px;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.nav {'
            printf '%s\n' '    display: flex;'
            printf '%s\n' '    gap: 10px;'
            printf '%s\n' '    margin: 0 0 18px 0;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.nav a {'
            printf '%s\n' '    background: var(--sgnd-panel-soft);'
            printf '%s\n' '    border: 1px solid var(--sgnd-border);'
            printf '%s\n' '    border-radius: 999px;'
            printf '%s\n' '    padding: 6px 12px;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.meta-grid {'
            printf '%s\n' '    display: grid;'
            printf '%s\n' '    grid-template-columns: 150px 1fr;'
            printf '%s\n' '    gap: 4px 14px;'
            printf '%s\n' '    color: var(--sgnd-muted);'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.section-header {'
            printf '%s\n' '    margin: 30px 0 10px 0;'
            printf '%s\n' '    padding-bottom: 6px;'
            printf '%s\n' '    border-bottom: 1px solid var(--sgnd-border);'
            printf '%s\n' '    font-size: 1.35rem;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.item-header {'
            printf '%s\n' '    margin: 22px 0 8px 0;'
            printf '%s\n' '    padding: 10px 12px;'
            printf '%s\n' '    background: var(--sgnd-panel-soft);'
            printf '%s\n' '    border-left: 4px solid var(--sgnd-accent);'
            printf '%s\n' '    border-radius: 8px;'
            printf '%s\n' '    font-size: 1.05rem;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.comment-section-header {'
            printf '%s\n' '    margin: 14px 0 4px 0;'
            printf '%s\n' '    color: var(--sgnd-accent);'
            printf '%s\n' '    font-weight: 700;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.prose {'
            printf '%s\n' '    margin: 3px 0 3px 18px;'
            printf '%s\n' '    white-space: pre-wrap;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.index-group {'
            printf '%s\n' '    margin-top: 24px;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.index-list {'
            printf '%s\n' '    list-style: none;'
            printf '%s\n' '    padding-left: 0;'
            printf '%s\n' '}'
            printf '\n'
            printf '%s\n' '.index-list li {'
            printf '%s\n' '    margin: 6px 0;'
            printf '%s\n' '}'
        } > "$css_file"
    }

    # _sgnd_doc_write_html_header
        # Returns:
        #   0 on success.
        # Usage:
        #   _sgnd_doc_write_html_header "$title" > "$file"
    _sgnd_doc_write_html_header() {
        local title="$(_sgnd_doc_html_escape "${1:-Documentation}")"

        cat <<HTML
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>$title</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="page">
HTML
    }

    # _sgnd_doc_write_html_footer
        # Returns:
        #   0 on success.
        # Usage:
        #   _sgnd_doc_write_html_footer >> "$file"
    _sgnd_doc_write_html_footer() {
        cat <<'HTML'
</div>
</body>
</html>
HTML
    }

    # fn: _sgnd_doc_render_index_page
        # Purpose:
        #   Render the main documentation index.
        #
        # Arguments:
        #   $1  OUTDIR
        #
        # Inputs (globals):
        #   DOC_MODULE
        #
        # Returns:
        #   0 on success.
        #   1 on write failure.
        #
        # Usage:
        #   _sgnd_doc_render_index_page "$outdir"
    _sgnd_doc_render_index_page() {
        local outdir="${1:-}"
        local page_file=""
        local row=""
        local file="" product="" title="" type="" group="" purpose="" version="" build="" checksum="" developers="" company="" client="" copyright="" license=""
        local current_group=""
        local safe_group=""
        local safe_title=""
        local safe_purpose=""
        local outfile=""

        [[ -n "$outdir" ]] || return 1
        page_file="${outdir%/}/index.html"

        {
            _sgnd_doc_write_html_header "Documentation Index"
            printf '<div class="site-header">\n'
            printf '  <h1>Documentation Index</h1>\n'
            printf '  <p>Generated from parser-produced documentation facts.</p>\n'
            printf '</div>\n'

            current_group=""
            for row in "${DOC_MODULE[@]:-}"; do
                IFS='|' read -r \
                    file product title type group purpose version build checksum \
                    developers company client copyright license <<< "$row"

                [[ -n "$file" ]] || continue

                if [[ "$group" != "$current_group" ]]; then
                    [[ -n "$current_group" ]] && printf '</ul>\n</div>\n'
                    current_group="$group"
                    safe_group="$(_sgnd_doc_html_escape "${current_group:-Ungrouped}")"
                    printf '<div class="index-group card">\n'
                    printf '  <h2>%s</h2>\n' "$safe_group"
                    printf '  <ul class="index-list">\n'
                fi

                outfile="$(_sgnd_doc_module_outfile "$file")"
                safe_title="$(_sgnd_doc_html_escape "${title:-$file}")"
                safe_purpose="$(_sgnd_doc_html_escape "$purpose")"
                printf '    <li><a href="%s">%s</a>' "$outfile" "$safe_title"
                [[ -n "$safe_purpose" ]] && printf ' — <span>%s</span>' "$safe_purpose"
                printf '</li>\n'
            done

            [[ -n "$current_group" ]] && printf '  </ul>\n</div>\n'
            _sgnd_doc_write_html_footer
        } > "$page_file" || return 1

        return 0
    }

    # _sgnd_doc_render_content_row
        # Returns:
        #   0 on success.
        # Usage:
        #   _sgnd_doc_render_content_row "$row"
    _sgnd_doc_render_content_row() {
        local row="${1:-}"
        local module_file="" module_group="" module_title="" access="" source_linenr="" section="" section_level="" parent="" grandparent="" item_type="" item_name="" line_type="" comment_section="" content_ord="" content=""
        local safe_content=""
        local safe_item=""
        local safe_item_type=""
        local safe_access=""

        IFS='|' read -r \
            module_file module_group module_title access source_linenr section section_level parent grandparent \
            item_type item_name line_type comment_section content_ord content <<< "$row"

        safe_content="$(_sgnd_doc_html_escape "$content")"
        safe_item="$(_sgnd_doc_html_escape "$item_name")"
        safe_item_type="$(_sgnd_doc_html_escape "$item_type")"
        safe_access="$(_sgnd_doc_html_escape "$access")"

        case "$line_type" in
            sectionheader)
                printf '<h2 class="section-header" data-line="%s">%s</h2>\n' "$source_linenr" "$safe_content"
                ;;
            itemheader)
                printf '<h3 class="item-header" data-line="%s">%s <span>(%s, %s)</span></h3>\n' "$source_linenr" "$safe_item" "$safe_item_type" "$safe_access"
                ;;
            commentsectionheader)
                printf '<div class="comment-section-header" data-line="%s">%s</div>\n' "$source_linenr" "$safe_content"
                ;;
            prose)
                [[ -n "$safe_content" ]] && printf '<div class="prose" data-line="%s">%s</div>\n' "$source_linenr" "$safe_content"
                ;;
            *)
                [[ -n "$safe_content" ]] && printf '<div class="prose" data-line="%s">%s</div>\n' "$source_linenr" "$safe_content"
                ;;
        esac
    }

    # fn: _sgnd_doc_render_module_page
        # Purpose:
        #   Render one module page from DOC_MODULE and RENDER_STREAM rows.
        #
        # Arguments:
        #   $1  OUTDIR
        #   $2  MODULE_ROW
        #
        # Inputs (globals):
        #   RENDER_STREAM
        #
        # Returns:
        #   0 on success.
        #   1 on write failure.
        #
        # Usage:
        #   _sgnd_doc_render_module_page "$outdir" "$module_row"
    _sgnd_doc_render_module_page() {
        local outdir="${1:-}"
        local module_row="${2:-}"
        local file="" product="" title="" type="" group="" purpose="" version="" build="" checksum="" developers="" company="" client="" copyright="" license=""
        local page_file=""
        local outfile=""
        local row=""
        local render_module_file=""
        local safe_title=""
        local safe_group=""
        local safe_purpose=""
        local safe_type=""
        local safe_version=""
        local safe_build=""
        local safe_developers=""
        local safe_company=""
        local safe_license=""

        [[ -n "$outdir" ]] || return 1
        [[ -n "$module_row" ]] || return 1

        IFS='|' read -r \
            file product title type group purpose version build checksum \
            developers company client copyright license <<< "$module_row"

        [[ -n "$file" ]] || return 1

        outfile="$(_sgnd_doc_module_outfile "$file")"
        page_file="${outdir%/}/$outfile"

        safe_title="$(_sgnd_doc_html_escape "${title:-$file}")"
        safe_group="$(_sgnd_doc_html_escape "$group")"
        safe_purpose="$(_sgnd_doc_html_escape "$purpose")"
        safe_type="$(_sgnd_doc_html_escape "$type")"
        safe_version="$(_sgnd_doc_html_escape "$version")"
        safe_build="$(_sgnd_doc_html_escape "$build")"
        safe_developers="$(_sgnd_doc_html_escape "$developers")"
        safe_company="$(_sgnd_doc_html_escape "$company")"
        safe_license="$(_sgnd_doc_html_escape "$license")"

        {
            _sgnd_doc_write_html_header "$safe_title"
            printf '<nav class="nav"><a href="index.html">Index</a></nav>\n'
            printf '<header class="module-header">\n'
            printf '  <h1>%s</h1>\n' "$safe_title"
            [[ -n "$safe_purpose" ]] && printf '  <p>%s</p>\n' "$safe_purpose"
            printf '  <div class="meta-grid">\n'
            printf '    <div>Group</div><div>%s</div>\n' "$safe_group"
            printf '    <div>Type</div><div>%s</div>\n' "$safe_type"
            printf '    <div>Version</div><div>%s</div>\n' "$safe_version"
            printf '    <div>Build</div><div>%s</div>\n' "$safe_build"
            printf '    <div>Developers</div><div>%s</div>\n' "$safe_developers"
            printf '    <div>Company</div><div>%s</div>\n' "$safe_company"
            printf '    <div>License</div><div>%s</div>\n' "$safe_license"
            printf '  </div>\n'
            printf '</header>\n'

            for row in "${RENDER_STREAM[@]:-}"; do
                IFS='|' read -r render_module_file _ <<< "$row"
                [[ "$render_module_file" == "$file" ]] || continue
                _sgnd_doc_render_content_row "$row"
            done

            _sgnd_doc_write_html_footer
        } > "$page_file" || return 1

        return 0
    }

    # fn: _sgnd_doc_render_pages
        # Purpose:
        #   Render all currently supported page types.
        #
        # Arguments:
        #   $1  OUTDIR
        #
        # Inputs (globals):
        #   DOC_MODULE
        #   RENDER_STREAM
        #
        # Returns:
        #   0 on success.
        #   1 on render failure.
        #
        # Usage:
        #   _sgnd_doc_render_pages "$outdir"
    _sgnd_doc_render_pages() {
        local outdir="${1:-}"
        local row=""
        local page_current=0
        local page_total=0
        local file="" product="" title="" type="" group="" purpose="" version="" build="" checksum="" developers="" company="" client="" copyright="" license=""
        local label=""

        [[ -n "$outdir" ]] || return 1

        page_total=$(( ${#DOC_MODULE[@]} + 2 ))

        (( page_current++ ))
        if declare -F sayprogress >/dev/null; then
            sayprogress \
                --current "$page_current" \
                --total "$page_total" \
                --label "Rendering stylesheet" \
                --type 5 \
                --padleft 0
        else
            sayinfo "Rendering [$page_current/$page_total]: stylesheet"
        fi
        _sgnd_doc_write_css "$outdir" || return 1

        (( page_current++ ))
        if declare -F sayprogress >/dev/null; then
            sayprogress \
                --current "$page_current" \
                --total "$page_total" \
                --label "Rendering index page" \
                --type 5 \
                --padleft 0
        else
            sayinfo "Rendering [$page_current/$page_total]: index page"
        fi
        _sgnd_doc_render_index_page "$outdir" || return 1

        for row in "${DOC_MODULE[@]:-}"; do
            IFS='|' read -r \
                file product title type group purpose version build checksum \
                developers company client copyright license <<< "$row"

            label="Rendering module: ${title:-$file}"

            (( page_current++ ))
            if declare -F sayprogress >/dev/null; then
                sayprogress \
                    --current "$page_current" \
                    --total "$page_total" \
                    --label "$label" \
                    --type 5 \
                    --padleft 0
            else
                sayinfo "Rendering [$page_current/$page_total]: ${title:-$file}"
            fi

            _sgnd_doc_render_module_page "$outdir" "$row" || return 1
        done

        if declare -F sayprogress_done >/dev/null; then
            sayprogress_done
        fi

        return 0
    }
# - Public API ---------------------------------------------------------------------
    # fn: sgnd_doc_render_site
        # Purpose:
        #   Build and render the documentation site from parser-produced render facts.
        #
        # Arguments:
        #   $1  OUTDIR
        #       Output directory for rendered site files.
        #
        # Inputs (globals):
        #   DOC_MODULE
        #   DOC_RENDER
        #   DOC_MASTER_INDEX
        #   FLAG_REVIEW
        #
        # Outputs (globals):
        #   RENDER_STREAM
        #   DOC_PAGE
        #
        # Returns:
        #   0 on success.
        #   1 on invalid input or render failure.
        #
        # Usage:
        #   sgnd_doc_render_site "$VAL_OUTDIR"
    sgnd_doc_render_site() {
        local outdir="${1:-}"

        sayinfo "Rendering site to $outdir"
        [[ -n "$outdir" ]] || return 1

        mkdir -p "$outdir" || return 1

        _sgnd_doc_build_render_stream || {
            sayfail "DOC_RENDER is not available; render site requires the v2 parser output."
            return 1
        }

        _sgnd_doc_build_pages || return 1

        if (( ${FLAG_REVIEW:-0} )); then
            if declare -F sgnd_dt_print_table >/dev/null; then
                sgnd_dt_print_table "$RENDER_STREAM_SCHEMA" RENDER_STREAM
                sgnd_dt_print_table "$DOC_PAGE_SCHEMA" DOC_PAGE
            else
                printf '%s\n' "RENDER_STREAM rows: ${#RENDER_STREAM[@]}" >&2
                printf '%s\n' "DOC_PAGE rows: ${#DOC_PAGE[@]}" >&2
            fi
        fi

        _sgnd_doc_render_pages "$outdir" || return 1

        sayok "Rendered documentation site to $outdir"
        return 0
    }
