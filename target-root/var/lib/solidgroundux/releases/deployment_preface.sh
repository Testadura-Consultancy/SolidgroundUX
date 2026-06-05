# ==================================================================================
# SolidGroundUX - Deployment and update 
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : deployment_preface.sh
#   Type        : documentation
#   Group       : Deployment
#   Purpose     : Group preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - Deployment ----------------------------------------------------------------------
#
# > The Deployment group contains the installer and uninstaller scripts used to place
# > SolidGroundUX release packages onto a target system and remove them again when
# > needed.
#
# > These scripts are framework-adjacent rather than part of the runtime framework
# > itself. The framework provides the libraries, tools, templates, console host,
# > and documentation system. The deployment scripts are responsible for getting
# > those files onto a machine in the expected locations.
#
# > In other words, SolidGroundUX does not need the installer in order to run once
# > it is installed, but the installer provides the supported path from release
# > archive to deployed filesystem layout.
#
# -- Relationship to Release Preparation --------------------------------------------
#
# > Deployment has a close relationship with release preparation.
#
# > The prepare-release tool creates the release artifacts that the installer is
# > expected to consume. This normally includes a packaged target-root layout,
# > release metadata, version information, checksums, and any supporting files
# > needed to validate or install the release.
#
# > The installer should therefore be understood as the consumer of the prepared
# > release package, not as the tool that builds the release itself.
#
# -- Typical Installation Workflow --------------------------------------------------
#
# > A typical installation starts with a prepared release archive.
#
# > Conceptually, the workflow is:
#
# >     Download release archive
# >         ↓
# >     Extract or make the installer available
# >         ↓
# >     Run sgnd-install.sh
# >         ↓
# >     Installer reads release metadata
# >         ↓
# >     Installer evaluates current installed version
# >         ↓
# >     Installer determines whether this is a fresh install, update, downgrade,
# >     reinstall, or no-op
# >         ↓
# >     Installer copies files into the target filesystem layout
# >         ↓
# >     Installer applies permissions and executable flags
# >         ↓
# >     Installer records or reports the installed result
#
# > The exact installation behavior may depend on command-line options and the
# > metadata available in the release package.
#
# -- Fresh Installs and Updates ------------------------------------------------------
#
# > During installation, the installer compares the package being installed with
# > the version or metadata already present on the target system.
#
# > If no compatible installation is found, the operation is treated as a fresh
# > install.
#
# > If an older installed version is found, the operation may be treated as an
# > update.
#
# > If the same version is already installed, the installer can avoid unnecessary
# > work unless a forced reinstall is requested.
#
# > If the target system appears to contain a newer version than the package being
# > installed, the installer should treat the situation carefully and avoid an
# > accidental downgrade unless explicitly instructed.
#
# > This version-aware behavior is what allows release archives to be used for both
# > first-time installation and controlled updates.
#
# -- Target Filesystem Layout -------------------------------------------------------
#
# > Installation places files into the expected SolidGroundUX filesystem layout.
#
# > User-facing commands are installed into executable locations such as bin or
# > sbin.
#
# > Reusable libraries are installed below the framework library location.
#
# > Internal implementation scripts are installed below the framework libexec
# > location.
#
# > Documentation, templates, configuration files, generated assets, and supporting
# > release data are installed into their corresponding target locations.
#
# > This mirrors the target-root structure produced during release preparation and
# > keeps deployed systems predictable.
#
# -- Uninstallation -----------------------------------------------------------------
#
# > The uninstaller reverses the installation process as far as safely possible.
#
# > Its purpose is to remove deployed SolidGroundUX files from the target system
# > without requiring the user to manually search through the filesystem.
#
# > Uninstallation should be treated with care. Runtime data, user configuration,
# > generated logs, and project-specific files may require different handling from
# > framework-owned installed files.
#
# > In general, uninstallers should avoid deleting user-owned data unless the user
# > explicitly requests that behavior.
#
# -- Administrative Expectations ----------------------------------------------------
#
# > Installation and uninstallation usually affect system-level directories.
#
# > Depending on the target paths, these operations may require elevated privileges.
# > A normal user can prepare and inspect release archives, but writing to system
# > locations such as /usr/local, /etc, or /var may require root permissions.
#
# > The installer should fail clearly when it lacks the permissions required to
# > complete the requested operation.
#
# -- Why Deployment Is Separate -----------------------------------------------------
#
# > Keeping deployment separate from the runtime framework keeps the framework
# > cleaner.
#
# > Runtime libraries should not need to know how they were installed. Executable
# > tools should be able to run from the deployed filesystem layout without carrying
# > installer logic around with them.
#
# > This separation also makes releases easier to reason about: prepare-release
# > builds the package, the installer applies the package, and the framework runs
# > after installation.
#
# > That distinction is what makes the deployment scripts framework-adjacent rather
# > than core runtime components.
# -- Checksums and Integrity --------------------------------------------------------
#
# > Release packages may contain checksums and other metadata describing the
# > expected contents of the package.
#
# > During installation, the installer can use this information to validate the
# > integrity of the release before files are deployed.
#
# > This helps detect damaged downloads, incomplete transfers, accidental
# > modification of release files, or packaging errors introduced during release
# > preparation.
#
# > The installer and release tooling exchange integrity information through the
# > release metadata generated during the prepare-release process.
#
# > Conceptually, the workflow is:
#
# >     Prepare release
# >         ↓
# >     Generate checksums and metadata
# >         ↓
# >     Package release archive
# >         ↓
# >     Transfer release archive
# >         ↓
# >     Installer validates package integrity
# >         ↓
# >     Installation proceeds
#
# > Integrity validation is intended to confirm that the package being installed is
# > the same package that was originally prepared.
#
# > Checksum validation is not a substitute for code signing or cryptographic trust
# > chains. Its primary purpose is to detect accidental corruption and ensure release
# > consistency.
