# Shared Field Context Hierarchy / Browse Repair Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | ARCHITECTURE ACCEPTED — production deployment pending |
| Branch | `agent/shared-field-context-hierarchy-browse-repair` |
| Base `main` | `340669b96b7da255d20700c9d9eddad92bb9c058` |
| Accepted candidate | `b1d897cf2b4d157ebf8a713c8dcc939726012df0` |
| Shared DB evidence source | `FieldWiring/Application/field_context_repository.py` |
| Existing structured-scope resolver | `FieldWiring/Application/field_context_resolver.py` |
| Canonical field-facing hierarchy entry point | `FieldWiring/Application/field_context_hierarchy.py` |
| Lower-level hierarchy builder | `FieldWiring/Application/field_context_browse.py` |
| Procedure status | paused until this repair is merged and production accepted |

## Governing authority

This repair is governed by the released Google Drive architecture, not by raw PostgreSQL or LOR naming:

- `Docs/00_Project_Overview/00-Google_Drive.md` Revision 1.3.1;
- `Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md`.

The required field hierarchy remains:

```text
Display Folders
  -> NN-Name-XY top-level Stage
      -> optional NNa-Name-XY Sub-stage
          -> optional defined NNa-Scene
      -> optional defined NN-Scene
```

This work does not redesign that hierarchy.

## Defect found

The production-accepted shared database context layer correctly separated permanent Display identity from FieldWiring eligibility, but its `stages()` output was still raw database/LOR evidence:

```text
all ref.stage rows
    +
all ref.lor_scene rows
    -> grouped by database stage
```

That raw evidence was incorrectly usable as though it were the field browse hierarchy.

The resulting defects included:

- `ref.stage.stage_name` appearing as a field-facing Stage label even when it was Preview/LOR-oriented;
- Sub-stages such as `05a` and `07a` appearing as peer/top-level Stage rows rather than nested physical scopes;
- every LOR Scene association being exposed as a possible child context;
- `Root` and Master Musical Stage-binding scenes creating duplicate choices even when they resolved to the Stage root;
- nonphysical `90–94` database stages being eligible to appear in browse;
- Stage `39/40` alignment conflicts being at risk of silent guessing.

## Audit evidence

The Procedure acceptance investigation produced `procedure_stage_scope_audit.csv` against the accepted SQLite snapshot plus the live `G:\Shared drives\Display Folders` tree.

The supplied audit contains 128 rows with these classifications:

```text
EXPLICIT_STAGE_ROOT                37
RAW_CONTEXT_RETURNS_STAGE_ROOT     36
UNRESOLVED_REVIEW_REQUIRED         29
DISTINCT_MARKED_CHILD_SCOPE        26
```

The audit demonstrates the central distinction required by this repair:

```text
raw LOR Scene association
    !=
automatic field/documentation Scene
```

Representative audit evidence:

- Stage `15`: `15-Church-CH` and `Root` resolve to `15-Church-Bells-CH` Stage root;
- Stage `13`: four prefixed marked child scopes resolve distinctly, while `13-Grover Train`, `Die Hard`, and `Static Contactor` return the Stage root;
- Stage `21`: `21-SnowballBears` resolves to a distinct marked child Scene, while `21-Sliding Penguins` and `Root` return the Stage root;
- Stage `05a`: actual marked Sub-stage is `05-Festive Trees-FT/05a-Mega Star-MS` even though the Stage row lacks a usable persisted `folder_path`;
- Stage `07a`: actual marked Sub-stage is `07-Whoville-WV/07a-Who Forest-WF` while the persisted path is stale/misaligned;
- Stage `39`: persisted Stage path points at `40-Parade Float-PF` and cannot be trusted for automatic browse binding;
- Stage `40`: current Stage row has no usable persisted folder anchor;
- Stages `90–94`: do not resolve to normal physical field roots.

## Accepted architecture

Database rows remain evidence. The field-facing hierarchy is created only after current filesystem roots have been resolved and validated.

Canonical caller chain:

```text
field_context_repository.stages()
    -> raw DB / LOR evidence only
    -> field_context_hierarchy.resolve_field_hierarchy(repository, drive_root)
        -> field_context_browse lower-level resolution/grouping
        -> field_context_resolver.resolve_structured_scope(...)
        -> current marked filesystem roots
        -> deduplicate by resolved root
        -> Stage -> Sub-stage -> defined Scene browse tree
        + review_required alignment findings
```

Applications must not present `repository.stages()` directly as the field hierarchy.

## Field-facing labels

The resolved current Google Drive scope basename is the field-facing label.

Examples:

```text
15-Church-Bells-CH
07-Whoville-WV
07a-Who Forest-WF
13-Winter Wonderland-WW
21-Polar Bear Playground-PB
25-Racing Arches-RA
```

`ref.stage.stage_name` remains database/LOR evidence and is returned only as supporting metadata. It is not field label authority.

## Stage rules

A normal top-level Stage browse node requires:

1. one actual marked top-level `NN-*` folder directly beneath `Display Folders`;
2. one corresponding current raw Stage row;
3. persisted top-level Stage path evidence that resolves back to that same current marked root.

If the top-level Stage path evidence is missing, stale, conflicting, or points at another Stage, the node is suppressed from normal browse and surfaced under `review_required`.

This rule is data-driven. No special-case code for Stage `39` or `40` is used.

## Sub-stage rules

A formal Sub-stage is an actual marked `NNa-*` child beneath its owning `NN-*` Stage.

A marked physical child relationship provides the additional ownership boundary required for nested browse. Therefore a stale or missing Sub-stage `folder_path` is surfaced for review but does not erase an otherwise unambiguous real nested scope.

This preserves current real cases such as:

```text
05-Festive Trees-FT
  -> 05a-Mega Star-MS

07-Whoville-WV
  -> 07a-Who Forest-WF
```

## Scene rules

A LOR Scene becomes a browse Scene only when the existing structured-scope resolver resolves it to one distinct marked child scope whose folder name has the owning Stage/Sub-stage prefix.

If the LOR Scene resolves to the owning Stage/Sub-stage root, it remains context/binding evidence on that root and does not create a duplicate child browse choice.

Therefore:

- `Root` never creates a duplicate browse Scene;
- `15-Church-CH` is Stage-root evidence, not a child Scene;
- `25-Racing Arches-RA` is Stage-root evidence, not a child Scene;
- `21-Sliding Penguins` is Stage-root evidence;
- `21-SnowballBears` is a distinct Scene;
- the four Stage 13 prefixed marked child scopes are distinct Scenes;
- unprefixed/raw LOR groups are not promoted merely because LOR calls them Scenes.

## Review output

Unresolved or conflicting evidence is preserved as structured `review_required` output rather than silently guessed.

Representative live review findings include:

```text
05a PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED
07a PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED
39  PERSISTED_STAGE_PATH_REVIEW_REQUIRED
39  TOP_LEVEL_STAGE_BINDING_REVIEW_REQUIRED
40  PERSISTED_STAGE_PATH_REVIEW_REQUIRED
40  TOP_LEVEL_STAGE_BINDING_REVIEW_REQUIRED
90–94 DATABASE_STAGE_NOT_IN_FIELD_HIERARCHY
```

The browse layer is therefore conservative while still exposing known real physical hierarchy.

## Synthetic regression gate

Final detached-worktree regression at candidate `b1d897cf2b4d157ebf8a713c8dcc939726012df0`:

```text
74 passed in 2.09s
```

The new tests cover:

- Stage-root deduplication;
- Stage/Sub-stage nesting;
- defined Scene creation from distinct marked child roots;
- rejection of raw/unprefixed LOR Scene groups as automatic field Scenes;
- top-level Stage path conflict suppression;
- top-level Stage missing-path suppression;
- preservation of valid nested Sub-stage browse despite reviewable persisted-path drift.

All previously accepted FieldWiring/shared-context tests remain green.

## Live production-data acceptance

The candidate was executed read-only against production PostgreSQL and `/mnt/msb-display-folders`.

Final result:

```text
normal Stage count: 27
review-required count: 36
normal Stage keys:
00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 18 19 20 21 22 23 24 25 26 30

SHARED FIELD HIERARCHY LIVE ACCEPTANCE: PASS
```

Representative live acceptance:

### Stage 15 Church

```text
label:      15-Church-Bells-CH
scope_root: /mnt/msb-display-folders/15-Church-Bells-CH
scenes:     []
root context count: 2
```

Master Musical/Root rows collapse to the Stage root.

### Stage 07 / 07a

```text
Stage:      07-Whoville-WV
Scenes:     07-Who People
            07-Who Spiral Tree
Sub-stage:  07a-Who Forest-WF
```

`07a` is nested rather than top-level.

### Stage 13

Only the four current defined marked child Scene scopes are exposed:

```text
13-Christmas Story
13-Christmas Vacation
13-Christmas With the Kranks
13-Nightmare Before Christmas
```

Raw LOR groups that return the Stage root do not appear as child Scenes.

### Stage 21

```text
Scene: 21-SnowballBears
```

`21-Sliding Penguins` collapses to Stage root.

### Stage 25

`25-Racing Arches-RA` remains one Stage browse node; its same-name Master Musical Scene does not duplicate it.

### Stage 39 / 40

Both are excluded from normal browse and surfaced for review because current persisted path evidence is not safe enough to bind automatically.

### Stages 90–94

None appear in normal physical browse.

## Identity and FieldWiring preservation

Permanent Display identity behavior is unchanged.

Real inventory-only Display `807` remains valid shared context:

```text
807  RA-SteelArch-DS-F-03
Stage 25
shared search includes 807
FieldWiring search excludes 807
direct FieldWiring -> No applicable field wiring is available for this Display
```

Normal wired Display `312` candidate output remained exactly equivalent to the unchanged production FieldWiring API:

```text
scope_type: STAGE
scope_root: /mnt/msb-display-folders/15-Church-Bells-CH
wiring_images: RGB Plus Prop Stage 15 Church-Tagged.jpg
```

## Runtime characteristic

Building the hierarchy touches the live read-only Google/rclone tree and is materially slower than returning raw PostgreSQL rows. This is expected because filesystem structure is part of the authoritative field-browse contract.

Consumers may later cache or refresh the resolved browse result at an appropriate boundary, but performance work must not replace resolved filesystem authority with raw database rows or weaken review/ambiguity handling.

No caching design is introduced by this repair.

## Scope preserved

This repair does not:

- modify Procedures;
- widen FieldWiring search;
- change permanent `display_id` resolution;
- remove inventory-only Display support;
- change FieldWiring eligibility filters;
- modify `field_context_resolver.resolve_structured_scope(...)`;
- create PostgreSQL schema, migrations, functions, or data changes;
- rename or move Google Drive folders;
- infer new hierarchy rules outside the released Google Drive documents.

## Acceptance decision

The repaired shared field hierarchy is architecture accepted because it now represents the actual released Google Drive field hierarchy rather than raw LOR/database association rows, preserves all established identity and FieldWiring behavior, and surfaces unsafe alignment conditions instead of guessing.

Production deployment remains a separate gate.

After merge and production acceptance, the Procedure branch may resume by merging current `main` into `feature/setup-takedown-procedures` and replacing raw Stage browse consumption with the canonical resolved hierarchy entry point.
