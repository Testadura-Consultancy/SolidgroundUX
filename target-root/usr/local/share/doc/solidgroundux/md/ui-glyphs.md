# 29. ui-glyphs.sh

[Back to index](index.md)

SolidgroundUX - UI Glyphs
-------------------------------------------------------------------------------------
## 29.1 Description

Defines reusable glyphs, symbols, and character helpers for use in
console output across the SolidgroundUX framework.
The library:
- Provides box-drawing characters and layout elements
- Defines commonly used symbols (checkmarks, arrows, separators, etc.)
- Encapsulates Unicode and ASCII fallbacks where needed
- Supports consistent visual language across all UI components
## 29.2 Design principles

- Centralize glyph definitions to avoid duplication
- Prefer readability and consistency over decorative complexity
- Allow graceful fallback for terminals with limited Unicode support
- Keep rendering concerns separate from glyph definition
## 29.3 Role in framework

- Foundational visual layer used by ui.sh and related UI modules
- Supports consistent styling across all console tools
## 29.4 Non-goals

- Rendering logic or layout behavior
- Terminal capability detection beyond basic fallback handling
- Theme or color management
## 29.5 Library guard ------------------------------------------------------------------

## 29.6 Light line drawing ------------------------------------------------------------

## 29.7 Double line drawing -----------------------------------------------------------

## 29.8 Common characters -------------------------------------------------------------

## 29.9 Math / comparison -------------------------------------------------------------

## 29.10 Keyboard hints ----------------------------------------------------------------

## 29.11 Greek letters -----------------------------------------------------------------

