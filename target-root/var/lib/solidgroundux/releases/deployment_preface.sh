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
# > A typical deployment starts with a prepared SolidGroundUX release bundle from
# > the GitHub release page. The release bundle is a convenience ZIP containing the
# > release archive, manifest, and checksum files.
#
# > First-time installation and later updates intentionally use different entry
# > points. A first-time installation bootstraps the system by extracting the
# > prepared target-root archive directly into the root filesystem. After that, the
# > installed deployment tools are available for future updates and removal.
#
# > Conceptually, the first-time workflow is:
#
# >     Download release bundle
# >         ↓
# >     Copy release bundle to the target machine
# >         ↓
# >     Extract release bundle into /var/lib/solidgroundux/releases
# >         ↓
# >     Extract the contained release archive into /
# >         ↓
# >     SolidGroundUX files are present in the target filesystem layout
#
# > Conceptually, the update workflow is:
#
# >     Download newer release bundle
# >         ↓
# >     Extract release bundle into /var/lib/solidgroundux/releases
# >         ↓
# >     Run sgnd-install
# >         ↓
# >     Installer selects a package, validates checksums, creates backups,
# >     extracts the package, and updates install records
#
# > The exact installation behavior may depend on command-line options and the
# > metadata available in the release package.
#
# - First-time Installation -------------------------------------------------------
#
# > A first-time installation on a clean system uses the prepared release archive
# > directly. The release archive mirrors the target filesystem layout and can
# > therefore be extracted into the root filesystem.
#
# > The normal first-install workflow is:
#
# >     Download the SolidGroundUX release bundle from the GitHub release
# >         ↓
# >     Copy the release bundle to the target machine
# >         ↓
# >     Extract the release bundle into /var/lib/solidgroundux/releases
# >         ↓
# >     Extract the contained release archive into /
#
# > Example:
#
# >     sudo mkdir -p /var/lib/solidgroundux/releases
# >
# >     sudo unzip SolidGroundUX-<version>-release.zip \
# >         -d /var/lib/solidgroundux/releases
# >
# >     sudo tar -xzpf \
# >         /var/lib/solidgroundux/releases/SolidGroundUX-<version>.tar.gz \
# >         -C /
#
# > The first-time extraction places the SolidGroundUX commands, libraries,
# > templates, documentation, deployment scripts, and supporting files into their
# > expected filesystem locations.
#
# > After the first installation, the installed deployment scripts can be used for
# > later update and uninstall operations.
#
# -- Update Installation -----------------------------------------------------------
#
# > Updates use the installed sgnd-install command. The newer release bundle is
# > extracted into the SolidGroundUX releases directory first, giving the installer
# > a stable location from which to discover packages and related metadata.
#
# > The normal update workflow is:
#
# >     Download the newer SolidGroundUX release bundle from the GitHub release
# >         ↓
# >     Copy the release bundle to the target machine
# >         ↓
# >     Extract the release bundle into /var/lib/solidgroundux/releases
# >         ↓
# >     Run sgnd-install for the SolidGroundUX product
#
# > Example:
#
# >     sudo mkdir -p /var/lib/solidgroundux/releases
# >
# >     sudo unzip SolidGroundUX-<version>-release.zip \
# >         -d /var/lib/solidgroundux/releases
# >
# >     sudo sgnd-install --product SolidGroundUX
#
# > The --product option limits package discovery to the named product. This avoids
# > accidentally selecting unrelated release packages if the releases directory is
# > later shared by multiple SolidGroundUX-related products.
#
# > In automatic mode, sgnd-install selects the newest matching package by parsed
# > build number, validates the matching archive and manifest checksums, creates a
# > backup of affected existing files, extracts the archive into the target root,
# > and records install metadata below /var/lib/solidgroundux.
#
# > A specific update package may also be installed explicitly:
#
# >     sudo sgnd-install \
# >         --package /var/lib/solidgroundux/releases/SolidGroundUX-<version>.tar.gz \
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
# > package may also be used, provided the installer state records are still
# > available:
#
# >     sudo bash sgnd-uninstall.sh
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
