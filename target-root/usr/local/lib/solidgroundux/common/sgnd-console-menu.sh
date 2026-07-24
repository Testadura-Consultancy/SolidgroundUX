# =====================================================================================
# SolidGroundUX - Console Menu System
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2620501
#   Checksum    : b21af8ae6acd9b37053b01c576f6955b58350d6ab168c2f5fafc713683113b39
#   Source      : sgnd-console-menu.sh
#   Group       : SolidGround Console
#   Type        : library
#   Purpose     : Provide menu definition and rendering logic for sgnd-console
#
# Description:
#   Implements the menu system used by sgnd-console for interactive navigation.
#
#   The library:
#     - Defines menu structures and item registration mechanisms
#     - Supports grouping, ordering, and labeling of menu items
#     - Integrates with rendering helpers to display menus consistently
#     - Handles user selection and dispatch to registered actions
#     - Enables modular extension by allowing external modules to register items
#
# Design principles:
#   - Modular menu composition through registration rather than hardcoding
#   - Clear separation between menu definition, rendering, and execution
#   - Predictable navigation and selection behavior
#   - Minimal coupling to specific applications or modules
#
# Role in framework:
#   - Core component of sgnd-console interactive tooling
#   - Bridges UI rendering, input handling, and executable scripts
#   - Enables pluggable console applications through module-based menus
#
# Non-goals:
#   - Full TUI frameworks or complex screen management
#   - Persistent menu state beyond runtime session
#   - Business logic execution beyond dispatching actions
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
# --- Toggle formatting --------------------------------------------------------------
    # fn: _sgnd_console_toggleword - Render toggle word
        # . Purpose
        #   Render a toggle label while emphasizing its hotkey character.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  WORD - Text word or label to render.
        #   $2  HOTKEY - Character within the word that should be emphasized as the hotkey.
        #   $3  STATE - Boolean or numeric state value.
        #   $4  ONCLR - Color used for the enabled state.
        #   $5  OFFCLR - Color used for the disabled state.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_toggleword "${WORD}" "${HOTKEY}" "${STATE}" "${ONCLR}" "${OFFCLR}"
    _sgnd_console_toggleword() {
        local word="${1:?missing word}"
        local hotkey="${2:?missing hotkey}"
        local state="${3:-0}"

        local onclr="${4:-$SGND_UI_ON}"
        local offclr="${5:-$SGND_UI_OFF}"

        local word_style=""
        local key_style=""
        local prefix=""
        local suffix=""

        if (( state )); then
            word_style="$(sgnd_sgr "$onclr" "$FX_BOLD")"
            key_style="$(sgnd_sgr "$onclr" "$FX_BOLD" "$FX_UNDERLINE")"
        else
            if [[ "$word" == "DRYRUN" ]]; then
                word="COMMIT(D)"
            fi
            word_style="$(sgnd_sgr "$offclr")"
            key_style="$(sgnd_sgr "$offclr" "$FX_BOLD" "$FX_UNDERLINE")"
        fi

        prefix="${word%%"$hotkey"*}"
        suffix="${word#*"$hotkey"}"

        if [[ "$word" == "$prefix" ]]; then
            printf '%s%s%s' "$word_style" "$word" "$RESET"
            return 0
        fi

        printf '%s%s%s%s%s%s%s' \
            "$word_style" "$prefix" \
            "$key_style" "$hotkey" \
            "$RESET" \
            "$word_style" "$suffix" \
            "$RESET"
    }
    # fn: _sgnd_console_onoff - Render on/off state
        # . Purpose
        #   Render a colored On/Off fragment for a boolean state.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  VALUE - Value to read, validate, render, or store.
        #   $2  ONCLR - Color used for the enabled state.
        #   $3  OFFCLR - Color used for the disabled state.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_onoff "${VALUE}" "${ONCLR}" "${OFFCLR}"
    _sgnd_console_onoff() {
        local value="${1:-0}"
        local onclr="${2:-$SGND_UI_ON}"
        local offclr="${3:-$SGND_UI_OFF}"

        if (( value )); then
            printf '%sOn%s' "$(sgnd_sgr "$onclr")" "$RESET"
        else
            printf '%sOff%s' "$(sgnd_sgr "$offclr")" "$RESET"
        fi
    }
# --- Toggle labels ------------------------------------------------------------------
    # fn: _sgnd_console_label_clearonrender - Build clear-on-render label
        # . Purpose
        #   Build the current menu label for the clear-on-render toggle.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_label_clearonrender
    _sgnd_console_label_clearonrender() {
        : "${SGND_CLEAR_ONRENDER:=1}"
        printf 'Clear screen: %s' "$(_sgnd_console_onoff "$SGND_CLEAR_ONRENDER")"
    }
    # fn: _sgnd_console_label_dryrun - Build dry-run label
        # . Purpose
        #   Build the current menu label for the dry-run/commit toggle.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_label_dryrun
    _sgnd_console_label_dryrun() {
        : "${FLAG_DRYRUN:=0}"
        printf 'Dry-run: %s' "$(_sgnd_console_onoff "$FLAG_DRYRUN" "$SGND_UI_DRYRUN" "$SGND_UI_COMMIT")"
    }
    # fn: _sgnd_console_label_debug - Build debug label
        # . Purpose
        #   Build the current menu label for the debug toggle.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_label_debug
    _sgnd_console_label_debug() {
        : "${FLAG_DEBUG:=0}"
        printf 'Debug: %s' "$(_sgnd_console_onoff "$FLAG_DEBUG")"
    }
    # fn: _sgnd_console_label_verbose - Build verbose label
        # . Purpose
        #   Build the current menu label for the verbose toggle.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_label_verbose
    _sgnd_console_label_verbose() {
        : "${FLAG_VERBOSE:=0}"
        printf 'Verbose: %s' "$(_sgnd_console_onoff "$FLAG_VERBOSE")"
    }
    # fn: _sgnd_console_label_logfile - Build logfile label
        # . Purpose
        #   Build the current menu label for the logfile toggle.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_label_logfile
    _sgnd_console_label_logfile() {
        : "${SGND_LOGFILE_ENABLED:=0}"
        printf 'Logfile: %s' "$(_sgnd_console_onoff "$SGND_LOGFILE_ENABLED")"
    }
# --- Toggle actions -----------------------------------------------------------------
    # fn: _sgnd_console_toggle_clearonrender - Toggle clear-on-render
        # . Purpose
        #   Render the console toggle clearonrender portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_toggle_clearonrender
    _sgnd_console_toggle_clearonrender() {
        : "${SGND_CLEAR_ONRENDER:=1}"

        if (( SGND_CLEAR_ONRENDER )); then
            SGND_CLEAR_ONRENDER=0
            sayinfo "Clear-on-render disabled"
        else
            SGND_CLEAR_ONRENDER=1
            sayinfo "Clear-on-render enabled"
        fi
    }
    # fn: _sgnd_console_toggle_dryrun - Toggle dry-run
        # . Purpose
        #   Handle console menu toggle dryrun behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_toggle_dryrun
    _sgnd_console_toggle_dryrun() {
        : "${FLAG_DRYRUN:=0}"

        if (( FLAG_DRYRUN )); then
            FLAG_DRYRUN=0
            sayinfo "Dry-run disabled"
        else
            FLAG_DRYRUN=1
            sayinfo "Dry-run enabled"
        fi
        SGND_LAST_WAITSECS=0
    }
    # fn: _sgnd_console_toggle_debug - Toggle debug
        # . Purpose
        #   Handle console menu toggle debug behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_toggle_debug
    _sgnd_console_toggle_debug() {
        : "${FLAG_DEBUG:=0}"

        if (( FLAG_DEBUG )); then
            FLAG_DEBUG=0
            sayinfo "Debug disabled"
        else
            FLAG_DEBUG=1
            sayinfo "Debug enabled"
        fi
        sgnd_update_runmode
    }
    # fn: _sgnd_console_toggle_verbose - Toggle verbose
        # . Purpose
        #   Handle console menu toggle verbose behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_toggle_verbose
    _sgnd_console_toggle_verbose() {
        : "${FLAG_VERBOSE:=0}"

        if (( FLAG_VERBOSE )); then
            FLAG_VERBOSE=0
            sayinfo "Verbose disabled"
        else
            FLAG_VERBOSE=1
            sayinfo "Verbose enabled"
        fi
    }

    # fn: _sgnd_console_set_file_loglevel - Set file log level
        # . Purpose
        #   Prompt for and apply the active SolidGroundUX file log level.
        #
        # . Behavior
        #   - Uses the current SGND_FILE_LOG_LEVEL value as the default.
        #   - Prompts the user to choose one supported file log level.
        #   - Updates SGND_FILE_LOG_LEVEL in the current console instance.
        #   - Persists the selected value to SGND_FRAMEWORK_STATEFILE when available.
        #
        # Inputs (globals):
        #   SGND_FILE_LOG_LEVEL
        #   SGND_FRAMEWORK_STATEFILE
        #
        # Outputs (globals):
        #   SGND_FILE_LOG_LEVEL
        #
        # Side effects:
        #   May update SGND_FRAMEWORK_STATEFILE.
        #
        # . Returns
        #   0 when the log level is selected and applied successfully.
        #   Non-zero when the prompt is cancelled or the state value cannot be saved.
        #
        # . Usage
        #   _sgnd_console_set_file_loglevel
    _sgnd_console_cycle_loglevel_value() {
        local current="${1:-silent}"
        local direction="${2:-1}"
        local i=0
        local current_index=0
        local -a levels=(silent quiet normal verbose debug trace)

        for i in "${!levels[@]}"; do
            if [[ "${levels[$i]}" == "$current" ]]; then
                current_index="$i"
                break
            fi
        done

        i=$(( (current_index + direction + ${#levels[@]}) % ${#levels[@]} ))
        printf '%s' "${levels[$i]}"
    }

    _sgnd_console_persist_framework_value() {
        local key="${1:?missing key}"
        local value="${2-}"

        [[ -n "${SGND_FRAMEWORK_STATEFILE:-}" ]] || return 0
        sgnd_state_set --file "$SGND_FRAMEWORK_STATEFILE" "$key" "$value"
    }

    _sgnd_console_cycle_console_loglevel() {
        local direction="${1:-1}"

        SGND_CONSOLE_LOG_LEVEL="$(_sgnd_console_cycle_loglevel_value             "${SGND_CONSOLE_LOG_LEVEL:-silent}"             "$direction")"
        _sgnd_console_persist_framework_value SGND_CONSOLE_LOG_LEVEL "$SGND_CONSOLE_LOG_LEVEL"
        SGND_LAST_WAITSECS=0
    }

    _sgnd_console_cycle_file_loglevel() {
        local direction="${1:-1}"

        SGND_FILE_LOG_LEVEL="$(_sgnd_console_cycle_loglevel_value             "${SGND_FILE_LOG_LEVEL:-silent}"             "$direction")"
        _sgnd_console_persist_framework_value SGND_FILE_LOG_LEVEL "$SGND_FILE_LOG_LEVEL"
        SGND_LAST_WAITSECS=0
    }

    _sgnd_console_theme_name() {
        local style="${SGND_UI_STYLE##*/}"

        style="${style%.sh}"
        if [[ "$style" =~ ^[0-9][0-9]-style-(.+)$ ]]; then
            style="${BASH_REMATCH[1]}"
        else
            style="${style#style-}"
            [[ "$style" == "default-ui-style" ]] && style="default"
        fi

        printf '%s' "$style"
    }

    _sgnd_console_cycle_theme() {
        local direction="${1:-1}"
        local current_file="${SGND_UI_STYLE##*/}"
        local candidate=""
        local theme_file=""
        local i=0
        local current_index=-1
        local next_index=0
        local -a theme_paths=()
        local -a theme_files=()

        shopt -s nullglob
        theme_paths=("${SGND_STYLE_DIR%/}"/[0-9][0-9]-style-*.sh)
        shopt -u nullglob

        (( ${#theme_paths[@]} > 0 )) || return 1

        mapfile -t theme_paths < <(
            printf '%s\n' "${theme_paths[@]}" | LC_ALL=C sort
        )

        for candidate in "${theme_paths[@]}"; do
            theme_files+=("${candidate##*/}")
        done

        if [[ ! "$current_file" =~ ^[0-9][0-9]-style-.+\.sh$ ]]; then
            current_file="${current_file%.sh}"
            current_file="${current_file#style-}"
            [[ "$current_file" == "default-ui-style" ]] && current_file="default"

            for candidate in "${theme_files[@]}"; do
                if [[ "$candidate" == [0-9][0-9]-style-"${current_file}".sh ]]; then
                    current_file="$candidate"
                    break
                fi
            done
        fi

        for i in "${!theme_files[@]}"; do
            if [[ "${theme_files[$i]}" == "$current_file" ]]; then
                current_index="$i"
                break
            fi
        done

        if (( current_index < 0 )); then
            if (( direction < 0 )); then
                current_index=0
            else
                current_index=-1
            fi
        fi

        next_index=$(( (current_index + direction + ${#theme_files[@]}) % ${#theme_files[@]} ))
        theme_file="${theme_files[$next_index]}"

        sgnd_theme "$theme_file" || return $?
        SGND_LAST_WAITSECS=0
    }

# --- Session actions ----------------------------------------------------------------
    # fn: _sgnd_console_set_lines_per_page - Set lines per page
        # . Purpose
        #   Prompt for and apply the number of menu lines available per page.
        #
        # . Returns
        #   0 on success; non-zero on cancellation or invalid input.
        #
        # . Usage
        #   _sgnd_console_set_lines_per_page
    _sgnd_console_set_lines_per_page() {
        local lines="${SGND_PAGE_MAX_ROWS:-15}"

        ask \
            --label "Lines per page" \
            --default "$lines" \
            --var lines || return $?

        if [[ ! "$lines" =~ ^[0-9]+$ ]] || (( lines < 5 )); then
            saywarning "Lines per page must be a whole number of at least 5"
            return 1
        fi

        SGND_PAGE_MAX_ROWS="$lines"
        SGND_PAGE_INDEX=0
        sayinfo "Menu lines per page set to $SGND_PAGE_MAX_ROWS"

        sgnd_state_set SGND_PAGE_MAX_ROWS "$SGND_PAGE_MAX_ROWS"
    }
    # fn: _sgnd_console_redraw - Console redraw
        # . Purpose
        #   Handle console menu redraw behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_redraw
    _sgnd_console_redraw() {
        return 0
    }
    # fn: _sgnd_console_quit - Console quit
        # . Purpose
        #   Handle console menu quit behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_quit
    _sgnd_console_quit() {
        return 200
    }
    # fn: _sgnd_console_nextpage - Console nextpage
        # . Purpose
        #   Handle console menu nextpage behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_nextpage
    _sgnd_console_nextpage() {
        _sgnd_console_build_pages

        if (( SGND_PAGE_INDEX < ${#SGND_PAGE_STARTS[@]} - 1 )); then
            SGND_PAGE_INDEX=$(( SGND_PAGE_INDEX + 1 ))
        fi

        return 0
    }
    # fn: _sgnd_console_prevpage - Console prevpage
        # . Purpose
        #   Handle console menu prevpage behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_prevpage
    _sgnd_console_prevpage() {
        if (( SGND_PAGE_INDEX > 0 )); then
            SGND_PAGE_INDEX=$(( SGND_PAGE_INDEX - 1 ))
        fi

        return 0
    }
# --- Menu model cache ---------------------------------------------------------------
    # _sgnd_console_refresh_model_cache
        # Purpose:
        #   Materialize the group and item datatables into direct-index arrays.
        #
        # Behavior:
        #   - Rebuilds only when the number of registered groups or items changes.
        #   - Splits every datatable row once per rebuild.
        #   - Provides direct array access during menu building and rendering.
        #
        # Returns:
        #   0 on success.
        #
        # Usage:
        #   _sgnd_console_refresh_model_cache
    _sgnd_console_refresh_model_cache() {
        local group_count="${#SGND_GROUP_ROWS[@]}"
        local item_count="${#SGND_ITEM_ROWS[@]}"
        local i
        local row=""
        local key=""
        local label=""
        local desc=""
        local source=""
        local builtin="0"
        local visible="1"
        local ord="1000"
        local group=""
        local handler=""
        local waitsecs="15"

        if (( SGND_CONSOLE_MODEL_CACHE_GROUP_COUNT == group_count &&
              SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT == item_count )); then
            return 0
        fi

        SGND_GROUP_CACHE_KEY=()
        SGND_GROUP_CACHE_LABEL=()
        SGND_GROUP_CACHE_BUILTIN=()
        SGND_GROUP_CACHE_VISIBLE=()
        SGND_GROUP_CACHE_ORD=()
        SGND_GROUP_CACHE_INDEX_BY_KEY=()

        for (( i=0; i<group_count; i++ )); do
            row="${SGND_GROUP_ROWS[$i]}"
            IFS='|' read -r key label desc source builtin visible ord <<< "$row"

            SGND_GROUP_CACHE_KEY[$i]="$key"
            SGND_GROUP_CACHE_LABEL[$i]="$label"
            SGND_GROUP_CACHE_BUILTIN[$i]="${builtin:-0}"
            SGND_GROUP_CACHE_VISIBLE[$i]="${visible:-1}"
            SGND_GROUP_CACHE_ORD[$i]="${ord:-1000}"
            SGND_GROUP_CACHE_INDEX_BY_KEY["$key"]="$i"
        done

        SGND_ITEM_CACHE_KEY=()
        SGND_ITEM_CACHE_GROUP=()
        SGND_ITEM_CACHE_LABEL=()
        SGND_ITEM_CACHE_HANDLER=()
        SGND_ITEM_CACHE_DESC=()
        SGND_ITEM_CACHE_BUILTIN=()
        SGND_ITEM_CACHE_WAITSECS=()
        SGND_ITEM_CACHE_VISIBLE=()

        for (( i=0; i<item_count; i++ )); do
            row="${SGND_ITEM_ROWS[$i]}"
            IFS='|' read -r key group label handler desc source builtin waitsecs visible <<< "$row"

            SGND_ITEM_CACHE_KEY[$i]="$key"
            SGND_ITEM_CACHE_GROUP[$i]="$group"
            SGND_ITEM_CACHE_LABEL[$i]="$label"
            SGND_ITEM_CACHE_HANDLER[$i]="$handler"
            SGND_ITEM_CACHE_DESC[$i]="$desc"
            SGND_ITEM_CACHE_BUILTIN[$i]="${builtin:-0}"
            SGND_ITEM_CACHE_WAITSECS[$i]="${waitsecs:-15}"
            SGND_ITEM_CACHE_VISIBLE[$i]="${visible:-1}"
        done

        SGND_CONSOLE_MODEL_CACHE_GROUP_COUNT="$group_count"
        SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT="$item_count"
        SGND_CONSOLE_MODEL_CACHE_GENERATION=$(( SGND_CONSOLE_MODEL_CACHE_GENERATION + 1 ))
        return 0
    }

# --- Menu model indexes -------------------------------------------------------------
    # fn: _sgnd_console_collect_group_render_indexes - Console collect group render indexes
        # . Purpose
        #   Render the console collect group indexes portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_collect_group_render_indexes
    _sgnd_console_collect_group_render_indexes() {
        _sgnd_console_refresh_model_cache

        if (( SGND_CONSOLE_GROUP_INDEX_CACHE_GENERATION == SGND_CONSOLE_MODEL_CACHE_GENERATION )); then
            return 0
        fi

        local i
        local row_count=0
        local builtin="0"
        local ord="1000"

        local -a sortable_rows=()
        local -a sorted_rows=()

        SGND_GROUP_RENDER_INDEXES=()

        row_count="${#SGND_GROUP_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            builtin="${SGND_GROUP_CACHE_BUILTIN[$i]}"
            ord="${SGND_GROUP_CACHE_ORD[$i]}"
            : "${ord:=1000}"

            # sort key = builtin bucket | ord | original row index
            # non-builtin first, builtin last
            sortable_rows+=("$(printf '%d|%08d|%08d' "$builtin" "$ord" "$i")")
        done

        if (( ${#sortable_rows[@]} == 0 )); then
            return 0
        fi

        mapfile -t sorted_rows < <(printf '%s\n' "${sortable_rows[@]}" | sort -t '|' -k1,1n -k2,2n -k3,3n)

        for i in "${!sorted_rows[@]}"; do
            SGND_GROUP_RENDER_INDEXES+=("$((10#${sorted_rows[$i]##*|}))")
        done

        SGND_CONSOLE_GROUP_INDEX_CACHE_GENERATION="$SGND_CONSOLE_MODEL_CACHE_GENERATION"
    }
    # fn: _sgnd_console_collect_visible_item_indexes - Console collect visible item indexes
        # . Purpose
        #   Handle console menu collect visible item indexes behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_collect_visible_item_indexes
    _sgnd_console_collect_visible_item_indexes() {
        _sgnd_console_refresh_model_cache

        if (( SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION == SGND_CONSOLE_MODEL_CACHE_GENERATION )); then
            return 0
        fi

        local gi
        local ii
        local item_row_count=0
        local group_key=""
        local group_builtin="0"
        local item_group=""
        local item_builtin="0"
        local item_state="1"

        SGND_VISIBLE_ITEM_INDEXES=()

        _sgnd_console_collect_group_render_indexes
        item_row_count="${#SGND_ITEM_ROWS[@]}"

        for gi in "${SGND_GROUP_RENDER_INDEXES[@]}"; do
            group_builtin="${SGND_GROUP_CACHE_BUILTIN[$gi]}"
            (( group_builtin )) && continue

            group_key="${SGND_GROUP_CACHE_KEY[$gi]}"

            for (( ii=0; ii<item_row_count; ii++ )); do
                item_group="${SGND_ITEM_CACHE_GROUP[$ii]}"
                [[ "$item_group" == "$group_key" ]] || continue

                item_builtin="${SGND_ITEM_CACHE_BUILTIN[$ii]}"
                (( item_builtin )) && continue

                item_state="${SGND_ITEM_CACHE_VISIBLE[$ii]}"
                case "$item_state" in
                    1|2)
                        SGND_VISIBLE_ITEM_INDEXES+=("$ii")
                        ;;
                esac
            done
        done

        SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION="$SGND_CONSOLE_MODEL_CACHE_GENERATION"
    }
    # fn: _sgnd_console_visible_item_count - Console visible item count
        # . Purpose
        #   Handle console menu visible item count behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_visible_item_count
    _sgnd_console_visible_item_count() {
        printf '%s\n' "${#SGND_VISIBLE_ITEM_INDEXES[@]}"
    }
    # fn: _sgnd_console_get_visible_row_index - Console get visible row index
        # . Purpose
        #   Handle console menu get visible row index behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  VISIBLE_INDEX - Zero-based index.
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
        #   _sgnd_console_get_visible_row_index "${VISIBLE_INDEX}"
    _sgnd_console_get_visible_row_index() {
        local visible_index="${1:?missing visible index}"

        if (( visible_index < 0 || visible_index >= ${#SGND_VISIBLE_ITEM_INDEXES[@]} )); then
            return 1
        fi

        printf '%s\n' "${SGND_VISIBLE_ITEM_INDEXES[$visible_index]}"
    }
    # fn: _sgnd_console_get_visible_display_number - Console get visible display number
        # . Purpose
        #   Handle console menu get visible display number behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  ROW_INDEX - Zero-based datatable row index.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   _sgnd_console_get_visible_display_number "${ROW_INDEX}"
    _sgnd_console_get_visible_display_number() {
        local row_index="${1:?missing row index}"
        local i

        for (( i=0; i<${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            if [[ "${SGND_VISIBLE_ITEM_INDEXES[$i]}" == "$row_index" ]]; then
                printf '%s\n' "$((i + 1))"
                return 0
            fi
        done

        return 1
    }
    # fn: _sgnd_console_find_visible_pos_for_row - Console find visible pos for row
        # . Purpose
        #   Handle console menu find visible pos for row behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  ROW_INDEX - Zero-based datatable row index.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   _sgnd_console_find_visible_pos_for_row "${ROW_INDEX}"
    _sgnd_console_find_visible_pos_for_row() {
        local row_index="${1:?missing row index}"
        local i

        for (( i=0; i<${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            if [[ "${SGND_VISIBLE_ITEM_INDEXES[$i]}" == "$row_index" ]]; then
                printf '%s\n' "$i"
                return 0
            fi
        done

        return 1
    }
    # fn: _sgnd_console_group_continues_after_visible_pos - Console group continues after visible pos
        # . Purpose
        #   Handle console menu group continues after visible pos behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  GROUP_KEY - Unique key or identifier.
        #   $2  LAST_VISIBLE_POS - Positional value used by this function.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   _sgnd_console_group_continues_after_visible_pos "${GROUP_KEY}" "${LAST_VISIBLE_POS}"
    _sgnd_console_group_continues_after_visible_pos() {
        local group_key="${1:?missing group key}"
        local last_visible_pos="${2:?missing visible position}"
        local i
        local row_index=0
        local item_group=""

        for (( i=last_visible_pos + 1; i<${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            row_index="${SGND_VISIBLE_ITEM_INDEXES[$i]}"
            item_group="${SGND_ITEM_CACHE_GROUP[$row_index]}"

            if [[ "$item_group" == "$group_key" ]]; then
                return 0
            fi
        done

        return 1
    }
# --- Menu layout measurement --------------------------------------------------------
    # fn: _sgnd_console_body_height - Console body height
        # . Purpose
        #   Handle console menu body height behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_body_height
    _sgnd_console_body_height() {
        local body_height="${SGND_PAGE_MAX_ROWS:-20}"

        (( body_height < 5 )) && body_height=5
        printf '%s\n' "$body_height"
    }
    # fn: _sgnd_console_measure_item_lines - Console measure item lines
        # . Purpose
        #   Handle console menu measure item lines behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  ROW_INDEX - Zero-based datatable row index.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_measure_item_lines "${ROW_INDEX}"
    _sgnd_console_measure_item_lines() {
        local row_index="${1:?missing row index}"
        local desc=""
        local term_width=80
        local left_width_max="${SGND_RENDER_LABEL_WIDTH:-28}"
        local gap=3
        local tpad=3
        local desc_width=0
        local wrapped_count=0
        local line=""

        desc="${SGND_ITEM_CACHE_DESC[$row_index]}"

        if [[ -z "$desc" ]]; then
            printf '1\n'
            return 0
        fi

        term_width="$(sgnd_terminal_width)"
        desc_width=$(( term_width - tpad - left_width_max - gap ))
        (( desc_width < 20 )) && desc_width=20

        while IFS= read -r line; do
            wrapped_count=$(( wrapped_count + 1 ))
        done < <(sgnd_wrap_words --width "$desc_width" --text "$desc")

        (( wrapped_count < 1 )) && wrapped_count=1
        printf '%s\n' "$wrapped_count"
    }
    # fn: _sgnd_console_measure_group_header_lines - Console measure group header lines
        # . Purpose
        #   Handle console menu measure group header lines behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_measure_group_header_lines
    _sgnd_console_measure_group_header_lines() {
        # group label + underline
        printf '2\n'
    }
    # fn: _sgnd_console_calc_label_width - Console calc label width
        # . Purpose
        #   Handle console menu calc label width behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_calc_label_width
    _sgnd_console_calc_label_width() {
        _sgnd_console_collect_visible_item_indexes

        if (( SGND_CONSOLE_LABEL_WIDTH_CACHE_GENERATION == SGND_CONSOLE_MODEL_CACHE_GENERATION )); then
            printf '%s\n' "$SGND_CONSOLE_LABEL_WIDTH_CACHE_VALUE"
            return 0
        fi

        local i
        local row_count=0
        local builtin="0"
        local display_key=""
        local label=""
        local left_text=""
        local width=0
        local max_width=0

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            builtin="${SGND_ITEM_CACHE_BUILTIN[$i]}"

            if (( builtin )); then
                display_key="${SGND_ITEM_CACHE_KEY[$i]}"
            else
                display_key="$(_sgnd_console_get_visible_display_number "$i" 2>/dev/null)" || continue
            fi

            label="${SGND_ITEM_CACHE_LABEL[$i]}"
            left_text="${display_key}) ${label}"
            width="$(sgnd_visible_length "$left_text")"

            (( width > max_width )) && max_width="$width"
        done

        (( max_width > 35 )) && max_width=35
        SGND_CONSOLE_LABEL_WIDTH_CACHE_VALUE="$max_width"
        SGND_CONSOLE_LABEL_WIDTH_CACHE_GENERATION="$SGND_CONSOLE_MODEL_CACHE_GENERATION"
        printf '%s\n' "$max_width"
    }
# --- Menu pagination ----------------------------------------------------------------
    # fn: _sgnd_console_build_pages - Console build pages
        # . Purpose
        #   Handle console menu build pages behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_build_pages
    _sgnd_console_build_pages() {
        local body_height=0
        local term_width=80
        local label_width=28
        local layout_cache_key=""
        local used_lines=0
        local visible_count=0
        local visible_i=0
        local row_index=0
        local group_key=""
        local current_group=""
        local item_lines=0
        local header_lines=0
        local needed_lines=0
        local page_index=0
        local page_row_offset=0
        local page_group_offset=0

        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes

        visible_count="${#SGND_VISIBLE_ITEM_INDEXES[@]}"
        body_height="$(_sgnd_console_body_height)"
        term_width="$(sgnd_terminal_width)"
        label_width="${SGND_RENDER_LABEL_WIDTH:-28}"
        layout_cache_key="${SGND_CONSOLE_MODEL_CACHE_GENERATION}|${SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION}|${body_height}|${term_width}|${label_width}"

        if [[ "$SGND_CONSOLE_LAYOUT_CACHE_KEY" == "$layout_cache_key" ]]; then
            return 0
        fi

        SGND_PAGE_STARTS=()
        SGND_PAGE_ROW_OFFSETS=()
        SGND_PAGE_ROW_COUNTS=()
        SGND_PAGE_ROWS=()
        SGND_PAGE_GROUP_OFFSETS=()
        SGND_PAGE_GROUP_COUNTS=()
        SGND_PAGE_GROUPS=()

        if (( visible_count == 0 )); then
            SGND_CONSOLE_LAYOUT_CACHE_KEY="$layout_cache_key"
            return 0
        fi

        SGND_PAGE_STARTS+=(0)
        SGND_PAGE_ROW_OFFSETS+=(0)
        SGND_PAGE_GROUP_OFFSETS+=(0)

        for (( visible_i=0; visible_i<visible_count; visible_i++ )); do
            row_index="${SGND_VISIBLE_ITEM_INDEXES[$visible_i]}"
            group_key="${SGND_ITEM_CACHE_GROUP[$row_index]}"
            item_lines="$(_sgnd_console_measure_item_lines "$row_index")"
            needed_lines="$item_lines"

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                needed_lines=$(( needed_lines + header_lines ))
            fi

            if (( used_lines + needed_lines > body_height && used_lines > 0 )); then
                SGND_PAGE_ROW_COUNTS+=("$(( ${#SGND_PAGE_ROWS[@]} - page_row_offset ))")
                SGND_PAGE_GROUP_COUNTS+=("$(( ${#SGND_PAGE_GROUPS[@]} - page_group_offset ))")

                page_index=$(( page_index + 1 ))
                page_row_offset="${#SGND_PAGE_ROWS[@]}"
                page_group_offset="${#SGND_PAGE_GROUPS[@]}"
                SGND_PAGE_STARTS+=("$visible_i")
                SGND_PAGE_ROW_OFFSETS+=("$page_row_offset")
                SGND_PAGE_GROUP_OFFSETS+=("$page_group_offset")
                used_lines=0
                current_group=""
            fi

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                SGND_PAGE_GROUPS+=("$group_key")
                used_lines=$(( used_lines + header_lines ))
                current_group="$group_key"
            fi

            SGND_PAGE_ROWS+=("$row_index")
            used_lines=$(( used_lines + item_lines ))
        done

        SGND_PAGE_ROW_COUNTS+=("$(( ${#SGND_PAGE_ROWS[@]} - page_row_offset ))")
        SGND_PAGE_GROUP_COUNTS+=("$(( ${#SGND_PAGE_GROUPS[@]} - page_group_offset ))")
        SGND_CONSOLE_LAYOUT_CACHE_KEY="$layout_cache_key"
    }
# --- Menu rendering -----------------------------------------------------------------
    # fn: _sgnd_console_render_menu - Console render menu
        # . Purpose
        #   Render the console menu portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_render_menu
    _sgnd_console_render_menu() {
        _sgnd_console_refresh_model_cache
        local idx=""
        local group_key=""
        local builtin="0"

        #_sgnd_console_refresh_builtin_labels
        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes
        SGND_RENDER_LABEL_WIDTH="$(_sgnd_console_calc_label_width)"

        _sgnd_console_render_menu_title
        _sgnd_console_render_menu_body_paged

        for idx in "${SGND_GROUP_RENDER_INDEXES[@]}"; do
            builtin="${SGND_GROUP_CACHE_BUILTIN[$idx]}"
            (( builtin )) || continue

            group_key="${SGND_GROUP_CACHE_KEY[$idx]}"
            _sgnd_console_render_group "$group_key"
        done

        _sgnd_console_render_togglebar
    }
    # fn: _sgnd_console_render_menu_title - Console render menu title
        # . Purpose
        #   Render the console menu title portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_render_menu_title
    _sgnd_console_render_menu_title() {
        (( ! SGND_CLEAR_ONRENDER )) || clear
        
        local width=80
        width="$(sgnd_terminal_width)"

        sgnd_print_sectionheader --border "$DL_H" --maxwidth "$width"
        sgnd_print --pad 4 "$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")${SGND_CONSOLE_TITLE}${RESET}" --maxwidth "$width"
        sgnd_print --pad 4 "$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")${SGND_CONSOLE_DESC}" --maxwidth "$width"
        sgnd_print_sectionheader --border "$LN_H" --maxwidth "$width"
        sgnd_print
    }
    # fn: _sgnd_console_render_menu_body_paged - Console render menu body paged
        # . Purpose
        #   Render the console menu body paged portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_render_menu_body_paged
    _sgnd_console_render_menu_body_paged() {
        local visible_count=0
        local page_row_offset=0
        local page_row_count=0
        local page_group_offset=0
        local page_group_count=0
        local i=0

        local -a page_rows=()
        local -a page_groups=()

        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes
        _sgnd_console_build_pages

        visible_count="${#SGND_VISIBLE_ITEM_INDEXES[@]}"
        SGND_PAGE_HAS_PREV=0
        SGND_PAGE_HAS_NEXT=0

        if (( visible_count == 0 )); then
            return 0
        fi

        if (( SGND_PAGE_INDEX < 0 || SGND_PAGE_INDEX >= ${#SGND_PAGE_STARTS[@]} )); then
            SGND_PAGE_INDEX=0
        fi

        (( SGND_PAGE_INDEX > 0 )) && SGND_PAGE_HAS_PREV=1
        (( SGND_PAGE_INDEX < ${#SGND_PAGE_STARTS[@]} - 1 )) && SGND_PAGE_HAS_NEXT=1

        page_row_offset="${SGND_PAGE_ROW_OFFSETS[$SGND_PAGE_INDEX]:-0}"
        page_row_count="${SGND_PAGE_ROW_COUNTS[$SGND_PAGE_INDEX]:-0}"
        page_group_offset="${SGND_PAGE_GROUP_OFFSETS[$SGND_PAGE_INDEX]:-0}"
        page_group_count="${SGND_PAGE_GROUP_COUNTS[$SGND_PAGE_INDEX]:-0}"

        for (( i=0; i<page_row_count; i++ )); do
            page_rows+=("${SGND_PAGE_ROWS[$((page_row_offset + i))]}")
        done

        for (( i=0; i<page_group_count; i++ )); do
            page_groups+=("${SGND_PAGE_GROUPS[$((page_group_offset + i))]}")
        done

        _sgnd_console_render_page_rows page_groups page_rows
    }
    # fn: _sgnd_console_render_page_rows - Console render page rows
        # . Purpose
        #   Render the console page rows portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #   $2  ARG2 - Positional value used by this function.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_render_page_rows "${ARG1}" "${ARG2}"
    _sgnd_console_render_page_rows() {
        local -n _page_groups="$1"
        local -n _page_rows="$2"

        local group_key=""
        local row_index=0
        local label=""
        local desc=""
        local display_key=""
        local item_group=""
        local item_state="1"

        local left_text=""
        local left_width=0
        local left_width_max="${SGND_RENDER_LABEL_WIDTH:-28}"
        local desc_width=0
        local term_width=80
        local gap=3
        local tpad=3

        local label_style=""
        local value_style=""
        local normal_label_style="$(sgnd_sgr "$SGND_UI_LABEL")"
        local normal_value_style="$(sgnd_sgr "$SGND_UI_VALUE" "" "$FX_ITALIC")"
        local disabled_label_style="$(sgnd_sgr "$SGND_UI_DISABLED")"
        local disabled_value_style="$(sgnd_sgr "$SGND_UI_DISABLED" "" "$FX_FAINT" "$FX_ITALIC")"

        local wrapped_line=""
        local first_line=1
        local group_label=""
        local group_label_display=""
        local gi

        local group_last_row_index=-1
        local group_last_visible_pos=-1

        term_width="$(sgnd_terminal_width)"
        desc_width=$(( term_width - tpad - left_width_max - gap ))
        (( desc_width < 20 )) && desc_width=20

        for group_key in "${_page_groups[@]}"; do
            group_label=""
            group_last_row_index=-1
            group_last_visible_pos=-1

            gi="${SGND_GROUP_CACHE_INDEX_BY_KEY[$group_key]:--1}"
            if (( gi >= 0 )); then
                group_label="${SGND_GROUP_CACHE_LABEL[$gi]}"
            fi

            [[ -n "$group_label" ]] || continue

            for row_index in "${_page_rows[@]}"; do
                item_group="${SGND_ITEM_CACHE_GROUP[$row_index]}"
                [[ "$item_group" == "$group_key" ]] || continue
                group_last_row_index="$row_index"
            done

            group_label_display="$group_label"

            if (( group_last_row_index >= 0 )); then
                group_last_visible_pos="$(_sgnd_console_find_visible_pos_for_row "$group_last_row_index" 2>/dev/null || printf '%s' '-1')"

                if (( group_last_visible_pos >= 0 )); then
                    if _sgnd_console_group_continues_after_visible_pos "$group_key" "$group_last_visible_pos"; then
                        group_label_display="${group_label} ....."
                    fi
                fi
            fi

            sgnd_print --text "$group_label_display"
            left_width="$(sgnd_visible_length "$group_label_display")"
            sgnd_print_sectionheader --border "$LN_H" --maxwidth "$left_width"

            for row_index in "${_page_rows[@]}"; do
                item_group="${SGND_ITEM_CACHE_GROUP[$row_index]}"
                [[ "$item_group" == "$group_key" ]] || continue

                item_state="${SGND_ITEM_CACHE_VISIBLE[$row_index]}"
                case "$item_state" in
                    1|2) ;;
                    *) continue ;;
                esac

                display_key="$(_sgnd_console_get_visible_display_number "$row_index")" || continue

                if (( item_state == 2 )); then
                    label_style="$disabled_label_style"
                    value_style="$disabled_value_style"
                else
                    label_style="$normal_label_style"
                    value_style="$normal_value_style"
                fi

                label="${SGND_ITEM_CACHE_LABEL[$row_index]}"
                desc="${SGND_ITEM_CACHE_DESC[$row_index]}"
                left_text="${display_key}) ${label}"

                if [[ -z "$desc" ]]; then
                    printf '%*s%s' "$tpad" "" "$label_style"
                    sgnd_padded_visible "$left_text" "$left_width_max"
                    printf '%s\n' "$RESET"
                    continue
                fi

                first_line=1
                while IFS= read -r wrapped_line; do
                    if (( first_line )); then
                        printf '%*s%s' "$tpad" "" "$label_style"
                        sgnd_padded_visible "$left_text" "$left_width_max"
                        printf '%s%*s%s%s%s\n' \
                            "$RESET" \
                            "$gap" "" \
                            "$value_style" "$wrapped_line" "$RESET"
                        first_line=0
                    else
                        printf '%*s%*s%*s%s%s%s\n' \
                            "$tpad" "" \
                            "$left_width_max" "" \
                            "$gap" "" \
                            "$value_style" "$wrapped_line" "$RESET"
                    fi
                done < <(sgnd_wrap_words --width "$desc_width" --text "$desc")
            done

            sgnd_print
        done
    }
    # fn: _sgnd_console_render_group - Console render group
        # . Purpose
        #   Render the console group portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  GROUP_KEY - Unique key or identifier.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_render_group "${GROUP_KEY}"
    _sgnd_console_render_group() {
        local group_key="${1:?missing group key}"
        local _tpad=3

        local gi
        local ii
        local row_count=0
        local label=""
        local desc=""
        local group_label=""
        local found_group=0
        local group_state=1
        local display_key=""
        local item_group=""
        local builtin="0"
        local item_state="1"
        local has_renderable_items=0

        local left_text=""
        local left_width=0
        local left_width_max="${SGND_RENDER_LABEL_WIDTH:-28}"
        local desc_width=0
        local term_width=80
        local gap=3

        local label_style=""
        local value_style=""
        local normal_label_style="$(sgnd_sgr "$SGND_UI_LABEL")"
        local normal_value_style="$(sgnd_sgr "$SGND_UI_VALUE" "" "$FX_ITALIC")"
        local disabled_label_style="$(sgnd_sgr "$SGND_UI_DISABLED")"
        local disabled_value_style="$(sgnd_sgr "$SGND_UI_DISABLED" "" "$FX_FAINT" "$FX_ITALIC")"

        row_count="${#SGND_GROUP_ROWS[@]}"

        for (( gi=0; gi<row_count; gi++ )); do
            if [[ "${SGND_GROUP_CACHE_KEY[$gi]}" == "$group_key" ]]; then
                group_label="${SGND_GROUP_CACHE_LABEL[$gi]}"
                group_state="${SGND_GROUP_CACHE_VISIBLE[$gi]}"
                found_group=1
                break
            fi
        done

        (( found_group )) || return 0
        (( group_state != 0 )) || return 0

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( ii=0; ii<row_count; ii++ )); do
            item_group="${SGND_ITEM_CACHE_GROUP[$ii]}"
            [[ "$item_group" == "$group_key" ]] || continue

            item_state="${SGND_ITEM_CACHE_VISIBLE[$ii]}"
            case "$item_state" in
                1|2)
                    has_renderable_items=1
                    break
                    ;;
            esac
        done

        (( has_renderable_items )) || return 0

        term_width="$(sgnd_terminal_width)"
        desc_width=$(( term_width - _tpad - left_width_max - gap ))
        (( desc_width < 20 )) && desc_width=20

        sgnd_print --text "$group_label"
        left_width="$(sgnd_visible_length "$group_label")"
        sgnd_print_sectionheader --border "$LN_H" --maxwidth "$left_width"

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( ii=0; ii<row_count; ii++ )); do
            item_group="${SGND_ITEM_CACHE_GROUP[$ii]}"
            [[ "$item_group" == "$group_key" ]] || continue

            item_state="${SGND_ITEM_CACHE_VISIBLE[$ii]}"
            case "$item_state" in
                1|2) ;;
                *) continue ;;
            esac

            builtin="${SGND_ITEM_CACHE_BUILTIN[$ii]}"

            if (( builtin )); then
                display_key="${SGND_ITEM_CACHE_KEY[$ii]}"
            else
                display_key="$(_sgnd_console_get_visible_display_number "$ii")" || continue
            fi

            if (( item_state == 2 )); then
                label_style="$disabled_label_style"
                value_style="$disabled_value_style"
            else
                label_style="$normal_label_style"
                value_style="$normal_value_style"
            fi

            label="${SGND_ITEM_CACHE_LABEL[$ii]}"
            desc="${SGND_ITEM_CACHE_DESC[$ii]}"
            left_text="${display_key}) ${label}"

            if [[ -z "$desc" ]]; then
                printf '%*s%s' "$_tpad" "" "$label_style"
                sgnd_padded_visible "$left_text" "$left_width_max"
                printf '%s\n' "$RESET"
                continue
            fi

            local first_line=1
            local wrapped_line=""

            while IFS= read -r wrapped_line; do
                if (( first_line )); then
                    printf '%*s%s' "$_tpad" "" "$label_style"
                    sgnd_padded_visible "$left_text" "$left_width_max"
                    printf '%s%*s%s%s%s\n' \
                        "$RESET" \
                        "$gap" "" \
                        "$value_style" "$wrapped_line" "$RESET"
                    first_line=0
                else
                    printf '%*s%*s%*s%s%s%s\n' \
                        "$_tpad" "" \
                        "$left_width_max" "" \
                        "$gap" "" \
                        "$value_style" "$wrapped_line" "$RESET"
                fi
            done < <(sgnd_wrap_words --width "$desc_width" --text "$desc")
        done

        sgnd_print
    }
    # fn: _sgnd_console_render_togglebar - Console render togglebar
        # . Purpose
        #   Render the console togglebar portion of the current workflow.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_render_togglebar
    _sgnd_console_render_togglebar() {
        local render_width=80
        local pad=3
        local gap=3
        local dryrun_text=""
        local console_text=""
        local file_text=""
        local theme_text=""
        local access_text=""
        local clearscr_text=""
        local prevtext=""
        local nexttext=""
        local page_text=""
        local bar_text=""
        local visible_len=0
        local left_pad=0
        local prev_enabled=0
        local next_enabled=0
        local page_count="${#SGND_PAGE_STARTS[@]}"
        local seg=""
        local -a segments=()

        render_width="$(sgnd_terminal_width)"
        dryrun_text="$(_sgnd_console_toggleword "DRYRUN" "D" "${FLAG_DRYRUN:-0}" "${SGND_UI_DRYRUN}" "${SGND_UI_COMMIT}")"
        console_text="$(_sgnd_console_toggleword \
            "CONSOLE(${SGND_CONSOLE_LOG_LEVEL^^})" \
            "C" \
            "$([[ "${SGND_CONSOLE_LOG_LEVEL:-silent}" != "silent" ]] && printf 1 || printf 0)" \
            "$GREEN" \
            "$DARK_GRAY")"
        file_text="$(_sgnd_console_toggleword \
            "FILE(${SGND_FILE_LOG_LEVEL^^})" \
            "F" \
            "$([[ "${SGND_FILE_LOG_LEVEL:-silent}" != "silent" ]] && printf 1 || printf 0)" \
            "$GREEN" \
            "$DARK_GRAY")"
        theme_text="$(_sgnd_console_toggleword \
            "THEME($(_sgnd_console_theme_name | tr '[:lower:]' '[:upper:]'))" \
            "T" \
            0 \
            "$SGND_UI_TEXT" \
            "$SGND_UI_TEXT")"
        if (( EUID == 0 )); then
            if _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"; then
                access_text="$(_sgnd_console_toggleword "ACCESS(ROOT)" "A" 1 "$SGND_UI_COMMIT" "$SGND_UI_COMMIT")"
            else
                access_text="$(_sgnd_console_toggleword "ACCESS(ROOT)" "A" 1 "$RED" "$RED")"
            fi
        else
            if _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"; then
                access_text="$(_sgnd_console_toggleword "ACCESS(STANDARD)" "A" 1 "$GREEN" "$GREEN")"
            else
                access_text="$(_sgnd_console_toggleword "ACCESS(STANDARD)" "A" 1 "$SGND_UI_COMMIT" "$SGND_UI_COMMIT")"
            fi
        fi

        (( SGND_PAGE_INDEX > 0 )) && prev_enabled=1
        (( SGND_PAGE_INDEX + 1 < page_count )) && next_enabled=1
        prevtext="$(_sgnd_console_toggleword "<<PREV" "<" "$prev_enabled")"
        nexttext="$(_sgnd_console_toggleword "NEXT>>" ">" "$next_enabled")"

        segments+=("$access_text" "$dryrun_text" "$console_text" "$file_text" "$theme_text")
        if (( page_count > 1 )); then
            page_text="$(sgnd_sgr "$SILVER" "" "$FX_ITALIC")Page $((SGND_PAGE_INDEX + 1))/$page_count${RESET}"
            segments=("$prevtext" "${segments[@]}" "$page_text" "$nexttext")
        fi

        for seg in "${segments[@]}"; do
            [[ -z "$bar_text" ]] || bar_text+="$(sgnd_string_repeat ' ' "$gap")"
            bar_text+="$seg"
        done

        visible_len="$(sgnd_visible_length "$bar_text")"
        left_pad=$(( (render_width - visible_len) / 2 ))
        (( left_pad < pad )) && left_pad="$pad"

        sgnd_print_sectionheader --border "$DL_H" --maxwidth "$render_width"
        printf '%*s%s\n' "$left_pad" "" "$bar_text"
    }
# --- Menu input and dispatch --------------------------------------------------------
    # fn: _sgnd_console_valid_choices_csv - Console valid choices csv
        # . Purpose
        #   Handle console menu valid choices csv behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_console_valid_choices_csv
    _sgnd_console_valid_choices_csv() {
        local i
        local out=""
        local row_count=0
        local builtin="0"
        local key=""

        _sgnd_console_collect_visible_item_indexes

        for (( i=1; i<=${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            [[ -n "$out" ]] && out+=","
            out+="$i"
        done

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            builtin="${SGND_ITEM_CACHE_BUILTIN[$i]}"
            (( builtin )) || continue

            key="${SGND_ITEM_CACHE_KEY[$i]}"
            [[ -n "$out" ]] && out+=","
            out+="$key"
        done

        printf '%s' "$out"
    }
    # fn: _sgnd_console_dispatch - Console dispatch
        # . Purpose
        #   Handle console menu dispatch behavior.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  CHOICE - Positional value used by this function.
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
        #   _sgnd_console_dispatch "${CHOICE}"
    _sgnd_console_dispatch() {
        _sgnd_console_refresh_model_cache

        local choice="${1:?missing choice}"
        local handler=""
        local label=""
        local state="1"
        local row_index=0
        local i
        local row_count=0
        local key=""

        case "$choice" in
            $'\e[D')
                _sgnd_console_prevpage
                return $?
                ;;
            $'\e[C')
                _sgnd_console_nextpage
                return $?
                ;;
            c)
                _sgnd_console_cycle_console_loglevel 1
                return $?
                ;;
            C)
                _sgnd_console_cycle_console_loglevel -1
                return $?
                ;;
            f)
                _sgnd_console_cycle_file_loglevel 1
                return $?
                ;;
            F)
                _sgnd_console_cycle_file_loglevel -1
                return $?
                ;;
            t)
                _sgnd_console_cycle_theme 1
                return $?
                ;;
            T)
                _sgnd_console_cycle_theme -1
                return $?
                ;;
        esac

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            _sgnd_console_collect_visible_item_indexes

            if (( choice < 1 || choice > ${#SGND_VISIBLE_ITEM_INDEXES[@]} )); then
                saywarning "Invalid selection: $choice"
                return 1
            fi

            row_index="${SGND_VISIBLE_ITEM_INDEXES[$((choice - 1))]}"
            label="${SGND_ITEM_CACHE_LABEL[$row_index]}"
            state="${SGND_ITEM_CACHE_VISIBLE[$row_index]}"

            if (( state == 2 )); then
                saywarning "Option disabled: $label"
                return 1
            fi

            handler="${SGND_ITEM_CACHE_HANDLER[$row_index]}"
            SGND_LAST_WAITSECS="${SGND_ITEM_CACHE_WAITSECS[$row_index]}"
            "$handler"
            return $?
        fi

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            key="${SGND_ITEM_CACHE_KEY[$i]}"

            if [[ "${choice^^}" == "${key^^}" ]]; then
                state="${SGND_ITEM_CACHE_VISIBLE[$i]}"
                label="${SGND_ITEM_CACHE_LABEL[$i]}"

                if (( state == 2 )); then
                    saywarning "Option disabled: $label"
                    return 1
                fi

                handler="${SGND_ITEM_CACHE_HANDLER[$i]}"
                SGND_LAST_WAITSECS="${SGND_ITEM_CACHE_WAITSECS[$i]}"
                "$handler"
                return $?
            fi
        done

        saywarning "Invalid selection: $choice"
        return 1
    }


