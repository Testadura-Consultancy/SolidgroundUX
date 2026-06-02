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
    mod_attribution.psv
    doc_content_lines.psv
    render_config.psv

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
from typing import Dict, List, Sequence

RENDERER_BUILD = "20260602-1615-template-filter-bold-v5"

Row = Dict[str, str]
ATTRIBUTION_PREFIX = "appendix:attribution:"


def read_psv(path: Path, *, required: bool = True) -> List[Row]:
    """Read a pipe-separated table with a schema/header row."""
    if not path.exists():
        if required:
            raise FileNotFoundError(f"Missing input table: {path}")
        return []

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
    rows = read_psv(path, required=False)
    config: Dict[str, str] = {}

    for row in rows:
        key = row.get("key", "")
        value = row.get("value", "")
        if key:
            config[key] = value

    return config


def esc(value: str | None) -> str:
    return html.escape(value or "", quote=True)


def slugify(value: str | None) -> str:
    text = (value or "").lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")
    return text or "page"


def normalize_key(value: str | None) -> str:
    text = (value or "").lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = text.strip("_")
    return text


def content_ref(
    module_name: str,
    grandparent_section: str = "",
    parent_section: str = "",
    section_name: str = "",
    item_name: str = "",
) -> str:
    return f"{module_name}:{grandparent_section}:{parent_section}:{section_name}:{item_name}"


def attribution_ref(product_name: str) -> str:
    return f"{ATTRIBUTION_PREFIX}{product_name}"


def page_href_from_contentref(ref: str) -> str:
    return f"pages/{slugify(ref)}.html"


def is_item_node(node_type: str) -> bool:
    return node_type in {"function", "variable", "general documentation"}


def display_name_with_title(name: str, title: str) -> str:
    clean_name = name or ""
    clean_title = title or ""

    if clean_title and clean_title != clean_name:
        return f"{clean_name} - {clean_title}"

    return clean_name


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
        self.mod_attribution: List[Row] = []
        self.doc_content_lines: List[Row] = []
        self.config: Dict[str, str] = {}

        self.nav: List[NavNode] = []
        self.content_by_ref: Dict[str, List[Row]] = defaultdict(list)

        self.doc_title = ""
        self.doc_subtitle = ""
        self.doc_version = ""
        self.doc_product = ""
        self.doc_render_date = ""

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
        self.mod_attribution = read_psv(self.input_dir / "mod_attribution.psv", required=False)
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

    # ----------------------------------------------------------------------
    # Hierarchy construction
    # ----------------------------------------------------------------------

    def build_doc_hierarchy(self) -> None:
        self.nav = []

        section_rows = list(self.mod_sections)
        item_rows = list(self.mod_items)
        modules_by_product = self.modules_by_product()

        for product_index, product_name in enumerate(sorted(modules_by_product.keys(), key=str.casefold), start=1):
            product_node_id = f"product:{product_name}"
            product_docindex = str(product_index)
            product_modules = modules_by_product[product_name]

            self.nav.append(
                NavNode(
                    nodeid=product_node_id,
                    parentnodeid="root",
                    nodetype="product",
                    node_name=product_name,
                    node_title=product_name,
                    hierarchy_level=0,
                    docindex=product_docindex,
                    contentref="",
                )
            )

            product_specials, group_specials, normal_modules = self.split_special_comment_modules(
                product_name,
                product_modules,
            )

            sequence_index = 0

            for role in ("preface",):
                for module in product_specials.get(role, []):
                    sequence_index += 1
                    self.add_standalone_doc_node(
                        module=module,
                        parent_node_id=product_node_id,
                        hierarchy_level=1,
                        docindex=f"{product_docindex}.{sequence_index}",
                        fallback_name="Product Preface",
                        nodetype="preface",
                    )

            groups = sorted({module.get("group", "") or "Ungrouped" for module in normal_modules}, key=str.casefold)

            for group_name in groups:
                sequence_index += 1
                group_docindex = f"{product_docindex}.{sequence_index}"
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

                group_sequence_index = 0

                for module in group_specials.get(group_name, {}).get("preface", []):
                    group_sequence_index += 1
                    self.add_standalone_doc_node(
                        module=module,
                        parent_node_id=group_node_id,
                        hierarchy_level=2,
                        docindex=f"{group_docindex}.{group_sequence_index}",
                        fallback_name="Group Preface",
                        nodetype="preface",
                    )

                group_modules = sorted(
                    [module for module in normal_modules if (module.get("group", "") or "Ungrouped") == group_name],
                    key=lambda module: (
                        (module.get("name", "") or module.get("title", "")).casefold(),
                        module.get("title", "").casefold(),
                    ),
                )

                for module in group_modules:
                    group_sequence_index += 1
                    self.add_module_node(
                        module=module,
                        group_node_id=group_node_id,
                        module_docindex=f"{group_docindex}.{group_sequence_index}",
                        section_rows=section_rows,
                        item_rows=item_rows,
                    )

                for module in group_specials.get(group_name, {}).get("epilogue", []):
                    group_sequence_index += 1
                    self.add_standalone_doc_node(
                        module=module,
                        parent_node_id=group_node_id,
                        hierarchy_level=2,
                        docindex=f"{group_docindex}.{group_sequence_index}",
                        fallback_name="Group Epilogue",
                        nodetype="epilogue",
                    )

            for role in ("epilogue",):
                for module in product_specials.get(role, []):
                    sequence_index += 1
                    self.add_standalone_doc_node(
                        module=module,
                        parent_node_id=product_node_id,
                        hierarchy_level=1,
                        docindex=f"{product_docindex}.{sequence_index}",
                        fallback_name="Product Epilogue",
                        nodetype="epilogue",
                    )

            sequence_index += 1
            appendices_docindex = f"{product_docindex}.{sequence_index}"
            appendices_node_id = f"appendices:{product_name}"

            self.nav.append(
                NavNode(
                    nodeid=appendices_node_id,
                    parentnodeid=product_node_id,
                    nodetype="appendices",
                    node_name="Appendices",
                    node_title="Appendices",
                    hierarchy_level=1,
                    docindex=appendices_docindex,
                    contentref="",
                )
            )

            self.nav.append(
                NavNode(
                    nodeid=f"appendix:{product_name}:attribution",
                    parentnodeid=appendices_node_id,
                    nodetype="appendix",
                    node_name="Appendix A: Attribution",
                    node_title="Appendix A: Attribution",
                    hierarchy_level=2,
                    docindex=f"{appendices_docindex}.1",
                    contentref=attribution_ref(product_name),
                )
            )

    def modules_by_product(self) -> Dict[str, List[Row]]:
        result: Dict[str, List[Row]] = defaultdict(list)

        for module in self.mod_table:
            product_name = module.get("product", "") or self.doc_product or "Documentation"
            result[product_name].append(module)

        if not result:
            result[self.doc_product or "Documentation"] = []

        return result

    def split_special_comment_modules(
        self,
        product_name: str,
        modules: List[Row],
    ) -> tuple[Dict[str, List[Row]], Dict[str, Dict[str, List[Row]]], List[Row]]:
        product_specials: Dict[str, List[Row]] = {"preface": [], "epilogue": []}
        group_specials: Dict[str, Dict[str, List[Row]]] = defaultdict(lambda: {"preface": [], "epilogue": []})
        normal_modules: List[Row] = []

        product_key = normalize_key(product_name)

        for module in modules:
            module_name = module.get("name", "")
            module_key = normalize_key(Path(module_name).stem)
            group_name = module.get("group", "") or "Ungrouped"
            group_key = normalize_key(group_name)

            role = self.product_comment_role(module_key, product_key)
            if role:
                product_specials[role].append(module)
                continue

            role = self.group_comment_role(module_key, group_key)
            if role:
                group_specials[group_name][role].append(module)
                continue

            normal_modules.append(module)

        for rows in product_specials.values():
            rows.sort(key=lambda row: row.get("name", "").casefold())

        for group_rows in group_specials.values():
            for rows in group_rows.values():
                rows.sort(key=lambda row: row.get("name", "").casefold())

        return product_specials, group_specials, normal_modules

    def product_comment_role(self, module_key: str, product_key: str) -> str:
        pre_names = {
            f"{product_key}_pref_comment",
            f"{product_key}_pre_comment",
            f"{product_key}_preface",
            "product_pref_comment",
            "product_pre_comment",
            "product_preface",
            "doc_product_preface",
        }
        epilogue_names = {
            f"{product_key}_epilogue",
            "product_epilogue",
            "doc_product_epilogue",
        }

        if module_key in pre_names:
            return "preface"
        if module_key in epilogue_names:
            return "epilogue"
        return ""

    def group_comment_role(self, module_key: str, group_key: str) -> str:
        pre_names = {
            f"{group_key}_comment",
            f"{group_key}_pref_comment",
            f"{group_key}_pre_comment",
            f"{group_key}_preface",
            f"group_{group_key}_comment",
            f"group_{group_key}_pref_comment",
            f"group_{group_key}_preface",
        }
        epilogue_names = {
            f"{group_key}_epilogue",
            f"group_{group_key}_epilogue",
        }

        if module_key in pre_names:
            return "preface"
        if module_key in epilogue_names:
            return "epilogue"
        return ""

    def add_standalone_doc_node(
        self,
        module: Row,
        parent_node_id: str,
        hierarchy_level: int,
        docindex: str,
        fallback_name: str,
        nodetype: str = "documentation",
    ) -> None:
        module_name = module.get("name", "")
        module_title = module.get("title", "") or fallback_name or module_name
        module_ref = content_ref(module_name)

        self.nav.append(
            NavNode(
                nodeid=f"doc:{module_name}:{docindex}",
                parentnodeid=parent_node_id,
                nodetype=nodetype,
                node_name=module_title,
                node_title=module_title,
                hierarchy_level=hierarchy_level,
                docindex=docindex,
                contentref=module_ref,
            )
        )

    def is_template_group(self, module: Row) -> bool:
        return (module.get("group", "") or "").casefold() == "templates"

    def should_render_item(self, module: Row, item: Row) -> bool:
        if item.get("itemrole", "") == "template" and not self.is_template_group(module):
            return False
        return True

    def add_module_node(
        self,
        module: Row,
        group_node_id: str,
        module_docindex: str,
        section_rows: List[Row],
        item_rows: List[Row],
    ) -> None:
        module_name = module.get("name", "")
        module_title = module.get("title", "") or module_name
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

        module_sections = [section for section in section_rows if section.get("modulename", "") == module_name]
        module_items = [item for item in item_rows if item.get("modulename", "") == module_name]

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

            section_ref = content_ref(module_name, grandparent_section, parent_section, section_name, "")
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

            rendered_item_index = 0
            for item in section_items:
                if not self.should_render_item(module, item):
                    continue

                rendered_item_index += 1
                item_name = item.get("name", "")
                item_title = item.get("title", "") or item_name
                item_type = item.get("type", "")
                item_typecode = item.get("typecode", "item")
                item_visibility = item.get("itemvisibility", "")
                item_role = item.get("itemrole", "")

                item_ref = content_ref(module_name, grandparent_section, parent_section, section_name, item_name)
                item_node_id = f"{item_typecode}:{module_name}:{grandparent_section}:{parent_section}:{section_name}:{item_name}"
                item_docindex = f"{docindex}.{rendered_item_index}"

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
            key=lambda row: (
                row.get("file", "").casefold(),
                int(row.get("source_linenr", "0") or "0"),
                int(row.get("doc_linenr", "0") or "0"),
            ),
        )

        for row in rows:
            ref = row.get("contentref", "")
            self.content_by_ref[ref].append(row)

    # ----------------------------------------------------------------------
    # Rendering
    # ----------------------------------------------------------------------

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
            ".doc-nav-special,",
            ".doc-nav-special a,",
            ".doc-nav-special > summary,",
            ".type-product,",
            ".type-product a,",
            ".type-group,",
            ".type-group a,",
            ".type-group > summary,",
            ".type-appendices,",
            ".type-appendices a,",
            ".type-appendices > summary,",
            ".type-appendix,",
            ".type-appendix a,",
            ".type-preface,"
            ".type-preface a,",
            ".type-epilogue,",
            ".type-epilogue a {",
            "    font-weight: bold;",
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
            ".doc-attribution-meta {",
            "    display: grid;",
            "    grid-template-columns: max-content 1fr;",
            "    column-gap: 12px;",
            "    row-gap: 4px;",
            "}",
            "",
            ".doc-attribution-meta dt {",
            "    font-weight: bold;",
            "}",
            "",
            ".doc-attribution-meta dd {",
            "    margin: 0;",
            "}",
            "",
            ".doc-data-table {",
            "    border-collapse: collapse;",
            "    margin-top: 10px;",
            "    width: 100%;",
            "}",
            "",
            ".doc-data-table th,",
            ".doc-data-table td {",
            "    border: 1px solid #d0d0d0;",
            "    padding: 5px 7px;",
            "    text-align: left;",
            "    vertical-align: top;",
            "}",
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

.doc-nav-special,
.doc-nav-special a,
.doc-nav-special > summary,
.type-product,
.type-product a,
.type-group,
.type-group a,
.type-group > summary,
.type-appendices,
.type-appendices a,
.type-appendices > summary,
.type-appendix,
.type-appendix a,
.type-preface,
.type-preface a,
.type-epilogue,
.type-epilogue a {
    font-weight: bold;
}

.doc-title-page {
    max-width: 900px;
}

.doc-title-page-title {
    font-family: Arial, sans-serif;
    font-size: 28pt;
    font-weight: bold;
    line-height: 1.2;
    margin: 0 0 16px 0;
}

.doc-title-page-subtitle {
    font-size: 15pt;
    font-style: italic;
    margin: 0 0 18px 0;
}

.doc-title-page-meta {
    margin-top: 28px;
}

"""


    def title_from_rows(self, ref: str, fallback: str) -> str:
        for row in self.content_by_ref.get(ref, []):
            if row.get("suppress", "0") == "1":
                continue
            content_type = row.get("contenttype", "")
            if content_type.endswith("header"):
                return row.get("content", "") or fallback
        return fallback

    def render_title_page(self) -> None:
        output_file = self.page_dir / "title.html"
        output_file.parent.mkdir(parents=True, exist_ok=True)

        product = self.doc_product or "Documentation"
        subtitle = self.doc_subtitle or "Full Development Documentation"

        meta_lines = []
        if self.doc_version:
            meta_lines.append(f'<div class="ct-documentbody"><strong>Version:</strong> {esc(self.doc_version)}</div>')
        meta_lines.append(f'<div class="ct-documentbody"><strong>Generated:</strong> {esc(self.doc_render_date)}</div>')

        html_lines = [
            "<!doctype html>",
            "<html>",
            "<head>",
            '  <meta charset="utf-8">',
            f"  <title>{esc(self.doc_title)}</title>",
            '  <link rel="stylesheet" href="../assets/doc.css">',
            '  <link rel="stylesheet" href="../assets/theme.css">',
            "</head>",
            "<body>",
            '<main class="doc-page doc-title-page">',
            f'<h1 class="doc-title-page-title">{esc(self.doc_title)}</h1>',
            f'<div class="doc-title-page-subtitle">{esc(subtitle)}</div>',
            f'<div class="ct-documentbody">{esc(product)}</div>',
            '<div class="doc-title-page-meta">',
            *meta_lines,
            '</div>',
            "</main>",
            "</body>",
            "</html>",
        ]

        output_file.write_text("\n".join(html_lines), encoding="utf-8")

    def render_index_page(self) -> None:
        first_page = "pages/title.html"
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

    def has_renderable_page(self, ref: str) -> bool:
        return ref.startswith(ATTRIBUTION_PREFIX) or ref in self.content_by_ref

    def render_navigation(self) -> str:
        lines: List[str] = []
        open_detail_levels: List[int] = []
        container_types = {"group", "module", "appendices"}

        for node in self.nav:
            label = node.node_name
            current_level = node.hierarchy_level
            indent = current_level * 12
            special_nav_types = {"product", "group", "appendices", "appendix", "preface", "epilogue"}
            style = f"padding-left:{indent}px"
            href = page_href_from_contentref(node.contentref) if node.contentref else ""
            special_class = " doc-nav-special" if node.nodetype in special_nav_types else ""
            type_class = slugify(node.nodetype)

            while open_detail_levels and open_detail_levels[-1] >= current_level:
                lines.append("</details>")
                open_detail_levels.pop()

            if node.nodetype in container_types:
                lines.append(f'<details class="doc-nav-node level-{current_level} type-{type_class}{special_class}">')

                if node.contentref and self.has_renderable_page(node.contentref):
                    lines.append(
                        f'<summary style="{style}"><a class="doc-nav-module" href="{esc(href)}" '
                        f'target="docframe">{esc(label)}</a></summary>'
                    )
                else:
                    lines.append(f'<summary style="{style}">{esc(label)}</summary>')

                open_detail_levels.append(current_level)
                continue

            if is_item_node(node.nodetype):
                lines.append(
                    f'<a class="doc-nav-item type-{type_class}" style="{style}" '
                    f'href="{esc(href)}" target="docframe">{esc(label)}</a>'
                )

            elif self.has_renderable_page(node.contentref):
                lines.append(
                    f'<a class="doc-nav-section type-{type_class}{special_class}" style="{style}" '
                    f'href="{esc(href)}" target="docframe">{esc(label)}</a>'
                )

            else:
                lines.append(f'<div class="doc-nav-section type-{type_class}{special_class}" style="{style}">{esc(label)}</div>')

        while open_detail_levels:
            lines.append("</details>")
            open_detail_levels.pop()

        return "\n".join(lines)

    def get_first_item_page(self) -> str:
        for node in self.nav:
            if node.contentref and node.contentref in self.content_by_ref:
                return page_href_from_contentref(node.contentref)

        for node in self.nav:
            if node.contentref and node.contentref.startswith(ATTRIBUTION_PREFIX):
                return page_href_from_contentref(node.contentref)

        return "about:blank"

    def render_content_pages(self) -> None:
        rendered_refs: set[str] = set()

        self.render_title_page()

        for product_name in sorted(self.modules_by_product().keys(), key=str.casefold):
            self.render_attribution_page(product_name)

        for node in self.nav:
            if not node.contentref:
                continue
            if node.contentref.startswith(ATTRIBUTION_PREFIX):
                continue
            if node.contentref not in self.content_by_ref:
                continue

            self.render_content_page(node)
            rendered_refs.add(node.contentref)

        for ref, rows in self.content_by_ref.items():
            if ref in rendered_refs:
                continue
            self.render_content_page_for_ref(ref, rows)

    def render_attribution_page(self, product_name: str) -> None:
        ref = attribution_ref(product_name)
        href = page_href_from_contentref(ref)
        output_file = self.output_dir / href
        output_file.parent.mkdir(parents=True, exist_ok=True)

        body = self.render_attribution_body(product_name)

        html_lines = [
            "<!doctype html>",
            "<html>",
            "<head>",
            '  <meta charset="utf-8">',
            "  <title>Appendix A: Attribution</title>",
            '  <link rel="stylesheet" href="../assets/doc.css">',
            '  <link rel="stylesheet" href="../assets/theme.css">',
            "</head>",
            "<body>",
            '<main class="doc-page">',
            '<header class="doc-page-header">',
            '  <div class="doc-title">Appendix A: Attribution</div>',
            f'  <div class="doc-breadcrumb">{esc(product_name)} / Appendices / Appendix A: Attribution</div>',
            "</header>",
            body,
            "</main>",
            "</body>",
            "</html>",
        ]

        output_file.write_text("\n".join(html_lines), encoding="utf-8")

    def render_attribution_body(self, product_name: str) -> str:
        modules_by_name: Dict[str, Row] = {
            module.get("name", ""): module
            for module in self.mod_table
            if module.get("name", "")
        }

        grouped_rows: Dict[tuple[str, str, str, str], List[Row]] = defaultdict(list)

        for attribution in self.mod_attribution:
            module_name = attribution.get("modulename", "")
            module = modules_by_name.get(module_name, {})
            row_product = module.get("product", "") or self.doc_product or "Documentation"
            if row_product != product_name:
                continue

            merged: Row = dict(attribution)
            merged["group"] = module.get("group", "")
            merged["moduletitle"] = module.get("title", "")
            merged["moduleversion"] = module.get("version", "")

            key = (
                attribution.get("copyright", ""),
                attribution.get("company", ""),
                attribution.get("developers", ""),
                attribution.get("license", ""),
            )
            grouped_rows[key].append(merged)

        lines: List[str] = [
            '<h1 class="ct-L1Sectionheader">Appendix A: Attribution</h1>',
            '<div class="ct-documentbody">This appendix lists module attribution metadata collected from module headers.</div>',
        ]

        if not grouped_rows:
            lines.append('<div class="ct-documentbody">No attribution data was exported.</div>')
            return "\n".join(lines)

        for group_key in sorted(grouped_rows.keys(), key=lambda value: tuple(part.casefold() for part in value)):
            copyright_text, company, developers, license_text = group_key
            rows = sorted(
                grouped_rows[group_key],
                key=lambda row: (
                    row.get("group", "").casefold(),
                    row.get("modulename", "").casefold(),
                ),
            )

            lines.extend([
                '<section class="doc-attribution-block">',
                f'<h2 class="ct-L2Sectionheader">{esc(company or "Unspecified company")}</h2>',
                '<dl class="doc-attribution-meta">',
                f'<dt>Copyright</dt><dd>{esc(copyright_text or "-")}</dd>',
                f'<dt>Company</dt><dd>{esc(company or "-")}</dd>',
                f'<dt>Developers</dt><dd>{esc(developers or "-")}</dd>',
                f'<dt>License</dt><dd>{esc(license_text or "-")}</dd>',
                '</dl>',
                '<table class="doc-data-table">',
                '<thead><tr><th>Group</th><th>Module</th><th>Title</th><th>Version</th></tr></thead>',
                '<tbody>',
            ])

            for row in rows:
                lines.append(
                    "<tr>"
                    f'<td>{esc(row.get("group", ""))}</td>'
                    f'<td>{esc(row.get("modulename", ""))}</td>'
                    f'<td>{esc(row.get("moduletitle", ""))}</td>'
                    f'<td>{esc(row.get("moduleversion", ""))}</td>'
                    "</tr>"
                )

            lines.extend(['</tbody>', '</table>', '</section>'])

        return "\n".join(lines)

    def render_content_page(self, node: NavNode) -> None:
        href = page_href_from_contentref(node.contentref)
        output_file = self.output_dir / href
        output_file.parent.mkdir(parents=True, exist_ok=True)

        title = self.title_from_rows(node.contentref, node.node_title or node.node_name)
        breadcrumb = self.breadcrumb_from_contentref(node.contentref)
        body = self.render_content_for_ref(node.contentref, skip_first_header=True)

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
            f'  <div class="doc-title">{esc(title)}</div>',
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

        body = self.render_content_for_ref(ref, skip_first_header=True)

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
            f'  <div class="doc-title">{esc(title)}</div>',
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

    def render_content_for_ref(self, ref: str, skip_first_header: bool = False) -> str:
        lines: List[str] = []
        skipped_first_header = False

        for row in self.content_by_ref.get(ref, []):
            if row.get("suppress", "0") == "1":
                continue

            content_type = row.get("contenttype", "documentbody") or "documentbody"
            if skip_first_header and not skipped_first_header and content_type.endswith("header"):
                skipped_first_header = True
                continue
            style_hint = row.get("stylehint", "normal") or "normal"
            content = row.get("content", "")

            classes = [f"ct-{content_type}"]
            if style_hint != "normal":
                classes.append(f"sh-{style_hint}")

            css_class = " ".join(classes)
            lines.append(f'<div class="{esc(css_class)}">{esc(content)}</div>')

        return "\n".join(lines)


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
