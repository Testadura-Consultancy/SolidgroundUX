# 4. console-devtools.sh

[Back to index](index.md)

SolidgroundUX — Developer Tools Console Module
----------------------------------------------------------------------------------
## 4.1 Description

Provides a console module that registers developer-oriented actions in
sgnd-console, allowing common tooling scripts to be launched from the
interactive console host.
The module currently exposes actions for:
- creating a new workspace
- deploying a workspace
- preparing a release archive
## 4.2 Design principles

- Console modules are source-only plugin libraries
- Functions are defined first, then registered explicitly
- Registration is the only intended load-time side effect
- Module actions delegate execution to the shared sgnd-console runtime
## 4.3 Role in framework

- Extends sgnd-console with developer workflow actions
- Acts as a lightweight plugin layer on top of the console host
- Uses _sgnd_run_script to execute related tooling scripts consistently
## 4.4 Assumptions

- Loaded by sgnd-console after framework bootstrap is complete
- sgnd_console_register_group and sgnd_console_register_item are available
- _sgnd_run_script is available in the host environment
## 4.5 Non-goals

- Standalone execution
- Framework bootstrap or path resolution
- Direct implementation of workspace/deploy/release logic
## 4.6 Library guard ------------------------------------------------------------------

## 4.7 Internal helpers -------------------------------------------------------------

## 4.8 Public API -------------------------------------------------------------------

## 4.9 Console registration --------------------------------------------------------

