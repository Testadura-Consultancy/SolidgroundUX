# metadata-editor.sh

[Back to index](index.md)

SolidgroundUX - Metadata Editor
-------------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2609100
  Checksum    : 65884ad57f319d8135ddafe3b0da3dbf86eb85d4cc17634dac5d97449757e7b6
  Source      : metadata-editor.sh
  Type        : script
  Purpose     : Inspect, edit, and version script metadata in a controlled workflow

## Description
  Provides an interactive and automated tool for managing script header metadata
  across SolidgroundUX workspaces.

  The script operates on one or more source files and allows:
    - Interactive editing of metadata fields (with validation and preview)
    - Controlled version bumping (build, minor, major)
    - Batch processing of multiple scripts with optional answer reuse (--idem)
    - Safe execution through dry-run simulation

  Metadata is treated as structured data and processed through the framework's
  datatable and comment-parser abstractions.

## Core capabilities
  - Discover source files via folder + mask or explicit file selection
  - Parse header sections into structured data tables
  - Present metadata in a readable, sectioned UI
  - Collect user input through aligned, validated prompts
  - Apply only actual changes (delta-based updates)
  - Maintain consistency of Version, Build, and Checksum fields

## Interaction model
  - Interactive mode:
      Guides the user through editing or versioning workflows
  - Auto mode (--auto):
      Applies direct updates without prompts
  - Version mode (--bump*):
      Updates version metadata deterministically

## Design principles
  - Metadata is treated as data, not text
  - Changes are explicit, minimal, and traceable
  - Interactive workflows remain predictable and reversible
  - Batch operations remain safe and transparent
  - UX consistency across all SolidgroundUX scripts

## Role in framework
  - Primary tool for maintaining script header integrity
  - Supports release preparation workflows
  - Acts as reference implementation for interactive CLI UX patterns

## Non-goals
  - Packaging or distributing artifacts
  - Version control operations (commit, tag, push)
  - Dependency or build management

## Attribution
  Developers  : Mark Fieten
  Company     : Testadura Consultancy
  Client      :
  Copyright   : © 2025 Mark Fieten — Testadura Consultancy
  License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
## Bootstrap -----------------------------------------------------------------------
## Script metadata (identity) ------------------------------------------------------
## Script metadata (framework integration) -----------------------------------------
## Local script Declarations -------------------------------------------------------
## Local UI ------------------------------------------------------------------------
## Local script functions ----------------------------------------------------------
## User input ----------------------------------------------------------------------
## Main ----------------------------------------------------------------------------
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
