# 25. sgnd-doc-writer.sh

[Back to index](index.md)

SolidGroundUX - Documentation Writer Library
-------------------------------------------------------------------------------------
## 25.1 Description

Provides the authoring and file-writing layer for the documentation generator.
## 25.2 Library guard -------------------------------------------------------------------

## 25.3 Internal helpers ----------------------------------------------------------------

### 25.3.1 Function: `_slugify_module_name()`

Returns:
Lowercase module basename without .sh, suitable for filenames.
### 25.3.2 Function: `_escape_html()`

Returns:
HTML-escaped text.
### 25.3.3 Function: `_compact_text()`

Purpose:
Normalize whitespace for compact paragraph rendering.
### 25.3.4 Function: `_append_output_line()`

### 25.3.5 Function: `_append_html_prolog()`

### 25.3.6 Function: `_append_html_epilog()`

### 25.3.7 Function: `_collect_header_summary()`

## 25.4 Authoring -----------------------------------------------------------------------

### 25.4.1 Function: `_author_index_md()`

### 25.4.2 Function: `_author_index_html()`

### 25.4.3 Function: `_author_header_summary_md()`

### 25.4.4 Function: `_author_header_summary_html()`

### 25.4.5 Function: `_author_module()`

## 25.5 Public API ----------------------------------------------------------------------

### 25.5.1 Function: `sgnd_doc_write_all()`

Purpose:
Render all documentation outputs and write them to disk.
Inputs (globals):
DOC_MODULES
DOC_SCAN_ROWS
DOC_OUTDIR
DOC_OUTPUT_SCHEMA
Outputs (globals):
DOC_OUTPUT_ROWS
### 25.5.2 Function: `_write_output_files()`

