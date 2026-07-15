# =====================================================================================
# SolidGroundUX - Console Menu System
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2619601
#   Checksum    : 683b61101dda203d94fe2b4ffd7346e6a992161c1641df16292c763077117861
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
    _sgnd_console_set_file_loglevel() {
        local level="${SGND_FILE_LOG_LEVEL:-silent}"

        ask_choose \
            --label "File log level" \
            --choices "silent,quiet,normal,verbose,debug,trace" \
            --default "$level" \
            --var level || return $?

        SGND_FILE_LOG_LEVEL="$level"

        if [[ -n "${SGND_FRAMEWORK_STATEFILE:-}" ]]; then
            sgnd_state_set \
                --file "$SGND_FRAMEWORK_STATEFILE" \
                SGND_FILE_LOG_LEVEL \
                "$SGND_FILE_LOG_LEVEL" || return 1
        fi

        sayinfo "File log level set to $SGND_FILE_LOG_LEVEL"
    }
# --- Session actions ----------------------------------------------------------------
    # fn: _sgnd_console_set_theme - Set console theme
        # . Purpose
        #   Prompt for and apply the active SolidGroundUX UI theme.
        #
        # . Behavior
        #   - Enumerates the installed themes.
        #   - Uses the currently active theme as the default.
        #   - Prompts the user to select a theme.
        #   - Applies the selected theme immediately.
        #   - Persists the selected theme to the framework state when available.
        #
        # Inputs (globals):
        #   SGND_UI_STYLE
        #   SGND_STYLE_DIR
        #   SGND_FRAMEWORK_STATEFILE
        #
        # Outputs (globals):
        #   SGND_UI_STYLE
        #
        # Side effects:
        #   May reload the active UI style.
        #   May update SGND_FRAMEWORK_STATEFILE.
        #
        # . Returns
        #   0 when the theme is selected and applied successfully.
        #   Non-zero when the prompt is cancelled, no themes are available, or the selected theme cannot be applied.
        #
        # . Usage
        #   _sgnd_console_set_theme
    _sgnd_console_set_theme() {
        local current_theme=""
        local theme=""
        local choices=""

        current_theme="${SGND_UI_STYLE##*/}"
        current_theme="${current_theme%.sh}"
        current_theme="${current_theme#style-}"

        [[ "${SGND_UI_STYLE##*/}" == "default-ui-style.sh" ]] && current_theme="default"

        while IFS= read -r theme; do
            [[ -n "$choices" ]] && choices+=","
            choices+="$theme"
        done < <(
            find "$SGND_STYLE_DIR" -maxdepth 1 -type f \
                \( -name 'default-ui-style.sh' -o -name 'style-*.sh' \) \
                | sort \
                | while IFS= read -r file; do
                    theme="${file##*/}"
                    theme="${theme%.sh}"
                    theme="${theme#style-}"
                    [[ "$theme" == "default-ui-style" ]] && theme="default"
                    printf '%s\n' "$theme"
                done
        )

        [[ -n "$choices" ]] || {
            saywarning "No themes found in $SGND_STYLE_DIR"
            return 1
        }

        ask_choose \
            --label "Theme" \
            --choices "$choices" \
            --default "$current_theme" \
            --var theme || return $?

        sgnd_theme "$theme" || return $?

        if [[ -n "${SGND_FRAMEWORK_STATEFILE:-}" ]]; then
            sgnd_state_set \
                --file "$SGND_FRAMEWORK_STATEFILE" \
                SGND_UI_STYLE \
                "$SGND_UI_STYLE" || return 1
        fi

        sayinfo "Theme set to $theme"
    }
    # fn: _sgnd_console_set_lines_per_page - Set menu lines per page
        # . Purpose
        #   Set the maximum number of rendered menu lines per page.
        #
        # . Behavior
        #   - Prompts for a new page height using the current value as the default.
        #   - Requires a whole number of at least 5.
        #   - Resets paging to the first page after a successful change.
        #
        # Outputs (globals):
        #   SGND_PAGE_MAX_ROWS
        #   SGND_PAGE_INDEX
        #
        # . Returns
        #   0 when the page height is updated.
        #   1 when the entered value is invalid.
        #   Non-zero when input is cancelled or fails.
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
        local i
        local row_count=0
        local builtin="0"
        local ord="1000"

        local -a sortable_rows=()
        local -a sorted_rows=()

        SGND_GROUP_RENDER_INDEXES=()

        row_count="$(sgnd_dt_row_count SGND_GROUP_ROWS)"

        for (( i=0; i<row_count; i++ )); do
            builtin="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$i" builtin)"
            ord="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$i" ord)"
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
            SGND_GROUP_RENDER_INDEXES+=("${sorted_rows[$i]##*|}")
        done
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
        item_row_count="$(sgnd_dt_row_count SGND_ITEM_ROWS)"

        for gi in "${SGND_GROUP_RENDER_INDEXES[@]}"; do
            group_builtin="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" builtin)"
            (( group_builtin )) && continue

            group_key="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" key)"

            for (( ii=0; ii<item_row_count; ii++ )); do
                item_group="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" group)"
                [[ "$item_group" == "$group_key" ]] || continue

                item_builtin="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" builtin)"
                (( item_builtin )) && continue

                item_state="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" visible)"
                case "$item_state" in
                    1|2)
                        SGND_VISIBLE_ITEM_INDEXES+=("$ii")
                        ;;
                esac
            done
        done
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
            item_group="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" group)"

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

        desc="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" desc)"

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
        local i
        local row_count=0
        local builtin="0"
        local display_key=""
        local label=""
        local left_text=""
        local width=0
        local max_width=0

        row_count="$(sgnd_dt_row_count SGND_ITEM_ROWS)"

        for (( i=0; i<row_count; i++ )); do
            builtin="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" builtin)"

            if (( builtin )); then
                display_key="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" key)"
            else
                display_key="$(_sgnd_console_get_visible_display_number "$i" 2>/dev/null)" || continue
            fi

            label="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" label)"
            left_text="${display_key}) ${label}"
            width="$(sgnd_visible_length "$left_text")"

            (( width > max_width )) && max_width="$width"
        done

        (( max_width > 35 )) && max_width=35
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
        local used_lines=0
        local visible_count=0
        local visible_i=0
        local row_index=0
        local group_key=""
        local current_group=""
        local item_lines=0
        local header_lines=0
        local needed_lines=0

        SGND_PAGE_STARTS=()

        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes

        visible_count="${#SGND_VISIBLE_ITEM_INDEXES[@]}"
        body_height="$(_sgnd_console_body_height)"

        (( visible_count == 0 )) && return 0

        SGND_PAGE_STARTS+=(0)

        for (( visible_i=0; visible_i<visible_count; visible_i++ )); do
            row_index="${SGND_VISIBLE_ITEM_INDEXES[$visible_i]}"
            group_key="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" group)"
            item_lines="$(_sgnd_console_measure_item_lines "$row_index")"

            needed_lines="$item_lines"

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                needed_lines=$(( needed_lines + header_lines ))
            fi

            if (( used_lines + needed_lines > body_height )); then
                SGND_PAGE_STARTS+=("$visible_i")
                used_lines=0
                current_group=""
            fi

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                used_lines=$(( used_lines + header_lines ))
                current_group="$group_key"
            fi

            used_lines=$(( used_lines + item_lines ))
        done
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
            builtin="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$idx" builtin)"
            (( builtin )) || continue

            group_key="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$idx" key)"
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
        sgnd_print --pad 4 "$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")${SGND_CONSOLE_TITLE}${RESET}"
        sgnd_print --pad 4 "$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")${SGND_CONSOLE_DESC}"
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
        local body_height=0
        local used_lines=0

        local visible_count=0
        local visible_i=0
        local row_index=0
        local group_key=""
        local current_group=""
        local item_lines=0
        local header_lines=0
        local needed_lines=0

        local pending_group=""
        local -a page_rows=()
        local -a page_groups=()

        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes
        _sgnd_console_build_pages

        visible_count="${#SGND_VISIBLE_ITEM_INDEXES[@]}"
        body_height="$(_sgnd_console_body_height)"

        SGND_PAGE_HAS_PREV=0
        SGND_PAGE_HAS_NEXT=0

        if (( visible_count == 0 )); then
            return 0
        fi

        if (( SGND_PAGE_INDEX < 0 )); then
            SGND_PAGE_INDEX=0
        fi

        if (( SGND_PAGE_INDEX >= ${#SGND_PAGE_STARTS[@]} )); then
            SGND_PAGE_INDEX=0
        fi

        (( SGND_PAGE_INDEX > 0 )) && SGND_PAGE_HAS_PREV=1
        (( SGND_PAGE_INDEX < ${#SGND_PAGE_STARTS[@]} - 1 )) && SGND_PAGE_HAS_NEXT=1

        local page_start_item=0
        local page_end_item="$visible_count"

        page_start_item="${SGND_PAGE_STARTS[$SGND_PAGE_INDEX]}"

        if (( SGND_PAGE_INDEX < ${#SGND_PAGE_STARTS[@]} - 1 )); then
            page_end_item="${SGND_PAGE_STARTS[$((SGND_PAGE_INDEX + 1))]}"
        fi

        for (( visible_i=page_start_item; visible_i<page_end_item; visible_i++ )); do
            row_index="${SGND_VISIBLE_ITEM_INDEXES[$visible_i]}"
            group_key="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" group)"
            item_lines="$(_sgnd_console_measure_item_lines "$row_index")"

            needed_lines="$item_lines"

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                needed_lines=$(( needed_lines + header_lines ))
            fi

            if [[ "$group_key" != "$current_group" ]]; then
                page_groups+=("$group_key")
                current_group="$group_key"
                used_lines=$(( used_lines + header_lines ))
            fi

            page_rows+=("$row_index")
            used_lines=$(( used_lines + item_lines ))
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

            for (( gi=0; gi<$(sgnd_dt_row_count SGND_GROUP_ROWS); gi++ )); do
                if [[ "$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" key)" == "$group_key" ]]; then
                    group_label="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" label)"
                    break
                fi
            done

            [[ -n "$group_label" ]] || continue

            for row_index in "${_page_rows[@]}"; do
                item_group="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" group)"
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
                item_group="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" group)"
                [[ "$item_group" == "$group_key" ]] || continue

                item_state="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" visible)"
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

                label="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" label)"
                desc="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" desc)"
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

        row_count="$(sgnd_dt_row_count SGND_GROUP_ROWS)"

        for (( gi=0; gi<row_count; gi++ )); do
            if [[ "$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" key)" == "$group_key" ]]; then
                group_label="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" label)"
                group_state="$(sgnd_dt_get "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS "$gi" visible)"
                found_group=1
                break
            fi
        done

        (( found_group )) || return 0
        (( group_state != 0 )) || return 0

        row_count="$(sgnd_dt_row_count SGND_ITEM_ROWS)"

        for (( ii=0; ii<row_count; ii++ )); do
            item_group="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" group)"
            [[ "$item_group" == "$group_key" ]] || continue

            item_state="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" visible)"
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

        row_count="$(sgnd_dt_row_count SGND_ITEM_ROWS)"

        for (( ii=0; ii<row_count; ii++ )); do
            item_group="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" group)"
            [[ "$item_group" == "$group_key" ]] || continue

            item_state="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" visible)"
            case "$item_state" in
                1|2) ;;
                *) continue ;;
            esac

            builtin="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" builtin)"

            if (( builtin )); then
                display_key="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" key)"
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

            label="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" label)"
            desc="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$ii" desc)"
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

        local debug_text=""
        local dryrun_text=""
        local logfile_text=""
        local verbose_text=""
        local clearscr_text=""
        local prevtext=""
        local nexttext=""

        local bar_text=""
        local visible_len=0
        local left_pad=0

        local prev_enabled=0
        local next_enabled=0

        render_width="$(sgnd_terminal_width)"

        debug_text="$(_sgnd_console_toggleword "DEBUG"   "B" "${FLAG_DEBUG:-0}")"
        dryrun_text="$(_sgnd_console_toggleword "DRYRUN" "D" "${FLAG_DRYRUN:-0}" "${SGND_UI_DRYRUN}" "${SGND_UI_COMMIT}")"
        logfile_text="$(_sgnd_console_toggleword "LOG"   "G" "${SGND_LOGFILE_ENABLED:-0}")"
        verbose_text="$(_sgnd_console_toggleword "VERBOSE" "V" "${FLAG_VERBOSE:-0}")"
        clearscr_text="$(_sgnd_console_toggleword "CLRSCR" "C" "${SGND_CLEAR_ONRENDER:-0}")"

        (( SGND_PAGE_INDEX > 0 )) && prev_enabled=1
        (( SGND_PAGE_INDEX + 1 < ${#SGND_PAGE_STARTS[@]} )) && next_enabled=1

        prevtext="$(_sgnd_console_toggleword "<<PREV" "<" "$prev_enabled")"
        nexttext="$(_sgnd_console_toggleword "NEXT>>" ">" "$next_enabled")"

        local page_text=""
        local page_count="${#SGND_PAGE_STARTS[@]}"
        local -a segments=()

        saydebug "Pagecount: ${page_count}"
        saydebug "Page index: ${SGND_PAGE_INDEX}"

        if (( page_count > 1 )); then
            page_text="Page $((SGND_PAGE_INDEX + 1))/$page_count"
            page_text="$(sgnd_sgr "$SILVER" "" "$FX_ITALIC")${page_text}${RESET}"

            segments+=("$prevtext")
            segments+=("$debug_text")
            segments+=("$dryrun_text")
            segments+=("$page_text")
            segments+=("$logfile_text")
            segments+=("$verbose_text")
            segments+=("$clearscr_text")
            segments+=("$nexttext")
        else
            segments+=("$debug_text")
            segments+=("$dryrun_text")
            segments+=("$logfile_text")
            segments+=("$verbose_text")
            segments+=("$clearscr_text")
        fi

        # Join with gaps
        bar_text=""
        local seg
        for seg in "${segments[@]}"; do
            if [[ -n "$bar_text" ]]; then
                bar_text+="$(sgnd_string_repeat ' ' "$gap")"
            fi
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

        row_count="$(sgnd_dt_row_count SGND_ITEM_ROWS)"

        for (( i=0; i<row_count; i++ )); do
            builtin="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" builtin)"
            (( builtin )) || continue

            key="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" key)"
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
        local choice="${1:?missing choice}"
        local handler=""
        local label=""
        local state="1"
        local row_index=0
        local i
        local row_count=0
        local key=""

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            _sgnd_console_collect_visible_item_indexes

            if (( choice < 1 || choice > ${#SGND_VISIBLE_ITEM_INDEXES[@]} )); then
                saywarning "Invalid selection: $choice"
                return 1
            fi

            row_index="${SGND_VISIBLE_ITEM_INDEXES[$((choice - 1))]}"
            label="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" label)"
            state="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" visible)"

            if (( state == 2 )); then
                saywarning "Option disabled: $label"
                return 1
            fi

            handler="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" handler)"
            SGND_LAST_WAITSECS="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$row_index" waitsecs)"
            "$handler"
            return $?
        fi

        row_count="$(sgnd_dt_row_count SGND_ITEM_ROWS)"

        for (( i=0; i<row_count; i++ )); do
            key="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" key)"

            if [[ "${choice^^}" == "${key^^}" ]]; then
                state="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" visible)"
                label="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" label)"

                if (( state == 2 )); then
                    saywarning "Option disabled: $label"
                    return 1
                fi

                handler="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" handler)"
                SGND_LAST_WAITSECS="$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" waitsecs)"
                "$handler"
                return $?
            fi
        done

        saywarning "Invalid selection: $choice"
        return 1
    }


