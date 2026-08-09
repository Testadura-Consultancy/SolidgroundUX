# Changelog

All notable changes to SolidGroundUX are documented in this file.

The format is inspired by *Keep a Changelog* while remaining focused on
practical framework development.

# Unreleased

## SolidGround Framework

### Added

-   Added `sgnd-definitions.sh` as the canonical source for
    SolidGroundUX framework identity, version/build information, default
    settings, framework registries, and core-library declarations.
-   Added `sgnd_print_labeledmultivalue`, a multiline variant of
    `sgnd_print_labeledvalue` that keeps the label on the first line
    while allowing values to span multiple lines.
-   `sgnd_print_labeledmultivalue` accepts either:
    -   A single string, optionally wrapped to a configurable value
        width.
    -   An array of values, with each item rendered on a separate
        aligned line.
-   Added `ask_datetime`, a datetime-aware variant of `ask` that accepts
    both absolute dates and SolidGroundUX relative date/time
    expressions.
-   Added the following datetime shortcuts:
    -   `N` -- Current date and time.
    -   `D` -- Today at the start of the day.
    -   `s` -- Seconds.
    -   `m` -- Minutes.
    -   `h` -- Hours.
    -   `d` -- Days.
    -   `M` -- Months.
    -   `y` -- Years.
    -   Relative expressions such as `-2m`, `-2h`, `+30m`, `-1d`, `-3M`,
        and `-1y`.
-   Relative datetime expressions are resolved immediately and returned
    as absolute ISO-8601 timestamps.
-   `ask_datetime` now displays the resolved absolute timestamp when a
    shorthand expression is entered.
-   Added an interactive `ask_datetime` test to the framework smoke
    test.

## SolidGround Management Console

### Added

-   Added persistent console-module visibility state, with module
    identifiers derived conventionally from module filenames.
-   Added **Manage modules** to **Console Session**, allowing console
    modules to be enabled or disabled without editing configuration
    files manually.
-   Added role-aware console visibility so Active Directory server,
    Active Directory client, DNS, user/group, and Samba file-server
    functionality is only exposed when the corresponding role packages
    are installed.
-   Added the executing machine hostname to the Management Console title
    bar, making machine identity immediately visible across local and
    remote sessions.
-   Added transient console initialization/progress feedback while
    paths, configuration, built-in menu items, and console modules are
    loaded.

### Changed

-   Consolidated all package-related actions into a dedicated **Package
    Management** module, including base packages, Active Directory
    server/client packages, Samba File Server, XRDP, and Docker.
-   Console module load control now follows SolidGroundUX
    convention-over-configuration: module IDs are derived from filenames
    rather than duplicated as explicit module declarations.
-   Disabled console modules are no longer sourced; modules without an
    explicit visibility-state entry remain enabled by default for
    backward compatibility.
-   Console screen clearing now uses an explicit ANSI
    erase-display/cursor-home sequence instead of the host `clear`
    implementation, producing consistent rendering across SSH/PowerShell
    and VS Code terminals.
-   Increased the console menu label-width allowance to improve
    readability of longer package-management actions.

### Fixed

-   Fixed the duplicate top separator line that could appear in the
    Management Console when running through SSH from PowerShell.
-   Fixed hidden console groups still allowing their menu items to
    participate in pagination/rendering.

### Changed

-   `sgnd-bootstrap-env.sh` now consumes canonical definitions from
    `sgnd-definitions.sh` while retaining responsibility for
    runtime-derived paths, rebasing, user resolution, and directory
    construction.
-   `prepare-release.sh` now updates framework version/build identity in
    `sgnd-definitions.sh` instead of `sgnd-bootstrap-env.sh`.

## Machine and Network Configuration

### Added

-   Added DNS search-domain support to `set-identity.sh`.
-   Added an interactive **DNS search domain** prompt alongside the DNS
    server setting.
-   Added `--DNS-search` support for non-interactive and DNS-only
    network updates.
-   DNS search-domain values now participate in persistent script state.
-   Netplan generation now writes the configured DNS search domain
    beneath `nameservers.search`.

### Changed

-   DNS configuration now treats the DNS server and DNS search domain as
    a single network identity concern.
-   Active Directory provisioning and domain join now use the generic
    DNS-setting path instead of maintaining separate Netplan
    search-domain logic.
-   Management console now has a state variable SGND_CONSOLE_ROLE_AWARE
    indicating if only role appropriate menus are displayed
    
## Active Directory

### Added

-   Added an **Active Directory DNS** console group.
-   Added DNS-zone listing and host-record query actions.
-   Added actions to create and delete IPv4 host records in Samba Active
    Directory DNS.
-   Added an action to rerun DNS registration for the local domain
    controller.
-   Added client-side actions to manually add or remove the current
    machine's Active Directory DNS record.
-   Domain join now registers the joining machine's IPv4 host record in
    Active Directory DNS.
-   Domain join now configures the Active Directory DNS server and
    domain search suffix as part of client network configuration.

### Changed

-   **Show membership** now provides a consolidated client-domain status
    overview, including:
    -   Machine FQDN.
    -   Machine IPv4 address.
    -   Joined realm.
    -   Domain membership state.
    -   Active Directory DNS server.
    -   DNS host-record registration state.
    -   Registered DNS A-record address.
    -   Kerberos SRV availability.
    -   LDAP SRV availability.
-   Domain join now explicitly configures and validates the machine FQDN
    before joining the realm.
-   Active Directory DNS registration checks now query the authoritative
    AD DNS server directly rather than relying on the local resolver.
-   DNS host-record creation and deletion use shared non-interactive
    helpers so the same implementation is available to both console
    actions and domain join.

### Fixed

-   Fixed joined clients retaining only a short hostname instead of the
    expected fully qualified domain name.
-   Fixed DNS-registration status reporting false positives caused by
    local `/etc/hosts` resolution.
-   Fixed DNS helper variable scoping that could reduce a host FQDN to a
    malformed value such as `td-nas.`.
-   Fixed domain-joined Linux clients being unable to resolve short AD
    hostnames because no DNS search domain was configured.
-   Fixed the domain-join chain so a successful join results in a
    resolvable AD DNS A record for the client.

## Storage

### Added

-   Added storage provisioning for an unused disk, including:
    -   GPT partition creation.
    -   EXT4 or XFS filesystem creation.
    -   Persistent `/etc/fstab` configuration.
    -   Mounting at `/srv/storage`.
    -   Creation of the standard `/srv/storage/shares` directory.
-   Added actions to mount, unmount, and expand configured storage.
-   Added **Validate storage provisioning**, which verifies:
    -   The storage filesystem is mounted.
    -   The filesystem is mounted read/write.
    -   The configured source matches the active mount source.
    -   The persistent `/etc/fstab` entry is valid.
    -   The expected filesystem label is present.
    -   `/srv/storage` exists.
    -   `/srv/storage/shares` exists.
-   Added a separate **Storage Access** menu group for managing the
    ownership and permissions of:
    -   `/srv/storage`
    -   `/srv/storage/shares`
-   Added actions to:
    -   Show storage ownership and permissions.
    -   Set the storage owner.
    -   Set the storage group.
    -   Set storage permissions.
    -   Restore canonical storage permissions.
-   Canonical storage permissions can now be restored to:
    -   `/srv/storage` -- `root:root`, mode `0755`.
    -   `/srv/storage/shares` -- `root:root`, mode `0770`.

### Changed

-   **Show storage status** now reports:
    -   Mount source.
    -   Filesystem.
    -   Filesystem label.
    -   UUID.
    -   Mounted state.
    -   Persistent configuration state.
    -   `/etc/fstab` validity.
    -   Whether the active mount source matches the configured source.
    -   Whether the filesystem is mounted read/write.
    -   Storage-root and shares-root availability.
    -   Capacity and available space.
-   Replaced the misleading **Storage root writable** status with
    **Mounted read/write**.
-   Storage configuration now performs `systemctl daemon-reload` after
    updating `/etc/fstab`.

### Fixed

-   Fixed storage mount detection incorrectly treating `/srv/storage` as
    mounted when it was only an ordinary directory on the root
    filesystem.
-   Fixed storage status showing the capacity of the system root instead
    of the configured storage volume.
-   Fixed storage provisioning stopping after filesystem creation
    without completing persistent mounting.

## Samba File Server

### Added

-   Added Samba file-server package installation.
-   Added managed Samba share creation beneath `/srv/storage/shares`.
-   Added actions to list and remove managed Samba shares.
-   Share creation now:
    -   Creates the backing directory.
    -   Adds a managed section to `smb.conf`.
    -   Validates the configuration with `testparm`.
    -   Reloads Samba.
    -   Restores the previous configuration if validation fails.
-   Added file-server validation for:
    -   Samba tooling.
    -   Samba configuration.
    -   `smbd` service state.
    -   Mounted storage.
    -   The managed share root.
    -   Configured share backing directories.
-   Added a dedicated `manage-samba-shares.sh` executable for
    interactive share management.
-   The share manager supports:
    -   Listing all managed shares.
    -   Selecting one or more shares by number.
    -   Comma-separated selections.
    -   Numeric ranges.
    -   Selecting all shares.
    -   Keeping the selected collection active while applying multiple
        actions.
-   Added share-management actions to:
    -   Show share details.
    -   Set owner.
    -   Set group.
    -   Set Unix permissions.
    -   Restore default permissions.
    -   Validate selected shares.

### Changed

-   Replaced the separate share-permission menu actions with a single
    **Manage shares** action.
-   Share ownership and permission management is now handled by the
    dedicated share-management executable rather than repeated prompts
    in the console module.
-   The Samba module now delegates detailed share-management workflows
    while retaining installation, creation, removal, validation, and
    status actions.

## Installation and Release Management

### Added

-   Added the standalone `release-manager.sh` as the canonical
    SolidGroundUX installation and release-lifecycle tool, replacing the
    separate install, update, and uninstall workflow.
-   Added filesystem-based release state:
    -   `/var/lib/solidgroundux/releases` contains releases available
        for installation.
    -   `/var/lib/solidgroundux/archive/<release>` contains installed
        release history.
    -   The highest archived version represents the currently installed
        release.
-   Added interactive archived-release selection for reinstallation and
    rollback, with the current release identified and **Remove
    SolidGroundUX** available as the final action.
-   Added GitHub latest-release discovery and download support.
-   Added release acquisition through temporary staging, extraction,
    checksum validation, release-identity validation, and path-safety
    validation before a release is admitted into `releases/`.
-   Added bootstrap installation from a GitHub release ZIP containing
    `release-manager.sh` and the complete prepared release set.
-   Added automatic creation of the SolidGroundUX release-management
    directories during first installation.
-   Added automatic installation of a valid release set found beside the
    bootstrap copy of `release-manager.sh`.
-   Added automatic installation of the release manager itself at
    `/var/lib/solidgroundux/release-manager.sh`.
-   Added safe cleanup of known bootstrap files after a successful
    installation from a temporary directory.
-   Added command-line operations for checking, downloading, installing,
    updating, rolling back, reinstalling, and removing releases,
    including unattended and dry-run operation.

### Changed

-   First-time installation no longer requires manually creating the
    releases directory, copying release files into it, or extracting the
    framework archive directly into `/`.
-   Release bundles now act as self-contained bootstrap packages: they
    can be downloaded and extracted into a temporary directory and
    installed by running the bundled `release-manager.sh`.
-   Updates now install complete release archives and process the
    incoming `.removed` manifest for files that no longer belong to the
    new release.
-   Rollback now reinstalls a complete archived release and returns
    newer archived releases to `releases/`, preserving the
    filesystem-based current-version rule.
-   Removal now uses release manifests to remove framework-owned files
    while retaining release artifacts for later reinstallation.
-   Release-manager UI is self-contained and framework-independent while
    following the SolidGroundUX default visual conventions for titles,
    separators, labels, values, prompts, and status colors.
-   Updated deployment and installation documentation to describe the
    new `prepare-release.sh` → release artifacts → `release-manager.sh`
    workflow and distinguish it from direct development deployment
    through `deploy-workspace.sh`.

### Removed

-   The separate installer/updater/uninstaller architecture is
    superseded by `release-manager.sh`.
-   Removed the requirement for installation metadata or a separate
    current-version marker; release and archive directories now provide
    the required state.

## Development Tools

### Added

-   `prepare-release.sh` now verifies that executable scripts directly
    beneath `usr/local/libexec/solidgroundux` have corresponding public
    command wrappers in `usr/local/bin`.
-   Added optional automatic creation of missing public command wrappers
    during release preparation.
-   `create-workspace.sh` now copies the canonical SolidGroundUX
    template set into the workspace under
    `target-root/usr/local/lib/solidgroundux/templates` and instantiates
    selected starter files from those workspace-local templates.

### Changed

-   Consolidated release metadata maintenance into `prepare-release.sh`,
    superseding the separate metadata-editor workflow.

-   Version and Build metadata policies in `prepare-release.sh` now
    support `A` (all files), `C` (changed files only), and `N` (no
    update) independently.

-   Changed-file detection for release metadata uses the canonical
    header checksum mechanism, allowing source changes to be
    distinguished from Version, Build, and Checksum metadata changes.

-   Checksums are refreshed automatically for changed files and whenever
    release metadata changes a file.

-   Version and Build policy prompts now use constrained SolidGroundUX
    decision input with `C` as the default.

-   Corrected the `prepare-release.sh` argument specifications so `C` is
    stored as the default for Version and Build policies and `A,C,N`
    remains the choice list.

-   Workspace creation now follows the repository-shaped `target-root`
    layout more explicitly and uses its local template copy as the
    source for newly selected executable, library, and module starter
    files.

-   `sgnd_doc_renderer.py` now renders \$ marked entries only for
    template packages, : is rendered always

-   `deploy-workspace.sh` now ends with a redo/continue prompt: Continue
    exits cleanly, while `R` restarts the deployment from the beginning
    with the original arguments.

-   `deploy-workspace.sh` now uses `ask_datetime` for the **Changed
    after** prompt.

-   The deployment filter now accepts SolidGroundUX relative date/time
    expressions, such as `N`, `D`, `-2h`, and `-1d`, in addition to
    absolute dates and timestamps.

-   `deploy-workspace.sh` now displays a deployment summary after a
    successful transfer.

-   The deployment summary reports:

    -   Result.
    -   Transport.
    -   Source root.
    -   Destination.
    -   Receiver.
    -   Start and finish timestamps.
    -   Every transferred file.

-   The deployment summary now uses `sgnd_print_labeledmultivalue`,
    displaying transferred files on separate aligned lines instead of as
    a truncated comma-separated string.

-   `prepare-release.sh` now ensures that every regular file directly
    beneath `usr/local/libexec/solidgroundux` has its executable bit set
    before staging and archive creation.

-   Dry-run mode reports which executable permissions would be corrected
    without modifying the source tree.

# Version 1.8 (Build 1.8.2621804)

## Changed

### Active Directory

-   Active Directory provisioning now automatically configures the
    domain controller to use itself as the primary DNS server after
    successful domain creation.
-   Refined the provisioning workflow with a clearer separation between
    network configuration and Active Directory provisioning
    responsibilities.
-   Active Directory provisioning now prompts for the Administrator
    account password as part of the provisioning process.
-   Completed and fully validated the end-to-end Active Directory
    provisioning workflow, including DNS, Kerberos, and domain
    verification.

### Development Tools

-   `deploy-workspace.sh` now supports comma-separated filenames and
    shell-style file masks.
-   Deployment settings are now persisted automatically between
    sessions.
-   Added support for incremental deployments based on the last
    successful deployment timestamp.
-   `deploy-workspace.sh` now offers an interactive **Since last
    deployment** option.
-   When **Since last deployment** is selected, the stored deployment
    timestamp is displayed and the **Changed after** prompt is skipped.
-   When **Since last deployment** is not selected, the **Changed
    after** date defaults to `1900-01-01`.
-   Streamlined deployment prompts and selection workflow for a faster
    incremental deployment experience.
-   Significantly improved incremental documentation generation by
    supporting selective regeneration of changed source files, greatly
    reducing documentation build times during development.

## Resolved

### Active Directory

-   Fixed domain provisioning to correctly configure the required Fully
    Qualified Domain Name (FQDN) before provisioning.
-   Fixed DNS listener detection during Active Directory verification.
-   Fixed Kerberos configuration and verification workflow.
-   Fixed Active Directory verification to correctly validate DNS,
    directory services, and Kerberos authentication.
-   Fixed Administrator account configuration to support non-expiring
    passwords.

### Development Tools

-   Fixed deployment state persistence in `deploy-workspace.sh`.
-   Fixed deployment selection to correctly process multiple filename
    filters during a single deployment operation.

# Version 1.8 (Build 2621612)

## SolidGround Management Console

### Added

#### Computer Setup

-   Machine status overview.
-   Machine identity and network configuration.
-   Machine ID generation.
-   SSH service configuration.
-   SSH host key generation.
-   VM template preparation.
-   Ubuntu package management.
-   Ubuntu base package installation.

#### Active Directory

-   Samba Active Directory package installation.
-   Active Directory domain provisioning.
-   Active Directory status overview.
-   Active Directory user management.
-   Active Directory group management.
-   Active Directory client installation.
-   Domain join and leave support.

#### Samba File Server

-   Samba File Server installation.

#### Optional Roles

-   Docker installation.
-   XRDP installation.
-   Framework for future optional server roles.

#### SolidGroundUX

-   Framework configuration management.
-   Framework state management.
-   Framework logging tools.
-   Framework diagnostics.
-   SolidGroundUX installation, update, and removal.

#### Development Tools

-   Workspace creation.
-   Workspace deployment through `deploy-workspace.sh`.
-   Workspace archiving.
-   Workspace restoration.
-   Release preparation.
-   Metadata editor.
-   Documentation generator.
-   `receive-files.sh` for receiving streamed deployments.
-   `tar-it.sh` for archive creation.
-   `untar-it.sh` for archive restoration.

### Changed

-   Reorganized the SolidGround Management Console into dedicated
    functional modules.
-   Simplified the overall console navigation.
-   Console actions that invoke external scripts now resolve those
    scripts from `SGND_COMMON_EXE` or `SGND_COMMON_LIB`.
-   Completely redesigned `deploy-workspace.sh`.
-   Added support for local and remote workspace deployment over SSH.
-   Added support for deploying complete workspaces or filtered file
    selections.
-   `deploy-workspace.sh` now creates a tar stream that is processed by
    `receive-files.sh`.
-   Simplified deployment selection by combining directory, filename or
    mask, and modification-date filters.

### Removed

-   Replaced the previous console modules with the new functional module
    structure:
    -   `10-sgnd-config.sh`
    -   `20-machine-config.sh`
    -   `30-role-provisioning.sh`

## SolidGround Framework

### Added

-   Global variable SGND_COMMON_EXE this is weher Solidground's
    executables can be found

# Version 1.8 (Build 1.8.2621804)

## Changed

### Active Directory

-   Active Directory provisioning now automatically configures the
    domain controller to use itself as the primary DNS server after
    successful domain creation.
-   Refined the provisioning workflow with a clearer separation between
    network configuration and Active Directory provisioning
    responsibilities.
-   Active Directory provisioning now prompts for the Administrator
    account password as part of the provisioning process.
-   Completed and fully validated the end-to-end Active Directory
    provisioning workflow, including DNS, Kerberos, and domain
    verification.

### Development Tools

-   `deploy-workspace.sh` now supports comma-separated filenames and
    shell-style file masks.
-   Deployment settings are now persisted automatically between
    sessions.
-   Added support for incremental deployments based on the last
    successful deployment timestamp.
-   `deploy-workspace.sh` now offers an interactive **Since last
    deployment** option.
-   When **Since last deployment** is selected, the stored deployment
    timestamp is displayed and the **Changed after** prompt is skipped.
-   When **Since last deployment** is not selected, the **Changed
    after** date defaults to `1900-01-01`.
-   Streamlined deployment prompts and selection workflow for a faster
    incremental deployment experience.
-   Significantly improved incremental documentation generation by
    supporting selective regeneration of changed source files, greatly
    reducing documentation build times during development.

## Resolved

### Active Directory

-   Fixed domain provisioning to correctly configure the required Fully
    Qualified Domain Name (FQDN) before provisioning.
-   Fixed DNS listener detection during Active Directory verification.
-   Fixed Kerberos configuration and verification workflow.
-   Fixed Active Directory verification to correctly validate DNS,
    directory services, and Kerberos authentication.
-   Fixed Administrator account configuration to support non-expiring
    passwords.

### Development Tools

-   Fixed deployment state persistence in `deploy-workspace.sh`.
-   Fixed deployment selection to correctly process multiple filename
    filters during a single deployment operation.

# Version 1.8 (Build 2621612)

## SolidGround Management Console

### Added

#### Computer Setup

-   Machine status overview.
-   Machine identity and network configuration.
-   Machine ID generation.
-   SSH service configuration.
-   SSH host key generation.
-   VM template preparation.
-   Ubuntu package management.
-   Ubuntu base package installation.

#### Active Directory

-   Samba Active Directory package installation.
-   Active Directory domain provisioning.
-   Active Directory status overview.
-   Active Directory user management.
-   Active Directory group management.
-   Active Directory client installation.
-   Domain join and leave support.

#### Samba File Server

-   Samba File Server installation.

#### Optional Roles

-   Docker installation.
-   XRDP installation.
-   Framework for future optional server roles.

#### SolidGroundUX

-   Framework configuration management.
-   Framework state management.
-   Framework logging tools.
-   Framework diagnostics.
-   SolidGroundUX installation, update, and removal.

#### Development Tools

-   Workspace creation.
-   Workspace deployment through `deploy-workspace.sh`.
-   Workspace archiving.
-   Workspace restoration.
-   Release preparation.
-   Metadata editor.
-   Documentation generator.
-   `receive-files.sh` for receiving streamed deployments.
-   `tar-it.sh` for archive creation.
-   `untar-it.sh` for archive restoration.

### Changed

-   Reorganized the SolidGround Management Console into dedicated
    functional modules.
-   Simplified the overall console navigation.
-   Console actions that invoke external scripts now resolve those
    scripts from `SGND_COMMON_EXE` or `SGND_COMMON_LIB`.
-   Completely redesigned `deploy-workspace.sh`.
-   Added support for local and remote workspace deployment over SSH.
-   Added support for deploying complete workspaces or filtered file
    selections.
-   `deploy-workspace.sh` now creates a tar stream that is processed by
    `receive-files.sh`.
-   Simplified deployment selection by combining directory, filename or
    mask, and modification-date filters.

### Removed

-   Replaced the previous console modules with the new functional module
    structure:
    -   `10-sgnd-config.sh`
    -   `20-machine-config.sh`
    -   `30-role-provisioning.sh`

## SolidGround Framework

### Added

-   Global variable SGND_COMMON_EXE this is weher Solidground's
    executables can be found

# Version 1.8 (Build 2621300)

## SolidGroundUX Framework

### Resolved

-   All print primitives in ui.sh now respect SGND_CONSOLE_WIDTH

### Added

-   Themed color constants SGND_UI_BOLD, SGND_UI_FAINT, SGND_UI_ITALIC
-   Incremental update options for doc-generator
-   Added Appendix 0 to documentation (Both for Dev's as well as AI)

## SolidGroundUX Management Studio

### Added

-   Added sshd verification to 20-machine-config.sh
-   Added new module 30-role-provisioning.sh with samba ad provisoning
    functions

### Changed

-   Warning when opening shell nows displays regardless of loglevel

# Version 1.8 (Build 2621022)

## SolidGroundUX Management Studio

### Added

-   Added a Machine Configuration action to enable or disable the SSH
    service.
-   Added a Console Session action to open a child shell.

### Changed

-   Updated `set-identity.sh` to use the current machine configuration
    as the default prompt values.
-   Added automatic availability checks for static IPv4 addresses before
    applying network configuration, with user confirmation when a
    potential address conflict is detected.

## SolidGroundUX Framework

### Added

-   Added dedicated style variables for title and section rendering,
    allowing title text, subtitle text, border colours, and border
    characters to be customized independently of the base UI palette.

# Version 1.8 (Build 2620810)

## Resolved

-   Fixed various machine configuration issues in the Management
    Console.
-   Fixed an issue where state variables were not being saved by
    `prepare-release.sh`.
-   Fixed documentation grouping issues caused by inconsistent script
    title prefixes.

## Added

-   Added framework global `SGND_CONSOLE_WIDTH` to define the preferred
    console rendering width.
-   Added framework global `SGND_MAX_RENDER_WIDTH` to define the maximum
    console rendering width.
-   Added documentation summary sections (`var:` blocks) to the
    framework style files.

## Changed

-   Updated all UI rendering primitives to respect the framework console
    width settings.
-   Changed HTML documentation rendering so consecutive non-empty lines
    are treated as paragraphs.
-   Updated `prepare-release.sh` to synchronize the selected version
    with changed script headers.
-   Improved documentation generation for style configuration variables.

# Version 1.8 (Build 2620423)

## Resolved

-   Fixed an issue where `sgnd-install.sh` could overwrite ownership and
    permissions of existing system directories (such as `/`, `/etc`, and
    `/usr`) during installation.

## Changed

-   Updated `sgnd-install.sh` to preserve metadata of existing target
    directories.
-   Updated `prepare-release.sh` to package repository directories with
    `root:root` ownership.

# Version 1.8 (Build 2620413)

## Added

-   Introduced the **SolidGroundUX Management Console**, a module-driven
    administration application built on the generic `sgnd-console`
    engine.
-   Added ordered console-module loading through numeric filename
    prefixes, allowing the first module to define the console title and
    description.
-   Added the `10-sgnd-config.sh` module for:
    -   Developer tools
    -   SolidGroundUX installation and maintenance
    -   Framework configuration
    -   Framework state
    -   Framework logging
    -   Framework diagnostics
-   Added the `20-machine-config.sh` module for machine identity,
    package maintenance, template preparation, and optional server
    roles.
-   Added direct bottom-bar controls for:
    -   Dry-run or commit mode
    -   Console log level
    -   File log level
    -   Active theme
    -   Screen clearing
-   Added reverse cycling for console log level, file log level, and
    theme using `Shift+C`, `Shift+F`, and `Shift+T`.
-   Added framework configuration actions for viewing effective settings
    and editing system-wide and user-specific configuration files.
-   Added framework logging actions for viewing, following, filtering,
    and rotating the active logfile.
-   Added `sgnd-update.sh` to download the latest SolidGroundUX release
    from GitHub.
-   Added public command wrappers for install, uninstall, and update
    operations.
-   Added cached console menu models and cached page layouts to make
    redraws effectively immediate.

## Changed

-   Redesigned `sgnd-console` as a reusable console engine rather than a
    SolidGroundUX-specific application.
-   Moved the visible console identity from the host into the first
    successfully loaded module.
-   Replaced implicit module discovery order with deterministic filename
    sorting.
-   Reworked the console module contract around:
    -   `SGND_MODULE_ID`
    -   `SGND_MODULE_NAME`
    -   `SGND_MODULE_VERSION`
    -   `SGND_MODULE_DESC`
-   Separated public commands from module-private helper scripts.
-   Merged the former Developer Tools and Framework State modules into
    `10-sgnd-config.sh`.
-   Moved SolidGroundUX installation actions into the SolidGroundUX
    configuration module.
-   Renamed the `vm-config` module and helper directory to
    `machine-config`.
-   Replaced the individual framework smoke-test menu entries with a
    single framework smoke-test command.
-   Reused `framework-smoketest.sh --show env` as the effective
    framework configuration and environment overview.
-   Updated console rendering to reuse cached datatable data instead of
    repeatedly querying and rebuilding menu structures.
-   Updated console and module documentation for the new Management
    Console architecture.
-   Made style sequence fixed so forward and back actually work

## Removed

-   Removed the old `console-devtools.sh` module.
-   Removed the old `console-framework-state.sh` module.
-   Removed the old `vm-config.sh` module name and `vm-config/` helper
    directory.
-   Removed the prompt-based console and file log-level selectors from
    the Console Session menu.
-   Removed the prompt-based theme selector from the Console Session
    menu.
-   Removed the individual in-process framework smoke-test menu actions.

------------------------------------------------------------------------

# Version 1.7 (Build 2620012) 2026-07-19

## Removed

-   Removed motd file, but archaic and cumbersome, and doesn't really
    add any functionality

## Added

-   Added images to documentation, do-generator now supports image tag
    in comments

  ---------------------
  \# Version 1.7 (Build
  2619600) - 2026-07-14

  \## Fixed -
  sgnd-console didn't
  handle --appcfg well,
  corrected so it works
  as intended - updated
  style files with
  SGND_UI_ON and
  SGND_UI_OFF

  \# Version 1.7 (Build
  2619513) - 2026-07-14

  \## Added

  \- Added Appendix F
  to the generated
  documentation
  containing the
  framework license. -
  Introduced persistent
  framework settings
  between sessions. -
  Added persistent
  console session
  settings. - Added
  interactive console
  customization for: -
  Theme selection -
  File log level - Menu
  lines per page

  \## Changed

  \- Reorganized
  `sgnd-console` and
  `sgnd-console-menu`
  into logical sections
  for improved
  maintainability.

  \## Fixed

  \- Framework settings
  are now correctly
  restored when scripts
  are started outside
  the console. -
  Restored menu page
  height is now applied
  before the first
  console render.
  ---------------------

# Version 1.6 (Build 2618912) - 2026-07-02

## Added

-   Introduced configurable console log levels, including the new
    default **Silent** mode.
-   Added extensive smoke tests for logging and progress bars.
-   Added a framework styled MOTD.
-   Introduced progress update intervals to improve performance.

## Changed

-   Refactored executable bootstrap architecture by introducing
    `sgnd-exe-common.sh`.
-   Redesigned the first-time installation process.
-   Updated the installation guide and generated documentation.

## Fixed

-   Prevented recursive backup of `/var` during installation.
-   Corrected progress bar cursor positioning.
-   Fixed multi-level progress bar rendering.
-   Improved progress bar performance for large jobs.
-   Corrected framework license acceptance recording.
-   Fixed precedence of command-line log level over configuration.
-   Corrected clean installation defaults and startup sequence.
