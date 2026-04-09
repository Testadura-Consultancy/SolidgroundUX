# 21. sgnd-comment-parser.sh

[Back to index](index.md)

SolidgroundUX - Comment Parser
-------------------------------------------------------------------------------------
## 21.1 Description

Provides parsing and update utilities for structured script header comments
used throughout the SolidgroundUX framework.
The library:
- Detects and reads canonical header sections
- Extracts field/value pairs from structured comment blocks
- Loads header data into sgnd-datatable structures
- Updates existing metadata field values while preserving formatting
- Adds missing fields where required
- Supports version, build, and checksum metadata workflows
## 21.2 Design principles

- Header comments are treated as structured, machine-readable data
- Parsing logic is independent from higher-level UI workflows
- Existing formatting is preserved when updating field values
- Header manipulation remains predictable and convention-based
## 21.3 Role in framework

- Core metadata parsing and update layer for script tooling
- Supports metadata-editor and other header-aware utilities
## 21.4 Non-goals

- Parsing arbitrary free-form comments outside canonical header sections
- Acting as a general-purpose text processing library
- Defining project policy beyond header comment conventions
## 21.5 Library guard ------------------------------------------------------------------

## 21.6 Public API ---------------------------------------------------------------------

