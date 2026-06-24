# =====================================================================================
# SolidGroundUX - Argument Parsing
# -------------------------------------------------------------------------------------
# Metadata: 
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : sgnd-args.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Parse and manage command-line arguments for scripts
#
# Description:
#   Provides a structured argument parsing system for SolidGroundUX scripts.
#
#   The library:
#     - Parses short and long command-line arguments
#     - Supports flags, values, and enumerated options
#     - Maps arguments to strongly defined variables
#     - Validates input against argument specifications
#     - Separates framework arguments from script-specific arguments
#     - Generates consistent help and usage output
#
# Design principles:
#   - Declarative argument specification via SGND_ARGS_SPEC
#   - Predictable and consistent parsing behavior across scripts
#   - Clear separation between parsing and business logic
#   - Minimal runtime surprises through validation and normalization
#
# Role in framework:
#   - Core infrastructure for all executable scripts
#   - Used during bootstrap to interpret command-line input
#   - Enables standardized CLI behavior across the framework
#
# Non-goals:
#   - Complex subcommand frameworks (e.g., git-style commands)
#   - Interactive input handling (handled by ui-ask/ui-dlg)
#   - Dynamic runtime argument schema mutation
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

# --- Helper functions ----------------------------------------------------------------
    # fn: _sgnd_arg_split - Split one argument specification
        # . Purpose
        #   Parse a pipe-separated argument specification into parser fields.
        #
        # . Behavior
        #   - Reads one SGND argument specification string.
        #   - Splits the string into name, short option, type, target variable,
        #     help text, default value, and enum choices.
        #   - Stores parsed fields in parser-scoped scratch variables.
        #
        # . Arguments
        #   $1  Argument specification in name|short|type|var|help|default|choices format.
        #
        # Outputs (globals):
        #   _sgnd_name, _sgnd_short, _sgnd_type, _sgnd_var
        #   _sgnd_help, _sgnd_default, _sgnd_choices
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sgnd_arg_split "$spec"
    _sgnd_arg_split() {
        local spec="$1"
        IFS='|' read -r _sgnd_name _sgnd_short _sgnd_type _sgnd_var _sgnd_help _sgnd_default _sgnd_choices <<< "$spec"
    }

    # fn: _sgnd_arg_find_spec - Find an argument specification
        # . Purpose
        #   Locate the effective argument specification for a long or short option.
        #
        # . Behavior
        #   - Iterates SGND_EFFECTIVE_ARGS_SPEC in declaration order.
        #   - Matches either the long option name or the short option letter.
        #   - Prints the matching raw specification to stdout.
        #
        # . Arguments
        #   $1  Long option name or short option letter to find.
        #
        # Inputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC
        #
        # . Output
        #   Matching raw argument specification on stdout.
        #
        # . Returns
        #   0 when a matching specification is found.
        #   1 when no matching specification exists.
        #
        # . Usage
        #   spec="$(_sgnd_arg_find_spec "$opt")"
    _sgnd_arg_find_spec() {
        local wanted="$1"
        local spec

        for spec in "${SGND_EFFECTIVE_ARGS_SPEC[@]:-}"; do
            _sgnd_arg_split "$spec"
            if [[ "$_sgnd_name" == "$wanted" || "$_sgnd_short" == "$wanted" ]]; then
                printf '%s\n' "$spec"
                return 0
            fi
        done

        return 1
    }
    
    # fn: _sgnd_arg_validate_enum - Validate an enum argument value
        # . Purpose
        #   Test whether a supplied value is present in a comma-separated choice list.
        #
        # . Behavior
        #   - Splits the allowed choices on commas.
        #   - Compares the value with each allowed choice exactly.
        #   - Produces no output.
        #
        # . Arguments
        #   $1  Value to validate.
        #   $2  Comma-separated list of allowed values.
        #
        # . Returns
        #   0 when the value is allowed.
        #   1 when the value is not allowed.
        #
        # . Usage
        #   _sgnd_arg_validate_enum "$value" "$choices_csv"
    _sgnd_arg_validate_enum() {
        local value="$1"
        local choices_csv="$2"

        local choice
        local ok=0
        local choices_arr=()

        IFS=',' read -r -a choices_arr <<< "$choices_csv"
        for choice in "${choices_arr[@]}"; do
            if [[ "$choice" == "$value" ]]; then
                ok=1
                break
            fi
        done

        [[ "$ok" -eq 1 ]]
    }

    # fn: _sgnd_arg_init_defaults - Initialize argument defaults
        # . Purpose
        #   Initialize argument target variables from builtin and/or script argument specs.
        #
        # . Behavior
        #   - Selects builtin specs, script specs, or both depending on the source argument.
        #   - Initializes flag variables to their configured default or 0.
        #   - Initializes value and enum variables to their configured default or empty.
        #   - Stores the selected combined specification in SGND_EFFECTIVE_ARGS_SPEC.
        #
        # . Arguments
        #   $1  Source selector: builtins, script, or both.
        #       Default: both
        #
        # Inputs (globals):
        #   SGND_BUILTIN_ARGS, SGND_ARGS_SPEC
        #
        # Outputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC and configured argument target variables.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sgnd_arg_init_defaults both
    _sgnd_arg_init_defaults() {
        local source="${1:-both}"
        local -a args=()

        case "$source" in
            builtins)
                if declare -p SGND_BUILTIN_ARGS >/dev/null 2>&1; then
                    args+=( "${SGND_BUILTIN_ARGS[@]}" )
                fi
                ;;
            script)
                if declare -p SGND_ARGS_SPEC >/dev/null 2>&1; then
                    args+=( "${SGND_ARGS_SPEC[@]}" )
                fi
                ;;
            both|*)
                if declare -p SGND_BUILTIN_ARGS >/dev/null 2>&1; then
                    args+=( "${SGND_BUILTIN_ARGS[@]}" )
                fi
                if declare -p SGND_ARGS_SPEC >/dev/null 2>&1; then
                    args+=( "${SGND_ARGS_SPEC[@]}" )
                fi
                ;;
        esac

        local spec
        local init_value

        for spec in "${args[@]}"; do
            _sgnd_arg_split "$spec"
            [[ -n "${_sgnd_var:-}" && -n "${_sgnd_type:-}" ]] || continue

            case "$_sgnd_type" in
                flag)
                    init_value="${_sgnd_default:-0}"
                    ;;
                value|enum)
                    init_value="${_sgnd_default:-}"
                    ;;
                *)
                    continue
                    ;;
            esac

            printf -v "$_sgnd_var" '%s' "$init_value"
        done

        SGND_EFFECTIVE_ARGS_SPEC=( "${args[@]}" )
    }

# --- Public API ----------------------------------------------------------------------
    # var: Help layout settings
        # . Purpose
        #   Configure indentation used by sgnd_show_help when rendering section headers
        #   and option descriptions.
        #
        # Variables:
        #   _header_indent  Left padding for help section headers.
        #   _text_indent    Left padding for option description lines.
    _header_indent=2
    _text_indent=3

    # var: SGND_BUILTIN_ARGS - Builtin framework argument specifications
        # . Purpose
        #   Define standard command-line options available to framework-enabled scripts.
        #
        # Format:
        #   name|short|type|target_variable|help|default|choices
        #
        # Notes:
        #   - type is flag, value, or enum.
        #   - enum choices are comma-separated.
        #   - Target variables are initialized by _sgnd_arg_init_defaults.
    SGND_BUILTIN_ARGS=(
        "dryrun|D|flag|FLAG_DRYRUN|Emulate only; do not perform actions|"
        "help|H|flag|FLAG_HELP|Show command-line help and exit|"
        "log|G|flag|FLAG_LOG|Enable logfile output|"
        "loglevel||enum|ARG_LOGLEVEL|Set console output level||silent,quiet,normal,verbose,debug,trace"
        "show||enum|ARG_SHOW|Show internal information and exit||args,cfg,state,meta,license,readme,env"
        "statereset|R|flag|FLAG_STATERESET|Reset the state file|"
    )

    # var: SGND_BUILTIN_EXAMPLES - Builtin help examples
        # . Purpose
        #   Provide reusable help examples for standard framework options.
        #
        # Notes:
        #   - Examples may be merged with SGND_SCRIPT_EXAMPLES by sgnd_show_help.
        #   - SGND_SCRIPT_NAME is resolved lazily for display.
    SGND_BUILTIN_EXAMPLES=(
         "  ${SGND_SCRIPT_NAME:-<script>} --dryrun --loglevel debug"
         "  ${SGND_SCRIPT_NAME:-<script>} --log --loglevel silent"
         "  ${SGND_SCRIPT_NAME:-<script>} --show env"
    ) 
    # fn: sgnd_show_help - Show help
        # . Purpose
        #   Print usage information generated from a SolidGroundUX argument specification.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $0  ARG0 - Positional value used by this function.
        #   $1  INCLUDE_BUILTINS - Positional value used by this function.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_show_help "${ARG0}" "${INCLUDE_BUILTINS}"
    sgnd_show_help() {
        local include_builtins="${1:-1}"
        local script_name="${SGND_SCRIPT_NAME:-$(basename "${SGND_SCRIPT_FILE:-$0}")}"
        local spaces="   "

        sgnd_print_sectionheader --text "$script_name" 
        sgnd_print "${spaces}Usage:" 
        sgnd_print "\t$script_name [options] [--] [args...]\n" 
        sgnd_print "${spaces}Description:" 
        sgnd_print "\t${SGND_SCRIPT_DESC:-No description available}\n" 

        sgnd_print_sectionheader --text "Script options:" --padleft "$_header_indent"

        if declare -p SGND_ARGS_SPEC >/dev/null 2>&1; then
            local spec opt meta

            for spec in "${SGND_ARGS_SPEC[@]}"; do
                _sgnd_arg_split "$spec"

                # Skip malformed/empty spec entries
                [[ -n "${_sgnd_name:-}" && -n "${_sgnd_type:-}" && -n "${_sgnd_var:-}" ]] || continue

                if [[ -n "${_sgnd_short:-}" ]]; then
                    opt="-$_sgnd_short, --$_sgnd_name"
                else
                    opt="--$_sgnd_name"
                fi

                meta=""
                case "$_sgnd_type" in
                    value) meta=" VALUE" ;;
                    enum)  meta=" {${_sgnd_choices//,/|}}" ;;
                    flag)  meta="" ;;
                esac

                sgnd_print_labeledvalue "$opt$meta" "${_sgnd_help:-}" --pad "$_text_indent" --textclr "$RESET" --valueclr "$RESET" --width 18
            done
        fi

        if (( include_builtins )); then
            if declare -p SGND_BUILTIN_ARGS >/dev/null 2>&1; then
                sgnd_print
                sgnd_print_sectionheader --text "Builtin options:" --padleft "$_header_indent"

                local spec opt meta

                for spec in "${SGND_BUILTIN_ARGS[@]}"; do
                    _sgnd_arg_split "$spec"

                    # Skip malformed/empty spec entries
                    [[ -n "${_sgnd_name:-}" && -n "${_sgnd_type:-}" && -n "${_sgnd_var:-}" ]] || continue

                    # Avoid duplicating help line (already printed above)
                    if [[ "${_sgnd_name}" == "help" ]]; then
                        continue
                    fi

                    if [[ -n "${_sgnd_short:-}" ]]; then
                        opt="-$_sgnd_short, --$_sgnd_name"
                    else
                        opt="--$_sgnd_name"
                    fi

                    meta=""
                    case "$_sgnd_type" in
                        value) meta=" VALUE" ;;
                        enum)  meta=" {${_sgnd_choices//,/|}}" ;;
                        flag)  meta="" ;;
                    esac

                    sgnd_print_labeledvalue "$opt$meta" "${_sgnd_help:-}" --pad "$_text_indent" --textclr "$RESET" --valueclr "$RESET" --width 18
                done
            fi 
        fi

        local -a examples=()

        if (( include_builtins )) && 
            declare -p SGND_BUILTIN_EXAMPLES >/dev/null 2>&1 && 
            declare -p SGND_SCRIPT_EXAMPLES  >/dev/null 2>&1; then
                sgnd_array_union examples SGND_SCRIPT_EXAMPLES SGND_BUILTIN_EXAMPLES
        elif (( include_builtins )) && declare -p SGND_BUILTIN_EXAMPLES >/dev/null 2>&1; then
            examples=( "${SGND_BUILTIN_EXAMPLES[@]}" )
        elif declare -p SGND_SCRIPT_EXAMPLES >/dev/null 2>&1; then
           examples=( "${SGND_SCRIPT_EXAMPLES[@]}" )
        fi

        if (( ${#examples[@]} > 0 )); then
            sgnd_print
            sgnd_print_sectionheader --text "Examples:" --padleft "$_header_indent"

            local ex
            for ex in "${examples[@]}"; do
                sgnd_print "$spaces$ex"
            done
        fi
        
        sgnd_print
        sgnd_print_sectionheader
    }
    # fn: sgnd_parse_args - Parse args
        # . Purpose
        #   Parse command-line options according to SGND_ARG_SPEC and dispatch built-in argument handlers.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #   $2  ARG2 - Positional value used by this function.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_parse_args "${ARG1}" "${ARG2}"
    sgnd_parse_args() {

        local stop_at_unknown=0

        # Optional mode switch
        if [[ "${1-}" == "--stop-at-unknown" ]]; then
            stop_at_unknown=1
            shift
        fi

        # Default parse source (kept for compatibility if you still use it)
        local source="${SGND_ARGS_SOURCE:-both}"

        # Reset positional array
        SGND_POSITIONAL=()

        # Initialize variables from spec defaults
        _sgnd_arg_init_defaults "$source"

        # Main parse loop
        while [[ $# -gt 0 ]]; do
            saydebug "Parsing argument $1"
            case "$1" in

                # Explicit end-of-options marker
                --)
                    shift
                    SGND_POSITIONAL+=("$@")
                    break
                    ;;

                # Long option: --option
                --*)
                    local opt spec
                    opt="${1#--}"

                    spec="$(_sgnd_arg_find_spec "$opt" || true)"

                    if [[ -z "${spec:-}" ]]; then
                        if (( stop_at_unknown )); then
                            SGND_POSITIONAL+=("$@")
                            break
                        fi
                        echo "Unknown option: $1" >&2
                        return 1
                    fi

                    _sgnd_arg_split "$spec"

                    case "$_sgnd_type" in
                        flag)
                            printf -v "$_sgnd_var" '1'
                            shift
                            ;;

                        value)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for --$opt" >&2
                                return 1
                            fi
                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        enum)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for --$opt" >&2
                                return 1
                            fi

                            if ! _sgnd_arg_validate_enum "$2" "${_sgnd_choices:-}"; then
                                echo "Invalid value '$2' for --$opt (allowed: ${_sgnd_choices:-<none>})" >&2
                                return 1
                            fi

                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        *)
                            echo "Invalid spec type '$_sgnd_type' for --$opt" >&2
                            return 1
                            ;;
                    esac
                    ;;

                # Short option: -o
                -?*)
                    local sopt spec
                    sopt="${1#-}"

                    # Only single short options supported
                    if [[ "${#sopt}" -ne 1 ]]; then
                        echo "Unknown option: $1" >&2
                        return 1
                    fi

                    spec="$(_sgnd_arg_find_spec "$sopt" || true)"

                    if [[ -z "${spec:-}" ]]; then
                        if (( stop_at_unknown )); then
                            SGND_POSITIONAL+=("$@")
                            break
                        fi
                        echo "Unknown option: $1" >&2
                        return 1
                    fi

                    _sgnd_arg_split "$spec"

                    case "$_sgnd_type" in
                        flag)
                            printf -v "$_sgnd_var" '1'
                            shift
                            ;;

                        value)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for -$sopt" >&2
                                return 1
                            fi
                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        enum)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for -$sopt" >&2
                                return 1
                            fi

                            if ! _sgnd_arg_validate_enum "$2" "${_sgnd_choices:-}"; then
                                echo "Invalid value '$2' for -$sopt (allowed: ${_sgnd_choices:-<none>})" >&2
                                return 1
                            fi

                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        *)
                            echo "Invalid spec type '$_sgnd_type' for -$sopt" >&2
                            return 1
                            ;;
                    esac
                    ;;

                # Positional or first unknown
                *)
                    SGND_POSITIONAL+=("$@")
                    break
                    ;;
            esac
        done

        return 0
    }
    # fn: sgnd_builtinarg_handler - Builtinarg handler
        # . Purpose
        #   Handle built-in framework options such as help, debug, verbose, dry-run, logfile, and UI mode.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_builtinarg_handler
    sgnd_builtinarg_handler(){
        local show_target="${ARG_SHOW:-}"
        local loglevel="${ARG_LOGLEVEL:-}"

        if (( ${FLAG_LOG:-0} )); then
            SGND_LOGFILE_ENABLED=1
        fi

        # Apply an explicit CLI loglevel without resetting a bootstrap/script default.
        case "$loglevel" in
            silent|quiet|normal|verbose|debug|trace)
                SGND_LOG_LEVEL="$loglevel"
                ;;
        esac

        # Info-only builtins: perform action and EXIT.
        if (( FLAG_HELP )); then
            sgnd_show_help
            sayend "Information displayed"
            exit 0
        fi

        case "$show_target" in
            args)
                sgnd_print_args
                sayend "Information displayed"
                exit 0
                ;;
            meta)
                sgnd_print_metadata
                sgnd_print
                sgnd_print_framework_metadata
                sayend "Information displayed"
                exit 0
                ;;
            cfg)
                sgnd_print_sectionheader --text "Script configuration ($SGND_SCRIPT_NAME.cfg)"
                sgnd_print_cfg SGND_SCRIPT_GLOBALS both
                sgnd_print_sectionheader --border "-" --text "Framework configuration ($SGND_FRAMEWORK_CFG_BASENAME)"
                sgnd_print_cfg SGND_FRAMEWORK_GLOBALS both
                sayend "Information displayed"
                exit 0
                ;;
            state)
                sgnd_print_state
                sayend "Information displayed"
                exit 0
                ;;
            env)
                sgnd_showenvironment
                sayend "Information displayed"
                exit 0
                ;;
            license)
                saydebug "Showing license as requested"
                sgnd_print_license
                sayend "Information displayed"
                exit 0
                ;;
            readme)
                saydebug "Showing README as requested"
                sgnd_print_readme
                sayend "Information displayed"
                exit 0
                ;;
            "")
                ;;
            *)
                sayfail "Unknown show target: $show_target"
                return 1
                ;;
        esac

        # Mutating builtins: perform action and CONTINUE.
        if (( FLAG_STATERESET )); then
            if (( FLAG_DRYRUN )); then
                sayinfo "Would have reset state file."
            else
                sgnd_state_reset
                sayinfo "State file reset as requested."
            fi
        fi
    }





