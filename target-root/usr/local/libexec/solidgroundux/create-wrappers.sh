#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Create Wrappers
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : 65218101aec5242de8f8267fa482932ba8bec11bfacf971c00f7b0e24ba297da
#   Source      : create-wrappers.sh
#   Type        : script
#   Group       : SDK
#   Purpose     : Create root-aware command wrappers for SolidGroundUX scripts.
#
# Description:
#   Creates one or more command wrappers from SolidGroundUX scripts. Source files are
#   selected from a source directory using a filename or shell mask. Generated wrappers
#   resolve SGND_APPLICATION_ROOT at runtime from the active SolidGroundUX configuration,
#   so the same wrapper works on development, test, and installed systems.
#
#   Wrapper names:
#     - script.sh       -> sgnd-script
#     - sgnd-script.sh  -> sgnd-script
#
#   Wrapper target directories:
#     - /usr/local/bin  (default)
#     - /usr/local/sbin
#
# Configuration precedence used by generated wrappers:
#   1. ~/.config/solidgroundux/solidgroundux.cfg
#   2. /etc/solidgroundux/solidgroundux.cfg
#
# Design principles:
#   - Generated wrappers remain environment-independent.
#   - Wrapper targets are stored relative to SGND_APPLICATION_ROOT.
#   - Existing wrappers are not overwritten without confirmation.
#   - A filename or mask may select one or multiple source scripts.
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
    # fn$ _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Purpose
        #   Resolve the active SolidGroundUX configuration and load executable support.
        # . Returns
        #   0 on success; 126/127 on bootstrap failure.
        # . Usage
        #   _framework_locator || return $?
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local exe_common=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"

        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"
        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"
        else
            printf 'FATAL: No SolidGroundUX configuration found.\n' >&2
            return 126
        fi

        # shellcheck source=/dev/null
        source "$cfg"

        : "${SGND_FRAMEWORK_ROOT:=/}"
        : "${SGND_APPLICATION_ROOT:=$SGND_FRAMEWORK_ROOT}"

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

# --- Framework integration -----------------------------------------------------------
    SGND_USING=(
    )

    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Repeat with last settings|0|"
        "source|s|value|SOURCE_DIR|Source directory containing scripts|"
        "mask|m|value|SOURCE_MASK|Filename or shell mask to select scripts|*.sh"
        "target|t|enum|TARGET_KIND|Wrapper target directory: bin or sbin|bin,sbin"
        "overwrite|o|flag|FLAG_OVERWRITE|Overwrite existing wrappers without confirmation|0|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Create wrappers interactively:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Create wrappers for all shell scripts in one directory:"
        "  $SGND_SCRIPT_NAME --source /path/to/scripts --mask '*.sh' --target bin"
        ""
        "Create one wrapper:"
        "  $SGND_SCRIPT_NAME --source /path/to/scripts --mask prepare-release.sh"
    )

    SGND_SCRIPT_GLOBALS=(
    )

    SGND_STATE_VARIABLES=(
        SOURCE_DIR
        SOURCE_MASK
        TARGET_KIND
        FLAG_OVERWRITE
    )

    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=1

# --- Helpers ------------------------------------------------------------------------
    # fn: _application_path - Resolve a path beneath SGND_APPLICATION_ROOT
        # . Purpose
        #   Convert an application-relative path to an absolute path.
        # . Returns
        #   0 always.
        # . Usage
        #   path="$(_application_path "usr/local/bin")"
    _application_path() {
        local relative="${1#/}"

        if [[ "$SGND_APPLICATION_ROOT" == "/" ]]; then
            printf '/%s\n' "$relative"
        else
            printf '%s/%s\n' "${SGND_APPLICATION_ROOT%/}" "$relative"
        fi
    }

    # fn: _relative_to_application_root - Convert an absolute source path to application-relative
        # . Purpose
        #   Ensure a selected source belongs to SGND_APPLICATION_ROOT and return its
        #   normalized path relative to that root.
        # . Returns
        #   0 when source is beneath the application root; 1 otherwise.
        # . Usage
        #   rel="$(_relative_to_application_root "$file")"
    _relative_to_application_root() {
        local file="${1:-}"
        local root="${SGND_APPLICATION_ROOT%/}"
        local absolute=""

        [[ -n "$file" ]] || return 1
        absolute="$(readlink -f "$file")" || return 1

        if [[ "$SGND_APPLICATION_ROOT" == "/" ]]; then
            printf '%s\n' "${absolute#/}"
            return 0
        fi

        case "$absolute" in
            "$root"/*)
                printf '%s\n' "${absolute#"$root"/}"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

    # fn: _wrapper_name_for_script - Return the canonical wrapper command name
        # . Purpose
        #   Prefix script basenames with sgnd- unless already present.
        # . Returns
        #   0 always.
        # . Usage
        #   name="$(_wrapper_name_for_script "$file")"
    _wrapper_name_for_script() {
        local file="${1:-}"
        local base=""

        base="$(basename -- "$file")"
        base="${base%.sh}"

        if [[ "$base" == sgnd-* ]]; then
            printf '%s\n' "$base"
        else
            printf 'sgnd-%s\n' "$base"
        fi
    }

    # fn: _write_wrapper - Create one root-aware wrapper
        # . Purpose
        #   Generate a wrapper whose target is stored relative to SGND_APPLICATION_ROOT.
        # . Returns
        #   0 on success; 1 on failure or declined overwrite.
        # . Usage
        #   _write_wrapper "$source" "$wrapper"
    _write_wrapper() {
        local source="${1:-}"
        local wrapper="${2:-}"
        local relative_target=""

        relative_target="$(_relative_to_application_root "$source")" || {
            sayfail "Source is outside SGND_APPLICATION_ROOT: $source"
            return 1
        }

        if [[ -e "$wrapper" || -L "$wrapper" ]]; then
            if (( ! ${FLAG_OVERWRITE:-0} )); then
                saywarning "Skipped existing wrapper: $wrapper"
                return 0
            fi
        fi

        if (( ${FLAG_DRYRUN:-0} )); then
            sayinfo "[DRYRUN] Would create wrapper: $wrapper -> $relative_target"
            return 0
        fi

        mkdir -p -- "$(dirname -- "$wrapper")" || return 1

        printf '%s\n' \
            '#!/usr/bin/env bash' \
            '# =====================================================================================' \
            '# SolidGroundUX - Command Wrapper' \
            '# -------------------------------------------------------------------------------------' \
            '# Metadata:' \
            '#   Version     : 1.0' \
            '#   Build       : -' \
            '#   Checksum    : -' \
            "#   Source      : $(basename -- "$wrapper")" \
            '#   Type        : wrapper' \
            '#   Group       : Generated' \
            '#   Purpose     : Launch a configured SolidGroundUX target beneath the application root.' \
            '#' \
            '# Description:' \
            '#   Resolves the active SolidGroundUX configuration, preferring the invoking user'\''s' \
            '#   configuration over the system configuration, then launches SGND_WRAPPER_TARGET' \
            '#   beneath SGND_APPLICATION_ROOT.' \
            '#' \
            '# Attribution:' \
            '#   Developers  : Mark Fieten' \
            '#   Company     : Testadura Consultancy' \
            '#   Client      : -' \
            '#   Copyright   : © 2025 - 2026 Testadura Consultancy' \
            '#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.' \
            '# =====================================================================================' \
            '' \
            'set -uo pipefail' \
            '' \
            "SGND_WRAPPER_TARGET=\"$relative_target\"" \
            '' \
            'cfg_home="$HOME"' \
            '' \
            'if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then' \
            '    cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"' \
            'fi' \
            '' \
            'cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"' \
            'cfg_sys="/etc/solidgroundux/solidgroundux.cfg"' \
            'cfg=""' \
            '' \
            'if [[ -r "$cfg_user" ]]; then' \
            '    cfg="$cfg_user"' \
            'elif [[ -r "$cfg_sys" ]]; then' \
            '    cfg="$cfg_sys"' \
            'else' \
            '    printf '\''FATAL: No SolidGroundUX configuration found.\n'\'' >&2' \
            '    exit 126' \
            'fi' \
            '' \
            '# shellcheck source=/dev/null' \
            'source "$cfg"' \
            '' \
            ': "${SGND_APPLICATION_ROOT:=/}"' \
            '' \
            'if [[ "$SGND_APPLICATION_ROOT" == "/" ]]; then' \
            '    target="/${SGND_WRAPPER_TARGET#/}"' \
            'else' \
            '    target="${SGND_APPLICATION_ROOT%/}/${SGND_WRAPPER_TARGET#/}"' \
            'fi' \
            '' \
            '[[ -f "$target" ]] || {' \
            '    printf '\''FATAL: Wrapper target not found: %s\n'\'' "$target" >&2' \
            '    exit 127' \
            '}' \
            '' \
            'exec bash "$target" "$@"' \
            > "$wrapper" || return 1

        chmod 0755 -- "$wrapper" || return 1
        sayok "Created wrapper: $wrapper -> $relative_target"
        return 0
    }

    # fn: _get_parameters - Collect wrapper-generation parameters
        # . Purpose
        #   Resolve source selection and wrapper target directory.
        # . Returns
        #   0 on success; 1 on cancellation/invalid input.
        # . Usage
        #   _get_parameters
    _get_parameters() {
        local lw=22
        local lp=4

        SOURCE_DIR="${SOURCE_DIR:-"$SGND_APPLICATION_ROOT"}"
        SOURCE_MASK="${SOURCE_MASK:-*.sh}"
        TARGET_KIND="${TARGET_KIND:-bin}"
        FLAG_OVERWRITE="${FLAG_OVERWRITE:-0}"

        sgnd_state_load_keys --array SGND_STATE_VARIABLES || return $?

        if (( ${FLAG_AUTO:-0} )); then
            return 0
        fi

        sgnd_print
        sgnd_print_sectionheader "Wrapper source" --padend 0

        ask --label "Source directory" \
            --var SOURCE_DIR \
            --default "$SOURCE_DIR" \
            --validate sgnd_validate_dir_exists \
            --colorize both \
            --labelclr "${CYAN}" \
            --pad "$lp" \
            --labelwidth "$lw"

        ask --label "Filename or mask" \
            --var SOURCE_MASK \
            --default "$SOURCE_MASK" \
            --colorize both \
            --labelclr "${CYAN}" \
            --pad "$lp" \
            --labelwidth "$lw"

        ask_decision --label "Target directory" \
            --choices "bin,sbin" \
            --default "$TARGET_KIND" \
            --var TARGET_KIND \
            --displaychoices 1 \
            --colorize both \
            --labelclr "${CYAN}" \
            --pad "$lp" \
            --labelwidth "$lw"

        local overwrite="N"
        (( FLAG_OVERWRITE )) && overwrite="Y"

        ask --label "Overwrite existing wrappers (Y/N)" \
            --var overwrite \
            --default "$overwrite" \
            --choices "Y,Yes,N,No" \
            --colorize both \
            --labelclr "${CYAN}" \
            --pad "$lp" \
            --labelwidth "$lw"

        case "${overwrite^^}" in
            Y|YES) FLAG_OVERWRITE=1 ;;
            *)     FLAG_OVERWRITE=0 ;;
        esac

        return 0
    }

    # fn: _create_wrappers - Create wrappers for selected scripts
        # . Purpose
        #   Match selected scripts and create canonical sgnd-* wrappers.
        # . Returns
        #   0 when all matching wrappers are handled successfully; 1 otherwise.
        # . Usage
        #   _create_wrappers
    _create_wrappers() {
        local target_root=""
        local source=""
        local wrapper_name=""
        local wrapper=""
        local matched=0
        local failed=0

        case "${TARGET_KIND,,}" in
            bin)
                target_root="$(_application_path "usr/local/bin")"
                ;;
            sbin)
                target_root="$(_application_path "usr/local/sbin")"
                ;;
            *)
                sayfail "Invalid wrapper target directory: $TARGET_KIND"
                return 1
                ;;
        esac

        while IFS= read -r -d '' source; do
            (( matched++ ))

            wrapper_name="$(_wrapper_name_for_script "$source")"
            wrapper="${target_root%/}/$wrapper_name"

            _write_wrapper "$source" "$wrapper" || failed=1
        done < <(
            find "$SOURCE_DIR" \
                -mindepth 1 \
                -maxdepth 1 \
                -type f \
                -name "$SOURCE_MASK" \
                -print0 2>/dev/null
        )

        if (( matched == 0 )); then
            saywarning "No files matched: ${SOURCE_DIR%/}/$SOURCE_MASK"
            return 1
        fi

        if (( failed )); then
            sayfail "One or more wrappers could not be created."
            return 1
        fi

        sayok "Wrapper generation complete: $matched source file(s) processed."
        return 0
    }

# --- Main ---------------------------------------------------------------------------
    # fn: main - Run wrapper generation
        # . Purpose
        #   Initialize SolidGroundUX and create selected command wrappers.
        # . Usage
        #   main "$@"
    main() {
        _framework_locator || exit $?
        sgnd_exe_start --state -- "$@"

        _get_parameters || exit $?
        _create_wrappers || exit $?
    }

    main "$@"
