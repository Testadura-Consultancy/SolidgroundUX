# =====================================================================================
# SolidGroundUX - Monochrome Amber UI Style
# -------------------------------------------------------------------------------------
# Type    : library
# Group   : Styles
# Purpose : Amber-on-dark semantic UI style mapping
# =====================================================================================

# --- say() global defaults -----------------------------------------------------------
SAY_DATE_DEFAULT=0
SAY_SHOW_DEFAULT="label"
SAY_COLORIZE_DEFAULT="label"
SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

# --- Say prefixes --------------------------------------------------------------------
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

# --- Semantic colors -----------------------------------------------------------------
MSG_CLR_INFO=$GOLD
MSG_CLR_STRT=$BRIGHT_GOLD
MSG_CLR_OK=$BRIGHT_GOLD
MSG_CLR_WARN=$BRIGHT_ORANGE
MSG_CLR_FAIL=$BRIGHT_RED
MSG_CLR_CNCL=$DARK_GOLD
MSG_CLR_END=$BRIGHT_GOLD
MSG_CLR_EMPTY=$DARK_BROWN
MSG_CLR_DEBUG=$DARK_ORANGE

PROG_BAR_CLR=$BRIGHT_GOLD
PROG_IND_CLR=$BRIGHT_ORANGE
PROG_TEXT_CLR=$GOLD

TUI_BORDER=$DARK_ORANGE
TUI_LABEL=$GOLD
TUI_VALUE=$BRIGHT_GOLD
TUI_COMMIT=$BRIGHT_ORANGE
TUI_DRYRUN=$DARK_GOLD
TUI_ENABLED=$BRIGHT_GOLD
TUI_DISABLED=$DARK_BROWN
TUI_INPUT=$BRIGHT_GOLD
TUI_PROMPT=$BRIGHT_ORANGE
TUI_INVALID=$BRIGHT_RED
TUI_VALID=$BRIGHT_GOLD
TUI_SUCCESS=$BRIGHT_GOLD
TUI_ERROR=$BRIGHT_RED
TUI_TEXT=$GOLD
TUI_DEFAULT=$DARK_BROWN
