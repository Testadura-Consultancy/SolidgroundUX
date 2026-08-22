#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Prepare Release
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623415
#   Checksum    : 8ac6b6ed173b03ef22b2f735e8d831dac52e8adb2ae3ca10ec453e05e69953be
#   Source      : prepare-release.sh
#   Type        : script
#   Group       : SDK
#   Purpose     : Prepare framework scripts for release
#
# Description:
#   Provides a release-preparation utility for SolidGroundUX workspaces.
#
#   The script:
#     - Selects target scripts by file or folder
#     - Refreshes version, build, and checksum metadata unless source updates are disabled
#     - Applies optional major or minor version bumps
#     - Supports dry-run verification before committing changes
#     - Ensures release metadata is consistent across processed scripts
#     - Verifies public command wrappers for executable top-level libexec scripts
#     - Creates release tar/manifests/checksums and a complete distributable release ZIP
#     - Uses an explicit removal-baseline manifest from persistent manifest history
#     - Ships the standalone release-manager.sh beside the release payload
#
# Design principles:
#   - Release preparation is deterministic and repeatable
#   - Metadata updates are explicit and convention-based
#   - Safe verification is supported through dry-run mode
#   - Script formatting is preserved when updating field values
#
# Role in framework:
#   - Pre-release maintenance tool for framework and utility scripts
#   - Ensures release metadata is synchronized before distribution
#
# Non-goals:
#   - Deploying files to target environments
#   - Managing version control, tagging, or publication workflows
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

# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# --- Script metadata (framework integration) -----------------------------------------
    # SGND_USING
        # Libraries to source from SGND_COMMON_LIB.
        # These are loaded automatically by sgnd_bootstrap AFTER core libraries.
        #
        # Example:
        #   SGND_USING=( net.sh fs.sh )
        #
        # Leave empty if no extra libs are needed.
    SGND_USING=(
        sgnd-comment-header-parser.sh
    )

    # SGND_ARGS_SPEC
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
        "auto|a|flag|FLAG_AUTO|Repeat with last settings|0|"
        "cleanup|c|flag|FLAG_CLEANUP|Cleanup staging files after run|1|"
        "useexisting|u|flag|FLAG_USEEXISTING|Use existing staging files|1|"
        "bumpmajor||flag|FLAG_BUMP_MAJOR|Bump major version in source headers before packaging|"
        "bumpminor||flag|FLAG_BUMP_MINOR|Bump minor version in source headers before packaging|"
        "updatebuild||enum|MODE_UPDATEBUILD|Build metadata policy: A=all, C=changed, N=none|C"
        "updateversion||enum|MODE_UPDATEVERSION|Version metadata policy: A=all, C=changed, N=none|C"
        "createwrappers|w|flag|FLAG_CREATEWRAPPERS|Create missing /usr/local/bin wrappers for top-level libexec scripts|1|"
        "previous-manifest||value|PREVIOUS_MANIFEST|Removal baseline manifest path|"
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
        #   - Variables listed here can be loaded and saved explicitly by the script.
        #   - On startup, previously saved values are restored before main logic runs.
        #
        # Contract:
        #   - Variables must be simple scalars (no arrays/associatives unless explicitly supported).
        #   - Script remains fully functional when state is disabled.
        #
        # Leave empty if:
        #   - The script does not use persistent state.
   SGND_STATE_VARIABLES=(
        SOURCE_DIR
        STAGING_ROOT
        PRODUCT
        VERSION
        FLAG_CLEANUP
        FLAG_USEEXISTING
        FLAG_SAVEPARMS
        MODE_UPDATEBUILD
        MODE_UPDATEVERSION
        FLAG_CREATEWRAPPERS
        PREVIOUS_MANIFEST
        MANIFEST_HISTORY_DIR
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

    # Automatic state saving is disabled.
        # State is loaded explicitly and saved only when FLAG_SAVEPARMS=1.
    SGND_STATE_SAVE=0

# --- Local script Declarations -------------------------------------------------------
    # Put script-local constants and defaults here (NOT framework config).
    # Prefer local variables inside functions unless a value must be shared.

# --- Local script functions ----------------------------------------------------------
    # _get_parameters
        # . Purpose
        #   Resolve and collect all parameters required to prepare a release archive.
        #
        # . Behavior
        #   - Computes default values from framework metadata and workspace paths.
        #   - In auto mode, reuses existing or default values without prompting.
        #   - In interactive mode, prompts for release settings and confirms them.
        #   - Saves confirmed parameters through _save_parameters().
        #
        # Parameters handled:
        #   RELEASE
        #       Release identifier used for staging and filenames
        #   SOURCE_DIR
        #       Source directory to package
        #   STAGING_ROOT
        #       Root directory containing staging files and release outputs
        #   TAR_FILE
        #       Final tar.gz filename
        #   FLAG_CLEANUP
        #       Whether to remove staging files after completion
        #   FLAG_USEEXISTING
        #       Whether to reuse a non-empty staging tree
        #
        # Outputs (globals):
        #   RELEASE
        #   SOURCE_DIR
        #   STAGING_ROOT
        #   TAR_FILE
        #   FLAG_AUTO
        #   FLAG_CLEANUP
        #   FLAG_USEEXISTING
        #
        # . Returns
        #   0 on successful resolution and confirmation
        #   Exits the script with status 1 if the user cancels
        #
        # . Usage
        #   _get_parameters
        #
        # Examples:
        #   _get_parameters || return 1
        #
        # Notes:
        #   - Uses ask() and ask_ok_redo_quit() for interactive input.
        #   - Auto mode assumes state was loaded during bootstrap (--state).
    # fn: _get_parameters - Collect prepare-release parameters
        # . Purpose
        #   Collect prepare-release parameters.
        #
        # . Behavior
        #   - Internal helper.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _get_parameters
    _get_parameters(){
        PRODUCT="${PRODUCT:-"$SGND_PRODUCT"}"
        VERSION="${VERSION:-"$SGND_VERSION"}"
        BUILD="$(date +%y%j%H)"

        SOURCE_DIR="${SOURCE_DIR:-"$SGND_APPLICATION_ROOT"}"
        SGND_APPLICATION_PARENT="$(dirname "$SGND_APPLICATION_ROOT")"
        STAGING_ROOT="${STAGING_ROOT:-"$SGND_APPLICATION_PARENT/releases"}"
        FLAG_AUTO="${FLAG_AUTO:-0}"
        FLAG_CLEANUP="${FLAG_CLEANUP:-1}"
        FLAG_USEEXISTING="${FLAG_USEEXISTING:-1}"
        FLAG_SAVEPARMS="${FLAG_SAVEPARMS:-1}"
        MODE_UPDATEBUILD="${MODE_UPDATEBUILD:-C}"
        MODE_UPDATEVERSION="${MODE_UPDATEVERSION:-C}"
        FLAG_CREATEWRAPPERS="${FLAG_CREATEWRAPPERS:-1}"
        MANIFEST_HISTORY_DIR="${MANIFEST_HISTORY_DIR:-"${STAGING_ROOT%/}/manifest-history"}"
        PREVIOUS_MANIFEST="${PREVIOUS_MANIFEST:-}"

        sgnd_state_load_keys --array SGND_STATE_VARIABLES || return $?
        
        if [[ "${FLAG_AUTO:-0}" -eq 1 ]]; then
             sayinfo "Auto mode: using last deployment or default settings."
             return 0
        fi
        local lw=20
        local lp=4
        while true; do
            sgnd_print
            sgnd_print_sectionheader "File locations" --padend 0
            ask --label "Source directory" --var SOURCE_DIR --default "$SOURCE_DIR" --validate sgnd_validate_dir_exists --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            ask --label "Staging directory" --var STAGING_ROOT --default "$STAGING_ROOT" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"

            sgnd_print
            sgnd_print_sectionheader "Release identification" --padend 0
            ask --label "Product" --var PRODUCT --default "$PRODUCT" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            ask --label "Version" --var VERSION --default "$VERSION" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            sgnd_print_labeledvalue --label "Build" --value "$BUILD" --colorize both --lableclr "$(sgnd_sgr "$SILVER" "" "$FX_ITALIC")" --valueclr "$(sgnd_sgr "$SILVER" "" "$FX_ITALIC")" --pad "$lp" --labelwidth "$lw"

            sgnd_print
            RELEASE="${RELEASE:-"$PRODUCT-$VERSION.$BUILD"}"
            ask --label "Release" --var RELEASE --default "$RELEASE" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            TAR_FILE="${TAR_FILE:-"$RELEASE.tar.gz"}"
            ask --label "Tar file" --var TAR_FILE --default "$TAR_FILE" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"

            sgnd_print
            sgnd_print_sectionheader "Switches" --padend 0
            lw=41

            if [[ "$FLAG_CLEANUP" -eq 1 ]]; then
                cleanup="Y"
            else
                cleanup="N"
            fi
            ask --label "Cleanup staging files after run (Y/N)" --var cleanup --default "$cleanup" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            if [[ "$cleanup" == "Y" || "$cleanup" == "y" ]]; then
                FLAG_CLEANUP=1
            else
                FLAG_CLEANUP=0
            fi

            # detect if staging root contains anything
            local staging_has_files=0
            if [[ -d "$STAGING_ROOT" ]] && find "$STAGING_ROOT" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
                staging_has_files=1
            fi

            if (( staging_has_files )); then
                if [[ "$FLAG_USEEXISTING" -eq 1 ]]; then
                    useexisting="Y"
                else
                    useexisting="N"
                fi

                ask --label "Use existing staging files (Y/N)" --var useexisting --default "$useexisting" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"

                case "${useexisting^^}" in
                    Y) FLAG_USEEXISTING=1 ;;
                    *) FLAG_USEEXISTING=0 ;;
                esac
            else
                # no files -> force behavior
                FLAG_USEEXISTING=0
                sayinfo "Staging folder is empty -> cannot reuse files."
            fi

             if [[ "$FLAG_SAVEPARMS" -eq 1 ]]; then
                saveparms="Y"
            else
                saveparms="N"
            fi

            ask_decision --label "Update build (A(ll)/C(hanged only)/N(o))" \
                --choices "A,C,N" \
                --default "${MODE_UPDATEBUILD^^}" \
                --var MODE_UPDATEBUILD \
                --displaychoices 0 \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            ask_decision --label "Update version (A(ll)/C(hanged only)/N(o))" \
                --choices "A,C,N" \
                --default "${MODE_UPDATEVERSION^^}" \
                --var MODE_UPDATEVERSION \
                --displaychoices 0 \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"

            if [[ "$FLAG_CREATEWRAPPERS" -eq 1 ]]; then
                createwrappers="Y"
            else
                createwrappers="N"
            fi
            ask --label "Create missing command wrappers (Y/N)" \
                --var createwrappers \
                --default "$createwrappers" \
                --choices "Y,Yes,N,No" \
                --colorize both \
                --labelclr "${CYAN}" \
                --pad "$lp" \
                --labelwidth "$lw"
            case "${createwrappers^^}" in
                Y|YES) FLAG_CREATEWRAPPERS=1 ;;
                *)     FLAG_CREATEWRAPPERS=0 ;;
            esac

            _sgnd_release_select_previous_manifest || {
                saycancel "Release preparation cancelled."
                return 1
            }

            ask --label "Save these settings for future use (Y/N)" --var saveparms --default "$saveparms" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            if [[ "$saveparms" == "Y" || "$saveparms" == "y" ]]; then
                FLAG_SAVEPARMS=1
            else
                FLAG_SAVEPARMS=0
            fi

            sgnd_print_sectionheader
            printf "\n"

            ask_dlg_autocontinue \
                --seconds 15 \
                --message "Continue with these settings?" \
                --redo \
                --cancel

            case $? in
                0|1) break ;;
                2) saycancel "Aborting as per user request."; return 1 ;;
                3) PROJECT_NAME=""; PROJECT_FOLDER=""; continue ;;
                *) sayfail "Aborting (unexpected response)."; return 1 ;;
            esac

        done

        if (( FLAG_SAVEPARMS == 1 )); then
            if (( FLAG_DRYRUN == 1 )); then
                sayinfo "Would have saved state variables (manual)"
            else
                sgnd_state_save_keys --array SGND_STATE_VARIABLES || return $?
            fi
        fi
    }


    # fn: _sgnd_release_list_manifest_history - List available removal-baseline manifests
        # . Purpose
        #   List persistent manifest-history files in release/version order.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sgnd_release_list_manifest_history
    _sgnd_release_list_manifest_history() {
        [[ -d "$MANIFEST_HISTORY_DIR" ]] || return 0
        find "$MANIFEST_HISTORY_DIR" -maxdepth 1 -type f -name "${PRODUCT}-*.manifest" -printf '%f\n' 2>/dev/null \
            | LC_ALL=C sort -V
    }

    # fn: _sgnd_release_select_previous_manifest - Select the removal-baseline manifest
        # . Purpose
        #   Resolve the manifest against which removed paths are calculated.
        #
        # . Behavior
        #   - Honors PREVIOUS_MANIFEST when already supplied by argument/state.
        #   - In auto mode, requires the stored path to still exist or uses no baseline.
        #   - In interactive mode, offers manifests from persistent history, an explicit
        #     custom path, or no baseline.
        #
        # . Returns
        #   0 on success; 1 on invalid/cancelled selection.
        #
        # . Usage
        #   _sgnd_release_select_previous_manifest
    _sgnd_release_select_previous_manifest() {
        local selection=""
        local custom=""
        local i=0
        local -a manifests=()
        local -a options=()

        if [[ -n "${PREVIOUS_MANIFEST:-}" && ! -f "$PREVIOUS_MANIFEST" ]]; then
            if (( ${FLAG_AUTO:-0} )); then
                sayfail "Stored removal baseline no longer exists: $PREVIOUS_MANIFEST"
                return 1
            fi

            saywarning "Stored removal baseline not found: $PREVIOUS_MANIFEST"
            PREVIOUS_MANIFEST=""
        fi

        mapfile -t manifests < <(_sgnd_release_list_manifest_history)

        if (( ${FLAG_AUTO:-0} )); then
            # Auto mode reuses the stored/argument baseline when present.
            return 0
        fi

        if (( ${#manifests[@]} > 0 )); then
            for (( i=${#manifests[@]}-1; i>=0; i-- )); do
                options+=("${manifests[$i]}")
            done
        else
            sayinfo "No manifests are currently stored in $MANIFEST_HISTORY_DIR"
        fi

        options+=("Custom path" "No removal baseline")

        ask_selection \
            --label "Removal baseline manifest" \
            --var selection \
            --items "${options[@]}" || return 1

        case "$selection" in
            "No removal baseline")
                PREVIOUS_MANIFEST=""
                return 0
                ;;
            "Custom path")
                ask \
                    --label "Manifest path" \
                    --var custom \
                    --default "" \
                    --validate sgnd_validate_file_exists \
                    --colorize both \
                    --labelclr "${CYAN}" \
                    --pad 4 \
                    --labelwidth 20

                PREVIOUS_MANIFEST="$(readlink -f "$custom")"
                return 0
                ;;
        esac

        PREVIOUS_MANIFEST="${MANIFEST_HISTORY_DIR%/}/$selection"
        return 0
    }

    # _sgnd_release_write_checksum
        # . Purpose
        #   Add or update a SHA256SUMS entry for a release artifact.
        #
        # . Behavior
        #   - Ensures SHA256SUMS contains exactly one entry for the specified filename.
        #   - Removes any existing line for the same filename before appending a new one.
        #   - Stores only the basename in the checksum file.
        #
        # . Arguments
        #   $1  TAR_PATH
        #       Path to the file to hash.
        #   $2  TAR_FILE
        #       Filename to write into SHA256SUMS.
        #   $3  STAGING_ROOT
        #       Directory containing SHA256SUMS.
        #
        # . Side effects
        #   - Creates or updates:
        #       <staging_root>/SHA256SUMS
        #
        # . Returns
        #   0 on success
        #   1 if required arguments are missing or file operations fail
        #
        # . Usage
        #   _sgnd_release_write_checksum "/tmp/sgnd-example" "/tmp/sgnd-example.txt" "/tmp/sgnd-example"
        # . Purpose
        #   Write release checksum metadata for a file.
        #
        # . Behavior
        #   - Public entry point.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _sgnd_release_write_checksum
    _sgnd_release_write_checksum() {
        local tar_path="${1:-}"
        local tar_file="${2:-}"
        local staging_root="${3:-}"

        [[ -n "$tar_path" ]] || return 1
        [[ -n "$tar_file" ]] || return 1
        [[ -n "$staging_root" ]] || return 1

        local sums_file
        sums_file="${staging_root%/}/SHA256SUMS"

        touch "$sums_file" || return 1

        # Remove any existing entry for this filename (idempotent).
        # Match: two spaces + filename at end of line.
        sed -i "\|  $tar_file$|d" "$sums_file" || return 1

        local hash
        hash="$(sha256sum "$tar_path" | awk '{print $1}')" || return 1
        [[ -n "$hash" ]] || return 1

        printf '%s  %s\n' "$hash" "$tar_file" >> "$sums_file" || return 1
    }


    # fn: _sgnd_release_write_removed_manifest - Write removed-path delta
        # . Purpose
        #   Create the release removal manifest by comparing the selected baseline and
        #   current package manifests.
        #
        # . Behavior
        #   - Uses PREVIOUS_MANIFEST as the explicit removal baseline.
        #   - Computes paths present in the baseline but absent from the current manifest.
        #   - Writes one removed relative path per line in sorted order.
        #   - Creates an empty removal manifest when no baseline was selected.
        #
        # . Arguments
        #   $1  CURRENT_MANIFEST - Newly generated release manifest.
        #   $2  REMOVED_MANIFEST - Output path for the removal manifest.
        #
        # . Returns
        #   0 on success; 1 when validation, comparison, or output creation fails.
        #
        # . Usage
        #   _sgnd_release_write_removed_manifest "$manifest_path" "$removed_path"
    _sgnd_release_write_removed_manifest() {
        local current_manifest="${1:-}"
        local removed_manifest="${2:-}"
        local previous_sorted=""
        local current_sorted=""
        local removed_count=0

        [[ -f "$current_manifest" ]] || return 1
        [[ -n "$removed_manifest" ]] || return 1

        if [[ -z "${PREVIOUS_MANIFEST:-}" ]]; then
            : > "$removed_manifest" || return 1
            sayinfo "No removal baseline selected; removal manifest is empty."
            return 0
        fi

        [[ -f "$PREVIOUS_MANIFEST" ]] || {
            sayfail "Removal baseline manifest does not exist: $PREVIOUS_MANIFEST"
            return 1
        }

        sayinfo "Removal baseline: $(basename -- "$PREVIOUS_MANIFEST")"

        previous_sorted="$(mktemp)" || return 1
        current_sorted="$(mktemp)" || {
            rm -f -- "$previous_sorted"
            return 1
        }

        if ! LC_ALL=C sort -u -- "$PREVIOUS_MANIFEST" > "$previous_sorted"; then
            rm -f -- "$previous_sorted" "$current_sorted"
            return 1
        fi

        if ! LC_ALL=C sort -u -- "$current_manifest" > "$current_sorted"; then
            rm -f -- "$previous_sorted" "$current_sorted"
            return 1
        fi

        if ! LC_ALL=C comm -23 -- "$previous_sorted" "$current_sorted" > "$removed_manifest"; then
            rm -f -- "$previous_sorted" "$current_sorted"
            return 1
        fi

        rm -f -- "$previous_sorted" "$current_sorted"

        removed_count="$(grep -cve '^[[:space:]]*$' "$removed_manifest" 2>/dev/null || true)"
        sayinfo "Removal manifest contains $removed_count obsolete path(s)."
        return 0
    }

    # _create_tar
        # . Purpose
        #   Stage a clean release tree and produce a versioned tar.gz archive.
        #
        # . Behavior
        #   - Ensures the release-specific staging directory exists.
        #   - Populates the staging directory from SOURCE_DIR via rsync.
        #   - Reuses existing staging files when requested and non-empty.
        #   - Creates an uncompressed tar archive from the staged files.
        #   - Generates an uninstall manifest from the tar contents.
        #   - Compares the new manifest with the selected removal-baseline manifest and writes a removal delta.
        #   - Embeds the uninstall manifest into the tar archive.
        #   - Compresses the archive to tar.gz.
        #   - Updates SHA256SUMS and writes sidecar .sha256 files.
        #
        # Inputs (globals):
        #   RELEASE
        #   SOURCE_DIR
        #   STAGING_ROOT
        #   TAR_FILE
        #   FLAG_DRYRUN
        #   FLAG_USEEXISTING
        #
        # . Side effects
        #   - Creates and updates staged files and release artifacts under STAGING_ROOT.
        #
        # Output artifacts:
        #   - $STAGING_ROOT/$TAR_FILE
        #   - $STAGING_ROOT/$RELEASE.manifest
        #   - $STAGING_ROOT/$RELEASE.removed
        #   - $STAGING_ROOT/SHA256SUMS
        #   - $STAGING_ROOT/$TAR_FILE.sha256
        #   - $STAGING_ROOT/$RELEASE.manifest.sha256
        #   - $STAGING_ROOT/$RELEASE.removed.sha256
        #
        # . Returns
        #   0 on success
        #   1 on failure to stage, package, hash, or write artifacts
        #
        # . Usage
        #   _create_tar
        #
        # Examples:
        #   _create_tar || return 1
        #
        # Notes:
        #   - In dry-run mode, only reports the intended actions.
        #   - Manifest is generated before embedding, so it does not list itself.
    # fn: _create_tar - Create the release tar archive
        # . Purpose
        #   Create the release tar archive.
        #
        # . Behavior
        #   - Internal helper.
        #   - Preserves existing script runtime behavior.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   _create_tar
    _create_tar() {
        saystart "Creating release: $RELEASE"

        local stage_path tar_path_tar tar_path_gz manifest_path removed_path sums_path
        local manifest_base manifest_hash removed_base removed_hash

        stage_path="${STAGING_ROOT%/}/$RELEASE"

        # --- Ensure staging directory ----------------------------------------------
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have check/created directory: $stage_path"
        else
            saydebug "Ensuring staging dir exists: $stage_path"
            mkdir -p "$stage_path" || { sayfail "mkdir failed."; return 1; }
        fi

        # --- Stage clean copy -------------------------------------------------------
        if [[ "$FLAG_USEEXISTING" -eq 1 && -n "$(ls -A "$stage_path" 2>/dev/null)" ]]; then
            sayinfo "Using existing staging files as requested."
        else
            if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
                sayinfo "Would have staged files from $SOURCE_DIR to $stage_path"
            else
                saydebug "Staging files from $SOURCE_DIR to $stage_path"
                rsync -a --delete \
                    --exclude '.*' \
                    --exclude '*.state' \
                    --exclude '*.code-workspace' \
                    "${SOURCE_DIR%/}/" "$stage_path/" || {
                        sayfail "rsync failed."
                        return 1
                    }
            fi
        fi

        # --- Build paths ------------------------------------------------------------
        tar_path_tar="${STAGING_ROOT%/}/${TAR_FILE%.gz}"
        tar_path_gz="${STAGING_ROOT%/}/$TAR_FILE"
        manifest_path="${STAGING_ROOT%/}/${RELEASE}.manifest"
        removed_path="${STAGING_ROOT%/}/${RELEASE}.removed"
        sums_path="${STAGING_ROOT%/}/SHA256SUMS"

        saydebug "Creating tar archive $tar_path_tar from staged files in $stage_path"

        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have created tar archive at: $tar_path_tar"
            sayinfo "Would have written manifest to: $manifest_path"
            sayinfo "Would have compared the selected removal baseline and written removals to: $removed_path"
            sayinfo "Would have updated checksums file: $sums_path"
            sayinfo "Would have generated manifest and compressed to: $tar_path_gz"
            sayinfo "Would have written checksum to: ${tar_path_gz}.sha256"
            sayinfo "Would have written checksum to: ${manifest_path}.sha256"
            sayinfo "Would have written checksum to: ${removed_path}.sha256"
        else

            # --- Create uncompressed tar -----------------------------------------------
            tar -C "$stage_path" \
                --owner=0 \
                --group=0 \
                --numeric-owner \
                -cpf "$tar_path_tar" . || { sayfail "tar failed."; return 1; }

            # --- Write uninstall manifest (external) ------------------------------------
            tar -tf "$tar_path_tar" \
                | sed 's|^\./||' \
                | sed '/^[[:space:]]*$/d' \
                > "$manifest_path" || { sayfail "Failed to write manifest."; return 1; }

            # --- Write removed-path delta ------------------------------------------------
            _sgnd_release_write_removed_manifest "$manifest_path" "$removed_path" \
                || { sayfail "Failed to write removal manifest."; return 1; }

            # --- Embed manifest into tar ------------------------------------------------
            tar -C "$STAGING_ROOT" \
                --owner=0 \
                --group=0 \
                --numeric-owner \
                -rf "$tar_path_tar" "${RELEASE}.manifest" \
                || { sayfail "Failed to embed manifest into tar."; return 1; }

            # --- Compress to tar.gz -----------------------------------------------------
            gzip -f "$tar_path_tar" || { sayfail "gzip failed."; return 1; }

            # --- Update SHA256SUMS ------------------------------------------------------
            _sgnd_release_write_checksum "$tar_path_gz" "$TAR_FILE" "$STAGING_ROOT" \
                || { sayfail "Failed to update SHA256SUMS."; return 1; }

            # Remove existing manifest entry (idempotent)
            sed -i "\|  $(basename "$manifest_path")$|d" "$sums_path" \
                || { sayfail "Failed to update SHA256SUMS (manifest)."; return 1; }

            manifest_base="$(basename "$manifest_path")"
            manifest_hash="$(sha256sum "$manifest_path" | awk '{print $1}')" \
                || { sayfail "Failed to hash manifest."; return 1; }

            printf '%s  %s\n' "$manifest_hash" "$manifest_base" >> "$sums_path" \
                || { sayfail "Failed to append manifest checksum to SHA256SUMS."; return 1; }

            # Add removal manifest checksum (idempotent)
            removed_base="$(basename "$removed_path")"
            removed_hash="$(sha256sum "$removed_path" | awk '{print $1}')" \
                || { sayfail "Failed to hash removal manifest."; return 1; }

            sed -i "\|  $removed_base$|d" "$sums_path" \
                || { sayfail "Failed to update SHA256SUMS (removal manifest)."; return 1; }

            printf '%s  %s\n' "$removed_hash" "$removed_base" >> "$sums_path" \
                || { sayfail "Failed to append removal manifest checksum to SHA256SUMS."; return 1; }

            # Write sidecar .sha256 files
            printf '%s  %s\n' "$(sha256sum "$tar_path_gz" | awk '{print $1}')" "$TAR_FILE" > "${tar_path_gz}.sha256"
            printf '%s  %s\n' "$manifest_hash" "$manifest_base" > "${manifest_path}.sha256"
            printf '%s  %s\n' "$removed_hash" "$removed_base" > "${removed_path}.sha256"

            sayinfo "Created $tar_path_gz"

            # Inspect archive (first few entries)
            tar -tf "$tar_path_gz" | head -n 30
        fi

        sayend "Done creating release."
        return 0
    }


    # fn: _find_release_manager_source - Resolve the release-manager source file
        # . Purpose
        #   Locate release-manager.sh in the managed source tree.
        #
        # . Returns
        #   0 with the path on stdout when found; 1 otherwise.
        #
        # . Usage
        #   manager="$(_find_release_manager_source)"
    _find_release_manager_source() {
        local direct="${SOURCE_DIR%/}/var/lib/solidgroundux/release-manager.sh"
        local candidate=""
        local -a candidates=()

        if [[ -f "$direct" ]]; then
            printf '%s\n' "$direct"
            return 0
        fi

        mapfile -t candidates < <(find "$SOURCE_DIR" -type f -name 'release-manager.sh' -not -path '*/releases/*' -print 2>/dev/null)
        (( ${#candidates[@]} == 1 )) || return 1

        candidate="${candidates[0]}"
        printf '%s\n' "$candidate"
    }

    # fn: _create_release_package - Create the complete distributable release ZIP
        # . Purpose
        #   Package the standalone release manager and release payload into one ZIP.
        #
        # . Behavior
        #   - Requires the six canonical release artifacts created by _create_tar.
        #   - Adds release-manager.sh at the ZIP root.
        #   - Does not include SHA256SUMS; the manager verifies individual sidecars.
        #
        # . Returns
        #   0 on success; 1 on missing artifacts or packaging failure.
        #
        # . Usage
        #   _create_release_package
    _create_release_package() {
        local manager=""
        local package_dir=""
        local zip_path="${STAGING_ROOT%/}/${RELEASE}-release.zip"
        local artifact=""
        local -a artifacts=(
            "${TAR_FILE}"
            "${TAR_FILE}.sha256"
            "${RELEASE}.manifest"
            "${RELEASE}.manifest.sha256"
            "${RELEASE}.removed"
            "${RELEASE}.removed.sha256"
        )

        manager="$(_find_release_manager_source)" || {
            sayfail "Could not uniquely locate release-manager.sh beneath $SOURCE_DIR"
            return 1
        }

        for artifact in "${artifacts[@]}"; do
            [[ -f "${STAGING_ROOT%/}/${artifact}" ]] || {
                sayfail "Missing release artifact for package: ${STAGING_ROOT%/}/${artifact}"
                return 1
            }
        done

        if (( ${FLAG_DRYRUN:-0} )); then
            sayinfo "Would have created release package: $zip_path"
            sayinfo "Would have included release-manager.sh and ${#artifacts[@]} release artifacts at ZIP root"
            return 0
        fi

        command -v zip >/dev/null 2>&1 || {
            sayfail "Required command not found: zip"
            return 1
        }

        package_dir="$(mktemp -d)" || return 1

        cp -f -- "$manager" "$package_dir/release-manager.sh" || {
            rm -rf -- "$package_dir"
            return 1
        }

        for artifact in "${artifacts[@]}"; do
            cp -f -- "${STAGING_ROOT%/}/${artifact}" "$package_dir/$artifact" || {
                rm -rf -- "$package_dir"
                return 1
            }
        done

        rm -f -- "$zip_path"
        (
            cd "$package_dir" || exit 1
            zip -q "$zip_path" "release-manager.sh" "${artifacts[@]}"
        ) || {
            rm -rf -- "$package_dir"
            sayfail "Failed to create release ZIP."
            return 1
        }

        rm -rf -- "$package_dir"
        sayok "Created release package: $zip_path"
        return 0
    }

    # fn: _archive_release_manifest - Persist the current manifest for future removal baselines
        # . Purpose
        #   Store the successfully packaged release manifest in persistent manifest history.
        #
        # . Returns
        #   0 on success; 1 on copy failure.
        #
        # . Usage
        #   _archive_release_manifest
    _archive_release_manifest() {
        local manifest_path="${STAGING_ROOT%/}/${RELEASE}.manifest"
        local destination="${MANIFEST_HISTORY_DIR%/}/${RELEASE}.manifest"

        [[ -f "$manifest_path" ]] || {
            sayfail "Cannot archive missing release manifest: $manifest_path"
            return 1
        }

        if (( ${FLAG_DRYRUN:-0} )); then
            sayinfo "Would have archived release manifest to: $destination"
            return 0
        fi

        mkdir -p -- "$MANIFEST_HISTORY_DIR" || return 1
        cp -f -- "$manifest_path" "$destination" || return 1
        sayinfo "Archived release manifest: $destination"
        return 0
    }

    # fn: _cleanup_staging - Remove gathered staging data
        # . Purpose
        #   Remove the release-specific staging directory if cleanup is enabled.
        #
        # . Behavior
        #   - Checks FLAG_CLEANUP to determine whether to remove the staging directory.
        #   - If FLAG_CLEANUP is 1, deletes the directory at STAGING_ROOT/RELEASE.
        #   - If FLAG_CLEANUP is 0, logs that cleanup is skipped.
        #
        # Inputs (globals):
        #   STAGING_ROOT
        #   RELEASE
        #   FLAG_CLEANUP
        #
        # . Side effects
        #   - Deletes files and directories under STAGING_ROOT/RELEASE when cleanup is enabled.
        #
        # . Returns
        #   0 on success (or if cleanup is skipped)
        #   1 if deletion fails
        #
        # . Usage
        #   _cleanup_staging
    _cleanup_staging() {
        if [[ "$FLAG_CLEANUP" -eq 1 ]]; then
            sayinfo "Cleaning up staging files in $STAGING_ROOT"
            rm -rf "${STAGING_ROOT%/}/$RELEASE" || {
                saywarning "Failed to remove staging directory: ${STAGING_ROOT%/}/$RELEASE"
            }
        else
            sayinfo "Skipping cleanup of staging files (--nocleanup)"
        fi
    }


    # fn: _set_script_header_version - Set an explicit version in a managed script header
        #
        # . Usage
        #   _set_script_header_version "/tmp/sgnd-example.txt" "1.8.0"
    _set_script_header_version() {
        local file="${1:-}"
        local version="${2:-}"

        [[ -n "$file" && -n "$version" ]] || return 2
        [[ -f "$file" ]] || return 1

        sed -i -E \
            "0,/^#([[:space:]]*)Version([[:space:]]*):[[:space:]]*.*/s//#\1Version\2: $version/" \
            "$file"
    }

    # fn: _apply_version_bump - Apply release metadata policy to managed source files
        # . Purpose
        #   Apply Version and Build according to A/C/N policy and always refresh Checksum
        #   for files whose source or metadata changed.
        #
        # . Behavior
        #   - Detects source changes by comparing the stored checksum with the current
        #     managed-body checksum.
        #   - MODE_UPDATEVERSION: A=all, C=changed, N=none.
        #   - MODE_UPDATEBUILD:   A=all, C=changed, N=none.
        #   - Any file changed by source edits or metadata policy receives a refreshed
        #     checksum after metadata updates are applied.
        #   - Optional major/minor bump flags override explicit Version policy.
        #
        # . Returns
        #   0 on success; 1 when one or more managed files could not be updated.
        #
        # . Usage
        #   _apply_version_bump
    _apply_version_bump() {
        local file=""
        local stored_checksum=""
        local current_checksum=""
        local source_changed=0
        local metadata_changed=0
        local failed=0
        local version_mode="${MODE_UPDATEVERSION:-C}"
        local -a failed_files=()
        local build_mode="${MODE_UPDATEBUILD:-C}"

        version_mode="${version_mode^^}"
        build_mode="${build_mode^^}"

        case "$version_mode" in A|C|N) ;; *) sayfail "Invalid version update mode: $version_mode"; return 1 ;; esac
        case "$build_mode" in A|C|N) ;; *) sayfail "Invalid build update mode: $build_mode"; return 1 ;; esac

        if (( ${FLAG_BUMP_MAJOR:-0} )) && (( ${FLAG_BUMP_MINOR:-0} )); then
            sayfail "Use either --bumpmajor or --bumpminor, not both"
            return 1
        fi

        while IFS= read -r -d '' file; do
            local existing_version=""

            # Files without a canonical Metadata/Version field are not managed by the
            # release metadata pass. Warn and continue; they must not block packaging.
            if ! sgnd_header_get_field "$file" "Metadata" "Version" existing_version; then
                saywarning "Skipping unmanaged file (missing metadata header): $file"
                continue
            fi

            current_checksum="$(sgnd_header_calc_checksum "$file")" || {
                saywarning "Skipping unmanaged file (checksum unavailable): $file"
                continue
            }

            sgnd_header_get_field "$file" "Metadata" "Checksum" stored_checksum || stored_checksum=""
            source_changed=0
            metadata_changed=0
            [[ "$stored_checksum" != "$current_checksum" ]] && source_changed=1

            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "[DRYRUN] $file source_changed=$source_changed version=$version_mode build=$build_mode"
                continue
            fi

            if (( ${FLAG_BUMP_MAJOR:-0} || ${FLAG_BUMP_MINOR:-0} )); then
                local bump_mode="major"
                (( ${FLAG_BUMP_MINOR:-0} )) && bump_mode="minor"
                sgnd_header_bump_version "$file" "$bump_mode" || { saywarning "Could not bump version in $file"; failed=1; failed_files+=("$file"); continue; }
                metadata_changed=1
            else
                if [[ "$version_mode" == "A" || ( "$version_mode" == "C" && "$source_changed" -eq 1 ) ]]; then
                    sgnd_header_upsert_field "$file" "Metadata" "Version" "$VERSION" || { saywarning "Could not set version in $file"; failed=1; failed_files+=("$file"); continue; }
                    metadata_changed=1
                fi

                if [[ "$build_mode" == "A" || ( "$build_mode" == "C" && "$source_changed" -eq 1 ) ]]; then
                    sgnd_header_upsert_field "$file" "Metadata" "Build" "$BUILD" || { saywarning "Could not set build in $file"; failed=1; failed_files+=("$file"); continue; }
                    metadata_changed=1
                fi

                if (( source_changed || metadata_changed )); then
                    current_checksum="$(sgnd_header_calc_checksum "$file")" || { saywarning "Could not calculate checksum for $file"; failed=1; failed_files+=("$file"); continue; }
                    sgnd_header_upsert_field "$file" "Metadata" "Checksum" "$current_checksum" || { saywarning "Could not set checksum in $file"; failed=1; failed_files+=("$file"); continue; }
                fi
            fi

            if (( source_changed || metadata_changed )); then
                sayok "Updated metadata in $file"
            else
                sayinfo "$file is unchanged, no metadata applied."
            fi
        done < <(find "$SOURCE_DIR" -type f -name '*.sh' -not -path '*/releases/*' -print0)

        local definitions_file
        definitions_file="$SOURCE_DIR/usr/local/lib/solidgroundux/common/sgnd-definitions.sh"

        if [[ -f "$definitions_file" ]]; then
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "[DRYRUN] Would have updated framework version identity in $definitions_file"
            else
                sgnd_framework_set_version "$definitions_file" "$VERSION" "$BUILD" \
                    || { sayfail "Failed to update framework version identity"; return 1; }
            fi
        else
            saydebug "No sgnd-definitions.sh in source tree; skipping framework version identity update."
        fi

        if (( failed )); then
            sayfail "One or more source files could not be prepared. Release creation aborted."
            if (( ${#failed_files[@]} > 0 )); then
                sayinfo "Files requiring attention:"
                local failed_file=""
                for failed_file in "${failed_files[@]}"; do
                    sgnd_print "    $failed_file"
                done
            fi
            return 1
        fi

        sayok "Source metadata preparation completed."
        return 0
    }


    # fn$ _ensure_libexec_executables
        # . Purpose
        #   Ensure top-level SolidGroundUX libexec files are executable before packaging.
        #
        # . Behavior
        #   - Inspects files directly beneath usr/local/libexec/solidgroundux.
        #   - Does not recurse into subdirectories.
        #   - Adds the executable bit for user, group, and others when missing.
        #   - Reports intended changes without modifying files in dry-run mode.
        #   - Succeeds quietly when the directory does not exist or contains no files.
        #
        # Inputs (globals):
        #   SOURCE_DIR
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when all applicable files are executable or the directory is absent.
        #   1 when one or more permission updates fail.
        #
        # . Usage
        #   _ensure_libexec_executables
    _ensure_libexec_executables() {
        local libexec_root="${SOURCE_DIR%/}/usr/local/libexec/solidgroundux"
        local file=""
        local failed=0

        [[ -d "$libexec_root" ]] || {
            saydebug "No SolidGroundUX libexec directory found at $libexec_root; skipping executable-bit verification."
            return 0
        }

        while IFS= read -r -d '' file; do
            [[ -x "$file" ]] && continue

            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "[DRYRUN] Would have set executable permissions on $file"
                continue
            fi

            if chmod a+x "$file"; then
                sayok "Set executable permissions on $file"
            else
                saywarning "Could not set executable permissions on $file"
                failed=1
            fi
        done < <(find "$libexec_root" -mindepth 1 -maxdepth 1 -type f -print0)

        return "$failed"
    }

    # fn: _ensure_public_command_wrappers - Ensure public wrappers exist for top-level libexec scripts
        # . Purpose
        #   Ensure every executable top-level shell script under the SolidGroundUX
        #   libexec directory has a matching public command wrapper in /usr/local/bin.
        #
        # . Behavior
        #   - Inspects executable *.sh files directly beneath usr/local/libexec/solidgroundux.
        #   - Uses the script basename without .sh as the public command name.
        #   - Leaves existing wrappers untouched.
        #   - Creates only missing wrappers when FLAG_CREATEWRAPPERS=1.
        #   - Reports missing wrappers without creating them when the option is disabled.
        #   - Honors dry-run mode.
        #
        # Inputs (globals):
        #   SOURCE_DIR
        #   FLAG_CREATEWRAPPERS
        #   FLAG_DRYRUN
        #
        # Side effects:
        #   May create executable files beneath SOURCE_DIR/usr/local/bin.
        #
        # . Returns
        #   0 when all wrappers exist or missing wrappers were created successfully.
        #   1 when one or more wrapper creations fail.
        #
        # . Usage
        #   _ensure_public_command_wrappers
    _ensure_public_command_wrappers() {
        local libexec_root="${SOURCE_DIR%/}/usr/local/libexec/solidgroundux"
        local bin_root="${SOURCE_DIR%/}/usr/local/bin"
        local script=""
        local script_base=""
        local command_name=""
        local wrapper=""
        local installed_target=""
        local missing=0
        local created=0
        local failed=0

        [[ -d "$libexec_root" ]] || {
            saydebug "No SolidGroundUX libexec directory found at $libexec_root; skipping wrapper verification."
            return 0
        }

        while IFS= read -r -d '' script; do
            script_base="$(basename -- "$script")"
            command_name="${script_base%.sh}"
            wrapper="${bin_root}/${command_name}"
            installed_target="/usr/local/libexec/solidgroundux/${script_base}"

            [[ -e "$wrapper" || -L "$wrapper" ]] && continue

            (( missing++ ))

            if (( ! ${FLAG_CREATEWRAPPERS:-0} )); then
                saywarning "Missing command wrapper: $wrapper -> $installed_target"
                continue
            fi

            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "[DRYRUN] Would create command wrapper: $wrapper -> $installed_target"
                continue
            fi

            mkdir -p -- "$bin_root" || {
                saywarning "Could not create wrapper directory: $bin_root"
                failed=1
                continue
            }

            printf '%s\n' \
                '#!/usr/bin/env bash' \
                "exec \"$installed_target\" \"\$@\"" \
                > "$wrapper" || {
                    saywarning "Could not create command wrapper: $wrapper"
                    failed=1
                    continue
                }

            chmod 0755 -- "$wrapper" || {
                saywarning "Could not make command wrapper executable: $wrapper"
                failed=1
                continue
            }

            sayok "Created command wrapper: $wrapper -> $installed_target"
            (( created++ ))
        done < <(find "$libexec_root" -mindepth 1 -maxdepth 1 -type f -name '*.sh' -perm /111 -print0)

        if (( missing == 0 )); then
            sayinfo "All executable top-level libexec scripts have public command wrappers."
        elif (( ${FLAG_CREATEWRAPPERS:-0} )); then
            sayinfo "Wrapper summary: $created created, $failed failed."
        else
            saywarning "Wrapper summary: $missing missing; creation disabled."
        fi

        return "$failed"
    }

# --- Main Sequence -------------------------------------------------------------------
    # fn: main - Run the executable main sequence - Run the executable main sequence
        # . Purpose
        #   Execute the release preparation workflow.
        #
        # . Behavior
        #   - Loads and initializes the framework bootstrap.
        #   - Executes builtin framework argument handling.
        #   - Prepares the standard UI state and title bar.
        #   - Resolves release parameters.
        #   - Creates the release archive and related metadata.
        #
        # . Arguments
        #   $@  Framework and script-specific command-line arguments
        #
        # . Returns
        #   Exits with the resulting status from bootstrap or release operations
        #
        # . Usage
        #   main "$@"
        #
        # Examples:
        #   main "$@"
    main() {
        # -- Startup
            _framework_locator || exit $?
            sgnd_exe_start --state -- "$@"

        # -- Main script logic

        _get_parameters || exit $?

        _apply_version_bump || {
            sayfail "Metadata preparation failed; release was not created."
            exit 1
        }

        _ensure_libexec_executables || {
            sayfail "Executable verification failed; release was not created."
            exit 1
        }

        _ensure_public_command_wrappers || {
            sayfail "Wrapper verification failed; release was not created."
            exit 1
        }

        _create_tar || {
            sayfail "Release archive creation failed."
            exit 1
        }

        _create_release_package || {
            sayfail "Release package creation failed."
            exit 1
        }

        _archive_release_manifest || {
            sayfail "Release manifest history update failed."
            exit 1
        }

        _cleanup_staging
    }

    # Run main with positional args only (not the options)
    main "$@"
