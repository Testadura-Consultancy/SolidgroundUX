# create-workspace.sh

[Back to index](index.md)

SolidgroundUX - Create Workspace
-------------------------------------------------------------------------------------
## Metadata
  Version     : 1.1
  Build       : 2609100
  Checksum    : c9f36b0ce0df57a7a2bdb4b5f871d33194fbb418920779a97cfd673f1121246c
  Source      : create-workspace.sh
  Type        : script
  Purpose     : Create a new development workspace from templates

## Description
  Provides a developer utility that scaffolds a new project workspace
  into a target directory using the framework's standard template layout.

  The script:
    - Resolves project name and target folder
    - Creates repository and target-root structure
    - Copies framework template files
    - Generates a VS Code workspace file
    - Generates a standard .gitignore

## Design principles
  - Workspace creation is deterministic and repeatable
  - Follows SolidgroundUX project conventions
  - Supports dry-run for all filesystem operations

## Role in framework
  - Entry point for initializing new development workspaces
  - Ensures consistent project structure across environments

## Non-goals
  - Deployment or installation of runtime environments
  - Managing existing workspaces beyond initial scaffolding

## Attribution
  Developers  : Mark Fieten
  Company     : Testadura Consultancy
  Client      : 
  Copyright   : © 2025 Mark Fieten — Testadura Consultancy
  License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
## Bootstrap -----------------------------------------------------------------------
## Bootstrap -----------------------------------------------------------------------
## Script metadata -----------------------------------------------------------------
## Script metadata (framework integration) -----------------------------------------
## local script functions ----------------------------------------------------------
## General helpers
## Manifest helpers
## Main sequence
## main ----------------------------------------------------------------------------
## Bootstrap
## Handle builtin arguments
## UI
## Main script logic
## Uncreate mode
## 'Normal' operation
