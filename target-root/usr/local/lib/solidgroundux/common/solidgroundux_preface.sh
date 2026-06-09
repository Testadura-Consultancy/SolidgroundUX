# ==================================================================================
# SolidGroundUX - Framework Introduction
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615900
#   Checksum    : 09cbfbdfc06ea025342bc0e89fc346262dff09ed880d784f5ef465e6a71f7ad7
#   Source      : solidgroundux_preface.sh
#   Type        : documentation
#   Group       : SolidGroundUX
#   Purpose     : Product preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================

# - How it came to pass... ---------------------------------------------------------
# > During a period in which I found myself lacking mental challenges in my current project, I decided to explore
# > the Linux world. Frustrated with the current software market, I envisioned creating a subscription-free,
# > vendor-neutral, on-site software solution. This started with configuring a few VMs, which quickly led to
# > needing to learn Bash. I received a lot of help with syntax from ChatGPT, but I quickly concluded that I
# > didn't want to have to type printf, read, and other boilerplate every time I wanted to communicate with
# > the user or request input.
#   
# > Coming from the C#/.NET ecosystem required some adjustment, especially letting go of object-oriented
# > thinking. Even so, I found myself constantly looking for ways to make things more modular, reusable,
# > and consistent.
#   
# > To make a long story short, six months later I present to you SolidGroundUX: a modular, reusable,
# > consistent, and hopefully enjoyable framework for building console applications in Bash. Not bad for a
# > first Bash project. I haven't configured a single VM since I started building it, so I sometimes wonder
# > whether the original plan still works...
#   
# > I'm releasing this software on GitHub under the Testadura Non-Commercial License (TD-NC) v1.1. This means
# > you can use it free of charge for non-commercial purposes, even within a commercial environment. However,
# > if you wish to use it as part of a commercial product or project, we will need to discuss licensing terms.
#   
# > I hope this framework makes someone's life a little easier. If you have suggestions for improvements,
# > discover a bug, or would like to contribute, feel free to reach out.
#  
# ~  What's in a name?
#
# > The name SolidGround originates from a .NET ETL orchestration framework that I have been developing over
# > the past ten years. That product is currently awaiting its adaptation to Linux and the Avalonia UI
# > framework, after which it is intended to be released as a commercial product in the hopefully near future.
#   
# > The name SolidGroundUX is a nod to that project and reflects the same philosophy: providing solid,
# > practical foundations on which other software can be built.
#  
# - SolidGroundUX in a nutshell ------------------------------------------------------
#
# > SolidGroundUX is a framework for building structured Bash applications. It consists of a collection of
# > libraries, tools, templates, and conventions designed to reduce boilerplate and encourage consistency.
#   
# > The framework provides reusable functionality for handling command-line arguments, configuration files,
# > state variables, metadata, logging, user interaction, and documentation generation.
#   
# > At its core, SolidGroundUX follows a classic bootstrap architecture. The libraries sgnd-bootstrap.sh
# > and sgnd-bootstrap-env.sh provide a common initialization mechanism that can be used by both scripts
# > and libraries. This process establishes a predictable runtime environment, initializes commonly used
# > variables, resolves expected filesystem locations, and can automatically load required framework
# > components.
#   
# > To help developers get started quickly, the framework includes script templates for executable programs,
# > reusable libraries, and console modules. Console modules can be hosted by a modular menu-driven
# > application, allowing functionality to be added or removed without modifying the host application itself.
#   
# > Beyond the runtime framework, SolidGroundUX also includes tools for creating VS Code workspaces,
# > deploying projects, creating packages, editing metadata, and generating documentation.
#   
# > The documentation generator extracts documentation directly from source files and produces a navigable
# > HTML documentation set. The file doc-sample.sh demonstrates the documentation conventions used
# > throughout the framework and serves as a practical reference implementation.
#   
# > At present, the documentation system supports Bash source files, but the architecture has been designed
# > with future support for Python and C# in mind.

# - Framework capabilities summary --------------------------------------------------
#
# > SolidGroundUX can be used as a small runtime framework, a documentation system,
# > a console application host, and a deployment toolkit. The sections below provide
# > a compact map of the most important capabilities before the detailed module
# > documentation begins.
#
# -- Bootstrap and runtime initialization -------------------------------------------
#
# > The bootstrap libraries initialize the SolidGroundUX runtime environment for
# > executable scripts, reusable libraries, and console modules. They resolve common
# > filesystem locations, initialize standard globals, load configuration and state
# > support, and prepare the script for using framework services.
#
# > Typical use is through the executable, library, and module templates. A script
# > should bootstrap once near startup and then use framework functions instead of
# > repeating path discovery and initialization code locally.
#
# -- Library loading with sgnd_using -------------------------------------------------
#
# > The sgnd_using mechanism loads framework libraries on demand and keeps scripts
# > from having to source every possible dependency manually. It provides a simple
# > way to declare that a script needs a particular framework service before using it.
#
# > Use it when a script depends on functionality such as configuration, state,
# > logging, user interaction, or datatable helpers. This keeps scripts readable and
# > makes dependency intent visible near the code that needs it.
#
# -- Built-in and custom arguments ---------------------------------------------------
#
# > The argument framework provides common command-line behavior such as help,
# > verbose output, debug output, dry-run handling, and other standard script flags.
# > This gives SolidGroundUX scripts a consistent command-line feel.
#
# > Scripts can also define custom arguments for their own behavior. This allows a
# > script to combine framework-standard options with application-specific options
# > without rewriting argument parsing from scratch every time.
#
# -- Configuration management --------------------------------------------------------
#
# > The configuration system provides a reusable way to read and manage configuration
# > values for scripts and framework components. It helps keep operational settings
# > outside the script body while still making them accessible through standard
# > framework calls.
#
# > Use configuration support when a value should be user-editable, environment-
# > specific, or shared across multiple scripts. This is generally preferable to
# > hardcoding local paths, defaults, and behavior switches throughout a script.
#
# -- State management ----------------------------------------------------------------
#
# > The state system stores runtime or persistent values that describe the current
# > framework, script, or user state. It is intended for values that are discovered,
# > derived, or changed during execution rather than static configuration.
#
# > Use state support for values that need to survive across function boundaries or
# > be reused by framework components without forcing every function to pass the same
# > values around explicitly.
#
# -- Screen logging and user messages ------------------------------------------------
#
# > The screen logging helpers provide consistent user-facing output for information,
# > warnings, errors, success messages, debug messages, and status reporting. They
# > reduce repeated printf boilerplate and keep scripts visually consistent.
#
# > Use the screen logging helpers whenever a script communicates with the user.
# > This makes output easier to scan and gives all tools a shared SolidGroundUX
# > command-line style.
#
# -- File logging --------------------------------------------------------------------
#
# > File logging provides persistent logging for scripts that need traceability
# > beyond the current terminal session. It is useful for deployment, automation,
# > diagnostics, and any script where later inspection of what happened matters.
#
# > Use file logging for operations that change system state, touch files, perform
# > deployment actions, or may need to be reviewed after failure.
#
# -- Pretty UI and dialogs -----------------------------------------------------------
#
# > The UI helpers provide higher-level console interaction patterns such as banners,
# > prompts, formatted messages, questions, and confirmation flows. They are intended
# > to make interactive scripts feel deliberate instead of improvised.
#
# > The auto-continue dialog is part of this interaction style. It gives scripts a
# > standard way to pause, inform the user, and continue automatically or after user
# > confirmation depending on the selected behavior.
#
# -- Datatable helpers ---------------------------------------------------------------
#
# > The datatable helpers provide functions for treating pipe-separated arrays as
# > rows in a lightweight table-like structure. This makes it easier to pass around,
# > inspect, and process structured row data in Bash without introducing heavier
# > external dependencies.
#
# > Use datatable support when a script needs to work with repeated structured data,
# > such as menu entries, generated lists, metadata rows, selection candidates, or
# > other small tabular datasets.
#
# -- Modular console host ------------------------------------------------------------
#
# > The SolidGroundUX console provides a menu-driven host application that can load
# > independently maintained modules. Modules register menu groups and commands with
# > the host, allowing the console to grow without hardcoding every action into one
# > large script.
#
# > Use console modules for administrative or SDK actions that benefit from an
# > interactive menu, especially when those actions belong to different functional
# > groups but should remain available from one common entry point.
#
# -- Documentation generator ---------------------------------------------------------
#
# > The documentation generator extracts module headers, function documentation,
# > variable documentation, general documentation blocks, glossaries, hierarchy data,
# > and appendices from the source tree and renders a navigable HTML documentation
# > set.
#
# > Use the documentation conventions demonstrated by doc-sample.sh when writing new
# > scripts or modules. Keeping documentation close to the code allows the generated
# > documentation to stay synchronized with the implementation.
#
# -- SDK templates -------------------------------------------------------------------
#
# > The SDK templates provide starting points for executable scripts, reusable
# > libraries, and console modules. They encode the expected module header, bootstrap,
# > guard, documentation, and entry-point structure.
#
# > Use templates when starting new SolidGroundUX components. This keeps new code
# > aligned with the framework conventions and reduces the amount of structural code
# > that has to be recreated manually.
#
# -- Workspace and deployment tools --------------------------------------------------
#
# > The SDK tools can create workspaces, deploy workspace content, prepare release
# > packages, install releases, update existing installations, and uninstall installed
# > releases. Together, these tools provide a simple development-to-deployment flow.
#
# > The intended release flow is to update the source tree, regenerate documentation,
# > run the release preparation tool, validate the generated manifest and checksums,
# > and then install or update from the generated release archive.
# - Architecture --------------------------------------------------------------------
#
# > SolidGroundUX is designed as a framework rather than a collection of unrelated
# > helper scripts. The goal is to provide a consistent and reusable foundation for
# > building structured Bash applications while minimizing repetitive boilerplate.
#   
# > Although implemented entirely in Bash, many of the architectural principles are
# > inspired by modern application frameworks. Concepts such as separation of concerns,
# > modularity, convention over configuration, documentation-driven development, and
# > reusable components are applied throughout the framework.
#
# -- Layered Architecture ------------------------------------------------------------
#
# > The framework is organized into several logical layers.
#   
# > At the foundation are the core libraries. These provide reusable functionality
# > such as configuration management, state handling, command-line argument processing,
# > user interaction, metadata handling, logging, deployment support, and
# > documentation generation.
#   
# > Above the library layer are executable applications. These are standalone tools
# > such as workspace generators, deployment utilities, package builders, metadata
# > editors, and documentation generators.
#   
# > The framework also supports modular console applications. Independent modules can
# > register menu groups and menu items with a common host application, providing a
# > lightweight plugin architecture implemented entirely in Bash.
#
# -- Bootstrap Architecture ----------------------------------------------------------
#
# > The bootstrap system is the heart of the framework.
#   
# > Rather than requiring every script to discover filesystem locations, load
# > libraries, initialize configuration, and prepare runtime variables independently,
# > the bootstrap libraries provide a standardized initialization sequence.
#   
# > A typical startup sequence consists of:
#   
# >     Script startup
# >         ↓
# >     Bootstrap initialization
# >         ↓
# >     Environment discovery
# >         ↓
# >     Framework path resolution
# >         ↓
# >     Configuration initialization
# >         ↓
# >     State initialization
# >         ↓
# >     Library loading
# >         ↓
# >     Application execution
#   
# > By centralizing initialization logic, application scripts remain focused on their
# > actual purpose rather than infrastructure concerns.
#
# -- Public and Internal APIs --------------------------------------------------------
#
# > SolidGroundUX uses naming conventions to distinguish public APIs from internal
# > implementation details.
#   
# > Public functions use the sgnd_ prefix and are intended for use by framework users
# > and framework components.
# >
# > Internal helper functions use a leading underscore and should be considered
# > private implementation details. Bash, of course, does not enforce access
# > restrictions, and I am not going to claim that I have always been perfectly
# > true to this convention. It is, however, an attempt to at least indicate intent.
#   
# > Consumers should avoid relying on internal functions, as their behavior may
# > change between framework releases.
#
# -- Convention Over Configuration ---------------------------------------------------
#
# > One of the primary design goals of SolidGroundUX is reducing repetitive code.
#   
# > Common functionality such as argument processing, configuration loading, state
# > management, user interaction, documentation generation, and deployment support
# > are implemented once and reused throughout the framework.
#   
# > Developers remain free to override framework behavior when necessary, but most
# > applications can rely on framework conventions and focus primarily on business
# > logic.
