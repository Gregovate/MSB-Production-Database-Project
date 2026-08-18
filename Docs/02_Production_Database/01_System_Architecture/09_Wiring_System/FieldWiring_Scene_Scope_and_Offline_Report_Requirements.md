# FieldWiring Scene Scope and Offline Report Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction |
| Sub-project | FieldWiring |
| Predecessor reference | FormView 0.3.1 Wiring View |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

This document records the Scene-aware wiring-image and offline-report behavior required for FieldWiring.

FormView proved the usefulness of combining wiring rows with one or more annotated field images and exporting a printable HTML document. Its limitation is that the application is Preview/Stage oriented: additional images discovered under the selected published wiring directory are presented as one paginated image set even when the physical work is more naturally organized into separate Scenes.

FieldWiring should preserve the useful multi-image and offline-document behavior while using the Production Database Scene relationships to narrow the field context when a defined Scene exists.

This document defines presentation and resolution requirements only. It does not authorize a database-schema or application-code change.

## Proven FormView Behavior

For a selected Preview, FormView currently:

1. reads the Preview `BackgroundFile`;
2. displays that image as the primary wiring image;
3. discovers additional published images from the same wiring directory;
4. presents them using Page X/Y pagination;
5. combines the image set with the selected Preview wiring rows; and
6. can export printable HTML for field use.

This behavior is useful and must not be lost merely because FieldWiring becomes browser based.

## Scene-Aware FieldWiring Scope

A Display scan resolves the permanent Display and its current field hierarchy.

Conceptually:

```text
Display QR
    -> display_id
    -> current Display record
    -> owning Scene, when defined
    -> owning Sub-stage, when applicable
    -> owning Stage
```

The task selected by the operator then determines the applicable presentation scope.

For FieldWiring, the preferred wiring scope is:

```text
Defined Scene
    -> Scene wiring context

No defined Scene
    -> applicable Sub-stage or Stage wiring context
```

The scan itself does not create, move, or change any Scene/Stage assignment.

## Scene-Scoped Wiring Rows

When the scanned Display belongs to a defined current Scene, the normal FieldWiring result should show the requisite wiring for that Scene rather than every wiring row from the complete Stage Preview.

This makes the scan result idempotent at the Scene level:

```text
scan Display A in Scene X -> Field Wiring -> Scene X wiring
scan Display B in Scene X -> Field Wiring -> Scene X wiring
scan Display C in Scene X -> Field Wiring -> Scene X wiring
```

The scanned Display may be highlighted or identified in the result, but it must not reduce a shared Scene wiring package to only that one Display.

If a Display is not assigned to a defined Scene, FieldWiring falls back to the applicable Sub-stage/Stage wiring scope.

### Shared-circuit preservation

Scene filtering must occur without changing the established field-lead semantics.

If multiple Displays within the resolved Scene legitimately share one controller/channel, every applicable Display relationship remains visible.

## Scene-Scoped Wiring Images

When a defined Scene owns the wiring documentation for the selected wiring context, FieldWiring should present the images belonging to that Scene as the default image set.

A Scene may legitimately have more than one published wiring image.

Those images remain one paginated set for that Scene:

```text
Scene X
    Wiring
        BackgroundStage or MusicalStage
            image 1
            image 2
            image 3

FieldWiring
    << Page 1/3 >>
```

The important change from FormView is the scope of the image set, not the elimination of pagination.

FieldWiring should not normally combine images from unrelated sibling Scenes into one Stage-wide image carousel merely because they ultimately belong to the same Stage.

## Stage/Sub-stage Fallback

Not every Display belongs to a defined Scene, and not every Scene necessarily has its own published wiring package.

Resolution must therefore be deterministic and conservative.

The intended lookup order is:

1. use the defined Scene wiring package when the Scene owns current wiring material for the selected context;
2. otherwise use the applicable Sub-stage wiring package when one exists;
3. otherwise use the owning Stage wiring package;
4. if the expected documentation cannot be resolved unambiguously, report the missing/ambiguous condition instead of silently choosing a different sibling folder.

This follows the existing project rule that uncertain documentation ownership must be surfaced rather than guessed.

## Background / Static versus Musical Context

Scene scope does not eliminate the distinction between the established wiring contexts.

The operator may still need a plain-language choice such as:

```text
Field Wiring
    Background / Static
    Musical
```

The selected context determines whether the Scene/Stage wiring presentation resolves through the Background or Musical branch.

The browser UI should use field-oriented wording while retaining traceability to the underlying LOR Preview/context.

## Multiple Images Remain a First-Class Requirement

A single image is not sufficient as a general FieldWiring assumption.

The browser application must support:

- one or more images for a resolved Scene/Stage wiring package;
- deterministic page order;
- previous/next navigation;
- Page X/Y indication;
- usable zoom or image enlargement;
- clear identification of the current Scene/Stage and wiring context; and
- inclusion of every current published image in the corresponding offline report.

The implementation does not need to reproduce the exact Tkinter controls, but it must preserve equivalent field usability.

## Offline Field Requirement

Internet access is not reliable in every part of the park.

FieldWiring therefore cannot assume that a technician will always have a live browser connection while performing setup.

The existing FormView printable HTML is operationally valuable because it can be generated while connected and then used as a portable field document.

FieldWiring must preserve an equivalent offline path.

## Self-Contained Offline HTML

FieldWiring should provide a **single-file printable HTML export** for the resolved wiring package.

The exported HTML must remain usable after the device loses network access.

At minimum it must contain locally within the exported artifact:

- resolved Stage/Sub-stage/Scene identity;
- selected wiring context;
- all applicable field-wiring rows;
- all applicable published wiring images;
- generation timestamp;
- explicit expiration timestamp;
- source snapshot/provenance sufficient to identify the data used; and
- the FieldWiring stale-document warning.

The HTML must not depend on:

- a mapped `G:` drive;
- `file:///G:/...` image references;
- live calls back to PostgreSQL;
- live calls to `my.sheboyganlights.org`; or
- live Google Drive image fetching after the export has been created.

Images may be embedded directly in the HTML or packaged by another method only if the resulting artifact remains reliably portable and offline. A single self-contained file is preferred for field simplicity.

## PDF

PDF may also be offered if useful, but PDF does not replace the requirement to preserve the practical offline/export behavior already proven by FormView unless the replacement is explicitly tested and accepted as operationally superior.

The current priority is the field outcome: generate while connected, then retain a current portable package that can be viewed or printed without Internet access.

## Offline Report Scope

The exported document must correspond to the same resolved package shown on screen.

Examples:

```text
Display in Scene X
    -> Field Wiring / Background
    -> Scene X wiring rows
    -> Scene X Background wiring images
    -> one offline HTML package
```

and:

```text
Display with no Scene
    -> Field Wiring / Background
    -> Stage wiring rows
    -> Stage Background wiring images
    -> one offline HTML package
```

The report must not silently expand a Scene-scoped browser result into a complete Stage-wide report unless the operator deliberately chooses a Stage-wide report.

## Expiration / Stale Document Rule

Offline capability increases the stale-document risk, so expiration markings are mandatory.

Every generated offline package must prominently show:

```text
Generated: <absolute local date/time>
Expires:   <absolute local date/time>
```

The current accepted default remains expiration at the end of the local calendar day in which the report is generated.

The report is also superseded immediately by a newer approved wiring snapshot/Preview build.

The document should identify the source import/snapshot and Preview/context so an operator or lead can determine which data created the package.

## FormView Transition Requirement

FormView remains available during FieldWiring development.

Scene-aware filtering and offline export must be validated against known-good Stages before FieldWiring replaces FormView for field wiring.

Comparison should include:

1. the full Stage/Preview wiring result in FormView;
2. the corresponding Scene membership in the Production Database;
3. the FieldWiring Scene-filtered wiring result;
4. the Scene's image set and page order;
5. fallback behavior for Displays without Scenes;
6. Background/Static versus Musical context;
7. shared circuits;
8. SPARE filtering; and
9. the exported offline HTML opened with network access disabled.

## Acceptance Cases

At minimum, test:

- a Stage with several defined Scenes;
- two or more Displays in the same Scene, proving identical base FieldWiring results;
- a Scene containing more than one wiring image;
- sibling Scenes with different image sets, proving they are not mixed together;
- a Display with no Scene, proving Stage/Sub-stage fallback;
- a Scene with no own wiring package, proving controlled fallback;
- a shared circuit involving multiple Displays in the same Scene;
- offline HTML with all images embedded/available after disconnecting from the network; and
- expiration/currentness markings on both screen and print.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Folder Alignment Engineering Design](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [Google Drive Folder Structure](../../../00_Project_Overview/00-Google_Drive.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
