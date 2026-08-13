# LOR Preview Version Compatibility Review

| Document control | Value |
|---|---|
| Status | CURRENT — controlled engineering procedure |
| Applies to | Any new Light-O-Rama release that can change `.lorprev` output |
| Current revision | 2026-08-13 |
| Owner | MSB Database Administrator |

## Purpose

This procedure defines how to evaluate a new Light-O-Rama version before its preview files are allowed into the production parsing and LOR2DB workflow.

The objective is to determine whether the new `.lorprev` structure remains compatible with the current parser, identify any parser or downstream changes required, and preserve a documented compatibility decision.

Do not assume compatibility because the new version opens existing previews or because the current parser completes without an exception.

## Required Engineering References

Use these documents together:

- [LOR Preview File Structure Specification](LOR_Preview_File_Structure_Specification.md)
- [LOR Preview Parser Architecture](LOR_Preview_Parser_Architecture.md)

The file-structure specification describes what the parser expects from `.lorprev` XML.

The parser architecture describes how the MSB parser interprets and materializes that structure.

## Production Boundary

Compatibility testing must be isolated from production.

Do not:

- replace the approved production preview source;
- run the production PostgreSQL ingest using an unapproved new-version snapshot;
- change production reconciliation procedures merely to accommodate an unverified parser result;
- overwrite the known-good LOR baseline previews;
- update the current parser in place before the comparison is complete.

Use copied test files and a separate test output database.

## Operator Version Record

LOR2DB maintains two explicit fields:

- **Current LOR version** — the approved production version of record;
- **New LOR version** — the candidate being evaluated.

The approved record identifies the versioned preview folder, for example
`Database Previews V6.6.4`. A candidate such as 6.6.10 uses `Database Previews
V6.6.10`. Approval changes the record; it does not rename or delete the
previous versioned folder.

## Mandatory Automated Gate

`Parser/lor_version_checker.py` inventories the complete XML independently of
the parser. It scans every `.lorprev` file and compares:

- every element/local name and namespace;
- every element path, parent/child edge, and sibling-order transition;
- every PreviewClass, Scene, and PropClass attribute, including fields the
  parser does not consume;
- observed value shapes;
- ChannelGrid record boundaries, token counts, and every positional value;
- record boundaries, token counts, and positional value shapes for every other
  comma/semicolon-encoded XML field, including non-descript PropClass fields;
- raw PreviewClass, Scene, and PropClass ID/count changes in every preview; and
- focused identity/position review in the selected deep preview.

Any added/removed structure, attribute, value shape, ordering contract, or
ChannelGrid position is blocking until it is explicitly reviewed. A failed
report records `parser_modifications_required`. Candidate parser testing may
then prove the required code changes; approval remains blocked until every
finding is explicitly recorded as resolved.

The XML check occurs before the parser. A successful parser run cannot override
a failed XML compatibility check.

## Test Preview Selection

Use the entire versioned preview folder for the complete structural scan. For
the focused manual per-record identity and positional review, use one
comprehensive preview rather than manually inspecting all production previews.
The automated positional inventory and critical ID/count scan still cover every
file.

For the 6.6.4 baseline, the selected deep preview is:

`2026 Master Musical Preview v6.6 2026-07-30.lorprev`

It exercises all observed six-position ChannelGrid record layouts, multiple
Scenes, LOR/DMX/None props, manual relationships, multi-grid props, tags, and
parameter fields. The complete scan of all 33 files remains mandatory because
other previews expose additional attributes and higher Parm positions.

## Preferred Logical Comparison

The strongest content comparison additionally uses the same logical preview
exported from both versions of Light-O-Rama. It supplements the complete-folder
contract scan; it does not replace it.

Example:

```text
Known-good LOR version
    -> export representative baseline.lorprev

New LOR version
    -> open same logical preview
    -> export representative_new.lorprev
```

This minimizes differences caused by normal authoring edits and makes XML structural changes easier to identify.

## Minimum Representative Preview Content

The test preview should exercise every parser-sensitive feature available in the production environment, including:

- standard single-grid LOR props;
- multi-grid LOR props with `IndividualChannels=True`;
- multi-grid one-plug props;
- manually related `MasterPropId` props/subprops;
- SPARE channel definitions;
- DMX props with representative universes/channels;
- `DeviceType=None` physical inventory;
- `DeviceType=None` fan-out behavior;
- blank-comment layout helpers;
- preview-level Scenes;
- multiple Scenes in one preview;
- a Scene without a normal stage assignment;
- sub-stage naming such as `07a`;
- Show Animation naming;
- background image references;
- tags;
- representative `Parm1` through `Parm8` values;
- copied or duplicated props where UUID behavior can be observed.

A single ordinary prop is not sufficient to prove compatibility.

## Phase 1 — Preserve the Known-Good Baseline

Before opening or exporting anything with the new Light-O-Rama version:

1. Preserve the existing known-good `.lorprev` file used for comparison.
2. Record the Light-O-Rama version that created it.
3. Record the current parser version.
4. Preserve the current parser output database and parser summary for the baseline if available.
5. Do not modify the baseline file during the review.

The comparison must always be reproducible.

## Phase 2 — Export the New-Version Preview

Using the new Light-O-Rama release:

1. Open the representative test preview.
2. Do not intentionally redesign or rename props during the format comparison.
3. Export the preview to a separate test location.
4. Record the exact Light-O-Rama version.
5. Record the filename and export date.

If Light-O-Rama automatically upgrades or rewrites the preview when opening it, record that behavior as part of the compatibility evidence.

## Phase 3 — Compare Raw `.lorprev` Structure

Compare the known-good and new-version XML before running the parser.

Review at least the following areas.

### Document and namespace structure

Check:

- XML declaration and encoding;
- root element;
- namespace declarations;
- namespace-qualified tag changes;
- document ordering.

A namespace change alone may be harmless because the parser matches important tags by suffix, but it must still be documented.

### PreviewClass

Compare:

- element name and location;
- `id`;
- `Name`;
- `Revision`;
- `Brightness`;
- `BackgroundFile`;
- any new or removed attributes.

### Scene

Compare:

- Scene element name;
- Scene `id` behavior;
- Scene `Name`;
- background metadata;
- HScroll/VScroll/Zoom;
- CreateGridView;
- element ordering;
- relationship to following PropClass rows.

Determine whether Scene membership is still positionally recoverable using the current parser rule.

Do not equate raw `<Scene>` count with operational true Scenes. Preserve all
raw rows for compatibility, while Folder Alignment separately classifies
`NN-Name-XY` Stage roots, `NNa-Name-XY` Sub-stage roots, prefixed true Scenes,
`Root` markers, and unprefixed Display/group locators.

### PropClass

Compare:

- `id`;
- `Name`;
- `Comment`;
- `DeviceType`;
- `MasterPropId`;
- `IndividualChannels`;
- `MaxChannels`;
- `ChannelGrid`;
- tags;
- parameter fields;
- any new or removed fields.

### ChannelGrid

This is a high-risk area.

Compare the raw serialization of equivalent LOR and DMX examples. Verify that network, UID/universe, start channel, end channel, color, and leg separation remain interpretable by the current parser.

### Identity behavior

Specifically compare UUID behavior for:

- unchanged props;
- copied props;
- manual subprops;
- multi-grid props;
- `DeviceType=None` inventory;
- Scene membership rows.

A change in UUID generation or reuse can affect both parser relational identity and downstream reconciliation.

## Phase 4 — Create a Structural Difference Inventory

Record every observed change, not only changes that appear dangerous.

Use a table like this:

| Area | Baseline | New version | Difference | Parser impact | Severity |
|---|---|---|---|---|---|
| PreviewClass | | | | | |
| Scene | | | | | |
| PropClass | | | | | |
| ChannelGrid | | | | | |
| DeviceType | | | | | |
| MasterPropId | | | | | |
| Identity behavior | | | | | |

Recommended severity meanings:

- **NONE** — structural change with no parser dependency;
- **LOW** — parser ignores change and existing meaning is preserved;
- **MEDIUM** — parser behavior may need additional validation;
- **HIGH** — current parser can misread or omit data;
- **BLOCKING** — new version must not enter production without parser or contract changes.

## Phase 5 — Review Against Parser Architecture

For every difference, determine whether it affects one or more current parser contracts:

- PreviewClass discovery;
- StageID extraction;
- Display Name / Channel Name mapping;
- raw PropClass identity;
- preview-scoped parser identity;
- LOR prop materialization;
- manual subprop handling;
- multi-grid handling;
- DMX handling;
- DeviceType=None fan-out;
- Scene metadata;
- positional Scene membership;
- Scene membership resolution;
- SQLite schema;
- wiring views;
- parser provenance;
- fail-fast validation.

Do not modify parser code during this phase. First establish the complete impact.

## Phase 6 — Run the Current Parser in Isolation

Only after the raw XML comparison is documented should the current parser be tested against the copied new-version previews.

Use the website's candidate parser action. It runs with `VERSION_CHECK` mode and
writes a separate test SQLite database under the candidate evidence folder.

Record:

- parser version;
- source folder;
- number of preview files discovered;
- parser warnings/errors;
- row counts;
- collision reports;
- raw LOR Scene-row counts (not operational true-Scene counts);
- Scene membership counts;
- unassigned or unresolved rows;
- parser completion status.

A successful process exit is not sufficient acceptance evidence.

## Phase 7 — Compare Parser Outputs

Compare the known-good and new-version SQLite results for equivalent previews.

Review at least:

- `previews`;
- `props`;
- `subProps`;
- `dmxChannels`;
- `scenes`;
- `scene_lor_props`;
- wiring/report views;
- parser-run provenance.

Compare both schema and content.

Expected differences caused only by the LOR version should be distinguishable from unintended parser differences.

## Phase 8 — Determine Downstream Impact

For every parser-output difference determine whether changes are required in:

1. the parser;
2. SQLite schema or compatibility views;
3. LOR2DB PostgreSQL ingest;
4. `lor_snap` PostgreSQL schema;
5. LOR2DB reconciliation;
6. FormView;
7. wiring/reporting systems;
8. documentation.

Do not change reconciliation to compensate for a parser defect. Correct the problem at the earliest responsible system boundary.

## Phase 9 — Regression Validation

If parser changes are required, validate the modified parser against both the known-good baseline and the new LOR release.

At minimum verify:

- existing known-good previews still parse;
- no unintended row-count changes;
- no lost props or subprops;
- DMX wiring remains correct;
- DeviceType=None materialization remains correct;
- RawPropID and scoped identity remain correct;
- Scene counts remain correct;
- Scene membership remains correct;
- no unresolved nonblank Scene rows;
- collision audits remain clean or explainable;
- wiring/report views remain compatible;
- FormView-required compatibility views still function;
- PostgreSQL ingest completes in an isolated/test workflow;
- reconciliation input contract remains intact.

Backward compatibility with the known-good baseline should be preserved unless an intentional breaking change is separately approved.

## Phase 10 — Compatibility Decision

Record one of these outcomes:

### COMPATIBLE — NO PARSER CHANGE

Use when the raw structure and parser-output validation demonstrate that the current parser remains safe.

### COMPATIBLE — PARSER UPDATE REQUIRED

Use when the new format is supported after controlled parser changes and regression validation.

### NOT COMPATIBLE / BLOCKED

Use when the new version cannot safely enter the production workflow yet.

The decision record should identify:

- old LOR version;
- new LOR version;
- parser version tested;
- test files;
- differences found;
- code changes, if any;
- downstream changes, if any;
- validation evidence;
- final approval.

Approval is permitted only when the candidate parser run is `COMPLETE` with
`ValidationStatus=PASSED` and either the XML report is `PASSED` or every failed
finding has a recorded engineering resolution tied to that parser version.
Unresolved findings remain attached to and block the candidate.

## Standard ChatGPT Compatibility Review Prompt

Use the following prompt when a representative preview exported by a new Light-O-Rama version is uploaded for review.

If possible, upload both:

- the known-good baseline `.lorprev` exported by the currently approved LOR version;
- the equivalent `.lorprev` exported by the new LOR version.

Also provide the LOR version numbers if they are not obvious from the files.

```text
MSB LOR Preview Compatibility Review

Review the attached Light-O-Rama .lorprev files as an engineering compatibility test.

Use the current repository versions of:

Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_File_Structure_Specification.md
Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md
Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py

as the current MSB baseline.

The older preview file is the known-good baseline. The newer preview file was exported by the new Light-O-Rama version being evaluated.

Do not assume compatibility and do not recommend code changes until the structural review is complete.

First compare the raw .lorprev XML and identify every meaningful difference, including:

- XML declaration and namespaces
- root/document hierarchy
- PreviewClass structure and attributes
- Scene structure and attributes
- Scene ordering and positional membership behavior
- PropClass structure and attributes
- PropClass id/UUID behavior
- Name and Comment behavior
- DeviceType values
- MasterPropId behavior
- IndividualChannels behavior
- ChannelGrid serialization
- LOR network/controller/channel data
- DMX universe/channel data
- DeviceType=None structures
- background image references
- tags and Parm fields
- added elements or attributes
- removed elements or attributes
- renamed elements or attributes
- changed nesting or ordering

Do not ignore a new element merely because the current parser does not consume it. Determine whether it changes the meaning or location of data the parser does consume.

Then compare every difference against the current V7 parser architecture.

For each difference answer:

1. Does the current parser depend on this structure or value?
2. Will the current parser still read it correctly?
3. Could the current parser silently omit or misinterpret data while still completing successfully?
4. Is parser modification required?
5. Is the SQLite schema or compatibility-view contract affected?
6. Is LOR2DB PostgreSQL ingest affected?
7. Is the lor_snap PostgreSQL contract affected?
8. Is LOR2DB reconciliation affected?
9. Is FormView or wiring/reporting compatibility affected?
10. Which engineering documentation must be updated?

Give each difference a severity of NONE, LOW, MEDIUM, HIGH, or BLOCKING.

Produce these outputs in order:

A. Executive compatibility conclusion
B. Raw XML structural difference table
C. Parser-impact table
D. Identity-risk review
E. Scene-architecture review
F. Wiring/ChannelGrid/DMX review
G. Downstream-system impact review
H. Required regression tests
I. Final recommendation: COMPATIBLE — NO PARSER CHANGE, COMPATIBLE — PARSER UPDATE REQUIRED, or NOT COMPATIBLE / BLOCKED

If the supplied files do not exercise an important parser-sensitive feature, explicitly identify the missing test coverage rather than assuming that feature is compatible.

Do not modify production code, production documentation, or production paths during the review. Complete the engineering comparison first.
```

## After the Review

If the new LOR version is approved:

1. update the file-structure specification with confirmed format changes;
2. update the parser architecture if parser behavior changed;
3. update the parser changelog/version when code changed;
4. update ingest or downstream documentation only where the contract actually changed;
5. retain the comparison evidence for future LOR upgrades;
6. update the approved LOR baseline only after the production transition is intentionally authorized.

## Current Pending Review

Light-O-Rama 6.6.10 is the next candidate. It must be exported into `Database
Previews V6.6.10` and reviewed through the website checker/parser gates before
replacing the approved 6.6.4 version record.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-13 | GAL / OpenAI | Added Current/New version records, complete all-preview XML manifests, the selected deep preview, blocking modification records/resolution, and website approval gates for the 6.6.10 review. |
| 2026-08-08 | GAL / OpenAI | Created controlled LOR-version compatibility review procedure, regression checklist, decision model, and reusable ChatGPT engineering comparison prompt. |
