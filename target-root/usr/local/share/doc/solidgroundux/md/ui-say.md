# 16. ui-say.sh

[Back to index](index.md)

SolidgroundUX - UI Messaging
-------------------------------------------------------------------------------------
## 16.1 Description

Implements consistent message output helpers for console applications.
The library:
- Provides a unified message API via `say` and typed wrappers (info, ok, warn, etc.)
- Applies consistent formatting, prefixes, and optional colorization
- Supports console output control via verbosity, debug flags, and message-type filtering
- Ensures all messages follow a unified visual and structural style
- Optionally performs best-effort file logging when enabled
## 16.2 Design principles

- Consistent message semantics across all scripts
- Separation of message intent (type) from rendering and output policy
- Respect global verbosity, debug, and console filtering rules
- Keep output predictable and script-friendly
## 16.3 Role in framework

- Core messaging layer used by all SolidgroundUX scripts
- Serves as the primary mechanism for user-facing output and diagnostics
- Works alongside ui.sh for rendering and formatting
## 16.4 Non-goals

- Persistent logging frameworks or advanced log management
- Complex formatting beyond message-level styling
- Replacement for dedicated logging systems
## 16.5 Notes

- Console output is governed by:
SGND_LOG_TO_CONSOLE and SGND_CONSOLE_MSGTYPES
- DEBUG messages are controlled separately via FLAG_DEBUG
- File logging is optional and best-effort; failures do not affect execution
## 16.6 Library guard ------------------------------------------------------------------

## 16.7 Global defaults ----------------------------------------------------------------

## 16.8 Helpers ------------------------------------------------------------------------

## 16.9 Public API ---------------------------------------------------------------------

## 16.10 Declarations

## 16.11 Parse options

## 16.12 Resolve style tokens for this TYPE via maps (LBL_*, ICO_*, SYM_*, MSG_CLR_*)

## 16.13 Decode --show (supports "label,icon", "label+symbol", "all")

