# =====================================================================================
# SolidgroundUX - UI Ask
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.2
#   Build       : 2608700
#   Checksum    :dff6fe73ee6826fe02ccda820afe458709f2f4550516bbb0cda37129e49bab1e
#   Source      : ui-ask.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide interactive prompting and lightweight dialog utilities
#
# Description:
#   Provides the framework's console interaction layer.
#
#   The library:
#     - Prompts for typed input using labeled questions
#     - Supports editable defaults and validation hooks
#     - Supports constrained symbolic decisions
#     - Supports timed auto-continue prompts with simple intervention keys
#     - Supports typed and immediate choice selection helpers
#     - Supports prompting a variable set from field-spec lines
#     - Reads input from the controlling terminal to avoid stdin conflicts
#
# Public API:
#   - ask
#   - ask_decision
#   - ask_dlg_autocontinue
#   - ask_choose
#   - ask_choose_immediate
#   - ask_prompt_form
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
    # _sgnd_lib_guard
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

# --- Internal helpers ----------------------------------------------------------------
    # _ask_expand_choices
        # Purpose:
        #   Expand a comma-separated choice specification into individual allowed values.
        #
        # Arguments:
        #   $1  Choice spec string. Supports:
        #       - Literal tokens: "dev,acc,prod"
        #       - Simple ranges:  "A-Z", "0-9" (single ASCII [[:alnum:]] endpoints)
        #       - Optional whitespace around tokens: "A-Z, 1-3, foo"
        #
        # Output:
        #   Prints one expanded value per line.
        #
        # Returns:
        #   0 always.
    _ask_expand_choices() {
        local spec="$1"
        local -a out=()
        local -a parts=()
        local part=""
        local start=""
        local end=""
        local i=0
        local s=0
        local e=0

        IFS=',' read -r -a parts <<< "$spec"

        for part in "${parts[@]}"; do
            part="${part#"${part%%[![:space:]]*}"}"
            part="${part%"${part##*[![:space:]]}"}"

            if [[ "$part" =~ ^([[:alnum:]])-([[:alnum:]])$ ]]; then
                start="${BASH_REMATCH[1]}"
                end="${BASH_REMATCH[2]}"

                s=$(printf '%d' "'$start")
                e=$(printf '%d' "'$end")

                if (( s > e )); then
                    saywarning "Invalid range: $part"
                    continue
                fi

                for (( i=s; i<=e; i++ )); do
                    out+=( "$(printf '\\%03o' "$i")" )
                done
            else
                out+=( "$part" )
            fi
        done

        for part in "${out[@]}"; do
            printf '%b\n' "$part"
        done
    }

    # _ask_choice_is_valid
        # Purpose:
        #   Validate a single choice against a ask_choose-style choices list.
        #
        # Arguments:
        #   $1  VALUE
        #   $2  CHOICES
        #
        # Returns:
        #   0 if valid
        #   1 if invalid
    _ask_choice_is_valid() {
        local value="${1-}"
        local choices="${2-}"
        local opt=""
        local -a expanded=()

        [[ -z "$choices" ]] && return 0

        mapfile -t expanded < <(_ask_expand_choices "$choices")
        for opt in "${expanded[@]}"; do
            if [[ "${value^^}" == "${opt^^}" ]]; then
                return 0
            fi
        done

        return 1
    }

    # _ask_build_prompt
        # Purpose:
        #   Build a readline-safe prompt with visible-width padding and optional colors.
        #
        # Arguments:
        #   $1  LABEL
        #   $2  LABELWIDTH
        #   $3  PAD
        #   $4  LABELCLR
        #   $5  INPUTCLR
        #   $6  COLORIZE
        #
        # Output:
        #   Writes the composed prompt string to stdout.
        #
        # Returns:
        #   0 always.
    _ask_build_prompt() {
        local label="$1"
        local labelwidth="$2"
        local pad="$3"
        local labelclr="$4"
        local inputclr="$5"
        local colorize="$6"

        local rl_start=$'\001'
        local rl_end=$'\002'
        local label_color="$labelclr"
        local input_color="$inputclr"
        local padded_label=""
        local padleft=""
        local prompt=""

        case "$colorize" in
            none)
                label_color=""
                input_color=""
                ;;
            label)
                input_color=""
                ;;
            input)
                label_color=""
                ;;
            both) ;;
            *) ;;
        esac

        if [[ -n "$labelwidth" && "$labelwidth" =~ ^[0-9]+$ ]]; then
            padded_label="$(sgnd_padded_visible "$label" "$labelwidth")"
        else
            padded_label="$label"
        fi

        padleft="$(sgnd_string_repeat " " "${pad:-0}")"
        padded_label="${padleft}${padded_label}"

        [[ -n "$label_color" ]] && prompt+="${rl_start}${label_color}${rl_end}"
        prompt+="$padded_label"
        [[ -n "${RESET-}" ]] && prompt+="${rl_start}${RESET}${rl_end}"
        prompt+=" : "
        [[ -n "$input_color" ]] && prompt+="${rl_start}${input_color}${rl_end}"

        printf '%s' "$prompt"
    }

    # _ask_validate
        # Purpose:
        #   Run a validation callback when provided.
        #
        # Arguments:
        #   $1  VALIDATE_FUNCTION
        #   $2  VALUE
        #
        # Returns:
        #   0 if valid or no validator is supplied.
        #   Non-zero when the validator rejects the value.
    _ask_validate() {
        local fn="${1-}"
        local value="${2-}"

        [[ -z "$fn" ]] && return 0
        "$fn" "$value"
    }

    # _ask_decision_expand_choices
        # Purpose:
        #   Expand a symbolic decision specification into canonical choices and aliases.
        #
        # Arguments:
        #   $1  CHOICES
        #       Choice specification, e.g. "YES|Y,NO|N".
        #
        # Output:
        #   Writes rows to stdout as CANONICAL|ALIAS.
        #
        # Returns:
        #   0 always.
    _ask_decision_expand_choices() {
        local spec="${1-}"
        local group=""
        local canonical=""
        local alias=""
        local IFS=','
        local -a aliases=()

        for group in $spec; do
            canonical=""
            IFS='|' read -r -a aliases <<< "$group"

            for alias in "${aliases[@]}"; do
                alias="${alias#"${alias%%[![:space:]]*}"}"
                alias="${alias%"${alias##*[![:space:]]}"}"
                alias="${alias^^}"

                [[ -n "$alias" ]] || continue
                [[ -z "$canonical" ]] && canonical="$alias"

                printf '%s|%s\n' "$canonical" "$alias"
            done
        done
    }

    # _ask_decision_normalize
        # Purpose:
        #   Normalize a typed decision value to its canonical token.
        #
        # Arguments:
        #   $1  VALUE
        #   $2  CHOICES
        #   $3  DEFAULT
        #
        # Output:
        #   Writes canonical token to stdout on success.
        #
        # Returns:
        #   0 if valid
        #   1 if invalid
    _ask_decision_normalize() {
        local value="${1-}"
        local choices="${2-}"
        local default_value="${3-}"
        local canonical=""
        local alias=""

        [[ -z "$value" ]] && value="$default_value"

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value^^}"

        while IFS='|' read -r canonical alias; do
            [[ "$value" == "$alias" ]] || continue
            printf '%s\n' "$canonical"
            return 0
        done < <(_ask_decision_expand_choices "$choices")

        return 1
    }

    # _ask_decision_display
        # Purpose:
        #   Build a compact display string from a decision specification.
        #
        # Arguments:
        #   $1  CHOICES
        #
        # Output:
        #   Writes display string, e.g. YES/NO.
        #
        # Returns:
        #   0 always.
    _ask_decision_display() {
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
            [[ -n "$out" ]] && out+="/"
            out+="$first"
        done

        printf '%s\n' "$out"
    }

    # _ask_decision_map_dlg_rc
        # Purpose:
        #   Map ask_dlg_autocontinue return codes to a canonical decision when possible.
        #
        # Arguments:
        #   $1  RC
        #   $2  CHOICES
        #   $3  DEFAULT
        #
        # Output:
        #   Writes canonical decision token to stdout when mapped.
        #
        # Returns:
        #   0 if mapped
        #   1 if no mapping applies and typed fallback should be used
    _ask_decision_map_dlg_rc() {
        local rc="${1-}"
        local choices="${2-}"
        local default_value="${3-}"
        local mapped=""

        case "$rc" in
            0|1)
                mapped="$(_ask_decision_normalize "$default_value" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            2)
                mapped="$(_ask_decision_normalize "CANCEL" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(_ask_decision_normalize "QUIT" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(_ask_decision_normalize "NO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            3)
                mapped="$(_ask_decision_normalize "REDO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

    # _ask_parse_fieldspec
        # Purpose:
        #   Parse a simple field-spec line into reusable globals for ask_prompt_form().
        #
        # Behavior:
        #   - Splits a pipe-delimited spec line into:
        #       key|label|default|validate
        #   - Writes parsed values to _ask_field_* globals.
        #   - Missing fields are allowed and become empty strings.
        #
        # Arguments:
        #   $1  FIELD_SPEC
        #       Pipe-delimited field spec.
        #
        # Outputs (globals):
        #   _ask_field_key
        #   _ask_field_label
        #   _ask_field_default
        #   _ask_field_validate
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _ask_parse_fieldspec "HOST|Host name|localhost|validate_text"
    _ask_parse_fieldspec() {
        local spec="${1-}"

        IFS='|' read -r \
            _ask_field_key \
            _ask_field_label \
            _ask_field_default \
            _ask_field_validate \
            <<< "$spec"
    }

    # _ask_is_ident
        # Purpose:
        #   Test whether a value is a valid shell variable identifier.
        #
        # Arguments:
        #   $1  VALUE
        #
        # Returns:
        #   0 if valid
        #   1 if invalid
    _ask_is_ident() {
        [[ "${1-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
    }

# --- Public API ---------------------------------------------------------------------
    # ask
        # Purpose:
        #   Prompt for interactive input from the controlling terminal (/dev/tty),
        #   with optional defaulting, validation, and direct assignment to a variable.
        #
        # Behavior:
        #   - Reads from /dev/tty rather than stdin, so it remains safe in scripts
        #     that consume piped or redirected stdin.
        #   - Supports readline-style editing and optional prefilled defaults.
        #   - Supports aligned labels via --labelwidth and --pad.
        #   - Uses readline-safe prompt markers so ANSI color codes do not break
        #     cursor positioning or default-value editing.
        #   - Optionally validates the entered value through a callback function.
        #   - Re-prompts recursively when validation fails.
        #   - Can either assign the accepted value to a variable or echo it.
        #
        # Arguments:
        #   LABEL
        #       Positional fallback label when --label is omitted.
        #
        # Options:
        #   --label TEXT
        #       Prompt label text.
        #   --default VALUE
        #       Editable default value; empty entry resolves to this value.
        #   --validate FUNC
        #       Validation callback invoked as:
        #           FUNC "$value"
        #       Return 0 to accept; non-zero to reject and re-prompt.
        #   --colorize MODE
        #       Prompt coloring mode:
        #           none | label | input | both
        #       Default: both
        #   --labelwidth N
        #       Visible width of the label column.
        #       Default: 25
        #   --pad N
        #       Left indentation in spaces.
        #       Default: 0
        #   --labelclr ANSI
        #       ANSI color/style prefix for the label.
        #       Default: TUI_LABEL
        #   --inputclr ANSI
        #       ANSI color/style prefix for the input area.
        #       Default: TUI_INPUT
        #   --var NAME
        #       Destination variable name for the accepted value.
        #   --echo
        #       Echo accepted input with ✓ / ✗ feedback to /dev/tty.
        #       Also prints the accepted value to stdout when --var is not used.
        #
        # Inputs (globals):
        #   TUI_LABEL
        #   TUI_INPUT
        #   TUI_VALID
        #   TUI_INVALID
        #   RESET
        #   sgnd_padded_visible
        #   sgnd_string_repeat
        #
        # Outputs (globals):
        #   Assigns the accepted value to --var NAME when provided.
        #
        # Output:
        #   - Prints validation feedback to /dev/tty when --echo is enabled.
        #   - Prints the accepted value to stdout only when --var is not used and
        #     --echo is enabled.
        #
        # Returns:
        #   0  on accepted input
        #   2  if /dev/tty cannot be opened
        #
        # Usage:
        #   ask --label "Project name" --var project
        #   ask --label "Environment" --default "dev" --var env
        #   ask --label "Release date" --validate validate_date --var release_date
        #
        # Examples:
        #   # Plain text input
        #   ask --label "Product" --var PRODUCT
        #
        #   # With default
        #   ask --label "Version" --default "1.0" --var VERSION
        #
        #   # With validation
        #   ask --label "Staging directory" \
        #       --default "$STAGING_ROOT" \
        #       --validate validate_dir_exists \
        #       --var STAGING_ROOT
        #
        #   # With alignment / styling
        #   ask --label "Release" \
        #       --default "$RELEASE" \
        #       --var RELEASE \
        #       --labelwidth 30 \
        #       --pad 4 \
        #       --labelclr "${CYAN}" \
        #       --colorize both
        #
        # Notes:
        #   - Re-prompt currently uses recursion; convert to a loop later if you want
        #     to avoid recursive retries entirely.
        #   - This is the base prompt primitive; higher-level helpers such as
        #     ask_decision and ask_choose build on top of it.
    ask() {
        local label=""
        local var_name=""
        local colorize="both"
        local validate_fn=""
        local def_value=""
        local echo_input=0
        local labelwidth=25
        local pad=0
        local labelclr="${TUI_LABEL}"
        local inputclr="${TUI_INPUT}"

        local -a _orig_args=( "$@" )

        local prompt=""
        local value=""
        local ok=1
        local tty_fd=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)       label="$2"; shift 2 ;;
                --labelwidth)  labelwidth="$2"; shift 2 ;;
                --pad)         pad="$2"; shift 2 ;;
                --labelclr)    labelclr="$2"; shift 2 ;;
                --inputclr)    inputclr="$2"; shift 2 ;;
                --var)         var_name="$2"; shift 2 ;;
                --colorize)    colorize="$2"; shift 2 ;;
                --validate)    validate_fn="$2"; shift 2 ;;
                --default)     def_value="$2"; shift 2 ;;
                --echo)        echo_input=1; shift ;;
                --)            shift; break ;;
                *)             [[ -z "$label" ]] && label="$1"; shift ;;
            esac
        done

        [[ "$labelwidth" =~ ^[0-9]+$ ]] || labelwidth=25
        [[ "$pad" =~ ^[0-9]+$ ]] || pad=0

        prompt="$(_ask_build_prompt "$label" "$labelwidth" "$pad" "$labelclr" "$inputclr" "$colorize")"

        exec {tty_fd}</dev/tty || {
            printf "%bNo TTY available%b\n" "$TUI_INVALID" "$RESET"
            return 2
        }

        if [[ -n "$def_value" ]]; then
            IFS= read -u "$tty_fd" -e -p "$prompt" -i "$def_value" value
            [[ -z "$value" ]] && value="$def_value"
        else
            IFS= read -u "$tty_fd" -e -p "$prompt" value
        fi

        exec {tty_fd}<&-
        printf "%b" "$RESET" >/dev/tty

        if _ask_validate "$validate_fn" "$value"; then
            ok=1
        else
            ok=0
        fi

        if (( echo_input )); then
            if (( ok )); then
                printf "  %b%s%b %b✓%b\n" \
                    "$inputclr" "$value" "$RESET" \
                    "$TUI_VALID" "$RESET" >/dev/tty
            else
                printf "  %b%s%b %b✗%b\n" \
                    "$inputclr" "$value" "$RESET" \
                    "$TUI_INVALID" "$RESET" >/dev/tty
            fi
        fi

        if (( ! ok )); then
            printf "%bInvalid value. Please try again.%b\n" "$TUI_INVALID" "$RESET" >/dev/tty
            ask "${_orig_args[@]}"
            return
        fi

        if [[ -n "$var_name" ]]; then
            printf -v "$var_name" '%s' "$value"
        elif (( echo_input )); then
            printf '%s\n' "$value"
        fi
    }

    # ask_decision
        # Purpose:
        #   Prompt for a constrained symbolic decision and store the canonical result.
        #
        # Behavior:
        #   - Builds on top of ask().
        #   - Accepts a developer-defined decision specification with aliases.
        #   - Optionally runs ask_dlg_autocontinue() first when --seconds > 0.
        #   - Validates typed input against the allowed decision values.
        #   - Stores the canonical decision token in the variable named by --var.
        #
        # Options:
        #   --label TEXT
        #   --choices SPEC
        #   --default VALUE
        #   --var NAME
        #   --seconds N
        #   --displaychoices 0|1
        #   --colorize MODE
        #   --labelclr ANSI
        #   --inputclr ANSI
        #   --labelwidth N
        #   --pad N
        #
        # Usage:
        #   ask_decision \
        #       --label "Use existing staging files?" \
        #       --choices "YES|Y,NO|N" \
        #       --default "NO" \
        #       --var answer
        #
        # Examples:
        #   local action=""
        #   ask_decision \
        #       --label "Create release using these settings?" \
        #       --choices "OK|O,REDO|R,CANCEL|C" \
        #       --default "OK" \
        #       --seconds 5 \
        #       --var action
        #
        #   local answer=""
        #   ask_decision \
        #       --label "Use existing staging files?" \
        #       --choices "YES|Y,NO|N" \
        #       --default "NO" \
        #       --var answer
        #
        #   case "$answer" in
        #       YES) FLAG_USEEXISTING=1 ;;
        #       NO)  FLAG_USEEXISTING=0 ;;
        #   esac
    ask_decision() {
        local label=""
        local choices=""
        local default_value=""
        local var_name="decision"
        local seconds=0
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
        local dlg_rc=0

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --default)        default_value="$2"; shift 2 ;;
                --var)            var_name="$2"; shift 2 ;;
                --seconds)        seconds="$2"; shift 2 ;;
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
            display="$(_ask_decision_display "$choices")"
            [[ -n "$display" ]] && prompt_label+=" [$display]"
        fi

        if [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds > 0 )); then
            ask_dlg_autocontinue --seconds "$seconds" --message "$prompt_label" --redo --cancel --pause
            dlg_rc=$?
            canonical="$(_ask_decision_map_dlg_rc "$dlg_rc" "$choices" "$default_value" 2>/dev/null || true)"
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

            canonical="$(_ask_decision_normalize "$typed" "$choices" "$default_value" 2>/dev/null || true)"
            [[ -n "$canonical" ]] && break

            saywarning "Invalid choice: $typed"
        done

        printf -v "$var_name" '%s' "$canonical"
    }

    # ask_dlg_autocontinue
        # Purpose:
        #   Show a lightweight timed auto-continue prompt on /dev/tty.
        #
        # Behavior:
        #   - Displays an optional message.
        #   - Displays a countdown line that updates once per second.
        #   - Auto-continues when the countdown expires.
        #   - Supports optional redo, cancel, and pause/resume controls.
        #   - Supports either Enter-to-continue or any-key-to-continue behavior.
        #
        # Options:
        #   --seconds N
        #   --message TEXT
        #   --redo
        #   --cancel
        #   --pause
        #   --anykey
        #   --hidelegend
        #
        # Returns:
        #   0  explicit continue
        #   1  timeout / auto-continue
        #   2  cancel
        #   3  redo
        #
        # Usage:
        #   ask_dlg_autocontinue --seconds 5 --message "Continuing shortly..."
        #
        # Examples:
        #   ask_dlg_autocontinue \
        #       --seconds 5 \
        #       --message "Create release using these settings?" \
        #       --redo \
        #       --cancel \
        #       --pause
        #
        #   ask_dlg_autocontinue \
        #       --seconds 5 \
        #       --message "Create release using these settings?" \
        #       --redo \
        #       --cancel \
        #       --pause
        #
        #   case $? in
        #       0|1) proceed ;;
        #       2)   exit 1 ;;
        #       3)   continue ;;
        #   esac
    ask_dlg_autocontinue() {
        local seconds=5
        local message=""
        local allow_redo=0
        local allow_cancel=0
        local allow_pause=0
        local allow_anykey=0
        local hide_legend=0

        local tty="/dev/tty"
        local paused=0
        local key=""
        local got=0
        local clr=""
        local line_count=1
        local legend=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --seconds)    seconds="$2"; shift 2 ;;
                --message)    message="$2"; shift 2 ;;
                --redo)       allow_redo=1; shift ;;
                --cancel)     allow_cancel=1; shift ;;
                --pause)      allow_pause=1; shift ;;
                --anykey)     allow_anykey=1; shift ;;
                --hidelegend) hide_legend=1; shift ;;
                --)           shift; break ;;
                *)
                    [[ -z "$message" ]] && message="$1"
                    shift
                    ;;
            esac
        done

        [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=5
        [[ -r "$tty" && -w "$tty" ]] || return 0

        clr="$(sgnd_sgr "$WHITE" "" "$FX_ITALIC")"

        [[ -n "$message" ]] && (( line_count++ ))
        (( ! hide_legend )) && (( line_count++ ))

        while true; do
            legend=""
            if (( allow_anykey )); then
                legend+="Any key=continue; "
            else
                legend+="Enter=continue; "
            fi
            (( allow_redo )) && legend+="R=redo; "
            (( allow_cancel )) && legend+="C/Esc=cancel; "
            if (( allow_pause )); then
                if (( paused )); then
                    legend+="P/Space=resume; "
                else
                    legend+="P/Space=pause; "
                fi
            fi
            legend="${legend%; }"

            if [[ -n "$message" ]]; then
                printf '\r\033[K%s%s%s\n' "$TUI_TEXT" "$message" "$RESET" >"$tty"
            fi
            if (( ! hide_legend )); then
                printf '\r\033[K%s%s%s\n' "$TUI_TEXT" "$legend" "$RESET" >"$tty"
            fi
            if (( paused )); then
                printf '\r\033[K%sPaused...%s' "$clr" "$RESET" >"$tty"
            else
                printf '\r\033[K%sContinuing in %ds...%s' "$clr" "$seconds" "$RESET" >"$tty"
            fi

            got=0
            key=""
            if (( paused )); then
                if IFS= read -r -n 1 -s key <"$tty"; then
                    got=1
                fi
            else
                if IFS= read -r -n 1 -s -t 1 key <"$tty"; then
                    got=1
                fi
            fi

            if (( line_count > 1 )); then
                printf '\033[%dA' "$((line_count - 1))" >"$tty"
            fi
            printf '\r' >"$tty"

            if (( got )); then
                [[ -z "$key" ]] && key=$'\n'
                case "$key" in
                    p|P|" ")
                        (( allow_pause )) || continue
                        (( paused )) && paused=0 || paused=1
                        continue
                        ;;
                    r|R)
                        (( allow_redo )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 3
                        ;;
                    c|C|$'\e')
                        (( allow_cancel )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 2
                        ;;
                    $'\n'|$'\r')
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 0
                        ;;
                    *)
                        (( allow_anykey )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 0
                        ;;
                esac
            fi

            if (( ! paused )); then
                ((seconds--))
                if (( seconds < 0 )); then
                    printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                    return 1
                fi
            fi
        done
    }

    # ask_choose
        # Purpose:
        #   Prompt for a constrained user choice using standard line input.
        #
        # Behavior:
        #   - Reads input from /dev/tty.
        #   - Requires Enter to confirm input.
        #   - Validates input against the allowed choice list when provided.
        #   - Re-prompts on invalid input when keepasking=1.
        #   - Supports default values.
        #   - Uses shared prompt rendering via _ask_build_prompt().
        #
        # Options:
        #   --label TEXT
        #       Prompt label.
        #
        #   --var NAME
        #       Destination variable name.
        #       Default: choice
        #
        #   --choices LIST
        #       Allowed values as comma-separated tokens and/or ranges.
        #
        #   --default VALUE
        #       Default value (editable).
        #
        #   --displaychoices 0|1
        #       Append [choices] to the label.
        #       Default: 1
        #
        #   --keepasking 0|1
        #       Re-prompt on invalid input.
        #       Default: 1
        #
        #   --labelwidth N
        #       Align label to fixed width.
        #
        #   --pad N
        #       Spacing between label and ':'.
        #
        #   --labelclr ANSI
        #       Color/style applied to label.
        #
        #   --inputclr ANSI
        #       Color/style applied to input.
        #
        #   --colorize MODE
        #       Colorization mode:
        #         label | input | both | none
        #
        # Outputs (globals):
        #   Assigns accepted value to variable defined by --var.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   ask_choose --label "Select option" --choices "1,2,3" --var choice
        #
        # Examples:
        #   # Basic choice
        #   ask_choose \
        #       --label "Action" \
        #       --choices "1,2,3,Q" \
        #       --var ACTION
        #
        #   # With default
        #   ask_choose \
        #       --label "Mode" \
        #       --choices "auto,manual" \
        #       --default "auto" \
        #       --var MODE
        #
        # Notes:
        #   - Intended for standard constrained input.
        #   - For instant key-driven menus, use ask_choose_immediate().
    ask_choose() {
        local label=""
        local choices=""
        local colorize="both"
        local displaychoices=1
        local keepasking=1
        local varname="choice"
        local labelwidth=""
        local pad=""
        local labelclr=""
        local inputclr=""

        local _rsp="" # Purposely ugly variablename to minimize risk of collisions

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --var)            varname="$2"; shift 2 ;;
                --colorize)       colorize="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --displaychoices) displaychoices="$2"; shift 2 ;;
                --keepasking)     keepasking="$2"; shift 2 ;;
                --labelwidth)     labelwidth="$2"; shift 2 ;;
                --pad)            pad="$2"; shift 2 ;;
                --labelclr)       labelclr="$2"; shift 2 ;;
                --inputclr)       inputclr="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$label" ]] && label="$1"
                    shift
                    ;;
            esac
        done

        if [[ -n "$choices" && "$displaychoices" -eq 1 ]]; then
            label+=" [$choices]"
        fi

        while :; do
            if [[ -n "$labelclr" || -n "$inputclr" || -n "$labelwidth" || -n "$pad" ]]; then
                local -a ask_opts=(
                    --label "$label"
                    --var _rsp
                    --colorize "$colorize"
                )
                [[ -n "$labelwidth" ]] && ask_opts+=( --labelwidth "$labelwidth" )
                [[ -n "$pad" ]]        && ask_opts+=( --pad "$pad" )
                [[ -n "$labelclr" ]]   && ask_opts+=( --labelclr "$labelclr" )
                [[ -n "$inputclr" ]]   && ask_opts+=( --inputclr "$inputclr" )

                ask "${ask_opts[@]}"
            else
                ask --label "$label" --var _rsp --colorize "$colorize"
            fi

            [[ -z "$choices" ]] && break

            if _ask_choice_is_valid "$_rsp" "$choices"; then
                break
            fi

            saywarning "Invalid choice: $_rsp"
            (( keepasking )) || break
        done

        printf -v "$varname" '%s' "$_rsp"
    }

    # ask_choose_immediate
        # Purpose:
        #   Prompt for a constrained user choice using immediate-capable TTY input.
        #
        # Behavior:
        #   - Reads directly from /dev/tty.
        #   - Accepts configured instant choices immediately (no Enter required).
        #   - Buffers all other input until Enter is pressed.
        #   - Supports backspace editing for buffered input.
        #   - Validates input against the allowed choice list when provided.
        #   - Re-prompts on invalid input when keepasking=1.
        #   - Uses shared prompt rendering via _ask_build_prompt().
        #
        # Options:
        #   --label TEXT
        #       Prompt label.
        #
        #   --var NAME
        #       Destination variable name.
        #       Default: choice
        #
        #   --choices LIST
        #       Allowed values as comma-separated tokens and/or ranges.
        #       Examples:
        #         "1,2,3,Q"
        #         "A-D,1-5"
        #
        #   --instantchoices LIST
        #       Choices accepted immediately without Enter.
        #
        #   --displaychoices 0|1
        #       Append [choices] to the label.
        #       Default: 1
        #
        #   --keepasking 0|1
        #       Re-prompt on invalid input.
        #       Default: 1
        #
        #   --labelwidth N
        #       Align label to fixed width.
        #
        #   --pad N
        #       Spacing between label and ':'.
        #
        #   --labelclr ANSI
        #       Color/style applied to label.
        #
        #   --inputclr ANSI
        #       Color/style applied to typed input.
        #
        #   --colorize MODE
        #       Colorization mode:
        #         label | input | both | none
        #       Default: both
        #
        # Outputs (globals):
        #   Assigns accepted value to variable defined by --var.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   ask_choose_immediate --label "Action" --choices "1,2,3,Q" --var action
        #
        # Examples:
        #   # Immediate hotkey (Q exits instantly)
        #   ask_choose_immediate \
        #       --label "Action" \
        #       --choices "1,2,3,Q" \
        #       --instantchoices "Q" \
        #       --var ACTION
        #
        #   # Menu-style hotkeys
        #   ask_choose_immediate \
        #       --label "Select option" \
        #       --choices "1-9,B,D,L,V,C,Q" \
        #       --instantchoices "B,D,L,V,C,Q" \
        #       --var ACTION
        #
        #   # Buffered input (Enter required)
        #   ask_choose_immediate \
        #       --label "Enter code" \
        #       --choices "A-D,1-3" \
        #       --var CODE
        #
        # Notes:
        #   - Intended for menu-driven UIs with immediate key reactions.
        #   - For standard constrained input, prefer ask_choose().
    ask_choose_immediate() {
        local label=""
        local choices=""
        local instantchoices=""
        local displaychoices=1
        local keepasking=1
        local varname="choice"

        local labelwidth=""
        local pad=""
        local labelclr=""
        local inputclr=""
        local colorize="both"

        local _rsp=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --var)            varname="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --instantchoices) instantchoices="$2"; shift 2 ;;
                --displaychoices) displaychoices="$2"; shift 2 ;;
                --keepasking)     keepasking="$2"; shift 2 ;;
                --labelwidth)     labelwidth="$2"; shift 2 ;;
                --pad)            pad="$2"; shift 2 ;;
                --labelclr)       labelclr="$2"; shift 2 ;;
                --inputclr)       inputclr="$2"; shift 2 ;;
                --colorize)       colorize="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$label" ]] && label="$1"
                    shift
                    ;;
            esac
        done

        if [[ -n "$choices" && "$displaychoices" -eq 1 ]]; then
            label+=" [$choices]"
        fi

        while :; do
            local key=""
            local buffer=""
            local candidate=""
            local prompt=""

            # --- Use shared prompt builder --------------------------------------
            prompt="$(_ask_build_prompt \
                "$label" \
                "$labelwidth" \
                "$pad" \
                "$labelclr" \
                "$inputclr" \
                "$colorize")"

            printf '%s' "$prompt" >/dev/tty

            while true; do
                IFS= read -r -s -n 1 key </dev/tty || return 1

                case "$key" in
                    "")
                        if [[ -n "$buffer" ]]; then
                            printf '\n' >/dev/tty
                            _rsp="$buffer"
                            break
                        fi
                        ;;

                    $'\177'|$'\b')
                        if [[ -n "$buffer" ]]; then
                            buffer="${buffer%?}"
                            printf '\b \b' >/dev/tty
                        fi
                        ;;

                    *)
                        candidate="${key^^}"

                        # --- Instant choice handling -----------------------------
                        if [[ -n "$instantchoices" ]] && _ask_choice_is_valid "$candidate" "$instantchoices"; then
                            printf '\n' >/dev/tty
                            _rsp="$candidate"
                            break
                        fi

                        buffer+="$key"

                        # --- Input coloring (match ask behavior) ----------------
                        if [[ "$colorize" == "both" || "$colorize" == "input" ]]; then
                            printf '%s%s%s' "${inputclr:-}" "$key" "${RESET:-}" >/dev/tty
                        else
                            printf '%s' "$key" >/dev/tty
                        fi
                        ;;
                esac
            done

            [[ -z "$choices" ]] && break

            if _ask_choice_is_valid "$_rsp" "$choices"; then
                break
            fi

            saywarning "Invalid choice: $_rsp"
            (( keepasking )) || break
        done

        printf -v "$varname" '%s' "$_rsp"
    }

    # ask_prompt_form
        # Purpose:
        #   Prompt for a list of variables described by field-spec lines.
        #
        # Behavior:
        #   - Parses each spec line via _ask_parse_fieldspec.
        #   - Resolves variable name, label, default value, and validator.
        #   - Uses the current shell value when present; otherwise uses the spec default.
        #   - Prompts via ask() and stores results directly in the target variables.
        #   - Optionally auto-aligns labels based on the longest label in the input list.
        #
        # Options:
        #   --labelwidth N
        #       Fixed label width.
        #       Default: 0
        #   --autoalign
        #       Compute label width from the longest label in the provided specs.
        #   --colorize MODE
        #       Passed through to ask --colorize.
        #       Default: both
        #   --pad N
        #       Passed through to ask --pad.
        #       Default: 0
        #   --labelclr ANSI
        #       Passed through to ask --labelclr.
        #   --inputclr ANSI
        #       Passed through to ask --inputclr.
        #   --
        #       End of options; remaining arguments are field-spec lines.
        #
        # Field-spec format:
        #   Each field spec is parsed by _ask_parse_fieldspec and is expected to provide:
        #     _ask_field_key
        #     _ask_field_label
        #     _ask_field_default
        #     _ask_field_validate
        #
        # Required helper contract:
        #   _ask_parse_fieldspec "$line" must populate:
        #     _ask_field_key
        #     _ask_field_label
        #     _ask_field_default
        #     _ask_field_validate
        #
        # Inputs (dependencies):
        #   _ask_parse_fieldspec
        #   _ask_is_ident
        #   ask
        #   saywarning
        #
        # Outputs (globals):
        #   Assigns prompted values directly to the variables named in each field spec.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   ask_prompt_form --autoalign -- "${FORM_FIELDS[@]}"
        #
        # Examples:
        #   askprompt_form --autoalign --colorize both --pad 4 -- \
        #       "HOST|Host name|localhost|validate_text" \
        #       "PORT|Port|8080|validate_int"
        #
        # Notes:
        #   - Invalid variable names are skipped with a warning.
        #   - This function is intentionally lightweight; it is a prompt loop, not a form engine.
    ask_prompt_form() {
        local labelwidth=0
        local autoalign=0
        local colorize="both"
        local pad=0
        local labelclr=""
        local inputclr=""

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
                --pad)
                    pad="$2"
                    shift 2
                    ;;
                --labelclr)
                    labelclr="$2"
                    shift 2
                    ;;
                --inputclr)
                    inputclr="$2"
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

        local line=""
        local key=""
        local label=""
        local def=""
        local validator=""
        local current=""
        local chosen=""
        local maxw=0

        # --- auto-align pass -------------------------------------------------------
        if (( autoalign )) && (( labelwidth <= 0 )); then
            for line in "$@"; do
                _ask_parse_fieldspec "$line"

                key="${_ask_field_key:-}"
                label="${_ask_field_label:-}"

                [[ -n "$key" ]] || continue
                _ask_is_ident "$key" || continue

                [[ -n "$label" ]] || label="$key"
                ((${#label} > maxw)) && maxw=${#label}
            done

            labelwidth="$maxw"
        fi

        # --- prompt pass -----------------------------------------------------------
        for line in "$@"; do
            _ask_parse_fieldspec "$line"

            key="${_ask_field_key:-}"
            label="${_ask_field_label:-}"
            def="${_ask_field_default:-}"
            validator="${_ask_field_validate:-}"

            if ! _ask_is_ident "$key"; then
                saywarning "Skipping invalid field key: '$key'"
                continue
            fi

            [[ -n "$label" ]] || label="$key"

            current="${!key-}"
            if [[ -n "$current" ]]; then
                chosen="$current"
            else
                chosen="$def"
            fi

            if [[ -n "$validator" ]]; then
                if [[ -n "$labelclr" && -n "$inputclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --validate "$validator" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr" \
                        --inputclr "$inputclr"
                elif [[ -n "$labelclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --validate "$validator" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr"
                else
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --validate "$validator" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad"
                fi
            else
                if [[ -n "$labelclr" && -n "$inputclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr" \
                        --inputclr "$inputclr"
                elif [[ -n "$labelclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr"
                else
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad"
                fi
            fi
        done
    }



