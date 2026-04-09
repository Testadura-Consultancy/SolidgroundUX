# 33. mod-template.sh

[Back to index](index.md)

SolidgroundUX Console Module Template
----------------------------------------------------------------------------------
## 33.1 Description

Provides the standard structure for modules that extend sgnd-console with:
- one or more menu groups
- one or more registered menu actions
- optional internal helper functions
Console modules are source-only plugin libraries. Their only intended
load-time side effect is self-registration with sgnd-console.
## 33.2 Design principles

- Modules define functions first, then register themselves explicitly
- Registration is data-driven through sgnd_console_register_group/item
- Keep module logic local and menu-facing
- Avoid framework-wide policy decisions inside modules
## 33.3 Role in framework

- Extends sgnd-console with domain-specific actions and menu entries
- Acts as a lightweight plugin layer on top of the console host
- May depend on framework and sgnd-console primitives already being loaded
## 33.4 Assumptions

- Loaded by sgnd-console after framework bootstrap is complete
- sgnd_console_register_group and sgnd_console_register_item are available
- Framework helpers such as say* and sgnd_print_* may be used
## 33.5 Non-goals

- Standalone execution
- Bootstrap, path resolution, or framework initialization
- Full-screen UI behavior outside the sgnd-console host
## 33.6 Library guard ------------------------------------------------------------------

## 33.7 Internal helpers -------------------------------------------------------------

## 33.8 Public module actions --------------------------------------------------------

## 33.9 Console registration ---------------------------------------------------------

