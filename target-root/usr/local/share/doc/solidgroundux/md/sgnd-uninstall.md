# 36. sgnd-uninstall.sh

[Back to index](index.md)

SolidgroundUX - Uninstall Installed Release
-------------------------------------------------------------------------------------
## 36.1 Description

Standalone uninstaller for SolidgroundUX installed release records.
The script:
- Reads installed release metadata from the target system
- Selects the current or a specific installed release
- Removes files and directories listed in the install manifest
- Restores backed-up files when a backup snapshot exists
- Moves uninstall records to a history directory
## 36.2 Design principles

- Standalone first: no framework bootstrap or library dependency
- Operates from install records stored on the target system
- Safe by default: restore backup after removal when available
- Explicit selection for manual or specific uninstall
## 36.3 Defaults ------------------------------------------------------------------------

## 36.4 Minimal UI ----------------------------------------------------------------------

