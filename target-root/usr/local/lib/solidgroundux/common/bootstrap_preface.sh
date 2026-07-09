
# ==================================================================================
# SolidGroundUX - Bootstrap Sequence
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.6
#   Build       : 2618812
#   Checksum    : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Source      : bootstrap_preface.sh
#   Type        : documentation
#   Group       : Bootstrap
#   Purpose     : Group preface
#
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
#   Checksum : 6f99c4cb18e1a37aa148ac40e0b5164cd9a01f5877fd364ea103ca38a5c54bb2
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - Bootstrap -----------------------------------------------------------------------
#
# > The bootstrap layer is the foundation of the SolidGroundUX runtime model.
#   
# > Its purpose is to give executable scripts and reusable libraries a predictable
# > starting point before application-specific logic begins. It resolves framework
# > locations, initializes common globals, loads requested libraries, prepares
# > configuration handling, and registers the framework's built-in command-line
# > arguments.
#   
# > In normal use, application scripts should not need to reproduce this logic.
# > Instead, they should follow the bootstrap section shown in the executable
# > template. The template demonstrates the expected startup pattern and should be
# > treated as the canonical example for new executable scripts.
#
# -- Bootstrap Sequence -------------------------------------------------------------
#
# > A typical executable script using SolidGroundUX starts with a small bootstrap
# > block. That block sources the framework bootstrap library and then hands control
# > to the framework initializer.
#   
# > Conceptually, the startup sequence is:
#   
# >     Script starts
# >         ↓
# >     Bootstrap file is located
# >        ↓
# >     Bootstrap environment is initialized
# >        ↓
# >     Standard SolidGroundUX globals are prepared
#          ↓
# >     Built-in command-line arguments are registered
# >         ↓
# >     Script-declared dependencies are resolved
#          ↓
# >     Core and requested libraries are sourced
#          ↓
# >     Configuration definitions are processed
#          ↓
# >     Command-line arguments are parsed
#          ↓
# >     Configuration values are loaded and applied
#          ↓
# >     Application code runs
#   
# > The exact implementation is intentionally hidden behind the bootstrap API. The
# > important point is that every bootstrapped script enters its main logic with the
# > same basic runtime assumptions.
#
# -- Bootstrap Environment ----------------------------------------------------------
#
# > The bootstrap environment is responsible for resolving the filesystem locations
# > used by the framework.
#   
# > This includes paths for framework libraries, internal helper scripts, shared
# > assets, configuration files, templates, documentation, and other expected
# > runtime locations.
#   
# > By resolving these paths centrally, scripts do not need to hard-code installation
# > paths or guess where framework components are located. This also allows the same
# > code to work both during development and after deployment, provided the expected
# > layout is available.
#
# -- Automatic Library Loading ------------------------------------------------------
#
# > SolidGroundUX uses a dependency declaration mechanism to determine which
# > libraries should be available to a script.
#   
# > Scripts can populate `SGND_USING` to declare framework libraries they depend on.
# > During bootstrap, the framework resolves these entries and sources the required
# > files automatically.
#   
# > This keeps executable scripts smaller and makes dependencies explicit near the
# > top of the file. Instead of scattering `source` statements throughout the script,
# > the script declares what it needs and lets the bootstrap layer perform the actual
# > loading.
#   
# > Core libraries needed by the bootstrap process itself are loaded automatically.
# > Additional libraries are loaded based on the script's declared requirements.
#
# -- Global Definitions -------------------------------------------------------------
#
# > The bootstrap process also prepares common SolidGroundUX global variables.
#   
# > These globals describe the runtime environment and provide shared values used by
# > other framework components. They may include resolved paths, script metadata,
# > runtime flags, configuration locations, and other common settings.
#   
# > When `SGND_GLOBALS` is populated by a script or library, the bootstrap and
# > configuration layers can use those definitions to prepare configurable values in
# > a consistent way.
#   
# > This mechanism helps bridge the gap between static script defaults,
# > configuration files, and command-line overrides.
#
# -- Configuration Management -------------------------------------------------------
#
# > Configuration handling is integrated into the bootstrap lifecycle.
#   
# > When configuration-related globals are available, the framework can initialize
# > configuration metadata, determine expected configuration files, load values, and
# > apply them before the main application logic runs.
#   
# > This means a script can define the values it cares about, while the framework
# > handles the repetitive work of loading, overriding, and exposing those values.
#   
# > The result is a consistent configuration model across scripts without requiring
# > every executable to implement its own configuration parser.
#
# -- Built-in Arguments -------------------------------------------------------------
#
# > Bootstrapped executables receive a set of framework-provided command-line
# > arguments.
#   
# > These built-in options cover common framework behavior such as help output,
# > version information, diagnostic output, tracing or debugging behavior, and
# > configuration-related overrides.
#   
# > Application-specific arguments can be added by the executable itself, but common
# > framework behavior remains standardized across all bootstrapped tools.
#   
# > This gives SolidGroundUX applications a shared command-line personality: once a
# > user understands the standard options for one tool, the same expectations apply
# > to the others.
#
# -- Relationship to the Executable Template ----------------------------------------
#
# > The executable template contains the preferred bootstrap structure for new
# > command-line tools.
#   
# > When creating a new SolidGroundUX executable, start from the template rather than
# > copying bootstrap code from an existing script by hand. Existing scripts may
# > contain historical details, local deviations, or project-specific behavior,
# > while the template represents the current intended pattern.
#   
# > In practical terms, the template shows where to declare dependencies, where to
# > define globals, where to register custom arguments, and where application logic
# > begins after bootstrap has completed.
#
# -- Why Bootstrap Matters ----------------------------------------------------------
#
# > The bootstrap layer exists to keep scripts boring in the best possible way.
#   
# > A bootstrapped executable does not need to rediscover the framework, reimplement
# > argument parsing, manually source every common library, or invent its own
# > configuration lifecycle.
#   
# > That work is centralized once, tested once, and reused everywhere.
#   
# > This is one of the main reasons SolidGroundUX behaves like a framework rather
# > than a collection of unrelated Bash helpers.
