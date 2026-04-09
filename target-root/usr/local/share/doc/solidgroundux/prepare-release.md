# prepare-release.sh

[Back to index](index.md)

SolidgroundUX - Prepare Release
-------------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2609100
  Checksum    : 3eb95e91721b977ee06150666997fa2466e96b405be4294ecd6e12a048acc583
  Source      : prepare-release.sh
  Type        : script
  Purpose     : Prepare framework scripts for release

## Description
  Provides a release-preparation utility for SolidgroundUX workspaces.

  The script:
    - Selects target scripts by file or folder
    - Refreshes version, build, and checksum metadata unless source updates are disabled
    - Applies optional major or minor version bumps
    - Supports dry-run verification before committing changes
    - Ensures release metadata is consistent across processed scripts

## Design principles
  - Release preparation is deterministic and repeatable
  - Metadata updates are explicit and convention-based
  - Safe verification is supported through dry-run mode
  - Script formatting is preserved when updating field values

## Role in framework
  - Pre-release maintenance tool for framework and utility scripts
  - Ensures release metadata is synchronized before distribution

## Non-goals
  - Packaging release artifacts
  - Deploying files to target environments
  - Managing version control, tagging, or publication workflows

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
## Local script functions ----------------------------------------------------------
## Ensure staging directory ----------------------------------------------
## Stage clean copy -------------------------------------------------------
## Build paths ------------------------------------------------------------
## Create uncompressed tar -----------------------------------------------
## Write uninstall manifest (external) ------------------------------------
## Embed manifest into tar ------------------------------------------------
## Compress to tar.gz -----------------------------------------------------
## Update SHA256SUMS ------------------------------------------------------
## Main Sequence -------------------------------------------------------------------
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
