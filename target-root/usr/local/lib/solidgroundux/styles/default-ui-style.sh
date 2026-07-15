# =====================================================================================
# SolidGroundUX - Default UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2619513
#   Checksum    : 76cd2dfc437b5d468fcaec58719cb04a0a1ededb6ecc2fa7a1a565c2524b6604
#   Source      : default-ui-style.sh
#   Type        : library
#   Group       : Styles
#   Purpose     : Define default UI layout, spacing, and styling conventions
#
# Description:
#   Provides the default layout and styling rules used by the SolidGroundUX UI layer.
#
#   The library:
#     - Defines spacing, padding, and alignment conventions
#     - Sets default widths for labels and columns
#     - Provides style constants for borders, separators, and layout elements
#     - Complements the color palette with structural presentation rules
#     - Ensures consistent visual composition across all console tools
#
# Design principles:
#   - Separate layout (style) from color (palette)
#   - Keep styling declarative and easy to override
#   - Favor readability and alignment over compactness
#   - Maintain consistency across all rendered output
#
# Role in framework:
#   - Structural styling layer used by ui.sh and related modules
#   - Works alongside default-ui-palette.sh to define the full UI theme
#   - Enables consistent layout behavior across scripts and tools
#
# Non-goals:
#   - Rendering logic or user interaction handling
#   - Terminal capability detection
#   - Dynamic layout adaptation beyond simple width awareness
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

# --- Message type labels and icons ---------------------------------------------------

  # --- say() global defaults ---------------------------------------------------
    SAY_DATE_DEFAULT=0     # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="label"   # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="label"  # none|label|msg|both|all
    SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S" 
  
    # var: style_say_global_defaults - say() global defaults
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   SAY_DATE_DEFAULT = 0
        #   SAY_SHOW_DEFAULT = "label"   # label|icon|symbol|all|label,icon|...
        #   SAY_COLORIZE_DEFAULT = "label"  # none|label|msg|both|all
        #   SAY_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
        #
        # Notes:
        #   Values are shown as assigned by this file. Referenced palette variables
        #   are resolved by the active palette when the style is sourced.
  # -- Say prefixes -------------------------------------------------------------
    # Labels
      LBL_CNCL="CANCEL"
      LBL_EMPTY="     "
      LBL_END="END"
      LBL_FAIL="ERROR"
      LBL_INFO="INFO"
      LBL_OK="SUCCESS"
      LBL_STRT="START"
      LBL_WARN="WARNING"
      LBL_DEBUG="DEBUG"

    # Icons
      ICO_CNCL=$'⏹️'
      ICO_EMPTY=$''
      ICO_END=$'🏁'
      ICO_FAIL=$'❌'
      ICO_INFO=$'ℹ️'
      ICO_OK=$'✅'
      ICO_STRT=$'▶️'
      ICO_WARN=$'⚠️'
      ICO_DEBUG=$'🐞'

    # Symbols
      SYM_CNCL="(-)"
      SYM_EMPTY=""
      SYM_END="<<<"
      SYM_FAIL="(X)"
      SYM_INFO="(+)"
      SYM_OK="(✓)"
      SYM_STRT=">>>"
      SYM_WARN="(!)"
      SYM_DEBUG="(~)"

      # var: style_say_prefixes - Say prefixes
          # . Purpose
          #   Document the variables assigned in this style section.
          #
          # Variables:
          #   LBL_CNCL = "CANCEL"
          #   LBL_EMPTY = "     "
          #   LBL_END = "END"
          #   LBL_FAIL = "ERROR"
          #   LBL_INFO = "INFO"
          #   LBL_OK = "SUCCESS"
          #   LBL_STRT = "START"
          #   LBL_WARN = "WARNING"
          #   LBL_DEBUG = "DEBUG"
          #   ICO_CNCL = $'⏹️'
          #   ICO_EMPTY = $''
          #   ICO_END = $'🏁'
          #   ICO_FAIL = $'❌'
          #   ICO_INFO = $'ℹ️'
          #   ICO_OK = $'✅'
          #   ICO_STRT = $'▶️'
          #   ICO_WARN = $'⚠️'
          #   ICO_DEBUG = $'🐞'
          #   SYM_CNCL = "(-)"
          #   SYM_EMPTY = ""
          #   SYM_END = "<<<"
          #   SYM_FAIL = "(X)"
          #   SYM_INFO = "(+)"
          #   SYM_OK = "(✓)"
          #   SYM_STRT = ">>>"
          #   SYM_WARN = "(!)"
          #   SYM_DEBUG = "(~)"
          #
          # Notes:
          #   Values are shown as assigned by this file. Referenced palette variables
          #   are resolved by the active palette when the style is sourced.
  # -- Colors -------------------------------------------------------------------
  # By message type
    MSG_CLR_INFO=$SILVER
    MSG_CLR_STRT=$BRIGHT_GREEN
    MSG_CLR_OK=$BRIGHT_GREEN
    MSG_CLR_WARN=$BRIGHT_ORANGE
    MSG_CLR_FAIL=$BRIGHT_RED
    MSG_CLR_CNCL=$YELLOW
    MSG_CLR_END=$BRIGHT_GREEN
    MSG_CLR_EMPTY=$DARK_SILVER
    MSG_CLR_DEBUG=$BRIGHT_MAGENTA

    PROG_BAR_CLR=$BRIGHT_CYAN
    PROG_IND_CLR=$BRIGHT_CYAN
    PROG_TEXT_CLR=$SILVER

  # CLI colors
    SGND_UI_BORDER=$BRIGHT_CYAN

    SGND_UI_LABEL=$SILVER
    SGND_UI_VALUE=$YELLOW  

    SGND_UI_COMMIT=$ORANGE
    SGND_UI_DRYRUN=$GREEN

    SGND_UI_ENABLED=$BRIGHT_WHITE
    SGND_UI_DISABLED=$DARK_WHITE
    SGND_UI_ON=$BRIGHT_GREEN
    SGND_UI_OFF=$DARK_SILVER

    SGND_UI_INPUT=$YELLOW
    SGND_UI_PROMPT=$BRIGHT_CYAN

    SGND_UI_INVALID=$ORANGE
    SGND_UI_VALID=$GREEN

    SGND_UI_SUCCESS=$BRIGHT_GREEN
    SGND_UI_ERROR=$BRIGHT_RED

    SGND_UI_TEXT=$SILVER

    SGND_UI_DEFAULT=$DARK_SILVER

    # var: style_colors - Colors
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   MSG_CLR_INFO = $SILVER
        #   MSG_CLR_STRT = $BRIGHT_GREEN
        #   MSG_CLR_OK = $BRIGHT_GREEN
        #   MSG_CLR_WARN = $BRIGHT_ORANGE
        #   MSG_CLR_FAIL = $BRIGHT_RED
        #   MSG_CLR_CNCL = $YELLOW
        #   MSG_CLR_END = $BRIGHT_GREEN
        #   MSG_CLR_EMPTY = $DARK_SILVER
        #   MSG_CLR_DEBUG = $BRIGHT_MAGENTA
        #   PROG_BAR_CLR = $BRIGHT_CYAN
        #   PROG_IND_CLR = $BRIGHT_CYAN
        #   PROG_TEXT_CLR = $SILVER
        #   SGND_UI_BORDER = $BRIGHT_CYAN
        #   SGND_UI_LABEL = $SILVER
        #   SGND_UI_VALUE = $YELLOW
        #   SGND_UI_COMMIT = $ORANGE
        #   SGND_UI_DRYRUN = $GREEN
        #   SGND_UI_ENABLED = $BRIGHT_WHITE
        #   SGND_UI_DISABLED = $DARK_WHITE
        #   SGND_UI_INPUT = $YELLOW
        #   SGND_UI_PROMPT = $BRIGHT_CYAN
        #   SGND_UI_INVALID = $ORANGE
        #   SGND_UI_VALID = $GREEN
        #   SGND_UI_SUCCESS = $BRIGHT_GREEN
        #   SGND_UI_ERROR = $BRIGHT_RED
        #   SGND_UI_TEXT = $SILVER
        #   SGND_UI_DEFAULT = $DARK_SILVER
        #
        # Notes:
        #   Values are shown as assigned by this file. Referenced palette variables
        #   are resolved by the active palette when the style is sourced.
