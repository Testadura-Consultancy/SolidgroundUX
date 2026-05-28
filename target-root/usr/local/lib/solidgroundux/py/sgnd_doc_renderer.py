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
from typing import Dict, Iterable, List, Sequence


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
        self.build_content_index()
        self.build_doc_hierarchy()
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

        module_rows = sorted(self.mod_table, key=lambda r: row_sort_key(r, ["product", "group", "type", "name"]))
        section_rows = sorted(self.mod_sections, key=lambda r: row_sort_key(r, ["modulename", "parent", "section", "level"]))
        item_rows = sorted(self.mod_items, key=lambda r: row_sort_key(r, ["modulename", "section", "itemvisibility", "type", "name"]))

        l1_index = 0

        for module in module_rows:
            l1_index += 1
            l2_index = 0
            l3_index = 0
            l4_index = 0
            l5_index = 0

            module_name = module.get("name", "")
            module_title = module.get("title", module_name)
            module_type = module.get("type", "module") or "module"

            module_node_id = f"mod:{module_name}"
            module_ref = content_ref(module_name)

            self.nav.append(
                NavNode(
                    nodeid=module_node_id,
                    parentnodeid="root",
                    nodetype="module",
                    node_name=module_name,
                    node_title=module_title,
                    hierarchy_level=0,
                    docindex=str(l1_index),
                    contentref=module_ref,
                )
            )

            section_node_ids: Dict[tuple[str, str, str], str] = {}

            for section in section_rows:
                if section.get("modulename", "") != module_name:
                    continue

                section_name = section.get("section", "")
                section_title = section.get("title", section_name)
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
                    l2_index += 1
                    l3_index = 0
                    l4_index = 0
                    l5_index = 0
                    parent_node_id = module_node_id
                    docindex = f"{l1_index}.{l2_index}"
                    node_id = f"sec:{module_name}:{section_name}"

                elif section_level == 2:
                    l3_index += 1
                    l4_index = 0
                    l5_index = 0
                    parent_node_id = section_node_ids.get((parent_section, "", ""), module_node_id)
                    docindex = f"{l1_index}.{l2_index}.{l3_index}"
                    node_id = f"sec:{module_name}:{parent_section}:{section_name}"

                else:
                    l4_index += 1
                    l5_index = 0
                    parent_node_id = section_node_ids.get((parent_section, grandparent_section, ""), module_node_id)
                    docindex = f"{l1_index}.{l2_index}.{l3_index}.{l4_index}"
                    node_id = f"sec:{module_name}:{grandparent_section}:{parent_section}:{section_name}"

                section_node_ids[(section_name, parent_section, grandparent_section)] = node_id

                section_ref = content_ref(
                    module_name,
                    grandparent_section,
                    parent_section,
                    section_name,
                    "",
                )

                self.nav.append(
                    NavNode(
                        nodeid=node_id,
                        parentnodeid=parent_node_id,
                        nodetype="section",
                        node_name=section_name,
                        node_title=section_title,
                        hierarchy_level=section_level,
                        docindex=docindex,
                        contentref=section_ref,
                    )
                )

                for item in item_rows:
                    if item.get("modulename", "") != module_name:
                        continue

                    if item.get("section", "") != section_name:
                        continue

                    if item.get("parentsection", "") != parent_section:
                        continue

                    l5_index += 1

                    item_name = item.get("name", "")
                    item_title = item.get("title", "")
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

                    item_node_id = f"{item_typecode}:{module_name}:{section_name}:{item_name}"
                    item_docindex = f"{docindex}.{l5_index}"

                    self.nav.append(
                        NavNode(
                            nodeid=item_node_id,
                            parentnodeid=node_id,
                            nodetype=item_type,
                            node_name=item_name,
                            node_title=item_title or item_name,
                            hierarchy_level=4,
                            docindex=item_docindex,
                            contentref=item_ref,
                            isinternal=item_visibility == "internal",
                            istemplate=item_role == "template",
                        )
                    )

    def build_content_index(self) -> None:
        rows = sorted(self.doc_content_lines, key=lambda r: row_sort_key(r, ["contentref", "doc_linenr"]))

        for row in rows:
            ref = row.get("contentref", "")
            self.content_by_ref[ref].append(row)

    # --------------------------------------------------------------------------
    # Rendering
    # --------------------------------------------------------------------------

    def render_assets(self) -> None:
        css_file = self.asset_dir / "doc.css"

        documentbody = self.config.get(
            "_docstyle_documentbody",
            "font-family:Arial, sans-serif;font-size:10pt;font-weight:normal;font-style:normal;line-height:1.45;margin:0 0 6px 0;",
        )
        documentheader = self.config.get(
            "_docstyle_documentheader",
            "font-family:Arial, sans-serif;font-size:18pt;font-weight:bold;font-style:normal;line-height:1.25;margin:0 0 14px 0;",
        )

        styles = {
            "moduleheader": self.config.get("_docstyle_moduleheader", "font-family:Arial, sans-serif;font-size:22pt;font-weight:bold;"),
            "modulebody": self.config.get("_docstyle_modulebody", documentbody),
            "L1Sectionheader": self.config.get("_docstyle_L1Sectionheader", "font-family:Arial, sans-serif;font-size:18pt;font-weight:bold;"),
            "L1Sectionbody": self.config.get("_docstyle_L1Sectionbody", documentbody),
            "L2Sectionheader": self.config.get("_docstyle_L2Sectionheader", "font-family:Arial, sans-serif;font-size:14pt;font-weight:bold;"),
            "L2Sectionbody": self.config.get("_docstyle_L2Sectionbody", documentbody),
            "L3Sectionheader": self.config.get("_docstyle_L3Sectionheader", "font-family:Arial, sans-serif;font-size:12pt;font-weight:bold;"),
            "L3Sectionbody": self.config.get("_docstyle_L3Sectionbody", documentbody),
            "functionheader": self.config.get("_docstyle_functionheader", "font-family:Arial, sans-serif;font-size:12pt;font-weight:bold;"),
            "functionbody": self.config.get("_docstyle_functionbody", documentbody),
            "variableheader": self.config.get("_docstyle_variableheader", "font-family:Arial, sans-serif;font-size:10pt;font-weight:bold;"),
            "variablebody": self.config.get("_docstyle_variablebody", documentbody),
            "gendocheader": self.config.get("_docstyle_gendocheader", "font-family:Arial, sans-serif;font-size:12pt;font-weight:bold;"),
            "gendocbody": self.config.get("_docstyle_gendocbody", documentbody),
            "documentbody": documentbody,
        }

        hint_styles = {
            "label": self.config.get("_docstyle_hint_label", "font-weight:bold;margin:8px 0 3px 0;"),
            "emphasis": self.config.get("_docstyle_hint_emphasis", "font-weight:bold;"),
            "quote": self.config.get("_docstyle_hint_quote", "font-style:italic;margin-left:18px;"),
            "listitem": self.config.get("_docstyle_hint_listitem", "margin-left:22px;"),
            "indent": self.config.get("_docstyle_hint_indent", "margin-left:22px;"),
        }

        css_lines = [
            "html, body {",
            "    margin: 0;",
            "    padding: 0;",
            "    height: 100%;",
            "    font-family: Arial, sans-serif;",
            "    color: #222;",
            "    background: #ffffff;",
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
            "    background: #f6f6f6;",
            "    overflow: auto;",
            "    padding: 36px 20px 14px 20px;",
            "}",
            "",
            ".doc-nav-title {",
            "    font-size: 12pt;",
            "    font-weight: bold;",
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
            "    font-weight: bold;",
            "    line-height: 1.25;",
            "}",
            "",
            ".doc-nav-module {",
            "    color: #111;",
            "    text-decoration: none;",
            "}",
            "",
            ".doc-nav-module:hover {",
            "    text-decoration: underline;",
            "}",
            "",
            ".doc-nav-node.level-0 > summary {",
            "    font-size: 11pt;",
            "    font-weight: bold;",
            "}",
            "",
            ".doc-nav-section {",
            "    display: block;",
            "    margin-top: 6px;",
            "    margin-bottom: 2px;",
            "    font-size: 10pt;",
            "    color: #111;",
            "    text-decoration: none;",
            "}",
            "",
            "a.doc-nav-section:hover {",
            "    text-decoration: underline;",
            "}",
            "",
            ".doc-nav-section.level-1 {",
            "    margin-left: 14px;",
            "    font-weight: 600;",
            "}",
            "",
            ".doc-nav-section.level-2 {",
            "    margin-left: 24px;",
            "    font-weight: 600;",
            "}",
            "",
            ".doc-nav-section.level-3 {",
            "    margin-left: 34px;",
            "    font-weight: 500;",
            "}",
            "",
            ".doc-nav-item {",
            "    display: block;",
            "    color: #204a87;",
            "    text-decoration: none;",
            "    font-size: 9.5pt;",
            "    line-height: 1.2;",
            "    margin-top: 2px;",
            "    margin-bottom: 2px;",
            "}",
            "",
            ".doc-nav-item:hover {",
            "    text-decoration: underline;",
            "}",
            "",
            ".doc-nav-item.level-4 {",
            "    margin-left: 42px;",
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
            ".doc-title {",
            f"    {documentheader}",
            "}",
            "",
            ".doc-breadcrumb {",
            "    font-style: italic;",
            "    color: #666;",
            "    font-size: 10pt;",
            "}",
            "",
        ]

        for content_type, style in styles.items():
            css_lines.append(f".ct-{content_type} {{ {style} }}")

        for style_hint, style in hint_styles.items():
            css_lines.append(f".sh-{style_hint} {{ {style} }}")

        css_lines.extend(
            [
                "",
                ".sh-listitem::before {",
                "    content: '\\2022 ';",
                "}",
                "",
            ]
        )

        css_file.write_text("\n".join(css_lines), encoding="utf-8")

    def render_index_page(self) -> None:
        first_page = self.get_first_item_page()
        index_file = self.output_dir / "index.html"

        html_lines = [
            "<!doctype html>",
            "<html>",
            "<head>",
            '  <meta charset="utf-8">',
            f"  <title>{esc(self.doc_title)}</title>",
            '  <link rel="stylesheet" href="assets/doc.css">',
            "</head>",
            "<body>",
            '<div class="doc-shell">',
            '<nav class="doc-nav">',
            '  <div class="doc-nav-title">Index by module</div>',
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
        module_open = False

        for node in self.nav:
            label = node.node_title or node.node_name
            current_level = node.hierarchy_level

            if current_level == 0:
                if module_open:
                    lines.append("</details>")

                href = page_href_from_contentref(node.contentref)
                lines.append('<details class="doc-nav-node level-0">')
                if node.contentref in self.content_by_ref:
                    lines.append(
                        f'<summary><a class="doc-nav-module" href="{esc(href)}" '
                        f'target="docframe">{esc(label)}</a></summary>'
                    )
                else:
                    lines.append(f"<summary>{esc(label)}</summary>")
                module_open = True
                continue

            href = page_href_from_contentref(node.contentref)

            if is_item_node(node.nodetype):
                type_class = slugify(node.nodetype)
                lines.append(
                    f'<a class="doc-nav-item level-{current_level} type-{type_class}" '
                    f'href="{esc(href)}" target="docframe">{esc(label)}</a>'
                )
            elif node.contentref in self.content_by_ref:
                lines.append(
                    f'<a class="doc-nav-section level-{current_level}" '
                    f'href="{esc(href)}" target="docframe">{esc(label)}</a>'
                )
            else:
                lines.append(
                    f'<div class="doc-nav-section level-{current_level}">{esc(label)}</div>'
                )

        if module_open:
            lines.append("</details>")

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

            self.render_item_page(node)
            rendered_refs.add(node.contentref)

        for ref, rows in self.content_by_ref.items():
            if ref in rendered_refs:
                continue

            self.render_content_page_for_ref(ref, rows)

    def render_item_page(self, node: NavNode) -> None:
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
        renderer = DocRenderer(input_dir, output_dir)
        renderer.run()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
