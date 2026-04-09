#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Documentation Generator
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2609100
#   Checksum    : none
#   Source      : doc-generator.sh
#   Type        : script
#   Purpose     : Generate documentation from source code comments using the
#                 sgnd-comment-parser library.
#
# Description:
#
# Design principles:
#
# Role in framework:
# Non-goals:
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      :
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# =====================================================================================
set -uo pipefail

# --- Bootstrap -----------------------------------------------------------------------
    # fn: _framework_locator
        # Purpose:
        #   Locate, create, and load the SolidGroundUX bootstrap configuration.
        #
        # Behavior:
        #   - Searches user and system bootstrap configuration locations.
        #   - Prefers the invoking user's config over the system config.
        #   - Creates a new bootstrap config when none exists.
        #   - Prompts for framework/application roots in interactive mode.
        #   - Applies default values when running non-interactively.
        #   - Sources the selected configuration file.
        #
        # Outputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # Returns:
        #   0   success
        #   126 configuration unreadable or invalid
        #   127 configuration directory or file could not be created
        #
        # Usage:
        #   _framework_locator || return $?
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys=""
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"
        cfg_sys="/etc/solidgroundux/solidgroundux.cfg"

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
                sayinfo "SolidGroundUX bootstrap configuration"
                sayinfo "No configuration file found."
                sayinfo "Creating: $cfg"

                printf "SGND_FRAMEWORK_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf "SGND_APPLICATION_ROOT [/] : " > /dev/tty
                read -r reply < /dev/tty
                app_root="${reply:-$fw_root}"
            fi

            case "$fw_root" in
                /*) ;;
                *) sayfail "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) sayfail "ERR: SGND_APPLICATION_ROOT must be an absolute path"; return 126 ;;
            esac

            mkdir -p "$(dirname "$cfg")" || return 127

            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            saydebug "Created bootstrap cfg: $cfg"
        fi

        if [[ -r "$cfg" ]]; then
            # shellcheck source=/dev/null
            source "$cfg"
            : "${SGND_FRAMEWORK_ROOT:=/}"
            : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"
        else
            sayfail "Cannot read bootstrap cfg: $cfg"
            return 126
        fi

        saydebug "Bootstrap cfg loaded: $cfg, SGND_FRAMEWORK_ROOT=$SGND_FRAMEWORK_ROOT, SGND_APPLICATION_ROOT=$SGND_APPLICATION_ROOT"
    }

    # fn: _load_bootstrapper
        # Purpose:
        #   Resolve and source the framework bootstrap library.
    _load_bootstrapper() {
        local bootstrap=""

        _framework_locator || return $?

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            bootstrap="/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"
        else
            bootstrap="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"
        fi

        [[ -r "$bootstrap" ]] || {
            printf "FATAL: Cannot read bootstrap: %s\n" "$bootstrap" >&2
            return 126
        }

        saydebug "Loading $bootstrap"

        # shellcheck source=/dev/null
        source "$bootstrap"
    }

    # Minimal colors
    MSG_CLR_INFO=$'\e[38;5;250m'
    MSG_CLR_STRT=$'\e[38;5;82m'
    MSG_CLR_OK=$'\e[38;5;82m'
    MSG_CLR_WARN=$'\e[1;38;5;208m'
    MSG_CLR_FAIL=$'\e[38;5;196m'
    MSG_CLR_CNCL=$'\e[0;33m'
    MSG_CLR_END=$'\e[38;5;82m'
    MSG_CLR_EMPTY=$'\e[2;38;5;250m'
    MSG_CLR_DEBUG=$'\e[1;35m'

    TUI_COMMIT=$'\e[2;37m'
    RESET=$'\e[0m'

    # Minimal UI
    saystart()   { printf '%sSTART%s\t%s\n'  "${MSG_CLR_STRT-}"  "${RESET-}" "$*" >&2; }
    sayinfo()    {
        if (( ${FLAG_VERBOSE:-0} )); then
            printf '%sINFO%s \t%s\n' "${MSG_CLR_INFO-}" "${RESET-}" "$*" >&2
        fi
    }
    sayok()      { printf '%sOK%s   \t%s\n' "${MSG_CLR_OK-}"    "${RESET-}" "$*" >&2; }
    saywarning() { printf '%sWARN%s \t%s\n' "${MSG_CLR_WARN-}"  "${RESET-}" "$*" >&2; }
    sayfail()    { printf '%sFAIL%s \t%s\n' "${MSG_CLR_FAIL-}"  "${RESET-}" "$*" >&2; }
    saydebug() {
        if (( ${FLAG_DEBUG:-0} )); then
            printf '%sDEBUG%s \t%s\n' "${MSG_CLR_DEBUG-}" "${RESET-}" "$*" >&2
        fi
    }
    saycancel()  { printf '%sCANCEL%s\t%s\n' "${MSG_CLR_CNCL-}" "${RESET-}" "$*" >&2; }
    sayend()     { printf '%sEND%s   \t%s\n' "${MSG_CLR_END-}"  "${RESET-}" "$*" >&2; }

# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# --- Script metadata (framework integration) -----------------------------------------
    # var: SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
    SGND_USING=(
        sgnd-datatable.sh
        sgnd-comment-parser.sh
        sgnd-doc-writer.sh
    )

    # var: SGND_ARGS_SPEC
        # Optional: script-specific arguments
    SGND_ARGS_SPEC=(
        "srcdir|s|value|VAL_SRCDIR|Source directory to scan||"
        "file|f|value|VAL_FILE|Single file to scan||"
        "mask|m|value|VAL_MASK|Filename mask for source scanning|*.sh|"
        "outdir|o|value|VAL_OUTDIR|Output directory for generated docs||"
        "recursive|r|flag|FLAG_RECURSIVE_SCAN|Recursively scan source directory|1|"
        "clean|c|flag|FLAG_CLEAN_OUTPUT|Clear output directory before writing|0|"
        "auto|a|flag|FLAG_AUTO_RUN|Automatically run with last used or default parameters|0|"
        "viewresults|v|flag|FLAG_VIEW_RESULTS|Automatically open generated docs in browser after generation (desktop mode only)|0|"
    )

    # var: SGND_SCRIPT_EXAMPLES
    SGND_SCRIPT_EXAMPLES=(
        "Run in dry-run mode:"
        "  $SGND_SCRIPT_NAME --dryrun"
        ""
        "Show verbose logging"
        "  $SGND_SCRIPT_NAME --verbose"
    )

    # var: SGND_SCRIPT_GLOBALS
    SGND_SCRIPT_GLOBALS=(
    )

    # var: SGND_STATE_VARIABLES
    SGND_STATE_VARIABLES=(
        "VAL_SRCDIR|Source Directory||"
        "VAL_FILE|Source File||"
        "VAL_MASK|Filename Mask|*.sh|"
        "VAL_OUTDIR|Output Directory||"
        "FLAG_RECURSIVE_SCAN|Recursive Scan|0|"
        "FLAG_CLEAN_OUTPUT|Clean Output Directory|0|"
        "VIEW_RESULTS|Automatically open generated docs in browser after generation (desktop mode only)|0|"
    )

    # var: SGND_ON_EXIT_HANDLERS
    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=1

# --- Local script declarations -------------------------------------------------------
    DOC_FUNCTION_SCHEMA="file|line|major_section|minor_section|function_name|purpose"
    DOC_FUNCTIONS=()

    DOC_SCAN_SCHEMA="file|line_nr|record_type|name|parent_section|text"
    DOC_SCAN_ROWS=()

    DOC_MODULE_SCHEMA="file|module_id"
    DOC_MODULES=()

    DOC_OUTPUT_SCHEMA="doc_type|target_file|module_name|sort_key|content_type|content"
    DOC_OUTPUT_ROWS=()

# --- Local helpers -------------------------------------------------------------------
    # fn: _clean_output_directories
    _clean_output_directories() {
        local md_dir="${DOC_OUTDIR%/}/md"
        local html_dir="${DOC_OUTDIR%/}/html"

        sayinfo "Cleaning output directories..."

        if [[ -d "$md_dir" ]]; then
            rm -f "${md_dir}/"*.md 2>/dev/null
        fi

        if [[ -d "$html_dir" ]]; then
            rm -f "${html_dir}/"*.html 2>/dev/null
        fi

        sayok "Output directories cleaned"
    }

    # fn: _is_header_separator
    _is_header_separator() {
        [[ "$1" =~ ^[[:space:]]*#[[:space:]]*={3,}[[:space:]]*$ ]]
    }

    # fn: _is_header_section_line
    _is_header_section_line() {
        [[ "$1" =~ ^#\ [A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]]
    }

    # fn: _parse_header_section_line
    _parse_header_section_line() {
        local line="${1-}"
        local value=""

        value="${line#\# }"
        value="${value%:}"
        value="${value%"${value##*[![:space:]]}"}"

        printf '%s\n' "$value"
    }

    # fn: _is_section_line
    _is_section_line() {
        [[ "$1" =~ ^[[:space:]]*#\ (-|--|---)\ ([^[:space:]].*)$ ]]
    }

    # fn: _get_section_level
    _get_section_level() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#\ (-|--|---)\  ]] || return 1

        case "${BASH_REMATCH[1]}" in
            ---) printf '1\n' ;;
            --)  printf '2\n' ;;
            -)   printf '3\n' ;;
            *)   return 1 ;;
        esac
    }

    # fn: _parse_section_line
    _parse_section_line() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#\ (-|--|---)\ (.*)$ ]] || return 1
        printf '%s\n' "${BASH_REMATCH[2]}"
    }

    # fn: _is_detail_comment_start
    _is_detail_comment_start() {
        [[ "$1" =~ ^[[:space:]]*#[[:space:]]*(fn|var):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]]
    }

    # fn: _parse_detail_kind
    _parse_detail_kind() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#[[:space:]]*(fn|var):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]] || return 1
        printf '%s\n' "${BASH_REMATCH[1]}"
    }

    # fn: _parse_detail_name
    _parse_detail_name() {
        local line="${1-}"

        [[ "$line" =~ ^[[:space:]]*#[[:space:]]*(fn|var):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]] || return 1
        printf '%s\n' "${BASH_REMATCH[2]}"
    }

    # fn: _detail_matches_declaration
    _detail_matches_declaration() {
        local kind="${1:?missing kind}"
        local name="${2:?missing name}"
        local line="${3-}"

        case "$kind" in
            fn)
                [[ "$line" =~ ^[[:space:]]*${name}[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*$ ]]
                ;;
            var)
                [[ "$line" =~ ^[[:space:]]*${name}= ]]
                ;;
            *)
                return 1
                ;;
        esac
    }

    # fn: _normalize_comment_line
    _normalize_comment_line() {
        local line="${1-}"

        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]?(.*)$ ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
        else
            printf '%s\n' "$line"
        fi
    }

# --- Local script functions ----------------------------------------------------------
    # fn: _resolve_parameters
    _resolve_parameters() {
        local lw=25
        local lp=4
        local recursive_default="No"
        local answ=""

        DOC_SOURCE="${VAL_SRCDIR:-${DOC_SOURCE:-$SGND_APPLICATION_ROOT}}"
        DOC_FILE="${VAL_FILE:-${DOC_FILE:-}}"
        DOC_MASK="${VAL_MASK:-${DOC_MASK:-*.sh}}"
        DOC_OUTDIR="${VAL_OUTDIR:-${DOC_OUTDIR:-$SGND_DOCS_DIR}}"
        CLEAN_OUTPUT="${FLAG_CLEAN_OUTPUT:-${CLEAN_OUTPUT:-0}}"

        RECURSIVE_SCAN="${FLAG_RECURSIVE_SCAN:-${RECURSIVE_SCAN:-1}}"
        VIEW_RESULTS="${FLAG_VIEW_RESULTS:-${VIEW_RESULTS:-0}}"

        while true; do
            sgnd_print
            sgnd_print_sectionheader "Enter Documentation Generator Parameters" --padend 0

            # Basic parameters
            ask --label "Source directory" \
                --var DOC_SOURCE \
                --default "$DOC_SOURCE" \
                --validate sgnd_validate_dir_exists \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask --label "Source file" \
                --var DOC_FILE \
                --default "$DOC_FILE" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            
            ask --label "Filename mask" \
                --var DOC_MASK \
                --default "$DOC_MASK" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            
            ask --label "Output directory" \
                --var DOC_OUTDIR \
                --default "$DOC_OUTDIR" \
                --validate sgnd_validate_dir_exists \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            # Clean output directory
            if (( CLEAN_OUTPUT )); then
                clean_default="Yes"
            else
                clean_default="No"
            fi

            ask --label "Clean output directory before writing (Y/N)" \
                --var answ \
                --type flag \
                --default "$clean_default" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            answ="${answ,,}"
            if [[ "$answ" == "y" || "$answ" == "yes" ]]; then
                CLEAN_OUTPUT=1
            else
                CLEAN_OUTPUT=0
            fi

            # Recursive scan
            if (( RECURSIVE_SCAN )); then
                recursive_default="Yes"
            else
                recursive_default="No"
            fi

            ask --label "Recursive scan (Y/N)" \
                --var answ \
                --type flag \
                --default "$recursive_default" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            answ="${answ,,}"

            if [[ "$answ" == "y" || "$answ" == "yes" ]]; then
                RECURSIVE_SCAN=1
            else
                RECURSIVE_SCAN=0
            fi

            if ! sgnd_is_desktop_mode; then
                ask --label "Automatically open generated docs in browser after generation (Y/N)" \
                    --var answ \
                    --type flag \
                    --default "Yes" \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad "$lp" \
                    --labelwidth "$lw"

                answ="${answ,,}"

                if [[ "$answ" == "y" || "$answ" == "yes" ]]; then
                    VIEW_RESULTS=1
                else
                    VIEW_RESULTS=0
                fi
            fi

            sgnd_print_sectionheader --maxwidth "$lw"
            sgnd_print
            ask_dlg_autocontinue --seconds 15 --message "Continue with these settings?" --redo --cancel --pause

            case $? in
                0|1) break ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                3) continue ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac
        done
    }

    # fn: _process_files
    _process_files() {
        local -a files=()
        local file=""
        local mask="${DOC_MASK:-*.sh}"
        local total=0
        local current=0
        local failed=0
        local succeeded=0

        DOC_MODULES=()
        DOC_FUNCTIONS=()
        DOC_SCAN_ROWS=()

        if [[ -n "${DOC_FILE:-}" ]]; then
            [[ -f "$DOC_FILE" ]] || {
                sayfail "Specified file does not exist: $DOC_FILE"
                return 1
            }

            [[ -r "$DOC_FILE" ]] || {
                sayfail "Specified file is not readable: $DOC_FILE"
                return 1
            }

            files+=("$DOC_FILE")
        else
            [[ -n "${DOC_SOURCE:-}" ]] || {
                sayfail "No source directory was specified."
                return 1
            }

            [[ -d "$DOC_SOURCE" ]] || {
                sayfail "Source directory does not exist: $DOC_SOURCE"
                return 1
            }

            if (( ${RECURSIVE_SCAN:-0} )); then
                while IFS= read -r -d '' file; do
                    files+=("$file")
                done < <(find "$DOC_SOURCE" -type f -name "$mask" -print0)
            else
                while IFS= read -r -d '' file; do
                    files+=("$file")
                done < <(find "$DOC_SOURCE" -maxdepth 1 -type f -name "$mask" -print0)
            fi
        fi

        if (( ${#files[@]} == 0 )); then
            saywarning "No matching files found."
            return 0
        fi

        total="${#files[@]}"
        saystart "Scanning ${total} file(s)..."

        for file in "${files[@]}"; do
            current=$((current + 1))

            sayprogress \
                --current "$current" \
                --total "$total" \
                --label "Processing file: $(basename "$file")" \
                --type 5 \
                --padleft 4

            if ! _scan_file "$file"; then
                failed=$((failed + 1))
                sayfail "Failed to scan file: $file"
                continue
            fi

            succeeded=$((succeeded + 1))
        done

        sayprogress_done

        if (( failed > 0 )); then
            saywarning "Scanned $succeeded of $total file(s); $failed failed."
        else
            sayok "Scanned $total file(s)"
        fi

        return 0
    }

    # fn: _scan_file
    _scan_file() {
        local file="${1:?missing file}"
        local line=""
        local line_nr=0
        local text=""

        local in_header=0
        local header_done=0
        local header_sep_count=0
        local current_header_section=""

        local current_major_section=""
        local current_minor_section=""
        local current_micro_section=""

        local pending_kind=""
        local pending_name=""
        local pending_major_section=""
        local pending_minor_section=""
        local pending_micro_section=""
        local pending_count=0

        local -a pending_lines=()
        local -a pending_line_nrs=()

        local i=0

        [[ -r "$file" ]] || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            line_nr=$((line_nr + 1))
            line="${line%$'\r'}"

            if (( ! header_done )); then
                if _is_header_separator "$line"; then
                    header_sep_count=$((header_sep_count + 1))

                    if (( header_sep_count == 1 )); then
                        in_header=1
                        current_header_section=""
                        continue
                    fi

                    if (( header_sep_count == 2 )); then
                        in_header=0
                        header_done=1
                        current_header_section=""
                        continue
                    fi
                fi

                if (( in_header )); then
                    if _is_header_section_line "$line"; then
                        current_header_section="$(_parse_header_section_line "$line")"

                        sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                            "$file" \
                            "$line_nr" \
                            "headersection" \
                            "$current_header_section" \
                            "" \
                            "$current_header_section" || return 1
                    else
                        text="$(_normalize_comment_line "$line")"

                        sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                            "$file" \
                            "$line_nr" \
                            "headerline" \
                            "" \
                            "$current_header_section" \
                            "$text" || return 1
                    fi

                    continue
                fi
            fi

            if _is_section_line "$line"; then
                text="$(_parse_section_line "$line")"

                case "$(_get_section_level "$line")" in
                    1)
                        current_major_section="$text"
                        current_minor_section=""
                        current_micro_section=""
                        ;;
                    2)
                        current_minor_section="$text"
                        current_micro_section=""
                        ;;
                    3)
                        current_micro_section="$text"
                        ;;
                esac

                sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                    "$file" \
                    "$line_nr" \
                    "section" \
                    "$text" \
                    "$current_major_section" \
                    "$text" || return 1

                pending_kind=""
                pending_name=""
                pending_count=0
                pending_lines=()
                pending_line_nrs=()
                continue
            fi

            if (( pending_count == 0 )) && _is_detail_comment_start "$line"; then
                pending_kind="$(_parse_detail_kind "$line")"
                pending_name="$(_parse_detail_name "$line")"
                pending_major_section="$current_major_section"
                pending_minor_section="$current_minor_section"
                pending_micro_section="$current_micro_section"

                pending_count=0
                pending_lines=()
                pending_line_nrs=()

                pending_lines[pending_count]="$line"
                pending_line_nrs[pending_count]="$line_nr"
                pending_count=$((pending_count + 1))

                saydebug "PENDING START: $pending_kind : $pending_name @ $line_nr"
                continue
            fi

            if (( pending_count > 0 )); then
                if [[ "$line" =~ ^[[:space:]]*# ]]; then
                    pending_lines[pending_count]="$line"
                    pending_line_nrs[pending_count]="$line_nr"
                    pending_count=$((pending_count + 1))
                    saydebug "PENDING ADD: $pending_kind : $pending_name @ $line_nr :: $line"
                    continue
                fi

                if _detail_matches_declaration "$pending_kind" "$pending_name" "$line"; then
                    for (( i=0; i<pending_count; i++ )); do
                        text="$(_normalize_comment_line "${pending_lines[i]}")"

                        sgnd_dt_append "$DOC_SCAN_SCHEMA" DOC_SCAN_ROWS \
                            "$file" \
                            "${pending_line_nrs[i]}" \
                            "$pending_kind" \
                            "$pending_name" \
                            "$pending_major_section" \
                            "$text" || return 1
                    done
                fi

                pending_kind=""
                pending_name=""
                pending_count=0
                pending_lines=()
                pending_line_nrs=()
            fi
        done < "$file"

        return 0
    }

    # fn: _list_modules
    _list_modules() {
        local row=""
        local file=""
        local line_nr=""
        local record_type=""
        local name=""
        local parent_section=""
        local text=""

        local module_row=""
        local module_file=""
        local module_id=""

        local mod_id=1
        local found=0

        DOC_MODULES=()

        local row_count="${#DOC_SCAN_ROWS[@]}"
        local current=0

        for row in "${DOC_SCAN_ROWS[@]}"; do
            IFS='|' read -r file line_nr record_type name parent_section text <<< "$row"

            ((current++))
            sayprogress \
                --current "$current" \
                --total "$row_count" \
                --label "Looking for modules" \
                --type 5 \
                --padleft 4

            found=0

            for module_row in "${DOC_MODULES[@]}"; do
                IFS='|' read -r module_file module_id <<< "$module_row"

                if [[ "$module_file" == "$file" ]]; then
                    found=1
                    break
                fi
            done

            if (( ! found )); then
                saydebug "Found module: $file (id: $mod_id)"
                sgnd_dt_append "$DOC_MODULE_SCHEMA" DOC_MODULES "$file" "$mod_id" || {
                    sayfail "Failed to append module row for: $file"
                    return 1
                }
                mod_id=$((mod_id + 1))
            fi
        done
        sayprogress_done
        
        return 0
    }

# --- Main ----------------------------------------------------------------------------
    # fn: main
    
    main() {
        local rc=0

        _load_bootstrapper || exit $?

        sgnd_bootstrap --autostate -- "$@"
        rc=$?

        saydebug "After bootstrap: $rc"
        (( rc != 0 )) && exit "$rc"

        saydebug "Calling builtinarg handler"
        sgnd_builtinarg_handler
        saydebug "Exited builtinarg handler"

        sgnd_update_runmode
        sgnd_print_titlebar

        FLAG_AUTO_RUN="${FLAG_AUTO_RUN:-0}"
        if ! sgnd_is_ui_mode; then
            FLAG_AUTO_RUN=1
            saywarning "Non-interactive mode detected; auto-run enabled."
        fi

        if (( ! FLAG_AUTO_RUN )); then
            _resolve_parameters || exit $?
        fi

        _process_files || exit $?
        _list_modules || exit $?

        sgnd_doc_write_all || exit $?

        saydebug "Exited sgnd_doc_write_all"

        if sgnd_is_desktop_mode; then
            xdg-open "${DOC_OUTDIR%/}/html/index.html" >/dev/null 2>&1 &
        fi

    }

    main "$@"