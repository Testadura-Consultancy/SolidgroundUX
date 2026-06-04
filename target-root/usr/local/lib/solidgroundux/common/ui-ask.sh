# =====================================================================================
# SolidgroundUX - UI Ask
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
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
#   Client      : -
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Library guard
        # Purpose:
        #   Prevent direct execution of a source-only module and avoid repeated initialization.
        #
        # Behavior:
        #   - Derives a module-specific guard variable from the current filename.
        #   - Exits with status 2 when the file is executed directly.
        #   - Returns immediately when the module has already been loaded.
        #   - Marks the module as loaded before normal initialization continues.
        #
        # Returns:
        #   0 when the module may continue loading or was already loaded.
        #   Exits with status 2 when executed directly.
        #
        # Usage:
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

# --- Internal helpers ----------------------------------------------------------------
    # fn: _ask_expand_choices - Ask Expand Choices
        # Purpose:
        #   Internal helper function for the  ask expand choices operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   _ask_expand_choices [arguments...]
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

    # fn: _ask_choice_is_valid
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

    # fn: _ask_build_prompt - Ask Build Prompt
        # Purpose:
        #   Internal helper function for the  ask build prompt operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   _ask_build_prompt [arguments...]
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

    # fn: _ask_validate
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

    # fn: _ask_decision_expand_choices - Ask Decision Expand Choices
        # Purpose:
        #   Internal helper function for the  ask decision expand choices operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   _ask_decision_expand_choices [arguments...]
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

    # fn: _ask_decision_normalize - Ask Decision Normalize
        # Purpose:
        #   Internal helper function for the  ask decision normalize operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   _ask_decision_normalize [arguments...]
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

    # fn: _ask_decision_display
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

    # fn: _ask_decision_map_dlg_rc - Ask Decision Map Dlg Rc
        # Purpose:
        #   Internal helper function for the  ask decision map dlg rc operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   _ask_decision_map_dlg_rc [arguments...]
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

    # fn: _ask_parse_fieldspec - Ask Parse Fieldspec
        # Purpose:
        #   Internal helper function for the  ask parse fieldspec operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   _ask_parse_fieldspec [arguments...]
    _ask_parse_fieldspec() {
        local spec="${1-}"

        IFS='|' read -r \
            _ask_field_key \
            _ask_field_label \
            _ask_field_default \
            _ask_field_validate \
            <<< "$spec"
    }

    # fn: _ask_is_ident
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
    # fn: ask - Ask
        # Purpose:
        #   Public API function for the ask operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   ask [arguments...]
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

    # fn: ask_decision - Ask Decision
        # Purpose:
        #   Public API function for the ask decision operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   ask_decision [arguments...]
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

    # fn: ask_dlg_autocontinue - Ask Dlg Autocontinue
        # Purpose:
        #   Public API function for the ask dlg autocontinue operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   ask_dlg_autocontinue [arguments...]
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

    # fn: ask_choose - Ask Choose
        # Purpose:
        #   Public API function for the ask choose operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   ask_choose [arguments...]
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

    # fn: ask_choose_immediate - Ask Choose Immediate
        # Purpose:
        #   Public API function for the ask choose immediate operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   ask_choose_immediate [arguments...]
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

    # fn: ask_prompt_form - Ask Prompt Form
        # Purpose:
        #   Public API function for the ask prompt form operation.
        #
        # Behavior:
        #   - Performs the operation implied by its name and arguments.
        #   - Uses SolidgroundUX UI, logging, or bootstrap conventions where applicable.
        #
        # Returns:
        #   0 on success, non-zero when validation or execution fails.
        #
        # Usage:
        #   ask_prompt_form [arguments...]
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



