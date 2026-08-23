# Procedure System Field Context Handoff — 2026-08-22

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING HANDOFF — resolves Procedure/FieldWiring documentation conflicts |
| Current revision | 2026-08-22 |
| Source baseline | `main` after accepted FieldWiring + Display Scan integration |
| Production field entry | `https://my.sheboyganlights.org/fieldwiring/` and `https://my.sheboyganlights.org/scan/` |
| Shared document filesystem | read-only Google `Display Folders` hierarchy on `msb-prod-db` |
| Procedure subsystem | Setup / Takedown / Inspection field-document presentation |

## Purpose

This handoff defines the starting architecture for the Procedure subsystem and resolves conflicting older engineering language about how Setup/Takedown/Inspection documents must be located.

The accepted direction is deliberately simple:

> **Use the same proven structured Stage/Sub-stage/Scene resolution used by FieldWiring. After the structured root is fixed, switch to the Procedure task branch instead of the Wiring branch.**

Do not build a second independent Display-to-Stage/Scene resolver for Procedures.

Do not require a new PostgreSQL row, Google document ID, or manually maintained direct document URL for every published Procedure PDF merely to make the first Procedure browser work.

PostgreSQL remains authoritative for durable Display/Stage/Scene identity and relationships. Google Shared Drive `Display Folders` remains authoritative for editable/published engineering documents. The server-side filesystem is the read-only bridge between those authorities.

---

## Accepted Production Prerequisites — Already Complete

The Procedure project must treat the following as existing production infrastructure, not prerequisites to rediscover or rebuild:

### FieldWiring

FieldWiring is production-operational and already proves:

```text
permanent Display identity
    -> current PostgreSQL Stage / Scene / Preview facts
    -> stored/current LOR path evidence
    -> Windows-root to Linux-root translation
    -> bounded marked Stage/Sub-stage/Scene resolution
    -> read-only Google filesystem traversal
    -> task-specific field presentation
```

Relevant production source includes:

```text
FieldWiring/Application/repository.py
FieldWiring/Application/wiring_images.py
FieldWiring/Application/wiring.py
```

The structured-scope behavior in `wiring_images.py` is the proven starting point. In particular, the current resolver already provides guarded behavior for:

- translating `G:\Shared drives\Display Folders\...` evidence to the server-visible tree;
- validating the configured `Display Folders` root;
- resolving a marked Stage root;
- resolving a marked Scene when one deterministically matches current Scene identity;
- retaining the known marked Stage root when no distinct Scene folder exists;
- bounded Scene search rather than unbounded drive crawling;
- stale path recovery only when one safe current marked hierarchy can be established;
- stopping before `SourceDocs`;
- failing visibly rather than guessing when evidence is ambiguous.

### Display Scan

The Display scan integration is accepted production work.

The existing QR/scan route resolves:

```text
DISP:<display_id>
    -> ref.display.display_id
```

FieldWiring is already launched from the Display scan hub using the permanent Display ID.

The Procedure system must reuse that same permanent identity handoff when Procedure actions are later added to the scan hub. No physical QR change is required.

The accepted scan integration is documented in:

```text
../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md
```

### Shared Google filesystem

The server-side Google `Display Folders` filesystem is production-operational and intentionally shared infrastructure for FieldWiring and future Procedure applications.

The Procedure project must not create a second Google authorization model, duplicate mount, downloaded document mirror, or Procedure-only Google hierarchy.

The field-presentation service is a read-only consumer of the same human-maintained Shared Drive structure.

---

## Shared Resolver Versus Task Adapter

This distinction is the central conflict-resolution rule.

### Shared structured-scope resolver owns

The common resolver answers only:

> **Which current structured Stage / Sub-stage / Scene root owns this field context?**

Its inputs may include:

- permanent `display_id` when entry began from a Display;
- current `ref.display` / `ref.stage` relationships;
- current `ref.lor_scene_display` / `ref.lor_scene` relationships;
- current Preview/Scene path evidence where useful;
- the marked Google Drive hierarchy;
- the configured shared `Display Folders` root.

Its output is a fixed structured context such as:

```text
scope_type = STAGE | SUBSTAGE | SCENE
scope_root = <current server-visible marked folder>
trigger_display_id = <optional permanent Display ID>
current Stage/Scene identity and provenance
warnings = <stale path / fallback / ambiguity evidence>
```

The Procedure project should reuse or extract the existing FieldWiring structured-scope logic rather than implement a second competing algorithm.

If extraction into a common module is required, it must be additive and regression-tested so existing FieldWiring behavior remains unchanged.

### Procedure task adapter owns

Once `scope_root` is fixed, the Procedure adapter answers:

> **Which current Procedure task content is published directly under this already-resolved scope?**

The initial task branches are:

```text
Setup      -> <scope_root>/Procedures/Setup
Takedown   -> <scope_root>/Procedures/Takedown
Inspection -> <scope_root>/Procedures/Inspection
```

The Procedure adapter must not re-resolve the Display, widen/narrow the scope based on filenames, or crawl to unrelated parent/sibling documentation just because the selected task folder is empty.

This is directly analogous to FieldWiring after structured resolution:

```text
same structured root
    |
    +--> FieldWiring adapter -> Wiring/BackgroundStage or Wiring/MusicalStage
    |
    +--> Procedure adapter   -> Procedures/Setup, Procedures/Takedown, Procedures/Inspection
```

---

## Procedure Marker Contract

Procedure markers remain task-specific and are not identical to FieldWiring's Wiring marker rules.

For the Procedure application path, current governing documentation requires markers on:

```text
<Stage / Sub-stage / Scene root>
Procedures
Procedures/Inspection
Procedures/Setup
Procedures/Setup/images
Procedures/Takedown
Procedures/Takedown/images
```

`Archive` and `SourceDocs` are excluded working/history areas and are not normal field-presentation sources.

This is **not** a conflict with reuse of the structured resolver.

The common resolver establishes the structured root. The Procedure adapter then validates the markers required by the Procedure branch it owns.

Do not copy Procedure child-marker requirements back onto FieldWiring's `Wiring/BackgroundStage` or `Wiring/MusicalStage` folders.

---

## Initial Current-Document Discovery Contract

The first Procedure browser does not require a per-document database registry merely to discover current published PDFs.

For the initial implementation, after the structured root and Procedure task branch are validated:

1. enumerate files **directly** in the selected task folder;
2. present approved current field-document formats supported by the implementation, beginning with PDF;
3. exclude the marker file itself from user choices;
4. do not recurse into `Archive`;
5. do not recurse into `SourceDocs`;
6. do not treat files inside `images` as independent Procedure documents;
7. if more than one current PDF exists, present a simple current-document list;
8. if no current document exists, show a clear missing-document state;
9. do not search neighboring Stage/Scene folders by filename in order to manufacture a result.

Example:

```text
resolved scope_root
    -> Procedures
        -> Setup
            -> Current Setup A.pdf
            -> Current Setup B.pdf
            -> images/        supporting assets, not separate procedure choices
            -> Archive/       excluded
            -> SourceDocs/    excluded
```

A filename may be used as a user-facing label for a discovered current file. It is not permanent Production Database identity.

---

## Durable Document IDs Are Not an Initial Runtime Prerequisite

Older Setup documents contain language suggesting the Procedure system must first determine where Google Doc IDs or published PDF references are stored in PostgreSQL.

That remains a legitimate **future publication/governance capability**, but it is not required for the first read-only Procedure browser because the accepted server architecture can safely enumerate the controlled current task folder after identity/scope resolution.

Durable per-document metadata may later be justified for needs such as:

- explicit approval/publication workflow;
- revision history independent of filenames;
- supersession relationships;
- Google Doc source -> published PDF lineage;
- content hashes;
- audit/history requirements;
- stable references when documents are deliberately renamed;
- workflow status beyond what the controlled current/archive folder contract expresses.

Do not create a new schema object merely because older documentation listed this as unresolved.

First prove the read-only Procedure application against the existing identity + hierarchy + marked-filesystem contract. Add schema only when a demonstrated requirement cannot be met safely by that contract.

---

## Source Versus Published Content

The authoring/publication workflow remains separate from runtime discovery.

Current intended Setup flow is still conceptually:

```text
editable source / legacy source
    -> review / convert / approve
    -> current field PDF published directly in Procedures/Setup
    -> old material retained under Archive or SourceDocs as governed
```

The Procedure field application consumes the published current result. It does not become the Google Docs editor or document-conversion authority.

The existing question of how a Google Doc source is linked durably to its published PDF may be engineered separately without blocking read-only current-PDF discovery.

---

## Scope Behavior

The Procedure application must preserve context idempotence.

If two Displays resolve to the same structured Scene for Setup, then:

```text
Display A lookup
Display B lookup
Scene browse
```

must all produce the same base `Procedures/Setup` result for that resolved Scene.

The triggering Display may remain visible for operator orientation, but it must not cause duplicate copies or a different Procedure package merely because a different Display in the same scope was selected.

If the shared structured resolver returns the Stage root rather than a distinct Scene root, the Procedure task is resolved beneath that Stage root. Do not run a second independent Procedure-only Scene guessing algorithm.

---

## Entry Methods

The Procedure browser should ultimately support the same three useful entry paths already established by FieldWiring/Scan:

```text
Find Display
Browse Stage / Scene
Scan permanent Display QR
```

All three entry methods must converge on the same structured context and then the same Procedure task adapter.

The first Procedure implementation may begin with manual Display/Stage/Scene lookup and add the scan action after standalone Procedure presentation is accepted. The accepted scan platform already provides the permanent `display_id` contract when that integration is ready.

---

## First Engineering Acceptance Target

The first acceptance target should be deliberately narrow:

1. use current `main` as the source baseline;
2. inspect the current FieldWiring repository/resolver implementation before writing Procedure resolver code;
3. identify the minimum reusable structured-context interface rather than copying the algorithm into a second code path;
4. use the existing read-only `Display Folders` filesystem;
5. resolve one known Stage/Scene context from current PostgreSQL identity;
6. select `Procedures/Setup` instead of `Wiring/...`;
7. validate the Procedure markers;
8. enumerate the current PDF directly in that Setup folder;
9. serve/open that PDF through a protected `my.sheboyganlights.org` Procedure route;
10. prove `Archive` and `SourceDocs` cannot be served through normal Procedure endpoints;
11. prove FieldWiring remains unchanged by any shared-resolver refactor.

Do not begin this acceptance by designing scheduling, forklift state, load planning, Container movement transactions, a Procedure database registry, or a generic document-management system. Those are separate Setup/Deployment concerns.

---

## Conflict Resolution / Precedence

For Procedure resolver engineering, this handoff is the current starting-point authority when older documents appear to conflict.

Interpret older guidance as follows:

### Still valid

- Production Database owns durable Display/Stage/Scene identities and relationships.
- Google `Display Folders` owns human-maintained field documents.
- Stage/Sub-stage/Scene structure is authoritative.
- Procedure task folders and markers are application contracts.
- `Archive` and `SourceDocs` are excluded from normal field presentation.
- current published PDF/rendered documents are preferred field output.
- durable document identity may be added when publication/history requirements justify it.

### Superseded as an initial implementation prerequisite

- Procedure runtime must have a PostgreSQL row for every current PDF before it can find the PDF;
- every current Procedure PDF must first have a stored Google file/document ID before browser discovery is allowed;
- Procedures should build their own independent Display-to-Stage/Scene resolver;
- QR codes should encode Procedure paths or document URLs;
- a missing current Procedure document should trigger fuzzy filename search elsewhere in the Shared Drive.

---

## Documents the Procedure Thread Must Read First

1. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
2. `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md`
3. `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md`
4. `FieldWiring/Application/wiring_images.py`
5. `FieldWiring/Application/repository.py`
6. `Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md`
7. `Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md`
8. `System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md`
9. `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md`

If those documents contain older wording that appears inconsistent, preserve the ownership/marker/publication rules but follow this handoff for the initial resolver/runtime architecture.

---

## Stop Point

The Procedure subsystem may now begin engineering reconnaissance from the accepted FieldWiring/Scan production baseline.

Do not modify FieldWiring, PostgreSQL schema, the Google folder hierarchy, marker placement, or the production scan extension merely to start the Procedure proof of concept.

First reconstruct the reusable structured-context boundary and prove one read-only Setup lookup end-to-end.
