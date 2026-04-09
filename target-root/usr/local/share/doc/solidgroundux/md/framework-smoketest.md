# 7. framework-smoketest.sh

[Back to index](index.md)

SolidgroundUX — Framework smoke tester
----------------------------------------------------------------------------------
## 7.1 Description

Standalone executable test harness for verifying foundational framework behavior.
The script:
- Locates and loads the SolidgroundUX bootstrap configuration
- Loads the framework bootstrapper and common runtime services
- Exercises argument parsing, state, config, UI, and messaging behavior
- Provides manual test routines for ask-* interaction helpers
- Serves as a smoke test for framework integration during development
## 7.2 Design principles

- Executable scripts explicitly bootstrap and opt into framework features
- Libraries are sourced only and never auto-run
- Test flow should stay simple, visible, and easy to extend
- Framework integration issues should fail early and clearly
## 7.3 Non-goals

- Full automated regression testing
- Fine-grained unit isolation for every library function
- Replacement for dedicated shell test frameworks
## 7.4 Bootstrap -----------------------------------------------------------------------

## 7.5 Script metadata (identity) ---------------------------------------------------

## 7.6 Script metadata (framework integration) --------------------------------------

## 7.7 Example: Arguments ----------------------------------------------

## 7.8 Local script Declarations ----------------------------------------------------

## 7.9 Local script functions -------------------------------------------------------

## 7.10 Sample/demo renderers

## 7.11 Main -------------------------------------------------------------------------

## 7.12 Bootstrap

## 7.13 Handle builtin arguments

## 7.14 UI

## 7.15 Main script logic

