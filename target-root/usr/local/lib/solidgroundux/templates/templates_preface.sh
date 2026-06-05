# ==================================================================================
# SolidGroundUX - Script templates 
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : deployment_preface.sh
#   Type        : documentation
#   Group       : Templates
#   Purpose     : Group preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - Templates -----------------------------------------------------------------------
#
# > The Templates group contains the starting points for creating new
# > SolidGroundUX-compatible scripts, libraries, console modules, and wrappers.
#
# > These templates are intended to capture the current recommended structure for
# > each type of component. Starting from a template helps keep bootstrap logic,
# > metadata headers, documentation comments, guards, naming conventions, and
# > runtime behavior consistent across projects.
#
# -- Template Overview --------------------------------------------------------------
#
# > The group contains four main templates:
#
# >     exe-template.sh
# >         Template for executable command-line tools.
#
# >     lib-template.sh
# >         Template for reusable source-only libraries.
#
# >     mod-template.sh
# >         Template for SolidGround Console modules.
#
# >     wrapper-template
# >         Template for lightweight launcher scripts.
#
# -- Executable Template ------------------------------------------------------------
#
# > The executable template is used for scripts that are intended to be run directly
# > by a user, administrator, scheduled task, or another process.
#
# > It contains the standard executable bootstrap block. This block resolves the
# > framework location, loads the bootstrap library, declares dependencies, prepares
# > framework globals, registers arguments, and hands control to the script's main
# > execution path.
#
# > New command-line tools should normally start from this template rather than
# > copying bootstrap code from an existing script. The template represents the
# > current intended executable structure.
#
# -- Library Template ---------------------------------------------------------------
#
# > The library template is used for reusable Bash libraries that are meant to be
# > sourced, not executed directly.
#
# > It contains the standard library guard pattern. The guard prevents accidental
# > direct execution, avoids repeated initialization when the same library is sourced
# > more than once, and marks the library as loaded before normal initialization
# > continues.
#
# > Libraries created from this template should expose reusable functionality
# > through public functions and keep implementation helpers internal where
# > appropriate.
#
# -- Console Module Template --------------------------------------------------------
#
# > The module template is used for modules loaded by the SolidGround Console host.
#
# > A console module is source-only. It registers menu groups and menu items when it
# > is loaded, but should not perform the actual action until the user selects the
# > corresponding menu item.
#
# > This pattern keeps console startup predictable while allowing functionality to be
# > added by dropping modules into the configured module directory.
#
# -- Wrapper Template ---------------------------------------------------------------
#
# > The wrapper template is used for small launcher scripts.
#
# > A wrapper should contain as little logic as possible. Its primary job is to
# > locate and invoke the real implementation script in the expected framework
# > location.
#
# > Wrappers keep user-facing commands short and stable while allowing the
# > implementation to live in the appropriate libexec or framework directory.
#
# -- Why Templates Matter -----------------------------------------------------------
#
# > The templates exist to prevent every script from becoming a slightly different
# > interpretation of the same framework rules.
#
# > They provide a known-good starting point for metadata, bootstrap structure,
# > documentation comments, guards, dependency declarations, and main execution
# > flow.
#
# > When framework conventions evolve, the templates should be updated first. New
# > scripts can then inherit the improved pattern without requiring developers to
# > rediscover the correct structure by reading older files.