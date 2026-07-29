# =====================================================================================
# SolidGroundUX - Dark UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621011
#   Checksum    : 59340bf0ad2f08a988455b36091bb81e19cc1437e0d8de15f84d4c9f56f86274
#   Source      : 10-style-dark.sh
#   Type        : library
#   Group       : Styles
#   Purpose     : Define the Dark semantic UI theme
#
# Description:
#   Provides a balanced dark semantic UI theme designed for clear, everyday console use.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

SAY_DATE_DEFAULT=0
SAY_SHOW_DEFAULT="label"
SAY_COLORIZE_DEFAULT="label"
SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

LBL_CNCL="CANCEL"
LBL_EMPTY="     "
LBL_END="END"
LBL_FAIL="ERROR"
LBL_INFO="INFO"
LBL_OK="SUCCESS"
LBL_STRT="START"
LBL_WARN="WARNING"
LBL_DEBUG="DEBUG"

ICO_CNCL=$'[STOP]'
ICO_EMPTY=$''
ICO_END=$'[END]'
ICO_FAIL=$'[ERR]'
ICO_INFO=$'[INF]'
ICO_OK=$'[OK]'
ICO_STRT=$'[RUN]'
ICO_WARN=$'[WRN]'
ICO_DEBUG=$'[DBG]'

SYM_CNCL="(-)"
SYM_EMPTY=""
SYM_END="<<<"
SYM_FAIL="(X)"
SYM_INFO="(+)"
SYM_OK="(+)"
SYM_STRT=">>>"
SYM_WARN="(!)"
SYM_DEBUG="(~)"

# Message output
MSG_CLR_INFO=$SILVER
MSG_CLR_STRT=$BRIGHT_CYAN
MSG_CLR_OK=$BRIGHT_GREEN
MSG_CLR_WARN=$BRIGHT_ORANGE
MSG_CLR_FAIL=$BRIGHT_RED
MSG_CLR_CNCL=$YELLOW
MSG_CLR_END=$BRIGHT_CYAN
MSG_CLR_EMPTY=$DARK_SILVER
MSG_CLR_DEBUG=$BRIGHT_MAGENTA

# Progress display
PROG_BAR_CLR=$GRAY
PROG_IND_CLR=$BRIGHT_CYAN
PROG_TEXT_CLR=$SILVER

# General UI elements
SGND_UI_BORDER=$GRAY
SGND_UI_LABEL=$SILVER
SGND_UI_VALUE=$BRIGHT_WHITE
SGND_UI_TEXT=$SILVER

# Title bar
SGND_TITLE_TEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_TITLE_BORDER=$DL_H
SGND_TITLE_SUBTEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")"
SGND_TITLE_RIGHTCLR=$SGND_TITLE_TEXTCLR
SGND_TITLE_BORDERCLR=$SGND_UI_BORDER

# Section headers
SGND_SECTION_TEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_SECTION_BORDER=$LN_H
SGND_SECTION_BORDERCLR=$SGND_UI_BORDER

SGND_UI_DEFAULT=$DARK_SILVER

# Run modes
SGND_UI_COMMIT=$BRIGHT_ORANGE
SGND_UI_DRYRUN=$GREEN

# States and validation
SGND_UI_ENABLED=$BRIGHT_WHITE
SGND_UI_DISABLED=$DARK_GRAY
SGND_UI_ON=$BRIGHT_GREEN
SGND_UI_OFF=$DARK_SILVER
SGND_UI_VALID=$GREEN
SGND_UI_INVALID=$BRIGHT_ORANGE
SGND_UI_SUCCESS=$BRIGHT_GREEN
SGND_UI_ERROR=$BRIGHT_RED

# Prompt and input
SGND_UI_PROMPT=$BRIGHT_CYAN
SGND_UI_INPUT=$BRIGHT_WHITE

# --- Documentation summaries ---------------------------------------------------------
    # var: style_say_global_defaults - say() global defaults
        # . Purpose
        #   Document the variables assigned in this style file.
        #
        # Variables:
        #   SAY_DATE_DEFAULT = 0
        #   SAY_SHOW_DEFAULT = "label"
        #   SAY_COLORIZE_DEFAULT = "label"
        #   SAY_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.

    # var: style_say_prefixes - Say prefixes
        # . Purpose
        #   Document the variables assigned in this style file.
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
        #   ICO_CNCL = $'[STOP]'
        #   ICO_EMPTY = $''
        #   ICO_END = $'[END]'
        #   ICO_FAIL = $'[ERR]'
        #   ICO_INFO = $'[INF]'
        #   ICO_OK = $'[OK]'
        #   ICO_STRT = $'[RUN]'
        #   ICO_WARN = $'[WRN]'
        #   ICO_DEBUG = $'[DBG]'
        #   SYM_CNCL = "(-)"
        #   SYM_EMPTY = ""
        #   SYM_END = "<<<"
        #   SYM_FAIL = "(X)"
        #   SYM_INFO = "(+)"
        #   SYM_OK = "(+)"
        #   SYM_STRT = ">>>"
        #   SYM_WARN = "(!)"
        #   SYM_DEBUG = "(~)"
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.

    # var: style_colors - Colors
        # . Purpose
        #   Document the variables assigned in this style file.
        #
        # Variables:
        #   MSG_CLR_INFO = $SILVER
        #   MSG_CLR_STRT = $BRIGHT_CYAN
        #   MSG_CLR_OK = $BRIGHT_GREEN
        #   MSG_CLR_WARN = $BRIGHT_ORANGE
        #   MSG_CLR_FAIL = $BRIGHT_RED
        #   MSG_CLR_CNCL = $YELLOW
        #   MSG_CLR_END = $BRIGHT_CYAN
        #   MSG_CLR_EMPTY = $DARK_SILVER
        #   MSG_CLR_DEBUG = $BRIGHT_MAGENTA
        #   PROG_BAR_CLR = $GRAY
        #   PROG_IND_CLR = $BRIGHT_CYAN
        #   PROG_TEXT_CLR = $SILVER
        #   SGND_UI_BORDER = $GRAY
        #   SGND_UI_LABEL = $SILVER
        #   SGND_UI_VALUE = $BRIGHT_WHITE
        #   SGND_UI_TEXT = $SILVER
        #   SGND_TITLE_TEXTCLR = bold SGND_UI_TEXT
        #   SGND_TITLE_BORDER = $DL_H
        #   SGND_TITLE_SUBTEXTCLR = italic SGND_UI_TEXT
        #   SGND_TITLE_RIGHTCLR = SGND_TITLE_TEXTCLR
        #   SGND_TITLE_BORDERCLR = SGND_UI_BORDER
        #   SGND_SECTION_TEXTCLR = bold SGND_UI_TEXT
        #   SGND_SECTION_BORDER = $LN_H
        #   SGND_SECTION_BORDERCLR = SGND_UI_BORDER
        #   SGND_UI_DEFAULT = $DARK_SILVER
        #   SGND_UI_COMMIT = $BRIGHT_ORANGE
        #   SGND_UI_DRYRUN = $GREEN
        #   SGND_UI_ENABLED = $BRIGHT_WHITE
        #   SGND_UI_DISABLED = $DARK_GRAY
        #   SGND_UI_ON = $BRIGHT_GREEN
        #   SGND_UI_OFF = $DARK_SILVER
        #   SGND_UI_VALID = $GREEN
        #   SGND_UI_INVALID = $BRIGHT_ORANGE
        #   SGND_UI_SUCCESS = $BRIGHT_GREEN
        #   SGND_UI_ERROR = $BRIGHT_RED
        #   SGND_UI_PROMPT = $BRIGHT_CYAN
        #   SGND_UI_INPUT = $BRIGHT_WHITE
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.
