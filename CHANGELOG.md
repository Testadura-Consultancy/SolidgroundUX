# Changelog

All notable changes to SolidGroundUX are documented in this file.

The format is inspired by *Keep a Changelog* while remaining focused on practical framework development.
# Unreleased

# Version 1.7 (Build 2620012) 2026-07-19

## Removed
- Removed motd file,  but archaic and cumbersome, and doesn't really add any functionality
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