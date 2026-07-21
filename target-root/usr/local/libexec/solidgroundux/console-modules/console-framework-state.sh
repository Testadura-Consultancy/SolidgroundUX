# ==================================================================================
# SolidGroundUX - Framework State Console Module
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.7
#   Build       : 2619600
#   Checksum    : 96cfbfca2943425f54b8ca7ec7731238f8113bec8166c3af031a97085adad437
#   Source      : console-framework-state.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Inspect and edit transferable SolidGroundUX framework state
#
# Description:
#   Provides sgnd-console actions for viewing, editing, saving, and reloading the
#   variables listed in SGND_FRAMEWORK_STATE.
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : -
#   Copyright     : © 2025 - 2026 Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# --- Library guard ----------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the module is sourced and initialized only once.
        #
        # . Returns
        #   0 when loading may continue.
        #   1 when the module was already loaded.
        #   Exits with status 2 when executed directly.
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

        [[ -n "${!guard-}" ]] && return 1
        printf -v "$guard" '1'
        return 0
    }

    _sgnd_lib_guard || return 0
    unset -f _sgnd_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

    SGND_FRAMEWORK_STATE_MODULE_ID="framework-state"
    SGND_FRAMEWORK_STATE_MODULE_NAME="Framework State"
    SGND_FRAMEWORK_STATE_MODULE_VERSION="1.0.0"
    SGND_FRAMEWORK_STATE_MODULE_DESC="Inspect and edit transferable SolidGroundUX framework runtime settings"

    SGND_MODULE_ID="$SGND_FRAMEWORK_STATE_MODULE_ID"
    SGND_MODULE_NAME="$SGND_FRAMEWORK_STATE_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_FRAMEWORK_STATE_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_FRAMEWORK_STATE_MODULE_DESC"

# --- Internal helpers -------------------------------------------------------------
    # fn: _framework_state_validate
        # . Purpose
        #   Verify that the transferable framework-state contract is available.
        #
        # . Returns
        #   0 when SGND_FRAMEWORK_STATEFILE and SGND_FRAMEWORK_STATE are available.
        #   1 otherwise.
        #
        # . Usage
        #   _framework_state_validate
    _framework_state_validate() {
        [[ -n "${SGND_FRAMEWORK_STATEFILE:-}" ]] || {
            saywarning "SGND_FRAMEWORK_STATEFILE is not set"
            return 1
        }

        declare -p SGND_FRAMEWORK_STATE >/dev/null 2>&1 || {
            saywarning "SGND_FRAMEWORK_STATE is not defined"
            return 1
        }

        return 0
    }

    # fn: _framework_state_apply_ui
        # . Purpose
        #   Reload the active palette and style after framework state changes.
        #
        # . Returns
        #   0 when UI state is reloaded or no loader is available.
        #   Non-zero when the UI loader fails.
        #
        # . Usage
        #   _framework_state_apply_ui
    _framework_state_apply_ui() {
        if declare -F sgnd_load_ui_style >/dev/null 2>&1; then
            sgnd_load_ui_style
        fi
    }

# --- Public module actions --------------------------------------------------------
    # fn: framework_state_show
        # . Purpose
        #   Display all transferable framework-state variables and their values.
        #
        # . Returns
        #   0 on success.
        #   1 when framework state is unavailable.
        #
        # . Usage
        #   framework_state_show
    framework_state_show() {
        _framework_state_validate || return 1

        local key=""
        local value=""

        sgnd_print
        sgnd_print_sectionheader --text "Transferable framework state"
        sgnd_print_labeledvalue --label "State file" --value "$SGND_FRAMEWORK_STATEFILE"
        sgnd_print

        for key in "${SGND_FRAMEWORK_STATE[@]}"; do
            value="${!key-}"
            sgnd_print_labeledvalue --label "$key" --value "$value" --labelwidth 30
        done
    }

    # fn: framework_state_edit
        # . Purpose
        #   Edit and save all transferable framework-state variables.
        #
        # . Behavior
        #   - Builds an input form from SGND_FRAMEWORK_STATE.
        #   - Uses the current runtime values as defaults.
        #   - Saves the edited values to SGND_FRAMEWORK_STATEFILE.
        #   - Reloads the active UI style after a successful save.
        #
        # Outputs (globals):
        #   Variables listed in SGND_FRAMEWORK_STATE.
        #
        # Side effects:
        #   Updates SGND_FRAMEWORK_STATEFILE.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when editing, saving, or UI reloading fails.
        #
        # . Usage
        #   framework_state_edit
    framework_state_edit() {
        _framework_state_validate || return 1

        local key=""
        local -a fields=()

        for key in "${SGND_FRAMEWORK_STATE[@]}"; do
            fields+=("$key|$key|${!key-}|")
        done

        sgnd_print
        sgnd_print_sectionheader --text "Edit transferable framework state"

        ask_prompt_form --autoalign --pad 2 -- "${fields[@]}" || return $?

        sgnd_state_save_keys \
            --file "$SGND_FRAMEWORK_STATEFILE" \
            --array SGND_FRAMEWORK_STATE || return $?

        _framework_state_apply_ui || return $?
        sayok "Framework state saved"
    }

    # fn: framework_state_save
        # . Purpose
        #   Save current transferable framework-state values.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when state is unavailable or cannot be saved.
        #
        # . Usage
        #   framework_state_save
    framework_state_save() {
        _framework_state_validate || return 1

        sgnd_state_save_keys \
            --file "$SGND_FRAMEWORK_STATEFILE" \
            --array SGND_FRAMEWORK_STATE || return $?

        sayok "Framework state saved to $SGND_FRAMEWORK_STATEFILE"
    }

    # fn: framework_state_reload
        # . Purpose
        #   Reload transferable framework state from disk into the console instance.
        #
        # Outputs (globals):
        #   Variables listed in SGND_FRAMEWORK_STATE.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when state is unavailable or cannot be loaded.
        #
        # . Usage
        #   framework_state_reload
    framework_state_reload() {
        _framework_state_validate || return 1

        sgnd_state_load_keys \
            --file "$SGND_FRAMEWORK_STATEFILE" \
            --array SGND_FRAMEWORK_STATE || return $?

        _framework_state_apply_ui || return $?
        sayok "Framework state reloaded"
    }

# --- Console registration ---------------------------------------------------------
    sgnd_console_register_group \
        "$SGND_FRAMEWORK_STATE_MODULE_ID" \
        "$SGND_FRAMEWORK_STATE_MODULE_NAME ($SGND_FRAMEWORK_STATE_MODULE_VERSION)" \
        "$SGND_FRAMEWORK_STATE_MODULE_DESC" \
        0 1 820

    sgnd_console_register_item "state-show" "$SGND_FRAMEWORK_STATE_MODULE_ID" "Show state" "framework_state_show" "Display current transferable framework-state values" 0 30 1
    sgnd_console_register_item "state-edit" "$SGND_FRAMEWORK_STATE_MODULE_ID" "Edit state" "framework_state_edit" "Edit and save transferable framework-state values" 0 30 1
    sgnd_console_register_item "state-save" "$SGND_FRAMEWORK_STATE_MODULE_ID" "Save state" "framework_state_save" "Save current transferable values to the state file" 0 30 1
    sgnd_console_register_item "state-reload" "$SGND_FRAMEWORK_STATE_MODULE_ID" "Reload state" "framework_state_reload" "Reload transferable values from the state file" 0 30 1
