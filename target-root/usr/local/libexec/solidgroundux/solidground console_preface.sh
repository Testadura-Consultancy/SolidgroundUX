# ==================================================================================
# SolidGroundUX - Console Host and Management Console Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.9
#   Build       : 2622203
#   Source      : solidground console_preface.sh
#   Type        : documentation
#   Group       : SolidGround Console
#   Purpose     : Describe the generic console host and its default management application
#
#   Checksum : 6f3be36aa510d9ee9cd400e29411a43e9b354dc5219fba8150b9e5056b26f8ce
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
# > SolidGroundUX Management Studio. The host provides menu registration, rendering,
# > paging, runtime state, action dispatch, and module loading. Applications are
# > composed from source-only console modules rather than hard-coded into the host.
#
# > The Management Studio uses the same console recursively: the main console loads
# > a small set of launcher modules, and each launcher opens another sgnd-console
# > instance with the module set that defines its submenu. The same menu engine,
# > themes, state indicators, paging, and dispatch logic are therefore reused at
# > every level.
#
# -- Architecture -------------------------------------------------------------------
#
# >     sgnd-console
# >         │
# >         ├─ Main menu module set
# >         │    ├─ Computer Management
# >         │    ├─ Active Directory
# >         │    ├─ File Services
# >         │    ├─ SolidGroundUX Setup
# >         │    ├─ Development
# >         │    └─ Console Settings
# >         │
# >         └─ selected launcher
# >              │
# >              └─ sgnd-console
# >                   │
# >                   └─ submenu module set
# >                        │
# >                        └─ registered groups and actions
# >                             │
# >                             └─ public/private executables
#
# > The important boundary is ownership: sgnd-console owns menu mechanics; modules
# > own menu content. A submenu is not a second menu implementation. It is another
# > use of the same console host with a different module source.
#
# -- Main Components ----------------------------------------------------------------
#
# >     sgnd-console
# >         Public launcher installed in `/usr/local/bin`.
#
# >     sgnd-console.sh
# >         Generic application host. Resolves framework and application roots,
# >         initializes runtime state, discovers modules, records module metadata,
# >         and runs the interaction loop. It can be invoked again with a different
# >         module source to host a submenu.
#
# >     sgnd-console-menu.sh
# >         Shared menu engine responsible for registration, paging, rendering,
# >         cached layouts, navigation, state indicators, and action dispatch.
#
# >     Console launcher modules
# >         Source-only modules used by the main Management Studio menu. Each
# >         represents one functional area and opens the corresponding submenu.
#
# >     Submenu definitions / module sets
# >         Define which functional modules are loaded for a submenu. They compose
# >         existing modules; they do not duplicate their operational logic.
#
# >     Functional console modules
# >         Source-only modules that register the submenu sections and actions.
# >         These remain the owners of their domain-specific menu structure.
#
# >     Private executables
# >         Standalone scripts implementing operational logic behind menu actions.
#
# -- Design Philosophy --------------------------------------------------------------
#
# > The console host deliberately contains no business logic and no knowledge of
# > Active Directory, storage, package management, or other functional domains.
# > Its responsibility is to provide a reusable execution and presentation engine.
#
# > The governing rule is:
#
# >     Modules own menus; the framework owns menu mechanics.
#
# > This makes submenu support a composition problem rather than a new UI feature.
# > The same host can render the main menu, a functional submenu, or an entirely
# > different console application simply by changing the modules it loads.
#
# -- Management Studio Main Menu ----------------------------------------------------
#
# > The standard Management Studio main menu intentionally remains shallow:
#
# >     1) Computer Management
# >     2) Active Directory
# >     3) File Services
# >     4) SolidGroundUX Setup
# >     5) Development
# >     6) Console Settings
#
# > These entries are launcher modules, not containers for business logic. Selecting
# > an entry opens a submenu hosted by sgnd-console with the appropriate functional
# > module set. Returning from that console returns control to the parent console.
#
# -- Submenus -----------------------------------------------------------------------
#
# > Submenus preserve the functional grouping defined by their modules. For example,
# > the Active Directory submenu can contain sections for Active Directory Server,
# > Active Directory DNS, Users and Groups, and Active Directory Client while still
# > using the standard group/item registration API.
#
# > Because a submenu is another console host invocation, it automatically inherits:
#
# >     • menu rendering and numbering
# >     • paging and left/right navigation
# >     • UI theme and framework state
# >     • dry-run / commit semantics
# >     • privilege awareness
# >     • role awareness
# >     • action dispatch
# >     • return behaviour
#
# > No submenu-specific renderer or input loop is required.
#
# -- Module Contract ----------------------------------------------------------------
#
# > A console module is a source-only Bash file. During loading it provides module
# > metadata such as SGND_MODULE_ID, SGND_MODULE_NAME, SGND_MODULE_VERSION, and
# > SGND_MODULE_DESC. Functions are defined before registration.
#
# > Functional modules extend a menu through:
#
# >     sgnd_console_register_group
# >     sgnd_console_register_item
#
# > Launcher modules instead expose a main-menu action that opens sgnd-console with
# > the module source/profile belonging to that functional area.
#
# > This keeps module discovery and registration data-driven while allowing modules
# > to be freely recomposed into different console applications.
#
# -- Public Commands and Private Executables ----------------------------------------
#
# > Public SolidGroundUX tools remain installed beneath `/usr/local/bin` and
# > `/usr/local/sbin` and may be invoked by modules through the standard command
# > runner. Domain-specific implementation remains in standalone executables beneath
# > `/usr/local/libexec/solidgroundux`.
#
# > Keeping operational logic outside the menu definitions means that changing the
# > console hierarchy does not require moving or duplicating the implementation.
# > Commands remain independently executable, testable, reusable, and documentable.
#
# -- Console State and Status Bar ---------------------------------------------------
#
# > Runtime state is presented as status, not as a collection of bottom-bar actions.
# > The status area communicates consequential console state such as execution mode
# > and privilege level. Existing framework colour semantics are retained; for
# > example SGND_UI_DRYRUN represents the safe dry-run state and SGND_UI_COMMIT marks
# > the consequential commit state.
#
# > The footer itself is reserved for navigation. Left and right arrow keys correspond
# > visually to `<<` and `>>`, with the current page position shown between them.
# > This separates three concerns clearly:
#
# >     menu       = actions
# >     status     = current framework/console state
# >     footer     = navigation
#
# -- Direct Keyboard Controls -------------------------------------------------------
#
# > Frequently used console states can also be changed directly from any menu by
# > using framework-owned keyboard shortcuts. These shortcuts do not appear as menu
# > items; the status bar provides the visual reminder and immediately reflects the
# > resulting state.
#
# >     M          Toggle execution mode between DRY-RUN and COMMIT
# >     A          Toggle access mode between STANDARD and ROOT
# >     c / C      Cycle console log level forward / backward
# >     f / F      Cycle file log level forward / backward
# >     t / T      Cycle the installed console theme forward / backward
# >     R          Toggle role-aware menu visibility
#
# > Lowercase and uppercase variants are used where a setting has an ordered cycle:
# > lowercase advances to the next value and uppercase returns to the previous value.
# > Binary settings use a single key because they simply toggle between two states.
#
# > The direct controls complement, rather than replace, Console Settings. Console
# > Settings remains the discoverable management interface for the same framework
# > parameters and for settings that do not require a global shortcut.
#
# -- Console Settings ---------------------------------------------------------------
#
# > Framework and console configuration that previously appeared as global session
# > controls is exposed through the Console Settings module. This keeps configuration
# > manageable without permanently occupying the footer and provides a natural home
# > for theme, paging, role-awareness, module-management, shell, redraw, and related
# > console settings.
#
# -- Paging and Rendering -----------------------------------------------------------
#
# > Menu registrations are stored in datatables but rendered from cached page models.
# > The menu engine materializes direct-index caches for groups and items, computes
# > visible entries, and rebuilds layouts only when required. Main menus and submenus
# > therefore share the same rendering and performance characteristics.
#
# -- Reuse and Composition ----------------------------------------------------------
#
# > Recursive hosting is intentionally simple:
#
# >     sgnd-console
# >         → loads modules
# >             → launcher opens sgnd-console
# >                 → loads another module set
# >                     → dispatches actions
#
# > This is not limited to two levels. A module may open another specialized console
# > when a future use case warrants it, without introducing another menu framework.
# > In practice, menu depth should remain purposeful and shallow for usability.
#
# -- Creating a Module or Dedicated Console -----------------------------------------
#
# > A new console module is created as a normal source-only SolidGroundUX module. It
# > supplies its module metadata, defines any menu action functions, and registers the
# > groups and menu items that make up its interface. The console host provides the
# > rendering, paging, state handling, navigation, and action dispatch.
#
# > To add the module to an existing console application, place it in that console's
# > module directory. When sgnd-console loads the directory, the module is discovered
# > together with the other `.sh` modules and contributes its registrations to the
# > resulting menu.
#
# > A module can also be used as an entire console application by itself. The
# > `--appcfg` option accepts either a module directory or one individual `.sh` module:
#
# >     sgnd-console.sh --appcfg ./50-my-module.sh --title "My Console"
#
# > In this form only that module is loaded. The same generic sgnd-console host is
# > therefore sufficient to create a dedicated management console without copying or
# > modifying sgnd-console itself. A directory may be supplied instead when the new
# > console consists of several cooperating modules.
#
# > The minimal workflow is therefore:
#
# >     create a source-only console module
# >         ↓
# >     define its actions
# >         ↓
# >     register its groups and menu items
# >         ↓
# >     run sgnd-console with the module file or module directory as `--appcfg`
#
# > If the new console later becomes part of a larger application, the same module can
# > be reused unchanged behind a launcher module or composed with other modules into a
# > submenu. This is the same mechanism used by the SolidGroundUX Management Studio.
#
# -- Creating Another Console Application -------------------------------------------
#
# > To create another console application, define the desired module set and launch
# > sgnd-console against it. Modules supply application identity, groups, items, and
# > actions while the host remains unchanged. A module may itself launch another
# > module set, allowing larger applications to be assembled from smaller functional
# > consoles.
#
# -- Why the Console Matters --------------------------------------------------------
#
# > The SolidGround Console is more than a menu system. It is a reusable execution
# > environment for modular administrative applications. The same mechanism hosts
# > both the Management Studio main menu and its functional submenus.
#
# > By separating host mechanics, module composition, menu ownership, and operational
# > executables, SolidGroundUX avoids duplicate UI code and keeps each responsibility
# > independently reusable. New console structures can be created by composition
# > rather than by implementing new menu engines.
