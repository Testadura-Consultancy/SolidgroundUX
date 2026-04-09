# 34. lib-template.sh

[Back to index](index.md)

SolidgroundUX Library Template
----------------------------------------------------------------------------------
## 34.1 Description

Provides the standard structure for framework libraries, including:
- canonical script header sections
- library-only execution guard (must be sourced, never executed)
- idempotent load guard
- naming conventions for internal and public functions
- reference function header layout
## 34.2 Design principles

- Libraries define functions and constants only
- No auto-execution (must always be sourced)
- Keep behavior deterministic and side-effect aware
- Separate mechanism (library) from policy (caller)
## 34.3 Role in framework

- Base template for all SolidGroundUX library modules
- Defines structure, conventions, and documentation standards
## 34.4 Non-goals

- Executable scripts (use exe-template.sh)
- Application logic
- Framework bootstrap or path resolution
## 34.5 Library guard ------------------------------------------------------------------

## 34.6 Internal helpers -------------------------------------------------------------

## 34.7 Public API -------------------------------------------------------------------

