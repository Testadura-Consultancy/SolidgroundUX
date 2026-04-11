# ==================================================================================
# SolidgroundUX - Developer Tools Console Module
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.1
#   Build       : 2609100
#   Checksum    : e72edae0572cbf7d0d5ac7fd17357b54f972e5bdb7688e85be6154765a370dd6
#   Source      : console-devtools.sh
#   Type        : module
#   Group       : Solidground Console
#   Purpose     : sgnd-console module exposing developer tooling actions
#
# Description:
#   Provides a console module that registers developer-oriented actions in
#   sgnd-console, allowing common tooling scripts to be launched from the
#   interactive console host.
#
#   The module currently exposes actions for:
#     - creating a new workspace
#     - deploying a workspace
#     - preparing a release archive
#
# Design principles:
#   - Console modules are source-only plugin libraries
#   - Functions are defined first, then registered explicitly
#   - Registration is the only intended load-time side effect
#   - Module actions delegate execution to the shared sgnd-console runtime
#
# Role in framework:
#   - Extends sgnd-console with developer workflow actions
#   - Acts as a lightweight plugin layer on top of the console host
#   - Uses _sgnd_run_script to execute related tooling scripts consistently
#
# Assumptions:
#   - Loaded by sgnd-console after framework bootstrap is complete
#   - sgnd_console_register_group and sgnd_console_register_item are available
#   - _sgnd_run_script is available in the host environment
#
# Non-goals:
#   - Standalone execution
#   - Framework bootstrap or path resolution
#   - Direct implementation of workspace/deploy/release logic
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : 
#   Copyright     : © 2025 Mark Fieten — Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================
set -uo pipefail
# --- Library guard ------------------------------------------------------------------
    # _sgnd_lib_guard
        # Purpose:
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # Behavior:
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # Returns:
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
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

# --- Internal helpers -------------------------------------------------------------
    # _exe_createworkspace
        # Purpose:
        #   Launch the create-workspace developer tool through the sgnd-console runtime.
        #
        # Behavior:
        #   - Delegates execution to _sgnd_run_script.
        #   - Invokes create-workspace.sh
        #
        # Returns:
        #   Exit code of the executed script.
        #
        # Usage:
        #   _exe_createworkspace
        #
        # Examples:
        #   _exe_createworkspace    
    _exe_createworkspace(){
            _sgnd_run_script "create-workspace.sh"
    }
    
    # _exe_deployworkspace
        # Purpose:
        #   Launch the deploy-workspace developer tool through the sgnd-console runtime.
        #
        # Behavior:
        #   - Delegates execution to _sgnd_run_script.
        #   - Invokes deploy-workspace.sh 
        # Returns:
        #   Exit code of the executed script.
        #
        # Usage:
        #   _exe_deployworkspace
        #
        # Examples:
        #   _exe_deployworkspace
    _exe_deployworkspace(){
            _sgnd_run_script "deploy-workspace.sh" 
    }

    # _exe_preparerelease
        # Purpose:
        #   Launch the prepare-release developer tool through the sgnd-console runtime.
        #
        # Behavior:
        #   - Delegates execution to _sgnd_run_script.
        #   - Invokes prepare-release.sh 
        #
        # Returns:
        #   Exit code of the executed script.
        #
        # Usage:
        #   _exe_preparerelease
        #
        # Examples:
        #   _exe_preparerelease
    _exe_preparerelease(){
            _sgnd_run_script "prepare-release.sh" 
    }

    # _exe_metadataeditor
        # Purpose:
        #   Launch the prepare-release developer tool through the sgnd-console runtime.
        #
        # Behavior:
        #   - Delegates execution to _sgnd_run_script.
        #   - Invokes prepare-release.sh 
        #
        # Returns:
        #   Exit code of the executed script.
        #
        # Usage:
        #   _exe_metadataeditor
        #
        # Examples:
        #   _exe_metadataeditor
    _exe_metadata-editor(){
        _sgnd_run_script "metadata-editor.sh"
    }

# --- Public API -------------------------------------------------------------------
#    sample_show_message() {
#        sayinfo "Sample module action executed"
#    }

# sys_status() {
#     sayinfo "System status"
# }

# --- Console registration --------------------------------------------------------
    # Allowed side effect:
    #   - On source, the module registers its groups and menu items with sgnd-console.

    sgnd_console_register_group "devtools" "Developer tools" "Tool scripts to create, deploy and release VSC-workspaces" 0 1 900

    sgnd_console_register_item "createws" "devtools" "Create workspace" "_exe_createworkspace" "Create a template workspace with target-root structure" 0 15 
    sgnd_console_register_item "deployws" "devtools" "Deploy workspace" "_exe_deployworkspace" "Deploy target-root structure from workspace to root" 0 15
    sgnd_console_register_item "preprel" "devtools" "Prepare release" "_exe_preparerelease" "Create a tar-file from workspace with checksums and manifests" 0 15
    sgnd_console_register_item "metaedt" "devtools" "Metadata editor" "_exe_metadata-editor" "Edit metadata fields in script header comments" 0 15


