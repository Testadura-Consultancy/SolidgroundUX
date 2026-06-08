# =====================================================================================
# SolidGroundUX - UI Rendering
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615900
#   Checksum    : 74e04b6a49ce86d70dcbb70e80eae2083c596a497a82c563e5ee88f0ea5f5db9
#   Source      : ui.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide terminal rendering utilities for styled console output
#
# Description:
#   Provides the core rendering layer for styled terminal output within
#   the SolidGroundUX framework.
#
#   The library:
#     - Defines reusable rendering helpers for text and layout
#     - Applies ANSI colors and text attributes through centralized helpers
#     - Renders labeled values, section headers, title bars, and filled lines
#     - Supports width-aware formatting for terminal output
#     - Provides standardized message and presentation conventions
#
# Design principles:
#   - Centralized styling without inline ANSI codes in consuming modules
#   - Readability over visual complexity
#   - Graceful degradation when styling is disabled or unavailable
#   - Consistent rendering semantics across all console tools
#
# Role in framework:
#   - Core visual layer for console-based SolidGroundUX tooling
#   - Supports higher-level interaction modules such as ui-ask and sgnd-console
#
# Non-goals:
#   - Input handling or dialog flow control
#   - Full terminal capability abstraction beyond framework needs
#   - Graphical or window-based user interface functionality
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Library guard
        # . Purpose
        #   Prevent direct execution of a source-only module and avoid repeated initialization.
        #
        # . Behavior
        #   - Derives a module-specific guard variable from the current filename.
        #   - Exits with status 2 when the file is executed directly.
        #   - Returns immediately when the module has already been loaded.
        #   - Marks the module as loaded before normal initialization continues.
        #
        # . Returns
        #   0 when the module may continue loading or was already loaded.
        #   Exits with status 2 when executed directly.
        #
        # . Usage
        #   _sgnd_lib_guard
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

# --- Compatibility overrides --------------------------------------------------------
    # Shims to integrate with legacy helpers if present (say/ask), with safe fallbacks.
    # These overrides are intentionally small and policy-free.

    # _sh_err
        # . Purpose
        #   Compatibility shim for legacy "_sh_err" error reporting.
        #
        # . Behavior
        #   - If say() exists, emits a FAIL message via say --type FAIL.
        #   - Otherwise prints the message directly to stderr.
        #
        # . Arguments
        #   $*  MESSAGE
        #       Error text to report.
        #
        # . Side effects
        #   - Writes one error line to stderr, directly or via say().
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sh_err "Something went wrong"
        #
        # Examples:
        #   _sh_err "Palette file missing"
    # fn: _sh_err - Sh err
        # . Purpose
        #   Write an error message through say when available, otherwise stderr.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _sh_err "$value"
    _sh_err() {
        if declare -f say >/dev/null 2>&1; then
            say --type FAIL "$*"
        else
            printf '%s\n' "${*:-(no message)}" >&2
        fi
    }

    # fn: confirm - Confirm
        # . Purpose
        #   Ask the user for a yes/no confirmation and return success for yes.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   confirm "$value"
    confirm() {
        if declare -f ask >/dev/null 2>&1; then
            local _ans

            ask \
                --label "${1:-Are you sure?}" \
                --var _ans \
                --default "N" \
                --validate validate_yesno \
                --colorize both \
                --echo

            [[ "$_ans" =~ ^[Yy]$ ]]
        else
            # fallback to the simple core behavior
            read -rp "${1:-Are you sure?} [y/N]: " _a
            [[ "$_a" =~ ^[Yy]$ ]]
        fi
    }

# --- Helpers ------------------------------------------------------------------------
    # fn: _sgnd_ui_resolve_theme_file - Ui resolve theme file
        # . Purpose
        #   Resolve a palette or style name to a readable theme file path.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _sgnd_ui_resolve_theme_file "$value"
    _sgnd_ui_resolve_theme_file() {
        local kind="$1"
        local spec="$2"
        local base
        local file

        if [[ -z "$spec" ]]; then
            printf '_sgnd_ui_resolve_theme_file: missing %s spec\n' "$kind" >&2
            return 2
        fi

        # Treat as explicit file path if it looks like a path or ends with .sh
        if [[ "$spec" == */* || "$spec" == *.sh ]]; then
            file="$spec"
            [[ "$file" != *.sh ]] && file="${file}.sh"
            if [[ -r "$file" ]]; then
                printf '%s' "$file"
                return 0
            fi
            printf 'UI theme %s file not found/readable: %s\n' "$kind" "$file" >&2
            return 3
        fi

        # Name resolution under theme dir
        base="${SGND_UI_THEME_DIR-}"
        if [[ -z "$base" ]]; then
            printf 'UI theme directory not set (SGND_UI_THEME_DIR/SGND_FRAMEWORK_ROOT missing)\n' >&2
            return 4
        fi

        file="${base%/}/${kind}/${spec}.sh"
        if [[ -r "$file" ]]; then
            printf '%s' "$file"
            return 0
        fi

        printf 'UI theme %s "%s" not found at: %s\n' "$kind" "$spec" "$file" >&2
        return 5
    }

# --- Public API ---------------------------------------------------------------------
 # -- Public helpers --------------------------------------------------------------
    # fn: sgnd_strip_ansi - Strip ansi
        # . Purpose
        #   Remove ANSI escape sequences from text.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_strip_ansi "$value"
    sgnd_strip_ansi() {
        sed -r $'s/\x1B\\[[0-9;?]*[[:alpha:]]//g' <<<"$1"
    }

    # fn: sgnd_visible_len - Visible len
        # . Purpose
        #   Return the visible character length of text after ANSI escape sequences are removed.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_visible_len "$value"
    sgnd_visible_len() {
        local plain
        plain="$(sgnd_strip_ansi "$1")"
        printf '%s' "${#plain}"
    }

 # -- Theme loading ---------------------------------------------------------------
    # fn: sgnd_ui_set_theme - Ui set theme
        # . Purpose
        #   Load a SolidGroundUX UI palette and style into the current shell session.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --palette VALUE
        #   --style VALUE
        #   --default VALUE
        #   --help VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_ui_set_theme --palette "..." --style "..." --default "..." --help
    sgnd_ui_set_theme() {
        local palette_spec=""
        local style_spec=""
        local use_default=0

        local a
        while (($#)); do
            a="$1"
            case "$a" in
                --palette) palette_spec="${2-}"; shift 2 ;;
                --style)   style_spec="${2-}"; shift 2 ;;
                --default) use_default=1; shift ;;
                -h|--help)
                    printf '%s\n' \
                        "sgnd_ui_set_theme --palette <file|name> --style <file|name>" \
                        "sgnd_ui_set_theme --default"
                    return 0
                    ;;
                *)
                    # allow shorthand: sgnd_ui_set_theme palette style
                    if [[ -z "$palette_spec" ]]; then
                        palette_spec="$a"
                    elif [[ -z "$style_spec" ]]; then
                        style_spec="$a"
                    else
                        printf 'sgnd_ui_set_theme: unexpected argument: %s\n' "$a" >&2
                        return 2
                    fi
                    shift
                    ;;
            esac
        done

        if (( use_default )); then
            palette_spec="default-ui-palette"
            style_spec="default-ui-style"
        fi

        # Theme root (where palettes/ and styles/ live)
        if [[ -z "${SGND_UI_THEME_DIR-}" ]]; then
            if [[ -n "${SGND_FRAMEWORK_ROOT-}" ]]; then
                SGND_UI_THEME_DIR="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/ui"
            else
                # fallback: relative to this file if possible
                SGND_UI_THEME_DIR=""
            fi
        fi

        # --- resolve palette/style -------------------------------------------------
        local palette_file
        local style_file

        palette_file="$(_sgnd_ui_resolve_theme_file "palettes" "$palette_spec")" || return $?
        style_file="$(_sgnd_ui_resolve_theme_file "styles"   "$style_spec")"   || return $?

        # --- load palette first, then style ---------------------------------------
        # shellcheck disable=SC1090
        source "$palette_file" || {
            printf 'sgnd_ui_set_theme: failed to load palette: %s\n' "$palette_file" >&2
            return 10
        }

        # Minimal sanity: palette should define RESET
        if [[ -z "${RESET-}" ]]; then
            printf 'sgnd_ui_set_theme: palette did not define RESET: %s\n' "$palette_file" >&2
            return 11
        fi

        # shellcheck disable=SC1090
        source "$style_file" || {
            printf 'sgnd_ui_set_theme: failed to load style: %s\n' "$style_file" >&2
            return 12
        }

        SGND_UI_PALETTE_FILE="$palette_file"
        SGND_UI_STYLE_FILE="$style_file"

        return 0
    }

    # fn: sgnd_ui_set_default_theme - Ui set default theme
        # . Purpose
        #   Load the default SolidGroundUX UI palette and style.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_ui_set_default_theme "$value"
    sgnd_ui_set_default_theme() {
        sgnd_ui_set_theme --default
    }

 # -- Styling helpers -------------------------------------------------------------
    # fn: sgnd_sgr - Sgr
        # . Purpose
        #   Build an ANSI SGR escape sequence from numeric codes or existing SGR fragments.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_sgr "$value"
    sgnd_sgr() {
        local -a parts=()
        local -a subparts=()
        local arg=""
        local inner=""
        local sub=""

        for arg in "$@"; do
            [[ -z "${arg:-}" ]] && continue

            # Numeric: treat as single SGR parameter
            if [[ "$arg" =~ ^[0-9]+$ ]]; then
                parts+=( "$arg" )
                continue
            fi

            # Numeric list: allow comma or semicolon separated params
            if [[ "$arg" =~ ^[0-9]+([,;][0-9]+)+$ ]]; then
                inner="${arg//,/;}"
                IFS=';' read -r -a subparts <<< "$inner"

                for sub in "${subparts[@]}"; do
                    [[ -n "$sub" ]] && parts+=( "$sub" )
                done
                continue
            fi

            # Escape: extract inner params from $'\e[...m'
            if [[ "$arg" == $'\e['*m ]]; then
                inner="${arg#$'\e['}"
                inner="${inner%m}"

                if [[ "$inner" =~ ^[0-9]+([;][0-9]+)*$ ]]; then
                    IFS=';' read -r -a subparts <<< "$inner"

                    for sub in "${subparts[@]}"; do
                        [[ -n "$sub" ]] && parts+=( "$sub" )
                    done
                fi
                continue
            fi
        done

        if (( ${#parts[@]} == 0 )); then
            printf '%s' "${RESET-}"
            return 0
        fi

        printf $'\e[%sm' "$(IFS=';'; echo "${parts[*]}")"
    }

    # fn: sgnd_fg - Fg
        # . Purpose
        #   Build a foreground-color SGR sequence.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_fg "$value"
    sgnd_fg() {  # fn: sgnd_fg <fg> [fx...]
        local fg="${1:-}"
        shift || true
        sgnd_sgr "$fg" "" "$@"
    }

    sgnd_bg() {  # fn: sgnd_bg <bg> [fx...]
        local bg="${1:-}"
        shift || true
        sgnd_sgr "" "$bg" "$@"
    }

 # -- Runmode indicators ----------------------------------------------------------
    sgnd_update_runmode() {
        if (( FLAG_DRYRUN )); then
            RUN_MODE="$(sgnd_runmode_color)DRYRUN${RESET}"
        else
            RUN_MODE="$(sgnd_runmode_color)COMMIT${RESET}"
        fi
    }

    # fn: sgnd_runmode_color - Runmode color
        # . Purpose
        #   Return the UI color associated with the current or supplied run mode.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_runmode_color "$value"
    sgnd_runmode_color() {
        (( FLAG_DRYRUN )) && printf '%s' "$TUI_DRYRUN" || printf '%s' "$TUI_COMMIT"
    }

 # -- Rendering primitives --------------------------------------------------------
    # fn: sgnd_print_labeledvalue - Print labeledvalue
        # . Purpose
        #   Print a formatted label/value row.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --label VALUE
        #   --value VALUE
        #   --sep VALUE
        #   --labelwidth VALUE
        #   --pad VALUE
        #   --labelclr VALUE
        #   --valueclr VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_labeledvalue --label "..." --value --sep --labelwidth
    sgnd_print_labeledvalue() {
        local label=""
        local value=""

        local sep=":"
        local labelwidth=25
        local pad=0
        local labelclr="${TUI_LABEL}"
        local valueclr="${TUI_VALUE}"

        # --- Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)
                    label="$2"
                    shift 2
                    ;;
                --value)
                    value="$2"
                    shift 2
                    ;;
                --sep)
                    sep="$2"
                    shift 2
                    ;;
                --labelwidth)
                    labelwidth="$2"
                    shift 2
                    ;;
                --pad)
                    pad="$2"
                    shift 2
                    ;;
                --labelclr)
                    labelclr="$2"
                    shift 2
                    ;;
                --valueclr)
                    valueclr="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    # Allow positional fallback: label value
                    if [[ -z "$label" ]]; then
                        label="$1"
                    elif [[ -z "$value" ]]; then
                        value="$1"
                    fi
                    shift
                    ;;
            esac
        done

        [[ -z "$label" ]] && return 0

        # Width / pad safety
        [[ "$labelwidth" =~ ^[0-9]+$ ]] || labelwidth=22
        [[ "$pad"   =~ ^[0-9]+$ ]] || pad=4

        printf '%*s%s %s %s\n' \
            "$pad" "" \
            "${labelclr}$(printf "%-*.*s" "$labelwidth" "$labelwidth" "$label")${RESET}" \
            "$sep" \
            "${valueclr}${value}${RESET}"
    }

    # fn: sgnd_print_fill - Print fill
        # . Purpose
        #   Print a left/right line filled to a target width.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --left VALUE
        #   --right VALUE
        #   --padleft VALUE
        #   --padright VALUE
        #   --maxwidth VALUE
        #   --fillchar VALUE
        #   --leftclr VALUE
        #   --rightclr VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_fill --left "..." --right "..." --padleft --padright
    sgnd_print_fill() {
        local left="" right=""
        local padleft=2 padright=1 maxwidth=80
        local fillchar=" "
        local leftclr="${TUI_TEXT}"
        local rightclr=""

        # --- Parse options (with positional fallback)
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --left)     left="$2"; shift 2 ;;
                --right)    right="$2"; shift 2 ;;
                --padleft)  padleft="$2"; shift 2 ;;
                --padright) padright="$2"; shift 2 ;;
                --maxwidth) maxwidth="$2"; shift 2 ;;
                --fillchar) fillchar="$2"; shift 2 ;;
                --leftclr)  leftclr="$2"; shift 2 ;;
                --rightclr) rightclr="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    if [[ -z "$left" ]]; then
                        left="$1"
                    elif [[ -z "$right" ]]; then
                        right="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # --- Defaults / safety
        [[ "$padleft"  =~ ^[0-9]+$ ]] || padleft=2
        [[ "$padright" =~ ^[0-9]+$ ]] || padright=1
        [[ "$maxwidth" =~ ^[0-9]+$ ]] || maxwidth=80
        (( maxwidth < 10 )) && maxwidth=10

        # right color inherits left color
        [[ -z "$rightclr" ]] && rightclr="$leftclr"

        # fillchar: single visible char only
        [[ -n "$fillchar" ]] || fillchar=" "
        fillchar="${fillchar:0:1}"

        fill=$(( maxwidth
                - padleft
                - $(sgnd_visible_len "$left")
                - $(sgnd_visible_len "$right")
                - padright ))

        (( fill < 0 )) && fill=0

        # --- Render (colors applied last)
        printf '%s%s%s%s%s%s\n' \
            "$(sgnd_string_repeat "$fillchar" "$padleft")" \
            "${leftclr}${left}${RESET}" \
            "$(sgnd_string_repeat "$fillchar" "$fill")" \
            "$(sgnd_string_repeat "$fillchar" "$padright")" \
            "${rightclr}${right}${RESET}" \
            ""
    }

    # fn: sgnd_print_titlebar - Print titlebar
        # . Purpose
        #   Print the standard SolidGroundUX title bar.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --left VALUE
        #   --leftclr VALUE
        #   --right VALUE
        #   --rightclr VALUE
        #   --sub VALUE
        #   --subclr VALUE
        #   --subjust VALUE
        #   --border VALUE
        #   --borderclr VALUE
        #   --padleft VALUE
        #   --maxwidth VALUE
        #
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_titlebar --left "..." --leftclr --right "..." --rightclr
    sgnd_print_titlebar() {

        local left="${SGND_SCRIPT_TITLE:-$SGND_SCRIPT_BASE}"
        local right="${RUN_MODE:-}"
        local leftclr="$(sgnd_sgr "$WHITE" "" "$FX_BOLD")"
        local rightclr=""                 # let sgnd_print_fill inherit
        local sub="${SGND_SCRIPT_DESC:-""}"
        local subclr="$(sgnd_sgr "$WHITE" "" "$FX_ITALIC")"
        local subjust="C"
        local border="$DL_H"
        local borderclr="${TUI_BORDER}"
        local padleft=4
        local maxwidth=80

        # -- Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --left)      left="$2"; shift 2 ;;
                --leftclr)   leftclr="$2"; shift 2 ;;
                --right)     right="$2"; shift 2 ;;
                --rightclr)  rightclr="$2"; shift 2 ;;
                --sub)       sub="$2"; shift 2 ;;
                --subclr)    subclr="$2"; shift 2 ;;
                --subjust)   subjust="$2"; shift 2 ;;
                --border)    border="$2"; shift 2 ;;
                --borderclr) borderclr="$2"; shift 2 ;;
                --padleft)   padleft="$2"; shift 2 ;;
                --maxwidth)  maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$left" ]] && left="$1"
                    shift
                    ;;
            esac
        done

        # -- Numeric safety
        [[ "$padleft"  =~ ^[0-9]+$ ]] || padleft=4
        [[ "$maxwidth" =~ ^[0-9]+$ ]] || maxwidth=80
        (( maxwidth < 10 )) && maxwidth=10
        (( padleft < 0 )) && padleft=0

        sgnd_print
        sgnd_print_sectionheader \
            --border "$border" \
            --borderclr "$borderclr" \
            --maxwidth "$maxwidth"

        sgnd_print_fill \
            --left "$left" \
            --right "$right" \
            --padleft "$padleft" \
            --maxwidth "$maxwidth" \
            --leftclr "$leftclr" \
            ${rightclr:+--rightclr "$rightclr"}

        if [[ "${sub}" != "" ]]; then
           sgnd_print \
            --text "$sub" \
            --justify "$subjust" \
            --textclr "$subclr" \
            --rightmargin "$(sgnd_visible_len "$right")"
        fi

        sgnd_print_sectionheader \
            --border "$border" \
            --borderclr "$borderclr" \
            --maxwidth "$maxwidth"
    }

    # fn: sgnd_print_sectionheader - Print sectionheader
        # . Purpose
        #   Print a section header or horizontal border line.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --text VALUE
        #   --textclr VALUE
        #   --border VALUE
        #   --borderclr VALUE
        #   --padleft VALUE
        #   --padend VALUE
        #   --maxwidth VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_sectionheader --text "..." --textclr --border --borderclr
    sgnd_print_sectionheader() {
        local text=""
        local textclr="$(sgnd_sgr "$WHITE" "" "$FX_BOLD")"
        local border="$LN_H"
        local borderclr="${TUI_BORDER}"
        local padleft=4
        local padend=1
        local maxwidth=80
   
        # -- Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text)      text="$2"; shift 2 ;;
                --textclr)   textclr="$2"; shift 2 ;;
                --border)    border="$2"; shift 2 ;;
                --borderclr) borderclr="$2"; shift 2 ;;
                --padleft)   padleft="$2"; shift 2 ;;
                --padend)    padend="$2"; shift 2 ;;
                --maxwidth)  maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    # positional fallback
                    [[ -z "$text" ]] && text="$1"
                    shift
                    ;;
            esac
        done

        # -- Numeric safety
        [[ "$padleft"  =~ ^[0-9]+$ ]] || padleft=4
        [[ "$padend"   =~ ^(0|1)$   ]] || padend=1
        [[ "$maxwidth" =~ ^[0-9]+$ ]] || maxwidth=80
        (( maxwidth < 10 )) && maxwidth=10
        (( padleft < 0 )) && padleft=0

        # -- Assemble line (PLAIN parts first; add color last)
        local left_plain="" mid_plain="" right_plain="" fnl=""
        local remaining=0

        # If no text: full-width border line
        if [[ -z "$text" ]]; then
            fnl="${borderclr}$(sgnd_string_repeat "$border" "$maxwidth")${RESET}"
            printf '%s\n' "$fnl"
            return 0
        fi

        # Left: "---- " (padleft times border + a space)
        if [[ -n "$border" && $padleft -gt 0 ]]; then
            left_plain="$(sgnd_string_repeat "$border" "$padleft") "
        fi

        # Middle: "Text"
        mid_plain="$(sgnd_strip_ansi "$text")"

        if (( padend )); then
            # We will output: left_plain + mid_plain + space + right_plain
            # So count exactly those visible chars.
            local spent=0
            spent=$(( spent + ${#left_plain} ))
            spent=$(( spent + ${#mid_plain} ))
            spent=$(( spent + 1 ))   # space before right fill

            remaining=$(( maxwidth - spent ))
            (( remaining < 0 )) && remaining=0

            if [[ -n "$border" && $remaining -gt 0 ]]; then
                right_plain="$(sgnd_string_repeat "$border" "$remaining")"
            fi

            if [[ -n "$right_plain" ]]; then
                fnl="${borderclr}${left_plain}${RESET}${textclr}${text}${RESET} ${borderclr}${right_plain}${RESET}"
            else
                fnl="${borderclr}${left_plain}${RESET}${textclr}${text}${RESET}"
            fi
        else
            fnl="${borderclr}${left_plain}${textclr}${text}${RESET}"
        fi

        printf '%s\n' "$fnl"
    }

    # fn: sgnd_print - Print
        # . Purpose
        #   Print styled, optionally padded, wrapped, or justified text.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --text VALUE
        #   --textclr VALUE
        #   --justify VALUE
        #   --wrap VALUE
        #   --pad VALUE
        #   --rightmargin VALUE
        #   --maxwidth VALUE
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print --text "..." --textclr --justify --wrap
    sgnd_print() {
        local text=""
        local textclr="${TUI_TEXT:-}"
        local wrap=0
        local wrap_explicit=0
        local pad=0
        local rightmargin=0
        local justify="L"   # L = left, C = center, R = right
        local maxwidth=80

        # --- Parse options --------------------------------------------------------
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text)         text="$2"; shift 2 ;;
                --textclr)      textclr="$2"; shift 2 ;;
                --justify)      justify="${2^^}"; shift 2 ;;
                --wrap)         wrap="$2"; wrap_explicit=1; shift 2 ;;
                --pad)          pad="$2"; shift 2 ;;
                --rightmargin)  rightmargin="$2"; shift 2 ;;
                --maxwidth)     maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$text" ]] && text="$1"
                    shift
                    ;;
            esac
        done

        # Empty call => newline
        if [[ -z "$text" ]]; then
            sgnd_print_single
            return 0
        fi

        # --- Safety defaults ------------------------------------------------------
        (( pad < 0 )) && pad=0
        (( rightmargin < 0 )) && rightmargin=0
        (( maxwidth < 1 )) && maxwidth=80

        # --- Available width for auto-wrap decision -------------------------------
        local avail=$(( maxwidth - (pad * 2) - rightmargin ))
        (( avail < 1 )) && avail=1

        # --- Auto-wrap if not explicitly specified --------------------------------
        if (( ! wrap_explicit )); then
            (( ${#text} > avail )) && wrap=1 || wrap=0
        fi

        # --- Render ---------------------------------------------------------------
        if (( wrap )); then
            local mw_eff=$(( maxwidth - rightmargin ))
            (( mw_eff < 1 )) && mw_eff=1

            while IFS= read -r line; do
                sgnd_print_single \
                    --text "$line" \
                    --textclr "$textclr" \
                    --pad "$pad" \
                    --justify "$justify" \
                    --maxwidth "$mw_eff"
            done < <(sgnd_wrap_words --width "$avail" --text "$text")
        else
            sgnd_print_single \
                --text "$text" \
                --textclr "$textclr" \
                --pad "$pad" \
                --justify "$justify" \
                --maxwidth "$maxwidth"
        fi
    }

    # fn: sgnd_print_single - Print single
        # . Purpose
        #   Print a single styled line without wrapping.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --text VALUE
        #   --textclr VALUE
        #   --justify VALUE
        #   --pad VALUE
        #   --maxwidth VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_single --text "..." --textclr --justify --pad
    sgnd_print_single() {
        local text=""
        local textclr="${TUI_TEXT:-}"
        local pad=0
        local justify="L"
        local maxwidth=80

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text)      text="$2"; shift 2 ;;
                --textclr)   textclr="$2"; shift 2 ;;
                --justify)   justify="${2^^}"; shift 2 ;;
                --pad)       pad="$2"; shift 2 ;;
                --maxwidth)  maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$text" ]] && text="$1"
                    shift
                    ;;
            esac
        done

        if [[ -z "$text" ]]; then
            printf "\n"
            return 0
        fi

        (( pad < 0 )) && pad=0
        (( maxwidth < 1 )) && maxwidth=80

        local textlen=${#text}

        local avail=$(( maxwidth - (pad * 2) ))
        (( avail < 1 )) && avail=1

        if (( textlen > avail )); then
            text="${text:0:avail}"
            textlen=${#text}
        fi

        local leftspace=0 rightspace=0
        case "$justify" in
            C)
                leftspace=$(( (avail - textlen) / 2 ))
                rightspace=$(( avail - textlen - leftspace ))
                ;;
            R)
                leftspace=$(( avail - textlen ))
                ;;
            *)
                rightspace=$(( avail - textlen ))
                ;;
        esac

        (( leftspace < 0 )) && leftspace=0
        (( rightspace < 0 )) && rightspace=0

        local line=""
        line+="$(printf '%*s' "$pad" "")"
        line+="$(printf '%*s' "$leftspace" "")"
        line+="$text"
        line+="$(printf '%*s' "$rightspace" "")"
        line+="$(printf '%*s' "$pad" "")"

        printf "%b\n" "${textclr}${line}${RESET}"
    }

    # fn: sgnd_print_file - Print file
        # . Purpose
        #   Print the contents of a file using sgnd_print formatting.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_file "$value"
    sgnd_print_file() {
        local file="$1"
        
        [[ -n "${file:-}" ]] || { printf "ERROR: sgnd_print_file: missing file\n" >&2; return 2; }
        [[ -r "$file" ]]      || { printf "ERROR: sgnd_print_file: not readable: %s\n" "$file" >&2; return 2; }

        
        local ext="${file##*.}"
        local is_tty=0
        [[ -t 1 ]] && is_tty=1

        # Pager (only if interactive)
        local pager_cmd=()
        if (( is_tty )); then
            if command -v less >/dev/null 2>&1; then
                pager_cmd=( less -FRSX )
            fi
        fi

        # Markdown render if possible
        if [[ "${ext,,}" == "md" ]]; then
            if command -v glow >/dev/null 2>&1; then
                # glow pages itself; use -p for pager mode
                glow -p "$file"
                return $?
            fi

            if command -v mdcat >/dev/null 2>&1; then
                if (( is_tty )) && ((${#pager_cmd[@]})); then
                    mdcat "$file" | "${pager_cmd[@]}"
                else
                    mdcat "$file"
                fi
                return $?
            fi

            if command -v bat >/dev/null 2>&1; then
                # bat handles paging/highlighting nicely
                bat --language=md --style=plain --paging=auto "$file"
                return $?
            fi

            if command -v pandoc >/dev/null 2>&1; then
                # Render to plain text
                if (( is_tty )) && ((${#pager_cmd[@]})); then
                    pandoc -t plain "$file" | "${pager_cmd[@]}"
                else
                    pandoc -t plain "$file"
                fi
                return $?
            fi
        fi

        # Plain text fallback
        if (( is_tty )) && ((${#pager_cmd[@]})); then
            "${pager_cmd[@]}" "$file"
        else
            cat -- "$file"
        fi
    }
    
    # fn: sgnd_print_cell - Print cell
        # . Purpose
        #   Print a fixed-width styled cell without a trailing newline.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_cell "$value"
    sgnd_print_cell() {
        local width="$1"
        local s="$2"

        # Strip ANSI CSI sequences for visible length calculation
        local plain
        plain="$(printf '%s' "$s" | sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g')"

        local vislen="${#plain}"
        local pad=$(( width - vislen ))
        (( pad < 0 )) && pad=0

        printf '%s%*s' "$s" "$pad" ""
    }

    # fn: sgnd_module_show_metadata - Module show metadata
        # . Purpose
        #   Print the metadata registered for the current module or script.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_module_show_metadata "$value"
    sgnd_module_show_metadata() {
        local module_ref="${1:?missing module prefix or file}"
        local prefix=""
        local file=""
        local base=""
        local key=""
        local var_name=""

        local v_file=""
        local v_dir=""
        local v_base=""
        local v_name=""
        local v_product=""
        local v_title=""
        local v_desc=""
        local v_version=""
        local v_build=""
        local v_checksum=""
        local v_source=""
        local v_type=""
        local v_purpose=""
        local v_developers=""
        local v_company=""
        local v_client=""
        local v_copyright=""
        local v_license=""

        # --- Resolve module prefix ----------------------------------------------------
        if [[ "$module_ref" == SGND_* ]]; then
            prefix="$module_ref"
        else
            file="$(readlink -f "$module_ref")" || return 1
            base="$(basename -- "$file")"
            key="${base%.sh}"
            key="${key//-/_}"
            prefix="SGND_${key^^}"
        fi

        # --- Resolve variables --------------------------------------------------------
        var_name="${prefix}_FILE";       v_file="${!var_name-}"
        var_name="${prefix}_DIR";        v_dir="${!var_name-}"
        var_name="${prefix}_BASE";       v_base="${!var_name-}"
        var_name="${prefix}_NAME";       v_name="${!var_name-}"
        var_name="${prefix}_PRODUCT";    v_product="${!var_name-}"
        var_name="${prefix}_TITLE";      v_title="${!var_name-}"
        var_name="${prefix}_DESC";       v_desc="${!var_name-}"
        var_name="${prefix}_VERSION";    v_version="${!var_name-}"
        var_name="${prefix}_BUILD";      v_build="${!var_name-}"
        var_name="${prefix}_CHECKSUM";   v_checksum="${!var_name-}"
        var_name="${prefix}_SOURCE";     v_source="${!var_name-}"
        var_name="${prefix}_TYPE";       v_type="${!var_name-}"
        var_name="${prefix}_PURPOSE";    v_purpose="${!var_name-}"
        var_name="${prefix}_DEVELOPERS"; v_developers="${!var_name-}"
        var_name="${prefix}_COMPANY";    v_company="${!var_name-}"
        var_name="${prefix}_CLIENT";     v_client="${!var_name-}"
        var_name="${prefix}_COPYRIGHT";  v_copyright="${!var_name-}"
        var_name="${prefix}_LICENSE";    v_license="${!var_name-}"

        # --- Output -------------------------------------------------------------------
        sgnd_print_labeled_value "Module"      "$prefix"
        sgnd_print_labeled_value "File"        "$v_file"
        sgnd_print_labeled_value "Directory"   "$v_dir"
        sgnd_print_labeled_value "Base"        "$v_base"
        sgnd_print_labeled_value "Name"        "$v_name"
        sgnd_print_labeled_value "Product"     "$v_product"
        sgnd_print_labeled_value "Title"       "$v_title"
        sgnd_print_labeled_value "Version"     "$v_version"
        sgnd_print_labeled_value "Build"       "$v_build"
        sgnd_print_labeled_value "Checksum"    "$v_checksum"
        sgnd_print_labeled_value "Source"      "$v_source"
        sgnd_print_labeled_value "Type"        "$v_type"
        sgnd_print_labeled_value "Purpose"     "$v_purpose"
        sgnd_print_labeled_value "Developers"  "$v_developers"
        sgnd_print_labeled_value "Company"     "$v_company"
        sgnd_print_labeled_value "Client"      "$v_client"
        sgnd_print_labeled_value "Copyright"   "$v_copyright"
        sgnd_print_labeled_value "License"     "$v_license"

        if [[ -n "$v_desc" ]]; then
            printf '\nDescription:\n%s\n' "$v_desc"
        fi

        return 0
    }
 # -- Externals -------------------------------------------------------------------
 # -- Sample/demo renderers -------------------------------------------------------
    # fn: sgnd_color_samples - Color samples
        # . Purpose
        #   Print sample output for the currently loaded color palette.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_color_samples "$value"
    sgnd_color_samples(){
        printf '\n%s\n\n' "---- Available foreground colors & effects in SolidGroundUX ----"

        sgnd_sample_row	BLUE	BRIGHT_BLUE	    DARK_BLUE	    BG_BLUE	    BG_DARK_BLUE
        sgnd_sample_row	BROWN	BRIGHT_BROWN	DARK_BROWN      BG_BROWN	BG_DARK_BROWN
        sgnd_sample_row	CYAN	BRIGHT_CYAN	    DARK_CYAN	    BG_CYAN	    BG_DARK_CYAN
        sgnd_sample_row	GOLD	BRIGHT_GOLD	    DARK_GOLD	    BG_GOLD	    BG_DARK_GOLD
        sgnd_sample_row	GREEN	BRIGHT_GREEN	DARK_GREEN	    BG_GREEN	BG_DARK_GREEN
        sgnd_sample_row	MAGENTA	BRIGHT_MAGENTA	DARK_MAGENTA	BG_MAGENTA	BG_DARK_MAGENTA
        sgnd_sample_row	ORANGE	BRIGHT_ORANGE	DARK_ORANGE	    BG_ORANGE	BG_DARK_ORANGE
        sgnd_sample_row	PINK	BRIGHT_PINK	    DARK_PINK	    BG_PINK	    BG_DARK_PINK
        sgnd_sample_row	PURPLE	BRIGHT_PURPLE	DARK_PURPLE	    BG_PURPLE	BG_DARK_PURPLE
        sgnd_sample_row	RED	    BRIGHT_RED	    DARK_RED	    BG_RED	    BG_DARK_RED
        sgnd_sample_row	TEAL	BRIGHT_TEAL	    DARK_TEAL	    BG_TEAL	    BG_DARK_TEAL
        sgnd_sample_row	WHITE	BRIGHT_WHITE	DARK_WHITE	    BG_WHITE	BG_DARK_WHITE
        sgnd_sample_row	YELLOW	BRIGHT_YELLOW	DARK_YELLOW	    BG_YELLOW	BG_DARK_YELLOW

    }

    # fn: sgnd_sample_row - Sample row
        # . Purpose
        #   Print one sample row for the style sample output.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_sample_row "$value"
    sgnd_sample_row(){
        local clr name val

        for clr in "$@"; do
            eval "val=\${$clr}"

            sgnd_print_cell 20 "$val$clr$RESET"

            # Bold
            printf "%sBOLD%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_BOLD")" \
                "$RESET"

            # Faint / Dim
            printf "%sFAINT%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_FAINT")" \
                "$RESET"

            # Italic
            printf "%sITALIC%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_ITALIC")" \
                "$RESET"

            # Underline
            printf "%sUNDER%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_UNDERLINE")" \
                "$RESET"

            # Reverse
            printf "%sREVERSE%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_REVERSE")" \
                "$RESET"

            # Strikethrough
            printf "%sSTRIKE%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_STRIKE")" \
                "$RESET"

            printf "\n"    
        done

        printf "\n"
    }

    # fn: sgnd_style_samples - Style samples
        # . Purpose
        #   Print sample output for the currently loaded UI style.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_style_samples "$value"
    sgnd_style_samples(){
        printf '\n%s\n\n' "---- Message colors (Say) ----"
       
        printf '%s\n' "${MSG_CLR_INFO}MSG_CLR_INFO${RESET}"
        printf '%s\n' "${MSG_CLR_STRT}MSG_CLR_STRT${RESET}"
        printf '%s\n' "${MSG_CLR_OK}MSG_CLR_OK${RESET}"
        printf '%s\n' "${MSG_CLR_WARN}MSG_CLR_WARN${RESET}"
        printf '%s\n' "${MSG_CLR_FAIL}MSG_CLR_FAIL${RESET}"
        printf '%s\n' "${MSG_CLR_CNCL}MSG_CLR_CNCL${RESET}"
        printf '%s\n' "${MSG_CLR_END}MSG_CLR_END${RESET}"
        printf '%s\n' "${MSG_CLR_EMPTY}MSG_CLR_EMPTY${RESET}"
        printf '%s\n' "${MSG_CLR_DEBUG}MSG_CLR_DEBUG${RESET}"

        printf '\n%s\n\n' "---- Ui element color ----"
        printf '%s\n' "${TUI_BORDER}TUI_BORDER${RESET}"

        printf '%s\n' "${TUI_LABEL}TUI_LABEL${RESET} : ${TUI_VALUE}TUI_VALUE${RESET}"

        printf '%s\n' "${TUI_COMMIT}TUI_COMMIT${RESET}/${TUI_DRYRUN}TUI_DRYRUN${RESET}"
        printf '%s\n' "${TUI_ENABLED}TUI_ENABLED${RESET}/${TUI_DISABLED}TUI_DISABLED${RESET}"
        printf '%s\n' "${TUI_PROMPT}TUI_PROMPT${RESET} : ${TUI_INPUT}TUI_INPUT${RESET}"

        printf '%s\n' "${TUI_INVALID}TUI_INVALID${RESET}/${TUI_VALID}TUI_VALID${RESET}"
        
        printf '%s\n' "${TUI_SUCCESS}TUI_SUCCESS${RESET}"
        printf '%s\n' "${TUI_ERROR}TUI_ERROR${RESET}"

        printf '%s\n' "${TUI_TEXT}TUI_TEXT${RESET}"

        printf '%s\n' "${TUI_DEFAULT}TUI_DEFAULT${RESET}"

    }





