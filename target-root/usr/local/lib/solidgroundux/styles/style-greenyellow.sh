# =====================================================================================
# SolidGroundUX - Green Yellow Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : style-greenyellow.sh
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
    SAY_DATE_DEFAULT=0       # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="label, symbol"   # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT=label  # none|label|msg|both|all
    SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S" 
    
    # var: style_say_global_defaults - say() global defaults
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   SAY_DATE_DEFAULT = 0
        #   SAY_SHOW_DEFAULT = "label, symbol"   # label|icon|symbol|all|label,icon|...
        #   SAY_COLORIZE_DEFAULT = label
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
        SYM_INFO="i"
        SYM_STRT=">"
        SYM_OK="+"
        SYM_WARN="!"
        SYM_FAIL="x"
        SYM_CNCL="/"
        SYM_EMPTY=" "

        # var: style_say_prefixes - Say prefixes
            # . Purpose
            #   Document the variables assigned in this style section.
            #
            # Variables:
            #   SYM_INFO = "i"
            #   SYM_STRT = ">"
            #   SYM_OK = "+"
            #   SYM_WARN = "!"
            #   SYM_FAIL = "x"
            #   SYM_CNCL = "/"
            #   SYM_EMPTY = " "
            #
            # Notes:
            #   Values are shown as assigned by this file. Referenced palette variables
            #   are resolved by the active palette when the style is sourced.
# -- Colors --------------------------------------------------------------------
    # By message type
        MSG_CLRINFO=$GREEN
        MSG_CLRSTRT=$BOLD_GREEN
        MSG_CLROK=$BOLD_GREEN
        MSG_CLRWARN=$BOLD_YELLOW
        MSG_CLRFAIL=$BOLD_RED
        MSG_CLRCNCL=$FAINT_RED
        MSG_CLREND=$FAINT_SILVER
        MSG_CLREMPTY=$FAINT_SILVER
    # Text elements
        TUI_LABEL=$GREEN
        TUI_MSG=$ITALIC_GREEN
        TUI_INPUT=$YELLOW
        TUI_TEXT=$YELLOW
        TUI_INVALID=$ORANGE
        TUI_VALID=$GREEN
        TUI_DEFAULT=$FAINT_SILVER
        # var: style_colors - Colors
            # . Purpose
            #   Document the variables assigned in this style section.
            #
            # Variables:
            #   MSG_CLRINFO = $GREEN
            #   MSG_CLRSTRT = $BOLD_GREEN
            #   MSG_CLROK = $BOLD_GREEN
            #   MSG_CLRWARN = $BOLD_YELLOW
            #   MSG_CLRFAIL = $BOLD_RED
            #   MSG_CLRCNCL = $FAINT_RED
            #   MSG_CLREND = $FAINT_SILVER
            #   MSG_CLREMPTY = $FAINT_SILVER
            #   TUI_LABEL = $GREEN
            #   TUI_MSG = $ITALIC_GREEN
            #   TUI_INPUT = $YELLOW
            #   TUI_TEXT = $YELLOW
            #   TUI_INVALID = $ORANGE
            #   TUI_VALID = $GREEN
            #   TUI_DEFAULT = $FAINT_SILVER
            #
            # Notes:
            #   Values are shown as assigned by this file. Referenced palette variables
            #   are resolved by the active palette when the style is sourced.
