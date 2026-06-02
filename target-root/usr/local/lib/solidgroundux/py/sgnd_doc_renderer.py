#!/usr/bin/env python3
"""
SolidgroundUX - Documentation HTML Renderer Backend
---------------------------------------------------

Purpose:
    Render SolidgroundUX documentation from normalized table exports produced by
    the Bash doc-generator/parser.

Backend contract:
    python3 sgnd_doc_renderer.py <input-dir> <output-dir>

Expected input files in <input-dir>:
    mod_table.psv
    mod_sections.psv
    mod_items.psv
    doc_content_lines.psv
    render_config.psv

File format:
    - Pipe-separated values
    - First line contains the schema/header
    - Remaining lines contain data rows
    - Values must not contain literal pipe characters

Notes:
    This script intentionally uses only the Python standard library.
"""

from __future__ import annotations

import html
import re
import shutil
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from textwrap import indent
from typing import Dict, Iterable, List, Sequence

RENDERER_BUILD = "20260602-1235-nav-v4"


# ------------------------------------------------------------------------------
# Data loading
# ------------------------------------------------------------------------------

Row = Dict[str, str]


def read_psv(path: Path) -> List[Row]:
    """Read a pipe-separated table with a schema/header row."""
    if not path.exists():
        raise FileNotFoundError(f"Missing input table: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        return []

    columns = lines[0].split("|")
    rows: List[Row] = []

    for line_number, line in enumerate(lines[1:], start=2):
        values = line.split("|")

        if len(values) < len(columns):
            values.extend([""] * (len(columns) - len(values)))

        if len(values) > len(columns):
            raise ValueError(
                f"Invalid column count in {path.name} line {line_number}: "
                f"expected {len(columns)}, got {len(values)}"
            )

        rows.append(dict(zip(columns, values)))

    return rows


def read_config(path: Path) -> Dict[str, str]:
    """Read render_config.psv as key|value."""
    if not path.exists():
        return {}

    rows = read_psv(path)
    config: Dict[str, str] = {}

    for row in rows:
        key = row.get("key", "")
        value = row.get("value", "")
        if key:
            config[key] = value

    return config


# ------------------------------------------------------------------------------
# Utility helpers
# ------------------------------------------------------------------------------

def esc(value: str | None) -> str:
    """HTML-escape a string."""
    return html.escape(value or "", quote=True)


def slugify(value: str | None) -> str:
    """Convert a content reference or label into a safe filename slug."""
    text = (value or "").lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")
    return text or "page"


def content_ref(
    module_name: str,
    grandparent_section: str = "",
    parent_section: str = "",
    section_name: str = "",
    item_name: str = "",
) -> str:
    """Build the same canonical content reference as the Bash parser."""
    return f"{module_name}:{grandparent_section}:{parent_section}:{section_name}:{item_name}"


def page_href_from_contentref(ref: str) -> str:
    return f"pages/{slugify(ref)}.html"


def is_item_node(node_type: str) -> bool:
    return node_type in {"function", "variable", "general documentation"}


def row_sort_key(row: Row, fields: Sequence[str]) -> tuple[str, ...]:
    return tuple((row.get(field, "") or "").lower() for field in fields)


def display_name_with_title(name: str, title: str) -> str:
    """Prefer the technical name, optionally followed by the friendly title."""
    clean_name = name or ""
    clean_title = title or ""

    if clean_title and clean_title != clean_name:
        return f"{clean_name} - {clean_title}"

    return clean_name


# ------------------------------------------------------------------------------
# Renderer model
# ------------------------------------------------------------------------------

@dataclass
class NavNode:
    nodeid: str
    parentnodeid: str
    nodetype: str
    node_name: str
    node_title: str
    hierarchy_level: int
    docindex: str
    contentref: str
    hasitems: bool = False
    isinternal: bool = False
    istemplate: bool = False


class DocRenderer:
    def __init__(self, input_dir: Path, output_dir: Path) -> None:
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.asset_dir = output_dir / "assets"
        self.page_dir = output_dir / "pages"

        self.mod_table: List[Row] = []
        self.mod_sections: List[Row] = []
        self.mod_items: List[Row] = []
        self.doc_content_lines: List[Row] = []
        self.config: Dict[str, str] = {}

        self.nav: List[NavNode] = []
        self.content_by_ref: Dict[str, List[Row]] = defaultdict(list)

        self.doc_title = ""
        self.doc_subtitle = ""
        self.doc_version = ""
        self.doc_product = ""
        self.doc_render_date = ""

    # --------------------------------------------------------------------------
    # Main sequence
    # --------------------------------------------------------------------------

    def run(self) -> None:
        self.load_input()
        self.prepare_output()
        self.init_metadata()
        self.build_doc_hierarchy()
        self.build_content_index()
        self.render_assets()
        self.render_content_pages()
        self.render_index_page()

    def load_input(self) -> None:
        self.mod_table = read_psv(self.input_dir / "mod_table.psv")
        self.mod_sections = read_psv(self.input_dir / "mod_sections.psv")
        self.mod_items = read_psv(self.input_dir / "mod_items.psv")
        self.doc_content_lines = read_psv(self.input_dir / "doc_content_lines.psv")
        self.config = read_config(self.input_dir / "render_config.psv")

    def prepare_output(self) -> None:
        clean_output = self.config.get("FLAG_CLEAN_OUTPUT", "1") == "1"

        if clean_output and self.output_dir.exists():
            shutil.rmtree(self.output_dir)

        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.asset_dir.mkdir(parents=True, exist_ok=True)
        self.page_dir.mkdir(parents=True, exist_ok=True)

    def init_metadata(self) -> None:
        self.doc_title = self.config.get("VAL_DOCUMENT_TITLE", "SolidGroundUX Documentation")
        self.doc_subtitle = self.config.get("VAL_DOCUMENT_SUBTITLE", "")
        self.doc_version = self.config.get("VAL_DOCUMENT_VERSION", "")
        self.doc_product = self.config.get("VAL_DOCUMENT_PRODUCT", "")
        self.doc_render_date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # --------------------------------------------------------------------------
    # Hierarchy construction
    # --------------------------------------------------------------------------

    def build_doc_hierarchy(self) -> None:
        self.nav = []

        # Render groups alphabetically, and render all modules for each group
        # together. A linear <details> renderer cannot correctly "return" to an
        # earlier group once another group has been emitted.
        module_rows = list(self.mod_table)
        section_rows = list(self.mod_sections)
        item_rows = list(self.mod_items)

        modules_by_group: Dict[str, List[Row]] = {}

        for module in module_rows:
            group_name = module.get("group", "") or "Ungrouped"
            modules_by_group.setdefault(group_name, []).append(module)

        group_order = sorted(modules_by_group.keys(), key=str.casefold)

        product_name = self.doc_product or "Documentation"
        product_node_id = f"product:{product_name}"

        self.nav.append(
            NavNode(
                nodeid=product_node_id,
                parentnodeid="root",
                nodetype="product",
                node_name=product_name,
                node_title=product_name,
                hierarchy_level=0,
                docindex="1",
                contentref="",
            )
        )

        for group_index, group_name in enumerate(group_order, start=1):
            group_docindex = f"1.{group_index}"
            group_node_id = f"group:{product_name}:{group_name}"

            self.nav.append(
                NavNode(
                    nodeid=group_node_id,
                    parentnodeid=product_node_id,
                    nodetype="group",
                    node_name=group_name,
                    node_title=group_name,
                    hierarchy_level=1,
                    docindex=group_docindex,
                    contentref="",
                )
            )

            group_modules = sorted(
                modules_by_group[group_name],
                key=lambda module: (
                    (module.get("name", "") or module.get("title", "")).casefold(),
                    module.get("title", "").casefold(),
                ),
            )

            for module_index, module in enumerate(group_modules, start=1):
                module_name = module.get("name", "")
                module_title = module.get("title", "") or module_name
                module_docindex = f"{group_docindex}.{module_index}"

                module_node_id = f"mod:{module_name}"
                module_ref = content_ref(module_name)

                self.nav.append(
                    NavNode(
                        nodeid=module_node_id,
                        parentnodeid=group_node_id,
                        nodetype="module",
                        node_name=module_name,
                        node_title=module_title,
                        hierarchy_level=2,
                        docindex=module_docindex,
                        contentref=module_ref,
                    )
                )

                module_sections = [
                    section for section in section_rows
                    if section.get("modulename", "") == module_name
                ]
                module_items = [
                    item for item in item_rows
                    if item.get("modulename", "") == module_name
                ]

                l1_index = 0
                l2_index = 0
                l3_index = 0
                section_node_ids: Dict[tuple[str, str, str], str] = {}
                section_docindex_by_id: Dict[str, str] = {}

                for section in module_sections:
                    section_name = section.get("section", "")
                    section_title = section.get("title", "") or section_name
                    parent_section = section.get("parent", "")
                    grandparent_section = section.get("grandparent", "")
                    level_text = section.get("level", "1")

                    try:
                        section_level = int(level_text)
                    except ValueError:
                        section_level = 1

                    if section_level < 1 or section_level > 3:
                        continue

                    if section_level == 1:
                        l1_index += 1
                        l2_index = 0
                        l3_index = 0
                        parent_node_id = module_node_id
                        docindex = f"{module_docindex}.{l1_index}"
                        node_id = f"sec:{module_name}:{section_name}"

                    elif section_level == 2:
                        l2_index += 1
                        l3_index = 0
                        parent_node_id = section_node_ids.get((parent_section, "", ""), module_node_id)
                        parent_docindex = section_docindex_by_id.get(parent_node_id, module_docindex)
                        docindex = f"{parent_docindex}.{l2_index}"
                        node_id = f"sec:{module_name}:{parent_section}:{section_name}"

                    else:
                        l3_index += 1
                        parent_node_id = section_node_ids.get((parent_section, grandparent_section, ""), module_node_id)
                        parent_docindex = section_docindex_by_id.get(parent_node_id, module_docindex)
                        docindex = f"{parent_docindex}.{l3_index}"
                        node_id = f"sec:{module_name}:{grandparent_section}:{parent_section}:{section_name}"

                    section_node_ids[(section_name, parent_section, grandparent_section)] = node_id
                    section_docindex_by_id[node_id] = docindex

                    section_ref = content_ref(
                        module_name,
                        grandparent_section,
                        parent_section,
                        section_name,
                        "",
                    )

                    nav_level = 2 + section_level
                    self.nav.append(
                        NavNode(
                            nodeid=node_id,
                            parentnodeid=parent_node_id,
                            nodetype="section",
                            node_name=section_name,
                            node_title=section_title,
                            hierarchy_level=nav_level,
                            docindex=docindex,
                            contentref=section_ref,
                        )
                    )

                    section_items = [
                        item for item in module_items
                        if item.get("section", "") == section_name
                        and item.get("parentsection", "") == parent_section
                        and item.get("grandparentsection", "") == grandparent_section
                    ]

                    for item_index, item in enumerate(section_items, start=1):
                        item_name = item.get("name", "")
                        item_title = item.get("title", "") or item_name
                        item_type = item.get("type", "")
                        item_typecode = item.get("typecode", "item")
                        item_visibility = item.get("itemvisibility", "")
                        item_role = item.get("itemrole", "")

                        item_ref = content_ref(
                            module_name,
                            grandparent_section,
                            parent_section,
                            section_name,
                            item_name,
                        )

                        item_node_id = (
                            f"{item_typecode}:{module_name}:{grandparent_section}:"
                            f"{parent_section}:{section_name}:{item_name}"
                        )
                        item_docindex = f"{docindex}.{item_index}"

                        self.nav.append(
                            NavNode(
                                nodeid=item_node_id,
                                parentnodeid=node_id,
                                nodetype=item_type,
                                node_name=item_name,
                                node_title=item_title,
                                hierarchy_level=nav_level + 1,
                                docindex=item_docindex,
                                contentref=item_ref,
                                isinternal=item_visibility == "internal",
                                istemplate=item_role == "template",
                            )
                        )

    def build_content_index(self) -> None:
        rows = sorted(
            self.doc_content_lines,
            key=lambda r: int(r.get("doc_linenr", "0") or "0"),
        )

        for row in rows:
            ref = row.get("contentref", "")
            self.content_by_ref[ref].append(row)

    # --------------------------------------------------------------------------
    # Rendering
    # --------------------------------------------------------------------------

    def render_assets(self) -> None:
        self.render_layout_css()
        self.ensure_theme_css()

    def render_layout_css(self) -> None:
        css_file = self.asset_dir / "doc.css"

        css_lines = [
            "html, body {",
            "    margin: 0;",
            "    padding: 0;",
            "    height: 100%;",
            "}",
            "",
            "body {",
            "    border-top: 3px solid #222;",
            "}",
            "",
            ".doc-shell {",
            "    display: grid;",
            f"    grid-template-columns: {self.config.get('VAL_NAV_WIDTH', '320px')} 1fr;",
            "    height: 100vh;",
            "}",
            "",
            ".doc-nav {",
            "    border-right: 1px solid #d0d0d0;",
            "    overflow: auto;",
            "    padding: 36px 20px 14px 20px;",
            "}",
            "",
            ".doc-nav-title {",
            "    margin: 0 0 14px 0;",
            "    padding-bottom: 6px;",
            "    border-bottom: 1px solid #c0c0c0;",
            "}",
            "",
            ".doc-nav-node {",
            "    margin-top: 4px;",
            "    margin-bottom: 4px;",
            "}",
            "",
            ".doc-nav-node summary {",
            "    cursor: pointer;",
            "    line-height: 1.25;",
            "}",
            "",
            ".doc-nav-module {",
            "    text-decoration: none;",
            "}",
            "",
            ".doc-nav-module:hover {",
            "    text-decoration: underline;",
            "}",
            "",
            ".doc-nav-section {",
            "    display: block;",
            "    margin-top: 6px;",
            "    margin-bottom: 2px;",
            "    text-decoration: none;",
            "}",
            "",
            "a.doc-nav-section:hover {",
            "    text-decoration: underline;",
            "}",
            "",
            ".doc-nav-section.level-1 {",
            "    margin-left: 14px;",
            "}",
            "",
            ".doc-nav-section.level-2 {",
            "    margin-left: 24px;",
            "}",
            "",
            ".doc-nav-section.level-3 {",
            "    margin-left: 34px;",
            "}",
            "",
            ".doc-nav-item {",
            "    display: block;",
            "    text-decoration: none;",
            "    line-height: 1.2;",
            "    margin-top: 2px;",
            "    margin-bottom: 2px;",
            "}",
            "",
            ".doc-nav-item:hover {",
            "    text-decoration: underline;",
            "}",
            "",
            ".doc-content-frame {",
            "    width: 100%;",
            "    height: 100vh;",
            "    border: 0;",
            "}",
            "",
            ".doc-page {",
            "    padding: 24px 36px;",
            "}",
            "",
            ".doc-page-header {",
            "    border-bottom: 1px solid #d0d0d0;",
            "    margin-bottom: 22px;",
            "    padding-bottom: 12px;",
            "}",
            "",
        ]

        css_file.write_text("\n".join(css_lines), encoding="utf-8")

    def ensure_theme_css(self) -> None:
        theme_file = self.asset_dir / "theme.css"

        if theme_file.exists():
            return

        theme_file.write_text(self.default_theme_css(), encoding="utf-8")

    def default_theme_css(self) -> str:
        return """html, body {
    font-family: Arial, sans-serif;
    color: #222;
    background: #ffffff;
}

body {
    font-size: 10pt;
}

.doc-nav {
    background: #f6f6f6;
}

.doc-nav-title {
    font-size: 12pt;
    font-weight: bold;
}

.doc-nav-node summary {
    font-weight: bold;
}

.doc-nav-node.level-0 > summary {
    font-size: 11pt;
    font-weight: bold;
}

.doc-nav-module {
    color: #111;
}

.doc-nav-section {
    font-size: 10pt;
    color: #111;
}

.doc-nav-section.level-1,
.doc-nav-section.level-2 {
    font-weight: 600;
}

.doc-nav-section.level-3 {
    font-weight: 500;
}

.doc-nav-item {
    color: #204a87;
    font-size: 9.5pt;
}

.doc-title {
    font-family: Arial, sans-serif;
    font-size: 18pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.25;
    margin: 0 0 14px 0;
}

.doc-breadcrumb {
    font-style: italic;
    color: #666;
    font-size: 10pt;
}

.ct-prefaceheader,
.ct-moduleheader {
    font-family: Arial, sans-serif;
    font-size: 22pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.2;
    margin: 0 0 16px 0;
}

.ct-epilogueheader,
.ct-appendixheader {
    font-family: Arial, sans-serif;
    font-size: 20pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.2;
    margin: 0 0 14px 0;
}

.ct-L1Sectionheader {
    font-family: Arial, sans-serif;
    font-size: 18pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.25;
    margin: 24px 0 10px 0;
}

.ct-L2Sectionheader {
    font-family: Arial, sans-serif;
    font-size: 15pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.25;
    margin: 18px 0 8px 0;
}

.ct-L3Sectionheader {
    font-family: Arial, sans-serif;
    font-size: 13pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.25;
    margin: 14px 0 6px 0;
}

.ct-functionheader,
.ct-variableheader {
    font-family: Arial, sans-serif;
    font-size: 11pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.35;
    margin: 12px 0 4px 0;
}

.ct-gendocheader {
    font-family: Arial, sans-serif;
    font-size: 12pt;
    font-weight: bold;
    font-style: normal;
    line-height: 1.35;
    margin: 12px 0 5px 0;
}

.ct-prefacebody,
.ct-modulebody,
.ct-epiloguebody,
.ct-appendixbody,
.ct-L1Sectionbody,
.ct-L2Sectionbody,
.ct-L3Sectionbody,
.ct-functionbody,
.ct-variablebody,
.ct-gendocbody,
.ct-documentbody {
    font-family: Arial, sans-serif;
    font-size: 10pt;
    font-weight: normal;
    font-style: normal;
    line-height: 1.45;
    margin: 0 0 6px 0;
    white-space: pre-wrap;
    tab-size: 4;
}

.sh-label {
    font-weight: bold;
    margin: 8px 0 3px 0;
}

.sh-emphasis {
    font-weight: bold;
}

.sh-quote {
    font-style: italic;
    margin-left: 18px;
}

.sh-listitem {
    margin-left: 22px;
}

.sh-listitem::before {
    content: "\\2022 ";
}

.sh-indent {
    margin-left: 22px;
}
"""

    def render_index_page(self) -> None:
        first_page = self.get_first_item_page()
        index_file = self.output_dir / "index.html"

        html_lines = [
            "<!doctype html>",
            "<html>",
            "<head>",
            '  <meta charset="utf-8">',
            f"  <title>{esc(self.doc_title)}</title>",
            '  <link rel="stylesheet" href="assets/doc.css">\n  <link rel="stylesheet" href="assets/theme.css">',
            "</head>",
            "<body>",
            '<div class="doc-shell">',
            '<nav class="doc-nav">',
            '  <div class="doc-nav-title">Index</div>',
            self.render_navigation(),
            "</nav>",
            f'<iframe class="doc-content-frame" name="docframe" src="{esc(first_page)}"></iframe>',
            "</div>",
            "</body>",
            "</html>",
        ]

        index_file.write_text("\n".join(html_lines), encoding="utf-8")

    def render_navigation(self) -> str:
        lines: List[str] = []
        open_detail_levels: List[int] = []
        container_types = {"group", "module"}

        for node in self.nav:
            label = node.node_name
            current_level = node.hierarchy_level
            indent = current_level * 12
            style = f'padding-left:{indent}px'
            href = page_href_from_contentref(node.contentref) if node.contentref else ""

            while open_detail_levels and open_detail_levels[-1] >= current_level:
                lines.append("</details>")
                open_detail_levels.pop()

            if node.nodetype in container_types:
                type_class = slugify(node.nodetype)
                lines.append(f'<details class="doc-nav-node level-{current_level} type-{type_class}">')

                if node.contentref and node.contentref in self.content_by_ref:
                    lines.append(
                        f'<summary style="{style}"><a class="doc-nav-module" href="{esc(href)}" '
                        f'target="docframe">{esc(label)}</a></summary>'
                    )
                else:
                    lines.append(f'<summary style="{style}">{esc(label)}</summary>')

                open_detail_levels.append(current_level)
                continue

            if is_item_node(node.nodetype):
                type_class = slugify(node.nodetype)
                lines.append(
                    f'<a class="doc-nav-item type-{type_class}" style="{style}" '
                    f'href="{esc(href)}" target="docframe">{esc(label)}</a>'
                )

            elif node.contentref in self.content_by_ref:
                lines.append(
                    f'<a class="doc-nav-section" style="{style}" '
                    f'href="{esc(href)}" target="docframe">{esc(label)}</a>'
                )

            else:
                lines.append(
                    f'<div class="doc-nav-section" style="{style}">{esc(label)}</div>'
                )

        while open_detail_levels:
            lines.append("</details>")
            open_detail_levels.pop()

        return "\n".join(lines)

    def get_first_item_page(self) -> str:
        for node in self.nav:
            if node.contentref in self.content_by_ref:
                return page_href_from_contentref(node.contentref)

        for ref in self.content_by_ref:
            return page_href_from_contentref(ref)

        return "about:blank"

    def render_content_pages(self) -> None:
        rendered_refs: set[str] = set()

        for node in self.nav:
            if node.contentref not in self.content_by_ref:
                continue

            self.render_content_page(node)
            rendered_refs.add(node.contentref)

        for ref, rows in self.content_by_ref.items():
            if ref in rendered_refs:
                continue

            self.render_content_page_for_ref(ref, rows)

    def render_content_page(self, node: NavNode) -> None:
        href = page_href_from_contentref(node.contentref)
        output_file = self.output_dir / href
        output_file.parent.mkdir(parents=True, exist_ok=True)

        title = node.node_title or node.node_name
        breadcrumb = self.breadcrumb_from_contentref(node.contentref)
        body = self.render_content_for_ref(node.contentref)

        html_lines = [
            "<!doctype html>",
            "<html>",
            "<head>",
            '  <meta charset="utf-8">',
            f"  <title>{esc(title)}</title>",
            '  <link rel="stylesheet" href="../assets/doc.css">',
            '  <link rel="stylesheet" href="../assets/theme.css">',
            "</head>",
            "<body>",
            '<main class="doc-page">',
            '<header class="doc-page-header">',
            f'  <div class="doc-title">{esc(self.doc_title)}</div>',
            f'  <div class="doc-breadcrumb">{esc(breadcrumb)}</div>',
            "</header>",
            body,
            "</main>",
            "</body>",
            "</html>",
        ]

        output_file.write_text("\n".join(html_lines), encoding="utf-8")

    def render_content_page_for_ref(self, ref: str, rows: List[Row]) -> None:
        href = page_href_from_contentref(ref)
        output_file = self.output_dir / href
        output_file.parent.mkdir(parents=True, exist_ok=True)

        title = ref.split(":")[-1] or ref.split(":")[0] or "Documentation"
        for row in rows:
            content_type = row.get("contenttype", "")
            if content_type.endswith("header"):
                title = row.get("content", title) or title
                break

        body = self.render_content_for_ref(ref)

        html_lines = [
            "<!doctype html>",
            "<html>",
            "<head>",
            '  <meta charset="utf-8">',
            f"  <title>{esc(title)}</title>",
            '  <link rel="stylesheet" href="../assets/doc.css">',
            '  <link rel="stylesheet" href="../assets/theme.css">',
            "</head>",
            "<body>",
            '<main class="doc-page">',
            '<header class="doc-page-header">',
            f'  <div class="doc-title">{esc(self.doc_title)}</div>',
            f'  <div class="doc-breadcrumb">{esc(ref)}</div>',
            "</header>",
            body,
            "</main>",
            "</body>",
            "</html>",
        ]

        output_file.write_text("\n".join(html_lines), encoding="utf-8")

    def breadcrumb_from_contentref(self, ref: str) -> str:
        parts = ref.split(":")
        while len(parts) < 5:
            parts.append("")

        module_name, grandparent_section, parent_section, section_name, item_name = parts[:5]

        breadcrumb_parts = [
            self.doc_product,
            module_name,
            grandparent_section,
            parent_section,
            section_name,
            item_name,
        ]

        return " / ".join(part for part in breadcrumb_parts if part)

    def render_content_for_ref(self, ref: str) -> str:
        lines: List[str] = []

        for row in self.content_by_ref.get(ref, []):
            content_type = row.get("contenttype", "documentbody") or "documentbody"
            style_hint = row.get("stylehint", "normal") or "normal"
            content = row.get("content", "")

            classes = [f"ct-{content_type}"]
            if style_hint != "normal":
                classes.append(f"sh-{style_hint}")

            css_class = " ".join(classes)
            lines.append(f'<div class="{esc(css_class)}">{esc(content)}</div>')

        return "\n".join(lines)

# ------------------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------------------

def main(argv: Sequence[str]) -> int:
    if len(argv) != 3:
        print("Usage: python3 sgnd_doc_renderer.py <input-dir> <output-dir>", file=sys.stderr)
        return 2

    input_dir = Path(argv[1]).resolve()
    output_dir = Path(argv[2]).resolve()

    try:
        print(f"SGND doc renderer build: {RENDERER_BUILD}", file=sys.stderr)
        renderer = DocRenderer(input_dir, output_dir)
        renderer.run()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
