# ==================================================================================
# SolidGroundUX - Development Tools
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621612
#   Checksum    : 40040c9b5cda73ae4a0bf0d45e0d679dadea8aca3c0bd7402a6e8b4bfa801c31
#   Source      : 95-development-tools.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Provide SolidGroundUX development and release tools
#
# Description:
#   Contains workspace, deployment, archive, restoration, release, metadata, and documentation actions.
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : -
#   Copyright     : © 2025 - 2026 Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# - Library guard ----------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the module is sourced and initialized only once.
        #
        # . Returns
        #   0 when loading may continue.
        #   1 when the module was already loaded.
        #   Exits with status 2 when executed directly.
        #
        # . Usage
        #   _sgnd_lib_guard "example-0"
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

# - Module metadata -------------------------------------------------------------
    SGND_DEVELOPMENT_TOOLS_MODULE_ID="development-tools"
    SGND_DEVELOPMENT_TOOLS_MODULE_NAME="Development Tools"
    SGND_DEVELOPMENT_TOOLS_MODULE_VERSION="1.0.0"
    SGND_DEVELOPMENT_TOOLS_MODULE_DESC="Workspace, deployment, archive, release, metadata, and documentation tools"

    SGND_MODULE_ID="${SGND_DEVELOPMENT_TOOLS_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_DEVELOPMENT_TOOLS_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_DEVELOPMENT_TOOLS_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_DEVELOPMENT_TOOLS_MODULE_DESC}"

# - Developer tool actions -------------------------------------------------------
    # fn: _exe_createworkspace
        # . Returns
        #   Exit status of create-workspace.sh.
        # . Usage
        #   _exe_createworkspace
    _exe_createworkspace() {
        _sgnd_run_public_command "sgnd-create-workspace"
    }

    # fn: _exe_deployworkspace
        # . Returns
        #   Exit status of deploy-workspace.sh.
        # . Usage
        #   _exe_deployworkspace
    _exe_deployworkspace() {
        _sgnd_run_public_command "sgnd-deploy-workspace"
    }

    # fn: _exe_preparerelease
        # . Returns
        #   Exit status of prepare-release.sh.
        # . Usage
        #   _exe_preparerelease
    _exe_preparerelease() {
        _sgnd_run_public_command "sgnd-prepare-release"
    }

    # fn: _exe_metadata_editor
        # . Returns
        #   Exit status of metadata-editor.sh.
        # . Usage
        #   _exe_metadata_editor
    _exe_metadata_editor() {
        _sgnd_run_public_command "sgnd-metadata-editor"
    }

    # _exe_generate_docs
        # . Returns
        #   Exit status of sgnd-generate-docs.
        #
        # . Usage
        #   _exe_generate_docs
    _exe_generate_docs() {
        _sgnd_run_public_command "sgnd-generate-docs"
    }

    # fn: _exe_tar_it - Create a SolidGroundUX archive
        # . Returns
        #   Exit status of sgnd-tar-it.
        #
        # . Usage
        #   _exe_tar_it
    _exe_tar_it() {
        _sgnd_run_public_command "sgnd-tar-it"
    }

    # fn: _exe_un_tar_it - Restore files from a SolidGroundUX archive
        # . Returns
        #   Exit status of sgnd-un-tar-it.
        #
        # . Usage
        #   _exe_un_tar_it
    _exe_un_tar_it() {
        _sgnd_run_public_command "sgnd-un-tar-it"
    }

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "$SGND_DEVELOPMENT_TOOLS_MODULE_NAME" "$SGND_DEVELOPMENT_TOOLS_MODULE_DESC" 0 1 950
    sgnd_console_register_item "createws" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Create workspace" "_exe_createworkspace" "Create a template workspace with target-root structure" 0 15 1
    sgnd_console_register_item "deployws" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Deploy workspace" "_exe_deployworkspace" "Select and deploy workspace files locally or remotely" 0 15 1
    sgnd_console_register_item "archive" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Create archive" "_exe_tar_it" "Create a timestamped SolidGroundUX archive" 0 15 1
    sgnd_console_register_item "restore" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Restore archive" "_exe_un_tar_it" "Restore selected files from a SolidGroundUX archive" 0 15 1
    sgnd_console_register_item "preprel" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Prepare release" "_exe_preparerelease" "Create a release archive with checksums and manifests" 0 15 1
    sgnd_console_register_item "metaedt" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Metadata editor" "_exe_metadata_editor" "Edit metadata fields in script header comments" 0 15 1
    sgnd_console_register_item "gendocs" "$SGND_DEVELOPMENT_TOOLS_MODULE_ID" "Generate documentation" "_exe_generate_docs" "Generate SolidGroundUX source documentation" 0 15 1
