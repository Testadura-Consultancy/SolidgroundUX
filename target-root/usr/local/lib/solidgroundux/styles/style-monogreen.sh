# =====================================================================================
# SolidgroundUX - Monochrome Green Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : none
#   Source      : style-monogreen.sh
#   Type        : library
#   Group       : Styles
#   Purpose     : Alternative style for testing pruposes
#
# Description:
#   Provides the default layout and styling rules used by the SolidgroundUX UI layer.
#
# Non-goals:
#   A pretty or ensible style
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
# --- say() global defaults ----------------------------------------------------
    SAY_DATE_DEFAULT="1"        # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="symbol"   # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="both"  # none|label|msg|both|all
    SAY_DATE_FORMAT="%a %H:%M:%S" 

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

# -- Colors --------------------------------------------------------------------
    # By message type
        MSG_CLR_INFO=$FAINT_GREEN
        MSG_CLR_STRT=$GREEN
        MSG_CLR_OK=$BOLD_GREEN
        MSG_CLR_WARN=$GREEN
        MSG_CLR_FAIL=$BOLD_GREEN
        MSG_CLR_CNCL=$FAINT_GREEN
        MSG_CLR_END=$FAINT_GREEN
        MSG_CLR_EMPTY=$FAINT_SILVER
    # Text elements
        TUI_LABEL=$GREEN
        TUI_MSG=$GREEN
        TUI_INPUT=$BOLD_GREEN
        TUI_TEXT=$FAINT_GREEN
        TUI_INVALID=$BOLD_GREEN
        TUI_VALID=$GREEN
        TUI_DEFAULT=$FAINT_SILVER
