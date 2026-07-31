# ==================================================================================
# SolidGroundUX - Console Host and Management Console Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621011
#   Source      : solidground console_preface.sh
#   Type        : documentation
#   Group       : SolidGround Console
#   Purpose     : Describe the generic console host and its default management application
#
#   Checksum : ff38bbec6d2018dc0eca621d43816abd22436cba921ed6e5d2057106a37be50e
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - SolidGround Console -------------------------------------------------------------
# . Images
#   smc.png :: Figure 1 – SolidGroundUX Management Studio.
#
# > The SolidGround Console is the reusable application host that powers the
# > SolidGroundUX Management Studio. The host provides menu management, rendering,
# > paging, runtime controls, state management, and action dispatch, while the
# > application itself is implemented entirely through loadable modules.
#
# > This separation allows the same console engine to host different applications.
# > The standard SolidGroundUX module set simply supplies one such application:
#
# >     SolidGroundUX Management Studio
#
# > The result is a reusable console framework whose behaviour is defined by the
# > modules it loads rather than by the host itself.
#
# -- Architecture -------------------------------------------------------------------
#
# > The console is organized as a layered architecture:
#
# >     User
# >         │
# >     sgnd-console
# >         │
# >     Console Host
# >         │
# >     Menu Engine
# >         │
# >     Console Modules
# >         │
# >     Private Executables
# >         │
# >     SolidGroundUX Framework
#
# > Each layer has a clearly defined responsibility and depends only on the layer
# > beneath it.
#
# -- Main Components ----------------------------------------------------------------
#
# >     sgnd-console
# >         Public launcher installed in `/usr/local/bin`.
#
# >     sgnd-console.sh
# >         Generic application host. Resolves framework and application roots,
# >         initializes runtime state, discovers modules, records module metadata,
# >         registers built-in session actions, and runs the interaction loop.
#
# >     sgnd-console-menu.sh
# >         Menu engine responsible for registrations, paging, rendering, cached
# >         layouts, runtime controls, and action dispatch.
#
# >     Console Modules
# >         Source-only modules that contribute application identity, menu groups,
# >         menu items, and action registrations.
#
# >     Private Executables
# >         Standalone scripts implementing the operational logic behind individual
# >         menu actions.
#
# -- Design Philosophy --------------------------------------------------------------
#
# > The console host deliberately contains no business logic.
#
# > Its responsibilities are limited to:
#
# >     • loading modules
# >     • rendering the interface
# >     • dispatching actions
# >     • maintaining runtime state
#
# > Modules define what functionality is available, while standalone executables
# > perform the actual work. This separation keeps the host generic, modules small,
# > and operational logic reusable outside the console itself.
#
# -- Host and Application Identity --------------------------------------------------
#
# > The executable itself has the neutral identity `sgnd-console`.
#
# > During startup the first successfully loaded module may provide:
#
# >     SGND_CONSOLE_TITLE_OVERRIDE
# >     SGND_CONSOLE_DESC_OVERRIDE
#
# > These values determine the application identity presented to the user.
#
# > Modules are loaded in filename order, making startup explicit and predictable:
#
# >     10-sgnd-config.sh
# >     20-machine-config.sh
# >     30-customer-extension.sh
#
# > Filename order determines initialization only. Permanent module identity is
# > defined through `SGND_MODULE_ID`.
#
# -- Console Startup ----------------------------------------------------------------
#
# >     Start sgnd-console
# >         ↓
# >     Resolve framework and application
# >         ↓
# >     Initialize runtime and console state
# >         ↓
# >     Discover and load modules
# >         ↓
# >     Modules register groups and actions
# >         ↓
# >     Build cached menu model
# >         ↓
# >     Enter interaction loop
#
# > Registration and layout occur only when the menu model changes. Ordinary redraws
# > reuse cached menu and page layouts for immediate responsiveness.
#
# -- Module Contract ----------------------------------------------------------------
#
# > A console module is a source-only Bash file.
#
# > During loading it temporarily provides:
#
# >     SGND_MODULE_ID
# >     SGND_MODULE_NAME
# >     SGND_MODULE_VERSION
# >     SGND_MODULE_DESC
#
# > The host validates these values, records the module, rejects duplicate module
# > IDs, and clears the temporary metadata before loading the next module.
#
# > Modules typically follow this structure:
#
# >     Define helper functions
# >         ↓
# >     Register groups
# >         ↓
# >     Register menu items
# >         ↓
# >     Menu items invoke standalone executables
#
# -- Registration API ---------------------------------------------------------------
#
# > Modules extend the application through:
#
# >     sgnd_console_register_group
# >     sgnd_console_register_item
#
# > Groups define ordered sections.
#
# > Items define labels, descriptions, actions, optional hotkeys, visibility rules,
# > and post-action behaviour.
#
# > The host stores these registrations as the logical menu model from which cached
# > page layouts are constructed.
#
# -- Public Commands and Private Executables ----------------------------------------
#
# > Public SolidGroundUX tools remain installed beneath:
#
# >     /usr/local/bin
# >     /usr/local/sbin
#
# > Modules invoke these through:
#
# >     _sgnd_run_public_command
#
# > Module-specific functionality is implemented as standalone executables located
# > beneath:
#
# >     /usr/local/libexec/solidgroundux/console-modules/<module-id>/
#
# > These executables are launched through:
#
# >     _sgnd_run_module_script
#
# > Keeping operational logic outside the menu modules provides several advantages:
#
# >     • modules remain small
# >     • actions are independently executable
# >     • functionality is reusable outside the console
# >     • testing becomes straightforward
# >     • documentation is generated from the implementation itself
#
# -- Runtime Controls ---------------------------------------------------------------
#
# > Runtime controls provide immediate access to frequently used console behaviour,
# > including:
#
# >     • dry-run mode
# >     • logging levels
# >     • UI themes
# >     • redraw behaviour
# >     • paging
# >     • console session actions
#
# > Changes are applied immediately and persisted where appropriate through the
# > framework state mechanism.
#
# -- Paging and Rendering -----------------------------------------------------------
#
# > Menu registrations are stored in datatables but rendered from cached page models.
#
# > The menu engine materializes direct-index caches for groups and items, computes
# > visible entries, and builds page layouts only when necessary.
#
# > Interactive redraws therefore avoid repeated traversal of the registration data,
# > providing consistent performance even as the number of modules grows.
#
# -- Standard Management Studio Modules ---------------------------------------------
#
# > The standard Management Studio is currently composed of two primary modules.
#
# > Framework Configuration provides:
#
# >     • installation and upgrades
# >     • framework configuration
# >     • framework state
# >     • logging
# >     • diagnostics
# >     • developer tools
#
# > Machine Configuration provides:
#
# >     • machine identity
# >     • network configuration
# >     • SSH management
# >     • template preparation
# >     • package maintenance
# >     • optional server roles
#
# > The host itself contributes the Console Session group containing runtime and
# > navigation actions.
#
# -- Framework State ----------------------------------------------------------------
#
# > Framework-wide behaviour, including log levels, UI themes, palettes, and other
# > shared settings, is stored independently from console-specific layout state.
#
# > Console state therefore contains only information specific to the user interface,
# > such as paging preferences, while transferable framework behaviour remains part
# > of the shared framework state.
#
# -- Creating Another Console Application -------------------------------------------
#
# > The console host may be reused for entirely different applications.
#
# >     Create a module directory
# >         ↓
# >     Add one or more console modules
# >         ↓
# >     Register groups and actions
# >         ↓
# >     Launch sgnd-console with the desired application configuration
#
# > The host remains unchanged while modules define the application's identity and
# > capabilities.
#
# -- Why the Console Matters --------------------------------------------------------
#
# > The SolidGround Console is more than a menu system. It is the execution
# > environment for modular administrative applications.
#
# > By separating the application host, menu modules, and operational executables,
# > SolidGroundUX keeps user interface, registration, and implementation concerns
# > independent. The result is a framework that is easier to extend, easier to test,
# > easier to document, and easier to maintain.
#
# > The standard module set turns this reusable console engine into the
# > SolidGroundUX Management Studio while preserving the flexibility to build
# > entirely different console applications on the same foundation.
