# 20. sgnd-system.sh

[Back to index](index.md)

SolidgroundUX - System Utilities
-------------------------------------------------------------------------------------
## 20.1 Description

Contains environment-aware helpers that sit above sgnd-core.
The library:
- Provides root/sudo/runtime guards
- Exposes OS, network, and service-state helpers
- Includes ownership and permission normalization helpers
- Keeps operational/debug output close to procedural system actions
## 20.2 Design principles

- Keep system behavior out of sgnd-core
- Depend on framework bootstrap guarantees for minimal say* functions
- Prefer explicit operational helpers over mixing host logic into generic primitives
- Keep behavior predictable and side effects documented
## 20.3 Role in framework

- System/runtime layer above sgnd-core
- Used by installers, setup routines, and host-aware modules
- Centralizes platform and privilege helpers
## 20.4 Non-goals

- Business logic or application-specific behavior
- Interactive UI rendering or menu behavior
- Generic string/array/text helpers (handled in sgnd-core)
## 20.5 Library guard ------------------------------------------------------------------

## 20.6 Requirement checks -------------------------------------------------------------

## 20.7 Filesystem helpers -------------------------------------------------------------

## 20.8 System helpers -----------------------------------------------------------------

## 20.9 Error handlers -----------------------------------------------------------------

