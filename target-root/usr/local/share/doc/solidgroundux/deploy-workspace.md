# deploy-workspace.sh

[Back to index](index.md)

SolidgroundUX - Deploy Workspace
-------------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2608700
  Checksum    : a2d4f9ae263c8a47930125f935dbb66f6632e2d58db07f1e502d9761be267a7e
  Source      : deploy-workspace.sh
  Type        : script
  Purpose     : Deploy or remove a development workspace to or from a target root

## Description
  Provides a deployment utility that synchronizes a structured workspace
  into a target filesystem root.

  The script:
    - Copies files from source to target while preserving structure
    - Creates destination directories as required
    - Applies permission policy based on PERMISSION_RULES
    - Skips private, hidden, and non-deployable files by convention
    - Records created files and directories in a deploy manifest
    - Supports manifest-based undeploy operations

## Design principles
  - Deployment behavior is explicit and predictable
  - Only created artifacts are tracked for undeploy
  - Honors dry-run, verbose, and debug run modes
  - Avoids destructive rollback behavior outside recorded manifests

## Role in framework
  - Entry point for deploying prepared workspaces into target roots
  - Supports controlled install and removal workflows for SolidgroundUX assets

## Non-goals
  - Full rollback of all modified target files
  - Generic backup or restore functionality
  - Arbitrary synchronization outside the workspace deployment model

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

IMPORTANT:
  - If this array is non-empty, sgnd_bootstrap will enable config loading.
  - Variables listed here may be populated from configuration files.
  - This makes SGND_SCRIPT_GLOBALS part of the script’s configuration contract.

Use this to:
  - Document intentional globals
  - Prevent accidental namespace leakage
  - Enable cfg integration in a predictable way

Only list:
  - Variables that are meant to be globally accessible
  - Variables that may be set via config files

Leave empty if:
  - The script does not use config-driven globals

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
## local script functions ----------------------------------------------------------tree
## Manifests
## Main sequence  
### Function: `_perm_resolve()`
Purpose:
  Resolve the effective permission mode for a given path based on PERMISSION_RULES.

Arguments:
  $1  abs_rel   Absolute path relative to root (e.g. "/usr/local/bin/foo")
  $2  kind      "file" or "dir"

Behavior:
  - Applies longest-prefix match against PERMISSION_RULES
  - Returns file_mode or dir_mode depending on kind
  - Falls back to defaults when no rule matches

Output:
  Prints the resolved mode to stdout (no newline)

Returns:
  0 always

Defaults:
  file → 644
  dir  → 755

Usage:
  mode="$(_perm_resolve "/usr/local/bin/foo" "file")"

Examples:
  dir_mode="$(_perm_resolve "/usr/local/bin" "dir")"
### Function: `_update_lastdeployinfo()`
Purpose:
  Persist metadata of the last deployment run for reuse (e.g. auto mode).

Behavior:
  - Stores timestamp, source, and target in state for later reuse
  - Skips writes when FLAG_DRYRUN is enabled

Writes:
  last_deploy_run
  last_deploy_source
  last_deploy_target

Inputs (globals):
  SRC_ROOT
  DEST_ROOT
  FLAG_DRYRUN

Returns:
  0 on success

Usage:
  _update_lastdeployinfo
### Function: `_getparameters()`
Purpose:
  Collect deployment parameters (source and target roots).

Behavior:
  - Auto mode:
      Uses last deployment settings when available
  - Interactive mode:
      Prompts for SRC_ROOT and DEST_ROOT
      Validates SRC_ROOT structure (advisory only)
      Asks for confirmation (OK/Redo/Quit)

Validation:
  - SRC_ROOT is considered valid if it contains "etc/" or "usr/"
  - Validation is advisory only (does not block execution)

Outputs (globals):
  SRC_ROOT
  DEST_ROOT

Returns:
  0 → confirmed
  1 → aborted

Usage:
  _getparameters ; return $?

Notes:
  - Uses ask and ask_ok_redo_quit
## Auto mode --------------------------------------------------------------
## Interactive mode -------------------------------------------------------
## Source root --------------------------------------------------------
## Target root --------------------------------------------------------
### Function: `_deploy()`
Purpose:
  Deploy workspace files from SRC_ROOT into DEST_ROOT.

Behavior:
  - Recursively processes files under SRC_ROOT
  - Computes relative path and destination path
  - Skips:
      - top-level files
      - "_" prefixed files
      - ".old" files
      - hidden or "_" directories

Update logic:
  - Installs when destination is missing or source is newer

Manifest behavior:
  - Initializes a new manifest at start of deployment
  - Records only files CREATED by this run
  - Records only directories CREATED by this run
  - Updated pre-existing files are not recorded
  - Finalizes manifest only after successful completion

Permissions:
  - File mode via _perm_resolve(abs_rel,"file")
  - Directory mode via _perm_resolve(abs_rel,"dir")

Dry run:
  - When FLAG_DRYRUN=1, only reports actions

Inputs (globals):
  SRC_ROOT
  DEST_ROOT
  FLAG_DRYRUN
  PERMISSION_RULES

Returns:
  0 on success
  1 on fatal deployment/manifest failure

Usage:
  _deploy

Notes:
  - Uses install for atomic writes and permission control
  - Manifest records created artifacts only; it is not full rollback state
### Function: `_undeploy()`
Purpose:
  Remove previously deployed files and directories using a manifest.

Behavior:
  - Resolves a manifest for the current SRC_ROOT
  - Uses MANIFEST_NAME when provided
  - Otherwise uses the latest manifest for the source root
  - Removes recorded files first
  - Removes recorded directories afterward in reverse-depth order

Manifest rules:
  - Only files recorded as created by deploy are removed
  - Only directories recorded as created by deploy are considered
  - Directories are removed only if empty

Dry run:
  - When FLAG_DRYRUN=1, only reports actions

Inputs (globals):
  SRC_ROOT
  DEST_ROOT
  MANIFEST_NAME
  FLAG_DRYRUN

Returns:
  0 on success
  1 if manifest resolution fails

Usage:
  _undeploy

Notes:
  - This is a manifest-based inverse of created artifacts only
  - Updated pre-existing files are not restored or removed
## Main ----------------------------------------------------------------------------
### Function: `main()`
Purpose:
  Execute the workspace deployment workflow.

Behavior:
  - Loads and initializes the framework bootstrap
  - Handles builtin arguments
  - Displays title bar
  - Collects parameters
  - Executes deploy or undeploy
  - Persists deployment metadata

Arguments:
  $@  Framework and script-specific arguments

Returns:
  Exit status from executed operations

Usage:
  main "$@"
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
## Deploy or undeploy                    
