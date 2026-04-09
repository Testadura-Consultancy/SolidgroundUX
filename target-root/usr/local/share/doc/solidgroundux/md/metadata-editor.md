# 3. metadata-editor.sh

[Back to index](index.md)

SolidgroundUX - Metadata Editor
-------------------------------------------------------------------------------------
## 3.1 Description

Provides an interactive and automated tool for managing script header metadata
across SolidgroundUX workspaces.
The script operates on one or more source files and allows:
- Interactive editing of metadata fields (with validation and preview)
- Controlled version bumping (build, minor, major)
- Batch processing of multiple scripts with optional answer reuse (--idem)
- Safe execution through dry-run simulation
Metadata is treated as structured data and processed through the framework's
datatable and comment-parser abstractions.
## 3.2 Core capabilities

- Discover source files via folder + mask or explicit file selection
- Parse header sections into structured data tables
- Present metadata in a readable, sectioned UI
- Collect user input through aligned, validated prompts
- Apply only actual changes (delta-based updates)
- Maintain consistency of Version, Build, and Checksum fields
## 3.3 Interaction model

- Interactive mode:
Guides the user through editing or versioning workflows
- Auto mode (--auto):
Applies direct updates without prompts
- Version mode (--bump*):
Updates version metadata deterministically
## 3.4 Design principles

- Metadata is treated as data, not text
- Changes are explicit, minimal, and traceable
- Interactive workflows remain predictable and reversible
- Batch operations remain safe and transparent
- UX consistency across all SolidgroundUX scripts
## 3.5 Role in framework

- Primary tool for maintaining script header integrity
- Supports release preparation workflows
- Acts as reference implementation for interactive CLI UX patterns
## 3.6 Non-goals

- Packaging or distributing artifacts
- Version control operations (commit, tag, push)
- Dependency or build management
## 3.7 Bootstrap -----------------------------------------------------------------------

## 3.8 Script metadata (identity) ------------------------------------------------------

## 3.9 Script metadata (framework integration) -----------------------------------------

## 3.10 Local script Declarations -------------------------------------------------------

## 3.11 Local UI ------------------------------------------------------------------------

## 3.12 Local script functions ----------------------------------------------------------

## 3.13 User input ----------------------------------------------------------------------

## 3.14 Main ----------------------------------------------------------------------------

## 3.15 Bootstrap

## 3.16 Handle builtin arguments

## 3.17 UI

## 3.18 Main script logic

