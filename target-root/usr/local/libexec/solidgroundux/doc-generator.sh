#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Documentation Generator Script
# ------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : b12493bbf4f587df211e6d9d6a3f78e9f7a10fa279544c7c15cb24ad0ecdefc8
#   Source      : doc-generator.sh
#   Type        : script
#   Group       : SDK
#   Subgroup    : Documentation Generator
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
    # fn& _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
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
        "clear-render-cache||flag|FLAG_CLEAR_RENDER_CACHE|Clear cached renderer input before rebuilding it|0|"
        "copy-to-git||flag|FLAG_COPY_TO_GIT|Copy generated documentation to the Git repository docs directory|0|"
        "file|f|value|VAL_FILESPEC|Comma-separated file masks for source scanning||"
        "mode|m|enum|VAL_UPDATE_MODE|Generation mode: full, selected, changed, or render|full|full,selected,changed,render"
        "update-files|u|value|VAL_UPDATE_FILES|Comma-separated files for selected update mode||"
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
        "Full documentation rebuild:"
        "  $SGND_SCRIPT_NAME --mode full"
        ""
        "Update selected source files:"
        "  $SGND_SCRIPT_NAME --mode selected --update-files common/ui-say.sh,common/ui-ask.sh"
        ""
        "Update files changed in Git:"
        "  $SGND_SCRIPT_NAME --mode changed"
        ""
        "Render HTML again from the existing renderer cache:"
        "  $SGND_SCRIPT_NAME --mode render"
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
        "VAL_FILESPEC|Filename masks||"
        "VAL_UPDATE_MODE|Generation mode (full, selected, changed, render)||"
        "VAL_UPDATE_FILES|Selected update files||"
        "VAL_OUTDIR|Output Directory||"
        "FLAG_RECURSIVE_SCAN|Recursive Scan||"
        "FLAG_CLEAN_OUTPUT|Clean Output Directory||"
        "FLAG_CLEAR_RENDER_CACHE|Clear cached renderer input before rebuilding||"
        "FLAG_COPY_TO_GIT|Copy generated documentation to the Git repository docs directory||"
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
        FLAG_CLEAR_RENDER_CACHE="${FLAG_CLEAR_RENDER_CACHE:-0}"
        FLAG_COPY_TO_GIT="${FLAG_COPY_TO_GIT:-0}"
        FLAG_RECURSIVE_SCAN="${FLAG_RECURSIVE_SCAN:-1}"
        FLAG_VIEW_RESULTS="${FLAG_VIEW_RESULTS:-1}"

        VAL_FILESPEC="${VAL_FILESPEC:-*.sh,*.py}"
        VAL_UPDATE_MODE="${VAL_UPDATE_MODE:-full}"
        VAL_UPDATE_FILES="${VAL_UPDATE_FILES:-}"
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
            sgnd_print_sectionheader "Generation mode" --padend 0

            local mode_reply=""
            case "$VAL_UPDATE_MODE" in
                full)     mode_reply="1" ;;
                selected) mode_reply="2" ;;
                changed)  mode_reply="3" ;;
                render)   mode_reply="4" ;;
                *)        mode_reply="1" ;;
            esac

            while true; do
                ask --label "Mode: 1 Full, 2 Selected, 3 Changed, 4 Render existing data" \
                    --var mode_reply \
                    --default "$mode_reply" \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad "$lp" \
                    --labelwidth "$lw"

                case "$mode_reply" in
                    1) VAL_UPDATE_MODE="full"; break ;;
                    2) VAL_UPDATE_MODE="selected"; break ;;
                    3) VAL_UPDATE_MODE="changed"; break ;;
                    4) VAL_UPDATE_MODE="render"; break ;;
                    *) saywarning "Choose generation mode 1, 2, 3, or 4" ;;
                esac
            done

            if [[ "$VAL_UPDATE_MODE" == "selected" ]]; then
                ask --label "Files to update (comma-separated)" \
                    --var VAL_UPDATE_FILES \
                    --default "$VAL_UPDATE_FILES" \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad "$lp" \
                    --labelwidth "$lw"
            fi

            sgnd_print
            if [[ "$VAL_UPDATE_MODE" == "render" ]]; then
                sgnd_print_sectionheader "Destination" --padend 0
            else
                sgnd_print_sectionheader "Source and destination" --padend 0
            fi

            if [[ "$VAL_UPDATE_MODE" != "render" ]]; then
                ask --label "Source directory" \
                    --var VAL_SRCDIR \
                    --default "$VAL_SRCDIR" \
                    --validate sgnd_validate_dir_exists \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad "$lp" \
                    --labelwidth "$lw"

                ask --label "Source file masks" \
                    --var VAL_FILESPEC \
                    --default "$VAL_FILESPEC" \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad "$lp" \
                    --labelwidth "$lw"
            fi

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

            if [[ "$VAL_UPDATE_MODE" == "full" ]]; then
                FLAG_CLEAN_OUTPUT=1
                sgnd_print "    Clean output directory before writing : Yes (required for Full mode)"
            else
                FLAG_CLEAN_OUTPUT=0
                sgnd_print "    Clean output directory before writing : No"
            fi

            if [[ "$VAL_UPDATE_MODE" == "render" ]]; then
                FLAG_CLEAR_RENDER_CACHE=0
                FLAG_REVIEW=0
                sgnd_print "    Clear cached render data             : No (Render mode uses the cache)"
                sgnd_print "    Scan recursively                     : Not applicable"
                sgnd_print "    View parsed data                     : Not applicable"
            else
                [[ "$VAL_UPDATE_MODE" == "full" ]] && default="Y" || default="N"
                ask --label "Clear cached render data" \
                    --var reply \
                    --type flag \
                    --default "$default" \
                    --validate sgnd_validate_yesno \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad "$lp" \
                    --labelwidth "$lw"
                [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_CLEAR_RENDER_CACHE=1 || FLAG_CLEAR_RENDER_CACHE=0

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
            fi

            (( ${FLAG_COPY_TO_GIT:-0} )) && default="Y" || default="N"
            ask --label "Copy generated site to Git docs" \
                --var reply \
                --type flag \
                --default "$default" \
                --validate sgnd_validate_yesno \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            [[ "${reply,,}" =~ ^(y|yes)$ ]] && FLAG_COPY_TO_GIT=1 || FLAG_COPY_TO_GIT=0

            if [[ "$VAL_UPDATE_MODE" != "render" ]]; then
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
            fi

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

    # fn: _doc_load_cached_table - Load a cached PSV table into a named array
        # . Purpose
        #   Restore one parser table from the persistent documentation cache.
        #
        # . Arguments
        #   $1  Cached PSV filename.
        #   $2  Destination array name.
        #
        # . Returns
        #   0 when the table was loaded.
        #   1 when the cache file is missing or unreadable.
        #
        # . Usage
        #   _doc_load_cached_table "$VAL_OUTDIR/.sgnd-doc-cache/mod_table.psv" MOD_TABLE
    _doc_load_cached_table() {
        local cache_file="${1:-}"
        local array_name="${2:-}"
        local line=""

        [[ -r "$cache_file" && -n "$array_name" ]] || return 1

        # A schema change (for example adding Subgroup to MOD_TABLE) invalidates
        # incremental cache rows because positional PSV fields would otherwise shift.
        if [[ "$array_name" == "MOD_TABLE" ]]; then
            local cached_schema=""
            IFS= read -r cached_schema < "$cache_file" || return 1
            [[ "$cached_schema" == "$MOD_TABLE_SCHEMA" ]] || {
                saywarning "Documentation cache schema changed; run a full documentation rebuild"
                return 1
            }
        fi

        local -n table_ref="$array_name"
        table_ref=()

        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && table_ref+=("$line")
        done < <(tail -n +2 "$cache_file")
    }

    # fn: _doc_load_cache - Restore all parser tables from the previous render cache
        # . Purpose
        #   Initialize incremental generation from the last complete documentation dataset.
        #
        # . Returns
        #   0 when every required cached table was loaded.
        #   1 when no complete cache is available.
        #
        # . Usage
        #   _doc_load_cache
    _doc_load_cache() {
        local cache_dir="$VAL_OUTDIR/.sgnd-doc-cache"

        [[ -d "$cache_dir" ]] || {
            sayfail "No documentation cache found: $cache_dir"
            sayinfo "Run a full documentation rebuild before using update mode"
            return 1
        }

        _doc_load_cached_table "$cache_dir/mod_table.psv" MOD_TABLE || return 1
        _doc_load_cached_table "$cache_dir/mod_sections.psv" MOD_SECTIONS || return 1
        _doc_load_cached_table "$cache_dir/mod_items.psv" MOD_ITEMS || return 1
        _doc_load_cached_table "$cache_dir/mod_attribution.psv" MOD_ATTRIBUTION || return 1
        _doc_load_cached_table "$cache_dir/mod_globals.psv" MOD_GLOBALS || return 1
        _doc_load_cached_table "$cache_dir/doc_content_lines.psv" DOC_CONTENT_LINES || return 1

        sayinfo "Loaded documentation cache from: $cache_dir"
    }

    # fn: _doc_remove_modules_from_table - Remove module rows from a named table
        # . Purpose
        #   Delete stale rows for modules that will be reparsed or were removed.
        #
        # . Arguments
        #   $1  Array name.
        #   $2  Zero-based field index containing the module name.
        #   $@  Module names to remove.
        #
        # . Returns
        #   0 after filtering the table.
        #
        # . Usage
        #   _doc_remove_modules_from_table MOD_ITEMS 0 "ui-say.sh" "ui-ask.sh"
    _doc_remove_modules_from_table() {
        local array_name="${1:-}"
        local field_index="${2:-0}"
        shift 2 || return 1

        local -A remove_set=()
        local module_name=""
        local row=""
        local field=""
        local -a fields=()
        local -a retained=()

        for module_name in "$@"; do
            [[ -n "$module_name" ]] && remove_set["$module_name"]=1
        done

        local -n table_ref="$array_name"
        for row in "${table_ref[@]}"; do
            IFS='|' read -r -a fields <<< "$row"
            field="${fields[$field_index]-}"
            [[ -n "${remove_set[$field]-}" ]] || retained+=("$row")
        done

        table_ref=("${retained[@]}")
    }

    # fn: _doc_remove_modules - Remove stale rows for one or more modules
        # . Purpose
        #   Purge all parser-owned records associated with selected module basenames.
        #
        # . Arguments
        #   $@  Module basenames to remove.
        #
        # . Usage
        #   _doc_remove_modules "ui-say.sh" "ui-ask.sh"
    _doc_remove_modules() {
        (( $# > 0 )) || return 0

        _doc_remove_modules_from_table MOD_TABLE 1 "$@"
        _doc_remove_modules_from_table MOD_ATTRIBUTION 0 "$@"
        _doc_remove_modules_from_table MOD_GLOBALS 0 "$@"
        _doc_remove_modules_from_table MOD_SECTIONS 0 "$@"
        _doc_remove_modules_from_table MOD_ITEMS 0 "$@"
        _doc_remove_modules_from_table DOC_CONTENT_LINES 0 "$@"
    }

    # fn: _doc_path_matches_filespec - Test whether a path matches the active source masks
        # . Purpose
        #   Match a source path against one or more comma-separated shell-style masks.
        #
        # . Arguments
        #   $1  Source path.
        #
        # . Returns
        #   0 when the basename matches at least one mask in VAL_FILESPEC.
        #   1 otherwise.
        #
        # . Usage
        #   VAL_FILESPEC="*.sh,*.py"; _doc_path_matches_filespec "/srv/project/tool.py"
    _doc_path_matches_filespec() {
        local path="${1:-}"
        local name="${path##*/}"
        local mask=""
        local -a masks=()

        IFS=',' read -r -a masks <<< "${VAL_FILESPEC:-}"

        for mask in "${masks[@]}"; do
            mask="${mask#"${mask%%[![:space:]]*}"}"
            mask="${mask%"${mask##*[![:space:]]}"}"
            [[ -n "$mask" ]] || continue
            [[ "$name" == $mask ]] && return 0
        done

        return 1
    }

    # fn: _doc_collect_selected_files - Resolve explicitly selected update files
        # . Purpose
        #   Convert the comma-separated selected-file argument into parse and removal lists.
        #
        # . Outputs (globals)
        #   SGND_DOC_UPDATE_FILES, SGND_DOC_REMOVE_MODULES
        #
        # . Returns
        #   0 when every selected file is valid.
        #   1 when no files were supplied or a file cannot be resolved.
        #
        # . Usage
        #   VAL_UPDATE_FILES="common/ui-say.sh,common/ui-ask.sh"; _doc_collect_selected_files
    _doc_collect_selected_files() {
        local spec="${VAL_UPDATE_FILES:-}"
        local entry=""
        local path=""
        local -a entries=()

        SGND_DOC_UPDATE_FILES=()
        SGND_DOC_REMOVE_MODULES=()

        [[ -n "$spec" ]] || {
            sayfail "Selected update mode requires --update-files"
            return 1
        }

        IFS=',' read -r -a entries <<< "$spec"
        for entry in "${entries[@]}"; do
            entry="${entry#"${entry%%[![:space:]]*}"}"
            entry="${entry%"${entry##*[![:space:]]}"}"
            [[ -n "$entry" ]] || continue

            if [[ "$entry" == /* ]]; then
                path="$entry"
            else
                path="${VAL_SRCDIR%/}/$entry"
            fi

            path="$(readlink -f -- "$path" 2>/dev/null)" || path=""
            [[ -f "$path" ]] || {
                sayfail "Selected source file does not exist: $entry"
                return 1
            }
            _doc_path_matches_filespec "$path" || {
                sayfail "Selected source file does not match $VAL_FILESPEC: $entry"
                return 1
            }

            SGND_DOC_UPDATE_FILES+=("$path")
            SGND_DOC_REMOVE_MODULES+=("${path##*/}")
        done

        (( ${#SGND_DOC_UPDATE_FILES[@]} > 0 ))
    }

    # fn: _doc_collect_changed_files - Collect Git additions, modifications, deletions, and renames
        # . Purpose
        #   Build incremental parse/removal lists from changes relative to HEAD plus untracked files.
        #
        # . Outputs (globals)
        #   SGND_DOC_UPDATE_FILES, SGND_DOC_REMOVE_MODULES
        #
        # . Returns
        #   0 when Git status was collected successfully, including when no matching files changed.
        #   1 when VAL_SRCDIR is not inside a Git work tree.
        #
        # . Usage
        #   _doc_collect_changed_files
    _doc_collect_changed_files() {
        local repo_root=""
        local source_root=""
        local status=""
        local old_rel=""
        local new_rel=""
        local rel=""
        local path=""
        local module=""
        local -A parse_seen=()
        local -A remove_seen=()

        SGND_DOC_UPDATE_FILES=()
        SGND_DOC_REMOVE_MODULES=()

        repo_root="$(git -C "$VAL_SRCDIR" rev-parse --show-toplevel 2>/dev/null)" || {
            sayfail "Source directory is not inside a Git work tree: $VAL_SRCDIR"
            return 1
        }
        source_root="$(readlink -f -- "$VAL_SRCDIR")"

        while IFS= read -r -d '' status; do
            IFS= read -r -d '' old_rel || break

            if [[ "$status" == R* || "$status" == C* ]]; then
                IFS= read -r -d '' new_rel || break
                path="$(readlink -m -- "$repo_root/$old_rel")"
                if [[ "$path" == "$source_root"/* ]] && _doc_path_matches_filespec "$path"; then
                    module="${path##*/}"
                    remove_seen["$module"]=1
                fi
                rel="$new_rel"
            else
                rel="$old_rel"
            fi

            path="$(readlink -m -- "$repo_root/$rel")"
            [[ "$path" == "$source_root"/* ]] || continue
            _doc_path_matches_filespec "$path" || continue

            module="${path##*/}"
            remove_seen["$module"]=1
            if [[ -f "$path" ]]; then
                parse_seen["$path"]=1
            fi
        done < <(git -C "$repo_root" diff --name-status -z HEAD --)

        while IFS= read -r -d '' rel; do
            path="$(readlink -m -- "$repo_root/$rel")"
            [[ "$path" == "$source_root"/* ]] || continue
            _doc_path_matches_filespec "$path" || continue
            [[ -f "$path" ]] || continue

            module="${path##*/}"
            remove_seen["$module"]=1
            parse_seen["$path"]=1
        done < <(git -C "$repo_root" ls-files --others --exclude-standard -z --)

        if (( ${#remove_seen[@]} > 0 )); then
            mapfile -t SGND_DOC_REMOVE_MODULES < <(printf '%s\n' "${!remove_seen[@]}" | sort)
        fi
        if (( ${#parse_seen[@]} > 0 )); then
            mapfile -t SGND_DOC_UPDATE_FILES < <(printf '%s\n' "${!parse_seen[@]}" | sort)
        fi

        sayinfo "Git update set: ${#SGND_DOC_UPDATE_FILES[@]} file(s) to parse, ${#SGND_DOC_REMOVE_MODULES[@]} module(s) to refresh/remove"
    }

    # fn: _doc_iterate_explicit_files - Parse an explicit list of source files
        # . Arguments
        #   $1  Callback function.
        #   $@  Source files.
        #
        # . Usage
        #   _doc_iterate_explicit_files _parse_module_file "common/ui-say.sh"
    _doc_iterate_explicit_files() {
        local callback="${1:-}"
        shift || return 1
        local file=""
        local files_ttl="$#"
        local files_proc=0
        local line_total=0
        local name=""

        declare -F "$callback" >/dev/null || return 1
        (( files_ttl > 0 )) || return 0

        sgnd_print
        sayprogress_begin --slots 1
        SGND_DOC_PROGRESS_ACTIVE=1
        SGND_DOC_PROGRESS_MODULE_TOTAL="$files_ttl"

        for file in "$@"; do
            [[ -f "$file" ]] || continue
            ((files_proc++))
            name="${file##*/}"
            line_total="$(_doc_count_lines "$file")"
            (( line_total > 0 )) || line_total=1

            SGND_DOC_PROGRESS_MODULE_CURRENT="$files_proc"
            SGND_DOC_PROGRESS_MODULE_NAME="$name"
            SGND_DOC_PROGRESS_LINE_TOTAL="$line_total"
            _doc_progress_line 0 "$line_total" "$name"
            "$callback" "$file" || saywarning "Callback $callback failed for file: $file"
            _doc_progress_line "$line_total" "$line_total" "$name"
        done

        SGND_DOC_PROGRESS_ACTIVE=0
        SGND_DOC_PROGRESS_MODULE_CURRENT=0
        SGND_DOC_PROGRESS_MODULE_TOTAL=0
        SGND_DOC_PROGRESS_MODULE_NAME=""
        SGND_DOC_PROGRESS_LINE_TOTAL=0
        sayprogress_done
    }

    # fn: _iterate_files - Iterate source files and collect documentation data
        # . Purpose
        #   Iterate over files in a directory using comma-separated file masks,
        #   optionally recursing into subdirectories.
        #
        # . Behavior
        #   - Filters source files against comma-separated file_spec masks
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
        #   _iterate_files "./src" "*.sh,*.py" 1 sgnd_doc_process_file
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
        #
        # . Usage
        #   _doc_count_lines "/tmp/sgnd-example.txt" "example-2" "example-3" "example-4"
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
        #   Iterate over files in a directory using comma-separated file masks,
        #   optionally recursing into subdirectories.
        #
        # . Behavior
        #   - Filters source files against comma-separated file_spec masks.
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
        #   _iterate_files "./src" "*.sh,*.py" 1 _parse_module_file
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
            while IFS= read -r -d '' file; do
                [[ -f "$file" ]] || continue
                _doc_path_matches_filespec "$file" || continue
                files+=("$file")
            done < <(
                find "$source_dir" -maxdepth 1 -type f -print0
            )
        else
            while IFS= read -r -d '' file; do
                [[ -f "$file" ]] || continue
                _doc_path_matches_filespec "$file" || continue
                files+=("$file")
            done < <(
                find "$source_dir" -type f -print0
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

    # fn: _copy_docs_to_git - Copy generated documentation into the repository docs directory
        # . Purpose
        #   Publish the generated documentation tree into the Git repository's
        #   top-level docs directory without relying on symbolic links.
        #
        # . Behavior
        #   - Resolves the Git repository root from VAL_SRCDIR.
        #   - Uses <repo-root>/docs as the destination.
        #   - Replaces the previous published copy so removed pages do not remain stale.
        #   - Excludes internal documentation cache directories from the Git copy.
        #   - Does nothing when FLAG_COPY_TO_GIT is disabled.
        #
        # . Returns
        #   0 when copying is disabled or completes successfully.
        #   1 when the repository or source documentation directory cannot be resolved.
        #
        # . Usage
        #   _copy_docs_to_git
    _copy_docs_to_git() {
        (( ${FLAG_COPY_TO_GIT:-0} )) || return 0

        local repo_root=""
        local git_docs_dir=""

        repo_root="$(git -C "$VAL_SRCDIR" rev-parse --show-toplevel 2>/dev/null)" || {
            sayfail "Cannot resolve Git repository from source directory: $VAL_SRCDIR"
            return 1
        }

        git_docs_dir="${repo_root%/}/docs"

        [[ -d "$VAL_OUTDIR" ]] || {
            sayfail "Generated documentation directory does not exist: $VAL_OUTDIR"
            return 1
        }

        [[ -n "$git_docs_dir" && "$git_docs_dir" != "/" && "$git_docs_dir" != "$VAL_OUTDIR" ]] || {
            sayfail "Refusing unsafe Git docs destination: $git_docs_dir"
            return 1
        }

        saystart "Copying generated documentation to Git docs directory"

        mkdir -p "$git_docs_dir" || {
            sayfail "Cannot create Git docs directory: $git_docs_dir"
            return 1
        }

        find "$git_docs_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + || {
            sayfail "Cannot clear Git docs directory: $git_docs_dir"
            return 1
        }

        cp -a "$VAL_OUTDIR/." "$git_docs_dir/" || {
            sayfail "Cannot copy generated documentation to: $git_docs_dir"
            return 1
        }

        rm -rf -- \
            "$git_docs_dir/.sgnd-doc-cache" \
            "$git_docs_dir/.sgnd-render-cache"

        sayok "Copied generated documentation to: $git_docs_dir"
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
        if [[ "$VAL_UPDATE_MODE" == "render" ]]; then
            sgnd_print "  Source parsing: skipped (existing renderer cache reused)"
            sgnd_print "  Renderer cache: ${DOC_RENDER_CACHE_DIR:-$VAL_OUTDIR/.sgnd-render-cache}"
        else
            sgnd_print  "  Modules processed: ${#MOD_TABLE[@]}"
            sgnd_print  "  Sections processed: ${#MOD_SECTIONS[@]}"
            sgnd_print  "  Items documented: ${#MOD_ITEMS[@]}"
            sgnd_print  "  Comments extracted: ${#DOC_CONTENT_LINES[@]}"
        fi
        sgnd_print
        sgnd_print "  Generation mode: $VAL_UPDATE_MODE"
        [[ "$VAL_UPDATE_MODE" == "render" ]] || sgnd_print "  Source directory: $VAL_SRCDIR"
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

        case "$VAL_UPDATE_MODE" in
            full)
                FLAG_CLEAN_OUTPUT=1
                _iterate_files "$VAL_SRCDIR" "$VAL_FILESPEC" "$FLAG_RECURSIVE_SCAN" _parse_module_file
                ;;
            selected)
                FLAG_CLEAN_OUTPUT=0
                _doc_load_cache || return 1
                _doc_collect_selected_files || return 1
                _doc_remove_modules "${SGND_DOC_REMOVE_MODULES[@]}"
                _doc_iterate_explicit_files _parse_module_file "${SGND_DOC_UPDATE_FILES[@]}"
                ;;
            changed)
                FLAG_CLEAN_OUTPUT=0
                _doc_load_cache || return 1
                _doc_collect_changed_files || return 1
                _doc_remove_modules "${SGND_DOC_REMOVE_MODULES[@]}"
                _doc_iterate_explicit_files _parse_module_file "${SGND_DOC_UPDATE_FILES[@]}"
                ;;
            render)
                FLAG_CLEAN_OUTPUT=0
                FLAG_CLEAR_RENDER_CACHE=0
                ;;
            *)
                sayfail "Unknown generation mode: $VAL_UPDATE_MODE"
                return 1
                ;;
        esac

        local end_time
        end_time="$(date +%s)"

        if [[ "$VAL_UPDATE_MODE" != "render" ]]; then
            display_time="$(date +%H:%M:%S)"
            sayok "Done parsing source files (duration: $(( end_time - start_time )) seconds)"
        else
            sayinfo "Render mode selected; source parsing skipped"
        fi

        if [[ "$VAL_UPDATE_MODE" != "render" ]] && (( FLAG_REVIEW )); then
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
        
        if [[ "$VAL_UPDATE_MODE" != "render" ]] && (( FLAG_REVIEW )); then
           sgnd_dt_print_table "$DOC_CONTENT_LINES_SCHEMA" DOC_CONTENT_LINES 1
        fi

        if (( FLAG_DRYRUN )); then
            if [[ "$VAL_UPDATE_MODE" == "render" ]]; then
                sayinfo "Would have rendered existing cached data to $VAL_OUTDIR"
            else
                sayinfo "Would have rendered site to $VAL_OUTDIR"
            fi
            if (( FLAG_COPY_TO_GIT )); then
                sayinfo "Would have copied the generated site to the Git repository docs directory"
            fi
        else
            saystart "Rendering html documentation"
            start_time="$(date +%s)"

            if [[ "$VAL_UPDATE_MODE" == "render" ]]; then
                _render_cached_site "$VAL_OUTDIR" || return 1
            else
                _render_site "$VAL_OUTDIR" || return 1
            fi

            end_time="$(date +%s)"
            sayok "Done rendering documentation hierarchy (duration: $(( end_time - start_time )) seconds)"

            _copy_docs_to_git || return 1
        fi

        end_time="$(date +%s)"
        display_time="$(date +%H:%M:%S)"

        _summary
        
        sayend "Documentation generation completed successfully at $display_time (duration: $(( end_time - main_start )) seconds)"
    }

    # Entrypoint: sgnd_bootstrap will split framework args from script args.
    main "$@"
