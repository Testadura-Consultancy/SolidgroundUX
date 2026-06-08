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
# - First-time Installation -------------------------------------------------------
#
# > A first-time installation should use the installer even on a clean system.
# > Although the release archive can technically be unpacked by hand, the installer
# > is the supported entry point because it validates the package, applies the
# > expected filesystem layout, preserves release metadata, and records the
# > installed state for later updates and removal.
#
# > The normal first-install workflow is:
#
# >     Download the SolidGroundUX release bundle from the GitHub release
# >         ↓
# >     Extract the release bundle into a temporary working directory
# >         ↓
# >     Run the bundled installer against the bundled package
# >         ↓
# >     Verify that the SolidGroundUX commands are available
#
# > Example:
#
# >     unzip SolidGroundUX-<version>.<build>.tar.gz.zip
# >     cd <extracted-release-directory>
# >
# >     sudo bash sgnd-install.sh \
# >         --package SolidGroundUX-<version>.<build>.tar.gz \
# >         --releases-dir . \
# >         --target-root /
#
# > The --package option selects the exact release archive to install.
# > The --releases-dir option tells the installer where related release metadata
# > and checksum files can be found. For a first install from an extracted bundle,
# > this is normally the current directory.
#
# > The --target-root option identifies the root of the filesystem that should
# > receive the installation. On a live system this is normally /. For testing,
# > packaging validation, or documentation examples, it may point to a temporary
# > target-root directory instead.
#
# > Manual extraction with tar should be treated as an emergency or bootstrap
# > fallback only. It bypasses the installer's state tracking and therefore makes
# > future update and uninstall behavior less reliable.
#
# -- Update Installation -----------------------------------------------------------
#
# > Updates use the same installer, but the release package is normally placed in
# > the installed SolidGroundUX releases directory first. This gives the deployed
# > installer a stable location from which it can discover available packages,
# > compare versions, validate integrity, and apply the selected update.
#
# > The normal update workflow is:
#
# >     Download the newer SolidGroundUX release bundle from the GitHub release
# >         ↓
# >     Extract the release bundle into a temporary working directory
# >         ↓
# >     Copy the new package, manifest, and checksum files into the releases
# >     directory below /var/lib/solidgroundux
# >         ↓
# >     Run the installed sgnd-install command for the SolidGroundUX product
# >         ↓
# >     Installer selects the appropriate newer package and applies the update
#
# > Example:
#
# >     unzip SolidGroundUX-<version>.<build>.tar.gz.zip
# >     cd <extracted-release-directory>
# >
# >     sudo mkdir -p /var/lib/solidgroundux/releases
# >     sudo cp SolidGroundUX-<version>.<build>.tar.gz* /var/lib/solidgroundux/releases/
# >     sudo cp SolidGroundUX-<version>.<build>.manifest* /var/lib/solidgroundux/releases/
# >
# >     sudo sgnd-install --product SolidGroundUX
#
# > The --product option limits package discovery to the named product. This avoids
# > accidentally selecting unrelated release packages if the releases directory is
# > later shared by multiple SolidGroundUX-related products.
#
# > A specific update package may also be installed explicitly:
#
# >     sudo sgnd-install \
# >         --package /var/lib/solidgroundux/releases/SolidGroundUX-<version>.<build>.tar.gz \
# >         --target-root /
#
# > Explicit package installation is useful when testing a particular release,
# > repeating a controlled deployment, or avoiding automatic selection from the
# > releases directory. Product-based installation is usually more convenient for
# > normal updates.
#
# > Release file names should use consistent product casing. For SolidGroundUX, the
# > recommended package and manifest prefix is SolidGroundUX. This matters because
# > product filtering and package discovery are based on release naming.
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
# - Uninstallation -----------------------------------------------------------------
#
# > SolidGroundUX provides a dedicated uninstaller that removes files recorded by
# > the installation process.
#
# > The preferred uninstall method is to use the installed uninstaller rather than
# > manually deleting files from the filesystem.
#
# > The normal uninstall workflow is:
#
# >     Run sgnd-uninstall
# >         ↓
# >     Uninstaller reads installed metadata
# >         ↓
# >     Uninstaller identifies framework-owned files
# >         ↓
# >     Uninstaller removes installed files
# >         ↓
# >     Uninstaller reports the result
#
# > Example:
#
# >     sudo sgnd-uninstall
#
# > If the installed command is unavailable, the bundled uninstaller from a release
# > package may also be used:
#
# >     sudo bash sgnd-uninstall.sh --product SolidGroundUX
#
# > The uninstaller relies on installation metadata and manifests created during
# > deployment. This allows it to remove framework-owned files without requiring
# > the user to manually locate them.
#
# > In general, the uninstaller should remove installed framework files while
# > preserving user-owned content such as:
#
# >     Configuration overrides
# >     Project files
# >     Generated documentation
# >     Runtime logs
# >     User data
#
# > Administrators should therefore avoid manually deleting SolidGroundUX files
# > unless recovering from a damaged installation. Using the uninstaller provides
# > the most predictable and supportable removal path.
#
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
