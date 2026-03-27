#!/usr/bin/env bash
# =====================================================================================
# SolidgroundUX - Prepare Release
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.0
#   Build       : 2608301
#   Checksum    : d3bc648060f0a904ebc96c50b710cd3378066bdfb731f3dec616f664b29a7566
#   Source      : prepare-release.sh
#   Type        : script
#   Purpose     : Prepare framework scripts for release
#
# Description:
#   Provides a release-preparation utility for SolidgroundUX workspaces.
#
#   The script:
#     - Selects target scripts by file or folder
#     - Refreshes version, build, and checksum metadata unless source updates are disabled
#     - Applies optional major or minor version bumps
#     - Supports dry-run verification before committing changes
#     - Ensures release metadata is consistent across processed scripts
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
#   - Packaging release artifacts
#   - Deploying files to target environments
#   - Managing version control, tagging, or publication workflows
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
    # _framework_locator
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
        # Examples:
        #   _framework_locator
        #
        # Notes:
        #   - Under sudo, configuration is resolved relative to SUDO_USER instead of /root.
    _framework_locator (){
        local cfg_home="$HOME"

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        local cfg_user="$cfg_home/.config/testadura/solidgroundux.cfg"
        local cfg_sys="/etc/testadura/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="$fw_root"
        local reply

        # Determine existing configuration
        if [[ -r "$cfg_user" ]]; then
            cfg="$cfg_user"

        elif [[ -r "$cfg_sys" ]]; then
            cfg="$cfg_sys"

        else
            # Determine creation location
            if [[ $EUID -eq 0 ]]; then
                cfg="$cfg_sys"
            else
                cfg="$cfg_user"
            fi

            # Interactive prompts (first run only)
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

            # Validate paths (must be absolute)
            case "$fw_root" in
                /*) ;;
                *) sayfail "ERR: SGND_FRAMEWORK_ROOT must be an absolute path"; return 126 ;;
            esac

            case "$app_root" in
                /*) ;;
                *) sayfail "ERR: SGND_APPLICATION_ROOT must be an absolute path"; return 126 ;;
            esac

            # Create configuration file
            mkdir -p "$(dirname "$cfg")" || return 127

            # write cfg file
            {
                printf '%s\n' "# SolidGroundUX bootstrap configuration"
                printf '%s\n' "# Auto-generated on first run"
                printf '\n'
                printf 'SGND_FRAMEWORK_ROOT=%q\n' "$fw_root"
                printf 'SGND_APPLICATION_ROOT=%q\n' "$app_root"
            } > "$cfg" || return 127

            saydebug "Created bootstrap cfg: $cfg"
        fi

        # Load configuration
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

    # _load_bootstrapper
        # Purpose:
        #   Resolve and source the framework bootstrap library.
        #
        # Behavior:
        #   - Calls _framework_locator to establish framework roots.
        #   - Derives the sgnd-bootstrap.sh path from SGND_FRAMEWORK_ROOT.
        #   - Verifies that the bootstrap library is readable.
        #   - Sources sgnd-bootstrap.sh into the current shell.
        #
        # Inputs (globals):
        #   SGND_FRAMEWORK_ROOT
        #
        # Returns:
        #   0   success
        #   126 bootstrap library unreadable
        #
        # Usage:
        #   _load_bootstrapper || return $?
        #
        # Examples:
        #   _load_bootstrapper
        #
        # Notes:
        #   - This is executable-level startup logic, not reusable framework behavior.
    _load_bootstrapper(){
        local bootstrap=""

        _framework_locator || return $?

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            bootstrap="/usr/local/lib/testadura/common/sgnd-bootstrap.sh"
        else
            bootstrap="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/testadura/common/sgnd-bootstrap.sh"
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
    MSG_CLR_EMPTY=$'\e[2;38;5;250m'
    MSG_CLR_DEBUG=$'\e[1;35m'

    TUI_COMMIT=$'\e[2;37m'
    RESET=$'\e[0m'

    # Minimal UI
    saystart()   { printf '%sSTART%s\t%s\n' "${MSG_CLR_STRT-}" "${RESET-}" "$*" >&2; }
    sayinfo()    {
        if (( ${FLAG_VERBOSE:-0} )); then
            printf '%sINFO%s \t%s\n' "${MSG_CLR_INFO-}" "${RESET-}" "$*" >&2;
        fi
    }
    sayok()      { printf '%sOK%s   \t%s\n' "${MSG_CLR_OK-}"   "${RESET-}" "$*" >&2; }
    saywarning() { printf '%sWARN%s \t%s\n' "${MSG_CLR_WARN-}" "${RESET-}" "$*" >&2; }
    sayfail()    { printf '%sFAIL%s \t%s\n' "${MSG_CLR_FAIL-}" "${RESET-}" "$*" >&2; }
    saydebug() {
        if (( ${FLAG_DEBUG:-0} )); then
            printf '%sDEBUG%s \t%s\n' "${MSG_CLR_DEBUG-}" "${RESET-}" "$*" >&2;
        fi
    }
    saycancel() { printf '%sCANCEL%s\t%s\n' "${MSG_CLR_CNCL-}" "${RESET-}" "$*" >&2; }
    sayend() { printf '%sEND%s   \t%s\n' "${MSG_CLR_END-}" "${RESET-}" "$*" >&2; }

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
        sgnd-comment-parser.sh
    )

    # SGND_ARGS_SPEC
        # Optional: script-specific arguments
    # SGND_ARGS_SPEC
        # Each entry:
        #   "name|short|type|var|help|choices"
        #
        #   name    = long option name WITHOUT leading --
        #   short   - short option name WITHOUT leading -
        #   type    = flag | value | enum
        #   var     = shell variable that will be set
        #   help    = help string for auto-generated --help output
        #   choices = for enum: comma-separated values (e.g. fast,slow,auto)
        #             for flag/value: leave empty
        #
        # Notes:
        #   - -h / --help is built in, you don't need to define it here.
        #   - After parsing you can use: FLAG_VERBOSE, VAL_CONFIG, ENUM_MODE, ...
    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Repeat with last settings|"
        "cleanup|c|flag|FLAG_CLEANUP|Cleanup staging files after run|"
        "useexisting|u|flag|FLAG_USEEXISTING|Use existing staging files|"
        "bumpmajor||flag|FLAG_BUMP_MAJOR|Bump major version in source headers before packaging|"
        "bumpminor||flag|FLAG_BUMP_MINOR|Bump minor version in source headers before packaging|"
        "updatebuild||flag|FLAG_UPDATEBUILD|Update source header metadata before packaging|"
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
        # Purpose:
        #   - Declares which globals are part of the script’s public/config contract.
        #   - Enables optional configuration loading when non-empty.
        #
        # Behavior:
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
        # Purpose:
        #   - Declares which variables should be saved/restored when state is enabled.
        #
        # Behavior:
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
    )

    # SGND_ON_EXIT_HANDLERS
        # List of functions to be invoked on script termination.
        #
        # Purpose:
        #   - Allows scripts to register cleanup or finalization hooks.
        #
        # Behavior:
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
    SGND_STATE_SAVE=0

# --- Local script Declarations -------------------------------------------------------
    # Put script-local constants and defaults here (NOT framework config).
    # Prefer local variables inside functions unless a value must be shared.

# --- Local script functions ----------------------------------------------------------
    # _save_parameters
        # Purpose:
        #   Persist the current release parameters to the framework state store.
        #
        # Behavior:
        #   - Saves all resolved and confirmed release parameters for later reuse.
        #   - Supports repeatable runs through --auto mode.
        #   - Skips state writes when FLAG_DRYRUN is enabled.
        #
        # Inputs (globals):
        #   RELEASE
        #   SOURCE_DIR
        #   STAGING_ROOT
        #   TAR_FILE
        #   FLAG_CLEANUP
        #   FLAG_USEEXISTING
        #   FLAG_DRYRUN
        #
        # Side effects:
        #   - Writes state entries via sgnd_state_set when not in dry-run mode.
        #
        # Returns:
        #   0 on success
        #   Non-zero if state storage fails
        #
        # Usage:
        #   _save_parameters
        #
        # Examples:
        #   _save_parameters || return 1
        #
        # Notes:
        #   - Requires sgnd_bootstrap --state so the state backend is available.
    _save_parameters(){
        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have saved state variables (manual)"
        else
            saydebug "Saving state variables (manual)"
            sgnd_state_set "PRODUCT" "$PRODUCT"
            sgnd_state_set "VERSION" "$VERSION"
            sgnd_state_set "RELEASE" "$RELEASE"
            sgnd_state_set "SOURCE_DIR" "$SOURCE_DIR"
            sgnd_state_set "STAGING_ROOT" "$STAGING_ROOT"
            sgnd_state_set "TAR_FILE" "$TAR_FILE"
            sgnd_state_set "FLAG_CLEANUP" "$FLAG_CLEANUP"
            sgnd_state_set "FLAG_USEEXISTING" "$FLAG_USEEXISTING"
            sgnd_state_set "FLAG_SAVEPARMS" "$FLAG_SAVEPARMS"
        fi
    }

    # _get_parameters
        # Purpose:
        #   Resolve and collect all parameters required to prepare a release archive.
        #
        # Behavior:
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
        # Returns:
        #   0 on successful resolution and confirmation
        #   Exits the script with status 1 if the user cancels
        #
        # Usage:
        #   _get_parameters
        #
        # Examples:
        #   _get_parameters || return 1
        #
        # Notes:
        #   - Uses ask() and ask_ok_redo_quit() for interactive input.
        #   - Auto mode assumes state was loaded during bootstrap (--state).
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
        FLAG_UPDATEBUILD="${FLAG_UPDATEBUILD:-1}"

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
            sgnd_print_labeledvalue --label "Build" --value "$BUILD" --coloriz both --lableclr "$(sgnd_sgr "$SILVER" "" "$FX_ITALIC")" --valueclr "$(sgnd_sgr "$SILVER" "" "$FX_ITALIC")" --pad "$lp" --labelwidth "$lw"

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

            if [[ "$FLAG_UPDATEBUILD" -eq 1 ]]; then
                upd="Y"
            else
                upd="N"
            fi
            ask --label "Cleanup staging files after run (Y/N)" --var cleanup --default "$upd" --colorize both --labelclr "${CYAN}" --pad "$lp" --labelwidth "$lw"
            if [[ "$cleanup" == "Y" || "$cleanup" == "y" ]]; then
                FLAG_UPDATEBUILD=1
            else
                FLAG_UPDATEBUILD=0
            fi

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
    }

    # sgnd_release_write_checksum
        # Purpose:
        #   Add or update a SHA256SUMS entry for a release artifact.
        #
        # Behavior:
        #   - Ensures SHA256SUMS contains exactly one entry for the specified filename.
        #   - Removes any existing line for the same filename before appending a new one.
        #   - Stores only the basename in the checksum file.
        #
        # Arguments:
        #   $1  TAR_PATH
        #       Path to the file to hash.
        #   $2  TAR_FILE
        #       Filename to write into SHA256SUMS.
        #   $3  STAGING_ROOT
        #       Directory containing SHA256SUMS.
        #
        # Side effects:
        #   - Creates or updates:
        #       <staging_root>/SHA256SUMS
        #
        # Returns:
        #   0 on success
        #   1 if required arguments are missing or file operations fail
        #
        # Usage:
        #   sgnd_release_write_checksum "$tar_path" "$TAR_FILE" "$STAGING_ROOT"
        #
        # Examples:
        #   sgnd_release_write_checksum "$tar_path_gz" "$TAR_FILE" "$STAGING_ROOT"
        #
        # Notes:
        #   - Idempotent for a given filename.
        #   - Requires sha256sum, sed, awk, and write permission to staging_root.
    sgnd_release_write_checksum() {
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

    # _create_tar
        # Purpose:
        #   Stage a clean release tree and produce a versioned tar.gz archive.
        #
        # Behavior:
        #   - Ensures the release-specific staging directory exists.
        #   - Populates the staging directory from SOURCE_DIR via rsync.
        #   - Reuses existing staging files when requested and non-empty.
        #   - Creates an uncompressed tar archive from the staged files.
        #   - Generates an uninstall manifest from the tar contents.
        #   - Embeds the manifest into the tar archive.
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
        # Side effects:
        #   - Creates and updates staged files and release artifacts under STAGING_ROOT.
        #
        # Output artifacts:
        #   - $STAGING_ROOT/$TAR_FILE
        #   - $STAGING_ROOT/$RELEASE.manifest
        #   - $STAGING_ROOT/SHA256SUMS
        #   - $STAGING_ROOT/$TAR_FILE.sha256
        #   - $STAGING_ROOT/$RELEASE.manifest.sha256
        #
        # Returns:
        #   0 on success
        #   1 on failure to stage, package, hash, or write artifacts
        #
        # Usage:
        #   _create_tar
        #
        # Examples:
        #   _create_tar || return 1
        #
        # Notes:
        #   - In dry-run mode, only reports the intended actions.
        #   - Manifest is generated before embedding, so it does not list itself.
    _create_tar() {
        saystart "Creating release: $RELEASE"

        local stage_path tar_path_tar tar_path_gz manifest_path sums_path
        local manifest_base manifest_hash

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
        sums_path="${STAGING_ROOT%/}/SHA256SUMS"

        saydebug "Creating tar archive $tar_path_tar from staged files in $stage_path"

        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have created tar archive at: $tar_path_tar"
            sayinfo "Would have written manifest to: $manifest_path"
            sayinfo "Would have updated checksums file: $sums_path"
            sayinfo "Would have generated manifest and compressed to: $tar_path_gz"
            sayinfo "Would have written checksum to: ${tar_path_gz}.sha256"
            sayinfo "Would have written checksum to: ${manifest_path}.sha256"
        else

            # --- Create uncompressed tar -----------------------------------------------
            tar -C "$stage_path" -cpf "$tar_path_tar" . || { sayfail "tar failed."; return 1; }

            # --- Write uninstall manifest (external) ------------------------------------
            tar -tf "$tar_path_tar" \
                | sed 's|^\./||' \
                | sed '/^[[:space:]]*$/d' \
                > "$manifest_path" || { sayfail "Failed to write manifest."; return 1; }

            # --- Embed manifest into tar ------------------------------------------------
            tar -C "$STAGING_ROOT" -rf "$tar_path_tar" "${RELEASE}.manifest" \
                || { sayfail "Failed to embed manifest into tar."; return 1; }

            # --- Compress to tar.gz -----------------------------------------------------
            gzip -f "$tar_path_tar" || { sayfail "gzip failed."; return 1; }

            # --- Update SHA256SUMS ------------------------------------------------------
            sgnd_release_write_checksum "$tar_path_gz" "$TAR_FILE" "$STAGING_ROOT" \
                || { sayfail "Failed to update SHA256SUMS."; return 1; }

            # Remove existing manifest entry (idempotent)
            sed -i "\|  $(basename "$manifest_path")$|d" "$sums_path" \
                || { sayfail "Failed to update SHA256SUMS (manifest)."; return 1; }

            manifest_base="$(basename "$manifest_path")"
            manifest_hash="$(sha256sum "$manifest_path" | awk '{print $1}')" \
                || { sayfail "Failed to hash manifest."; return 1; }

            printf '%s  %s\n' "$manifest_hash" "$manifest_base" >> "$sums_path" \
                || { sayfail "Failed to append manifest checksum to SHA256SUMS."; return 1; }

            # Write sidecar .sha256 files
            printf '%s  %s\n' "$(sha256sum "$tar_path_gz" | awk '{print $1}')" "$TAR_FILE" > "${tar_path_gz}.sha256"
            printf '%s  %s\n' "$manifest_hash" "$manifest_base" > "${manifest_path}.sha256"

            sayinfo "Created $tar_path_gz"

            # Inspect archive (first few entries)
            tar -tf "$tar_path_gz" | head -n 30
        fi

        sayend "Done creating release."
        return 0
    }

    # _apply_version_bump
        # Purpose:
        #   Apply header checksum/build refresh and optional version bumping to source files.
        #
        # Behavior:
        #   - Scans SOURCE_DIR for readable shell source files.
        #   - Applies sgnd_header_bump_version to each file.
        #   - Uses --bumpmajor or --bumpminor to decide the bump mode.
        #   - When no bump flag is set, refreshes build/checksum only for changed files.
        #   - Reports unchanged files separately.
        #   - In dry-run mode, reports intended actions without modifying files.
        #
        # Inputs (globals):
        #   SOURCE_DIR
        #   FLAG_BUMP_MAJOR
        #   FLAG_BUMP_MINOR
        #   FLAG_DRYRUN
        #   FLAG_NOSOURCEUPDATE
        #
        # Returns:
        #   0 on success
        #   1 on failure
    _apply_version_bump() {
        local mode="none"
        local file=""
        local failed=0

        if (( ${FLAG_NOSOURCEUPDATE:-0} )); then
            sayinfo "Skipping source header metadata updates (--nosourceupdate)"
            return 0
        fi

        if (( ${FLAG_BUMP_MAJOR:-0} )) && (( ${FLAG_BUMP_MINOR:-0} )); then
            sayfail "Use either --bumpmajor or --bumpminor, not both"
            return 1
        fi

        if (( ${FLAG_BUMP_MAJOR:-0} )); then
            mode="major"
        elif (( ${FLAG_BUMP_MINOR:-0} )); then
            mode="minor"
        else
            mode="none"
        fi

        while IFS= read -r -d '' file; do
            if (( ${FLAG_DRYRUN:-0} )); then
                case "$mode" in
                    major) sayinfo "[DRYRUN] Would have bumped major version in $file" ;;
                    minor) sayinfo "[DRYRUN] Would have bumped minor version in $file" ;;
                    none)  sayinfo "[DRYRUN] Would have refreshed build/checksum in $file if needed" ;;
                esac
                continue
            fi

            if sgnd_header_bump_version "$file" "$mode"; then
                if (( ${SGND_HEADER_BUMP_CHANGED:-0} )); then
                    case "$mode" in
                        major) sayok "Bumped major version in $file" ;;
                        minor) sayok "Bumped minor version in $file" ;;
                        none)  sayok "Updated build/checksum in $file" ;;
                    esac
                else
                    sayinfo "$file is unchanged, no new buildnr applied."
                fi
            else
                saywarning "Skipping unmanaged file (no valid header): $file"
                failed=1
            fi
        done < <(find "$SOURCE_DIR" -type f -name '*.sh' -not -path '*/releases/*' -print0)

        return "$failed"
    }

# --- Main Sequence -------------------------------------------------------------------
    # main
        # Purpose:
        #   Execute the release preparation workflow.
        #
        # Behavior:
        #   - Loads and initializes the framework bootstrap.
        #   - Executes builtin framework argument handling.
        #   - Prepares the standard UI state and title bar.
        #   - Resolves release parameters.
        #   - Creates the release archive and related metadata.
        #
        # Arguments:
        #   $@  Framework and script-specific command-line arguments
        #
        # Returns:
        #   Exits with the resulting status from bootstrap or release operations
        #
        # Usage:
        #   main "$@"
        #
        # Examples:
        #   main "$@"
    main() {
        # -- Bootstrap
            local rc=0

            _load_bootstrapper || exit $?

            # Recognized switches:
            #     --state      -> enable saving state variables
            #     --autostate  -> enable state support and auto-save SGND_STATE_VARIABLES on exit
            #     --needroot   -> restart script if not root
            #     --cannotroot -> exit script if root
            #     --log        -> enable file logging
            #     --console    -> enable console logging
            # Example:
            #   sgnd_bootstrap --state --needroot -- "$@"
            sgnd_bootstrap -- "$@"
            rc=$?

            saydebug "After bootstrap: $rc"
            (( rc != 0 )) && exit "$rc"

        # -- Handle builtin arguments
            saydebug "Calling builtinarg handler"
            sgnd_builtinarg_handler
            saydebug "Exited builtinarg handler"

        # -- UI
            sgnd_update_runmode
            sgnd_print_titlebar

        # -- Main script logic

        _get_parameters
        _apply_version_bump || exit $?
        _create_tar
    }

    # Run main with positional args only (not the options)
    main "$@"