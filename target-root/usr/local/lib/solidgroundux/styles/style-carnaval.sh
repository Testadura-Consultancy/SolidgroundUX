# =====================================================================================
# SolidGroundUX - Carnaval Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615900
#   Checksum    : 8e0009af291155793cfac2831ee26e39baccab4d1d85e6e13f888deb8c989da8
#   Source      : style-carnaval.sh
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
    SAY_DATE_DEFAULT=1    # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="all"   # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="all"  # none|label|msg|both|all
    SAY_DATE_FORMAT="%Y-%j %H:%M:%S" 
    # var: style_say_global_defaults - say() global defaults
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   SAY_DATE_DEFAULT = 1
        #   SAY_SHOW_DEFAULT = "all"   # label|icon|symbol|all|label,icon|...
        #   SAY_COLORIZE_DEFAULT = "all"  # none|label|msg|both|all
        #   SAY_DATE_FORMAT = "%Y-%j %H:%M:%S"
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
        SYM_CNCL="⏹"
        SYM_EMPTY=" "
        SYM_END="🏁"
        SYM_FAIL="✖"
        SYM_INFO="🛈"
        SYM_OK="✓"
        SYM_STRT="⮞"
        SYM_WARN="⚠"

        # var: style_say_prefixes - Say prefixes
            # . Purpose
            #   Document the variables assigned in this style section.
            #
            # Variables:
            #   SYM_CNCL = "⏹"
            #   SYM_EMPTY = " "
            #   SYM_END = "🏁"
            #   SYM_FAIL = "✖"
            #   SYM_INFO = "🛈"
            #   SYM_OK = "✓"
            #   SYM_STRT = "⮞"
            #   SYM_WARN = "⚠"
            #
            # Notes:
            #   Values are shown as assigned by this file. Referenced palette variables
            #   are resolved by the active palette when the style is sourced.
# -- Colors --------------------------------------------------------------------
    # By message type
        MSG_CLR_INFO=$BOLD_CYAN
        MSG_CLR_STRT=$BOLD_BLUE
        MSG_CLR_OK=$BOLD_GREEN
        MSG_CLR_WARN=$BOLD_YELLOW
        MSG_CLR_FAIL=$BOLD_RED
        MSG_CLR_CNCL=$BOLD_MAGENTA
        MSG_CLR_END=$BOLD_ORANGE
        MSG_CLR_EMPTY=$FAINT_SILVER
    # Text elements
        TUI_LABEL=$BOLD_MAGENTA
        TUI_MSG=$BOLD_BLUE
        TUI_INPUT=$BOLD_ORANGE
        TUI_TEXT=$BOLD_CYAN
        TUI_INVALID=$BOLD_RED
        TUI_VALID=$BOLD_GREEN
        TUI_DEFAULT=$FAINT_SILVER
        # var: style_colors - Colors
            # . Purpose
            #   Document the variables assigned in this style section.
            #
            # Variables:
            #   MSG_CLR_INFO = $BOLD_CYAN
            #   MSG_CLR_STRT = $BOLD_BLUE
            #   MSG_CLR_OK = $BOLD_GREEN
            #   MSG_CLR_WARN = $BOLD_YELLOW
            #   MSG_CLR_FAIL = $BOLD_RED
            #   MSG_CLR_CNCL = $BOLD_MAGENTA
            #   MSG_CLR_END = $BOLD_ORANGE
            #   MSG_CLR_EMPTY = $FAINT_SILVER
            #   TUI_LABEL = $BOLD_MAGENTA
            #   TUI_MSG = $BOLD_BLUE
            #   TUI_INPUT = $BOLD_ORANGE
            #   TUI_TEXT = $BOLD_CYAN
            #   TUI_INVALID = $BOLD_RED
            #   TUI_VALID = $BOLD_GREEN
            #   TUI_DEFAULT = $FAINT_SILVER
            #
            # Notes:
            #   Values are shown as assigned by this file. Referenced palette variables
            #   are resolved by the active palette when the style is sourced.
