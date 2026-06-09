# ==================================================================================
# SolidGroundUX - How to?
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2616001
#   Checksum    : 92c8dcb19969ec66d6b07f7078427bd7f1b14df3ab105b54d051cafce3ad2de0
#   Source      : solidgroundux_epilogue.sh
#   Type        : documentation
#   Group       : SolidGroundUX
#   Purpose     : How to section
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - How do I...? --------------------------------------------------------------------
#
# -- Add a command-line argument ----------------------------------------------------
#
# > Add an entry to SGND_ARGS_SPEC. The bootstrapper calls sgnd_parse_args and stores
# > the parsed value in the variable named by the argument specification.
#
# > Default framework arguments are handled by the framework itself. Script-specific
# > arguments are declared by the script and are included in generated help output.
#
# > Example:
# >     SGND_ARGS_SPEC=(
# >         "auto|a|flag|FLAG_AUTO|Repeat with last settings|0|"
# >         "target|t|value|DEST_ROOT|Set target directory|"
# >         "mode|m|enum|ENUM_MODE|Select mode|copy,move,link"
# >     )
#
# -- Use configuration files --------------------------------------------------------
#
# > Add configuration-driven variables to SGND_SCRIPT_GLOBALS. When this array is
# > non-empty, sgnd_bootstrap applies script configuration through
# > sgnd_cfg_domain_apply. Readable system/user cfg files are loaded automatically at
# > startup. Missing domain files can be created by the cfg layer.
#
# > Example:
# >     SGND_SCRIPT_GLOBALS=(
# >         "system|SGND_SYS_STRING|System CFG string|"
# >         "user|SGND_USR_STRING|User CFG string|"
# >         "both|SGND_COMMON_STRING|Common CFG string|"
# >     )
#
# -- Use persistent state variables -------------------------------------------------
#
# > Add state variables to SGND_STATE_VARIABLES. State support is enabled by invoking
# > the bootstrapper with state support. With autostate, registered state variables
# > are loaded at startup and saved again on clean exit.
#
# > Example:
# >     SGND_STATE_VARIABLES=(
# >         "INP_NAME|Name|Petrus Puk|"
# >         "INP_AGE|Leeftijd|102|sgnd_is_number"
# >     )
#
# -- Source an additional framework library -----------------------------------------
#
# > Add the library filename to SGND_USING. After core libraries are loaded,
# > sgnd_bootstrap sources the declared libraries from the common library directory.
#
# > Example:
# >     SGND_USING=(
# >         sgnd-comment-header-parser.sh
# >     )
#
# -- Use themed colors, styles, and glyphs ------------------------------------------
#
# > Use the framework UI variables instead of hard-coded terminal escape sequences.
# > Color and style variables keep output consistent across scripts, while glyph
# > variables provide reusable symbols for status, navigation, prompts, and visual
# > markers.
#
# > Typical use:
# >     printf "%s%s%s\n" "$SGND_CLR_OK" "Operation completed" "$SGND_CLR_RESET"
# >     printf "%s %s\n" "$SGND_GLYPH_OK" "Validated"
#
# > Prefer the say and ask helpers for normal user interaction. Use color, style, and
# > glyph variables directly only when a script needs custom formatted output.
#
# -- Ask the user for input ----------------------------------------------------------
#
# > Use ask for a single typed value, ask_choose or ask_choose_immediate for choices,
# > ask_decision for symbolic decisions, and ask_prompt_form for multiple named fields.
#
# > Example:
# >     ask_prompt_form --autoalign "${SGND_STATE_VARIABLES[@]}"
#
# -- Show an auto-continue prompt ----------------------------------------------------
#
# > Use ask_dlg_autocontinue for an interruptible countdown. It supports redo, cancel,
# > pause/resume, any-key continuation, and returns distinct status codes.
#
# > Example:
# >     ask_dlg_autocontinue --seconds 10 --message "Continuing deployment" --redo --cancel --pause
#
# -- Write screen output -------------------------------------------------------------
#
# > Use the say helpers from ui-say.sh for consistent terminal output.
#
# > Example:
# >     sayinfo "Preparing release"
# >     sayok "Release package created"
# >     saywarning "Existing manifest found"
# >     sayfail "Checksum validation failed"
# >     saydebug "Resolved target root: $DEST_ROOT"
#
# -- Work with pipe-separated datatables --------------------------------------------
#
# > Use sgnd-datatable.sh when data is represented as schema and pipe-separated rows.
# > It provides helpers for splitting schemas/rows, validating values, inserting,
# > deleting, getting, setting, finding, sorting, printing, and exporting PSV data.
#
# > Example functions:
# >     sgnd_dt_make_row
# >     sgnd_dt_insert
# >     sgnd_dt_get
# >     sgnd_dt_set
# >     sgnd_dt_find_first
# >     sgnd_dt_print_table
# >     sgnd_dt_export_psv
#
# -- Create a VS Code workspace ------------------------------------------------------
#
# > Use sgnd-create-workspace. The underlying create-workspace tool creates the
# > repository directory structure, workspace file, .gitignore, module app cfg, and
# > can undo created artifacts from its creation manifest.
#
# -- Deploy a workspace --------------------------------------------------------------
#
# > Use sgnd-deploy-workspace. The underlying deploy-workspace tool can deploy files
# > from a workspace into a target root, record deployment manifests, undeploy from a
# > manifest, and repeat with last settings through auto mode.
#
# -- Generate documentation ----------------------------------------------------------
#
# > Use the documentation generator. The processor extracts module headers, fn:, var:,
# > doc:, and template blocks; the renderer builds the HTML documentation set.
#
# -- Add a console command -----------------------------------------------------------
#
# > Add a console module under the console modules location. The console menu library
# > handles menu rendering, paging, toggle labels, dispatch, and registered actions.
#
# -- Add generated help examples -----------------------------------------------------
#
# > Add lines to SGND_SCRIPT_EXAMPLES. sgnd_show_help includes these examples when
# > rendering script help.
#
# > Example:
# >     SGND_SCRIPT_EXAMPLES=(
# >         "Deploy using defaults:"
# >         "  $SGND_SCRIPT_NAME"
# >         ""
# >         "Undeploy everything:"
# >         "  $SGND_SCRIPT_NAME --undeploy"
# >     )
