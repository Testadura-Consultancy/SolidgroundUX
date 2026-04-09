# 28. sgnd-console-menu.sh

[Back to index](index.md)

SolidgroundUX - Console Menu System
-------------------------------------------------------------------------------------
## 28.1 Description

Implements the menu system used by sgnd-console for interactive navigation.
The library:
- Defines menu structures and item registration mechanisms
- Supports grouping, ordering, and labeling of menu items
- Integrates with rendering helpers to display menus consistently
- Handles user selection and dispatch to registered actions
- Enables modular extension by allowing external modules to register items
## 28.2 Design principles

- Modular menu composition through registration rather than hardcoding
- Clear separation between menu definition, rendering, and execution
- Predictable navigation and selection behavior
- Minimal coupling to specific applications or modules
## 28.3 Role in framework

- Core component of sgnd-console interactive tooling
- Bridges UI rendering, input handling, and executable scripts
- Enables pluggable console applications through module-based menus
## 28.4 Non-goals

- Full TUI frameworks or complex screen management
- Persistent menu state beyond runtime session
- Business logic execution beyond dispatching actions
## 28.5 Library guard ------------------------------------------------------------------

## 28.6 Label and status formatting -----------------------------------------------------

## 28.7 Builtin actions -----------------------------------------------------------------

## 28.8 Menu layout ---------------------------------------------------------------------

## 28.9 Menu rendering ------------------------------------------------------------------

## 28.10 Menu dispatch -------------------------------------------------------------------

