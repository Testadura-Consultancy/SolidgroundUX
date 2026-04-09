# 31. ui.sh

[Back to index](index.md)

SolidgroundUX - UI Rendering
-------------------------------------------------------------------------------------
## 31.1 Description

Provides the core rendering layer for styled terminal output within
the SolidgroundUX framework.
The library:
- Defines reusable rendering helpers for text and layout
- Applies ANSI colors and text attributes through centralized helpers
- Renders labeled values, section headers, title bars, and filled lines
- Supports width-aware formatting for terminal output
- Provides standardized message and presentation conventions
## 31.2 Design principles

- Centralized styling without inline ANSI codes in consuming modules
- Readability over visual complexity
- Graceful degradation when styling is disabled or unavailable
- Consistent rendering semantics across all console tools
## 31.3 Role in framework

- Core visual layer for console-based SolidgroundUX tooling
- Supports higher-level interaction modules such as ui-ask and sgnd-console
## 31.4 Non-goals

- Input handling or dialog flow control
- Full terminal capability abstraction beyond framework needs
- Graphical or window-based user interface functionality
## 31.5 Library guard ------------------------------------------------------------------

## 31.6 Compatibility overrides --------------------------------------------------------

## 31.7 Helpers ------------------------------------------------------------------------

## 31.8 Public API ---------------------------------------------------------------------

## 31.9 Public helpers --------------------------------------------------------------

## 31.10 Theme loading ---------------------------------------------------------------

## 31.11 resolve palette/style -------------------------------------------------

## 31.12 load palette first, then style ---------------------------------------

## 31.13 Styling helpers -------------------------------------------------------------

## 31.14 Runmode indicators ----------------------------------------------------------

## 31.15 Rendering primitives --------------------------------------------------------

## 31.16 Parse options

## 31.17 Parse options (with positional fallback)

## 31.18 Defaults / safety

## 31.19 Render (colors applied last)

## 31.20 Parse options

## 31.21 Numeric safety

## 31.22 Parse options

## 31.23 Numeric safety

## 31.24 Assemble line (PLAIN parts first; add color last)

## 31.25 Parse options --------------------------------------------------------

## 31.26 Safety defaults ------------------------------------------------------

## 31.27 Available width for auto-wrap decision -------------------------------

## 31.28 Auto-wrap if not explicitly specified --------------------------------

## 31.29 Render ---------------------------------------------------------------

## 31.30 Resolve module prefix ----------------------------------------------------

## 31.31 Resolve variables --------------------------------------------------------

## 31.32 Output -------------------------------------------------------------------

## 31.33 Externals -------------------------------------------------------------------

## 31.34 Sample/demo renderers -------------------------------------------------------

