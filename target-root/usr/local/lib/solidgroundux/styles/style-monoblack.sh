# =====================================================================================
# SolidGroundUX - Monochrome Black Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615900
#   Checksum    : a40edd148016af1471e3bc2609f7dcc1ed62940eee3b3d5c9e68a9691da0f5d7
#   Source      : style-monoblack.sh
#   Type        : library
#   Group       : Styles
#   Purpose     : Alternative style for testing purposes
#
# Description:
#   Provides the default layout and styling rules used by the SolidGroundUX UI layer.
#
# Non-goals:
#   A pretty or sensible style
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
# --- say() global defaults ----------------------------------------------------
    SAY_DATE_DEFAULT=0     # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="symbol"   # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="both"  # none|label|msg|both|all
    SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S" 

    # var: style_say_global_defaults - say() global defaults
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   SAY_DATE_DEFAULT = 0
        #   SAY_SHOW_DEFAULT = "symbol"   # label|icon|symbol|all|label,icon|...
        #   SAY_COLORIZE_DEFAULT = "both"  # none|label|msg|both|all
        #   SAY_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
        #
        # Notes:
        #   Values are shown as assigned by this file. Referenced palette variables
        #   are resolved by the active palette when the style is sourced.
# -- Say prefixes --------------------------------------------------------------
    # Labels
      #LBL_CNCL="[CNCL]"
      #LBL_EMPTY="     "
      #LBL_END="[ END]"
      #LBL_FAIL="[FAIL]"
      #LBL_INFO="[INFO]"
      #LBL_OK="[ OK ]"
      #LBL_STRT="[STRT]"
      #LBL_WARN="[WARN]"

    # Icons
      #ICO_CNCL=$'⏹️'
      #ICO_EMPTY=$''
      #ICO_END=$'🏁'
      #ICO_FAIL=$'❌'
      #ICO_INFO=$'ℹ️'
      #ICO_OK=$'✅'
      #ICO_STRT=$'▶️'
      #ICO_WARN=$'⚠️'

    # Symbols
      SYM_CNCL="(-)"
      SYM_EMPTY=""
      SYM_END="<<<"
      SYM_FAIL="(X)"
      SYM_INFO="(+)"
      SYM_OK="(✓)"
      SYM_STRT=">>>"
      SYM_WARN="(!)"

      # var: style_say_prefixes - Say prefixes
          # . Purpose
          #   Document the variables assigned in this style section.
          #
          # Variables:
          #   SYM_CNCL = "(-)"
          #   SYM_EMPTY = ""
          #   SYM_END = "<<<"
          #   SYM_FAIL = "(X)"
          #   SYM_INFO = "(+)"
          #   SYM_OK = "(✓)"
          #   SYM_STRT = ">>>"
          #   SYM_WARN = "(!)"
          #
          # Notes:
          #   Values are shown as assigned by this file. Referenced palette variables
          #   are resolved by the active palette when the style is sourced.
# -- Colors --------------------------------------------------------------------
  # By message type
    MSG_CLR_INFO=$SILVER
    MSG_CLR_STRT=$BOLD_SILVER
    MSG_CLR_OK=$BOLD_SILVER
    MSG_CLR_WARN=$SILVER
    MSG_CLR_FAIL=$BOLD_BLACK
    MSG_CLR_CNCL=$FAINT_BLACK
    MSG_CLR_END=$FAINT_SILVER
    MSG_CLR_EMPTY=$FAINT_SILVER
  # Text elements
    TUI_LABEL=$BOLD_SILVER
    TUI_MSG=$SILVER
    TUI_INPUT=$SILVER
    TUI_TEXT=$FAINT_SILVER
    TUI_INVALID=$BOLD_BLACK
    TUI_VALID=$SILVER
    TUI_DEFAULT=$FAINT_SILVER
    # var: style_colors - Colors
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   MSG_CLR_INFO = $SILVER
        #   MSG_CLR_STRT = $BOLD_SILVER
        #   MSG_CLR_OK = $BOLD_SILVER
        #   MSG_CLR_WARN = $SILVER
        #   MSG_CLR_FAIL = $BOLD_BLACK
        #   MSG_CLR_CNCL = $FAINT_BLACK
        #   MSG_CLR_END = $FAINT_SILVER
        #   MSG_CLR_EMPTY = $FAINT_SILVER
        #   TUI_LABEL = $BOLD_SILVER
        #   TUI_MSG = $SILVER
        #   TUI_INPUT = $SILVER
        #   TUI_TEXT = $FAINT_SILVER
        #   TUI_INVALID = $BOLD_BLACK
        #   TUI_VALID = $SILVER
        #   TUI_DEFAULT = $FAINT_SILVER
        #
        # Notes:
        #   Values are shown as assigned by this file. Referenced palette variables
        #   are resolved by the active palette when the style is sourced.
