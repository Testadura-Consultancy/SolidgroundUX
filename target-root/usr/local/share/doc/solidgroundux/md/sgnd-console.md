# 1. sgnd-console.sh

[Back to index](index.md)

SolidgroundUX - Console Host
-------------------------------------------------------------------------------------
## 1.1 Description

Provides a generic, modular console host that dynamically loads modules
and presents their functionality through a structured menu interface.
The script:
- Loads console modules from a configured module directory
- Allows modules to register menu items dynamically
- Builds and renders interactive menus
- Handles user input and dispatches actions
- Supports navigation, paging, and toggle controls
- Persists runtime flags such as debug, verbose, and dry-run
## 1.2 Design principles

- Modular architecture with clear separation of host and modules
- Convention-based module registration
- Minimal assumptions about module implementation
- Consistent user interaction patterns across all tools
## 1.3 Role in framework

- Central entry point for interactive SolidgroundUX tooling
- Hosts and orchestrates functionality provided by console modules
## 1.4 Non-goals

- Implementing business logic directly in the console host
- Managing module-specific state beyond registration and dispatch
- Providing a full TUI framework beyond structured menu interaction
## 1.5 Bootstrap -----------------------------------------------------------------------

## 1.6 Script metadata (identity) ------------------------------------------------------

## 1.7 Script metadata (framework integration) -----------------------------------------

## 1.8 Example: Arguments

## 1.9 Local scripts and definitions ---------------------------------------------------

## 1.10 Console state

## 1.11 Module loading and registration 

## 1.12 Script execution ----------------------------------------------------------------

## 1.13 Console loop --------------------------------------------------------------------

## 1.14 Public API ----------------------------------------------------------------------

## 1.15 Main ----------------------------------------------------------------------------

## 1.16 Bootstrap

## 1.17 Handle builtin arguments

## 1.18 UI

## 1.19 Main script logic

