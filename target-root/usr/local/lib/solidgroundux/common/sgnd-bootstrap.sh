# =====================================================================================
# SolidgroundUX - Bootstrap Core
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : 20fb63472d1d804a40d05bfb8f0bc8f688c034fdd9609b4abf5bfa62b27f6621
#   Source      : sgnd-bootstrap.sh
#   Type        : library
#   Group       : Bootstrap
#   Purpose     : Initialize the SolidgroundUX framework and load core modules
#
# Description:
#   Provides the central bootstrap mechanism for all SolidgroundUX scripts.
#
#   The library:
#     - Orchestrates framework initialization sequence
#     - Loads core and declared libraries (SGND_USING)
#     - Parses and separates framework and script arguments
#     - Initializes environment, configuration, and runtime state
#     - Applies standard execution flow for all scripts
#     - Ensures consistent startup behavior across all tools
#
# Design principles:
#   - Single entry point for framework initialization
#   - Deterministic and repeatable startup sequence
#   - Explicit dependency loading via SGND_USING
#   - Minimal assumptions about script context
#
# Role in framework:
#   - Central orchestrator of the SolidgroundUX runtime
#   - Bridges bootstrap environment, argument parsing, and module loading
#   - Ensures every script runs within a fully initialized framework context
#
# Non-goals:
#   - Business logic execution
#   - UI rendering or interaction handling
#   - Application-specific behavior
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : 
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail
# --- Library guard -------------------------------------------------------------------
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

    # _boot_fail
        # Purpose:
        #   Emit a bootstrap failure message with caller context and return a code.
        #
        # Behavior:
        #   - Captures caller file, function, and line information.
        #   - Formats one contextual failure message.
        #   - Writes the message through sayfail.
        #   - Returns the supplied status code unchanged.
        #
        # Arguments:
        #   $1  MESSAGE
        #       Failure text to report.
        #   $2  RETURN_CODE
        #       Code to return to the caller.
        #       Default: 1
        #
        # Output:
        #   Writes one formatted FAIL message to stderr.
        #
        # Returns:
        #   The supplied return code.
        #
        # Usage:
        #   cmd || { local rc=$?; _boot_fail "Step failed" "$rc"; return "$rc"; }
        #
        # Examples:
        #   _boot_fail "Framework cfg load failed" 1
    _boot_fail() {
        local msg="${1:-Bootstrap step failed}"
        local rc="${2:-1}"

        # Caller context
        local caller_file="${BASH_SOURCE[1]}"
        local caller_func="${FUNCNAME[1]}"
        local caller_line="${BASH_LINENO[0]}"

        local fnlmsg="${msg} (at ${caller_file}:${caller_line} in function ${caller_func})"

        sayfail "$fnlmsg"
        return "$rc"
    }

# --- Main sequence helpers + EXIT dispatch -------------------------------------------
    # _parse_bootstrap_args
        # Purpose:
        #   Parse framework-level bootstrap switches before script/builtin parsing.
        #
        # Arguments:
        #   $@  Full command line as received by sgnd_bootstrap().
        #
        # Outputs (globals):
        #   exe_state
        #     0 = no state, 1 = load state, 2 = load + autosave state on EXIT.
        #   exe_root
        #     0 = no constraint, 1 = must be root, 2 = must be non-root.
        #   SGND_BOOTSTRAP_REST
        #     Array of remaining arguments after bootstrap parsing (preserved verbatim).
        #
        # Behavior:
        #   - Consumes recognized bootstrap switches from the start of the argument list.
        #   - Stops parsing at "--" or at the first unknown option.
        #   - Copies the remaining arguments into SGND_BOOTSTRAP_REST unchanged.
        #
        # Returns:
        #   0 always (validation is deferred to later stages).
        #
        # Notes:
        #   Recognized switches:
        #     --state      -> exe_state=1
        #     --autostate  -> exe_state=2
        #     --needroot   -> exe_root=1
        #     --cannotroot -> exe_root=2
        #     --log        -> SGND_LOGFILE_ENABLED=1
        #     --console    -> SGND_LOG_TO_CONSOLE=1
        #     --           -> explicit end of bootstrap switches
        #     <unknown>    -> implicit end of bootstrap switches

    _parse_bootstrap_args() {
        exe_state=0
        exe_root=0

        SGND_BOOTSTRAP_REST=()

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --state)
                    exe_state=1; shift ;;
                --autostate)
                     exe_state=2; shift ;;
                --needroot)
                    exe_root=1; shift ;;
                --cannotroot)
                    exe_root=2; shift ;;
                --log)
                    SGND_LOGFILE_ENABLED=1; shift ;;
                --quiet)
                    SGND_LOG_TO_CONSOLE=0; shift ;;
                --) 
                    shift; SGND_BOOTSTRAP_REST=("$@"); return 0 ;;
                *) 
                    SGND_BOOTSTRAP_REST=("$@"); return 0 ;;
            esac
        done
    }

    # _init_bootstrap
        # Purpose:
        #   Initialize the early bootstrap environment before core library loading.
        #
        # Behavior:
        #   - Resolves SGND_BOOTSTRAP_DIR from the current file location.
        #   - Sources sgnd-comment-header-parser.sh and sgnd-bootstrap-env.sh.
        #   - Initializes bootstrap-related module metadata once header parsing is available.
        #   - Initializes executable metadata for the calling script.
        #   - Applies default framework values.
        #   - Rebuilds derived directories and framework cfg paths.
        #   - Ensures required framework directories exist.
        #
        # Outputs (globals):
        #   SGND_BOOTSTRAP_DIR
        #
        # Side effects:
        #   - Sources bootstrap support libraries.
        #   - Populates bootstrap and script metadata variables.
        #   - Recomputes framework path globals.
        #   - Creates required directories when missing.
        #
        # Returns:
        #   0 on success.
        #   Non-zero if a sourced dependency or bootstrap step fails.
        #
        # Notes:
        #   - Runs before core libraries are sourced.
        #   - May execute more than once across process boundaries when root re-exec occurs.
    _init_bootstrap() {
        sayinfo "Sourcing bootstrap environment"
        SGND_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        # shellcheck source=/dev/null
        source "$SGND_BOOTSTRAP_DIR/sgnd-comment-header-parser.sh"
        source "$SGND_BOOTSTRAP_DIR/sgnd-bootstrap-env.sh"

        # Core modules cannot self-initialize metadata during early source phase.
        # Initialize them here once header parsing helpers are available.     
        sgnd_module_init_metadata "$SGND_BOOTSTRAP_DIR/sgnd-bootstrap.sh"
        sgnd_module_init_metadata "$SGND_BOOTSTRAP_DIR/sgnd-comment-header-parser.sh"
        sgnd_module_init_metadata "$SGND_BOOTSTRAP_DIR/sgnd-bootstrap-env.sh"

        sgnd_script_init_metadata

        sgnd_apply_defaults

        sayinfo "Rebasing directories"
        sgnd_rebase_directories
        sgnd_rebase_framework_cfg_paths  

        sayinfo "Making sure directories exist"
        sgnd_ensure_dirs "${SGND_FRAMEWORK_DIRS[@]}"

    }

    # _source_corelibs
        # Purpose:
        #   Source core framework libraries in the defined order (SGND_CORE_LIBS).
        #
        # Inputs (globals):
        #   SGND_COMMON_LIB
        #   SGND_CORE_LIBS
        #
        # Behavior:
        #   - Rebase directories.
        #   - Sources each library from: $SGND_COMMON_LIB/<lib>.
        #
        # Side effects:
        #   - Defines functions/variables provided by core libraries.
        #
        # Returns:
        #   Propagates any sourcing failures to the caller.
    _source_corelibs(){
        sayinfo "Loading core libraries..."  
        sgnd_rebase_directories

        local lib path
        for lib in "${SGND_CORE_LIBS[@]}"; do
            path="$SGND_COMMON_LIB/$lib"
            # shellcheck source=/dev/null
            source "$path"
        done
    }

    # _source_usinglibs
        # Purpose:
        #   Source optional script-requested libraries from SGND_COMMON_LIB.
        #
        # Inputs (globals):
        #   SGND_COMMON_LIB
        #   SGND_USING
        #
        # Behavior:
        #   - If SGND_USING is defined and non-empty, sources each library from:
        #       $SGND_COMMON_LIB/<lib>
        #   - Libraries are loaded after core libraries, so they may depend on them.
        #
        # Returns:
        #   0  success
        #   Non-zero if any requested library cannot be sourced
    _source_usinglibs() {
        local lib path

        declare -p SGND_USING >/dev/null 2>&1 || return 0
        (( ${#SGND_USING[@]} > 0 )) || return 0

        sayinfo "Loading optional libraries..."

        for lib in "${SGND_USING[@]}"; do
            path="$SGND_COMMON_LIB/$lib"
            [[ -r "$path" ]] || {
                sayfail "Optional library not found or unreadable: $path"
                return 126
            }

            saydebug "Sourcing optional library: $path"
            # shellcheck source=/dev/null
            source "$path"
        done
    }

    # _sgnd_on_exit_run
        # Purpose:
        #   Execute registered EXIT handlers (LIFO) while preserving the original exit code.
        #
        # Inputs (globals):
        #   SGND_ON_EXIT_HANDLERS
        #
        # Behavior:
        #   - Captures the current exit code ($?) immediately.
        #   - Executes handlers in reverse registration order.
        #   - Evaluates each handler via eval.
        #   - Ignores handler failures to ensure all handlers run.
        #
        # Returns:
        #   The original exit code.
        #
        # Notes:
        #   Installed once via sgnd_on_exit_install().
    _sgnd_on_exit_run() {
        local rc=$?
        local i cmd
        saydebug "Entering on exit"
        declare -p SGND_ON_EXIT_HANDLERS >/dev/null 2>&1 || { return "$rc"; }

        for (( i=${#SGND_ON_EXIT_HANDLERS[@]}-1; i>=0; i-- )); do
            
            cmd="${SGND_ON_EXIT_HANDLERS[i]}"
            saydebug "On exit executing: $cmd"
            eval "$cmd" || true
        done

        return "$rc"
    }

    # _sgnd_save_state_dispatch
        # Purpose:
        #   Save state on EXIT only for clean exits.
        #
        # Behavior:
        #   - Captures the current exit code ($?).
        #   - Calls sgnd_save_state only when rc == 0.
        #   - Skips save on rc == 130 (Ctrl+C) and other non-zero exits.
        #
        # Returns:
        #   The original exit code.
        #
        # Notes:
        #   Registered only when --autostate is active.
    _sgnd_save_state_dispatch() {
        local rc=$?   # capture immediately!

        # Only run state save on clean exit
        if (( rc == 0 && SGND_STATE_SAVE == 1 )); then
            sgnd_save_state
        elif (( rc == 130 )); then
            saydebug "Interrupted (Ctrl+C), not saving state"
        else
            saydebug "Error exit ($rc), not saving state"
        fi

        return "$rc"
    }

# --- Public API ----------------------------------------------------------------------
    # sgnd_script_init_metadata
        # Purpose:
        #   Initialize executable metadata from structured header comments.
        #
        # Behavior:
        #   - Reads structured header sections once:
        #       • Banner line  (Product / Title)
        #       • Description  (multiline)
        #       • Metadata     (key/value pairs)
        #       • Attribution  (key/value pairs)
        #   - Extracts values from these sections and assigns them to
        #     SGND_SCRIPT_* variables.
        #   - Preserves existing values, allowing developer overrides.
        #   - Avoids repeated file scans by working on in-memory section content.
        #
        # Arguments:
        #   None (uses SGND_SCRIPT_FILE)
        #
        # Inputs (globals):
        #   SGND_SCRIPT_FILE  (must be set before calling)
        #
        # Outputs (globals):
        #   SGND_SCRIPT_PRODUCT
        #   SGND_SCRIPT_TITLE
        #   SGND_SCRIPT_DESC
        #   SGND_SCRIPT_VERSION
        #   SGND_SCRIPT_BUILD
        #   SGND_SCRIPT_CHECKSUM
        #   SGND_SCRIPT_SOURCE
        #   SGND_SCRIPT_TYPE
        #   SGND_SCRIPT_PURPOSE
        #   SGND_SCRIPT_DEVELOPERS
        #   SGND_SCRIPT_COMPANY
        #   SGND_SCRIPT_CLIENT
        #   SGND_SCRIPT_COPYRIGHT
        #   SGND_SCRIPT_LICENSE
        #
        # Returns:
        #   0  success
        #   1  missing or unreadable SGND_SCRIPT_FILE
        #
        # Usage:
        #   SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
        #   sgnd_script_init_metadata
        #
        # Notes:
        #   - Must be called after bootstrap initialization, as it depends on
        #     header parsing helpers (sgnd_header_get_*).
        #   - Intended for executables (not libraries).
        #   - Uses sgnd_section_get_field_value for in-memory parsing.
    sgnd_script_init_metadata() {
        local metadata=""
        local attribution=""
        local value=""

        [[ -n "${SGND_SCRIPT_FILE:-}" && -r "$SGND_SCRIPT_FILE" ]] || return 1

        # --- Banner (Product / Title) ------------------------------------------------
        [[ -n "${SGND_SCRIPT_PRODUCT:-}" && -n "${SGND_SCRIPT_TITLE:-}" ]] || \
            sgnd_header_get_banner_parts "$SGND_SCRIPT_FILE" SGND_SCRIPT_PRODUCT SGND_SCRIPT_TITLE

        # --- Description (multiline section) -----------------------------------------
        [[ -n "${SGND_SCRIPT_DESCRIPTION:-}" ]] || \
            sgnd_header_get_section "$SGND_SCRIPT_FILE" "Description" SGND_SCRIPT_DESCRIPTION

        # --- Load sections once ------------------------------------------------------
        sgnd_header_get_section "$SGND_SCRIPT_FILE" "Metadata" metadata
        sgnd_header_get_section "$SGND_SCRIPT_FILE" "Attribution" attribution

        # --- Metadata fields ---------------------------------------------------------
        [[ -n "${SGND_SCRIPT_VERSION:-}" ]]   || SGND_SCRIPT_VERSION="$(sgnd_section_get_field_value "$metadata" "Version")"
        [[ -n "${SGND_SCRIPT_BUILD:-}" ]]     || SGND_SCRIPT_BUILD="$(sgnd_section_get_field_value "$metadata" "Build")"
        [[ -n "${SGND_SCRIPT_CHECKSUM:-}" ]]  || SGND_SCRIPT_CHECKSUM="$(sgnd_section_get_field_value "$metadata" "Checksum")"
        [[ -n "${SGND_SCRIPT_SOURCE:-}" ]]    || SGND_SCRIPT_SOURCE="$(sgnd_section_get_field_value "$metadata" "Source")"
        [[ -n "${SGND_SCRIPT_TYPE:-}" ]]      || SGND_SCRIPT_TYPE="$(sgnd_section_get_field_value "$metadata" "Type")"
        [[ -n "${SGND_SCRIPT_PURPOSE:-}" ]]   || SGND_SCRIPT_PURPOSE="$(sgnd_section_get_field_value "$metadata" "Purpose")"

        # --- Attribution fields ------------------------------------------------------
        [[ -n "${SGND_SCRIPT_DEVELOPERS:-}" ]] || SGND_SCRIPT_DEVELOPERS="$(sgnd_section_get_field_value "$attribution" "Developers")"    
        [[ -n "${SGND_SCRIPT_COMPANY:-}" ]]    || SGND_SCRIPT_COMPANY="$(sgnd_section_get_field_value "$attribution" "Company")"
        [[ -n "${SGND_SCRIPT_CLIENT:-}" ]]     || SGND_SCRIPT_CLIENT="$(sgnd_section_get_field_value "$attribution" "Client")"
        [[ -n "${SGND_SCRIPT_COPYRIGHT:-}" ]]  || SGND_SCRIPT_COPYRIGHT="$(sgnd_section_get_field_value "$attribution" "Copyright")"
        [[ -n "${SGND_SCRIPT_LICENSE:-}" ]]    || SGND_SCRIPT_LICENSE="$(sgnd_section_get_field_value "$attribution" "License")"

        # --- Short description (first line of Description) ------------------------------
        if [[ -z "${SGND_SCRIPT_DESC:-}" ]]; then
            if [[ -n "${SGND_SCRIPT_DESCRIPTION:-}" ]]; then
                SGND_SCRIPT_DESC="${SGND_SCRIPT_DESCRIPTION%%$'\n'*}"
            else
                SGND_SCRIPT_DESC=""
            fi
        fi
        return 0
    }

    # sgnd_module_init_metadata
        # Purpose:
        #   Define module-scoped metadata variables for a sourced library and
        #   populate them from the library header comment.
        #
        # Behavior:
        #   - Derives a canonical module prefix from the library filename.
        #       e.g. sgnd-comment-parser.sh → SGND_COMMENT_PARSER
        #   - Defines structural variables:
        #       SGND_<MODULE>_FILE
        #       SGND_<MODULE>_DIR
        #       SGND_<MODULE>_BASE
        #       SGND_<MODULE>_NAME
        #       SGND_<MODULE>_KEY
        #   - Loads the script header into the shared header buffer once.
        #   - Extracts banner metadata:
        #       SGND_<MODULE>_PRODUCT
        #       SGND_<MODULE>_TITLE
        #   - Extracts Description section:
        #       SGND_<MODULE>_DESC
        #   - Extracts common metadata and attribution fields from buffered section text:
        #       Version, Build, Checksum, Source, Type, Purpose
        #       Developers, Company, Client, Copyright, License
        #   - Preserves existing values (allows developer override).
        #
        # Arguments:
        #   $1  FILE   (optional; defaults to BASH_SOURCE[1])
        #
        # Outputs (globals):
        #   SGND_<MODULE>_*
        #
        # Returns:
        #   0  success
        #   1  file missing or unreadable
        #
        # Usage:
        #   sgnd_module_init_metadata "${BASH_SOURCE[0]}"
        #
        # Notes:
        #   - Intended for libraries only.
        #   - Uses buffered header parsing to reduce repeated file reads.
    sgnd_module_init_metadata() {
        local file="${1:-${BASH_SOURCE[1]}}"
        local abs_file=""
        local dir=""
        local base=""
        local name=""
        local key=""
        local prefix=""
        local var_name=""

        local product=""
        local title=""
        local desc=""
        local metadata=""
        local attribution=""
        local value=""

        [[ -n "$file" && -r "$file" ]] || return 1

        abs_file="$(readlink -f "$file")" || return 1
        dir="$(cd -- "$(dirname -- "$abs_file")" && pwd)" || return 1
        base="$(basename -- "$abs_file")"
        name="${base%.sh}"
        key="${name//-/_}"
        prefix="SGND_${key^^}"

        # --- Structural variables ----------------------------------------------------
        var_name="${prefix}_FILE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$abs_file"
        var_name="${prefix}_DIR";  [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$dir"
        var_name="${prefix}_BASE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$base"
        var_name="${prefix}_NAME"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$name"
        var_name="${prefix}_KEY";  [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$prefix"

        # --- Load header buffer once -------------------------------------------------
        sgnd_header_buffer_load "$abs_file" || return 1

        # --- Banner (Product / Title) ------------------------------------------------
        if sgnd_header_get_banner_parts_from_text "$SGND_HEADER_BUFFER_TEXT" product title; then
            var_name="${prefix}_PRODUCT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$product"
            var_name="${prefix}_TITLE";   [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$title"
        else
            var_name="${prefix}_PRODUCT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' ""
            var_name="${prefix}_TITLE";   [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' ""
        fi

        # --- Load sections once ------------------------------------------------------
        sgnd_header_buffer_get_section "Description" desc || desc=""
        sgnd_header_buffer_get_section "Metadata" metadata || metadata=""
        sgnd_header_buffer_get_section "Attribution" attribution || attribution=""

        # --- Description (multiline section) -----------------------------------------
        var_name="${prefix}_DESC"
        if [[ -z "${!var_name-}" ]]; then
            printf -v "$var_name" '%s' "$desc"
        fi

        # --- Metadata fields ---------------------------------------------------------
        value="$(sgnd_section_get_field_value "$metadata" "Version")"
        var_name="${prefix}_VERSION"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Build")"
        var_name="${prefix}_BUILD"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Checksum")"
        var_name="${prefix}_CHECKSUM"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Source")"
        var_name="${prefix}_SOURCE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Type")"
        var_name="${prefix}_TYPE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Purpose")"
        var_name="${prefix}_PURPOSE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        # --- Attribution fields ------------------------------------------------------
        value="$(sgnd_section_get_field_value "$attribution" "Developers")"
        var_name="${prefix}_DEVELOPERS"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "Company")"
        var_name="${prefix}_COMPANY"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "Client")"
        var_name="${prefix}_CLIENT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "Copyright")"
        var_name="${prefix}_COPYRIGHT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "License")"
        var_name="${prefix}_LICENSE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        return 0
    }

    # sgnd_on_exit_install
        # Purpose:
        #   Install the framework EXIT dispatcher (trap) exactly once per process.
        #
        # Behavior:
        #   - If not yet installed, registers _sgnd_on_exit_run as the EXIT trap.
        #   - Subsequent calls are no-ops (idempotent).
        #
        # Side effects:
        #   - Sets _SGND_ON_EXIT_INSTALLED=1 on first install.
        #   - Installs an EXIT trap handler.
        #
        # Returns:
        #   0 always.
        #
        # Notes:
        #   - This does not register handlers; it only installs the dispatcher.
        #   - Add handlers via sgnd_on_exit_add().
    sgnd_on_exit_install() {
        # Install once
        [[ "${_SGND_ON_EXIT_INSTALLED-0}" -eq 1 ]] && return 0
        _SGND_ON_EXIT_INSTALLED=1
        trap '_sgnd_on_exit_run' EXIT
    }

    # sgnd_parse_statespec
        # Purpose:
        #   Parse a pipe-delimited state specification into component fields.
        #
        # Arguments:
        #   $1  State specification string in the format:
        #       key|label|default|validator|colorize
        #
        # Outputs (globals):
        #   _statekey       Variable name to persist (expected identifier).
        #   _statelabel     Optional human-readable label (UI/prompt usage).
        #   _statedefault   Optional default value when no persisted value exists.
        #   _statevalidate  Optional validator function name.
        #   _statecolorize  Optional UI color token.
        #
        # Behavior:
        #   - Splits the spec on '|' using IFS.
        #   - Assigns missing fields as empty strings.
        #
        # Returns:
        #   0 always (parsing only; no validation performed here).
        #
        # Notes:
        #   - Callers must validate _statekey and interpret semantics of other fields.
        #   - Scratch variables are intentionally global to avoid array/echo returns.
    sgnd_parse_statespec() {
        local spec="${1-}"
        _statekey="" _statelabel="" _statedefault="" _statevalidate="" _statecolorize=""
        IFS='|' read -r _statekey _statelabel _statedefault _statevalidate _statecolorize <<< "$spec"
    }
    
    # sgnd_enable_save_state
        # Purpose:
        #   Enable automatic state persistence.
        #
        # Behavior:
        #   - Sets SGND_STATE_SAVE=1.
        #   - Allows sgnd_save_state to execute when invoked.
    sgnd_enable_save_state(){
        SGND_STATE_SAVE=1
    }

    # sgnd_disable_save_state
        # Purpose:
        #   Disable automatic state persistence.
        #
        # Behavior:
        #   - Sets SGND_STATE_SAVE=0.
        #   - Causes sgnd_save_state to become a no-op.
    sgnd_disable_save_state(){
        SGND_STATE_SAVE=0
    }

    # sgnd_save_state
        # Purpose:
        #   Persist selected state variables to storage (as configured by SGND_STATE_VARIABLES).
        #
        # Inputs (globals):
        #   SGND_STATE_SAVE       Gate flag (0 disables saving; non-zero enables saving).
        #   SGND_STATE_VARIABLES  Array of state specs (pipe-delimited).
        #
        # Behavior:
        #   - No-op if SGND_STATE_SAVE is disabled.
        #   - Parses each SGND_STATE_VARIABLES entry via sgnd_parse_statespec().
        #   - Collects valid state keys (identifiers) into a local list.
        #   - Delegates persistence to sgnd_state_save_keys <keys...>.
        #
        # Side effects:
        #   - Writes state via sgnd_state_save_keys() (implementation-owned).
        #
        # Returns:
        #   0 on success or when no-op (disabled or nothing to save).
        #   Non-zero if sgnd_state_save_keys fails.
        #
        # Notes:
        #   - Intended to be called from EXIT dispatch (e.g., _sgnd_save_state_dispatch).
        #   - Validation is limited to identifier checks; semantics belong to state layer.
    sgnd_save_state(){

        (( ! SGND_STATE_SAVE )) && return 0

        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have saved state variables from list"
        else
            saydebug "Assembling list out of SGND_STATE_VARIABLES"
            local line key label def validator colorize
            local keys=()

            [[ ${#SGND_STATE_VARIABLES[@]} -gt 0 ]] || return 0
            saystart "Saving state variables"
            for line in "${SGND_STATE_VARIABLES[@]}"; do
                sgnd_parse_statespec "$line"
                key="$(sgnd_trim "$_statekey")"
                _sgnd_is_ident "$key" || continue
                keys+=( "$key" )
            done

            saydebug "Saving state variables from array"
            # Only save if the array exists and has elements
            [[ ${#keys[@]} -gt 0 ]] || return 0
            sgnd_state_save_keys "${keys[@]}"
            sayend "Done saving state variables."
        fi
    }    

    # sgnd_on_exit_add
        # Purpose:
        #   Register a new EXIT handler to be executed by the EXIT dispatcher.
        #
        # Arguments:
        #   $*  Command string to execute on process EXIT (stored as a single string).
        #
        # Inputs (globals):
        #   SGND_ON_EXIT_HANDLERS
        #
        # Behavior:
        #   - Appends the handler command string to SGND_ON_EXIT_HANDLERS.
        #   - Handlers execute in reverse registration order (LIFO).
        #
        # Returns:
        #   0 always.
        #
        # Notes:
        #   - Handlers are evaluated via eval in _sgnd_on_exit_run.
        #   - Call sgnd_on_exit_install() before relying on handlers running.
    sgnd_on_exit_add() {
        # store as one string per handler: "fn arg1 arg2 ..."
        SGND_ON_EXIT_HANDLERS+=( "$*" )
    }

    # sgnd_check_license
        # Purpose:
        #   Verify that the current framework license has been accepted.
        #
        # Behavior:
        #   - Computes the hash of the current license file.
        #   - Checks whether a stored acceptance record exists.
        #   - Compares the stored hash with the current license hash.
        #   - Prints the license and prompts the user when acceptance is missing or outdated.
        #   - Stores the current license hash when the user accepts.
        #   - Updates SGND_LICENSE_ACCEPTED to reflect the resulting state.
        #
        # Inputs (globals):
        #   SGND_DOCS_DIR
        #   SGND_LICENSE_FILE
        #   SGND_STATE_DIR
        #
        # Outputs (globals):
        #   SGND_LICENSE_ACCEPTED
        #
        # Side effects:
        #   - May print the license text.
        #   - May prompt the user for acceptance.
        #   - May write an acceptance file under SGND_STATE_DIR.
        #
        # Returns:
        #   0 if the license is accepted.
        #   2 if the user declines or cancels.
        #   1 on operational failure.
        #
        # Usage:
        #   sgnd_check_license || return $?
        #
        # Examples:
        #   sgnd_check_license
        #
        # Notes:
        #   - Intended to run only after root/non-root re-exec decisions are complete,
        #     to avoid prompting twice.
        #   - Called only after root constraints are resolved to avoid double prompting
        #     across sudo re-exec.
    sgnd_check_license() {
        local license_file="$SGND_DOCS_DIR/$SGND_LICENSE_FILE"
        local accepted_file="$SGND_STATE_DIR/$SGND_LICENSE_FILE.accepted"
        local isaccepted=0
        local wasaccepted=0
        local current_hash

        if ! current_hash="$(sgnd_hash_sha256_file "$license_file")"; then
            saywarning "sgnd_check_license: could not compute hash"
            current_hash=""
        fi

        if [[ -r "$accepted_file" ]]; then

            local stored_hash
            stored_hash="$(cat "$accepted_file" 2>/dev/null)"
            wasaccepted=1

            if [[ "$stored_hash" == "$current_hash" ]]; then
                sayinfo "sgnd_check_license: accepted state matches current license hash"
                isaccepted=1
            else
                sayinfo "sgnd_check_license: accepted state hash does NOT match current license hash"
            fi
        else
            sayinfo "sgnd_check_license: no accepted state file found at: $accepted_file"
        fi

        if (( isaccepted == 0 )); then
            local question_text
            if (( ${wasaccepted:-0} == 1 )); then
                question_text="The license has been updated since you last accepted it. Do you accept the new license terms?"
            else
                question_text="Do you accept these license terms? \n (You must accept to use this software.)"
            fi

            sgnd_print_license 
            
            local accepted="Y"
            ask --label "$question_text" --var accepted --default "$accepted" --colorize both --labelclr "${CYAN}" 
            case $? in
                0)
                    echo "$current_hash" > "$accepted_file"
                    ;;
                1)
                    saywarning "Cancelled by user."
                    return 2
                    ;;
                2)
                    saywarning "Cancelled by user."
                    return 2
                    ;;
                *)
                    sayfail "Aborting (unexpected response)."
                    return 1
                    ;;
            esac
                       
            sayinfo "sgnd_check_license: license not accepted; prompting user"
        fi

        sayinfo "License acceptance status: $(
            [[ $isaccepted -eq 1 ]] \
            && echo "${TUI_VALID}ACCEPTED${RESET}" \
            || echo "${TUI_INVALID}NOT ACCEPTED${RESET}"
        )"

        SGND_LICENSE_ACCEPTED=$isaccepted
    }

    # sgnd_load_ui_style
        # Purpose:
        #   Load the active UI palette and style definitions.
        #
        # Behavior:
        #   - Resolves SGND_UI_PALETTE and SGND_UI_STYLE to full paths when needed.
        #   - Treats basename-only values as files under SGND_STYLE_DIR.
        #   - Sources the palette file first.
        #   - Sources the style file second.
        #
        # Inputs (globals):
        #   SGND_UI_PALETTE
        #   SGND_UI_STYLE
        #   SGND_STYLE_DIR
        #
        # Side effects:
        #   - Sources palette and style files into the current shell.
        #
        # Returns:
        #   0 on success.
        #   1 if either file is missing or unreadable.
        #
        # Usage:
        #   sgnd_load_ui_style || return 1
        #
        # Examples:
        #   sgnd_load_ui_style
    sgnd_load_ui_style() {
        local style_path palette_path

        style_path="$SGND_UI_STYLE"
        palette_path="$SGND_UI_PALETTE"

        # If values are basenames, resolve from SGND_STYLE_DIR
        [[ "$style_path" == */* ]] || style_path="$SGND_STYLE_DIR/$style_path"
        [[ "$palette_path" == */* ]] || palette_path="$SGND_STYLE_DIR/$palette_path"

        [[ -r "$palette_path" ]] || { saywarning "Palette not found: $palette_path"; return 1; }
        [[ -r "$style_path"   ]] || { saywarning "Style not found: $style_path";   return 1; }

        # shellcheck source=/dev/null
        source "$palette_path"
        # shellcheck source=/dev/null
        source "$style_path"
    }
    
# --- Main ----------------------------------------------------------------------------
    # sgnd_bootstrap
        # Purpose:
        #   Initialize the Testadura framework runtime environment.
        #
        # Behavior:
        #   - Sources sgnd-bootstrap-env.sh.
        #   - Applies default configuration values.
        #   - Derives framework directory and cfg paths.
        #   - Ensures required directories exist.
        #   - Loads core libraries defined in SGND_CORE_LIBS.
        #   - Applies framework configuration (system + user).
        #
        # Inputs (globals):
        #   SGND_COMMON_LIB (optional override before call)
        #
        # Outputs (globals):
        #   All SGND_* framework variables
        #   Loaded functions from core libraries
        #
        # Side effects:
        #   - Creates directories if missing
        #   - Sources multiple library files
        #   - Applies configuration values to global state
        #
        # Returns:
        #   0   success
        #   1   failure loading required components
        #
        # Usage:
        #   sgnd_bootstrap
        #
        # Examples:
        #   # Minimal bootstrap
        #   sgnd_bootstrap
        #
        #   # Override root before bootstrap
        #   SGND_FRAMEWORK_ROOT="/opt/solidgroundux"
        #   sgnd_bootstrap
    sgnd_bootstrap() {
        saystart "Initializing framework"
        # Definitions
            : "${TUI_COMMIT:=$(printf '\e[38;5;214m')}"
            : "${TUI_DRYRUN:=$(printf '\e[38;5;214m')}"
            : "${RESET:=$(printf '\e[0m')}"
            : "${RUN_MODE:="${TUI_COMMIT}COMMIT${RESET}"}"
            : "${FLAG_DEBUG:=0}"
            : "${FLAG_DRYRUN:=0}"
            : "${FLAG_VERBOSE:=0}"
            : "${FLAG_STATERESET:=0}"
            : "${FLAG_INIT_CONFIG:=0}"
            : "${FLAG_SHOWARGS:=0}"
            : "${FLAG_HELP:=0}"

            if ! declare -p SGND_SCRIPT_GLOBALS >/dev/null 2>&1; then
                declare -ag SGND_SCRIPT_GLOBALS=()
            fi
            
            if ! declare -p SGND_STATE_VARIABLES >/dev/null 2>&1; then
                declare -ag SGND_STATE_VARIABLES=()
            fi

            if ! declare -p SGND_ON_EXIT_HANDLERS >/dev/null 2>&1; then
                declare -ag SGND_ON_EXIT_HANDLERS=()
            fi

        # Basic initialization - Defaults
            sayinfo "Initializing bootstrap..."
            _init_bootstrap || { local rc=$?; _boot_fail "Failed to initialize bootstrapper" "$rc"; return "$rc"; }

            sayinfo "Parsing bootstrap arguments..."
            _parse_bootstrap_args "$@" || { local rc=$?; _boot_fail "Failed parsing bootstrap arguments" "$rc"; return "$rc"; }

            _source_corelibs || { local rc=$?; _boot_fail "Failed to load core libraries" "$rc"; return "$rc"; }
            _source_usinglibs || { local rc=$?; _boot_fail "Failed to load optional libraries" "$rc"; return "$rc"; }

            sayinfo "Loading UI style"
            sgnd_load_ui_style || { local rc=$?; _boot_fail "Failed to load UI style" "$rc"; return "$rc"; }

        # Load Framework globals
            sayinfo "Loading framework globals"
            sgnd_cfg_domain_apply "Framework" "$SGND_FRAMEWORK_SYSCFG_FILE" "$SGND_FRAMEWORK_USRCFG_FILE" "SGND_FRAMEWORK_GLOBALS" "framework" \
                || { local rc=$?; _boot_fail "Framework cfg load failed" "$rc"; return "$rc"; }

        # Parse builtin arguments early
            saydebug "Processing builtin arguments."
            local -a _sgnd_script_args
            local -a _sgnd_after_builtins
                _sgnd_script_args=( "${SGND_BOOTSTRAP_REST[@]}" )

            saydebug "Parsing arguments $SGND_BUILTIN_ARGS ${_sgnd_script_args[@]}"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
            sgnd_parse_args --stop-at-unknown "${_sgnd_script_args[@]}" || { local rc=$?; _boot_fail "Error parsing builtins" "$rc"; return "$rc"; }
            
            _sgnd_after_builtins=( "${SGND_POSITIONAL[@]}" )

        # Final basic settings
            saydebug "Finalizing initial settings"
            sgnd_update_runmode || { local rc=$?; _boot_fail "Error setting RUN_MODE" "$rc"; return "$rc"; }

        sayinfo "Applying bootstrap options"

        # Root checks (after libs so need_root exists)
            if (( exe_root == 1 )); then
                sgnd_need_root "${_sgnd_script_args[@]}" \
                    || { local rc=$?; _boot_fail "Failed to enable need_root" "$rc"; return "$rc"; }
            fi

            if (( exe_root == 2 )); then
                sgnd_cannot_root "${_sgnd_script_args[@]}" \
                    || { local rc=$?; _boot_fail "Failed to enable cannot_root" "$rc"; return "$rc"; }
            fi

        # Now the root/non-root debate has been settled, check license acceptance.
            sgnd_check_license
            case $? in
                0) : ;;
                2) return 2 ;;
                *) { _boot_fail "License acceptance check failed" 1; return 1; } ;;
            esac
        
        # Now that we know we won't re-exec, continue with the remainder of the arguments
        SGND_BOOTSTRAP_REST=( "${_sgnd_after_builtins[@]}" )

        # Reset statefile before it's loaded if requested
        if [[ "${FLAG_STATERESET:-0}" -eq 1 ]]; then
            sgnd_state_reset
            sayinfo "State file reset as requested."
        fi

        # Load state and parse *script* args
        if (( exe_state > 0 )); then
            saydebug "Installing on exit handler"
            sgnd_on_exit_install

            saydebug "Loading state file."
            sgnd_state_load || { local rc=$?; _boot_fail "Failed to load state" "$rc"; return "$rc"; }
        fi

        if (( exe_state == 2 )); then
            saydebug "Registering save state"
            sgnd_on_exit_add "_sgnd_save_state_dispatch"
        fi
        
        if (( ${#SGND_SCRIPT_GLOBALS[@]} > 0 )); then
            saydebug "Processing CFG."
            sgnd_cfg_domain_apply "Script" "$SGND_SYSCFG_FILE" "$SGND_USRCFG_FILE" "SGND_SCRIPT_GLOBALS" \
                || { local rc=$?; _boot_fail "Script cfg load failed" "$rc"; return "$rc"; }
        fi

        # Always parse script args if the script defines any arg specs
        if (( ${#SGND_ARGS_SPEC[@]} > 0 && ${#SGND_BOOTSTRAP_REST[@]} > 0 )); then
            saydebug "Parsing script arguments $SGND_BOOTSTRAP_REST"
            sgnd_parse_args "${SGND_BOOTSTRAP_REST[@]}" \
                || { local rc=$?; _boot_fail "Error parsing script args" "$rc"; return "$rc"; }
            SGND_BOOTSTRAP_REST=( "${SGND_POSITIONAL[@]}" )
            saydebug "Parsed script arguments $SGND_BOOTSTRAP_REST remaining"
        fi

        saydebug "Update loadmode"
        sgnd_update_runmode || { local rc=$?; _boot_fail "Error updating RUN_MODE" "$rc"; return "$rc"; }

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Running in $RUN_MODE mode (no changes will be made)."
        else
            sayinfo "Running in $RUN_MODE mode (changes will be applied)."
        fi
        sayend "Finished bootstrap"
        return 0
    }






         
