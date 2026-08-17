# ==================================================================================
# SolidGroundUX - SDK Tools Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2622911
#   Checksum    : 0eb1384b339cb7addd5a74c729f22a2262ea08ff58854a00a922d28f86c8dd41
#   Source      : sdk tools_preface.sh
#   Type        : documentation
#   Group       : SDK Tools
#   Purpose     : Group preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================

# - SDK Tools -----------------------------------------------------------------------
#
# > The SDK Tools group contains the utilities used to create, maintain, deploy,
# > document, package, and release SolidGroundUX-based projects.
#
# > While the framework itself provides the runtime foundation for applications,
# > the SDK tools support the development lifecycle around that runtime. Together
# > they form a lightweight development environment for creating structured Bash
# > applications without having to reinvent the surrounding project administration
# > for every new tool.
#
# -- Typical Development Workflow ---------------------------------------------------
#
# > A typical SolidGroundUX project follows an iterative lifecycle:
#
# >     Create workspace
# >         ↓
# >     Develop application
# >         ↓
# >     Deploy to development environment
# >         ↓
# >     Test and debug
# >         ↓
# >     Return to development as needed
# >         ↺
#
# >     Repeat until satisfied
# >         ↓
# >     Generate documentation
# >         ↓
# >     Prepare release
# >         ↓
# >     Distribute package
#
# > The SDK tools automate much of the repetitive work involved in these stages,
# > allowing developers to focus primarily on application functionality.
#
# -- Creating a New Project ---------------------------------------------------------
#
# > Most projects begin with the workspace creation utility.
#
# > The workspace generator creates the directory structure expected by the
# > framework and populates it with the required templates, configuration files,
# > documentation scaffolding, and supporting assets.
#
# > The resulting workspace provides a consistent starting point for development.
# > Rather than manually creating directories and copying scripts between projects,
# > developers can begin with a known structure that already follows framework
# > conventions.
#
# -- Development Phase --------------------------------------------------------------
#
# > During development, executable scripts, libraries, modules, and documentation
# > are created within the workspace structure.
#
# > The provided templates are intended to be the preferred starting point for new
# > components. They contain the recommended metadata headers, bootstrap structure,
# > documentation conventions, and coding patterns used throughout the framework.
#
# > Following the templates helps maintain consistency across projects and reduces
# > the amount of boilerplate code required.
#
# -- Development Deployment ---------------------------------------------------------
#
# > During development, the workspace can be deployed into a development target
# > environment. This allows scripts and libraries to be tested in a layout that
# > closely resembles the final installed structure.
#
# > This deployment step is part of the normal development loop. Code is written in
# > the workspace, deployed to the development target, tested, debugged, and then
# > refined in the workspace again.
#
# > This keeps the development process honest: scripts are not only tested from
# > their source location, but also from the filesystem layout in which they are
# > eventually expected to run.
#
# -- Metadata Management ------------------------------------------------------------
#
# > Metadata plays an important role within the SolidGroundUX ecosystem. Version,
# > build, checksum, attribution, licensing, and source identity are maintained through
# > the canonical source-header model.
#
# > Metadata maintenance is consolidated into prepare-release.sh and the shared
# > header-parser support. Version and Build can be updated for all files, changed files
# > only, or left untouched, while checksums are refreshed whenever source or release
# > metadata changes require it.
#
# > Keeping this work in release preparation avoids a separate metadata-maintenance tool
# > and ensures the release artifacts and source headers are synchronized together.
#
# -- Documentation Generation -------------------------------------------------------
#
# > Documentation is generated directly from source code comments.
#
# > Rather than maintaining a completely separate documentation tree, developers
# > document modules, functions, variables, and concepts alongside the
# > implementation.
#
# > The documentation generator extracts this information and transforms it into a
# > navigable HTML documentation set.
#
# > This approach helps keep implementation and documentation synchronized while
# > reducing duplication of effort.
#
# -- Workspace Deployment -----------------------------------------------------------
#
# > deploy-workspace.sh is a development and test-deployment tool. It transfers a
# > complete workspace or a filtered/incremental selection into a local or remote
# > target root so the code can be exercised in its intended filesystem layout.
#
# > Workspace deployment is deliberately separate from formal release installation.
# > It does not define the installed-release lifecycle and should not be treated as an
# > installer. Formal release creation belongs to prepare-release.sh; installation,
# > update, rollback/reinstallation, and removal belong to release-manager.sh.
#
# -- Preparing a Release ------------------------------------------------------------
#
# > prepare-release.sh creates the complete release set consumed by the standalone
# > release manager. It can maintain Version and Build metadata, refresh changed-file
# > checksums, verify executable wrappers, optionally create missing wrappers, and
# > generate the archive, manifest, removal manifest, and checksum sidecars.
#
# > The prepared bundle includes release-manager.sh so a fresh machine can bootstrap
# > from the same framework-independent lifecycle used for later updates and rollback.
# > release-manager.sh then owns check, download, install, update, rollback/reinstall,
# > and removal operations.
#
# -- Why These Tools Exist ----------------------------------------------------------
#
# > Bash projects often begin as a handful of scripts and gradually evolve into
# > collections of loosely related files with inconsistent structures.
#
# > The SDK tools attempt to prevent that outcome by encouraging a repeatable
# > workflow and a consistent project layout from the beginning.
#
# > In other words, they automate the boring parts of project administration so
# > developers can spend their time building software rather than managing files.
#
# -- Workspace Layout ---------------------------------------------------------------
#
# > SolidGroundUX projects follow a standardized directory structure.
#
# > While individual projects may add folders as needed, the framework expects a
# > number of well-known locations. The typical workspace structure mimics the
# > expected deployment layout, making it easier to transition from development to
# > deployment without reorganizing files.
#
# > The deployment tools depend on this structure to determine which files to
# > include and where to place them during deployment. The structure also helps
# > ensure that generated documentation, metadata, and supporting assets are
# > maintained consistently across projects.
#
# ! Deviate at your own peril.
#
# >     <project-root>/
# >     ├── etc
# >     │   ├── solidgroundux                       Product or company configuration
# >     │   ├── testadura                           Testadura-specific configuration
# >     │   └── update-motd.d                       MOTD scripts, such as ##-<product>
# >     │                                           SolidGroundUX uses 90 as its prefix
# >     ├── usr
# >     │   └── local
# >     │       ├── bin                             User-facing executable applications
# >     │       ├── sbin                            System administration tools
# >     │       ├── lib
# >     │       │   └── solidgroundux               Reusable libraries and shared code
# >     │       │       ├── common                  Common framework libraries
# >     │       │       ├── py                      Python support code
# >     │       │       ├── styles                  Documentation and UI style assets
# >     │       │       └── templates               Script and project templates
# >     │       ├── libexec
# >     │       │   └── solidgroundux               Internal executable helpers
# >     │       │       └── console-modules         Console application modules
# >     │       └── share
# >     │           └── doc
# >     │               └── solidgroundux           Generated HTML documentation
# >     │                   ├── assets
# >     │                   └── pages
# >     ├── var
# >     │   └── lib
# >     │       └── solidgroundux                   Runtime data and generated artifacts
# >     │           └── releases                    Release archives and deployment output
# >     └── home
# >         └── .config                             User-local configuration and logs
#
# > Executable applications are typically placed in bin and sbin, reusable
# > libraries in lib, and internal implementation helpers in libexec.
#
# > This separation helps distinguish public interfaces from internal
# > implementation details and keeps larger projects maintainable.
#
# -- Development Conventions --------------------------------------------------------
#
# > SolidGroundUX relies heavily on conventions to keep projects consistent.
#
# > Public framework functions should use the sgnd_ prefix.
#
# > Framework-public functions use `sgnd_*`. Framework-internal functions shared by
# > cooperating framework libraries use `_sgnd_*`. A plain leading underscore such as
# > `_helper` identifies a script- or module-local private implementation detail. Bash
# > cannot enforce these access levels, but the naming convention communicates intent.
#
# > Executable scripts should be based on the executable template.
# > User-facing executables should normally be exposed through lightweight wrappers
# > in bin or sbin. The actual implementation script should live in the appropriate
# > product subfolder, usually below libexec, and be invoked by the wrapper.
#
# > This keeps the command path clean while allowing implementation scripts,
# > supporting files, and internal helpers to remain grouped by product.
#
# > Reusable libraries should be based on the library template.
#
# > Libraries should generally not perform actions merely because they are sourced.
# > With the exception of library guards, metadata registration, dependency
# > registration, and similar initialization tasks, sourcing a library should not
# > execute business logic, modify user data, create files, or perform external
# > operations.
#
# > Libraries are expected to provide functionality through public functions. The
# > caller decides when that functionality is executed.
#
# > Modules intended for menu-driven applications should use the module template.
#
# > Metadata headers should be maintained in all framework-managed files.
#
# > Documentation should be maintained close to the source code using the framework
# > documentation conventions.
#
# > Development-only artifacts should be kept out of the deployed target layout
# > unless they are intentionally part of the product being released.
#
# > Developers are free to deviate from these conventions when appropriate, but
# > following them generally results in more maintainable projects and more useful
# > generated documentation.
