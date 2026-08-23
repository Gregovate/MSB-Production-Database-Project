# Shared Field Context Path-Contract Recovery — 2026-08-23

| Document control | Value |
|---|---|
| Status | **ENGINEERING RECOVERY — runtime contract correction** |
| Branch | `agent/shared-field-context-path-contract-recovery` |
| Governing filesystem contract | `Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md` |
| Shared context contract | `Field_Context_Resolution_Contract.md` |
| FieldWiring resolver design | `../09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md` |
| Procedure status | Frozen at the reverted green baseline until shared recovery is accepted |

## Why this recovery exists

The earlier shared-hierarchy implementation correctly recognized that raw `ref.stage` and raw LOR Scene rows could not simply be rendered as the field hierarchy. However, it solved that problem by enumerating the mounted `Display Folders` tree and rebuilding the Stage/Sub-stage/Scene hierarchy at application request time.

That runtime behavior is **superseded by this recovery** because it conflicts with the pre-existing governing path-resolution documents and produced unacceptable field-browser latency.

The governing documents already established the intended runtime behavior:

```text
current Production Database identity / relationships
        +
current LOR BackgroundFile/path evidence
        |
        v
walk the supplied path upward only as needed
        |
        v
nearest valid Stage / Sub-stage / Scene scope
        |
        v
task adapter selects its own fixed relative branch
```

The resolver must not rediscover the entire park hierarchy from Google Drive during a normal phone/tablet/desktop request.

## Authority boundary

The following rules are now explicit engineering gates.

1. `Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md` owns filesystem/path interpretation.
2. `Field_Context_Resolution_Contract.md` owns the shared identity/context boundary.
3. `FieldWiring_Drive_Context_Resolver_Engineering_Design.md` owns FieldWiring-specific resolver behavior.
4. A lower-level acceptance document or implementation must not introduce a competing runtime traversal model without an explicit architecture review.

## Shared runtime responsibilities

### Shared database/context repository

`FieldWiring/Application/field_context_repository.py`

Owns current read-only Production Database facts:

- permanent Display identity;
- current Stage/Sub-stage relationship;
- current Scene membership;
- current Preview identity/context;
- current stored BackgroundFile/path evidence.

### Shared lookup hierarchy

`FieldWiring/Application/field_context_hierarchy.py`

Owns the fast common lookup/browse presentation model.

It is built only from already-reconciled database/LOR facts and stored path **strings**. It performs no Google Drive enumeration.

Its purpose is to give FieldWiring, Procedures, and future field applications the same Stage/Sub-stage/Scene navigation model.

### Shared structured-scope resolver

`FieldWiring/Application/field_context_resolver.py`

Owns resolution of one selected context to one structured filesystem root.

It must:

1. start from the supplied current Stage/Scene/Preview facts;
2. use Scene `BackgroundFile` first when present, otherwise allowed Preview path evidence;
3. treat the pointer as navigation evidence, not task content identity;
4. stop before `SourceDocs`;
5. walk upward through that supplied path;
6. ignore helper folders and unprefixed Display/group folders while walking upward;
7. return the nearest valid marked Scene, Sub-stage, or Stage root;
8. fall back upward to the owning Stage when a more-specific Scene scope is not present;
9. use only bounded stale-pointer recovery inside the already-known Stage when exact evidence no longer resolves;
10. never enumerate `Display Folders` to discover candidate Stages.

### Task adapters

After the shared root is fixed, the task adapter alone chooses content:

```text
FieldWiring
    -> <scope>\Wiring\BackgroundStage
    -> <scope>\Wiring\MusicalStage

Procedures
    -> <scope>\Procedures\Setup
    -> <scope>\Procedures\Takedown
    -> <scope>\Procedures\Inspection
```

Changing task does not change the resolved physical scope.

## Background ownership is not documentation ownership

The governing worked examples remain authoritative.

A BackgroundFile may point to:

- a Stage `PreviewBackground`;
- a Scene `PreviewBackground`;
- a Display-specific `PreviewBackground` beneath a Scene;
- a Display-specific `PreviewBackground` directly beneath a Stage;
- `Wiring\BackgroundStage`;
- `Wiring\MusicalStage`;
- or another allowed current/legacy location within the owning Stage.

The resolver climbs through that existing path until it reaches the applicable structured documentation owner.

Example:

```text
21-Polar Bear Playground-PB
  -> 21-Sliding Penguins
      -> PB-SlidingPenguins-07
          -> PreviewBackground\Penguin-07.jpg
```

The background owner is the Display folder, but the shared documentation owner is `21-Sliding Penguins`.

If the same Display is directly beneath the Stage with no defined Scene, the resolver climbs to `21-Polar Bear Playground-PB`.

## Runtime browse vs engineering validation

`FieldWiring/Application/field_context_browse.py` may remain useful as a **read-only engineering/alignment validator** that compares database/path evidence with the actual mounted Drive tree.

It is not the normal runtime source for `/api/stages` or equivalent shared field lookup.

This distinction supersedes the runtime-crawler portions of:

`Shared_Field_Context_Hierarchy_Browse_Repair_Acceptance_2026-08-23.md`

The historical acceptance record remains valuable evidence of the issue that was found, but its statement that normal browse should rebuild the hierarchy by walking the mounted Drive is no longer the runtime contract.

## Regression gate

The documented worked path examples are being converted into executable tests.

Required regression cases include:

- Stage-level `PreviewBackground` -> Stage;
- Scene-level `PreviewBackground` -> Scene;
- Display-level `PreviewBackground` beneath a Scene -> climb to Scene;
- Display-level `PreviewBackground` directly beneath a Stage -> climb to Stage;
- direct Stage Wiring path -> Stage;
- direct Scene Wiring path -> Scene;
- formal Sub-stage path -> Sub-stage;
- `Root` -> owning Stage, never a literal child;
- Master Musical Stage-binding Scene -> Stage, not a fake child Scene;
- nested legacy Scene proven by exact path -> Scene;
- `SourceDocs` -> hard traversal boundary;
- stale pointer -> bounded recovery inside the known Stage only;
- unprefixed Display/group folder -> never promoted to Scene merely from its folder name;
- runtime lookup hierarchy -> must succeed even when the supplied `drive_root` object would fail if accessed.

## No schema change authorized by this recovery

This recovery does not currently authorize:

- parser changes;
- new PostgreSQL schema objects;
- rewriting LOR paths;
- moving/renaming Google Drive folders;
- Procedure application changes;
- production deployment.

The immediate objective is to restore the already-documented shared context boundaries and prove them with regression tests before application integration resumes.
