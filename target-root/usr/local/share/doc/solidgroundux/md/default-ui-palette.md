# 15. default-ui-palette.sh

[Back to index](index.md)

SolidgroundUX - Default UI Palette
-------------------------------------------------------------------------------------
## 15.1 Description

Provides the default color and style definitions used by the
SolidgroundUX UI layer.
The library:
- Defines ANSI color variables for labels, input, and message types
- Establishes consistent visual identity across console tools
- Supplies defaults for UI modules such as ui.sh, ui-ask, and ui-say
- Allows overriding by alternative palettes or user configuration
## 15.2 Design principles

- Centralize all color definitions in one place
- Keep naming semantic (INFO, WARN, LABEL, INPUT, etc.)
- Allow easy customization without touching rendering logic
- Ensure readability across common terminal backgrounds
## 15.3 Role in framework

- Default styling layer for all console rendering
- Used by UI modules to apply consistent colors and emphasis
- Can be replaced or extended for theming purposes
## 15.4 Non-goals

- Rendering logic or layout behavior
- Terminal capability detection
- Dynamic theme switching at runtime
## 15.5 Text attributes (SGR) -----------------------------------------------------------

## 15.6 Color codes ---------------------------------------------------------------------

## 15.7 Foreground colors ---------------------------------------------------------------

## 15.8 Foreground: Dark / muted --------------------------------------------------------

## 15.9 Foreground: Normal --------------------------------------------------------------

## 15.10 Foreground: Bright --------------------------------------------------------------

## 15.11 Background colors ---------------------------------------------------------------

## 15.12 Background: Dark / muted --------------------------------------------------------

## 15.13 Background: Normal --------------------------------------------------------------

## 15.14 Background: Bright --------------------------------------------------------------

