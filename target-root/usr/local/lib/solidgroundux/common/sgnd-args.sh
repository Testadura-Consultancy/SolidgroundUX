# =====================================================================================
# SolidgroundUX - Argument Parsing
# -------------------------------------------------------------------------------------
# Metadata: 
#   Version     : 1.1
#   Build       : 2608203
#   Checksum    : 8514965960d1becba4459cc212b011b1bd6e9b51a2d41a9570cba36ff0e9354d
#   Source      : sgnd-args.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Parse and manage command-line arguments for scripts
#
# Description:
#   Provides a structured argument parsing system for SolidgroundUX scripts.
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

# --- Helper functions ----------------------------------------------------------------
    # _sgnd_arg_split
        # Purpose:
        #   Split a single SGND_ARGS_SPEC definition into internal scratch variables.
        #
        # Behavior:
        #   - Reads one pipe-delimited spec string.
        #   - Assigns each field to the corresponding _sgnd_* scratch variable.
        #   - Performs parsing only; does not validate semantic correctness.
        #
        # Arguments:
        #   $1  SPEC
        #       SGND_ARGS_SPEC entry in the format:
        #       "name|short|type|var|help|choices"
        #
        # Outputs (globals):
        #   _sgnd_name
        #   _sgnd_short
        #   _sgnd_type
        #   _sgnd_var
        #   _sgnd_help
        #   _sgnd_choices
        #
        # Side effects:
        #   - Overwrites the current _sgnd_* scratch field variables.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_arg_split "$spec"
        #
        # Examples:
        #   _sgnd_arg_split "config|c|value|CFG_FILE|Config file path|"
        #   printf '%s\n' "$_sgnd_var"
        #
        # Notes:
        #   - Intended as an internal helper for spec-driven parsing.
    _sgnd_arg_split() {
        local spec="$1"
        IFS='|' read -r _sgnd_name _sgnd_short _sgnd_type _sgnd_var _sgnd_help _sgnd_default _sgnd_choices <<< "$spec"
    }

    # _sgnd_arg_find_spec
        # Purpose:
        #   Find the effective argument specification that matches a long or short option token.
        #
        # Behavior:
        #   - Iterates over SGND_EFFECTIVE_ARGS_SPEC in order.
        #   - Splits each spec entry into scratch fields.
        #   - Matches against either the long name or short name.
        #   - Prints the full matching spec line when found.
        #
        # Arguments:
        #   $1  TOKEN
        #       Option token without leading dashes:
        #       - "config" for --config
        #       - "c"      for -c
        #
        # Inputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC
        #
        # Output:
        #   Prints the matching full spec line to stdout.
        #
        # Side effects:
        #   - Updates _sgnd_* scratch variables while scanning.
        #
        # Returns:
        #   0 if a matching spec is found.
        #   1 if no matching spec exists.
        #
        # Usage:
        #   spec="$(_sgnd_arg_find_spec "config")"
        #
        # Examples:
        #   spec="$(_sgnd_arg_find_spec "c")" || return 1
        #   _sgnd_arg_split "$spec"
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
    
    # _sgnd_arg_validate_enum
        # Purpose:
        #   Validate whether a value is present in a comma-separated enum choice list.
        #
        # Behavior:
        #   - Splits the supplied CSV string into individual allowed values.
        #   - Compares the requested value against each entry.
        #   - Succeeds on the first exact match.
        #
        # Arguments:
        #   $1  VALUE
        #       Value to validate.
        #   $2  CHOICES_CSV
        #       Comma-separated allowed values (for example: "dev,prd").
        #
        # Returns:
        #   0 if VALUE is allowed.
        #   1 if VALUE is not found in CHOICES_CSV.
        #
        # Usage:
        #   _sgnd_arg_validate_enum "$mode" "dev,prd,tst"
        #
        # Examples:
        #   if _sgnd_arg_validate_enum "$2" "${_sgnd_choices:-}"; then
        #       printf 'valid\n'
        #   fi
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

    # _sgnd_arg_init_defaults
        # Purpose:
        #   Initialize option variables and build the effective argument specification list.
        #
        # Behavior:
        #   - Selects argument specs from SGND_BUILTIN_ARGS, SGND_ARGS_SPEC, or both.
        #   - Initializes each declared option variable according to its type:
        #       flag  -> spec default or 0
        #       value -> spec default or ""
        #       enum  -> spec default or ""
        #   - Rebuilds SGND_EFFECTIVE_ARGS_SPEC in parse order.
        #
        # Arguments:
        #   $1  SOURCE
        #       Spec source selector:
        #       builtins | script | both
        #       Default: both
        #
        # Inputs (globals):
        #   SGND_BUILTIN_ARGS
        #   SGND_ARGS_SPEC
        #
        # Outputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC
        #
        # Side effects:
        #   - Creates or resets variables declared in the selected spec set.
        #   - Overwrites SGND_EFFECTIVE_ARGS_SPEC.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   _sgnd_arg_init_defaults "both"
        #
        # Examples:
        #   _sgnd_arg_init_defaults "script"
        #   _sgnd_arg_init_defaults "${SGND_ARGS_SOURCE:-both}"
        #
        # Notes:
        #   - Re-running the function resets declared option variables to their defaults.
        #   - Does not validate spec correctness beyond presence of type and variable name.
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
    _header_indent=2
    _text_indent=3

    # Global Arrays
    SGND_BUILTIN_ARGS=(
        "dryrun|D|flag|FLAG_DRYRUN|Emulate only; do not perform actions|"
        "debug||flag|FLAG_DEBUG|Show debug messages|"
        "help|H|flag|FLAG_HELP|Show command-line help and exit|"
        "quiet|Q|flag|FLAG_QUIET|Suppress non-error output|"
        "showargs|A|flag|FLAG_SHOWARGS|Print parsed arguments and exit|"
        "showcfg|C|flag|FLAG_SHOWCFG|Print configuration values and exit|"
        "showenv|E|flag|FLAG_SHOWENV|Print all info (args, cfg, state) and exit|"
        "showmeta|M|flag|FLAG_SHOWMETA|Shows framework and script metadata and exit|"
        "showstate|S|flag|FLAG_SHOWSTATE|Print state values and exit|"
        "showlicense|L|flag|FLAG_SHOWLICENSE|Show framework license and exit|"
        "showreadme||flag|FLAG_SHOWREADME|Show framework README and exit|"
        "statereset|R|flag|FLAG_STATERESET|Reset the state file|"
        "verbose|V|flag|FLAG_VERBOSE|Enable verbose output|"
    )

    SGND_BUILTIN_EXAMPLES=(
         "  ${SGND_SCRIPT_NAME:-<script>} --dryrun --verbose"
    ) 

    # sgnd_show_help
        # Purpose:
        #   Render and display the generated help text for the current script.
        #
        # Behavior:
        #   - Builds help output from the active argument specification set.
        #   - Includes built-in arguments when configured to do so.
        #   - Renders usage, option descriptions, and related help sections.
        #   - Prints the final help text to stdout.
        #
        # Inputs (globals):
        #   SGND_SCRIPT_NAME
        #   SGND_SCRIPT_DESC
        #   SGND_ARGS_SPEC
        #   SGND_BUILTIN_ARGS
        #   SGND_ARGS_SOURCE
        #   SGND_EFFECTIVE_ARGS_SPEC
        #
        # Side effects:
        #   - Writes help text to stdout.
        #
        # Returns:
        #   0 always.
        #
        # Usage:
        #   sgnd_show_help
        #
        # Examples:
        #   sgnd_show_help
        #
        #   SGND_ARGS_SOURCE="both"
        #   sgnd_show_help
        #
        # Notes:
        #   - Intended for direct CLI help rendering.
        #   - Built-in options are only shown when included in the effective spec set.
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

    # sgnd_parse_args
        # Purpose:
        #   Parse command-line arguments according to the effective argument specification.
        #
        # Behavior:
        #   - Initializes option variables from the selected spec source.
        #   - Processes long and short options, including grouped short flags where supported.
        #   - Assigns values to the configured target variables.
        #   - Validates enum arguments against their declared choice list.
        #   - Collects positional arguments into SGND_POSITIONAL_ARGS.
        #   - Applies unknown-argument handling according to SGND_ARGMODE.
        #
        # Arguments:
        #   $@  ARGS
        #       Command-line arguments to parse.
        #
        # Inputs (globals):
        #   SGND_ARGS_SPEC
        #   SGND_BUILTIN_ARGS
        #   SGND_ARGS_SOURCE
        #   SGND_ARGMODE
        #
        # Outputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC
        #   SGND_POSITIONAL_ARGS
        #   Variables declared in the selected argument specs
        #
        # Side effects:
        #   - Resets declared argument variables to their default state before parsing.
        #   - Rebuilds SGND_EFFECTIVE_ARGS_SPEC.
        #   - Updates SGND_POSITIONAL_ARGS.
        #   - May print diagnostics for invalid or unknown arguments.
        #
        # Returns:
        #   0 if parsing succeeds.
        #   1 if parsing fails due to invalid input or strict-mode argument rejection.
        #
        # Usage:
        #   sgnd_parse_args "$@"
        #
        # Examples:
        #   sgnd_parse_args "$@"
        #
        #   SGND_ARGMODE="strict"
        #   sgnd_parse_args "$@" || return 1
        #
        #   SGND_ARGMODE="stop-at-unknown"
        #   sgnd_parse_args "$@"
        #
        # Notes:
        #   - The effective spec set is determined by SGND_ARGS_SOURCE.
        #   - Intended as the primary public entry point for argument parsing.
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

    # sgnd_builtinarg_handler
        # Purpose:
        #   Apply framework-defined built-in argument behavior after argument parsing.
        #
        # Behavior:
        #   - Evaluates built-in framework flags after sgnd_parse_args has populated them.
        #   - Applies common runtime settings such as debug, verbose, dryrun, and logging.
        #   - Handles immediate built-in actions such as help or version display when present.
        #   - Exits early when a built-in action fully satisfies program flow.
        #
        # Inputs (globals):
        #   Built-in argument variables initialized through SGND_BUILTIN_ARGS
        #   SGND_SCRIPT_NAME
        #   SGND_SCRIPT_VERSION
        #   SGND_LOGFILE_ENABLED
        #   SGND_LOG_TO_CONSOLE
        #
        # Side effects:
        #   - Updates framework runtime globals based on parsed built-in options.
        #   - May write informational output to stdout.
        #   - May terminate script execution early for handled built-in actions.
        #
        # Returns:
        #   0 if built-in handling succeeds.
        #
        # Usage:
        #   sgnd_parse_args "$@" || return 1
        #   sgnd_builtinarg_handler
        #
        # Examples:
        #   sgnd_parse_args "$@" || return 1
        #   sgnd_builtinarg_handler
        #
        #   sgnd_parse_args "$@" || exit 1
        #   sgnd_builtinarg_handler
        #   main
        #
        # Notes:
        #   - Intended to be called immediately after sgnd_parse_args.
        #   - Centralizes framework-level option behavior so scripts do not need to duplicate it.
    sgnd_builtinarg_handler(){
        # Info-only builtins: perform action and EXIT.
        if (( FLAG_HELP )); then
            sgnd_show_help
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_SHOWARGS )); then
            sgnd_print_args
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_SHOWMETA )); then
            sgnd_print_metadata
            sgnd_print
            sgnd_print_framework_metadata
            sayend "Information displayed"
            exit 0
        fi
        
        if (( FLAG_SHOWCFG )); then
            sgnd_print_sectionheader --text "Script configuration ($SGND_SCRIPT_NAME.cfg)"
            sgnd_print_cfg SGND_SCRIPT_GLOBALS both
            sgnd_print_sectionheader --border "-" --text "Framework configuration ($SGND_FRAMEWORK_CFG_BASENAME)"
            sgnd_print_cfg SGND_FRAMEWORK_GLOBALS both
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_SHOWSTATE )); then
            sgnd_print_state
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_SHOWENV )); then
            sgnd_showenvironment
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_SHOWLICENSE )); then
            saydebug "Showing license as requested"
            sgnd_print_license
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_SHOWREADME )); then
            saydebug "Showing README as requested"
            sgnd_print_readme
            sayend "Information displayed"
            exit 0
        fi

        if (( FLAG_QUIET )); then
            SGND_LOG_TO_CONSOLE=0
            saydebug "Quiet mode enabled; non-error output will be suppressed"
        else
            SGND_LOG_TO_CONSOLE=1
        fi

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





