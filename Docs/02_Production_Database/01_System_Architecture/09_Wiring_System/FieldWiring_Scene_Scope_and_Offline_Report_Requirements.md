# FieldWiring Scene Scope and Offline Report Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction |
| Sub-project | FieldWiring |
| Predecessor reference | FormView 0.3.1 Wiring View |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION / TEST CONTRACT |

## Purpose

This document records the Scene-aware wiring-image and offline-report behavior required for FieldWiring.

FormView proved the usefulness of combining wiring rows with one or more annotated field images and exporting a printable HTML document. FieldWiring preserves that practical field outcome while using current Production Database Scene/Sub-stage/Stage relationships and the controlled Google Drive source structure.

A critical distinction is now explicit:

> **Procedure inheritance and Wiring inheritance are not the same rule.**

A Procedure may legitimately apply at a parent Stage/Sub-stage level. FieldWiring must not silently substitute a parent wiring image for a more-specific Scene/Sub-stage whose own wiring image is missing.

---

## Scene-Aware FieldWiring Scope

A Display scan or operator lookup resolves the permanent Display and its current hierarchy:

```text
Display
    -> defined Scene, when applicable
    -> formal Sub-stage, when applicable
    -> Stage
```

For FieldWiring, the resolved wiring scope is the **most-specific current structured scope that owns the selected wiring context**.

Examples:

```text
Display in Scene X
    -> Scene X wiring scope

Display in formal Sub-stage with no separate Scene wiring scope
    -> Sub-stage wiring scope

Display with no defined Scene/Sub-stage wiring scope
    -> Stage wiring scope
```

Once that wiring scope is resolved, FieldWiring stays inside it for wiring-image discovery.

---

## No Parent Wiring-Image Inheritance

When a Scene or Sub-stage is the resolved FieldWiring scope, FieldWiring must **not crawl upward to the parent Stage to borrow a wiring image** merely because the Scene/Sub-stage wiring branch is empty.

That would mix two different physical/documentation scopes and could show the operator a wiring drawing that does not describe the selected Scene.

Therefore:

```text
Resolved Scene
    -> Scene Wiring only
    -> optional Scene PreviewBackground for visual context only
    -> otherwise NO WIRING IMAGE AVAILABLE

Resolved Sub-stage
    -> Sub-stage Wiring only
    -> optional Sub-stage PreviewBackground for visual context only
    -> otherwise NO WIRING IMAGE AVAILABLE

Resolved Stage
    -> Stage Wiring
    -> optional Stage PreviewBackground for visual context only
    -> otherwise NO WIRING IMAGE AVAILABLE
```

A missing Scene/Sub-stage wiring image is a documentation gap to expose and fill, not a reason to use the parent Stage wiring drawing.

This rule applies to **Wiring**. It does not prohibit Setup/Takedown/Inspection procedures from using their separately defined parent-scope inheritance rules.

---

## PreviewBackground Is Context, Not Wiring

`PreviewBackground` may be useful when no published wiring drawing exists at the resolved scope because it can show the operator what the Scene/Sub-stage/Stage looks like.

However, it must be labeled honestly.

The operator presentation should distinguish:

```text
WIRING IMAGE
    published image from Wiring\BackgroundStage or Wiring\MusicalStage

CONTEXT IMAGE
    image from the same scope's PreviewBackground

NO WIRING IMAGE AVAILABLE
    no published wiring image exists at the resolved scope
```

If a context image is available, the preferred presentation is:

```text
NO WIRING IMAGE AVAILABLE

Context image:
    <same-scope PreviewBackground image>
```

The context image must never receive a badge or caption that implies it is a published wiring drawing.

This makes missing documentation visible while still giving the field user useful visual orientation when possible.

---

## Scene-Scoped Wiring Rows

When the scanned Display belongs to a defined current Scene, the normal FieldWiring result shows the requisite wiring rows for that Scene rather than every row from the complete Stage Preview.

This creates idempotent Scene behavior:

```text
scan Display A in Scene X -> Field Wiring -> Scene X wiring
scan Display B in Scene X -> Field Wiring -> Scene X wiring
scan Display C in Scene X -> Field Wiring -> Scene X wiring
```

The scanned Display may be highlighted, but it must not reduce a shared Scene wiring package to only that one Display.

Shared controller/channel relationships within the resolved Scene remain visible according to the established field-lead semantics.

The wiring-row scope is independent of whether a wiring image currently exists.

A Scene can therefore legitimately present:

```text
Scene X
    wiring rows: AVAILABLE
    wiring image: MISSING
    context image: AVAILABLE or MISSING
```

---

## Published Wiring Images

For the resolved wiring scope and selected context, FieldWiring inspects only the corresponding published branch:

```text
<resolved scope>\Wiring\BackgroundStage
```

or:

```text
<resolved scope>\Wiring\MusicalStage
```

Only directly published image files in that branch are normal wiring-image candidates.

Current expected extensions include:

```text
.jpg
.jpeg
.png
```

`SourceDocs` is never field content and is a hard traversal boundary.

FieldWiring must not combine images from a parent Stage, sibling Scene, or unrelated folder merely to avoid a missing-image condition.

---

## Multiple Images Remain a First-Class Requirement

A resolved wiring scope may contain more than one published wiring image.

FieldWiring must support:

- all published images from the resolved wiring branch;
- deterministic page order;
- previous/next navigation;
- Page X/Y indication;
- zoom or image enlargement;
- clear Stage/Sub-stage/Scene and wiring-context identification; and
- the same image set in the offline report.

Images from sibling or parent scopes are not added to that set.

---

## Background / Static Versus Musical

The operator may choose:

```text
Field Wiring
    Background / Static
    Musical
```

The selected context determines the branch within the already resolved wiring scope:

```text
Background / Static -> Wiring\BackgroundStage
Musical             -> Wiring\MusicalStage
```

Changing wiring context does not authorize changing the resolved Scene/Sub-stage/Stage scope.

---

## Procedure Inheritance Is Separate

Setup, Takedown, Inspection, and other procedure applications may have valid parent-scope inheritance because a Stage-level procedure can intentionally apply to child Scenes or Displays.

That behavior is owned by the Procedure subsystem documentation.

Conceptually:

```text
Procedures
    Scene procedure if applicable
        else Sub-stage / Stage procedure according to Procedure rules
```

FieldWiring does **not** reuse that fallback behavior for wiring images.

The shared Drive resolver may resolve hierarchy for both callers, but each task adapter applies its own task-specific ownership rules after the structured scope is known.

---

## Operator Missing-Image Behavior

When the resolved FieldWiring scope has no published wiring image, the browser should clearly display:

```text
NO WIRING IMAGE AVAILABLE
```

If the same resolved scope has one or more `PreviewBackground` images, FieldWiring may also show them under a separate label such as:

```text
Scene / Area Context
```

The UI must make clear that the context image is not the wiring drawing.

This missing-image state is useful operationally because it exposes documentation holes that should be filled before setup season.

The wiring table should still display when authoritative wiring rows are available even if the visual is missing.

---

## Offline Field Requirement

FieldWiring must preserve an offline path equivalent to the practical FormView printable HTML behavior.

The preferred export remains a self-contained printable HTML file containing:

- resolved Stage/Sub-stage/Scene identity;
- selected Background/Static or Musical context;
- all applicable field-wiring rows;
- all published wiring images from the resolved wiring scope;
- a clearly labeled same-scope context image when one is intentionally included;
- `NO WIRING IMAGE AVAILABLE` when published wiring imagery is missing;
- generation timestamp;
- expiration timestamp;
- source snapshot/provenance; and
- stale-document warning.

The offline package must not depend on a mapped `G:` drive, live PostgreSQL, live Google Drive fetching, or live `my.sheboyganlights.org` access after export.

The current accepted default remains expiration at the end of the local calendar day in which the report is generated. A newer approved wiring snapshot supersedes an older package immediately.

---

## FormView Transition Requirement

FormView remains available during FieldWiring development until the replacement behavior is explicitly accepted.

Comparison must include:

1. wiring rows;
2. resolved Scene/Sub-stage/Stage scope;
3. published wiring images;
4. missing wiring-image behavior;
5. same-scope context-image behavior;
6. Background/Static versus Musical selection;
7. shared circuits;
8. SPARE filtering; and
9. offline HTML opened without network access.

---

## Acceptance Cases

At minimum, test:

- a Stage-level wiring scope with a published wiring image;
- a Scene with its own published wiring image;
- a Scene with no wiring image but with a Scene `PreviewBackground` context image;
- a Scene with neither wiring nor context image, proving `NO WIRING IMAGE AVAILABLE`;
- a Scene whose parent Stage has a wiring image, proving the Stage image is **not** substituted;
- a Sub-stage whose parent Stage has a wiring image, proving the Stage image is **not** substituted;
- sibling Scenes with different image sets, proving they are never mixed;
- a Scene containing multiple published wiring images;
- shared circuits within a Scene;
- wiring rows displayed even when the image is missing; and
- offline HTML preserving the same missing/context/wiring distinction.

---

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Folder Alignment Engineering Design](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [Google Drive Folder Structure](../../../00_Project_Overview/00-Google_Drive.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
