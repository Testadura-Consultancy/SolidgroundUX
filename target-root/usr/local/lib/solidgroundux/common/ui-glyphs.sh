# =====================================================================================
# SolidgroundUX - UI Glyphs
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : 8ebc3d54151c1111ff4418082d1b0626cc590689a7134a33b3b543a0636eb836
#   Source      : ui-glyphs.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide glyph and symbol helpers for console rendering
#
# Description:
#   Defines reusable glyphs, symbols, and character helpers for use in
#   console output across the SolidgroundUX framework.
#
#   The library:
#     - Provides box-drawing characters and layout elements
#     - Defines commonly used symbols (checkmarks, arrows, separators, etc.)
#     - Encapsulates Unicode and ASCII fallbacks where needed
#     - Supports consistent visual language across all UI components
#
# Design principles:
#   - Centralize glyph definitions to avoid duplication
#   - Prefer readability and consistency over decorative complexity
#   - Allow graceful fallback for terminals with limited Unicode support
#   - Keep rendering concerns separate from glyph definition
#
# Role in framework:
#   - Foundational visual layer used by ui.sh and related UI modules
#   - Supports consistent styling across all console tools
#
# Non-goals:
#   - Rendering logic or layout behavior
#   - Terminal capability detection beyond basic fallback handling
#   - Theme or color management
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail

# --- Library guard ------------------------------------------------------------------
    # tmp: _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Behavior:
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
    _sgnd_lib_guard() {
        local lib_base
        local guard

        lib_base="$(basename "${BASH_SOURCE[0]}" .sh)"
        lib_base="${lib_base//-/_}"
        guard="SGND_${lib_base^^}_LOADED"

        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            printf 'This is a library; source it, do not execute it: %s\n' "${BASH_SOURCE[0]}" >&2
            exit 2
        }

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"
    
# --- Light line drawing ------------------------------------------------------------
    LN_H="─"
    LN_V="│"

    LN_TL="┌"
    LN_TR="┐"
    LN_BL="└"
    LN_BR="┘"

    LN_T="┬"
    LN_B="┴"
    LN_L="├"
    LN_R="┤"
    LN_X="┼"


# --- Double line drawing -----------------------------------------------------------
    DL_H="═"
    DL_V="║"

    DL_TL="╔"
    DL_TR="╗"
    DL_BL="╚"
    DL_BR="╝"

    DL_T="╦"
    DL_B="╩"
    DL_L="╠"
    DL_R="╣"
    DL_X="╬"

# --- Common characters -------------------------------------------------------------
    CH_DEG="°"
    CH_COPY="©"
    CH_TM="™"
    CH_REG="®"

    CH_BULLET="•"
    CH_ARROW="→"
    CH_ELLIPSIS="…"

# --- Math / comparison -------------------------------------------------------------
    CH_SQRT="√"
    CH_GE="≥"
    CH_LE="≤"
    CH_NE="≠"
    CH_APPROX="≈"
    CH_INF="∞"

# --- Keyboard hints ----------------------------------------------------------------
    KY_ENTER="↵"
    KY_UP="↑"
    KY_DOWN="↓"
    KY_LEFT="←"
    KY_RIGHT="→"

# --- Greek letters -----------------------------------------------------------------
    GR_ALPHA="α"
    GR_BETA="β"
    GR_GAMMA="γ"
    GR_DELTA="Δ"
    GR_PI="π"
    GR_OMEGA="Ω"


