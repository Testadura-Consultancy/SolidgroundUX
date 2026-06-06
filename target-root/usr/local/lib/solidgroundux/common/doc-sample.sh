#!/usr/bin/env bash
# ==================================================================================
# SolidGroundUX - Documentation Sample
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : doc-sample.sh
#   Type        : documentation
#   Group       : SDK Documentation
#   Purpose     : Demonstrate all supported SolidGroundUX documentation comment
#                 conventions, content types, item markers, and layout hints.
#
# Description:
#   This file is a documentation fixture and style guide.
#
#   It demonstrates:
#     - Module header metadata
#     - Attribution metadata
#     - Header-only prose sections
#     - Level 1, 2, and 3 documentation sections
#     - Function, variable, and general documentation items
#     - Template markers
#     - Style/layout hints
#
# Notes:
#   This section is intentionally inside the module header.
#   Header sections other than Metadata and Attribution are rendered as module body
#   content. Metadata and Attribution are captured as structured data and suppressed
#   from normal page content.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
    # fn: sample_public_function - Sample public function
        # . Purpose
        #   Sample public function.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sample_public_function
    sample_public_function() {
        return 0
    }

    # fn: _sample_internal_function - Internal function documentation
        # . Purpose
        #   Demonstrate an internal function.
        #
        # . Behavior
        #   - A leading underscore marks the function as internal.
        #   - The renderer may use this visibility metadata later.
        #
        # . Returns
        #   0 on success.
    _sample_internal_function() {
        return 0
    }
    # fn: sample_template_function - Sample template function
        # . Purpose
        #   Sample template function.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sample_template_function
    sample_template_function() {
        return 0
    }

# - Variable items -----------------------------------------------------------------
    # var: SAMPLE_PUBLIC_VARIABLE - Public variable documentation
        # . Purpose
        #   Demonstrate a normal documented variable.
        #
        # . Behavior
        #   - Creates a variable item.
        #   - Uses the variable header/body content type.
        #   - Is included in the variable glossary.
        #
        # Default:
        #   empty
    SAMPLE_PUBLIC_VARIABLE=""

    # var: _SAMPLE_INTERNAL_VARIABLE - Internal variable documentation
        # . Purpose
        #   Demonstrate an internal variable.
        #
        # . Behavior
        #   - A leading underscore marks the variable as internal.
        #   - The renderer may use this visibility metadata later.
    _SAMPLE_INTERNAL_VARIABLE=""

    # var$ SAMPLE_TEMPLATE_VARIABLE - Template variable documentation
        # . Purpose
        #   Demonstrate the var$ template marker.
        #
        # . Behavior
        #   - The dollar marker means this is a template/example variable.
        #   - Template variables are only shown when the module belongs to the Templates group.
        #
        # Notes:
        #   If a real module implements this variable, document it with var: instead of var$.
    SAMPLE_TEMPLATE_VARIABLE=""

# - Recommended prose blocks --------------------------------------------------------
    # doc: purpose_block - Purpose block convention
        # . Purpose
        #   Demonstrate the preferred prose structure for documented items.
        #
        # Recommended labels:
        #   Purpose
        #   Behavior
        #   Inputs
        #   Outputs
        #   Arguments
        #   Returns
        #   Examples
        #   Notes
        #
        # Notes:
        #   These labels are plain body content today, but they give the rendered
        #   documentation a predictable structure.

# - Empty section example -----------------------------------------------------------
# This section intentionally contains body text, so it is not considered empty.
# A section with no body text, no visible items, and no visible child sections should
# be omitted from the index by the renderer.
