
# ==================================================================================
# SolidGroundUX - SolidGround Console Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2618309
#   Checksum    : acc5ab844845ed904134ec4dcc7794a6b45d2cddabe7db1be7eaa6503a04445d
#   Source      : solidground console_preface.sh
#   Type        : documentation
#   Group       : SolidGround Console
#   Purpose     : Group preface
#
#   Checksum : acc5ab844845ed904134ec4dcc7794a6b45d2cddabe7db1be7eaa6503a04445d
#   Checksum : acc5ab844845ed904134ec4dcc7794a6b45d2cddabe7db1be7eaa6503a04445d
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - SolidGround Console -------------------------------------------------------------
#
# > The SolidGround Console group contains the interactive console host used by
# > SolidGroundUX and the menu system that supports it.
#
# > The console provides a structured, menu-driven way to expose framework tools,
# > developer utilities, and project-specific actions without turning every action
# > into a separate command that must be remembered and typed manually.
#
# > In short, it is a lightweight application host for Bash-based tooling.
#
# -- What the Console Does -----------------------------------------------------------
#
# > The console host loads a configurable set of console modules, lets those modules
# > register menu groups and menu items, renders the resulting menu, accepts user
# > input, and dispatches the selected action.
#
# > The host itself does not implement application-specific business logic. Its job
# > is to provide the runtime environment, menu structure, navigation behavior, and
# > dispatch mechanism.
#
# > Actual functionality is added through modules.
#
# -- Main Components ----------------------------------------------------------------
#
# > The console group consists of several related components.
#
# >     sgnd-console
# >         User-facing launcher installed in the executable path.
#
# >     sgnd-console.sh
# >         Console host. Handles bootstrap, configuration, module loading,
# >         built-in menu items, dispatch, and the main interaction loop.
#
# >     sgnd-console-menu.sh
# >         Console menu library. Provides menu registration, layout, rendering,
# >         paging, toggle labels, and dispatch support.
#
# >     console-devtools.sh
# >         Default developer tools module. Registers common development actions
# >         such as workspace creation, workspace deployment, release preparation,
# >         and metadata editing.
#
# >     mod-template.sh
# >         Template module for console environments. It contains the boilerplate
# >         required for framework bootstrap, module registration, and interaction
# >         with the SolidGround Console host.
#  
# -- Console Startup Sequence -------------------------------------------------------
#
# > A typical console session follows this sequence:
#
# >     User starts sgnd-console
# >         ↓
# >     Launcher starts sgnd-console.sh
# >         ↓
# >     Framework bootstrap is loaded
# >         ↓
# >     Built-in framework arguments are handled
# >         ↓
# >     Console configuration is loaded or created
# >         ↓
# >     Built-in console menu items are registered
# >         ↓
# >     Console modules are loaded from the configured module directory
# >         ↓
# >     Modules register their own groups and menu items
# >         ↓
# >     The menu is rendered
# >         ↓
# >     User selections are dispatched to registered actions
#
# > This keeps the console host generic. The menu that appears at runtime is the
# > result of the loaded modules rather than a hard-coded list inside the host.
#
# -- Console Configuration ----------------------------------------------------------
#
# > The console can use an application configuration file to define its title,
# > description, module directory, and page size.
#
# > If an application configuration file is requested but does not yet exist, the
# > console can create one with sensible defaults. In interactive mode it can prompt
# > for values; in non-interactive mode it falls back to defaults.
#
# > The module directory may be absolute or relative. Relative module paths are
# > resolved against the configuration file location, making it practical to create
# > separate console environments with their own module sets.
#
# -- Menu Groups and Items ----------------------------------------------------------
#
# > Console modules extend the host by registering groups and items.
#
# > A group represents a logical section in the menu. An item represents a selectable
# > action within a group.
#
# > Modules register their entries through the public console registration API:
#
# >     sgnd_console_register_group
# >     sgnd_console_register_item
#
# > This registration model allows independent modules to contribute functionality
# > without modifying the console host itself.
#
# -- Built-in Console Actions -------------------------------------------------------
#
# > The console host registers a number of built-in actions for common runtime and
# > session behavior.
#
# > These include toggles for debug output, dry-run mode, verbose output, logfile
# > output, and clear-on-render behavior.
#
# > The console also provides session controls such as previous page, next page,
# > redraw, and quit.
#
# > These built-in actions give every console application a consistent baseline user
# > experience, regardless of which modules are loaded.
#
# -- Console Lifecycle --------------------------------------------------------------
#
# > Once initialized, the console follows a simple lifecycle.
#
# >     Console Host
# >          ↓
# >     Loads Modules
# >          ↓
# >     Modules Register Groups
# >          ↓
# >     Groups Register Items
# >          ↓
# >     Menu Rendered
# >          ↓
# >     User Selects Action
# >          ↓
# >     Registered Function Executes
# >          ↓
# >     Menu Rendered Again
#
# > The console itself contains very little application-specific functionality.
# > Instead, it acts as a host for modules that contribute menu groups and menu
# > items.
#
# > During startup, each loaded module registers its functionality with the host.
# > Once registration is complete, the menu is rendered and user interaction begins.
#
# > Selecting a menu item causes the associated function to execute. When the
# > action completes, control returns to the console and the menu is rendered
# > again.
#
# > This cycle continues until the user exits the console.
#  
# -- The Default Developer Tools Module ---------------------------------------------
#
# > The default console application includes the developer tools module.
#
# > This module registers common SDK actions in the console so they can be launched
# > interactively instead of being invoked manually from the command line.
#
# > The default developer tools currently include actions for:
#
# >     Create workspace
# >     Deploy workspace
# >     Prepare release
# >     Metadata editor
#
# > The module itself does not implement these tools directly. It delegates execution
# > to the corresponding SDK scripts through the console runtime.
#
# -- Creating a New Console Environment ---------------------------------------------
#
# > A developer can create a separate console environment by using an application
# > configuration file with its own title, description, and module directory.
#
# > Conceptually, the workflow is:
#
# >     Choose or create an environment directory
# >         ↓
# >     Create an application configuration file
# >         ↓
# >     Point the configuration at a console module directory
# >         ↓
# >     Add one or more module scripts
# >         ↓
# >     Start the console with that application configuration
# >         ↓
# >     Let the console load the modules and build the menu
#
# > This makes it possible to have different console environments for different
# > purposes, such as framework development, application development, deployment
# > tooling, customer-specific maintenance, or administrative tasks.
#
# -- Setting Up an Application Development Workspace ---------------------------------
#
# > For application development, the console is intended to work together with the
# > SDK tools.
#
# > A typical application workflow is:
#
# >     Start the SolidGround Console
# >         ↓
# >     Use Create workspace to create a structured development workspace
# >         ↓
# >     Develop scripts, libraries, modules, configuration, and documentation
# >         ↓
# >     Use Deploy workspace to deploy the target-root structure to a development
# >     environment
# >         ↓
# >     Test and debug the application
# >         ↓
# >     Return to development and repeat as needed
# >         ↓
# >     Generate documentation
# >         ↓
# >     Use Prepare release when the project is ready to package
#
# > This workflow keeps development, deployment, documentation, and release
# > preparation connected while still allowing each step to remain explicit.
#
# -- Writing Console Modules --------------------------------------------------------
#
# > Console modules are source-only Bash modules loaded by the console host.
#
# > A module normally defines its helper functions first and then registers its
# > groups and items at load time.
#
# > Registration should be the only intended load-time side effect. The actual work
# > should happen only when the user selects the corresponding menu item.
#
# > This keeps module loading predictable and prevents the console from performing
# > unexpected actions simply because a module was sourced.
#
# -- Why the Console Helps ----------------------------------------------------------
#
# > The console reduces friction when working with a growing set of framework and
# > project tools.
#
# > Instead of remembering every script name, option, and workflow step, developers
# > can expose common actions through a consistent interactive menu.
#
# > It also provides a simple plugin model: adding functionality can be as simple as
# > dropping a module into the configured module directory and letting it register
# > its menu entries.
#
# > This makes the SolidGround Console both a developer convenience and a practical
# > foundation for project-specific administration tools.
