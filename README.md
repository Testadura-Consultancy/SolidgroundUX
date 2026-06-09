# SolidGroundUX

![SolidGroundUX](docs/images/Presenting%20SolidGroundUX%20medium.png)

*A framework for building structured Bash applications.*

SolidGroundUX is a collection of libraries, tools, templates, and conventions designed to reduce boilerplate when developing Bash applications.

The framework provides reusable solutions for common application concerns such as:

- Command-line argument processing
- Configuration management
- Persistent state variables
- Screen and file logging
- User interaction and dialogs
- Terminal UI helpers
- Data table processing
- Documentation generation
- Deployment and packaging
- Modular console applications

Rather than treating every script as a standalone program, SolidGroundUX encourages a consistent application structure built around a shared bootstrap process and reusable framework services.

The result is less repetitive code, more predictable behavior, and easier maintenance.

## Documentation and Installation

Documentation:
https://testadura-consultancy.github.io/SolidgroundUX/

Installation Guide:
https://github.com/Testadura-Mark/SolidGroundUX/blob/main/INSTALL.md

---

# Why SolidGroundUX?

Most shell scripts start small.

A few months later they contain:

- argument parsing
- configuration loading
- state management
- logging
- menus
- prompts
- validation
- deployment logic

...all implemented slightly differently every time.

SolidGroundUX attempts to solve that problem by providing a common foundation that can be reused across projects.

The framework does not attempt to hide Bash.

Instead, it provides practical building blocks that allow developers to focus on application behavior rather than infrastructure code.

---

# Framework Features

## Bootstrap and Runtime

The bootstrap system provides:

- Environment discovery
- Framework path resolution
- Library loading
- Configuration initialization
- State initialization
- Runtime metadata

Applications start with a predictable runtime environment and a common execution model.

## Command-Line Processing

Built-in support for:

- Standardized help generation
- Short and long options
- Flags
- Value arguments
- Enumerations
- Validation
- Usage examples

Argument definitions are declared as metadata rather than manually parsed.

## Configuration Management

Supports:

- System configuration
- User configuration
- Script-specific configuration
- Automatic configuration loading
- Configuration persistence

Configuration values can be integrated directly into application startup.

## Persistent State

State variables allow applications to remember values between executions.

Typical uses include:

- Previous user selections
- Last-used directories
- Runtime preferences
- Wizard-style workflows

When enabled, state variables are automatically loaded and saved by the framework.

## User Interface Services

Provides reusable terminal interaction helpers including:

- Information messages
- Warnings and errors
- Input prompts
- Selection dialogs
- Form-style input
- Auto-continue dialogs
- Consistent formatting

The framework also includes themed colors, styles, and glyphs for building more readable terminal applications.

## Data Tables

The datatable library provides utilities for working with schema-based pipe-separated datasets.

## Documentation Generation

Documentation is extracted directly from source code and rendered as a navigable HTML documentation set.

## Deployment

SolidGroundUX includes deployment tooling for:

- Workspace creation
- Workspace deployment
- Release packaging
- Installation
- Upgrades
- Uninstallation

## Modular Console Applications

Applications can be composed from independent console modules.

---

# Included Tools

| Tool | Purpose |
|--------|--------|
| create-workspace | Create a framework-oriented development workspace |
| deploy-workspace | Deploy or undeploy workspace content |
| prepare-release | Build release packages and manifests |
| sgnd-install | Install or upgrade a release |
| sgnd-uninstall | Remove an installed release |
| doc-generator | Generate framework documentation |
| sgnd-console | Interactive console host |

---

# Intended Audience

SolidGroundUX is intended for developers and system administrators who:

- Build more than a handful of shell scripts
- Prefer reusable infrastructure over copy-paste development
- Want consistent application structure
- Value documentation and maintainability
- Need deployment and packaging support without adopting a larger framework

---

# Philosophy

SolidGroundUX is not trying to replace Bash.

It is an attempt to provide the kind of reusable foundation commonly found in larger development ecosystems while remaining entirely within the shell environment.

The framework favors convention, consistency, and practical engineering over minimalism for its own sake.
