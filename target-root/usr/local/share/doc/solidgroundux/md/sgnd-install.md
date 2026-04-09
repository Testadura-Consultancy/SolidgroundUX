# 35. sgnd-install.sh

[Back to index](index.md)

SolidgroundUX - Install Release Package
-------------------------------------------------------------------------------------
## 35.1 Description

Standalone installer for SolidgroundUX release archives.
The script:
- Scans a releases directory for .tar.gz release archives
- Selects the newest matching release automatically by build number
- Optionally allows manual package selection
- Verifies archive and manifest checksum files before installation
- Backs up existing files and directories affected by the manifest
- Extracts the selected archive into a target root
- Writes install metadata and an install manifest to the target system
## 35.2 Design principles

- Standalone first: no framework bootstrap or library dependency
- Safe by default: verify and back up before extracting
- Deterministic automatic package selection
- Explicit manual override when desired
- Suitable for first-time framework installation
## 35.3 Defaults ------------------------------------------------------------------------

## 35.4 Minimal UI ----------------------------------------------------------------------

