# FieldWiring Drive Context Resolver Engineering Design

| Document control | Value |
|---|---|
| Status | DRAFT — resolver design under test |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Runtime data authority | Current V7+ PostgreSQL/LOR snapshot |
| Legacy comparison authority | FormView / V6 reports are validation evidence only |
| Code/schema status | Design and read-only test contract; no schema change authorized |

## Purpose

This document records the durable engineering design for resolving the current Google Drive context used by FieldWiring.

The V7+ LOR model is Scene-aware. The Master Musical Preview normally carries useful path evidence at the Scene level rather than at Preview level, so FieldWiring must resolve Stage/Sub-stage/Scene context from current V7/PostgreSQL identity plus Scene/Preview path evidence before presenting wiring information.

The resolver has two distinct responsibilities:

1. resolve the correct structured scope — Stage, formal Sub-stage, or Scene; and
2. allow the FieldWiring task adapter to inspect only the current marked source folders belonging to that resolved scope.

The wiring-row result is the primary FieldWiring product. Images are supplemental guidance only.

---

## Runtime Authority Beginning With 2026

FieldWiring runtime resolution uses the current V7+/PostgreSQL state:

```text
approved current LOR previews
    -> V7 parser
    -> approved PostgreSQL snapshot
    -> current Preview / Scene / Display relationships
    -> FieldWiring
```

The development `fieldwiring_snapshot.db` is a read-only representation used for resolver testing.

V6 SQLite/FormView remains historical comparison evidence only and is never runtime authority for FieldWiring.

---

## Entry Methods

The resolver is independent of the operator entry method:

```text
Display QR
    OR Display lookup
    OR Scene browse
    OR Stage browse
        -> shared current field context
        -> current identity / hierarchy / Preview facts
        -> Drive context resolver
```

A physical QR identifies permanent Display identity. It does not encode a Google Drive path, LOR UUID, task-specific document, or FieldWiring URL.

---

## V7+ Background Path Model

### Master Musical Preview

The normal V7 musical path is:

```text
Master Musical Preview
    -> Scene
    -> Scene.background_file
    -> Google Drive navigation evidence
```

The Preview-level background is not expected to be the operational path anchor for the Master Musical Preview.

### Show Background Stage Previews

Background Previews may still provide useful Preview-level path evidence and may use a `Root` Scene.

`Root` means the owning Preview Stage root. It is not a literal child folder.

---

## `BackgroundFile` Is Navigation Evidence

A Scene/Preview `BackgroundFile` is an integration pointer into the Google Drive hierarchy. It is not automatically the image FieldWiring should present.

The pointer may refer to:

- a published wiring image;
- a marked `PreviewBackground` image;
- a Display/shared-folder background image;
- a deep legacy engineering file;
- a stale path;
- or a legacy `SourceDocs` path.

The resolver uses allowed path evidence to find the correct current Stage/Sub-stage/Scene scope. Once the scope is known, FieldWiring returns to the controlled marked source folders for published/current content.

Loose legacy files may remain valid path evidence without becoming FieldWiring content.

---

## Marker Boundary

The standard marker is:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Every current Stage, formal Sub-stage, and Scene root carries the structural marker.

Current application-source helpers are marked separately:

```text
PreviewBackground
Procedures
Wiring
```

`Photos` is not currently an application-source helper.

The structural marker supports validation of the resolved hierarchy. The helper marker confirms that the helper folder participates in the current application-source contract.

Loose files and unmarked legacy folders are ignored for current published-content discovery.

---

## `SourceDocs` Is a Hard Traversal Boundary

FieldWiring and the shared resolver must never descend into, enumerate, open, fetch, or present files from `SourceDocs`.

For example, a stored pointer such as:

```text
...\Wiring\MusicalStage\SourceDocs\WhoPeople.jpg
```

may provide path-text evidence above `SourceDocs`, but navigation stops before the `SourceDocs` folder.

The raw pointer may be retained in an engineering report as a cleanup finding. The source file itself is not accessed or presented.

---

## Google Shared Drive Root

Mapped Windows root:

```text
G:\Shared drives\Display Folders\
```

Shared Drive identifier:

```text
0AGgL6E6xJQh3Uk9PVA
```

`Display Folders` contains non-Stage repositories in addition to Stage folders. The resolver must never enumerate the Shared Drive root and assume every child is a Stage.

Current database identity and bounded LOR path evidence constrain navigation.

---

## Common Structured-Scope Resolver

The structured-scope resolver may be shared by FieldWiring and Procedure applications:

```text
current identity + allowed path evidence
        -> DRIVE CONTEXT RESOLVER
        -> Stage / Sub-stage / Scene
        -> task adapter
```

The common resolver owns **which structured root applies**.

The task adapter owns **what to do with that root**.

This is important because Wiring and Procedures are different tasks. FieldWiring must not import a Procedure-style parent fallback rule merely because both use the same hierarchy resolver.

Procedure presentation/availability is governed separately and is not part of the FieldWiring wiring-image fallback contract.

---

## Resolver Order

The resolver operates conservatively:

1. Start with current permanent Stage, Scene, Display, and Preview facts.
2. Obtain current V7 path evidence; for Master Musical this normally means `Scene.background_file`.
3. Confirm filesystem evidence is beneath the configured `Display Folders` root.
4. Inspect the path text for excluded branches before traversal.
5. Stop before `SourceDocs` when present.
6. Attempt the exact allowed path where appropriate.
7. Use allowed exact hierarchy evidence when it resolves.
8. Walk upward only as needed to identify the nearest valid current structured Stage/Sub-stage/Scene root.
9. If the stored path is stale, use current identity plus deterministic actual hierarchy rules to find one safe current marked root.
10. Use structural markers as supporting validation.
11. Do not rewrite LOR, PostgreSQL, or Drive as a side effect.
12. If current identity/path/hierarchy evidence does not yield one safe result, report review/unresolved rather than guess.

---

## Stale Path Recovery

A stale path does not invalidate current identity.

Current proven recovery examples include:

```text
02-Fred's Stars-TR
    -> current 02-Fred's Stars

17-Candy Land-CL
    -> current marked 17-Candyland-CL
```

Recovery is allowed only when one deterministic current marked hierarchy can be established. The stale stored value remains visible as a warning and is not silently rewritten.

---

## FieldWiring Scope Is Fixed Before Image Discovery

After the structured resolver identifies the applicable scope, that scope is fixed for FieldWiring image discovery:

```text
Resolved Scene
    -> Scene

Resolved Sub-stage
    -> Sub-stage

Resolved Stage
    -> Stage
```

The operator's wiring-context choice selects only the child branch:

```text
Background / Static -> Wiring\BackgroundStage
Musical             -> Wiring\MusicalStage
```

Changing wiring context does not change the resolved structured scope.

---

## No Parent Wiring-Image Fallback

This rule is now accepted:

> **FieldWiring must not crawl from a resolved Scene or Sub-stage back to its parent Stage to borrow a wiring image.**

If a Scene/Sub-stage owns the current wiring scope but has no published wiring image, the missing image is a documentation gap.

Example:

```text
05a-Mega Star-MS
    resolved scope = SUBSTAGE

05a-Mega Star-MS\Wiring\MusicalStage
    no published image

Stage 05\Wiring\MusicalStage
    published image exists
```

FieldWiring result:

```text
wiring rows: AVAILABLE when current V7 wiring data exists
wiring image: NO WIRING IMAGE AVAILABLE
```

FieldWiring must **not** show the Stage 05 wiring image as though it describes the Mega Star Sub-stage.

This behavior intentionally exposes missing documentation that should be filled.

---

## Wiring Data Is Primary; Images Are Supplemental

FieldWiring remains usable without a wiring image.

The primary field output is the current wiring data, including:

```text
Controller
Channel
Channel Name
Display Name
Network
```

A published image is rough field/layout guidance. Its absence does not make the wiring data unresolved.

Therefore the resolver/test/report must distinguish:

```text
scope resolution
wiring-row availability
published wiring-image availability
same-scope context-image availability
```

Do not collapse those into one `RESOLVED/UNRESOLVED` result merely based on whether an image exists.

---

## Same-Scope `PreviewBackground` May Be Context Only

If the resolved scope has no published wiring image, FieldWiring may show a marked `PreviewBackground` image from the **same resolved scope** as visual context.

It must be labeled as context rather than wiring.

Preferred field presentation:

```text
NO WIRING IMAGE AVAILABLE

Scene / Area Context:
    <same-scope PreviewBackground image>

Field Wiring:
    <Controller / Channel / Channel Name / Display / Network rows>
```

If no same-scope context image exists, FieldWiring simply shows `NO WIRING IMAGE AVAILABLE` and continues with the wiring data.

A parent Stage `PreviewBackground` is not substituted for a resolved Scene/Sub-stage context.

---

## Published Wiring Folder Rule

FieldWiring inspects only the applicable branch inside the fixed resolved scope:

```text
<resolved scope>\Wiring\BackgroundStage
<resolved scope>\Wiring\MusicalStage
```

Only files directly in that branch are published wiring-image candidates.

Expected image extensions include:

```text
.jpg
.jpeg
.png
```

Do not recursively crawl the Stage tree. Do not mix parent, sibling, loose legacy, archive, or source images into the package.

Multiple directly published images in the selected branch remain one paginated image set.

---

## Current All-Master Test Findings

The 2026-08-19 all-Master resolver test enumerated 18 current Master Musical Scenes.

After stale Stage-path recovery, the harness reached the correct structured scope in the expected 18-Scene test set, while the old image-driven result reported 14/18 because four Stages had no published image in their marked source structure.

Those four image gaps were:

```text
16-Northern Lights-NL
18-Dancing Forest-DF
19-Santa's Workshop-SW
22-Glistening Grove-GG
```

Under the clarified FieldWiring contract, those are **missing-image findings**, not failures to resolve the Stage or wiring data.

The all-Master test also exposed `05a-Mega Star-MS`, which incorrectly inherited the Stage 05 wiring image under the earlier candidate ladder. That behavior is now rejected by the no-parent-wiring-image rule.

Stage 07 cases demonstrated that generic Stage `PreviewBackground` images also must not be treated as wiring images for more-specific Scene scopes.

---

## Procedures Are a Separate Caller

The shared hierarchy resolver can also support Setup/Takedown/Inspection discovery, but Procedure behavior is separately governed.

FieldWiring should not attempt to present Procedure documents as part of its wiring-image resolution logic.

A broader field interface may later show which procedures are available for the resolved Stage/Scene context, but whether/how those documents open is a Procedure subsystem concern rather than a FieldWiring wiring rule.

---

## Acceptance Principle

The Drive/scope resolver gate is accepted when it can demonstrate:

> Given current V7/PostgreSQL identity, current Scene/Preview relationships, current path evidence, structural/source markers, and the actual Google Drive hierarchy, the application can deterministically locate the correct Stage/Sub-stage/Scene scope without V6 runtime data, unsafe folder guessing, or traversal into source-only branches.

Image completeness is evaluated separately from scope resolution.

FieldWiring presentation acceptance additionally requires that:

- current wiring rows remain the primary result;
- published images are restricted to the fixed resolved scope;
- a missing image is clearly reported rather than hidden by parent fallback;
- same-scope `PreviewBackground` is context only; and
- no parent/sibling/source image is substituted merely to produce a visual.

---

## Related Documents

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring View Inventory and Read-Model Decision](FieldWiring_View_Inventory_and_Read_Model_Decision.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring Drive Resolver All-Master Test Findings](FieldWiring_Drive_Resolver_All_Master_Test_Findings_2026-08-19.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Google Drive Path Resolution Contract](../../../00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md)
- [Google Drive Folder Structure](../../../00_Project_Overview/00-Google_Drive.md)
