# doc-generator.sh

[Back to index](index.md)

SolidgroundUX - Documentation Generator
------------------------------------------------------------------------------------
## Metadata
  Version     : 1.0
  Build       : 2609100
  Checksum    : none
  Source      : doc-generator.sh
  Type        : script
  Purpose     : Generate documentation from source code comments using the sgnd-comment-parser library.

## Description

## Design principles

## Role in framework
## Non-goals

## Attribution
  Developers  : Mark Fieten
  Company     : Testadura Consultancy
  Client      : 
  Copyright   : © 2025 Mark Fieten — Testadura Consultancy
  License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
## Bootstrap -----------------------------------------------------------------------
## Script metadata (identity) ------------------------------------------------------
## Script metadata (framework integration) -----------------------------------------
### Variable: `SGND_USING`
Libraries to source from SGND_COMMON_LIB.
These are loaded automatically by sgnd_bootstrap AFTER core libraries.

Example:
  SGND_USING=( net.sh fs.sh )

Leave empty if no extra libs are needed.
## Example: Arguments
### Variable: `SGND_SCRIPT_EXAMPLES`
Optional: examples for --help output.
Each entry is a string that will be printed verbatim.

Example:
  SGND_SCRIPT_EXAMPLES=(
      "Example usage:"
      "  script.sh --verbose --mode fast"
      "  script.sh -v -m slow"
  )

Leave empty if no examples are needed.
### Variable: `SGND_SCRIPT_GLOBALS`
Explicit declaration of global variables intentionally used by this script.

Purpose:
  - Declares which globals are part of the script’s public/config contract.
  - Enables optional configuration loading when non-empty.

Behavior:
  - If this array is non-empty, sgnd_bootstrap enables config integration.
  - Variables listed here may be populated from configuration files.
  - Unlisted globals will NOT be auto-populated.

Use this to:
  - Document intentional globals
  - Prevent accidental namespace leakage
  - Make configuration behavior explicit and predictable

Only list:
  - Variables that must be globally accessible
  - Variables that may be defined in config files

Leave empty if:
  - The script does not use configuration-driven globals
### Variable: `SGND_STATE_VARIABLES`
List of variables participating in persistent state.

Purpose:
  - Declares which variables should be saved/restored when state is enabled.

Behavior:
  - Only used when sgnd_bootstrap is invoked with --state.
  - Variables listed here are serialized on exit (if SGND_STATE_SAVE=1).
  - On startup, previously saved values are restored before main logic runs.

Contract:
  - Variables must be simple scalars (no arrays/associatives unless explicitly supported).
  - Script remains fully functional when state is disabled.

Leave empty if:
  - The script does not use persistent state.
### Variable: `SGND_ON_EXIT_HANDLERS`
List of functions to be invoked on script termination.

Purpose:
  - Allows scripts to register cleanup or finalization hooks.

Behavior:
  - Functions listed here are executed during framework exit handling.
  - Execution order follows array order.
  - Handlers run regardless of normal exit or controlled termination.

Contract:
  - Functions must exist before exit occurs.
  - Handlers must not call exit directly.
  - Handlers should be idempotent (safe if executed once).

Typical uses:
  - Cleanup temporary files
  - Persist additional state
  - Release locks

Leave empty if:
  - No custom exit behavior is required.
## Local script Declarations -------------------------------------------------------
## Local helpers -------------------------------------------------------------------
### Function: `_is_header_separator()`
Returns:
  0 if LINE is a canonical header separator line.
  1 otherwise.

Usage:
  _is_header_separator "$line"
### Function: `_is_header_section_line()`
Returns:
  0 if LINE is a canonical header section line.
  1 otherwise.

Usage:
  _is_header_section_line "$line"
### Function: `_parse_header_section_line()`
Returns:
  Prints the parsed header section title to stdout.

Usage:
  _parse_header_section_line "$line"
### Function: `_is_section_line()`
### Function: `_get_section_level()`
### Function: `_parse_section_line()`
### Function: `_is_detail_comment_start()`
### Function: `_parse_detail_kind()`
### Function: `_parse_detail_name()`
### Function: `_detail_matches_declaration()`
### Function: `_normalize_comment_line()`
Remove leading comment marker and one optional following space.
## Local script functions ----------------------------------------------------------
### Function: `_resolve_parameters()`
Purpose:
  Resolve effective documentation generator input parameters from
  command-line values, existing globals, and interactive prompts.

Behavior:
  - Establishes effective values for source directory, optional
    single-file mode, filename mask, output directory, and recursive scan.
  - Prefers parsed command-line values when present.
  - Falls back to existing globals or framework defaults when needed.
  - Prompts the user interactively to review or modify the resolved values.
  - Converts the recursive scan answer into the numeric flag
    RECURSIVE_SCAN (1 or 0).
  - Repeats the prompt cycle when the user chooses redo.

Inputs (globals):
  VAL_SRCDIR
  VAL_FILE
  VAL_MASK
  VAL_OUTDIR
  FLAG_RECURSIVE_SCAN
  SGND_APPLICATION_ROOT
  SGND_DOCS_DIR

Outputs (globals):
  DOC_SOURCE
  DOC_FILE
  DOC_MASK
  DOC_OUTDIR
  RECURSIVE_SCAN

Returns:
  0 on success.
  1 if the user cancels or an unexpected dialog result occurs.

Notes:
  - When DOC_FILE is specified later in processing, it takes precedence
    over directory scanning.
  - DOC_MASK should default to "*.sh".
### Function: `_scan_file()`
Purpose:
  Scan one source file line by line and store normalized structural
  records in the documentation scan table.

Behavior:
  - Detects the canonical top-of-file header between the first two
    header separator lines and stores one row per inner header line.
  - Detects section marker lines in three levels:
      # --- major
      # --  minor
      # -   micro
  - Detects explicit detail comment blocks:
      # fn: <name>
      # var: <name>
  - Collects subsequent comment lines as detail text.
  - Confirms a detail block only when a matching declaration line is found:
      fn  -> <name>() {
      var -> <name>=...
  - Discards pending detail blocks that are interrupted by unrelated code
    or a new structural marker.

Arguments:
  $1  FILE
      Readable source file to scan.

Inputs (globals):
  DOC_SCAN_SCHEMA
  DOC_SCAN_ROWS

Returns:
  0 on success.
  1 on invalid input or append failure.
## Header ---------------------------------------------------------
## Section markers ------------------------------------------------
## Start detail block --------------------------------------------
## Continue / confirm / discard detail block ----------------------
### Function: `_list_modules()`
## Main ----------------------------------------------------------------------------
### Function: `main()`
Purpose:
  Canonical entry point for executable scripts.

Behavior:
  - Loads the framework bootstrapper.
  - Initializes runtime via sgnd_bootstrap.
  - Handles built-in framework arguments.
  - Prepares UI state (runmode + title bar).
  - Executes script-specific logic.

Arguments:
  $@  Command-line arguments (framework + script-specific).

Returns:
  Exits with the resulting status code from bootstrap or script logic.

Usage:
  main "$@"

Examples:
  # Standard script entrypoint
  main "$@"

Notes:
  - sgnd_bootstrap splits framework and script arguments automatically..
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
