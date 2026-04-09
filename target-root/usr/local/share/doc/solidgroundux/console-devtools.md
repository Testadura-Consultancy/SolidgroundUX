# console-devtools.sh

[Back to index](index.md)

SolidgroundUX — Developer Tools Console Module
----------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2609100
  Checksum    : e72edae0572cbf7d0d5ac7fd17357b54f972e5bdb7688e85be6154765a370dd6
  Source      : console-devtools.sh
  Type        : module
  Purpose     : sgnd-console module exposing developer tooling actions

## Description
  Provides a console module that registers developer-oriented actions in
  sgnd-console, allowing common tooling scripts to be launched from the
  interactive console host.

  The module currently exposes actions for:
    - creating a new workspace
    - deploying a workspace
    - preparing a release archive

## Design principles
  - Console modules are source-only plugin libraries
  - Functions are defined first, then registered explicitly
  - Registration is the only intended load-time side effect
  - Module actions delegate execution to the shared sgnd-console runtime

## Role in framework
  - Extends sgnd-console with developer workflow actions
  - Acts as a lightweight plugin layer on top of the console host
  - Uses _sgnd_run_script to execute related tooling scripts consistently

## Assumptions
  - Loaded by sgnd-console after framework bootstrap is complete
  - sgnd_console_register_group and sgnd_console_register_item are available
  - _sgnd_run_script is available in the host environment

## Non-goals
  - Standalone execution
  - Framework bootstrap or path resolution
  - Direct implementation of workspace/deploy/release logic

## Attribution
  Developers    : Mark Fieten
  Company       : Testadura Consultancy
  Client        : 
  Copyright     : © 2025 Mark Fieten — Testadura Consultancy
  License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
## Library guard ------------------------------------------------------------------
## Internal helpers -------------------------------------------------------------
## Public API -------------------------------------------------------------------
## Console registration --------------------------------------------------------
