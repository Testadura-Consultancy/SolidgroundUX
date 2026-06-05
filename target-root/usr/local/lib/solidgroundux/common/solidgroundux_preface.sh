# ==================================================================================
# SolidGroundUX - Framework Introduction
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
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

# - Raison d'être -------------------------------------------------------------------
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
