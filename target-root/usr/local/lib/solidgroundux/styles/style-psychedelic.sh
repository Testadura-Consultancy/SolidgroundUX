# =====================================================================================
# SolidGroundUX - Steel Blue UI Style
# -------------------------------------------------------------------------------------
# Type    : library
# Group   : Styles
# Purpose : Steel Blue-on-dark semantic UI style mapping
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

SGND_UI_BORDER=$BRIGHT_MAGENTA

SGND_UI_LABEL=$BRIGHT_CYAN
SGND_UI_VALUE=$BRIGHT_YELLOW

SGND_UI_COMMIT=$BRIGHT_GREEN
SGND_UI_DRYRUN=$BRIGHT_BLUE

SGND_UI_ENABLED=$BRIGHT_GREEN
SGND_UI_DISABLED=$MAGENTA

SGND_UI_INPUT=$BRIGHT_WHITE
SGND_UI_PROMPT=$BRIGHT_CYAN

SGND_UI_INVALID=$BRIGHT_RED
SGND_UI_VALID=$BRIGHT_GREEN

SGND_UI_ERROR="$(sgnd_sgr "$BRIGHT_YELLOW" "$RED" "$FX_BOLD")"
SGND_UI_SUCCESS="$(sgnd_sgr "$BLACK" "$BRIGHT_GREEN" "$FX_BOLD")"
SGND_UI_PROMPT="$(sgnd_sgr "$BRIGHT_CYAN" "$MAGENTA" "$FX_BOLD")"

SGND_UI_TEXT=$BRIGHT_MAGENTA
SGND_UI_DEFAULT=$BRIGHT_BLUE

PROG_TEXT_CLR=$BRIGHT_WHITE
PROG_IND_CLR=$BRIGHT_CYAN
PROG_BAR_CLR=$BRIGHT_MAGENTA
