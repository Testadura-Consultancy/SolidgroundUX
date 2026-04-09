# 26. ui-dlg.sh

[Back to index](index.md)

SolidgroundUX - UI Dialogs
-------------------------------------------------------------------------------------
## 26.1 Description

Implements dialog-oriented interaction patterns for console applications.
The library:
- Provides higher-level dialog constructs built on top of ui-ask
- Supports timed prompts with auto-continue behavior
- Normalizes user responses into consistent action tokens
- Enables structured interaction flows such as confirmations and selections
- Integrates with UI rendering for consistent look and feel
## 26.2 Design principles

- Build on top of primitive input helpers (ui-ask)
- Normalize interaction results for predictable scripting
- Keep dialogs lightweight and composable
- Support both interactive and semi-automated scenarios
## 26.3 Role in framework

- Intermediate interaction layer between raw input (ui-ask) and applications
- Used by scripts requiring structured or timed user decisions
## 26.4 Non-goals

- Full-screen or TUI-style dialog systems
- Complex workflow/state engines
- Persistent dialog sessions
## 26.5 Library guard ------------------------------------------------------------------

## 26.6 Internal helpers ------------------------------------------------------------------

## 26.7 Public API ---------------------------------------------------------------------

## 26.8 Helpers ---------------------------------------------------------------

## 26.9 Runtime state --------------------------------------------------------

