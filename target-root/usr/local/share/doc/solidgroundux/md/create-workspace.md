# 6. create-workspace.sh

[Back to index](index.md)

SolidgroundUX - Create Workspace
-------------------------------------------------------------------------------------
## 6.1 Description

Provides a developer utility that scaffolds a new project workspace
into a target directory using the framework's standard template layout.
The script:
- Resolves project name and target folder
- Creates repository and target-root structure
- Copies framework template files
- Generates a VS Code workspace file
- Generates a standard .gitignore
## 6.2 Design principles

- Workspace creation is deterministic and repeatable
- Follows SolidgroundUX project conventions
- Supports dry-run for all filesystem operations
## 6.3 Role in framework

- Entry point for initializing new development workspaces
- Ensures consistent project structure across environments
## 6.4 Non-goals

- Deployment or installation of runtime environments
- Managing existing workspaces beyond initial scaffolding
## 6.5 Bootstrap -----------------------------------------------------------------------

## 6.6 Bootstrap -----------------------------------------------------------------------

## 6.7 Script metadata -----------------------------------------------------------------

## 6.8 Script metadata (framework integration) -----------------------------------------

## 6.9 local script functions ----------------------------------------------------------

## 6.10 General helpers

## 6.11 Manifest helpers

## 6.12 Main sequence

## 6.13 main ----------------------------------------------------------------------------

## 6.14 Bootstrap

## 6.15 Handle builtin arguments

## 6.16 UI

## 6.17 Main script logic

## 6.18 Uncreate mode

## 6.19 'Normal' operation

