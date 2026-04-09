# 32. exe-template.sh

[Back to index](index.md)

SolidgroundUX - Executable Script Template
------------------------------------------------------------------------------------
## 32.1 Description

Provides the standard structure for all executable scripts in the framework,
including:
- bootstrap resolution and framework initialization
- optional argument parsing and configuration integration
- metadata declaration and lifecycle hooks
- a consistent main() entry pattern
## 32.2 Design principles

- Executables are explicit: resolve, bootstrap, then run
- Libraries never auto-execute (composition over inheritance)
- Framework integration is opt-in and declarative
- UI and input must be TTY-safe
## 32.3 Role in framework

- Entry point pattern for all SolidGroundUX-based scripts
- Defines how scripts integrate with td-bootstrap and common libraries
## 32.4 Non-goals

- Business logic implementation (provided by the script author)
- Library behavior (handled in /common modules)
## 32.5 Bootstrap -----------------------------------------------------------------------

## 32.6 Script metadata (identity) ------------------------------------------------------

## 32.7 Script metadata (framework integration) -----------------------------------------

## 32.8 Example: Arguments

## 32.9 Local script Declarations -------------------------------------------------------

## 32.10 Local script functions ----------------------------------------------------------

## 32.11 Main ----------------------------------------------------------------------------

## 32.12 Bootstrap

## 32.13 Handle builtin arguments

## 32.14 UI

## 32.15 Main script logic

