
# ==================================================================================
# SolidGroundUX - Documentation Generator Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615900
#   Checksum    : 70b0cb552daa93a71a50fe036dd34cbe107c23ea01079001a1b01bc28d3fe39d
#   Source      : sdk documentation_preface.sh
#   Type        : documentation
#   Group       : SDK Documentation
#   Purpose     : Group preface
#
#   Checksum : 70b0cb552daa93a71a50fe036dd34cbe107c23ea01079001a1b01bc28d3fe39d
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - SDK Documentation ---------------------------------------------------------------
#
# > The SDK Documentation group contains the tools used to extract, process, render,
# > and generate SolidGroundUX documentation.
#
# > The documentation system is built around the idea that documentation should live
# > close to the code it describes. Instead of maintaining a separate manual by hand,
# > source files contain structured comment blocks that can be converted into a
# > navigable HTML documentation set.
#
# > The file doc-sample.sh demonstrates the supported documentation conventions and
# > should be treated as the practical reference for writing documentation comments.
#
# -- Documentation Workflow ---------------------------------------------------------
#
# > The documentation pipeline consists of several stages.
#
# >     Source files
# >         ↓
# >     Documentation processor
# >         ↓
# >     Normalized table output
# >         ↓
# >     HTML renderer
# >         ↓
# >     Generated documentation set
#
# > The processor reads source files and extracts module metadata, sections, items,
# > documentation lines, attribution data, and integrity information.
#
# > The renderer receives the normalized tables produced by the processor and turns
# > them into HTML pages, navigation, appendices, glossary entries, and supporting
# > assets.
#
# > The generator coordinates the overall process and acts as the main entry point
# > for producing the documentation set.
#
# -- Module Headers -----------------------------------------------------------------
#
# > Documentation begins with the module header.
#
# > The Metadata section describes the module itself. Common fields include Version,
# > Build, Checksum, Source, Type, Group, and Purpose.
#
# > Version and Build identify the documented module version. Checksum can be used
# > for integrity tracking. Source identifies the original source file. Type
# > classifies the module, Group determines where it appears in the documentation
# > hierarchy, and Purpose provides a short description of why the module exists.
#
# > The Attribution section describes ownership and licensing information. Common
# > fields include Developers, Company, Client, Copyright, and License.
#
# > These fields are used to generate attribution and integrity appendices, and help
# > keep generated documentation traceable back to the source files.
#
# -- Documentation Labels -----------------------------------------------------------
#
# > Structured documentation lines use a small set of labels to identify the type
# > of content being documented.
#
# > The primary labels are:
#
# >     fn:      Function documentation
# >     var:     Variable documentation
# >     doc:     General documentation
#
# > Each label can be followed by either a colon or a dollar sign.
#
# > A colon indicates a normal documentation item:
#
# >     fn:      Normal function documentation
# >     var:     Normal variable documentation
# >     doc:     Normal general documentation
#
# > A dollar sign indicates a template documentation item:
#
# >     fn$      Template function documentation
# >     var$     Template variable documentation
# >     doc$     Template general documentation
#
# > Template items are primarily intended for reusable examples and template files.
# > The renderer can treat them differently from normal framework items, depending
# > on the group or context in which they appear.
#
# > The file doc-sample.sh demonstrates the supported labels and should be treated
# > as the practical reference for the documentation syntax.
#
# -- Sections and Structure ---------------------------------------------------------
#
# > Documentation comments can define product, module, section, subsection, and item
# > content.
#
# > Section headers are used to group related functions, variables, configuration
# > values, or explanatory text.
#
# > This allows generated documentation to be organized as a navigable hierarchy
# > instead of a flat list of extracted comments.
#
# > Good sectioning is especially important in larger modules, where a long list of
# > functions would otherwise become difficult to read.
#
# -- Style Hints --------------------------------------------------------------------
#
# > Documentation lines may include an optional leading marker that either identifies
# > plain documentation content or assigns a renderer style hint.
#
# > The plain documentation marker is:
#
# >     >           Plain documentation line
# >     >           When used without text, emits an intentional blank line
#
# > Style hints are presentation hints layered on top of the structural content type.
# > The renderer reads the exported stylehint value for each documentation line.
# > When the style hint is normal, no additional style class is added. When another
# > value is supplied, the renderer adds a corresponding sh-<stylehint> CSS class.
#
# > The currently supported style hints are:
#
# >     normal      Standard rendered text
# >     label       (:) Label or small subheader text
# >     highlight   (.) Highlighted text
# >     emphasis    (!) Emphasized text
# >     underline   (_) Underlined text
# >     quote       (~) Quoted or aside text
# >     listitem    (-) Bullet-style list item
# >     indent          Reserved indentation style
#
# > Marker characters are only interpreted when they are the first token after the
# > comment marker. Leading whitespace after "# " is preserved as author layout and
# > prevents marker interpretation.
#
# > These symbols are intended as visual cues and make it easier to identify the
# > purpose of a line while scanning a page.
#
# > Style hints should be used for presentation only. They do not replace content
# > labels such as fn:, fn$, var:, var$, doc:, or doc$.
#
# > The file doc-sample.sh should be treated as the practical reference for the
# > supported documentation syntax.
#
# -- Generated Output ---------------------------------------------------------------
#
# > The generated documentation consists of an HTML index, content pages, stylesheet
# > assets, appendices, glossary pages, and integrity information.
#
# > The output is intentionally static HTML so it can be viewed in any browser
# > without requiring a web server, database, or application runtime.
#
# > This makes the documentation easy to publish, archive, review, and distribute
# > together with a release package.
#
# -- Documentation Conventions ------------------------------------------------------
#
# > Documentation comments should be written as part of normal development, not as
# > an afterthought at release time.
#
# > Module headers should be kept complete and current.
#
# > Public functions should include enough information for another developer to
# > understand their purpose, expected inputs, output, return behavior, and typical
# > usage.
#
# > Internal helpers may use shorter documentation, but should still explain intent
# > when the behavior is not obvious.
#
# > Empty documentation separator lines should use a plain comment line rather than
# > a quoted documentation line, to avoid stray quote markers in rendered output.
#
# -- Why Source-Based Documentation -------------------------------------------------
#
# > Bash projects are especially vulnerable to documentation drift. Scripts are easy
# > to change quickly, and separate documentation is easy to forget.
#
# > SolidGroundUX avoids this by treating source comments as the primary
# > documentation source.
#
# > This does not remove the need for prose, examples, or architectural explanation,
# > but it does make the reference documentation much more likely to stay close to
# > the implementation.
