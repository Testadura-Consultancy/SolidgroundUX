# ==================================================================================
# SolidGroundUX - Framework Services Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615900
#   Checksum    : e200aac99ed20ec670214866399444f12f748505e652085c12dbce216d353344
#   Source      : common core_preface.sh
#   Type        : documentation
#   Group       : Common Core
#   Purpose     : Group preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
#  
# - Available Services -----------------------------------------------------------------
#
# > This chapter introduces the major framework services available to application
# > developers. While each subsystem is documented individually, this overview
# > explains how the various components work together.
#  
# -- Configuration Management --------------------------------------------------------
#  
# > The configuration subsystem provides a consistent mechanism for loading,
# > validating, modifying, and persisting application settings.
#  
# > Configuration values typically represent user preferences or application
# > settings that remain relatively static between executions.
#  
# -- State Management ----------------------------------------------------------------
#  
# > The state subsystem stores runtime information that applications may wish to
# > remember between executions.
#  
# > Unlike configuration values, state information represents remembered runtime
# > conditions such as previous selections, recently opened resources, window
# > positions, or cached information.
#  
# -- Command-Line Arguments ----------------------------------------------------------
#  
# > The argument subsystem provides standardized command-line processing. Each exectable
# > after the bootstrapper is complete the script's own arguments as well as framework-supplied options.
# > This include built-in support for version reporting, help output, tracing, debugging, and configuration overrides.
#   
# > Applications may define custom arguments while also benefiting from framework
# > supplied options such as version reporting, help output, tracing, debugging,
# > and configuration overrides.
#
# -- User Interface Services ---------------------------------------------------------
#
# > The UI subsystem provides a collection of functions intended to simplify
# > communication with the user.
#   
# > Common operations such as informational messages, warnings, errors,
# > confirmations, prompts, selections, and formatted output are provided through
# > a consistent interface.
#
# -- Console Applications ------------------------------------------------------------
#
# > The console framework allows applications to expose functionality through a
# > menu-driven interface.
#   
# > Functionality is organized into groups and menu items. Individual modules can
# > register their own functionality, allowing menu structures to be assembled
# > dynamically at runtime.
#
# -- Documentation Generation --------------------------------------------------------
#
# > The documentation generator extracts documentation directly from source files.
#   
# > Product information, architecture descriptions, API documentation, appendices,
# > glossaries, and implementation notes are all maintained close to the source
# > code and transformed into a navigable HTML documentation set.
#  
# > This approach helps ensure that documentation remains synchronized with the
# > implementation and reduces the risk of documentation becoming outdated.
