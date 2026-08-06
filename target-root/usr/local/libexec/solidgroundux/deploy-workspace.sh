#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Deploy Workspace
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621814
#   Checksum    : 2ce7581258f0ea52e5d3553b03125393df6a7152fa410bd422052c613c41d890
#   Source      : deploy-workspace-v4.sh
#   Type        : script
#   Group       : SDK Tools
#   Purpose     : Select workspace files and deploy them through receive-files.sh
#
# Description:
#   Collects deployment settings from command-line arguments and interactive prompts,
#   resolves the requested workspace files into a concrete relative path list, creates
#   a tar stream, and passes that stream to receive-files.sh locally or over SSH.
#
# Design principles:
#   - Selection and transport remain separate from destination-side installation policy
#   - Local and remote deployment use the same receive-files.sh contract
#   - Command-line values override saved defaults
#   - Confirmed deployment settings are always saved; the success timestamp changes only after a successful receive operation
#   - Changed-after defaults to the last successful deployment timestamp when available
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
        #   - Loads sgnd-exe-common.sh from the resolved framework root.
        #
        # . Globals (write)
        #   SGND_FRAMEWORK_ROOT
        #   SGND_APPLICATION_ROOT
        #
        # . Returns
        #   0 when the bootstrap configuration and executable common library were loaded.
        #   126 when configuration or executable common library is unreadable or invalid.
        #   127 when the configuration directory or file could not be created.
        #
        # . Usage
        #   _framework_locator || return $?
    _framework_locator() {
        local cfg_home="$HOME"
        local cfg_user=""
        local cfg_sys="/etc/solidgroundux/solidgroundux.cfg"
        local cfg=""
        local fw_root="/"
        local app_root="/"
        local reply=""
        local exe_common=""

        if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            cfg_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        fi

        cfg_user="$cfg_home/.config/solidgroundux/solidgroundux.cfg"

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

                printf 'SGND_FRAMEWORK_ROOT [/] : ' > /dev/tty
                read -r reply < /dev/tty
                fw_root="${reply:-/}"

                printf 'SGND_APPLICATION_ROOT [%s] : ' "$fw_root" > /dev/tty
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
        fi

        # shellcheck source=/dev/null
        source "$cfg" || return 126
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

# --- Script metadata (identity) ------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Deploy workspace"
    : "${SGND_SCRIPT_DESC:=Select and stream development workspace files to a SolidGroundUX receiver.}"
    : "${SGND_SCRIPT_VERSION:=1.8}"
    : "${SGND_SCRIPT_BUILD:=2621602}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

# --- Script metadata (framework integration) -----------------------------------------
    SGND_USING=(
    )

    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Deploy immediately using saved settings|0|"
        "local|l|flag|FLAG_LOCAL|Deploy to the local system|0|"
        "remote|r|value|REMOTE_TARGET|Deploy through SSH to user@host|"
        "source|s|value|SRC_ROOT|Workspace source root|"
        "target|t|value|DEST_ROOT|Destination filesystem root|"
        "directory|d|value|SELECT_DIRECTORY|Optional directory below the workspace root|"
        "match|m|value|SELECT_MATCH|Comma-separated filenames or shell-style file masks|"
        "changed-after|c|value|CHANGED_AFTER|Only include files modified after this date, timestamp, or datetime shortcut|"
        "since-last||flag|FLAG_SINCE_LAST|Only include files changed since the last successful deployment|0|"
        "receiver||value|RECEIVER_PATH|Path to receive-files.sh on the destination|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Deploy all shell files beneath one directory locally:"
        "  $SGND_SCRIPT_NAME --local --source /srv/solidgroundux/target-root --directory usr/local/lib/solidgroundux --match '*.sh'"
        ""
        "Deploy one named file remotely:"
        "  $SGND_SCRIPT_NAME --remote sysadmin@192.168.0.253 --match sgnd-console.sh"
        ""
        "Deploy files changed since the last successful deployment:"
        "  $SGND_SCRIPT_NAME --remote sysadmin@192.168.0.253 --since-last"
    )

    SGND_SCRIPT_GLOBALS=(
    )

    SGND_STATE_VARIABLES=(
        DEPLOY_TRANSPORT
        REMOTE_TARGET
        SRC_ROOT
        DEST_ROOT
        SELECT_DIRECTORY
        SELECT_MATCH
        RECEIVER_PATH
        LAST_DEPLOY_SUCCESS
    )

    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=1

# --- Local declarations ---------------------------------------------------------------
    DEPLOY_TRANSPORT="${DEPLOY_TRANSPORT:-}"
    REMOTE_TARGET="${REMOTE_TARGET:-}"
    SRC_ROOT="${SRC_ROOT:-}"
    DEST_ROOT="${DEST_ROOT:-}"
    SELECT_DIRECTORY="${SELECT_DIRECTORY:-}"
    SELECT_MATCH="${SELECT_MATCH:-}"
    CHANGED_AFTER="${CHANGED_AFTER:-}"
    RECEIVER_PATH="${RECEIVER_PATH:-}"
    LAST_DEPLOY_SUCCESS="${LAST_DEPLOY_SUCCESS:-}"

    CLI_DEPLOY_TRANSPORT=0
    CLI_REMOTE_TARGET=0
    CLI_SRC_ROOT=0
    CLI_DEST_ROOT=0
    CLI_SELECT_DIRECTORY=0
    CLI_SELECT_MATCH=0
    CLI_CHANGED_AFTER=0
    CLI_SINCE_LAST=0
    CLI_RECEIVER_PATH=0

    SELECTED_PATHS=()
    DEPLOY_STARTED_AT=""
    DEPLOY_FINISHED_AT=""

# --- Selection helpers ---------------------------------------------------------------
    # fn: _is_deployable_path - Test whether a relative workspace path is deployable
        # . Arguments
        #   $1  Relative path beneath SRC_ROOT.
        #
        # . Returns
        #   0 when the path is deployable.
        #   1 when the path is top-level, hidden, private, or marked .old.
        #
        # . Usage
        #   _is_deployable_path "usr/local/bin/sgnd-console"
    _is_deployable_path() {
        local rel="$1"
        local name=""

        name="$(basename -- "$rel")"

        [[ "$rel" == */* ]] || return 1
        [[ "$name" != _* ]] || return 1
        [[ "$name" != *.old ]] || return 1
        [[ "$rel" != .*/* ]] || return 1
        [[ "$rel" != _*/* ]] || return 1
        [[ "$rel" != */.*/* ]] || return 1
        [[ "$rel" != */_*/* ]] || return 1
        return 0
    }

    # fn: _normalize_relative_path - Normalize and validate a workspace-relative path
        # . Arguments
        #   $1  User-provided path.
        #
        # . Output
        #   Writes the normalized relative path to stdout.
        #
        # . Returns
        #   0 when the path is safe and remains beneath SRC_ROOT.
        #   1 for absolute paths, empty paths, or parent traversal.
        #
        # . Usage
        #   rel="$(_normalize_relative_path "usr/local/bin")"
    _normalize_relative_path() {
        local rel="${1#./}"

        rel="${rel%/}"
        [[ -n "$rel" && "$rel" != /* ]] || return 1
        [[ "$rel" != ".." && "$rel" != ../* && "$rel" != */../* && "$rel" != */.. ]] || return 1
        printf '%s\n' "$rel"
    }

    # fn: _add_selected_file - Add one deployable file to the normalized selection
        # . Arguments
        #   $1  Absolute filename beneath SRC_ROOT.
        #
        # . Side effects
        #   Appends a relative path to SELECTED_PATHS when eligible.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _add_selected_file "$SRC_ROOT/usr/local/bin/sgnd-console"
    _add_selected_file() {
        local file="$1"
        local rel=""

        [[ -f "$file" ]] || return 0
        rel="${file#"$SRC_ROOT"/}"
        [[ "$rel" != "$file" ]] || return 0
        _is_deployable_path "$rel" || return 0
        SELECTED_PATHS+=("$rel")
    }

    # fn: _select_files - Resolve the combined workspace filters into a concrete file list
        # . Purpose
        #   Select deployable files by optional directory, filename or mask, and modification time.
        #
        # . Inputs (globals)
        #   SRC_ROOT, SELECT_DIRECTORY, SELECT_MATCH, CHANGED_AFTER,
        #   FLAG_SINCE_LAST, LAST_DEPLOY_SUCCESS
        #
        # . Outputs (globals)
        #   SELECTED_PATHS
        #
        # . Returns
        #   0 when at least one deployable file was selected.
        #   1 when a filter is invalid or no files match.
        #
        # . Usage
        #   _select_files || return $?
    _select_files() {
        local search_root="$SRC_ROOT"
        local directory=""
        local match_list="${SELECT_MATCH:-*}"
        local changed_after="${CHANGED_AFTER:-1900-01-01}"
        local candidate=""
        local pattern=""
        local -a patterns=()

        SELECTED_PATHS=()

        if [[ -n "${SELECT_DIRECTORY:-}" ]]; then
            directory="$(_normalize_relative_path "$SELECT_DIRECTORY")" || {
                sayfail "Invalid relative directory path: $SELECT_DIRECTORY"
                return 1
            }
            search_root="$SRC_ROOT/$directory"
        fi

        [[ -d "$search_root" ]] || {
            sayfail "Selection directory not found: $search_root"
            return 1
        }

        if [[ "${FLAG_SINCE_LAST:-0}" -eq 1 ]]; then
            [[ -n "${LAST_DEPLOY_SUCCESS:-}" ]] || {
                sayfail "No successful deployment timestamp is available for --since-last."
                return 1
            }
            changed_after="$LAST_DEPLOY_SUCCESS"
        fi

        IFS=',' read -r -a patterns <<< "$match_list"

        for pattern in "${patterns[@]}"; do
            pattern="${pattern#"${pattern%%[![:space:]]*}"}"
            pattern="${pattern%"${pattern##*[![:space:]]}"}"
            [[ -n "$pattern" ]] || continue

            while IFS= read -r -d '' candidate; do
                _add_selected_file "$candidate"
            done < <(find "$search_root" -type f -name "$pattern" -newermt "$changed_after" -print0)
        done

        if (( ${#SELECTED_PATHS[@]} == 0 )); then
            saywarning "No deployable files matched the filters."
            return 1
        fi

        mapfile -d '' -t SELECTED_PATHS < <(printf '%s\0' "${SELECTED_PATHS[@]}" | sort -zu)
        sayinfo "Selected ${#SELECTED_PATHS[@]} file(s)."
        return 0
    }

# --- Parameter collection ------------------------------------------------------------
    # fn: _capture_cli_parameters - Record which deployment settings were supplied explicitly
        # . Purpose
        #   Distinguish command-line values from state/default values so explicit settings
        #   are not prompted again.
        #
        # . Arguments
        #   $@  Original executable arguments.
        #
        # Outputs (globals)
        #   CLI_DEPLOY_TRANSPORT, CLI_REMOTE_TARGET, CLI_SRC_ROOT, CLI_DEST_ROOT,
        #   CLI_SELECT_DIRECTORY, CLI_SELECT_MATCH, CLI_CHANGED_AFTER,
        #   CLI_SINCE_LAST, CLI_RECEIVER_PATH
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _capture_cli_parameters "$@"
    _capture_cli_parameters() {
        local arg=""

        while (( $# > 0 )); do
            arg="$1"
            shift

            case "$arg" in
                --local|-l)
                    CLI_DEPLOY_TRANSPORT=1
                    ;;
                --remote|-r)
                    CLI_DEPLOY_TRANSPORT=1
                    CLI_REMOTE_TARGET=1
                    (( $# > 0 )) && shift
                    ;;
                --remote=*)
                    CLI_DEPLOY_TRANSPORT=1
                    CLI_REMOTE_TARGET=1
                    ;;
                --source|-s)
                    CLI_SRC_ROOT=1
                    (( $# > 0 )) && shift
                    ;;
                --source=*)
                    CLI_SRC_ROOT=1
                    ;;
                --target|-t)
                    CLI_DEST_ROOT=1
                    (( $# > 0 )) && shift
                    ;;
                --target=*)
                    CLI_DEST_ROOT=1
                    ;;
                --directory|-d)
                    CLI_SELECT_DIRECTORY=1
                    (( $# > 0 )) && shift
                    ;;
                --directory=*)
                    CLI_SELECT_DIRECTORY=1
                    ;;
                --match|-m)
                    CLI_SELECT_MATCH=1
                    (( $# > 0 )) && shift
                    ;;
                --match=*)
                    CLI_SELECT_MATCH=1
                    ;;
                --changed-after|-c)
                    CLI_CHANGED_AFTER=1
                    (( $# > 0 )) && shift
                    ;;
                --changed-after=*)
                    CLI_CHANGED_AFTER=1
                    ;;
                --since-last)
                    CLI_SINCE_LAST=1
                    ;;
                --receiver)
                    CLI_RECEIVER_PATH=1
                    (( $# > 0 )) && shift
                    ;;
                --receiver=*)
                    CLI_RECEIVER_PATH=1
                    ;;
            esac
        done

        return 0
    }

    # fn: _validate_parameters - Validate the resolved deployment settings
        # . Returns
        #   0 when all required settings are valid.
        #   1 when one or more settings are unusable.
        #
        # . Usage
        #   _validate_parameters || return $?
    _validate_parameters() {
        local directory=""

        [[ -d "$SRC_ROOT" ]] || {
            sayfail "Workspace root not found: $SRC_ROOT"
            return 1
        }

        case "$DEPLOY_TRANSPORT" in
            local) ;;
            remote)
                [[ -n "$REMOTE_TARGET" ]] || {
                    sayfail "A remote SSH target is required."
                    return 1
                }
                ;;
            *)
                sayfail "Deployment transport must be 'local' or 'remote'."
                return 1
                ;;
        esac

        case "$DEST_ROOT" in
            /*) ;;
            *) sayfail "Destination root must be an absolute path: $DEST_ROOT"; return 1 ;;
        esac

        [[ -n "$RECEIVER_PATH" ]] || {
            sayfail "Receiver path cannot be empty."
            return 1
        }

        if [[ -n "${SELECT_DIRECTORY:-}" ]]; then
            directory="$(_normalize_relative_path "$SELECT_DIRECTORY")" || {
                sayfail "Invalid relative directory path: $SELECT_DIRECTORY"
                return 1
            }
            [[ -d "$SRC_ROOT/$directory" ]] || {
                sayfail "Selection directory not found: $SRC_ROOT/$directory"
                return 1
            }
        fi

        [[ -n "${SELECT_MATCH:-}" ]] || SELECT_MATCH="*"
        [[ -n "${CHANGED_AFTER:-}" ]] || CHANGED_AFTER="1900-01-01"

        if [[ "${FLAG_SINCE_LAST:-0}" -eq 1 ]]; then
            [[ -n "${LAST_DEPLOY_SUCCESS:-}" ]] || {
                sayfail "No successful deployment timestamp is available for --since-last."
                return 1
            }
        elif ! date -d "$CHANGED_AFTER" >/dev/null 2>&1; then
            sayfail "Changed-after value is not a valid date or timestamp: $CHANGED_AFTER"
            return 1
        fi

        return 0
    }

    # fn: _getparameters - Collect deployment parameters from CLI values, state, and ask
        # . Purpose
        #   Resolve command-line overrides first, use saved state as prompt defaults,
        #   and combine directory, filename/mask, and changed-after filters.
        #
        # . Outputs (globals)
        #   DEPLOY_TRANSPORT, REMOTE_TARGET, SRC_ROOT, DEST_ROOT, SELECT_DIRECTORY,
        #   SELECT_MATCH, CHANGED_AFTER, RECEIVER_PATH
        #
        # . Returns
        #   0 after confirmation or when auto mode has valid resolved settings.
        #   1 when validation fails or the user cancels.
        #
        # . Usage
        #   _getparameters || return $?
    _getparameters() {
        local reply=""
        local since_last="N"

        if [[ "${FLAG_LOCAL:-0}" -eq 1 ]]; then
            DEPLOY_TRANSPORT="local"
        elif [[ -n "${REMOTE_TARGET:-}" ]]; then
            DEPLOY_TRANSPORT="remote"
        fi

        : "${DEPLOY_TRANSPORT:=local}"
        : "${SRC_ROOT:=$HOME/dev/target-root}"
        : "${DEST_ROOT:=/}"
        : "${SELECT_DIRECTORY:=}"
        : "${SELECT_MATCH:=*}"
        : "${CHANGED_AFTER:=1900-01-01}"
        : "${RECEIVER_PATH:=/usr/local/libexec/solidgroundux/receive-files.sh}"

        if [[ "${FLAG_SINCE_LAST:-0}" -eq 1 ]]; then
            since_last="Y"
        fi

        if [[ "${FLAG_AUTO:-0}" -eq 1 ]]; then
            _validate_parameters || return $?
            return 0
        fi

        while true; do
            if (( ! CLI_DEPLOY_TRANSPORT )); then
                sgnd_print "Choose how the files will be delivered."
                sgnd_print "  local  - Run receive-files.sh on this machine."
                sgnd_print "  remote - Send the stream over SSH to another machine."

                ask --label "Deployment transport" \
                    --var DEPLOY_TRANSPORT \
                    --default "$DEPLOY_TRANSPORT" \
                    --colorize both
            fi

            if [[ "$DEPLOY_TRANSPORT" == "remote" ]]; then
                if (( ! CLI_REMOTE_TARGET )); then
                    sgnd_print "Enter the SSH destination in user@host format."
                    sgnd_print "Examples: sysadmin@192.168.0.253 or sysadmin@td-sambaad"

                    ask --label "Remote target (user@host)" \
                        --var REMOTE_TARGET \
                        --default "$REMOTE_TARGET" \
                        --colorize both
                fi
            else
                REMOTE_TARGET=""
            fi

            if (( ! CLI_SRC_ROOT )); then
                sgnd_print "Enter the local workspace root containing the deployable tree."
                sgnd_print "All selected paths are resolved beneath this directory."

                ask --label "Workspace root" \
                    --var SRC_ROOT \
                    --default "$SRC_ROOT" \
                    --colorize both
            fi

            if (( ! CLI_DEST_ROOT )); then
                sgnd_print "Enter the filesystem root beneath which received paths are installed."
                sgnd_print "Use / to deploy into the destination system root."

                ask --label "Destination root" \
                    --var DEST_ROOT \
                    --default "$DEST_ROOT" \
                    --colorize both
            fi

            if (( ! CLI_SELECT_DIRECTORY )); then
                sgnd_print "Optionally restrict the search to a directory below the workspace root."
                sgnd_print "Leave it empty to search the complete workspace."

                ask --label "Directory" \
                    --var SELECT_DIRECTORY \
                    --default "$SELECT_DIRECTORY" \
                    --colorize both
            fi

            if (( ! CLI_SELECT_MATCH )); then
                sgnd_print "Enter one or more filenames or shell-style file masks."
                sgnd_print "Separate multiple entries with commas; use * to include every filename."

                ask --label "Files or masks" \
                    --var SELECT_MATCH \
                    --default "$SELECT_MATCH" \
                    --colorize both
            fi

            if (( CLI_CHANGED_AFTER )); then
                FLAG_SINCE_LAST=0
            elif (( CLI_SINCE_LAST )); then
                sgnd_print_labeledvalue \
                    --label "Last succeededdeployment" \
                    --value "${LAST_DEPLOY_SUCCESS:-Not available}"
            else
                if [[ -n "${LAST_DEPLOY_SUCCESS:-}" ]]; then
                    sgnd_print "Deploy only files changed since the last successful deployment."
                    ask --label "Since last deployment (Y/N)" \
                        --var since_last \
                        --default "$since_last" \
                        --colorize both
                else
                    since_last="N"
                    sgnd_print "No successful deployment timestamp is available yet."
                fi

                case "${since_last^^}" in
                    Y|YES)
                        FLAG_SINCE_LAST=1
                        sgnd_print_labeledvalue \
                            --label "Last succeeded deployment" \
                            --value "$LAST_DEPLOY_SUCCESS"
                        ;;
                    *)
                        FLAG_SINCE_LAST=0
                        CHANGED_AFTER="1900-01-01"
                        sgnd_print "Only files modified after this date or timestamp are included."
                        sgnd_print "Datetime shortcuts are accepted, for example N, D, -2h, -30m, or -1d."
                        sgnd_print "Use 1900-01-01 to apply no practical date restriction."

                        ask_datetime --label "Changed after" \
                            --var CHANGED_AFTER \
                            --default "$CHANGED_AFTER" \
                            --colorize both
                        ;;
                esac
            fi

            if (( ! CLI_RECEIVER_PATH )); then
                sgnd_print "Enter the receive-files.sh path as it exists on the destination system."

                ask --label "Receiver path" \
                    --var RECEIVER_PATH \
                    --default "$RECEIVER_PATH" \
                    --colorize both
            fi

            _validate_parameters || {
                saywarning "Please correct the deployment settings."
                continue
            }

            ask_dlg_autocontinue \
                --seconds 15 \
                --message "Select files and start deployment?" \
                --redo \
                --cancel

            reply=$?
            case "$reply" in
                0|1) break ;;
                2) saycancel "Deployment cancelled."; return 1 ;;
                3) continue ;;
                *) sayfail "Unexpected confirmation response: $reply"; return 1 ;;
            esac
        done

        return 0
    }


# --- Reporting ----------------------------------------------------------------------
    # fn: _print_deployment_summary - Display the completed deployment details
        # . Purpose
        #   Show which workspace files were selected and where they were sent.
        #
        # . Behavior
        #   - Displays source, destination, transport, receiver, timing, and result mode.
        #   - Displays every selected relative path on its own aligned value line.
        #   - Uses sgnd_print_labeledmultivalue so no selected path is truncated.
        #   - Clearly marks dry-run deployments.
        #
        # Inputs (globals)
        #   DEPLOY_TRANSPORT, REMOTE_TARGET, SRC_ROOT, DEST_ROOT, RECEIVER_PATH,
        #   SELECTED_PATHS, DEPLOY_STARTED_AT, DEPLOY_FINISHED_AT, FLAG_DRYRUN
        #
        # . Returns
        #   0 after displaying the summary.
        #
        # . Usage
        #   _print_deployment_summary
    _print_deployment_summary() {
        local destination=""
        local result="Completed"

        case "$DEPLOY_TRANSPORT" in
            local)
                destination="$DEST_ROOT"
                ;;
            remote)
                destination="$REMOTE_TARGET:$DEST_ROOT"
                ;;
            *)
                destination="$DEST_ROOT"
                ;;
        esac

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            result="Dry run completed"
        fi

        sgnd_print
        sgnd_print_sectionheader "Deployment summary"
        sgnd_print_labeledvalue --label "Result" --value "$result" --labelwidth 20
        sgnd_print_labeledvalue --label "Transport" --value "$DEPLOY_TRANSPORT" --labelwidth 20
        sgnd_print_labeledvalue --label "Source root" --value "$SRC_ROOT" --labelwidth 20
        sgnd_print_labeledvalue --label "Destination" --value "$destination" --labelwidth 20
        sgnd_print_labeledvalue --label "Receiver" --value "$RECEIVER_PATH" --labelwidth 20
        sgnd_print_labeledvalue --label "Started" --value "${DEPLOY_STARTED_AT:-Unknown}" --labelwidth 20
        sgnd_print_labeledvalue --label "Finished" --value "${DEPLOY_FINISHED_AT:-Unknown}" --labelwidth 20
        sgnd_print_labeledmultivalue \
            --label "Changed files" \
            --labelwidth 20 \
            --items "${SELECTED_PATHS[@]}"

        return 0
    }

# --- Transport ----------------------------------------------------------------------
    # fn: _quote_remote_arg - Shell-quote one argument for the remote receive command
        # . Arguments
        #   $1  Argument value.
        #
        # . Output
        #   Writes one shell-safe argument to stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   quoted="$(_quote_remote_arg "$DEST_ROOT")"
    _quote_remote_arg() {
        printf '%q' "$1"
    }

    # fn: _stream_local - Stream selected workspace files to the local receiver
        # . Returns
        #   Status returned by tar or receive-files.sh through pipefail.
        #
        # . Usage
        #   _stream_local
    _stream_local() {
        local -a receiver_args=("$RECEIVER_PATH" --target "$DEST_ROOT")

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            receiver_args+=(--dry-run)
        fi

        sudo -v || {
            sayfail "Unable to obtain local sudo authorization."
            return 1
        }

        tar -C "$SRC_ROOT" -cf - -- "${SELECTED_PATHS[@]}" |
            sudo -n "${receiver_args[@]}"
    }

    # fn: _stream_remote - Stream selected workspace files to the remote receiver over SSH
        # . Returns
        #   Status returned by tar, SSH, or receive-files.sh through pipefail.
        #
        # . Usage
        #   _stream_remote
    _stream_remote() {
        local remote_command=""

        remote_command="sudo -n $(_quote_remote_arg "$RECEIVER_PATH") --target $(_quote_remote_arg "$DEST_ROOT")"
        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            remote_command+=" --dry-run"
        fi

        tar -C "$SRC_ROOT" -cf - -- "${SELECTED_PATHS[@]}" |
            ssh "$REMOTE_TARGET" "$remote_command"
    }

    # fn: _deploy - Select files and stream them to the configured receiver
        # . Returns
        #   0 after a successful receive operation.
        #   Non-zero when selection, transport, or receiver processing fails.
        #
        # . Usage
        #   _deploy || return $?
    _deploy() {
        DEPLOY_STARTED_AT="$(date --iso-8601=seconds)"
        DEPLOY_FINISHED_AT=""

        SRC_ROOT="${SRC_ROOT%/}"
        DEST_ROOT="${DEST_ROOT%/}"
        [[ -n "$DEST_ROOT" ]] || DEST_ROOT="/"

        _select_files || return $?

        saystart "Deploying ${#SELECTED_PATHS[@]} file(s) from $SRC_ROOT"

        case "$DEPLOY_TRANSPORT" in
            local)
                sayinfo "Receiver: local $RECEIVER_PATH"
                _stream_local || {
                    sayfail "Local receiver failed."
                    return 1
                }
                ;;
            remote)
                sayinfo "Receiver: $REMOTE_TARGET:$RECEIVER_PATH"
                _stream_remote || {
                    sayfail "Remote receiver failed."
                    return 1
                }
                ;;
        esac

        if [[ "${FLAG_DRYRUN:-0}" -eq 0 ]]; then
            LAST_DEPLOY_SUCCESS="$DEPLOY_STARTED_AT"
        fi

        DEPLOY_FINISHED_AT="$(date --iso-8601=seconds)"
        _print_deployment_summary
        sayend "Deployment completed successfully."
        return 0
    }

# --- Main ----------------------------------------------------------------------------
    # fn: main - Run the workspace deployment workflow
        # . Arguments
        #   $@  Framework and script-specific arguments.
        #
        # . Returns
        #   Exit status from parameter collection, selection, transport, or receiver processing.
        #
        # . Usage
        #   main "$@"
    main() {
        _capture_cli_parameters "$@"
        _framework_locator || exit $?
        sgnd_exe_start --autostate -- "$@"

        _getparameters || return $?

        _deploy
    }

    main "$@"
