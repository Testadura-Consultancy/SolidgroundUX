# 30. sgnd-args.sh

[Back to index](index.md)

SolidgroundUX - Argument Parsing
-------------------------------------------------------------------------------------
## 30.1 Metadata:

Version : 1.1
Build : 2608203
Checksum : 8514965960d1becba4459cc212b011b1bd6e9b51a2d41a9570cba36ff0e9354d
Source : sgnd-args.sh
Type : library
Group : Common
Purpose : Parse and manage command-line arguments for scripts
## 30.2 Description

Provides a structured argument parsing system for SolidgroundUX scripts.
The library:
- Parses short and long command-line arguments
- Supports flags, values, and enumerated options
- Maps arguments to strongly defined variables
- Validates input against argument specifications
- Separates framework arguments from script-specific arguments
- Generates consistent help and usage output
## 30.3 Design principles

- Declarative argument specification via SGND_ARGS_SPEC
- Predictable and consistent parsing behavior across scripts
- Clear separation between parsing and business logic
- Minimal runtime surprises through validation and normalization
## 30.4 Role in framework

- Core infrastructure for all executable scripts
- Used during bootstrap to interpret command-line input
- Enables standardized CLI behavior across the framework
## 30.5 Non-goals

- Complex subcommand frameworks (e.g., git-style commands)
- Interactive input handling (handled by ui-ask/ui-dlg)
- Dynamic runtime argument schema mutation
## 30.6 Library guard ------------------------------------------------------------------

## 30.7 Helper functions ----------------------------------------------------------------

## 30.8 Public API ----------------------------------------------------------------------

