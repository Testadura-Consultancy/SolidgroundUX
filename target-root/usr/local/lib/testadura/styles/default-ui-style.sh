# =====================================================================================
# SolidgroundUX - Default UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608201
#   Checksum    : 8c840adf092daf880ea9cc21de6cb6be06cf5b530527cf120cb874b082ced5bd
#   Source      : default-ui-style.sh
#   Type        : library
#   Purpose     : Define default UI layout, spacing, and styling conventions
#
# Description:
#   Provides the default layout and styling rules used by the SolidgroundUX UI layer.
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
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================

# --- Message type labels and icons ---------------------------------------------------

  # --- say() global defaults ---------------------------------------------------
    SAY_DATE_DEFAULT=0     # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="label"   # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="label"  # none|label|msg|both|all
    SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S" 
  
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

  # CLI colors
    TUI_BORDER=$BRIGHT_CYAN

    TUI_LABEL=$SILVER
    TUI_VALUE=$YELLOW  

    TUI_COMMIT=$ORANGE
    TUI_DRYRUN=$GREEN

    TUI_ENABLED=$BRIGHT_WHITE
    TUI_DISABLED=$DARK_WHITE

    TUI_INPUT=$YELLOW
    TUI_PROMPT=$BRIGHT_CYAN

    TUI_INVALID=$ORANGE
    TUI_VALID=$GREEN

    TUI_SUCCESS=$BRIGHT_GREEN
    TUI_ERROR=$BRIGHT_RED

    TUI_TEXT=$SILVER

    TUI_DEFAULT=$DARK_SILVER

