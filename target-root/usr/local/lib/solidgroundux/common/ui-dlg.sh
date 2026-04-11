# =====================================================================================
# SolidgroundUX - UI Dialogs
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : 2df0e709171ec597ebb49edccbf080412c6103a1fd8ffae244556f2686341327
#   Source      : ui-dlg.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide dialog-style user interaction helpers
#
# Description:
#   Implements dialog-oriented interaction patterns for console applications.
#
#   The library:
#     - Provides higher-level dialog constructs built on top of ui-ask
#     - Supports timed prompts with auto-continue behavior
#     - Normalizes user responses into consistent action tokens
#     - Enables structured interaction flows such as confirmations and selections
#     - Integrates with UI rendering for consistent look and feel
#
# Design principles:
#   - Build on top of primitive input helpers (ui-ask)
#   - Normalize interaction results for predictable scripting
#   - Keep dialogs lightweight and composable
#   - Support both interactive and semi-automated scenarios
#
# Role in framework:
#   - Intermediate interaction layer between raw input (ui-ask) and applications
#   - Used by scripts requiring structured or timed user decisions
#
# Non-goals:
#   - Full-screen or TUI-style dialog systems
#   - Complex workflow/state engines
#   - Persistent dialog sessions
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # _td_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Behavior:
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
        #
        # Usage:
        #   _td_lib_guard
        #
        # Examples:
        #   # Typical usage at top of library file
        #   _td_lib_guard
        #   unset -f _td_lib_guard
        #
        # Notes:
        #   - Guard variable is derived dynamically (e.g. ui-glyphs.sh → SGND_UI_GLYPHS_LOADED).
        #   - Safe under `set -u` due to indirect expansion with default.
    _td_lib_guard() {
        local lib_base
        local guard

        lib_base="$(basename "${BASH_SOURCE[0]}")"
        lib_base="${lib_base%.sh}"
        lib_base="${lib_base//-/_}"
        guard="SGND_${lib_base^^}_LOADED"

        # Refuse to execute (library only)
        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            echo "This is a library; source it, do not execute it: ${BASH_SOURCE[0]}" >&2
            exit 2
        }

        # Load guard (safe under set -u)
        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _td_lib_guard
    unset -f _td_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# --- Internal helpers ------------------------------------------------------------------
    # _dlg_keymap
        # Purpose:
        #   Build a human-readable key legend string for the current dialog state.
        #
        # Behavior:
        #   - Includes only the actions enabled by the supplied choice string.
        #   - Adapts the pause legend to "pause" or "resume" based on PAUSED.
        #   - Returns a semicolon-separated legend without a trailing delimiter.
        #
        # Arguments:
        #   $1  CHOICES
        #       Choice specification describing enabled dialog keys.
        #   $2  PAUSED
        #       Optional paused state flag:
        #       1 = paused
        #       0 = not paused
        #       Default: 0
        #
        # Output:
        #   Prints the legend string to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _dlg_keymap "AERCPQ" 0
        #
        # Examples:
        #   legend="$(_dlg_keymap "ERCPQ" 1)"
        #
        # Notes:
        #   - Intended as an internal rendering helper.
    _dlg_keymap(){
        local choices="$1"
        local keymap=""
        local paused="${2:-0}"

        [[ "$choices" == *"E"* ]] && keymap+="Enter=continue; "
        [[ "$choices" == *"R"* ]] && keymap+="R=redo; "
        [[ "$choices" == *"C"* ]] && keymap+="C/Esc=cancel; "

        [[ "$choices" == *"Q"* ]] && keymap+="Q=quit; "
        [[ "$choices" == *"A"* ]] && keymap+="Press any key to continue; "
        
        if [[ "$choices" == *"P"* ]]; then
            if (( paused )); then
                keymap+="P/Space=resume; "
            else
                keymap+="P/Space=pause; "
            fi
        fi

        # Trim trailing "; "
        keymap="${keymap%; }"

        printf '%s' "$keymap"
    }

    # sgnd_decision_expand_choices
        # Purpose:
        #   Expand a symbolic decision specification into canonical choices and aliases.
        #
        # Behavior:
        #   - Parses a comma-separated list of choice groups.
        #   - Each group may contain aliases separated by |.
        #   - The first token in each group becomes the canonical value.
        #   - Tokens are normalized to uppercase.
        #
        # Arguments:
        #   $1  CHOICES
        #       Choice specification, e.g. "OK|O,Redo|R,Quit|Q|Cancel|C"
        #
        # Outputs:
        #   Writes rows to stdout as:
        #       CANONICAL|ALIAS
        #
        # Returns:
        #   0 always.
    sgnd_decision_expand_choices() {
        local spec="${1-}"
        local group=""
        local canonical=""
        local alias=""
        local IFS=','

        for group in $spec; do
            canonical=""
            IFS='|' read -r -a _aliases <<< "$group"

            for alias in "${_aliases[@]}"; do
                alias="${alias#"${alias%%[![:space:]]*}"}"
                alias="${alias%"${alias##*[![:space:]]}"}"
                alias="${alias^^}"

                [[ -n "$alias" ]] || continue

                if [[ -z "$canonical" ]]; then
                    canonical="$alias"
                fi

                printf '%s|%s\n' "$canonical" "$alias"
            done
        done
    }


    # sgnd_decision_normalize
        # Purpose:
        #   Normalize a typed value to its canonical decision token.
        #
        # Behavior:
        #   - Matches the typed value against a decision specification.
        #   - Returns the canonical token for the matching alias.
        #   - Matching is case-insensitive.
        #   - Empty input is treated as the provided default.
        #
        # Arguments:
        #   $1  VALUE
        #       User-entered value.
        #   $2  CHOICES
        #       Choice specification, e.g. "OK|O,Redo|R,Quit|Q|Cancel|C"
        #   $3  DEFAULT
        #       Optional default value used when VALUE is empty.
        #
        # Outputs:
        #   Writes canonical token to stdout when matched.
        #
        # Returns:
        #   0 if the value is valid and normalized.
        #   1 if the value is invalid.
    sgnd_decision_normalize() {
        local value="${1-}"
        local choices="${2-}"
        local default_value="${3-}"
        local line=""
        local canonical=""
        local alias=""

        if [[ -z "$value" ]]; then
            value="$default_value"
        fi

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value^^}"

        while IFS='|' read -r canonical alias; do
            [[ "$value" == "$alias" ]] || continue
            printf '%s\n' "$canonical"
            return 0
        done < <(sgnd_decision_expand_choices "$choices")

        return 1
    }

    # sgnd_decision_display_choices
        # Purpose:
        #   Build a compact display label for a decision specification.
        #
        # Behavior:
        #   - Uses the first token from each comma-separated choice group.
        #   - Joins canonical labels with / for prompt display.
        #
        # Arguments:
        #   $1  CHOICES
        #       Choice specification, e.g. "OK|O,Redo|R,Quit|Q|Cancel|C"
        #
        # Outputs:
        #   Writes compact display text, e.g. "OK/Redo/Quit"
        #
        # Returns:
        #   0 always.
    sgnd_decision_display_choices() {
        local spec="${1-}"
        local group=""
        local out=""
        local first=""
        local IFS=','

        for group in $spec; do
            first="${group%%|*}"
            first="${first#"${first%%[![:space:]]*}"}"
            first="${first%"${first##*[![:space:]]}"}"

            [[ -n "$first" ]] || continue

            if [[ -n "$out" ]]; then
                out+="/"
            fi
            out+="$first"
        done

        printf '%s\n' "$out"
    }


    # sgnd_decision_from_dialog_rc
        # Purpose:
        #   Translate a sgnd_dlg_autocontinue() return code into a canonical decision token.
        #
        # Behavior:
        #   - Maps dialog return codes to canonical decision names when possible.
        #   - Returns non-zero when the dialog result should fall back to typed input.
        #
        # Arguments:
        #   $1  RC
        #       Return code from sgnd_dlg_autocontinue().
        #   $2  CHOICES
        #       Decision specification used for normalization.
        #   $3  DEFAULT
        #       Default decision token.
        #
        # Outputs:
        #   Writes canonical decision token to stdout when mapped.
        #
        # Returns:
        #   0 if RC was mapped to a canonical decision.
        #   1 if typed fallback should be used.
    sgnd_decision_from_dialog_rc() {
        local rc="${1:-}"
        local choices="${2-}"
        local default_value="${3-}"
        local mapped=""

        case "$rc" in
            0|1)
                mapped="$(sgnd_decision_normalize "$default_value" "$choices" "$default_value")" || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            2)
                mapped="$(sgnd_decision_normalize "CANCEL" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(sgnd_decision_normalize "NO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(sgnd_decision_normalize "QUIT" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            3)
                mapped="$(sgnd_decision_normalize "REDO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            4)
                mapped="$(sgnd_decision_normalize "QUIT" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(sgnd_decision_normalize "CANCEL" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

# --- Public API ---------------------------------------------------------------------
    # sgnd_dlg_autocontinue
        # Purpose:
        #   Render a timed dialog on /dev/tty with a countdown and simple key-driven actions.
        #
        # Behavior:
        #   - Displays an optional message, optional key legend, and countdown line.
        #   - Redraws the dialog block in place using minimal cursor movement.
        #   - Supports pause/resume, continue, cancel, redo, quit, and custom keys.
        #   - Returns immediately with success when no usable /dev/tty is available.
        #
        # Arguments:
        #   $1  SECONDS
        #       Countdown duration in seconds.
        #       Default: 5
        #   $2  MESSAGE
        #       Optional text shown above the countdown.
        #   $3  CHOICES
        #       Enabled key set.
        #       Default: AERCPQ
        #
        # Supported reserved keys:
        #   A  Any key continues
        #   E  Enter continues
        #   R  Redo
        #   C  Cancel
        #   P  Pause / resume
        #   Q  Quit
        #   H  Hide key legend
        #
        # Custom keys:
        #   - Any non-reserved single-character key in CHOICES is treated as a custom key.
        #   - Custom keys return 10 for the first custom key, 11 for the second, and so on.
        #
        # Inputs (globals):
        #   TUI_TEXT
        #   WHITE
        #   FX_ITALIC
        #   RESET
        #
        # Returns:
        #   0   continue
        #   1   timeout / auto-continue
        #   2   cancel
        #   3   redo
        #   4   quit
        #   10+ custom key index
        #
        # Usage:
        #   sgnd_dlg_autocontinue 5 "Continuing shortly..." "AERCPQ"
        #
        # Examples:
        #   sgnd_dlg_autocontinue 10 "Proceed with installation?" "ERCPQ"
        #
        #   case $? in
        #       0)  continue_flow ;;
        #       1)  timeout_flow ;;
        #       2)  cancel_flow ;;
        #       3)  redo_flow ;;
        #       4)  quit_flow ;;
        #   esac
        #
        # Notes:
        #   - This function defines dialog mechanics only; callers interpret the return code.
    sgnd_dlg_autocontinue() {
        local seconds="${1:-5}"
        local msg="${2:-}"
        local dlgchoices="${3:-AERCPQ}"
        dlgchoices="${dlgchoices^^}"

        local tty="/dev/tty"
        [[ -r "$tty" && -w "$tty" ]] || return 0

        # --- Helpers ---------------------------------------------------------------
        # Reserved keys are matched case-insensitively.
        local reserved="AERCPQH"

        # Build a de-duplicated list of custom keys in encounter order.
        # Excludes reserved letters (A/E/R/C/P/Q/H), but allows Enter/Space/Esc behavior
        # through the existing logic.
        local custom_keys=""
        local _ch=""
        local i=0

        for (( i=0; i<${#dlgchoices}; i++ )); do
            _ch="${dlgchoices:i:1}"
            # Normalize to uppercase for reserved detection
            if [[ "$reserved" == *"$_ch"* ]]; then
                continue
            fi
            # Skip duplicates
            if [[ "$custom_keys" == *"$_ch"* ]]; then
                continue
            fi
            custom_keys+="${_ch}"
        done

        # Return code for a custom key, or empty if not a custom key.
        # Custom keys are matched exactly as provided, but also accept case-insensitive
        # match if the provided key is alphabetic.
        sgnd_dlg_custom_rc_for_key() {
            local pressed="${1:-}"
            local j=0
            local k=""

            for (( j=0; j<${#custom_keys}; j++ )); do
                k="${custom_keys:j:1}"
                if [[ "$pressed" == "$k" ]]; then
                    printf '%d' "$((10 + j))"
                    return 0
                fi
                # If both are letters, accept case-insensitive match
                if [[ "$pressed" =~ ^[A-Za-z]$ && "$k" =~ ^[A-Za-z]$ ]]; then
                    if [[ "${pressed^^}" == "${k^^}" ]]; then
                        printf '%d' "$((10 + j))"
                        return 0
                    fi
                fi
            done

            return 1
        }

        # --- Runtime state --------------------------------------------------------
        local paused=0
        local key=""
        local got=0

        local lines=1
        local hide_keymap=0
        if [[ "$dlgchoices" == *"H"* ]]; then
            hide_keymap=1
        else
            hide_keymap=0
            ((lines++))
        fi

        if [[ -n "$msg" ]]; then
            ((lines++))
        fi

        local clr
        clr="$(sgnd_sgr "$WHITE" "$FX_ITALIC")"

        while true; do
            local line_keymap
            line_keymap="$(_dlg_keymap "$dlgchoices" "$paused")"

            # Message line (optional)
            if [[ -n "$msg" ]]; then
                printf '\r\e[K%s\n' "${TUI_TEXT}${msg}${RESET}" >"$tty"
            fi

            # Keymap line
            if (( ! hide_keymap )); then
                printf '\r\e[K%s\n' "${TUI_TEXT}${line_keymap}${RESET}" >"$tty"
            fi

            if (( paused )); then
                printf '\r\e[K%sPaused... Press P or Space to resume countdown%s' \
                    "$clr" "$RESET" >"$tty"
            else
                printf '\r\e[K%sContinuing in %ds...%s' \
                    "$clr" "$seconds" "$RESET" >"$tty"
            fi

            # Read key
            got=0
            key=""
            if (( paused )); then
                if IFS= read -r -n 1 -s key <"$tty"; then got=1; fi
            else
                if IFS= read -r -n 1 -s -t 1 key <"$tty"; then got=1; fi
            fi

            # Move cursor back up to redraw block next iteration (IMPORTANT: to tty)
                # We move (lines-1) lines up (to the start of the block) and return to column 0,
                # so the next print redraws the block in place.
                # Assumes the block is exactly 'lines' lines tall (message + optional keymap + countdown)
            if (( lines > 1 )); then
                printf '\e[%dA' "$((lines-1))" >"$tty"
            fi
            printf '\r' >"$tty"

            if (( got )); then
                [[ -z "$key" ]] && key=$'\n'

                case "$key" in
                    p|P|" ")
                        [[ "$dlgchoices" == *"P"* ]] || continue
                        (( paused )) && paused=0 || paused=1
                        continue
                        ;;

                    r|R)
                        [[ "$dlgchoices" == *"R"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 3
                        ;;

                    c|C|$'\e')
                        [[ "$dlgchoices" == *"C"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 2
                        ;;

                    q|Q)
                        [[ "$dlgchoices" == *"Q"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 4
                        ;;

                    $'\n'|$'\r')
                        [[ "$dlgchoices" == *"E"* ]] || continue
                        # If you want Enter to count as "any key", use:
                        # [[ "$dlgchoices" == *"E"* || "$dlgchoices" == *"A"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 0
                        ;;

                    *)
                        # 1) Custom key? return 10+
                        local rc=""
                        rc="$(sgnd_dlg_custom_rc_for_key "$key" 2>/dev/null || true)"
                        if [[ -n "$rc" ]]; then
                            printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                            return "$rc"
                        fi

                        # 2) Fallback to "any key continues" if enabled
                        [[ "$dlgchoices" == *"A"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 0
                        ;;
                esac
            fi


            if (( ! paused )); then      
                ((seconds--))
                if (( seconds < 0 )); then
                    printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                    saydebug '%s\n' "${TUI_TEXT}Auto-continued.${RESET}" >"$tty"
                    return 1
                fi
            fi
        done
    }

    # sgnd_prompt_fromlist
        # Purpose:
        #   Prompt for a list of state or configuration entries described by state-spec lines.
        #
        # Behavior:
        #   - Parses each spec line via sgnd_parse_statespec.
        #   - Resolves the target variable name, label, default value, and validator.
        #   - Uses the current shell value when present, otherwise the spec default.
        #   - Calls ask() for each valid entry and stores results directly in the target variables.
        #   - Optionally auto-aligns labels based on the longest label in the input list.
        #
        # Options:
        #   --labelwidth N
        #       Fixed label width. Default: 0
        #   --autoalign
        #       Compute label width from the longest label in the provided specs.
        #   --colorize MODE
        #       Passed through to ask --colorize.
        #       Default: both
        #   --
        #       End of options; remaining arguments are spec lines.
        #
        # Spec format:
        #   Each spec line is parsed by sgnd_parse_statespec and is expected to provide:
        #     _statekey
        #     _statelabel
        #     _statedefault
        #     _statevalidate
        #
        # Inputs (globals / dependencies):
        #   sgnd_parse_statespec
        #   _td_is_ident
        #   sgnd_trim
        #   sgnd_fill_right
        #   ask
        #   saywarning
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_prompt_fromlist --autoalign -- "${SGND_STATE_VARIABLES[@]}"
        #
        # Examples:
        #   sgnd_prompt_fromlist --autoalign --colorize both -- \
        #       "HOST|Host name|localhost|validate_text|" \
        #       "PORT|Port|8080|validate_int|"
        #
        # Notes:
        #   - Invalid state keys are skipped with a warning.
        #   - Results are assigned directly to the variables named by each spec.
    sgnd_prompt_fromlist() {
        local labelwidth=0
        local autoalign=0
        local colorize="both"

        # ---- parse optional parameters ---------------------------------
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --labelwidth)
                    labelwidth="$2"
                    shift 2
                    ;;
                --autoalign)
                    autoalign=1
                    shift
                    ;;
                --colorize)
                    colorize="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done

        # ---- compute labelwidth if autoalign is enabled -----------------
        if (( autoalign )) && (( labelwidth <= 0 )); then
            local line key label def validator
            local w=0

            for line in "$@"; do
                sgnd_parse_statespec "$line"
                key="$(sgnd_trim "$_statekey")"
                label="$(sgnd_trim "$_statelabel")"

                _td_is_ident "$key" || continue
                [[ -n "$label" ]] || label="$key"

                ((${#label} > w)) && w=${#label}
            done

            labelwidth="$w"
        fi

        # ---- main prompt loop ------------------------------------------
        local line key label def validator
        local current chosen

        for line in "$@"; do
            sgnd_parse_statespec "$line"

            key="$(sgnd_trim "$_statekey")"
            label="$(sgnd_trim "$_statelabel")"
            def="$(sgnd_trim "$_statedefault")"
            validator="$(sgnd_trim "$_statevalidate")"

            _td_is_ident "$key" || { saywarning "Skipping invalid state key: '$key'"; continue; }
            [[ -n "$label" ]] || label="$key"

            # ---- optional label alignment --------------------------------
            if (( labelwidth > 0 )); then
                label="$(sgnd_fill_right "$label" "$labelwidth" " ")"
            fi

            current="${!key-}"
            if [[ -n "$current" ]]; then
                chosen="$current"
            else
                chosen="$def"
            fi

            if [[ -n "$validator" ]]; then
                ask --label "$label" --var "$key" \
                    --default "$chosen" \
                    --validate "$validator" \
                    --colorize "$colorize"
            else
                ask --label "$label" --var "$key" \
                    --default "$chosen" \
                    --colorize "$colorize"
            fi
        done
    }

    # sgnd_ask_decision
        # Purpose:
        #   Prompt for a constrained symbolic decision and normalize the result.
        #
        # Behavior:
        #   - Builds a prompt label from free text plus compact choice display.
        #   - Optionally runs sgnd_dlg_autocontinue() first when --seconds > 0.
        #   - Maps dialog outcomes to canonical decision tokens when possible.
        #   - Falls back to ask() for typed input when needed.
        #   - Re-prompts until a valid value is entered.
        #   - Returns the canonical decision token in the requested variable.
        #
        # Options:
        #   --label TEXT
        #       Prompt label text.
        #   --choices SPEC
        #       Choice specification, e.g. "OK|O,Redo|R,Quit|Q|Cancel|C"
        #   --default VALUE
        #       Default decision token or alias.
        #   --var NAME
        #       Destination variable name. Default: decision
        #   --seconds N
        #       Optional auto-continue countdown in seconds.
        #   --dlgchoices TEXT
        #       Optional sgnd_dlg_autocontinue key set. Default: ERCPQTH
        #   --displaychoices 0|1
        #       Append compact choices to the label. Default: 1
        #   --colorize MODE
        #       Passed through to ask(). Default: both
        #   --labelclr ANSI
        #       Passed through to ask().
        #   --inputclr ANSI
        #       Passed through to ask().
        #   --labelwidth N
        #       Passed through to ask().
        #   --pad N
        #       Passed through to ask().
        #
        # Returns:
        #   0 on accepted valid input.
    sgnd_ask_decision() {
        local label=""
        local choices=""
        local default_value=""
        local var_name="decision"
        local seconds=0
        local dlgchoices="ERCPQTH"
        local displaychoices=1
        local colorize="both"
        local labelclr="${TUI_LABEL}"
        local inputclr="${TUI_INPUT}"
        local labelwidth=25
        local pad=0

        local prompt_label=""
        local display=""
        local typed=""
        local canonical=""
        local dlg_message=""
        local dlg_rc=0

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --default)        default_value="$2"; shift 2 ;;
                --var)            var_name="$2"; shift 2 ;;
                --seconds)        seconds="$2"; shift 2 ;;
                --dlgchoices)     dlgchoices="$2"; shift 2 ;;
                --displaychoices) displaychoices="$2"; shift 2 ;;
                --colorize)       colorize="$2"; shift 2 ;;
                --labelclr)       labelclr="$2"; shift 2 ;;
                --inputclr)       inputclr="$2"; shift 2 ;;
                --labelwidth)     labelwidth="$2"; shift 2 ;;
                --pad)            pad="$2"; shift 2 ;;
                --)               shift; break ;;
                *)
                    [[ -z "$label" ]] && label="$1"
                    shift
                    ;;
            esac
        done

        prompt_label="$label"

        if [[ -n "$choices" && "$displaychoices" -eq 1 ]]; then
            display="$(sgnd_decision_display_choices "$choices")"
            [[ -n "$display" ]] && prompt_label+=" [$display]"
        fi

        # optional timed phase
        if [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds > 0 )); then
            dlg_message="$prompt_label"
            sgnd_dlg_autocontinue "$seconds" "$dlg_message" "$dlgchoices"
            dlg_rc=$?

            canonical="$(sgnd_decision_from_dialog_rc "$dlg_rc" "$choices" "$default_value" 2>/dev/null || true)"
            if [[ -n "$canonical" ]]; then
                printf -v "$var_name" '%s' "$canonical"
                return 0
            fi
        fi

        while :; do
            ask \
                --label "$prompt_label" \
                --var typed \
                --default "$default_value" \
                --colorize "$colorize" \
                --labelclr "$labelclr" \
                --inputclr "$inputclr" \
                --labelwidth "$labelwidth" \
                --pad "$pad"

            if [[ -z "$choices" ]]; then
                canonical="${typed^^}"
                break
            fi

            canonical="$(sgnd_decision_normalize "$typed" "$choices" "$default_value")" && break

            saywarning "Invalid choice: $typed"
        done

        printf -v "$var_name" '%s' "$canonical"
    }


