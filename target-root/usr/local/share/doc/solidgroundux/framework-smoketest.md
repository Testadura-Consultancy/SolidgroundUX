# framework-smoketest.sh

[Back to index](index.md)

SolidgroundUX — Framework smoke tester
----------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2609100
  Checksum    : 97fdc59a6f6aedf4ef09394e54d2c97b7b85eae2d19422d57768ec0f5e947528
  Source      : framework-smoketest.sh
  Type        : script
  Purpose     : Exercise and validate core SolidgroundUX framework functionality

## Description
  Standalone executable test harness for verifying foundational framework behavior.

  The script:
    - Locates and loads the SolidgroundUX bootstrap configuration
    - Loads the framework bootstrapper and common runtime services
    - Exercises argument parsing, state, config, UI, and messaging behavior
    - Provides manual test routines for ask-* interaction helpers
    - Serves as a smoke test for framework integration during development

## Design principles
  - Executable scripts explicitly bootstrap and opt into framework features
  - Libraries are sourced only and never auto-run
  - Test flow should stay simple, visible, and easy to extend
  - Framework integration issues should fail early and clearly

## Non-goals
  - Full automated regression testing
  - Fine-grained unit isolation for every library function
  - Replacement for dedicated shell test frameworks

## Attribution
  Developers  : Mark Fieten
  Company     : Testadura Consultancy
  Client      :
  Copyright   : © 2025 Mark Fieten — Testadura Consultancy
  License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
## Bootstrap -----------------------------------------------------------------------
## Script metadata (identity) ---------------------------------------------------
## Script metadata (framework integration) --------------------------------------
## Example: Arguments ----------------------------------------------
## Local script Declarations ----------------------------------------------------
## Local script functions -------------------------------------------------------
## Sample/demo renderers
## Main -------------------------------------------------------------------------
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
