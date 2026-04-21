# =====================================================================================
# SolidgroundUX - UI Messaging
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2608700
#   Checksum    : f7e4267783fd0613aceb52b88074ab5baa838b5643fd7b834e6015adca4703b5
#   Source      : ui-say.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide standardized console messaging helpers
#
# Description:
#   Implements consistent message output helpers for console applications.
#
#   The library:
#     - Provides a unified message API via `say` and typed wrappers (info, ok, warn, etc.)
#     - Applies consistent formatting, prefixes, and optional colorization
#     - Supports console output control via verbosity, debug flags, and message-type filtering
#     - Ensures all messages follow a unified visual and structural style
#     - Optionally performs best-effort file logging when enabled
#
# Design principles:
#   - Consistent message semantics across all scripts
#   - Separation of message intent (type) from rendering and output policy
#   - Respect global verbosity, debug, and console filtering rules
#   - Keep output predictable and script-friendly
#
# Role in framework:
#   - Core messaging layer used by all SolidgroundUX scripts
#   - Serves as the primary mechanism for user-facing output and diagnostics
#   - Works alongside ui.sh for rendering and formatting
#
# Non-goals:
#   - Persistent logging frameworks or advanced log management
#   - Complex formatting beyond message-level styling
#   - Replacement for dedicated logging systems
#
# Notes:
#   - Console output is governed by:
#       SGND_LOG_TO_CONSOLE and SGND_CONSOLE_MSGTYPES
#   - DEBUG messages are controlled separately via FLAG_DEBUG
#   - File logging is optional and best-effort; failures do not affect execution
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

# --- Global defaults ----------------------------------------------------------------
    # Can be overridden in:
    #   - environment
    #   - styles/*.sh
    SAY_DATE_DEFAULT="${SAY_DATE_DEFAULT:-0}"              # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="${SAY_SHOW_DEFAULT:-label}"         # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="${SAY_COLORIZE_DEFAULT:-label}" # none|label|msg|both|all|date
    SAY_WRITELOG_DEFAULT="${SAY_WRITELOG_DEFAULT:-0}"     # 0 = no log, 1 = log
    SAY_DATE_FORMAT="${SAY_DATE_FORMAT:-%Y-%m-%d %H:%M:%S}"  # date format for --date

    SGND_LINEBREAK_PENDING=0  # Internal flag to track if a line break is needed before the next message (used by sayprogress)

# --- Helpers ------------------------------------------------------------------------
    # fn: say_should_print_console
        # Purpose:
        #   Determine whether a message type should be printed to the console
        #   according to the current output policy.
        #
        # Behavior:
        #   - SGND_LOG_TO_CONSOLE=0 suppresses all console output.
        #   - FLAG_VERBOSE=1 overrides all filters (always prints).
        #   - DEBUG messages require FLAG_DEBUG=1 (unless verbose).
        #   - All other types must be present in SGND_CONSOLE_MSGTYPES.
        #
        # Arguments:
        #   $1  TYPE
        #       Message type token (case-insensitive).
        #
        # Inputs (globals):
        #   FLAG_VERBOSE, SGND_LOG_TO_CONSOLE, FLAG_DEBUG, SGND_CONSOLE_MSGTYPES
        #
        # Returns:
        #   0 if the message should be printed
        #   1 otherwise
        #
        # Usage:
        #   if _say_should_print_console "INFO"; then
        #       printf "...\n"
        #   fi
        #
        # Examples:
        #   _say_should_print_console "DEBUG" || return
    _say_should_print_console() {
        local type="${1^^}"
        local list="${SGND_CONSOLE_MSGTYPES:-INFO|STRT|WARN|FAIL|CNCL|OK|END|EMPTY}"
        list="${list^^}"

        if [[ "${SGND_LOG_TO_CONSOLE:-1}" -eq 0 ]]; then
            case "$type" in
                WARN|FAIL) return 0 ;;
                *)         return 1 ;;
            esac
        fi
        
        [[ "${FLAG_VERBOSE:-0}" -eq 1 ]] && return 0

        if [[ "$type" == "DEBUG" ]]; then
            [[ "${FLAG_DEBUG:-0}" -eq 1 ]] && return 0
            return 1
        fi

        [[ "|$list|" == *"|$type|"* ]]
    }


    # fn: say_caller
        # Purpose:
        #   Resolve the originating caller location for logging purposes.
        #
        # Behavior:
        #   - Traverses the call stack.
        #   - Skips internal say* wrappers.
        #   - Returns the first non-wrapper frame.
        #
        # Outputs:
        #   Prints:
        #     <function>\t<file>\t<line>
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   IFS=$'\t' read -r func file line <<< "$(_say_caller)"
        #
        # Examples:
        #   caller="$(_say_caller)"
    _say_caller() {
        local i
        for ((i=1; i<${#FUNCNAME[@]}; i++)); do
            case "${FUNCNAME[$i]}" in
                say|sayinfo|saystart|saywarning|sayfail|saycancel|sayok|sayend|saydebug|justsay)
                    continue
                    ;;
                *)
                    printf '%s\t%s\t%s' \
                        "${FUNCNAME[$i]}" \
                        "${BASH_SOURCE[$i]}" \
                        "${BASH_LINENO[$((i-1))]}"
                    return
                    ;;
            esac
        done
        printf '<main>\t<unknown>\t?'
    }

    # fn: say_write_log
        # Purpose:
        #   Append a formatted log record to the logfile with optional rotation.
        #
        # Behavior:
        #   - No-op when logging is disabled or no valid logfile is available.
        #   - Sanitizes message (removes ANSI, normalizes whitespace).
        #   - Adds timestamp, user, type, and caller metadata.
        #   - Rotates logfile when size exceeds SGND_LOG_MAX_BYTES.
        #   - Never fails the caller (best-effort).
        #
        # Arguments:
        #   $1  TYPE
        #   $2  MSG
        #   $3  DATE_STR (optional)
        #
        # Inputs (globals):
        #   SGND_LOGFILE_ENABLED, SGND_LOG_MAX_BYTES, SGND_LOG_KEEP, SGND_LOG_COMPRESS
        #   SAY_DATE_FORMAT
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _say_write_log "INFO" "Starting process" ""
        #
        # Examples:
        #   _say_write_log "FAIL" "Connection error" "$(date)"
    _say_write_log() {
        local type="${1^^}"
        local msg="$2"
        local date_str="$3"

        : "${SGND_LOGFILE_ENABLED:=0}"
        : "${SGND_LOG_MAX_BYTES:=$((25 * 1024 * 1024))}"
        : "${SGND_LOG_KEEP:=5}"
        : "${SGND_LOG_COMPRESS:=0}"

        # Looks backwards at first glance: logging OFF → exit successfully (=no-op)
        (( SGND_LOGFILE_ENABLED )) || return 0

        local logfile
        logfile="$(_sgnd_logfile)" || return 0
        [[ -n "$logfile" ]] || return 0

        local log_ts log_user caller_func caller_file caller_line clean_msg log_line

        if [[ -n "$date_str" ]]; then
            log_ts="$date_str"
        else
            log_ts="$(date "+${SAY_DATE_FORMAT}")"
        fi

        log_user="$(id -un 2>/dev/null || printf '%s' "${USER:-unknown}")"
        IFS=$'\t' read -r caller_func caller_file caller_line <<< "$(_say_caller)"

        clean_msg="$msg"
        clean_msg="$(printf '%s' "$clean_msg" | sed -r 's/\x1B\[[0-9;]*[[:alpha:]]//g')"
        clean_msg="${clean_msg//$'\r'/}"
        clean_msg="${clean_msg//$'\n'/\\n}"
        clean_msg="${clean_msg//$'\t'/\\t}"

        log_line="${log_ts} user=${log_user} type=${type} caller=${caller_func}:${caller_file}:${caller_line} msg=${clean_msg}"

        local size add_bytes
        size=$(stat -c %s "$logfile" 2>/dev/null || echo 0)
        add_bytes=$(( ${#log_line} + 1 ))   # +1 for '\n'

        if (( size + add_bytes >= SGND_LOG_MAX_BYTES )); then
            _sgnd_rotate_logs "$logfile"
        fi

        printf '%s\n' "$log_line" >>"$logfile" 2>/dev/null || true
    }

    # fn: _sgnd_rotate_logs
        # Purpose:
        #   Perform size-based rotation of a logfile.
        #
        # Behavior:
        #   - Renames logfile to logfile.1, shifts older files upward.
        #   - Keeps up to SGND_LOG_KEEP rotated files.
        #   - Optionally compresses rotated files.
        #   - Recreates the active logfile.
        #
        # Arguments:
        #   $1  LOGFILE
        #
        # Inputs (globals):
        #   SGND_LOG_MAX_BYTES, SGND_LOG_KEEP, SGND_LOG_COMPRESS
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_rotate_logs "/var/log/app.log"
        #
        # Examples:
        #   _sgnd_rotate_logs "$logfile"
    _sgnd_rotate_logs() {
            # Usage: _sgnd_rotate_logs "/path/to/logfile"
            local logfile="$1"
            [[ -n "$logfile" ]] || return 0
            [[ -f "$logfile" ]] || return 0

            # If not exceeding, do nothing (caller can pre-check; keep safe here too)
            local size
            size="$(wc -c < "$logfile" 2>/dev/null)" || return 0
            (( size >= SGND_LOG_MAX_BYTES )) || return 0

            local i src dst
            # Shift: logfile.N(.gz) -> logfile.(N+1)(.gz)
            for (( i=SGND_LOG_KEEP; i>=1; i-- )); do
                src="${logfile}.${i}"
                dst="${logfile}.$((i+1))"
                [[ -f "$src" ]] && mv -f -- "$src" "$dst" 2>/dev/null || true
                [[ -f "${src}.gz" ]] && mv -f -- "${src}.gz" "${dst}.gz" 2>/dev/null || true
            done

            # Move current to .1
            mv -f -- "$logfile" "${logfile}.1" 2>/dev/null || true

            # Recreate (keep perms reasonable; adjust if you manage perms elsewhere)
            : > "$logfile" 2>/dev/null || true

            # Compress rotated file
            if (( SGND_LOG_COMPRESS )) && [[ -f "${logfile}.1" ]]; then
                gzip -f "${logfile}.1" 2>/dev/null || true
            fi

            # Trim oldest beyond keep
            rm -f -- "${logfile}.$((SGND_LOG_KEEP+1))" "${logfile}.$((SGND_LOG_KEEP+1)).gz" 2>/dev/null || true
    }

    # fn: _sgnd_logfile
        # Purpose:
        #   Resolve the effective logfile path based on configured priorities.
        #
        # Behavior:
        #   - Checks SGND_LOG_PATH first, then SGND_ALT_LOGPATH.
        #   - Uses sgnd_can_append to validate write capability.
        #   - Returns the first usable path.
        #
        # Outputs:
        #   Prints the resolved logfile path (no newline).
        #
        # Returns:
        #   0 if a usable path is found
        #   1 otherwise
        #
        # Usage:
        #   logfile="$(_sgnd_logfile)" || return
        #
        # Examples:
        #   if logfile="$(_sgnd_logfile)"; then
        #       echo "Logging to $logfile"
        #   fi
    _sgnd_logfile() {
        
        # Determine logfile path according to priority:
        # 1. SGND_LOG_PATH if set and usable
        if [[ -n "${SGND_LOG_PATH:-}" ]] && sgnd_can_append "$SGND_LOG_PATH"; then
            printf '%s' "$SGND_LOG_PATH"
            return 0
        fi

        # 2. SGND_ALT_LOGPATH if set and usable
        if [[ -n "${SGND_ALT_LOGPATH:-}" ]] && sgnd_can_append "$SGND_ALT_LOGPATH"; then
            printf '%s' "$SGND_ALT_LOGPATH"
            return 0
        fi

        return 1
    }
# --- Public API ---------------------------------------------------------------------
    # fn: say
        # Purpose:
        #   Emit a typed message with formatting, colorization, and optional logging.
        #
        # Behavior:
        #   - Supports message types: INFO, STRT, WARN, FAIL, CNCL, OK, END, DEBUG, EMPTY
        #   - Builds prefix using label/icon/symbol based on configuration
        #   - Applies colorization rules
        #   - Honors console output policy
        #   - Logs message if enabled
        #
        # Usage:
        #   say INFO "Starting process"
        #   say --type WARN "Low disk space"
        #   say --date --show all --colorize both INFO "Message"
        #
        # Examples:
        #   say STRT "Initializing..."
        #
        #   say --date --type FAIL "Connection failed"
        #
        #   say DEBUG "Value = $value"
        #
        # Returns:
        #   0 always.
    say() {
      # -- Declarations
        local type="EMPTY"
        local add_date="${SAY_DATE_DEFAULT:-0}"
        local show="${SAY_SHOW_DEFAULT:-label}"
        local colorize="${SAY_COLORIZE_DEFAULT:-label}"

        local explicit_type=0
        local msg=""
        local s_label=0 s_icon=0 s_symbol=0
        local prefixlength=0

      # -- Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --type)
                    type="${2^^}"
                    explicit_type=1
                    shift 2
                    ;;
                --date)
                    add_date=1
                    prefixlength=$((prefixlength + 19))
                    shift
                    ;;
                --show)
                    show="$2"
                    shift 2
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
                    # Positional TYPE: say STRT "message"
                    if (( ! explicit_type )); then
                        local maybe="${1^^}"
                        case "$maybe" in
                            INFO|STRT|WARN|FAIL|CNCL|OK|END|DEBUG|EMPTY)
                                type="$maybe"
                                explicit_type=1
                                shift
                                continue
                                ;;
                        esac
                    fi
                    break
                    ;;
            esac
        done

        msg="${*:-}"

        # Normalize TYPE
        type="${type^^}"
        case "$type" in
            INFO|STRT|WARN|FAIL|CNCL|OK|END|DEBUG|EMPTY) ;;
            *) type="EMPTY" ;;
        esac

        # EMPTY = print message only (no prefix), still eligible for logging
        if [[ "$type" == "EMPTY" ]]; then
            if _say_should_print_console "EMPTY"; then
                printf '%s\n' "$msg"
            fi
            _say_write_log "EMPTY" "$msg" ""
            return 0
        fi

      # -- Resolve style tokens for this TYPE via maps (LBL_*, ICO_*, SYM_*, MSG_CLR_*)
        local lbl icn smb clr
        local w

        w="LBL_${type}";     lbl="${!w:-$type}"
        w="ICO_${type}";     icn="${!w:-}"
        w="SYM_${type}";     smb="${!w:-}"
        w="MSG_CLR_${type}"; clr="${!w:-}"

      # -- Decode --show (supports "label,icon", "label+symbol", "all")
        local sel p
        IFS=',+' read -r -a sel <<<"$show"
        if [[ "${#sel[@]}" -eq 0 ]]; then
            sel=(label)
        fi

        for p in "${sel[@]}"; do
            case "${p,,}" in
                label)  s_label=1;  prefixlength=$((prefixlength + 8)) ;;
                icon)   s_icon=1;   prefixlength=$((prefixlength + 1)) ;;
                symbol) s_symbol=1; prefixlength=$((prefixlength + 3)) ;;
                all)
                    s_label=1; s_icon=1; s_symbol=1
                    prefixlength=$((prefixlength + 16))
                    ;;
            esac
        done

        if (( s_label + s_icon + s_symbol == 0 )); then
            s_label=1
            prefixlength=$((prefixlength + 8))
        fi

      # -- Decode colorize: none|label|msg|date|both|all
        local c_label=0 c_msg=0 c_date=0
        case "${colorize,,}" in
            none) ;;
            label) c_label=1 ;;
            msg)   c_msg=1 ;;
            date)  c_date=1 ;;
            both|all) c_label=1; c_msg=1; c_date=1 ;;
            *) c_label=1 ;;
        esac

      # -- Build final output line and print
        local fnl=""
        local date_str=""
        local rst="${RESET:-}"
        local prefix_parts=()

        if (( add_date )); then
            date_str="$(date "+${SAY_DATE_FORMAT}")"
            if (( c_date )); then
                prefix_parts+=("${clr}${date_str}${rst}")
            else
                prefix_parts+=("$date_str")
            fi
        fi

        local l_len pad_lbl
        l_len=$(sgnd_visible_len "$lbl")
        pad_lbl=""
        if (( l_len < 8 )); then
            printf -v pad_lbl '%*s' $((8 - l_len)) ''
        fi
        lbl="${lbl}${pad_lbl}"

        if (( s_label )); then
            if (( c_label )); then
                prefix_parts+=("${clr}${lbl}${rst}")
            else
                prefix_parts+=("$lbl")
            fi
        fi

        if (( s_icon )); then
            if (( c_label )); then
                prefix_parts+=("${clr}${icn}${rst}")
            else
                prefix_parts+=("$icn")
            fi
        fi

        if (( s_symbol )); then
            if (( c_label )); then
                prefix_parts+=("${clr}${smb}${rst}")
            else
                prefix_parts+=("$smb")
            fi
        fi

        if ((${#prefix_parts[@]} > 0)); then
            fnl+="${prefix_parts[*]} "
            prefixlength=$((prefixlength + 1))
        fi

        local v_len
        v_len=$(sgnd_visible_len "$fnl")

        local pad_col=""
        if (( v_len < prefixlength )); then
            printf -v pad_col '%*s' $((prefixlength - v_len)) ''
        else
            pad_col=" "
        fi
        fnl+="$pad_col"

        if (( c_msg )); then
            fnl+="${clr}${msg}${rst}"
        else
            fnl+="$msg"
        fi

        if _say_should_print_console "$type"; then
            if (( SGND_LINEBREAK_PENDING )); then
                printf '\n' >&2
                SGND_LINEBREAK_PENDING=0
            fi
            printf '%s\n' "$fnl $RESET"
        fi

        _say_write_log "$type" "$msg" "$date_str"
    }

    # fn: sayprogress
        # Purpose:
        #   Render single-line progress output on stderr and update it in place.
        #
        # Behavior:
        #   - Reuses the same console line using carriage return.
        #   - Builds the rendered output from selected progress parts.
        #   - Supports absolute counters, percentage, and progress bar output.
        #   - Applies optional colors independently to bar, indicators, and label.
        #   - Supports optional left padding.
        #   - Pads the rendered line so older longer text is cleared.
        #   - Does not print a trailing newline.
        #
        # Options:
        #   --current N
        #       Current position.
        #   --total N
        #       Total number of items.
        #   --label TEXT
        #       Optional label text to append.
        #   --type N
        #       Bitmask selecting which progress parts to show:
        #         1 = absolute counter
        #         2 = percentage
        #         4 = progress bar
        #   --barcolor SGR
        #       ANSI SGR sequence for the progress bar.
        #   --labelcolor SGR
        #       ANSI SGR sequence for the label.
        #   --indicatorcolor SGR
        #       ANSI SGR sequence for percentage and absolute indicators.
        #   --padleft N
        #       Number of spaces to prefix before rendered output.
        #   --width N
        #       Width of the progress bar in characters.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid option.
    sayprogress() {
        local current=0
        local total=1
        local label=""
        local progress_type=7
        local bar_color="${PROG_BAR_CLR:-CYAN}"
        local label_color="${PROG_TEXT_CLR:-WHITE}"
        local indicator_color="${PROG_IND_CLR:-CYAN}"
        local padleft=0
        local width=30

        local percent=0
        local filled=0
        local empty=0
        local bar_filled=""
        local bar_empty=""
        local text=""
        local part=""
        local prefix=""
        local reset="${RESET-}"

        while (($#)); do
            case "$1" in
                --current)        current="${2:-0}"; shift 2 ;;
                --total)          total="${2:?missing value for --total}"; shift 2 ;;
                --label)          label="${2:?missing value for --label}"; shift 2 ;;
                --type)           progress_type="${2:-0}"; shift 2 ;;
                --barcolor)       bar_color="${2-}"; shift 2 ;;
                --labelcolor)     label_color="${2-}"; shift 2 ;;
                --indicatorcolor) indicator_color="${2-}"; shift 2 ;;
                --padleft)        padleft="${2:?missing value for --padleft}"; shift 2 ;;
                --width)          width="${2:?missing value for --width}"; shift 2 ;;
                --) shift; break ;;
                *) return 1 ;;
            esac
        done

        (( total > 0 )) || total=1
        (( current < 0 )) && current=0
        (( current > total )) && current=$total
        (( progress_type > 0 )) || progress_type=1
        (( width > 0 )) || width=30
        (( padleft >= 0 )) || padleft=0

        percent=$(( current * 100 / total ))
        filled=$(( current * width / total ))
        empty=$(( width - filled ))

        if (( padleft > 0 )); then
            printf -v prefix '%*s' "$padleft" ''
        fi

        # Progress bar
        if (( progress_type & 4 )); then
            [[ -n "$text" ]] && text+="  "

            printf -v bar_filled '%*s' "$filled" ''
            bar_filled="${bar_filled// /#}"

            printf -v bar_empty '%*s' "$empty" ''
            bar_empty="${bar_empty// /.}"

            part="[${bar_filled}${bar_empty}]"

            if [[ -n "$bar_color" ]]; then
                part="${bar_color}${part}${reset}"
            fi

            text+="$part"
        fi

        # Percentage indicator
        if (( progress_type & 2 )); then
            [[ -n "$text" ]] && text+="  "

            printf -v part '%3d%%' "$percent"

            if [[ -n "$indicator_color" ]]; then
                part="${indicator_color}${part}${reset}"
            fi

            text+="$part"
        fi

        # Absolute progress indicator
        if (( progress_type & 1 )); then
            [[ -n "$text" ]] && text+="  "

            part="${current}/${total}"

            if [[ -n "$indicator_color" ]]; then
                part="${indicator_color}${part}${reset}"
            fi

            text+="$part"
        fi

        # Label
        if [[ -n "$label" ]]; then
            [[ -n "$text" ]] && text+="  "

            part="$label"

            if [[ -n "$label_color" ]]; then
                part="${label_color}${part}${reset}"
            fi

            text+="$part"
        fi

        text="${prefix}${text}"

        SGND_LINEBREAK_PENDING=1
        printf '\r%-140s' "$text" >&2
    }

    # fn: sayprogress_done
        # Purpose:
        #   Finalize progress output by printing a newline.
        #
        # Behavior:
        #   - Prints a newline to stderr to move past the progress line.
        #
        # Usage:
        #   sayprogress_done
        #
        # Examples:
        #   sayprogress_done
        #
        # Returns:
        #   0 always.
    sayprogress_done() {
        SGND_LINEBREAK_PENDING=0    
        printf '\n' >&2
    }

    # -- Convenience wrappers for say() with a fixed TYPE.
        # fn: sayinfo
            # Purpose:
            #   Emit an INFO message.
            #
            # Behavior:
            #   - Delegates to say INFO.
            #   - Only emits when FLAG_VERBOSE=1.
            #   - Always returns 0, even when suppressed.
            #
            # Inputs (globals):
            #   FLAG_VERBOSE
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   sayinfo "Loading optional libraries..."
            #
            # Examples:
            #   sayinfo "Using default configuration"
        sayinfo() {
                say INFO "$@"
        }

        # fn: saystart
            # Purpose:
            #   Emit a STRT message.
            #
            # Behavior:
            #   - Delegates to say STRT.
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   saystart "Initializing framework"
            #
            # Examples:
            #   saystart "Starting installation"
        saystart() {
            say STRT "$@"
        }

        # fn: saywarning
            # Purpose:
            #   Emit a WARN message.
            #
            # Behavior:
            #   - Delegates to say WARN.
            #
            # Usage:
            #   saywarning "Disk space low"
            #
            # Examples:
            #   saywarning "Configuration missing"
        saywarning() {
            say WARN "$@"
        }

        # fn: sayfail
            # Purpose:
            #   Emit a FAIL message.
            #
            # Behavior:
            #   - Delegates to say FAIL.
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   sayfail "Cannot create directory: $dir"
            #
            # Examples:
            #   sayfail "Bootstrap failed"
        sayfail() {
            say FAIL "$@"
        }

        # fn: saycancel
            # Purpose:
            #   Emit a CNCL message.
            #
            # Behavior:
            #   - Delegates to say CNCL.
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   saycancel "Cancelled by user"
            #
            # Examples:
            #   saycancel "Operation aborted"
        saycancel() {
            say CNCL "$@"
        }

        # fn: sayok
            # Purpose:
            #   Emit an OK message.
            #
            # Behavior:
            #   - Delegates to say OK.
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   sayok "Configuration written successfully"
            #
            # Examples:
            #   sayok "Validation passed"
        sayok() {
            say OK "$@"
        }

        # fn: sayend
            # Purpose:
            #   Emit an END message.
            #
            # Behavior:
            #   - Delegates to say END.
            #
            # Returns:
            #   0 always.
            #
            # Usage:
            #   sayend "Process completed"
            #
            # Examples:
            #   sayend "Finished successfully"
        sayend() {
            say END "$@"
        }

        # justsay
            # Purpose:
            #   Emit plain text without formatting or logging.
            #
            # Behavior:
            #   - Prints directly to stdout.
            #
            # Usage:
            #   justsay "Hello world"
            #
            # Examples:
            #   justsay "Raw output"
        justsay() {
            printf '%s\n' "$@"
        }

        # fn: saydebug
            # Purpose:
            #   Emit a DEBUG message with optional caller context.
            #
            # Behavior:
            #   - Only active when FLAG_DEBUG=1.
            #   - Adds caller info when FLAG_VERBOSE=1.
            #   - Delegates to say DEBUG.
            #
            # Usage:
            #   saydebug "Value = $x"
            #
            # Examples:
            #   saydebug "Entering function"
        saydebug() {
            if [[ ${FLAG_DEBUG:-0} -eq 1 ]]; then

                if [[ ${FLAG_VERBOSE:-0} -eq 1 ]]; then
                    # Stack level 1 = caller of saydebug
                    local src="${BASH_SOURCE[1]##*/}"
                    local func="${FUNCNAME[1]}"
                    local line="${BASH_LINENO[0]}"

                    say DEBUG "$@" "[$src:$func:$line]"
                else
                    say DEBUG "$@"
                fi
            fi
            return 0
        }

