# SolidGroundUX 2.1 Release Notes

**Version 2.1**

![SolidGroundUX 2.1](resources/solidgroundux-social-preview.png)

> **Canonical • Project-aware • Self-bootstrapping • Built for real-world automation**

SolidGroundUX 2.1 is an architectural consolidation release.

Version 2.0 established the framework, modular Management Console, administration modules, documentation pipeline, development tooling, and formal release lifecycle as one coherent platform. Version 2.1 focuses on making that platform simpler to locate, safer to generate, easier to extend into additional projects, and considerably cleaner to release and install.

The central change is the removal of an unnecessary distinction between framework and application roots. SolidGroundUX now derives one `SGND_FRAMEWORK_ROOT` directly from the physical location of the executing component. Around that simpler bootstrap model, 2.1 introduces canonical source normalization, project definitions and workspace scaffolding, project-aware release packages, and a substantially redesigned standalone Release Manager.

The result is less configuration, less duplicated bootstrap logic to maintain, and a clearer path from development workspace to published package to installed system.

## Highlights

### One framework root

SolidGroundUX no longer requires `SGND_APPLICATION_ROOT` or the former `solidgroundux.cfg` bootstrap configuration.

Executables derive `SGND_FRAMEWORK_ROOT` from their physical path by locating the last `usr`, `etc`, or `var` component. This gives production and development trees the same filesystem contract:

```text
/usr/local/bin/...                                      -> /
/etc/solidgroundux/...                                  -> /
/srv/storage/development/SolidGroundUX/target-root/usr/... -> /srv/storage/development/SolidGroundUX/target-root
```

A development `target-root` therefore behaves like a staged installation root without requiring a separate application-root configuration.

This removes first-run root questions from normal framework bootstrap and eliminates a substantial amount of path-specific configuration.

### Canonical bootstrap generation

The small pieces of code that necessarily exist before the framework can load itself are now treated as generated canonical fragments rather than dozens of independently maintained copies.

`normalize-canon.sh` normalizes the framework locator in executables and the library guard in sourced libraries and modules. It skips the canonical source fragments themselves, validates modified shell files with `bash -n`, and uses checksum comparison to determine whether a file actually changed.

`prepare-release.sh` invokes canonical normalization before release metadata and artifacts are produced, ensuring released bootstrap code comes from the canonical definitions.

The library guard also now avoids early metadata initialization until the comment-header parser is available, removing a bootstrap dependency cycle exposed during the 2.1 conversion.

### Order-independent argument handling

Framework built-in arguments can now be mixed naturally with script-specific options.

Bootstrap extracts recognized framework arguments while preserving unknown arguments, their order, and positional data for the script's own parser. The standard `--` marker remains an absolute end-of-options boundary.

Built-ins such as execution mode, automatic operation, state reset, and title control can therefore be supplied without requiring callers to know which parser runs first.

This also fixes early bootstrap values such as `--auto` being lost when arguments were parsed again later in the executable lifecycle.

### Project-aware workspaces

`create-workspace.sh` has evolved from a SolidGroundUX-specific helper into project scaffolding for software built around the framework conventions.

A workspace can establish the canonical `target-root` structure, create project definitions under:

```text
/usr/local/lib/solidgroundux/globals/
```

and optionally create starter executables, libraries, modules, templates, project MOTD integration, a local Git repository, and a GitHub repository.

Project identity uses namespaced definition variables rather than overloading SolidGroundUX framework identity.

The workspace creator can initialize `main`, create the initial commit, create a public or private GitHub repository through the authenticated GitHub CLI account, and push the initial branch.

### Project definitions

Project identity is now deployable runtime information rather than repository-only metadata.

SolidGroundUX retains its canonical `sgnd-definitions.sh`, while additional projects can provide:

```text
<project>-definitions.sh
```

beneath the shared globals directory.

These files carry project-specific product, version, and build identity. Bootstrap loads the foundational SolidGroundUX definitions and additional project definition files from the globals directory.

Release preparation uses the appropriate definitions file as the authoritative project release identity.

### Project-aware release packages

Prepared releases now have an explicit package contract.

Every distributable release ZIP contains a `release-package.info` shipping label identifying the package format, project, product, version, build, and exact release identity.

A package contains the canonical release artifacts:

```text
release-package.info
<Product>-<release>.tar.gz
<Product>-<release>.tar.gz.sha256
<Product>-<release>.manifest
<Product>-<release>.manifest.sha256
<Product>-<release>.removed
<Product>-<release>.removed.sha256
```

SolidGroundUX packages additionally contain `release-manager.sh` at ZIP root so they can bootstrap a clean machine. Generic project packages omit the manager and are consumed by an installed Release Manager.

The definitions file remains the runtime authority after installation; `release-package.info` is the transport-level identity used to validate and admit the package.

### A simpler Release Manager bootstrap

The Release Manager remains the canonical installation and release-lifecycle tool, but its bootstrap role is now more explicit.

For a new SolidGroundUX installation the complete workflow can begin with:

```bash
unzip SolidGroundUX-<release>-release.zip
sudo ./release-manager.sh
```

The ZIP-root manager is only the bootstrap runner. It validates and installs the package; the release archive itself installs the canonical manager beneath:

```text
/var/lib/solidgroundux/release-manager.sh
```

The bootstrap copy no longer attempts to overwrite the canonical manager merely because it is running from another location.

When a manager is not running from a canonical installed location, `/` is the default target root and interactive operation asks for the target explicitly. An installed manager can derive its default target root from its own location.

### One release interface

Release lifecycle operations now belong to the Release Manager rather than being duplicated throughout the Management Console.

The SolidGroundUX console page retains **About SolidGroundUX** and a single **Release manager** action. Checking, downloading, updating, installing, reinstalling, rolling back, removing, and project selection are handled by the Release Manager itself.

Interactive menu actions and command-line actions use the same underlying implementation.

### Stateful standalone release management

The Release Manager remains deliberately usable without a working SolidGroundUX installation.

Parameter values such as target root, selected project, package source, repository, release selector, and state location can be retained as simple standalone state. Explicit command-line values override stored defaults for the current run.

This gives the standalone tool the convenience of persistent defaults without making bootstrap or recovery depend on the framework state subsystem.

### Framework UI when available, fallback when not

Release recovery must not depend on the thing being repaired.

The Release Manager therefore always carries a small standalone UI and a fallback palette based on the SolidGroundUX Default theme.

When a healthy SolidGroundUX framework is available at the selected target root, the manager may use the normal SolidGroundUX UI primitives and active theme. If those cannot be loaded, it falls back to its standalone implementation and release operations remain available.

## What's New in 2.1

### Bootstrap and framework location

- Removed the `SGND_APPLICATION_ROOT` runtime concept.
- Removed the former `solidgroundux.cfg` bootstrap/root-discovery workflow.
- Added deterministic `SGND_FRAMEWORK_ROOT` derivation from the physical script path.
- Production paths resolve naturally to `/`; staged development `target-root` trees resolve to their containing root.
- Framework location no longer requires interactive first-run configuration.
- Framework and application code now share one root contract.
- Bootstrap environment rebasing follows `SGND_FRAMEWORK_ROOT`.
- The globals directory is exposed through `SGND_GLOBALS_FOLDER`.

### Canonical source normalization

- Added canonical `_framework_locator` normalization for executables.
- Added canonical `_sgnd_lib_guard` normalization for libraries and modules.
- Canonical source fragments are excluded from normalization.
- Existing Bootstrap sections are preserved when only the locator function is replaced.
- Library-guard sections can be replaced as a complete canonical unit.
- Modified shell files are checked with `bash -n`.
- Checksum comparison prevents unchanged normalized files from being treated as modifications.
- Release preparation runs canonical normalization before packaging.
- Library metadata initialization is deferred until the header parser required by metadata processing is available.

### Arguments and executable lifecycle

- Framework built-ins are extracted independently of their position before `--`.
- Non-framework arguments remain available to script-specific parsing in their original order.
- Positional arguments after `--` are preserved untouched.
- Added preservation of unknown arguments during the bootstrap parsing pass.
- Fixed framework defaults being reinitialized by a later parsing pass.
- `--auto` now survives the complete bootstrap/script argument lifecycle.
- Built-in execution controls include dry-run/commit, automatic operation, state reset, and title handling.

### Workspace and project creation

- `create-workspace.sh` now creates project-aware target-root workspaces.
- Added project definitions under `usr/local/lib/solidgroundux/globals`.
- Added namespaced product, version, and build variables for non-framework projects.
- Added optional project MOTD generation using `95-<project>`.
- Workspace templates are copied as deployable template files while canonical normalization sources remain framework-owned.
- `templates_preface.sh` is excluded from normal workspace template copying.
- Module projects use a project-specific `usr/local/libexec/solidgroundux/<project>/` location.
- Removed the former module application-configuration scaffolding.
- Added optional local Git initialization.
- Added optional GitHub repository creation through `gh`.
- GitHub creation displays the authenticated account, repository, visibility, and branch before confirmation.
- Newly created repositories use `main` and are pushed explicitly after creation.
- Interactive workspace creation provides a short auto-continue completion window.

### Project identity and globals

- Introduced `SGND_GLOBALS_FOLDER`.
- Moved project identity toward the shared globals directory.
- SolidGroundUX continues to use `sgnd-definitions.sh` for framework identity.
- Additional projects use `<project>-definitions.sh`.
- Bootstrap loads additional project definition files after the foundational framework definitions.
- Project definitions are deployable runtime code and are not treated as ordinary `SGND_USING` dependencies.
- Project MOTD scripts can obtain version/build identity from the corresponding project definitions.

### Release preparation

- `prepare-release.sh` is project-aware.
- Project identity is resolved from the definitions files beneath the staged target root.
- Version and build updates are applied to the appropriate authoritative project definitions.
- Added `release-package.info` to every distributable release ZIP.
- SolidGroundUX packages include the standalone Release Manager for first-install bootstrap.
- Generic project packages do not duplicate the Release Manager.
- Release build output remains in the workspace release-output directory.
- Preparing a release no longer requires duplicating release artifacts into the staged target-root Release Manager state.
- Package admission, rather than package preparation, populates managed release state.

### Release Manager

- Added package identity parsing through `release-package.info`.
- Added project-aware package admission.
- SolidGroundUX retains `/var/lib/solidgroundux/releases` and `/var/lib/solidgroundux/archive`.
- Additional projects use independent state beneath `/var/lib/solidgroundux/projects/<project>/`.
- Added project selection.
- Added direct package acquisition through a local ZIP or URL.
- Retained GitHub latest-release discovery for SolidGroundUX.
- Retained check, download, update, install, rollback, reinstall, and removal workflows.
- Interactive and command-line operation dispatch the same release actions.
- Added stateful standalone parameter defaults.
- Explicit command-line parameters override persisted defaults.
- Bootstrap target root defaults to `/` and is explicitly presented in interactive operation.
- Installed managers can derive the default target root from their canonical location.
- Removed Release Manager self-copy behavior.
- The SolidGroundUX tar archive installs the permanent canonical Release Manager.
- Added a small standalone Default-theme-derived fallback UI.
- Normal SolidGroundUX UI primitives and the active theme may be used when a healthy framework is available.
- Failure to load framework UI does not prevent bootstrap, update, rollback, or recovery.

### Management Console

- Consolidated release lifecycle access into one **Release manager** action.
- Removed the thin console wrappers for Check for updates, Download latest release, Update, Install, Rollback, and Remove.
- Retained **About SolidGroundUX** on the SolidGroundUX page.
- Removed the obsolete repository-mirroring action from the Development module.
- Development tooling now focuses on workspace creation, workspace deployment, release preparation, wrapper creation, and documentation generation.

### Wrapper generation

- Wrapper creation can use an explicit `Wrapper` metadata field when a script's public command name differs from the source filename.
- Existing filename-derived wrapper behavior remains the fallback.
- Release preparation uses the same wrapper identity when validating required public commands.
- Wrapper output is derived from the root belonging to the selected source tree rather than assuming the currently running framework root.

### Framework testing and UI

- Framework Test menu actions that conflicted with global console shortcut keys were converted to numbered menu entries.
- Smoke-test choice handling accepts multi-digit menu selections.
- Canonical comments now distinguish full function contracts from concise headers for simple helpers.
- Every documented function requires at least one concrete `. Usage` example.
- Function documentation is expected to remain proportional to behavioral complexity rather than repeating boilerplate.

### Documentation and Canon

- Deployment documentation now describes project-aware packages and Release Manager state.
- First-install documentation reflects the ZIP-root bootstrap-manager model.
- Release documentation distinguishes workspace build output from installed Release Manager state.
- The Canon now uses `SGND_FRAMEWORK_ROOT` consistently.
- Obsolete application-root and bootstrap-configuration rules have been removed.
- Canonical argument parsing documents order-independent framework built-ins and the `--` boundary.
- Function documentation rules now explicitly allow concise contracts for simple helpers while requiring usage examples.
- Installer rules now cover project-aware package identity, bootstrap-manager behavior, standalone recovery, and optional framework UI integration.

## Compatibility and Migration

### `SGND_APPLICATION_ROOT`

`SGND_APPLICATION_ROOT` is removed from the 2.1 architecture.

Code that previously used it to address files beneath the staged or installed tree should use `SGND_FRAMEWORK_ROOT`.

### Bootstrap configuration

The former `solidgroundux.cfg` framework/application-root discovery file is no longer part of normal bootstrap.

Executables locate the framework from their own physical path. Existing deployment or development procedures that create this file solely for root discovery should remove that step.

### Canonical bootstrap copies

Bootstrap locator and library-guard implementations should no longer be maintained independently.

Run canonical normalization after changing the canonical fragments and before preparing a release.

### Project definitions

Projects built around SolidGroundUX should keep their runtime identity in the shared globals directory using a project definitions file. Release preparation uses that identity when constructing packages.

### Release packages

2.1 packages include `release-package.info`. Tools that inspect or transport release ZIPs should preserve this file at ZIP root.

The package label identifies the transport package; it does not replace the deployed definitions file.

### Release Manager

Existing SolidGroundUX release state locations remain valid.

The main behavioral change is that a temporary/bootstrap Release Manager no longer installs itself by copying the currently executing file. The permanent manager is supplied by the installed SolidGroundUX release.

Management Console users should use the single **Release manager** entry for all lifecycle operations.

### Repository synchronization

The former repository synchronization tool and Development-module **Mirror repository** action are no longer part of the 2.1 development workflow. GitHub is the canonical repository/backup path, while `deploy-workspace.sh` remains the fast path for deploying development changes to target systems.

## Release Workflow at a Glance

The 2.1 release path is deliberately small:

```text
Development workspace
        |
        v
normalize-canon.sh
        |
        v
prepare-release.sh
        |
        v
Project release ZIP
  - release-package.info
  - archive + manifests + checksums
  - release-manager.sh (SolidGroundUX only)
        |
        v
GitHub Release / package source
        |
        v
release-manager.sh
        |
        +--> validate and admit package
        |
        +--> install / update / rollback
        |
        v
Target root + project release history
```

`deploy-workspace.sh` remains outside this formal lifecycle. It is the development transfer path and does not create installed release history.

## Reliability and Fixes

The 2.1 work resolves several architectural problems that were difficult to eliminate cleanly while retaining the older bootstrap model.

Notable fixes include framework-root ambiguity between production and development trees, repeated maintenance of locator and guard fragments, bootstrap metadata initialization before its parser dependency was available, framework arguments being reset during later parsing, public wrapper generation against the wrong staged root, Release Manager self-copy attempts from development or temporary locations, and duplication of release-lifecycle actions between the Management Console and Release Manager.

The release workflow now has a clearer ownership model: workspace tools create packages, packages describe themselves, the Release Manager admits and installs them, and installed project state records their lifecycle.

## SolidGroundUX 2.1

Version 2.1 is less about adding another layer to SolidGroundUX than removing layers that no longer earned their keep.

The framework no longer needs a separate application-root concept to know where it lives. Bootstrap fragments no longer need to drift independently across dozens of files. Projects no longer need to masquerade as the framework to obtain versioned release packages. The Management Console no longer needs to duplicate the Release Manager's interface. And the Release Manager no longer needs the framework to be healthy before it can repair the framework.

That simplification makes SolidGroundUX easier to reason about as both a framework and a development platform.

The development tree mirrors the installed filesystem. Canonical fragments define the unavoidable pre-framework bootstrap code. Project definitions establish runtime identity. `prepare-release.sh` turns a staged tree into a self-describing package. `release-manager.sh` takes responsibility from there.

The result is a cleaner boundary between development, packaging, installation, and operation — with fewer special cases between them.

**One root. One package contract. One release interface.**
