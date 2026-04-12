# =====================================================================================
# SolidgroundUX - Core Utilities
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.2
#   Build       : 2609100
#   Checksum    : 6034f64b9ad377a4336278a4ad14be211c19c367f36ba7d4b935226c1ad2fbd6
#   Source      : sgnd-core.sh
#   Type        : library
#   Group       : Common
#   Purpose     : Provide foundational utility functions and shared primitives
#
# Description:
#   Contains the lowest-level generic helpers used throughout the SolidgroundUX
#   framework.
#
#   The library:
#     - Defines generic reusable helper functions
#     - Provides string, array, and low-level utility primitives
#     - Implements shared conventions and diagnostics helpers
#     - Avoids system-, UI-, and business-specific behavior where possible
#
# Design principles:
#   - Keep utilities generic and broadly reusable
#   - Avoid domain-specific logic in core helpers
#   - Prefer clarity and predictability over cleverness
#   - Minimize dependencies to keep the core lightweight
#
# Role in framework:
#   - Foundational layer used by nearly all other libraries
#   - Supports argument parsing, configuration, UI, and script logic
#   - Acts as the lowest-level shared functionality layer
#
# Non-goals:
#   - Business logic or application-specific behavior
#   - UI rendering or user interaction handling
#   - System administration and host/runtime operations (handled in sgnd-system)
#   - Configuration or state management (handled in dedicated modules)
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
        # Inputs (globals):
        #   BASH_SOURCE
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

# --- Requirement checks -------------------------------------------------------------
    # sgnd_have
        # Returns:
        #   0 if the command exists on PATH; non-zero otherwise.
        #
        # Usage:
        #   sgnd_have COMMAND
    sgnd_have() { command -v "$1" >/dev/null 2>&1; }

    # sgnd_need_cmd
        # Returns:
        #   0 when the command exists; exits 1 otherwise.
        #
        # Usage:
        #   sgnd_need_cmd COMMAND
    sgnd_need_cmd() { sgnd_have "$1" || { printf 'Missing required command: %s\n' "$1" >&2; exit 1; }; }

    # sgnd_need_bash
        # Returns:
        #   0 when the current Bash major version is sufficient; exits 1 otherwise.
        #
        # Usage:
        #   sgnd_need_bash [MIN_MAJOR]
    sgnd_need_bash() { (( BASH_VERSINFO[0] >= ${1:-4} )) || { printf 'Bash %s+ required.\n' "${1:-4}" >&2; exit 1; }; }

    # sgnd_need_tty
        # Returns:
        #   0 if stdout is a TTY; 1 otherwise.
        #
        # Usage:
        #   sgnd_need_tty
    sgnd_need_tty() { [[ -t 1 ]] || { printf 'No TTY attached.\n' >&2; return 1; }; }

# --- Filesystem helpers -------------------------------------------------------------
    # sgnd_can_append
        # Purpose:
        #   Test whether a file can be appended to, or created for later appending.
        #
        # Behavior:
        #   - If the target file exists, requires it to be a writable regular file.
        #   - If the target file does not exist, checks whether the parent directory is writable.
        #   - If the parent directory does not exist, attempts to create it with mkdir -p.
        #   - Does not create the target file itself.
        #
        # Arguments:
        #   $1  FILE
        #       File path to test.
        #
        # Side effects:
        #   - May create the parent directory path using mkdir -p.
        #
        # Returns:
        #   0 if the file is appendable or creatable for append.
        #   1 otherwise.
        #
        # Usage:
        #   sgnd_can_append FILE
    sgnd_can_append() {
        local f="$1"
        local d

        [[ -n "$f" ]] || return 1
        d="$(dirname -- "$f")"

        if [[ -e "$f" ]]; then
            [[ -f "$f" && -w "$f" ]] || return 1
            return 0
        fi

        if [[ -d "$d" ]]; then
            [[ -w "$d" ]] || return 1
            return 0
        fi

        mkdir -p -- "$d" 2>/dev/null || return 1
        [[ -w "$d" ]] || return 1
        return 0
    }

    # sgnd_ensure_dir
        # Purpose:
        #   Ensure a directory exists.
        #
        # Arguments:
        #   $1  Directory path.
        #
        # Returns:
        #   0 on success.
        #   2 if the argument is missing.
        #   Otherwise mkdir's exit status.
        #
        # Usage:
        #   sgnd_ensure_dir DIR
    sgnd_ensure_dir() {
        local dir="${1:-}"
        [[ -n "$dir" ]] || return 2
        [[ -d "$dir" ]] || mkdir -p -- "$dir"
    }

    # sgnd_abs_path
        # Returns:
        #   0 on success; 127 if no supported resolver is available.
        #
        # Usage:
        #   sgnd_abs_path PATH
    sgnd_abs_path() {
        if sgnd_have readlink; then
            readlink -f -- "$1" 2>/dev/null && return 0
        fi

        if sgnd_have realpath; then
            realpath -- "$1"
            return $?
        fi

        return 127
    }

    # sgnd_mktemp_dir
        # Returns:
        #   0 on success; non-zero on failure.
        #
        # Usage:
        #   sgnd_mktemp_dir
    sgnd_mktemp_dir() { mktemp -d 2>/dev/null || TMPDIR=${TMPDIR:-/tmp} mktemp -d "${TMPDIR%/}/XXXXXX"; }

    # sgnd_mktemp_file
        # Returns:
        #   0 on success; non-zero on failure.
        #
        # Usage:
        #   sgnd_mktemp_file
    sgnd_mktemp_file() { TMPDIR=${TMPDIR:-/tmp} mktemp "${TMPDIR%/}/XXXXXX"; }

    # sgnd_slugify
        # Purpose:
        #   Convert text into a lowercase filename-safe slug.
        #
        # Behavior:
        #   - Lowercases the input text.
        #   - Replaces whitespace runs with a single dash.
        #   - Removes characters outside [a-z0-9-_.].
        #   - Collapses repeated dashes and trims leading/trailing dashes.
        #   - Falls back to "hub" when the resulting slug would otherwise be empty.
        #
        # Arguments:
        #   $1  TEXT
        #
        # Output:
        #   Prints the slug to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_slugify TEXT
    sgnd_slugify() {
        local s="${1:-}"

        s="${s,,}"
        s="$(printf '%s' "$s" | tr -s '[:space:]' '-')"
        s="$(printf '%s' "$s" | tr -cd 'a-z0-9-_.')"

        while [[ "$s" == *--* ]]; do
            s="${s//--/-}"
        done

        s="${s#-}"
        s="${s%-}"

        [[ -n "$s" ]] || s="hub"
        printf '%s' "$s"
    }

    # sgnd_hash_sha256_file
        # Purpose:
        #   Compute and print the SHA-256 hash of a readable file.
        #
        # Arguments:
        #   $1  FILE
        #
        # Output:
        #   Prints the SHA-256 hash to stdout.
        #
        # Returns:
        #   0 on success.
        #   2 if FILE is not readable.
        #   3 if the hashing tool fails.
        #   127 if no supported hashing tool is available.
        #
        # Usage:
        #   sgnd_hash_sha256_file FILE
    sgnd_hash_sha256_file() {
        local file="$1"
        local out

        [[ -r "$file" ]] || return 2

        if sgnd_have sha256sum; then
            out="$(sha256sum "$file")" || return 3
            printf '%s\n' "${out%% *}"
            return 0
        fi

        if sgnd_have shasum; then
            out="$(shasum -a 256 "$file")" || return 3
            printf '%s\n' "${out%% *}"
            return 0
        fi

        return 127
    }

    # sgnd_safe_replace_file
        # Purpose:
        #   Replace a destination file with a source file while preserving mode bits.
        #
        # Arguments:
        #   $1  SRC
        #   $2  DST
        #
        # Returns:
        #   0 on success; 1 on failure.
        #
        # Usage:
        #   sgnd_safe_replace_file SRC DST
    sgnd_safe_replace_file() {
        local src="${1:?missing source}"
        local dst="${2:?missing destination}"

        [[ -e "$src" ]] || return 1
        [[ -e "$dst" ]] || return 1

        chmod --reference="$dst" "$src" || return 1
        mv "$src" "$dst" || return 1
    }

# --- Argument & environment helpers -------------------------------------------------
    # sgnd_is_set
        # Returns:
        #   0 if the variable name is defined; non-zero otherwise.
        #
        # Usage:
        #   sgnd_is_set VAR_NAME
    sgnd_is_set() { [[ -v "$1" ]]; }

    # sgnd_default
        # Purpose:
        #   Assign a default value to a variable when it is unset or empty.
        #
        # Arguments:
        #   $1  VAR_NAME
        #   $2  DEFAULT
        #
        # Side effects:
        #   - Sets the target variable in the current shell.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_default VAR_NAME DEFAULT
    sgnd_default() {
        local name="$1"
        local default="${2-}"
        local -n ref="$name"

        [[ -n "${ref:-}" ]] || ref="$default"
    }

    # sgnd_is_number
        # Returns:
        #   0 if the value contains only digits; non-zero otherwise.
        #
        # Usage:
        #   sgnd_is_number VALUE
    sgnd_is_number() { [[ "$1" =~ ^[0-9]+$ ]]; }

    # sgnd_array_has_items
        # Returns:
        #   0 if the named array exists and contains at least one element; non-zero otherwise.
        #
        # Usage:
        #   sgnd_array_has_items ARRAY_NAME
    sgnd_array_has_items() {
        declare -p "$1" &>/dev/null || return 1
        local -n _arr="$1"
        (( ${#_arr[@]} > 0 ))
    }

    # sgnd_is_true
        # Returns:
        #   0 if the token is one of: y, yes, 1, true; non-zero otherwise.
        #
        # Usage:
        #   sgnd_is_true VALUE
    sgnd_is_true() {
        case "${1,,}" in
            y|yes|1|true) return 0 ;;
            *)            return 1 ;;
        esac
    }

# --- Process & state helpers --------------------------------------------------------
    # sgnd_proc_exists
        # Returns:
        #   0 if a process with the exact name is running; non-zero otherwise.
        #
        # Usage:
        #   sgnd_proc_exists PROCESS_NAME
    sgnd_proc_exists() { pgrep -x "$1" &>/dev/null; }

    # sgnd_wait_for_exit
        # Returns:
        #   0 when the named process is no longer running.
        #
        # Usage:
        #   sgnd_wait_for_exit PROCESS_NAME [INTERVAL]
    sgnd_wait_for_exit() {
        local name="$1"
        local interval="${2:-0.5}"

        while sgnd_proc_exists "$name"; do
            sleep "$interval"
        done
    }

    # sgnd_kill_if_running
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_kill_if_running PROCESS_NAME
    sgnd_kill_if_running() { pkill -x "$1" &>/dev/null || true; }

    # sgnd_caller_id
        # Purpose:
        #   Build a compact caller identifier string for diagnostics.
        #
        # Arguments:
        #   $1  DEPTH
        #       Optional stack depth. Default: 1
        #
        # Output:
        #   Prints the caller identifier to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_caller_id [DEPTH]
    sgnd_caller_id() {
        local depth="${1:-1}"
        local file="${BASH_SOURCE[$depth]}"
        local func="${FUNCNAME[$depth]}"
        local line="${BASH_LINENO[$((depth-1))]}"

        printf '%s:%s (%s)' "${file##*/}" "$line" "$func"
    }

    # sgnd_stack_trace
        # Purpose:
        #   Print a simple stack trace with the most recent caller first.
        #
        # Output:
        #   Prints stack trace lines to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_stack_trace
    sgnd_stack_trace() {
        local i
        for (( i=1; i<${#FUNCNAME[@]}; i++ )); do
            printf '  at %s:%s (%s)\n' \
                "${BASH_SOURCE[$i]##*/}" \
                "${BASH_LINENO[$((i-1))]}" \
                "${FUNCNAME[$i]}"
        done
    }

    # sgnd_has_tty
        # Returns:
        #   0 if /dev/tty is readable and writable; 1 otherwise.
        #
        # Usage:
        #   sgnd_has_tty
    sgnd_has_tty() { [[ -r /dev/tty && -w /dev/tty ]]; }

    # fn: sgnd_is_ui_mode
        # Purpose:
        #   Determine whether the current execution context supports interactive UI.
        #
        # Behavior:
        #   - Honors explicit runmode flags when present
        #   - Falls back to TTY detection
        #
        # Returns:
        #   0 if UI mode is active
        #   1 otherwise
    sgnd_is_ui_mode() {
        # Explicit overrides first (future-proof)
        (( ${FLAG_NOUI:-0} ))   && return 1
        (( ${FLAG_BATCH:-0} ))  && return 1
        (( ${FLAG_UI:-0} ))     && return 0

        # Fallback: interactive terminal
        [[ -t 0 && -t 1 ]]
    }
    
    # fn: sgnd_is_desktop_mode
        # Purpose:
        #   Detect whether a graphical desktop environment is available.
        #
        # Behavior:
        #   - Detects X11 or Wayland session
        #   - Does not guarantee UI interactivity (separate concern)
        #
        # Returns:
        #   0 if desktop environment is available
        #   1 otherwise
    sgnd_is_desktop_mode() {
        [[ -n "${DISPLAY:-}" ]] && return 0
        [[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0
        return 1
    }

    # fn: sgnd_internal_call_guard
        # Purpose:
        #   Warn when an internal helper is called from outside the expected API flow.
        #
        # Behavior:
        #   - Inspects the Bash call stack.
        #   - Treats callers named sgnd_* as public framework entry points.
        #   - Treats callers named _* as internal helper flow.
        #   - Emits a warning when the guarded internal function appears to be called
        #     directly from outside that convention.
        #
        # Arguments:
        #   $1  FUNCTION_NAME
        #       Name of the internal function being guarded.
    sgnd_internal_call_guard() {
        local func="${1:?missing function name}"

        case "${FUNCNAME[1]}" in
            sgnd_*) return 0 ;;   # called from public function → OK
            _*)     return 0 ;;   # called from another internal → OK
            *)
                printf "WARN: Internal function '%s' called from outside API\n" "$func" >&2
                ;;
        esac
    }
# --- Version helpers ----------------------------------------------------------------
    # sgnd_version_ge
        # Returns:
        #   0 if version A is greater than or equal to version B; 1 otherwise.
        #
        # Usage:
        #   sgnd_version_ge VERSION_A VERSION_B
    sgnd_version_ge() { [[ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

    # --- Misc utilities -----------------------------------------------------------------
    # sgnd_timestamp
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_timestamp
    sgnd_timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

    # sgnd_retry
        # Purpose:
        #   Retry a command up to N times with a delay between attempts.
        #
        # Arguments:
        #   $1  ATTEMPTS
        #   $2  DELAY_SECONDS
        #   $@  COMMAND
        #
        # Returns:
        #   0 if the command succeeds within the retry budget.
        #   1 if all attempts fail.
        #   2 on invalid arguments.
        #
        # Usage:
        #   sgnd_retry ATTEMPTS DELAY COMMAND [ARG ...]
    sgnd_retry() {
        local n="$1"
        local d="$2"
        local i

        shift 2
        (( n >= 1 )) || return 2
        (( $# >= 1 )) || return 2

        for (( i=1; i<=n; i++ )); do
            "$@" && return 0
            (( i < n )) && sleep "$d"
        done

        return 1
    }

    # sgnd_join
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_join SEPARATOR ITEM [ITEM ...]
    sgnd_join() {
        local IFS="$1"
        shift
        printf '%s' "$*"
    }

    # sgnd_array_union
        # Purpose:
        #   Build a stable union of one or more source arrays into a destination array.
        #
        # Arguments:
        #   $1  DEST_ARRAY name.
        #   $@  One or more SRC_ARRAY names.
        #
        # Returns:
        #   0 on success; 1 on invalid arguments.
        #
        # Usage:
        #   sgnd_array_union DEST_ARRAY SRC_ARRAY [SRC_ARRAY ...]
    sgnd_array_union() {
        local dest_name="$1"
        local src_name
        local item
        local -A _seen=()

        shift || true
        [[ -n "${dest_name:-}" && $# -ge 1 ]] || return 1

        local -n _dest="$dest_name"
        _dest=()

        for src_name in "$@"; do
            [[ -n "${src_name:-}" ]] || continue
            declare -p "$src_name" >/dev/null 2>&1 || continue

            local -n _src="$src_name"
            for item in "${_src[@]:-}"; do
                [[ -n "${item:-}" ]] || continue
                if [[ -z "${_seen[$item]+x}" ]]; then
                    _dest+=( "$item" )
                    _seen["$item"]=1
                fi
            done
        done

        return 0
    }

# --- Text functions -----------------------------------------------------------------
    # sgnd_trim
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_trim TEXT
    sgnd_trim() {
        local v="${*:-}"
        v="${v#"${v%%[![:space:]]*}"}"
        printf '%s' "${v%"${v##*[![:space:]]}"}"
    }

    # sgnd_string_repeat
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_string_repeat STRING COUNT
    sgnd_string_repeat() {
        local s="${1- }"
        local n="${2-0}"
        local out=""
        local i=0

        (( n > 0 )) || { printf '%s' ""; return 0; }

        for (( i=0; i<n; i++ )); do
            out+="$s"
        done

        printf '%s' "$out"
    }

    # sgnd_fill_left
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_fill_left TEXT [WIDTH] [FILL]
    sgnd_fill_left() {
        local source="${1-}"
        local maxlength="${2-20}"
        local char="${3- }"
        local padcount=$(( maxlength - ${#source} ))
        local pad

        (( padcount > 0 )) || { printf '%s' "$source"; return 0; }
        pad="$(sgnd_string_repeat "$char" "$padcount")"
        printf '%s%s' "$pad" "$source"
    }

    # sgnd_fill_right
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_fill_right TEXT [WIDTH] [FILL]
    sgnd_fill_right() {
        local source="${1-}"
        local maxlength="${2-20}"
        local char="${3- }"
        local padcount=$(( maxlength - ${#source} ))
        local pad

        (( padcount > 0 )) || { printf '%s' "$source"; return 0; }
        pad="$(sgnd_string_repeat "$char" "$padcount")"
        printf '%s%s' "$source" "$pad"
    }

    # sgnd_fill_center
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_fill_center TEXT [WIDTH] [FILL]
    sgnd_fill_center() {
        local source="${1-}"
        local maxlength="${2-20}"
        local char="${3- }"
        local padcount=$(( maxlength - ${#source} ))
        local left
        local right
        local pad_left
        local pad_right

        (( padcount > 0 )) || { printf '%s' "$source"; return 0; }

        left=$(( padcount / 2 ))
        right=$(( padcount - left ))
        pad_left="$(sgnd_string_repeat "$char" "$left")"
        pad_right="$(sgnd_string_repeat "$char" "$right")"

        printf '%s%s%s' "$pad_left" "$source" "$pad_right"
    }

    # sgnd_visible_length
        # Purpose:
        #   Measure the character length of text after stripping ANSI escape sequences.
        #
        # Arguments:
        #   $1  TEXT
        #
        # Output:
        #   Prints the stripped character count to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_visible_length TEXT
    sgnd_visible_length() {
        local text="${1-}"

        text="$(printf '%s' "$text" | sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g')"
        printf '%s' "$text" | wc -m
    }

    # sgnd_terminal_width
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_terminal_width
    sgnd_terminal_width() {
        local term_width=80
        local max_render_width="${SGND_MAX_RENDER_WIDTH:-140}"

        if sgnd_have tput; then
            term_width="$(tput cols 2>/dev/null || printf '80')"
        fi
        [[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80

        (( term_width > max_render_width )) && term_width="$max_render_width"
        (( term_width < 40 )) && term_width=40

        printf '%s\n' "$term_width"
    }

    # sgnd_padded_visible
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_padded_visible TEXT WIDTH
    sgnd_padded_visible() {
        local text="${1-}"
        local width="${2:-0}"
        local visible_len=0
        local pad_len=0

        visible_len="$(sgnd_visible_length "$text")"
        pad_len=$(( width - visible_len ))
        (( pad_len < 0 )) && pad_len=0

        printf '%s%*s' "$text" "$pad_len" ""
    }

    # sgnd_wrap_words
        # Purpose:
        #   Wrap a text string to a fixed width on word boundaries.
        #
        # Arguments:
        #   --width N
        #   --text STR
        #
        # Returns:
        #   0 on success, including empty text.
        #   2 on invalid arguments.
        #
        # Usage:
        #   sgnd_wrap_words --width N --text STR
    sgnd_wrap_words() {
        local width=80
        local text=""
        local line=""
        local word=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --width) width="$2"; shift 2 ;;
                --text)  text="$2"; shift 2 ;;
                --) shift; break ;;
                *) return 2 ;;
            esac
        done

        [[ -z "$text" ]] && return 0
        (( width < 1 )) && printf '%s\n' "$text" && return 0

        while read -r word; do
            if [[ -z "$line" ]]; then
                line="$word"
            elif (( ${#line} + 1 + ${#word} <= width )); then
                line+=" $word"
            else
                printf '%s\n' "$line"
                line="$word"
            fi
        done < <(printf '%s\n' "$text" | tr -s '[:space:]' '\n')

        [[ -n "$line" ]] && printf '%s\n' "$line"
    }

# --- Validators ---------------------------------------------------------------------
    # sgnd_validate_ipv4
        # Returns:
        #   0 if the value is a syntactically valid IPv4 address; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_ipv4 IP
    sgnd_validate_ipv4() {
        local ip="$1"
        local IFS='.'
        local octets
        local o

        read -r -a octets <<<"$ip"
        [[ ${#octets[@]} -eq 4 ]] || return 1

        for o in "${octets[@]}"; do
            [[ "$o" =~ ^[0-9]+$ ]] || return 1
            (( o >= 0 && o <= 255 )) || return 1
        done

        return 0
    }

    # sgnd_validate_yesno
        # Returns:
        #   0 if the value is a single-char Y/y/N/n token; non-zero otherwise.
        #
        # Usage:
        #   sgnd_validate_yesno VALUE
    sgnd_validate_yesno() { [[ "$1" =~ ^[YyNn]$ ]]; }

    # sgnd_validate_int
        # Returns:
        #   0 if the value is a signed integer; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_int VALUE
    sgnd_validate_int() { [[ "$1" =~ ^-?[0-9]+$ ]]; }

    # sgnd_validate_numeric
        # Returns:
        #   0 if the value is numeric; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_numeric VALUE
    sgnd_validate_numeric() { [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; }

    # sgnd_validate_text
        # Returns:
        #   0 if the value is non-empty; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_text VALUE
    sgnd_validate_text() { [[ -n "$1" ]]; }

    # sgnd_validate_bool
        # Returns:
        #   0 if the value is a recognized boolean token; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_bool VALUE
    sgnd_validate_bool() {
        case "${1,,}" in
            y|yes|n|no|true|false|1|0) return 0 ;;
            *) return 1 ;;
        esac
    }

    # sgnd_validate_date
        # Returns:
        #   0 if the value matches YYYY-MM-DD; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_date VALUE
    sgnd_validate_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }

    # sgnd_validate_cidr
        # Returns:
        #   0 if the value is a CIDR prefix length from 0 to 32; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_cidr VALUE
    sgnd_validate_cidr() { [[ "$1" =~ ^([0-9]|[12][0-9]|3[0-2])$ ]]; }

    # sgnd_validate_slug
        # Returns:
        #   0 if the value matches the lowercase slug character set; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_slug VALUE
    sgnd_validate_slug() { [[ "$1" =~ ^[a-z0-9._-]+$ ]]; }

    # sgnd_validate_fs_name
        # Returns:
        #   0 if the value contains only filesystem-safe name characters; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_fs_name VALUE
    sgnd_validate_fs_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }

    # sgnd_validate_file_exists
        # Returns:
        #   0 if the path is an existing regular file; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_file_exists PATH
    sgnd_validate_file_exists() {
        local path="$1"
        [[ -f "$path" ]]
    }

    # sgnd_validate_path_exists
        # Returns:
        #   0 if the path exists; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_path_exists PATH
    sgnd_validate_path_exists() { [[ -e "$1" ]]; }

    # sgnd_validate_dir_exists
        # Returns:
        #   0 if the path is an existing directory; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_dir_exists PATH
    sgnd_validate_dir_exists() { [[ -d "$1" ]]; }

    # sgnd_validate_executable
        # Returns:
        #   0 if the path is executable; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_executable PATH
    sgnd_validate_executable() { [[ -x "$1" ]]; }

    # sgnd_validate_file_not_exists
        # Returns:
        #   0 if the path is not an existing regular file; 1 otherwise.
        #
        # Usage:
        #   sgnd_validate_file_not_exists PATH
    sgnd_validate_file_not_exists() { [[ ! -f "$1" ]]; }
