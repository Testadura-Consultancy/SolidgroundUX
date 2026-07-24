# Changelog

All notable changes to SolidGroundUX are documented in this file.

The format is inspired by *Keep a Changelog* while remaining focused on practical framework development.

# Unreleased

# Version 1.8 (Build 2620423) 2026-07-23

## Resolved

- sgnd-install overwrites the ownership of root, /etc, /usr, etcetera
  - sgnd-install.sh to never overwrite metadata of existing folders in teh target tree
  - prepare-release.sh to set ownership of repository folders to root:root

## Changed

- added toggle button to sgnd-console to switch between root and non-root
- added left and right arrow for page navigation in sgnd-console

# Version 1.8 (Build 2620413) 2026-07-23

## Added

- Introduced the **SolidGroundUX Management Console**, a module-driven administration application built on the generic `sgnd-console` engine.
- Added ordered console-module loading through numeric filename prefixes, allowing the first module to define the console title and description.
- Added the `10-sgnd-config.sh` module for:
  - Developer tools
  - SolidGroundUX installation and maintenance
  - Framework configuration
  - Framework state
  - Framework logging
  - Framework diagnostics
- Added the `20-machine-config.sh` module for machine identity, package maintenance, template preparation, and optional server roles.
- Added direct bottom-bar controls for:
  - Dry-run or commit mode
  - Console log level
  - File log level
  - Active theme
  - Screen clearing
- Added reverse cycling for console log level, file log level, and theme using `Shift+C`, `Shift+F`, and `Shift+T`.
- Added framework configuration actions for viewing effective settings and editing system-wide and user-specific configuration files.
- Added framework logging actions for viewing, following, filtering, and rotating the active logfile.
- Added `sgnd-update.sh` to download the latest SolidGroundUX release from GitHub.
- Added public command wrappers for install, uninstall, and update operations.
- Added cached console menu models and cached page layouts to make redraws effectively immediate.

## Changed

- Redesigned `sgnd-console` as a reusable console engine rather than a SolidGroundUX-specific application.
- Moved the visible console identity from the host into the first successfully loaded module.
- Replaced implicit module discovery order with deterministic filename sorting.
- Reworked the console module contract around:
  - `SGND_MODULE_ID`
  - `SGND_MODULE_NAME`
  - `SGND_MODULE_VERSION`
  - `SGND_MODULE_DESC`
- Separated public commands from module-private helper scripts.
- Merged the former Developer Tools and Framework State modules into `10-sgnd-config.sh`.
- Moved SolidGroundUX installation actions into the SolidGroundUX configuration module.
- Renamed the `vm-config` module and helper directory to `machine-config`.
- Replaced the individual framework smoke-test menu entries with a single framework smoke-test command.
- Reused `framework-smoketest.sh --show env` as the effective framework configuration and environment overview.
- Updated console rendering to reuse cached datatable data instead of repeatedly querying and rebuilding menu structures.
- Updated console and module documentation for the new Management Console architecture.
- Made style sequence fixed so forward and back actually work

## Removed

- Removed the old `console-devtools.sh` module.
- Removed the old `console-framework-state.sh` module.
- Removed the old `vm-config.sh` module name and `vm-config/` helper directory.
- Removed the prompt-based console and file log-level selectors from the Console Session menu.
- Removed the prompt-based theme selector from the Console Session menu.
- Removed the individual in-process framework smoke-test menu actions.

---

# Version 1.7 (Build 2620012) 2026-07-19

## Removed
- Removed motd file,  but archaic and cumbersome, and doesn't really add any functionality

## Added
- Added images to documentation, do-generator now supports image tag in comments

---
# Version 1.7 (Build 2619600) - 2026-07-14

## Fixed
- sgnd-console didn't handle --appcfg well, corrected so it works as intended
- updated style files with SGND_UI_ON and SGND_UI_OFF

# Version 1.7 (Build 2619513) - 2026-07-14

## Added

- Added Appendix F to the generated documentation containing the framework license.
- Introduced persistent framework settings between sessions.
- Added persistent console session settings.
- Added interactive console customization for:
  - Theme selection
  - File log level
  - Menu lines per page

## Changed

- Reorganized `sgnd-console` and `sgnd-console-menu` into logical sections for improved maintainability.

## Fixed

- Framework settings are now correctly restored when scripts are started outside the console.
- Restored menu page height is now applied before the first console render.


---

# Version 1.6 (Build 2618912) - 2026-07-02

## Added

- Introduced configurable console log levels, including the new default **Silent** mode.
- Added extensive smoke tests for logging and progress bars.
- Added a framework styled MOTD.
- Introduced progress update intervals to improve performance.

## Changed

- Refactored executable bootstrap architecture by introducing `sgnd-exe-common.sh`.
- Redesigned the first-time installation process.
- Updated the installation guide and generated documentation.

## Fixed

- Prevented recursive backup of `/var` during installation.
- Corrected progress bar cursor positioning.
- Fixed multi-level progress bar rendering.
- Improved progress bar performance for large jobs.
- Corrected framework license acceptance recording.
- Fixed precedence of command-line log level over configuration.
- Corrected clean installation defaults and startup sequence.