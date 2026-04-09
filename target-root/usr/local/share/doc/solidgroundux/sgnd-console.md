# sgnd-console.sh

[Back to index](index.md)

SolidgroundUX - Console Host
-------------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2609100
  Checksum    : ef152f3d52e888d59e77f5896d311e27c29da8e55b7cd2b49de050601cb7ea9e
  Source      : sgnd-console.sh
  Type        : script
  Purpose     : Provide a modular console interface for SolidgroundUX tooling

## Description
  Provides a generic, modular console host that dynamically loads modules
  and presents their functionality through a structured menu interface.

  The script:
    - Loads console modules from a configured module directory
    - Allows modules to register menu items dynamically
    - Builds and renders interactive menus
    - Handles user input and dispatches actions
    - Supports navigation, paging, and toggle controls
    - Persists runtime flags such as debug, verbose, and dry-run

## Design principles
  - Modular architecture with clear separation of host and modules
  - Convention-based module registration
  - Minimal assumptions about module implementation
  - Consistent user interaction patterns across all tools

## Role in framework
  - Central entry point for interactive SolidgroundUX tooling
  - Hosts and orchestrates functionality provided by console modules

## Non-goals
  - Implementing business logic directly in the console host
  - Managing module-specific state beyond registration and dispatch
  - Providing a full TUI framework beyond structured menu interaction

## Attribution
  Developers  : Mark Fieten
  Company     : Testadura Consultancy
  Client      : 
  Copyright   : © 2025 Mark Fieten — Testadura Consultancy
  License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
## Bootstrap -----------------------------------------------------------------------
## Script metadata (identity) ------------------------------------------------------
## Script metadata (framework integration) -----------------------------------------
## Example: Arguments
## Local scripts and definitions ---------------------------------------------------
## Console state
## Module loading and registration 
## Script execution ----------------------------------------------------------------
## Console loop --------------------------------------------------------------------
## Public API ----------------------------------------------------------------------
## Main ----------------------------------------------------------------------------
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
