# 5. prepare-release.sh

[Back to index](index.md)

SolidgroundUX - Prepare Release
-------------------------------------------------------------------------------------
## 5.1 Description

Provides a release-preparation utility for SolidgroundUX workspaces.
The script:
- Selects target scripts by file or folder
- Refreshes version, build, and checksum metadata unless source updates are disabled
- Applies optional major or minor version bumps
- Supports dry-run verification before committing changes
- Ensures release metadata is consistent across processed scripts
## 5.2 Design principles

- Release preparation is deterministic and repeatable
- Metadata updates are explicit and convention-based
- Safe verification is supported through dry-run mode
- Script formatting is preserved when updating field values
## 5.3 Role in framework

- Pre-release maintenance tool for framework and utility scripts
- Ensures release metadata is synchronized before distribution
## 5.4 Non-goals

- Packaging release artifacts
- Deploying files to target environments
- Managing version control, tagging, or publication workflows
## 5.5 Bootstrap -----------------------------------------------------------------------

## 5.6 Script metadata (identity) ------------------------------------------------------

## 5.7 Script metadata (framework integration) -----------------------------------------

## 5.8 Local script Declarations -------------------------------------------------------

## 5.9 Local script functions ----------------------------------------------------------

## 5.10 Ensure staging directory ----------------------------------------------

## 5.11 Stage clean copy -------------------------------------------------------

## 5.12 Build paths ------------------------------------------------------------

## 5.13 Create uncompressed tar -----------------------------------------------

## 5.14 Write uninstall manifest (external) ------------------------------------

## 5.15 Embed manifest into tar ------------------------------------------------

## 5.16 Compress to tar.gz -----------------------------------------------------

## 5.17 Update SHA256SUMS ------------------------------------------------------

## 5.18 Main Sequence -------------------------------------------------------------------

## 5.19 Bootstrap

## 5.20 Handle builtin arguments

## 5.21 UI

## 5.22 Main script logic

