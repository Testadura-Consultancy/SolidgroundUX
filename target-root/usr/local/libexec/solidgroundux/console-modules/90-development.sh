# ==================================================================================
# SolidGroundUX - Development
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.0
#   Build       : 2623201
#   Checksum    : 380a2bde657a89e1ed6b25bd0df878205af945382bb832a5696fdd39b395774c
#   Source      : 90-development.sh
#   Type        : module
#   Group       : SolidGround Console
#   Subgroup    : Console Modules
#   Purpose     : Provide SolidGroundUX workspace, deployment, release, and documentation tools
# ==================================================================================
set -uo pipefail

# - Library guard ------------------------------------------------------------------
    # fn: _sgnd_lib_guard
        # . Purpose
        #   Ensure the module is sourced and initialized only once.
        #
        # . Returns
        #   0 when loading may continue; exits with 2 when executed directly.
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

# - Module metadata ----------------------------------------------------------------
    SGND_DEVELOPMENT_MODULE_ID="development"
    SGND_DEVELOPMENT_MODULE_NAME="Development"
    SGND_DEVELOPMENT_MODULE_VERSION="1.0.0"
    SGND_DEVELOPMENT_MODULE_DESC="Workspace, deployment, release, wrapper, and documentation tools"

    SGND_MODULE_NAME="$SGND_DEVELOPMENT_MODULE_NAME"
    SGND_MODULE_VERSION="$SGND_DEVELOPMENT_MODULE_VERSION"
    SGND_MODULE_DESC="$SGND_DEVELOPMENT_MODULE_DESC"

# - Development actions -----------------------------------------------------------
    # fn: _dev_create_workspace
        # . Purpose
        #   Launch the canonical SolidGroundUX workspace-creation tool.
        #
        # . Returns
        #   Returns the underlying public-command status.
        #
        # . Usage
        #   _dev_create_workspace
    _dev_create_workspace() {
        _sgnd_run_public_command "sgnd-create-workspace"
    }

    # fn: _dev_deploy_workspace
        # . Purpose
        #   Launch the canonical SolidGroundUX workspace-deployment tool.
        #
        # . Returns
        #   Returns the underlying public-command status.
        #
        # . Usage
        #   _dev_deploy_workspace
    _dev_deploy_workspace() {
        _sgnd_run_public_command "sgnd-deploy-workspace"
    }

    # fn: _dev_prepare_release
        # . Purpose
        #   Launch the canonical SolidGroundUX release-preparation tool.
        #
        # . Returns
        #   Returns the underlying public-command status.
        #
        # . Usage
        #   _dev_prepare_release
    _dev_prepare_release() {
        _sgnd_run_public_command "sgnd-prepare-release"
    }

    # fn: _dev_create_wrappers
        # . Purpose
        #   Launch the canonical SolidGroundUX wrapper-creation tool.
        #
        # . Returns
        #   Returns the underlying public-command status.
        #
        # . Usage
        #   _dev_create_wrappers
    _dev_create_wrappers() {
        _sgnd_run_public_command "sgnd-create-wrappers"
    }

    # fn: _dev_generate_docs
        # . Purpose
        #   Launch the canonical SolidGroundUX documentation generator.
        #
        # . Returns
        #   Returns the underlying public-command status.
        #
        # . Usage
        #   _dev_generate_docs
    _dev_generate_docs() {
        _sgnd_run_public_command "sgnd-generate-docs"
    }

    # fn: _sync_repository
        # . Purpose
        #   Launch the canonical SolidGroundUX repository synchronization tool.
        #
        # . Returns
        #   Returns the underlying public-command status.
        #
        # . Usage
        #   _sync_repository
    _sync_repository() {
        _sgnd_run_public_command "sgnd-sync-repository"
    }


# - Console registration ----------------------------------------------------------
    sgnd_menu_register_group \
        "$SGND_DEVELOPMENT_MODULE_ID" \
        "$SGND_DEVELOPMENT_MODULE_NAME" \
        "$SGND_DEVELOPMENT_MODULE_DESC" \
        0 1 900

    sgnd_menu_register_item "dev-createws" "$SGND_DEVELOPMENT_MODULE_ID" "Create workspace" "_dev_create_workspace" "Create a template workspace with target-root structure" 0 15 1 0
    sgnd_menu_register_item "dev-deployws" "$SGND_DEVELOPMENT_MODULE_ID" "Deploy workspace" "_dev_deploy_workspace" "Select and deploy workspace files locally or remotely" 0 15 1 0
    sgnd_menu_register_item "dev-preprel" "$SGND_DEVELOPMENT_MODULE_ID" "Prepare release" "_dev_prepare_release" "Create a release archive with checksums and manifests" 0 15 1 0
    sgnd_menu_register_item "dev-wrappers" "$SGND_DEVELOPMENT_MODULE_ID" "Create wrappers" "_dev_create_wrappers" "Create root-aware bin or sbin wrappers for selected scripts" 0 20 1 0
    sgnd_menu_register_item "dev-gendocs" "$SGND_DEVELOPMENT_MODULE_ID" "Generate documentation" "_dev_generate_docs" "Generate SolidGroundUX source documentation" 0 25 1 0
    sgnd_menu_register_item "dev-syncrepo" "$SGND_DEVELOPMENT_MODULE_ID" "Sync repository" "_sync_repository" "Synchronize the SolidGroundUX repository with the remote source" 0 30 1 0

    sayinfo "Development module registered with the console."
