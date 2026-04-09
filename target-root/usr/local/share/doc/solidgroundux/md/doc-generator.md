# 2. doc-generator.sh

[Back to index](index.md)

SolidgroundUX - Documentation Generator
-------------------------------------------------------------------------------------
## 2.1 Description

## 2.2 Design principles

## 2.3 Role in framework

## 2.4 Non-goals

## 2.5 Bootstrap -----------------------------------------------------------------------

### 2.5.1 Function: `_framework_locator()`

Purpose:
Locate, create, and load the SolidGroundUX bootstrap configuration.
Behavior:
- Searches user and system bootstrap configuration locations.
- Prefers the invoking user's config over the system config.
- Creates a new bootstrap config when none exists.
- Prompts for framework/application roots in interactive mode.
- Applies default values when running non-interactively.
- Sources the selected configuration file.
Outputs (globals):
SGND_FRAMEWORK_ROOT
SGND_APPLICATION_ROOT
Returns:
0 success
126 configuration unreadable or invalid
127 configuration directory or file could not be created
Usage:
