# 17. sgnd-core.sh

[Back to index](index.md)

SolidgroundUX - Core Utilities
-------------------------------------------------------------------------------------
## 17.1 Description

Contains the lowest-level generic helpers used throughout the SolidgroundUX
framework.
The library:
- Defines generic reusable helper functions
- Provides string, array, and low-level utility primitives
- Implements shared conventions and diagnostics helpers
- Avoids system-, UI-, and business-specific behavior where possible
## 17.2 Design principles

- Keep utilities generic and broadly reusable
- Avoid domain-specific logic in core helpers
- Prefer clarity and predictability over cleverness
- Minimize dependencies to keep the core lightweight
## 17.3 Role in framework

- Foundational layer used by nearly all other libraries
- Supports argument parsing, configuration, UI, and script logic
- Acts as the lowest-level shared functionality layer
## 17.4 Non-goals

- Business logic or application-specific behavior
- UI rendering or user interaction handling
- System administration and host/runtime operations (handled in sgnd-system)
- Configuration or state management (handled in dedicated modules)
## 17.5 Library guard ------------------------------------------------------------------

## 17.6 Requirement checks -------------------------------------------------------------

## 17.7 Filesystem helpers -------------------------------------------------------------

## 17.8 Argument & environment helpers -------------------------------------------------

## 17.9 Process & state helpers --------------------------------------------------------

### 17.9.1 Function: `sgnd_is_ui_mode()`

Purpose:
Determine whether the current execution context supports interactive UI.
Behavior:
- Honors explicit runmode flags when present
- Falls back to TTY detection
Returns:
0 if UI mode is active
1 otherwise
### 17.9.2 Function: `sgnd_is_desktop_mode()`

Purpose:
Detect whether a graphical desktop environment is available.
Behavior:
- Detects X11 or Wayland session
- Does not guarantee UI interactivity (separate concern)
Returns:
0 if desktop environment is available
1 otherwise
## 17.10 Version helpers ----------------------------------------------------------------

## 17.11 Misc utilities -----------------------------------------------------------------

## 17.12 Text functions -----------------------------------------------------------------

## 17.13 Validators ---------------------------------------------------------------------

