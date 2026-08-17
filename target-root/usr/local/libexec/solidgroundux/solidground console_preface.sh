# ==================================================================================
# SolidGroundUX - SolidGround Management Console
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2622911
#   Source      : solidground console_preface.sh
#   Type        : documentation
#   Group       : Common Core
#   Purpose     : Describe the SolidGround Management Console architecture and module contract
#
#   Checksum : 190bb7f74d857fada971987e793034aefbd2ccaa137f6885bb905734aaff1e73
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - SolidGround Management Console -------------------------------------------------
# . Images
#   smc.png :: Figure 1 – SolidGround Management Console.
#
# > The SolidGround Management Console is the interactive administration shell for
# > SolidGroundUX. It is built from a generic console host, a reusable menu engine,
# > and source-only functional modules.
#
# > The console deliberately separates discovery from loading. At startup it discovers
# > the available module files and reads only the literal module name and description
# > required to build the main index. The module body is not sourced until its page is
# > selected.
#
# > Once a module has been opened it remains loaded for the lifetime of the console
# > process. Returning to the index does not unload it, and opening the page again does
# > not source it a second time.
#
# -- Architecture -------------------------------------------------------------------
#
# >     sgnd-console
# >         │
# >         ├─ discovers enabled module files
# >         │      │
# >         │      └─ reads literal page metadata only
# >         │
# >         ├─ renders main index
# >         │
# >         └─ selected page
# >                │
# >                ├─ source module once when first opened
# >                ├─ module registers groups and items
# >                ├─ render only registrations from that module
# >                └─ Esc returns to the main index
#
# > This page-level lazy-loading model keeps initial console startup small while
# > preserving self-contained functional modules. Implementation code is parsed only
# > when the corresponding page is actually used.
#
# -- Main Components ----------------------------------------------------------------
#
# >     sgnd-console.sh
# >         Executable console host. Resolves the framework runtime, loads console
# >         configuration and state, discovers page modules, renders the main index,
# >         lazy-loads selected modules, owns direct console controls, and runs the
# >         interaction loop.
#
# >     sgnd-menu.sh
# >         Reusable menu engine. Owns group/item registration, page layout, numbering,
# >         rendering, paging, visibility filtering, status decoration, input parsing,
# >         and menu-item dispatch.
#
# >     console-modules/*.sh
# >         Source-only functional modules. Each file represents one top-level console
# >         page and owns the menu groups, items, and action functions for that subject.
#
# >     /usr/local/libexec/solidgroundux
# >         Standalone operational scripts used by console actions where the function
# >         is better implemented outside the module itself.
#
# >     /usr/local/lib/solidgroundux/common/console-helpers.sh
# >         Small console-specific helpers shared by more than one lazy-loaded module.
# >         The console host loads this library through SGND_USING, so modules do not
# >         depend on another module having been opened first.
# >
# >     /usr/local/lib/solidgroundux/common
# >         Reusable framework libraries shared by executables and modules. Subject
# >         implementation should remain in its owning module unless it is genuinely
# >         shared or later proves large enough to justify a separate reusable library.
#
# -- Governing Boundary -------------------------------------------------------------
#
# >     Modules own menu content; sgnd-menu owns menu mechanics; sgnd-console owns
# >     application lifecycle and navigation between module pages.
#
# > Domain logic does not belong in sgnd-console or sgnd-menu. Likewise, modules should
# > not implement their own paging, title bars, input loops, or generic navigation.
# > A helper required by more than one module belongs in console-helpers.sh (or another
# > appropriately scoped common library), not in one of the participating modules.
# >
# > Public console/framework functions use `sgnd_*`. Helpers shared internally between
# > cooperating SolidGroundUX libraries use `_sgnd_*` and are treated as
# > framework-internal/protected rather than application-facing API. Plain `_helper`
# > names remain local/private to their owning script or module.
#
# -- Main Index ---------------------------------------------------------------------
#
# > The initial screen is an index of enabled module pages. The current standard
# > collection is:
#
# >     1) Computer Setup
# >     2) Storage
# >     3) Active Directory Server
# >     4) Active Directory Client
# >     5) Samba File Server
# >     6) SolidGroundUX
# >     7) Development
#
# > The index is intentionally lightweight. It does not source each module in order to
# > discover its menu contents. Instead, sgnd-console reads literal assignments matching
# > the module name and description metadata. If a display name is unavailable, a
# > fallback name is derived from the ordered module filename.
#
# > Selecting a page by number activates that module. Q/q exits the console.
#
# -- Lazy Module Lifecycle ----------------------------------------------------------
#
# > Module loading follows four rules:
#
# >     1. Discover all enabled module files at startup.
# >     2. Do not source a module until its page is selected.
# >     3. Source each module at most once per console process.
# >     4. Keep a loaded module resident until the console exits.
#
# > Keeping previously used modules loaded is intentional, bounded process state rather
# > than a leak. It avoids repeated parsing and preserves any module state required by
# > later actions during the same console session.
#
# > While a page is active, sgnd-menu filters registered groups and items by the source
# > module. Registrations belonging to previously loaded pages therefore remain present
# > in the model without appearing on the current page.
#
# -- Module Contract ----------------------------------------------------------------
#
# > A console module is a source-only Bash file and follows the canonical module
# > pattern: metadata, library guard, module metadata, helpers/actions, then console
# > registration.
#
# > At minimum, its literal page metadata should include assignments in the standard
# > form used by the index reader:
#
# >     SGND_<SUBJECT>_MODULE_NAME="Display Name"
# >     SGND_<SUBJECT>_MODULE_DESC="Short page description"
#
# > The module is sourced only after the page is selected. At that point it registers
# > its detailed menu model with:
#
# >     sgnd_menu_register_group
# >     sgnd_menu_register_item
#
# > Functions must be defined before the registrations that reference them. Modules
# > should use the standard source-only guard so loading remains idempotent. Shared
# > cross-module helpers must be provided by a common library instead of relying on
# > another lazy-loaded page to have been opened first.
#
# -- Page Ordering ------------------------------------------------------------------
#
# > Top-level page order comes from the numeric filename prefix. For example:
#
# >     10-computer-setup.sh
# >     15-storage.sh
# >     20-active-directory-server.sh
# >     25-active-directory-client.sh
# >     30-samba-file-server.sh
# >     40-solidgroundux.sh
# >     90-development.sh
#
# > Group order values are local to the page being rendered. They only need to express
# > the relative order of groups inside that module; they do not need to reserve global
# > ranges for unrelated pages.
#
# -- Navigation ---------------------------------------------------------------------
#
# > The console has two navigation levels:
#
# >     Index view
# >         Number      Open a module page
# >         V           Manage page visibility (root only)
# >         Q/q         Exit
#
# >     Module page
# >         Number      Execute a visible menu action
# >         Esc         Return to the main index
# >         Left/Right  Previous or next menu page when the active module spans pages
# >         Q/q         Exit
#
# > A module page can therefore be reached directly from the index without traversing
# > the pages that precede it.
#
# -- Post-action Pause ---------------------------------------------------------------
#
# > Normal menu actions may request a post-action wait through the WAITSECS argument of
# > sgnd_menu_register_item. A non-zero wait for a normal action is never shorter than
# > 15 seconds. The console presents that wait with ask_dlg_autocontinue so the operator
# > can continue early, pause the countdown, or cancel the countdown without changing
# > the action result. Host-owned immediate controls set SGND_LAST_WAITSECS to 0 and
# > therefore redraw without a post-action pause.
#
# -- Console Status and Direct Controls ---------------------------------------------
#
# > The status area shows framework-owned runtime state. These controls are available
# > directly from the console and are not implemented as module menu items:
#
# >     M          Toggle DRY-RUN / COMMIT
# >     A          Toggle STANDARD / ROOT access by relaunching the console
# >     c / C      Cycle console log level forward / backward
# >     f / F      Cycle file log level forward / backward
# >     t / T      Cycle installed theme forward / backward
# >     Shift+S    Open a shell
# >     L          Set lines per page
# >     R          Redraw the current page
#
# > The toggle bar is status; the legend is navigation/help. These direct controls
# > replace the former Console Settings menu/module. Functional modules should not
# > duplicate them or depend on a Console Settings page being loaded.
#
# -- Paging and Rendering -----------------------------------------------------------
#
# > sgnd-menu stores group and item registrations in datatables and derives cached
# > render models from them. It determines visible rows, label widths, wrapping, group
# > continuation, and page boundaries from the active source and current terminal size.
#
# > The main index is rendered by sgnd-console because it exists before any functional
# > module is loaded. Its visual layout should nevertheless follow the same title,
# > section, indentation, label, description, and border conventions as normal menu
# > pages.
#
# -- Module Enable State ------------------------------------------------------------
#
# > The console persists enabled/disabled state for discoverable module files in the
# > console module state file. Disabled modules are omitted from the index and are
# > therefore never sourced during that console run.
# >
# > When the console runs as root, the main index adds a separate Console management
# > section with V) Manage visibility. That dialog discovers all module files without
# > sourcing them and toggles their persisted enabled/disabled state. The lightweight
# > index is rebuilt immediately when the dialog closes, so visibility changes do not
# > require a console restart. Non-root sessions do not display the visibility control.
#
# -- Action Status ------------------------------------------------------------------
#
# > Menu actions can record a transient/persisted result state such as never, success,
# > warning, or failed. sgnd-menu renders the corresponding status decoration while the
# > host owns the action-tracking lifecycle.
#
# -- SolidGroundUX Page -------------------------------------------------------------
#
# > The SolidGroundUX page manages the framework itself. It contains About information,
# > framework configuration and state, logging and diagnostics, and delegates release
# > lifecycle operations to the standalone release-manager rather than duplicating
# > installation/update logic in the console module.
#
# > release-manager remains independently executable so framework repair, rollback, or
# > removal does not depend on the framework being healthy enough to run the console.
#
# -- Storage Page -------------------------------------------------------------------
#
# > Storage is a separate Computer Management subject page. It owns local storage
# > provisioning, mounting, expansion, validation, status, ownership, group, and Unix
# > permission operations. File-service modules may depend on the resulting storage but
# > do not own its provisioning logic.
#
# -- Creating a New Console Module --------------------------------------------------
#
# > The normal workflow is:
#
# >     create an ordered source-only module file
# >         ↓
# >     define literal module name and description metadata
# >         ↓
# >     define helpers and menu action functions
# >         ↓
# >     register groups and items with sgnd_menu_*
# >         ↓
# >     place the file in the configured console module directory
#
# > No change to sgnd-console is required for a normal new page. On the next start the
# > module appears in the index and is loaded only if selected.
#
# -- Dedicated Console Applications -------------------------------------------------
#
# > sgnd-console still accepts --appcfg with either one module file or a directory of
# > modules. This allows the same host and menu engine to be reused for another console
# > application without copying either implementation.
#
# > A dedicated application using several modules receives the same index/lazy-loading
# > behavior. Supplying one module file produces an index containing that single page.
#
# -- Why This Architecture Matters --------------------------------------------------
#
# > The management console is not a collection of nested menu scripts. It is one host
# > with a lightweight page index and a set of lazily loaded functional modules.
#
# > This keeps startup work small, prevents duplicated UI mechanics, gives every module
# > a clear ownership boundary, and leaves operational scripts independently reusable.
# > The resulting model is simple: discover early, load only when needed, and keep what
# > has been used for the remainder of the session.
