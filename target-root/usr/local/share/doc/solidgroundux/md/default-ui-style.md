# 13. default-ui-style.sh

[Back to index](index.md)

SolidgroundUX - Default UI Style
-------------------------------------------------------------------------------------
## 13.1 Description

Provides the default layout and styling rules used by the SolidgroundUX UI layer.
The library:
- Defines spacing, padding, and alignment conventions
- Sets default widths for labels and columns
- Provides style constants for borders, separators, and layout elements
- Complements the color palette with structural presentation rules
- Ensures consistent visual composition across all console tools
## 13.2 Design principles

- Separate layout (style) from color (palette)
- Keep styling declarative and easy to override
- Favor readability and alignment over compactness
- Maintain consistency across all rendered output
## 13.3 Role in framework

- Structural styling layer used by ui.sh and related modules
- Works alongside default-ui-palette.sh to define the full UI theme
- Enables consistent layout behavior across scripts and tools
## 13.4 Non-goals

- Rendering logic or user interaction handling
- Terminal capability detection
- Dynamic layout adaptation beyond simple width awareness
## 13.5 Message type labels and icons ---------------------------------------------------

## 13.6 say() global defaults ---------------------------------------------------

## 13.7 Say prefixes -------------------------------------------------------------

## 13.8 Colors -------------------------------------------------------------------

