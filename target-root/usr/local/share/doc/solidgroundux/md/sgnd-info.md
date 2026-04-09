# 24. sgnd-info.sh

[Back to index](index.md)

SolidgroundUX - Framework Information
-------------------------------------------------------------------------------------
## 24.1 Description

Exposes information about the SolidgroundUX framework and runtime environment.
The library:
- Provides access to framework identity (name, version, paths)
- Exposes resolved bootstrap values such as SGND_FRAMEWORK_ROOT and SGND_APPLICATION_ROOT
- Supplies helper functions for displaying framework and environment details
- Supports diagnostics, logging, and informational output
## 24.2 Design principles

- Keep information access centralized and consistent
- Avoid duplication of framework identity data across modules
- Ensure values reflect the active runtime environment
- Keep implementation lightweight and dependency-free where possible
## 24.3 Role in framework

- Provides introspection capabilities for scripts and tools
- Supports diagnostics, debugging, and informational commands
- Complements bootstrap and configuration modules
## 24.4 Non-goals

- Configuration management (handled by cfg.sh)
- Argument parsing or user interaction
- Persistent state tracking
## 24.5 Library guard ------------------------------------------------------------------

## 24.6 Internal helpers ----------------------------------------------------------------

## 24.7 Public API ----------------------------------------------------------------------

