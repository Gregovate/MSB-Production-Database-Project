# FieldWiring Drive Context Resolver Engineering Design

| Document control | Value |
|---|---|
| Status | DRAFT — resolver design under test |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Runtime data authority | Current V7+ PostgreSQL/LOR snapshot |
| Legacy comparison authority | FormView / V6 reports are validation evidence only |
| Code/schema status | Design and test contract; no schema change authorized |

## Purpose

This document records the durable engineering design for resolving the current Google Drive documentation context used by FieldWiring and related field applications.

The resolver exists because the V7+ LOR model is Scene-aware. FormView historically used a selected Preview and Preview-level `BackgroundFile`, but that is not sufficient for the current model. In particular, the Master Musical Preview does not normally carry the useful background path at Preview level; its individual Scenes carry the current `BackgroundFile` path evidence.

The first implementation task is therefore to prove Scene/Stage path resolution against the current V7 snapshot and the real Google Shared Drive hierarchy before building the FieldWiring browser application around it.

## Runtime Authority Beginning With 2026

Beginning with the 2026 FieldWiring implementation, runtime resolution must use the current V7+/PostgreSQL state.

Conceptually:

```text
approved current LOR previews
        -> V7 parser
        -> approved PostgreSQL snapshot
        -> current Preview / Scene / Display relationships
        -> FieldWiring resolver
```

The development export `fieldwiring_snapshot.db` is a read-only representation of the current PostgreSQL state and may be used for resolver development and acceptance testing.

The V6 SQLite database and FormView are not runtime authorities for FieldWiring. They remain useful as known-good historical comparison evidence for expected wiring rows, drawings, and operator outcomes.

## Entry Methods

The Drive resolver must not depend on how the operator reached the field context.

Supported entry paths are:

```text
physical Display QR scan
        OR
PC Display lookup
        OR
PC Scene browse/lookup
        OR
PC Stage browse/lookup
        |
        v
shared field context resolution
        |
        v
current permanent identity + Stage / Scene / Preview facts
        |
        v
Drive context resolver
```

A Display QR identifies the permanent Production Database Display. It does not contain a Google Drive path or task-specific document URL.

A PC user may begin directly from a Display, Scene, or Stage without requiring a physical scan.

## V7+ Background Path Model

### Show Background Stage Previews

Show Background Stage previews may still have useful Preview-level background context, but the resolver must use the current V7 Scene/Preview evidence rather than assuming Preview-level population.

A Background Preview may also use a `Root` Scene. In that case `Root` means the owning Preview Stage root; it does not imply a literal `Root` folder.

### Master Musical Preview

The Master Musical Preview is not expected to use a Preview-level `BackgroundFile` as the operational path anchor.

Its individual Scenes carry the useful current path evidence:

```text
Master Musical Preview
        -> Scene
        -> Scene.background_file
        -> Google Drive navigation pointer
```

This Scene-level `BackgroundFile` behavior is the key V7+ replacement for the former RGB Plus Preview-level image/path organization.

## Scene `BackgroundFile` Is a Navigation Pointer

The current Scene `BackgroundFile` is an integration pointer/anchor into the Google Drive engineering hierarchy.

It is **not necessarily the final image or document that the calling application will present**.

The pointer may refer to:

- a published Wiring image;
- a Scene `PreviewBackground` image;
- a Display-level `PreviewBackground` image;
- a deeper legacy engineering image;
- a file inside a `SourceDocs` branch; or
- another current LOR-referenced image whose path still provides useful hierarchy evidence.

The application uses the pointer to navigate into the correct Stage / Substage / Scene part of the Drive, then the calling task applies its own branch rules.

## Google Shared Drive Root

The current Google Workspace Shared Drive is **Display Folders**.

Current mapped Windows root used by LOR/Google Drive for desktop:

```text
G:\Shared drives\Display Folders\
```

Current Google Shared Drive/root identifier:

```text
0AGgL6E6xJQh3Uk9PVA
```

`Display Folders` contains many non-Stage engineering repositories in addition to Stage folders. Therefore:

> The resolver must never enumerate the Shared Drive root and assume that every child folder is a Stage.

Permanent Stage/Scene identity and the current LOR path pointer constrain navigation.

## Common Drive Context Resolver

The Drive context resolver is shared infrastructure. FieldWiring, Setup, Takedown, Inspection, and future field-document applications should consume the same resolved structured scope rather than independently inventing path rules.

Conceptually:

```text
current Display / Scene / Stage context
        +
current Scene/Preview BackgroundFile path evidence
        |
        v
DRIVE CONTEXT RESOLVER
        |
        v
resolved structured root
(Stage / Substage / Scene)
        |
        +--> Wiring task adapter
        +--> Procedures task adapter
        +--> Photos task adapter
        +--> future task adapters
```

The common resolver owns scope discovery. The calling application owns which standardized branch to inspect after the scope is known.

## Resolver Behavior

The first resolver implementation should operate conservatively in this order:

1. Start with the permanent/current Stage, Scene, and Preview facts supplied by the field-context resolver or direct PC browse selection.
2. Obtain the applicable current V7 `BackgroundFile` evidence. For Master Musical this normally means the selected Scene's `background_file`.
3. Normalize the known mapped-drive prefix without treating that prefix as identity.
4. Attempt to walk the exact stored relative path beneath the `Display Folders` Shared Drive root.
5. If the exact stored path resolves, use its hierarchy as strong current filesystem evidence.
6. Walk upward from the pointed file as necessary to identify the nearest valid structured Scene, Substage, or Stage context under the governing naming/hierarchy rules.
7. A pointer inside `SourceDocs` may identify the correct scope or Wiring context, but `SourceDocs` itself is not normal published field content.
8. If the stored path no longer resolves, use the known current Stage + Scene identity and the actual folder hierarchy to locate the deterministic current structured folder.
9. Do not repair or rewrite the LOR `BackgroundFile` as a side effect of viewing documentation.
10. If current identity, path evidence, naming, and hierarchy do not produce one safe answer, return an unresolved/review result instead of guessing.

This design intentionally supports legacy cleanup. As folders and Scene backgrounds become better aligned, the resolver should naturally take simpler paths without requiring a new application architecture.

## Path Evidence Can Be Stale Without Invalidating Current Identity

A stored Scene background path may no longer exactly match the current Google Drive folder name.

For example, a Scene may still point to a prior folder spelling or suffix while the Production Database correctly identifies the current Stage and Scene.

The resolver must distinguish:

```text
permanent/current identity
    !=
fragile historical path text
```

An exact path failure therefore triggers controlled hierarchy resolution; it does not authorize fuzzy guessing.

A deterministic unique match based on current Stage/Scene identity and the governing folder rules may be accepted by the resolver test. Multiple plausible matches or contradictory evidence must be reported for review.

## FieldWiring Task Adapter

After the common resolver identifies the applicable structured scope, FieldWiring selects the wiring context requested by the operator:

```text
Background / Static
        -> Wiring\BackgroundStage

Musical
        -> Wiring\MusicalStage
```

The Drive/image resolution is separate from electrical wiring-row authority.

Current controller/channel/network rows continue to come from the current V7/PostgreSQL wiring model and Scene membership. The Drive resolver supplies the associated visual/documentation package.

## Candidate Wiring Visual Fallback Order — Under Test

The following most-specific-to-less-specific order reflects the current operator hypothesis and **must be tested before being treated as final production behavior**:

```text
resolved Scene
    |
    |-- 1. applicable Scene Wiring branch exists?
    |       YES -> use Scene Wiring
    |
    |-- 2. usable Scene PreviewBackground exists?
    |       YES -> use Scene visual context
    |
    |-- 3. applicable Stage Wiring branch exists?
    |       YES -> use Stage Wiring
    |
    |-- 4. usable Stage PreviewBackground exists?
            YES -> use Stage visual context

otherwise -> unresolved / missing documentation
```

The exact treatment of a formal Substage within this fallback ladder remains subject to testing under the already-established Google Drive hierarchy rules. Do not silently invent a Substage fallback order merely to make a test pass.

The test must make clear whether the selected result came from:

- exact Scene Wiring;
- Scene PreviewBackground fallback;
- Stage Wiring fallback;
- Stage PreviewBackground fallback; or
- unresolved/review.

This fallback ladder concerns the **visual/document package**. It does not change or broaden the V7 Scene-filtered electrical wiring rows.

## Published Wiring Folder Rule

When an applicable published Wiring branch is selected, FieldWiring should inspect that exact folder rather than recursively crawling the complete Stage tree.

Published branches are:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

Current published image extensions are expected to include:

```text
.jpg
.jpeg
.png
```

`SourceDocs` is not normal published field content regardless of whether it appears nested beneath a Wiring branch or as a legacy sibling folder.

Additional archive/source/engineering folders must not become visible merely because they are physically nearby in the Drive hierarchy.

## Procedure Applications Use the Same Scope Resolver

Procedure applications should use the same Stage/Substage/Scene context resolver and then apply their own branch.

Conceptually:

```text
resolved structured scope
        |
        +--> Procedures\Setup
        +--> Procedures\Takedown
        +--> Procedures\Inspection
```

The common Drive resolver should not contain Setup-, Takedown-, or Inspection-specific content rules.

Likewise, the Procedure application must not independently reinterpret the Scene background path or create another competing Stage/Scene folder resolver.

The exact Procedure inheritance/fallback behavior remains owned by the applicable Procedure subsystem documentation. The common resolver supplies the structured scope and filesystem evidence.

## First Test Gate — Resolver Before Browser

Before implementing the FieldWiring browser page, build and run a read-only resolver test harness against:

- the current `fieldwiring_snapshot.db` development snapshot / equivalent current PostgreSQL relations; and
- the actual mapped `G:\Shared drives\Display Folders` folder hierarchy.

The first test does **not** need to prove the final browser UI, QR scanner, wiring table layout, or report export.

It must first prove that V7 Scene path evidence can navigate to the correct structured Drive scope and expose the correct candidate task folders.

For every test Scene, record at minimum:

```text
Preview
Scene
Stage
Scene BackgroundFile pointer
whether exact stored pointer resolves
resolved Stage/Substage/Scene root
candidate Scene Wiring branch
candidate Scene PreviewBackground
candidate Stage Wiring branch
candidate Stage PreviewBackground
selected candidate under the current test rule
resolution basis
warnings / conflicts / unresolved condition
```

## Initial Resolver Acceptance Cases

The first harness should include at least these current V7 cases because they exercise different path shapes:

### `15-Church-CH`

Purpose: direct published Musical Wiring path.

Expected behavior: path evidence should resolve Stage 15 / Church scope and the applicable `Wiring\MusicalStage` branch without using V6 runtime data.

### `05a-Mega Star-MS`

Purpose: deep arbitrary image path beneath a formal Substage.

Expected behavior: walk upward from the pointed image to the valid `05a-Mega Star-MS` structured root and identify the applicable task candidates there.

### `03-Mega Cube-MC`

Purpose: Scene-level `PreviewBackground` context where Scene-level Wiring may not exist.

Expected behavior: report the available Scene/Stage candidates and show which fallback step would be selected by the current test rule.

### `07-Who Characters`

Purpose: pointer inside a `SourceDocs` branch.

Expected behavior: use the pointer as scope/context evidence but do not treat `SourceDocs` itself as published field content.

### `02-Fred's Stars`

Purpose: stored path text that may no longer exactly match the current actual folder name.

Expected behavior: exact pointer failure must trigger controlled Stage/Scene hierarchy resolution. The harness must report whether one unique safe current folder can be resolved; it must not silently use fuzzy matching.

## Church Dual-Context Acceptance Case

Stage 15 Church is also the first complete two-context FieldWiring acceptance case after the resolver itself is proven.

The same permanent physical Stage must resolve two independent current V7 wiring contexts:

```text
Stage 15 Church
    |
    +--> Background / Static
    |       -> current Show Background Preview / Scene context
    |       -> BackgroundStage visual package
    |       -> current background wiring rows
    |
    +--> Musical
            -> Master Musical Preview
            -> Scene 15-Church-CH
            -> MusicalStage visual package
            -> current musical wiring rows
```

The V6 FormView reports remain comparison evidence for the final field result, but neither branch may depend on the V6 database at runtime.

## Acceptance Principle

The resolver is accepted only when it can demonstrate:

> Given current V7/PostgreSQL identity, Scene/Preview relationships, current Scene path evidence, and the actual Google Drive hierarchy, the application can deterministically locate the correct structured documentation context without relying on V6 runtime data, hard-coded per-Stage paths, or unsafe folder guessing.

Only after that gate passes should FieldWiring browser implementation proceed to wiring rows + images + filters + offline report behavior.

## Related Documents

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring View Inventory and Read-Model Decision](FieldWiring_View_Inventory_and_Read_Model_Decision.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Google Drive Path Resolution Contract](../../../00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md)
- [Google Drive Folder Structure](../../../00_Project_Overview/00-Google_Drive.md)
