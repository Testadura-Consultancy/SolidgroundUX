#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Documentation Generator Script
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2620309
#   Checksum    : eedf72bf4022604507835dbf90dd62abd32f86ff9857981c48a15cefadccb320
#   Source      : doc-generator.sh
#   Type        : script
#   Group       : SDK Documentation
#   Purpose     : Collect and prepare documentation data from source files using the SolidGroundUX framework.
#
# Description:
#   Provides the executable entry point for documentation data collection.
#
#   The script:
#     - Bootstraps the SolidGroundUX runtime
#     - Resolves source and output parameters from arguments, state, or user input
#     - Collects normalized documentation data from matching source files
#     - Exports parser output and invokes the renderer pipeline
#
# Design principles:
#   - Collection logic is kept separate from rendering logic
#   - Script behavior is deterministic and state-aware
#   - Framework conventions are reused wherever possible
#   - Interactive prompting remains optional rather than mandatory
#
# Role in framework:
#   - Executable entry point for documentation collection workflows
#   - Demonstrates canonical integration with sgnd-bootstrap and common libraries
#   - Bridges bootstrap, state, argument parsing, and collector execution
#
# Non-goals:
#   - Rendering output without the renderer component
#   - Parsing arbitrary free-form comments outside framework conventions
#   - Replacing the lower-level parser libraries
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# --- Bootstrap ----------------------------------------------------------------------
    # fn: _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Purpose
        #   Locate, create, and load the SolidGroundUX bootstrap configuration, then
        #   load the executable runtime support library.
        #
        # . Behavior
        #   - Searches user and system bootstrap configuration locations.
        #   - Prefers the invoking user's config over the system config.
        #   - Creates a new bootstrap config when none exists.
        #   - Prompts for framework/application roots in interactive mode.
        #   - Applies default values when running non-interactively.
        #   - Sources the selected bootstrap configuration file.
        #   - Loads sgnd-exe-common.sh from the resolved framework root.
        #
        # . Globals (write)
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # . Output
        #   Writes primitive printf-based messages before the framework UI is available.
        #
        # . Returns
        #   0 when the bootstrap configuration and executable common library were loaded.
        #   126 when configuration or executable common library is unreadable or invalid.
        #   127 when the configuration directory or file could not be created.
        #
        # . Usage
        #   _framework_locator || return $?
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
        #   - This function intentionally uses printf rather than say* helpers because
        #     the executable common library has not been loaded yet.
    _framework_locator() {
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply=""

        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"

        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"

        else
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            if [[ -t 0 && -t 1 ]]; then
                printf '%s\n' "SolidGroundUX bootstrap configuration" >&2
                printf '%s\n' "No configuration file found." >&2
                printf '%s\n' "Creating: $cfg" >&2

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_FRAMEWORK_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) printf '%s\n' "ERR: SGND_APPLICATION_ROOT must be an absolute path" >&2; return 126 ;;
            esac

            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            printf '%s\n' "Created bootstrap cfg: $cfg" >&2
        fi

        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"

            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            printf '%s\n' "Cannot read bootstrap cfg: $cfg" >&2
            return 126
        fi

        case "${SGND_LOG_LEVEL:-silent}" in
            silent|quiet)
                ;;
            *)
                printf '%s\n' "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT" >&2
                ;;
        esac

        local exe_common=""

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        fi

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# --- Script identity ----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# --- Framework integration ----------------------------------------------------------
    # var$ SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
        #
        # Example:
        #   SGND_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    SGND_USING=(
            doc-processor.sh
            doc-renderer.sh
            sgnd-datatable.sh
    )

    # SGND_ARGS_SPEC 
        # Optional: script-specific arguments
        # 
        # Each entry:
        #   "name|short|type|var|help|choices"
        #
        #   name    = long option name WITHOUT leading --
        #   short   - short option name WITHOUT leading -
        #   type    = flag | value | enum
        # var: = shell variable that will be set
        #   help    = help string for auto-generated --help output
        #   choices = for enum: comma-separated values (e.g. fast,slow,auto)
        #             for flag/value: leave empty
        #
        # Notes:
        #   - -h / --help is built in, you don't need to define it here.
        #   - After parsing you can use: FLAG_VERBOSE, VAL_CONFIG, ENUM_MODE, ...
    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO_RUN|Automatically run with last used or default parameters|0|"
        "clean|c|flag|FLAG_CLEAN_OUTPUT|Clear output directory before writing|0|"
        "file|f|value|VAL_FILESPEC|File mask for source scanning||"
        "outdir|o|value|VAL_OUTDIR|Output directory for generated docs||"
        "recursive|r|flag|FLAG_RECURSIVE_SCAN|Recursively scan source directory|1|"
        "srcdir|s|value|VAL_SRCDIR|Source directory to scan||"
        "review|v|flag|FLAG_REVIEW|Review assembled data|0|"
    )

    # SGND_SCRIPT_EXAMPLES
        # Optional: examples for --help output.
        # Each entry is a string that will be printed verbatim.
        #
        # Example:
        #   SGND_SCRIPT_EXAMPLES=(
        #       "Example usage:"
        #       "  script.sh --verbose --mode fast"
        #       "  script.sh -v -m slow"
        #   )
        #
        # Leave empty if no examples are needed.
    SGND_SCRIPT_EXAMPLES=(
        "Run in dry-run mode:"
        "  $SGND_SCRIPT_NAME --dryrun"
        ""
        "Show verbose logging"
        "  $SGND_SCRIPT_NAME --verbose"
    ) 

    # SGND_SCRIPT_GLOBALS
        # Explicit declaration of global variables intentionally used by this script.
        #
        # . Purpose
        #   - Declares which globals are part of the script’s public/config contract.
        #   - Enables optional configuration loading when non-empty.
        #
        # . Behavior
        #   - If this array is non-empty, sgnd_bootstrap enables config integration.
        #   - Variables listed here may be populated from configuration files.
        #   - Unlisted globals will NOT be auto-populated.
        #
        # Use this to:
        #   - Document intentional globals
        #   - Prevent accidental namespace leakage
        #   - Make configuration behavior explicit and predictable
        #
        # Only list:
        #   - Variables that must be globally accessible
        #   - Variables that may be defined in config files
        #
        # Leave empty if:
        #   - The script does not use configuration-driven globals
    SGND_SCRIPT_GLOBALS=(
    )

    # SGND_STATE_VARIABLES
        # List of variables participating in persistent state.
        #
        # . Purpose
        #   - Declares which variables should be saved/restored when state is enabled.
        #
        # . Behavior
        #   - Only used when sgnd_bootstrap is invoked with --state.
        #   - Variables listed here are serialized on exit (if SGND_STATE_SAVE=1).
        #   - On startup, previously saved values are restored before main logic runs.
        #
        # Contract:
        #   - Variables must be simple scalars (no arrays/associatives unless explicitly supported).
        #   - Script remains fully functional when state is disabled.
        #
        # Leave empty if:
        #   - The script does not use persistent state.
    SGND_STATE_VARIABLES=(
        "VAL_SRCDIR|Source Directory||"
        "VAL_FILESPEC|Filename mask||"
        "VAL_OUTDIR|Output Directory||"
        "FLAG_RECURSIVE_SCAN|Recursive Scan||"
        "FLAG_CLEAN_OUTPUT|Clean Output Directory||"
        "FLAG_REVIEW|Automatically open generated docs in browser after generation (desktop mode only)||"
        "VAL_DOCUMENT_TITLE|Document title||"
        "VAL_DOCUMENT_SUBTITLE|Document subtitle||"
        "VAL_DOCUMENT_VERSION|Document version||"
        "VAL_DOCUMENT_PRODUCT|Document product name||"
    )

    # SGND_ON_EXIT_HANDLERS
        # List of functions to be invoked on script termination.
        #
        # . Purpose
        #   - Allows scripts to register cleanup or finalization hooks.
        #
        # . Behavior
        #   - Functions listed here are executed during framework exit handling.
        #   - Execution order follows array order.
        #   - Handlers run regardless of normal exit or controlled termination.
        #
        # Contract:
        #   - Functions must exist before exit occurs.
        #   - Handlers must not call exit directly.
        #   - Handlers should be idempotent (safe if executed once).
        #
        # Typical uses:
        #   - Cleanup temporary files
        #   - Persist additional state
        #   - Release locks
        #
        # Leave empty if:
        #   - No custom exit behavior is required.
    SGND_ON_EXIT_HANDLERS=(
    )
    
    # State persistence is opt-in.
        # Scripts that want persistent state must:
        #   1) set SGND_STATE_SAVE=1
        #   2) call sgnd_bootstrap --state
    SGND_STATE_SAVE=1


# --- Local script functions ----------------------------------------------------------
    # fn: _init_parameters - Initialize documentation generator parameters
        # . Purpose
        #   Initialize parameter variables from defaults when still unset.
        #
        # . Behavior
        #   - Preserves values already supplied through parsed arguments or restored state.
        #   - Applies default values only where variables are unset or empty.
        #   - Does not validate or interpret parameter values.
        #   - Does not override explicit user input.
        #   - Does not perform interactive prompting.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _init_parameters
        #
        # Examples:
        #   _init_parameters
    _init_parameters() {
        sgnd_internal_call_guard "_init_parameters"
        saydebug "Initializing parameters with defaults where not set by arguments"

        FLAG_AUTO_RUN="${FLAG_AUTO_RUN:-0}"
        FLAG_CLEAN_OUTPUT="${FLAG_CLEAN_OUTPUT:-1}"
        FLAG_RECURSIVE_SCAN="${FLAG_RECURSIVE_SCAN:-1}"
        FLAG_VIEW_RESULTS="${FLAG_VIEW_RESULTS:-1}"

        VAL_FILESPEC="${VAL_FILESPEC:-*.sh}"
        VAL_OUTDIR="${VAL_OUTDIR:-$SGND_DOCS_DIR}"
        VAL_SRCDIR="${VAL_SRCDIR:-$SGND_APPLICATION_ROOT}"

        VAL_DOCUMENT_TITLE="${VAL_DOCUMENT_TITLE:-${SGND_PRODUCT:-}, Full Development Documentation}"
        VAL_DOCUMENT_SUBTITLE="${VAL_DOCUMENT_SUBTITLE:-}"
        VAL_DOCUMENT_VERSION="${VAL_DOCUMENT_VERSION:-${SGND_VERSION:-}}"
        VAL_DOCUMENT_PRODUCT="${VAL_DOCUMENT_PRODUCT:-${SGND_PRODUCT:-}}"

   
    }

    # fn: _get_userinput - Collect documentation generator input
        # . Purpose
        #   Interactively collect and confirm documentation generator parameters.
        #
        # . Behavior
        #   - Displays grouped prompts for source, destination, and behavioral flags.
        #   - Applies validation to supported fields.
        #   - Normalizes Y/N replies into numeric flag values.
        #   - Repeats until the user confirms, cancels, or requests redo.
        #
        # Outputs (globals):
        #   VAL_SRCDIR
        #   VAL_FILESPEC
        #   VAL_OUTDIR
        #   FLAG_CLEAN_OUTPUT
        #   FLAG_RECURSIVE_SCAN
        #   FLAG_VIEW_RESULTS
        #   SGND_STATE_SAVE
        #
        # . Returns
        #   0 on confirmed input.
        #   1 if the user cancels or an unexpected dialog result occurs.
        #
        # . Usage
        #   _get_userinput || return $?
        #
        # Examples:
        #   _get_userinput
    _get_userinput() {
        local lw=25
        local lp=4
        local default="N"
        local reply
    
        while true; do
            sgnd_print
            sgnd_print_sectionheader "Source and destination" --padend 0

            # Basic parameters
            ask --label "Source directory" \
                --var VAL_SRCDIR \
                --default "$VAL_SRCDIR" \
                --validate sgnd_validate_dir_exists \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Source file" \
                --var VAL_FILESPEC \
                --default "$VAL_FILESPEC" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Output directory" \
                --var VAL_OUTDIR \
                --default "$VAL_OUTDIR" \
                --validate sgnd_validate_dir_exists \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            
            sgnd_print
            sgnd_print_sectionheader "Behavioral flags" --padend 0
            lw=45
            (( ${FLAG_CLEAN_OUTPUT:-0} )) && default="Y" || default="N"
            ask --label "Clean output directory before writing (Y/N)" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_CLEAN_OUTPUT=1 || FLAG_CLEAN_OUTPUT=0

            (( ${FLAG_RECURSIVE_SCAN:-0} )) && default="Y" || default="N"
            ask --label "Scan recursively" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_RECURSIVE_SCAN=1 || FLAG_RECURSIVE_SCAN=0
        
            (( ${FLAG_REVIEW:-0} )) && default="Y" || default="N"
            ask --label "View parsed data" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_REVIEW=1 || FLAG_REVIEW=0

            sgnd_print
            sgnd_print_sectionheader "Documentation metadata" --padend 0
            ask --label "Document title" \
                --var VAL_DOCUMENT_TITLE \
                --default "$VAL_DOCUMENT_TITLE" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Document subtitle" \
                --var VAL_DOCUMENT_SUBTITLE \
                --default "$VAL_DOCUMENT_SUBTITLE" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Document version" \
                --var VAL_DOCUMENT_VERSION \
                --default "$VAL_DOCUMENT_VERSION" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Document product name" \
                --var VAL_DOCUMENT_PRODUCT \
                --default "$VAL_DOCUMENT_PRODUCT" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            (( ${SGND_STATE_SAVE:-0} )) && default="Y" || default="N"
            ask --label "Save these answers" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && SGND_STATE_SAVE=1 || SGND_STATE_SAVE=0

            # Confirmation
            sgnd_print_sectionheader #--maxwidth "$(( lw + 5 ))"
            sgnd_print
            ask_dlg_autocontinue --seconds 15 --message "Continue with these settings?" --redo --cancel --pause

            case $? in
                0|1) break ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                3) continue ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac

            sgnd_showenvironment
        done
    }

    # fn: _iterate_files - Iterate source files and collect documentation data
        # . Purpose
        #   Iterate over files in a directory using a file mask,
        #   optionally recursing into subdirectories.
        #
        # . Behavior
        #   - Expands file_spec within source_dir
        #   - Supports recursive and non-recursive modes
        #   - Calls a callback function for each matched file
        #   - Skips non-regular files
        #
        # . Arguments
        #   $1  SOURCE_DIR
        #   $2  FILE_SPEC
        #   $3  FLAG_RECURSIVE   (0 = no recursion, 1 = recursive)
        #   $4  CALLBACK_FUNC
        #
        # . Returns
        #   0 on success
        #   1 on invalid input
        #
        # . Usage
        #   _iterate_files "./src" "*.sh" 1 sgnd_doc_process_file
    # fn: _doc_progress_line - Update active-module line progress
        # . Purpose
        #   Update progress slot 1 for the line currently being parsed inside the
        #   active module.
        #
        # . Behavior
        #   - Intended to be called by the parser while it walks the current file.
        #   - Uses globals prepared by _iterate_files.
        #   - Does nothing when documentation progress is not active.
        #
        # . Arguments
        #   $1  CURRENT_LINE
        #   $2  TOTAL_LINES     optional; defaults to SGND_DOC_PROGRESS_LINE_TOTAL
        #   $3  LABEL           optional; defaults to SGND_DOC_PROGRESS_MODULE_NAME
        #
        # . Usage
        #   _doc_progress_line "$line_no" "$line_total" "$module_name"
    _doc_progress_line() {
        (( ${SGND_DOC_PROGRESS_ACTIVE:-0} )) || return 0

        local current="${1:-0}"
        local total="${2:-${SGND_DOC_PROGRESS_LINE_TOTAL:-1}}"
        local name="${3:-${SGND_DOC_PROGRESS_MODULE_NAME:-}}"
        local module_current="${SGND_DOC_PROGRESS_MODULE_CURRENT:-0}"
        local module_total="${SGND_DOC_PROGRESS_MODULE_TOTAL:-0}"

        (( total > 0 )) || total=1
        (( current < 0 )) && current=0
        (( current > total )) && current="$total"

        sayprogress \
            --slot 0 \
            --current "$current" \
            --total "$total" \
            --label "Module ${module_current}/${module_total}: $name" \
            --type 5 \
            --padleft 0
            
    }

    # fn: _doc_count_lines - Count physical lines in a file
        # . Purpose
        #   Return the number of lines in a regular file.
        #
        # . Arguments
        #   $1  FILE
        #
        # . Outputs
        #   Prints the line count to stdout.
    _doc_count_lines() {
        local file="$1"
        local count=0

        [[ -f "$file" ]] || { printf '%s\n' 0; return 0; }

        count="$(wc -l < "$file")"
        count="${count//[[:space:]]/}"
        printf '%s\n' "${count:-0}"
    }

    # fn: _iterate_files - Iterate source files and collect documentation data
        # . Purpose
        #   Iterate over files in a directory using a file mask,
        #   optionally recursing into subdirectories.
        #
        # . Behavior
        #   - Expands file_spec within source_dir.
        #   - Supports recursive and non-recursive modes.
        #   - Shows two-level progress:
        #       slot 0 = module/file progress
        #       slot 1 = line progress inside the active module
        #   - Calls a callback function for each matched file.
        #   - Skips non-regular files.
        #
        # . Arguments
        #   $1  SOURCE_DIR
        #   $2  FILE_SPEC
        #   $3  FLAG_RECURSIVE   (0 = no recursion, 1 = recursive)
        #   $4  CALLBACK_FUNC
        #
        # . Returns
        #   0 on success
        #   1 on invalid input
        #
        # . Usage
        #   _iterate_files "./src" "*.sh" 1 _parse_module_file
    _iterate_files() {
        local source_dir="$1"
        local file_spec="$2"
        local recursive="$3"
        local callback="$4"

        [[ -z "$source_dir" || -z "$file_spec" || -z "$callback" ]] && return 1
        [[ -d "$source_dir" ]] || return 1
        declare -F "$callback" >/dev/null || return 1

        local -a files=()
        local file=""
        local name=""
        local files_ttl=0
        local files_proc=0
        local line_total=0

        if (( recursive == 0 )); then
            shopt -s nullglob

            for file in "$source_dir"/$file_spec; do
                [[ -f "$file" ]] || continue
                files+=("$file")
            done

            shopt -u nullglob
        else
            while IFS= read -r -d '' file; do
                [[ -f "$file" ]] || continue
                files+=("$file")
            done < <(
                find "$source_dir" -type f -name "$file_spec" -print0
            )
        fi

        files_ttl="${#files[@]}"
        (( files_ttl > 0 )) || return 0

        sgnd_print
        sayprogress_begin --slots 1

        SGND_DOC_PROGRESS_ACTIVE=1
        SGND_DOC_PROGRESS_MODULE_TOTAL="$files_ttl"

        for file in "${files[@]}"; do
            ((files_proc++))

            name="${file##*/}"
            line_total="$(_doc_count_lines "$file")"
            (( line_total > 0 )) || line_total=1

            SGND_DOC_PROGRESS_MODULE_CURRENT="$files_proc"
            SGND_DOC_PROGRESS_MODULE_NAME="$name"
            SGND_DOC_PROGRESS_LINE_TOTAL="$line_total"

            # Initialize the bar for the new module.
            _doc_progress_line 0 "$line_total" "$name"

            "$callback" "$file" ||
                saywarning "Callback $callback failed for file: $file"

            # Ensure that the module ends visibly at 100%.
            _doc_progress_line "$line_total" "$line_total" "$name"
        done

        SGND_DOC_PROGRESS_ACTIVE=0
        SGND_DOC_PROGRESS_MODULE_CURRENT=0
        SGND_DOC_PROGRESS_MODULE_TOTAL=0
        SGND_DOC_PROGRESS_MODULE_NAME=""
        SGND_DOC_PROGRESS_LINE_TOTAL=0

        sayprogress_done
        return 0
    }

    # fn: _summary - Print documentation generation summary
        # . Purpose
        #   Generate a summary of the documentation data collected.
        #
        # . Behavior
        #   - Aggregates key metadata from processed modules and items.
        #   - Prints a concise summary to the console for review.
        #
        # . Usage
        #   _summary
    _summary() {
        local module_count
        local item_count
        sgnd_print
        sgnd_print_sectionheader "Documentation Summary" --padend 1
        sgnd_print
        sgnd_print  "  Modules processed: ${#MOD_TABLE[@]}"
        sgnd_print  "  Sections processed: ${#MOD_SECTIONS[@]}"
        sgnd_print  "  Items documented: ${#MOD_ITEMS[@]}"
        sgnd_print  "  Comments extracted: ${#DOC_CONTENT_LINES[@]}"
        sgnd_print
        sgnd_print "  Source directory: $VAL_SRCDIR"
        sgnd_print "  Output directory: $VAL_OUTDIR"
        sgnd_print
        sgnd_print "  Starttime: $(date -d "@$main_start" '+%H:%M:%S')"
        sgnd_print "  Endtime:   $(date -d "@$end_time" '+%H:%M:%S')"
        local duration=$(( end_time - main_start ))
        local duration_text
        printf -v duration_text '%02d:%02d:%02d' \
            $(( duration / 3600 )) \
            $(( (duration % 3600) / 60 )) \
            $(( duration % 60 ))
        sgnd_print "  Duration:  $duration_text"
        sgnd_print
        sgnd_print_sectionheader "" --padend 1
        sgnd_print

    }
# --- Main ---------------------------------------------------------------------------
    # fn: main - Run the executable main sequence - Run the executable main sequence
        # . Purpose
        #   Provide the canonical executable entry point for the documentation generator.
        #
        # . Behavior
        #   - Loads the framework bootstrapper.
        #   - Initializes the runtime through sgnd_bootstrap.
        #   - Processes built-in framework arguments.
        #   - Prepares UI state and title bar output.
        #   - Initializes script parameters from defaults, state, and arguments.
        #   - Prompts for interactive input when auto-run is not enabled.
        #   - Hands off control to the script's main logic.
        #
        # . Arguments
        #   $@  Command-line arguments (framework and script-specific).
        #
        # . Returns
        #   0  on success.
        #   Non-zero on bootstrap, input, or script failure.
        #
        # . Usage
        #   main "$@"
        #
        # Examples:
        #   main "$@"
        #
        # Notes:
        #   - sgnd_bootstrap separates framework arguments from script arguments.
        #   - This function is script-owned orchestration logic, not template-only scaffolding.
    main() {
        # -- Startup
            _framework_locator || exit $?
            sgnd_exe_start --autostate -- "$@"

        # -- Main script logic
        
        # Initialize parameters with defaults where not set by arguments or state
        _init_parameters

        # Prompt for user input if not auto-running  
        if (( !FLAG_AUTO_RUN )); then      
            _get_userinput || return $?
        fi

        local start_time
        local display_time
        start_time="$(date +%s)"
        local main_start="$start_time"

        display_time="$(date +%H:%M:%S)"
        saystart "Documentation generation started at $display_time"

        _iterate_files "$VAL_SRCDIR" "$VAL_FILESPEC" "$FLAG_RECURSIVE_SCAN" _parse_module_file

        local end_time
        end_time="$(date +%s)"

        display_time="$(date +%H:%M:%S)"
        sayok "Done parsing source files (duration: $(( end_time - start_time )) seconds)"

        if (( FLAG_REVIEW )); then
            sgnd_dt_print_table "$MOD_TABLE_SCHEMA" MOD_TABLE 1
            sgnd_dt_print_table "$MOD_ATTRIBUTION_SCHEMA" MOD_ATTRIBUTION  1  
            sgnd_dt_print_table "$MOD_SECTIONS_SCHEMA" MOD_SECTIONS  1  
            sgnd_dt_print_table "$MOD_ITEMS_SCHEMA" MOD_ITEMS  1  

            ask_dlg_autocontinue \
               --seconds 15 \
               --message "Parsing complete continue with documentation generation ?" \
               --cancel \
               --pause \
               --anykey
        fi
        
        if (( FLAG_REVIEW )); then
           sgnd_dt_print_table "$DOC_CONTENT_LINES_SCHEMA" DOC_CONTENT_LINES 1
        fi

        if (( FLAG_DRYRUN )); then
            sayinfo "Would have rendered site to $VAL_OUTDIR"
        else
            #_render_site "$VAL_OUTDIR"
            saystart "Rendering html documentation"
            start_time="$(date +%s)"

            _render_site "$VAL_OUTDIR"

            end_time="$(date +%s)"
            sayok "Done rendering documentation hierarchy (duration: $(( end_time - start_time )) seconds)"
        fi

        end_time="$(date +%s)"
        display_time="$(date +%H:%M:%S)"

        _summary
        
        sayend "Documentation generation completed successfully at $display_time (duration: $(( end_time - main_start )) seconds)"
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
