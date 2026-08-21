# FieldWiring PostgreSQL DMX Propagation Change Map — 2026-08-21

| Item | Value |
|---|---|
| Status | DESIGN REVIEW — NO POSTGRESQL / INGEST / BROWSER CHANGE AUTHORIZED |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Parser source | V7.0.11 accepted SQLite DMX source detail |
| Current production PostgreSQL | Run 50 / parser V7.0.10 / ingest V0.4.1 |
| Purpose | Define the exact additive path from accepted V7.0.11 DMX source rows into PostgreSQL and the FieldWiring browser without changing FormView compatibility contracts |

## Purpose

This document is the controlled implementation map for the next FieldWiring data-boundary step after parser V7.0.11 real-snapshot acceptance.

It does **not** authorize a production migration, ingest change, FieldWiring renderer change, or merge to `main`.

The required path is:

```text
LOR .lorprev
    -> parser V7.0.11 SQLite dmxChannels
        -> PostgreSQL lor_snap.dmx_channels
            -> lor_snap.v_current_dmx_channels
                -> FieldWiring-specific DMX read contract
                    -> device-family presentation
                        -> E1.31 dense RGB
                        -> DMX / DumbRGB / CR50
```

The existing FormView / compatibility view path remains intact beside it.

## Evidence Already Accepted

### Parser V7.0.11

V7.0.11 appends these fields to SQLite `dmxChannels`:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

Their controlled meanings are:

```text
RawPropID
    = originating LOR Prop ID (`PropClass.id`) that supplied the DMX Channel Grid Row

ChannelName
    = originating LOR Channel Name (`PropClass.Name`)

ChannelGridRowNumber
    = 1-based source Channel Grid position local to that PropClass
```

The existing SQLite `PropId` remains the canonical/materialized Display master parser identity.

### Real-snapshot acceptance

V7.0.11 successfully parsed the current corrected 33-preview LOR 6.6.10 acceptance set in `VERSION_CHECK` mode.

Accepted results include:

```text
parser version           V7.0.11
validation               PASSED
previews                 33
dmxChannels rows         508
new DMX fields           populated on accepted rows
```

A V7.0.10 parser was then run against the **same copied 33 Preview files**. The same-input legacy regression comparison passed:

```text
REGRESSION ACCEPTANCE: PASS
```

The comparison proved that the V7.0.11 change did not alter the legacy authoritative table content, old eight DMX field values, or legacy wiring-view rows/shapes.

### Dense RGB evidence

Mega Star proves the source-preservation need directly. The accepted V7.0.11 rows retain one canonical Display master while separately preserving Channel Names such as:

```text
MS Long Spire 1 4x150
MS Long Spire 2 4x150
MS Long Spire 3 4x150
MS Short Spire 1 2x150
MS Center Hub Front
MS Center Hub Back
```

with their own `RawPropID` and local `ChannelGridRowNumber` values.

Mega Tree and Mega Ball also preserve the expected explicit universe/channel rows.

Mega Cube and Mt. Crumpit / Who Matrix still expose the separately documented compact-ChannelGrid limitation. The PostgreSQL propagation in this document must **not** fabricate missing compact rows or combine that later parser change into this work.

### CR50 / Northern Lights evidence

The accepted V7.0.11 Northern Lights data proves that each physical CR50 fixture is represented by **three one-channel DMX source rows**, one per RGB control channel.

Example:

```text
NL-DS-01
    Grid Row 1 -> U145 channel 1
    Grid Row 2 -> U145 channel 2
    Grid Row 3 -> U145 channel 3

NL-DS-02
    Grid Row 1 -> U145 channel 6
    Grid Row 2 -> U145 channel 7
    Grid Row 3 -> U145 channel 8
```

The two-channel gaps are intentional because the CR50 is physically a five-channel DMX fixture and MSB excludes the two non-RGB fixture-function channels from the LOR Channel Grid.

The accepted Northern Lights set contains:

```text
NL-DS-01 through NL-DS-32 -> Universe 145
NL-PS-01 through NL-PS-34 -> Universe 146
```

or 66 physical CR50 fixture contexts represented by 198 RGB source rows.

## Live PostgreSQL Verification — 2026-08-21

Read-only production inspection confirmed:

```text
import_run_id             50
parser_version            V7.0.10
ingest_script_version     V0.4.1
current DMX rows          508
```

### Current `lor_snap.dmx_channels`

The deployed table currently contains:

```text
import_run_id
int_dmx_channel_id
prop_id
network
start_universe
start_channel
end_channel
unknown
preview_id
```

It does not contain the V7.0.11 source-detail fields.

### Current `lor_snap.v_current_dmx_channels`

The deployed view explicitly projects the legacy columns. It does **not** use `SELECT *`.

Therefore table-column additions alone would not make the new fields visible through the current-snapshot interface.

### Current legacy wiring views

`lor_snap.preview_wiring_map_v6` and downstream `preview_wiring_*_v6` objects remain the FormView-compatible surface.

The DMX branch intentionally joins the canonical `dc.prop_id` to the canonical current Prop and exposes the canonical master Prop Channel Name.

That behavior is now known to be insufficient for grouped-DMX FieldWiring detail, but it is still the accepted compatibility behavior and must remain unchanged during this propagation.

## Additive PostgreSQL Snapshot Columns

The approved design is to append these nullable columns to `lor_snap.dmx_channels`:

```text
raw_prop_id             TEXT
channel_name            TEXT
channel_grid_row_number INTEGER
```

### Why nullable

Historical snapshots were ingested before parser V7.0.11 and legitimately do not contain these values.

Do not backfill historical snapshots from guesses or current data.

New V7.0.11 snapshots must carry complete values according to the ingest safety contract below.

### Column meaning

| PostgreSQL field | SQLite source | Meaning |
|---|---|---|
| `raw_prop_id` | `RawPropID` | LOR Prop ID of the source PropClass that supplied this DMX row |
| `channel_name` | `ChannelName` | LOR Channel Name of that source PropClass |
| `channel_grid_row_number` | `ChannelGridRowNumber` | local source Channel Grid row position within that PropClass |

### No new source-Prop foreign key

Do **not** add a foreign key from `lor_snap.dmx_channels.raw_prop_id` to `lor_snap.props`.

Grouped DMX source PropClasses can supply wiring rows without becoming separate physical Display rows in `lor_snap.props`.

The existing foreign key remains:

```text
(import_run_id, prop_id)
    -> lor_snap.props(import_run_id, prop_id)
```

and continues to represent the canonical Display/master relationship.

## Current-Snapshot View Change

`lor_snap.v_current_dmx_channels` must explicitly append:

```text
raw_prop_id
channel_name
channel_grid_row_number
```

while preserving every existing column name, order, and meaning first.

Conceptual shape:

```text
import_run_id
int_dmx_channel_id
prop_id
network
start_universe
start_channel
end_channel
unknown
preview_id
raw_prop_id
channel_name
channel_grid_row_number
```

The current-run join logic remains unchanged.

Historical current-run behavior is naturally nullable if an older snapshot is selected during recovery or rollback.

## Ingest Change — Fail Closed

Current ingest already maps SQLite and PostgreSQL columns by normalized name, so the three new columns do not require positional mapping logic.

However, relying only on the generic mapper is unsafe because a stale PostgreSQL schema could silently omit the new fields.

The ingest contract must therefore be extended with an explicit DMX source-detail schema gate.

### Required source schema for V7.0.11+

SQLite table `dmxChannels` must contain:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

### Required target schema

PostgreSQL table `lor_snap.dmx_channels` must contain:

```text
raw_prop_id
channel_name
channel_grid_row_number
```

### Required source-value completeness

For a V7.0.11+ production parser snapshot, every materialized `dmxChannels` row must have:

```text
RawPropID              nonblank
ChannelName            nonblank
ChannelGridRowNumber   non-null and >= 1
```

If that contract is not met, ingest must fail **before** creating a new `import_run`.

### Required target-value completeness

After inserting a V7.0.11+ snapshot but before commit, the ingest must verify that every `lor_snap.dmx_channels` row for the new `import_run_id` has:

```text
raw_prop_id              nonblank
channel_name              nonblank
channel_grid_row_number   non-null and >= 1
```

Failure must roll back the entire snapshot transaction.

### Parser-version boundary

The ingest must not retroactively require these fields from historical V7.0.10-or-earlier artifacts.

The implementation should explicitly gate the new requirement on parser capability/version rather than assuming every historical SQLite artifact has the extended schema.

Exact version-comparison implementation belongs in the reviewed ingest change, but the behavioral rule is fixed here.

## Ingest Tests Required

The existing ingest safety tests must be extended to cover at least:

1. V7.0.11 source and target schema present -> contract passes;
2. V7.0.11 SQLite missing one of the three source fields -> fail before `import_run` creation;
3. V7.0.11 PostgreSQL target missing one of the three columns -> fail before `import_run` creation;
4. V7.0.11 source row has blank `RawPropID` -> fail;
5. V7.0.11 source row has blank `ChannelName` -> fail;
6. V7.0.11 source row has null/invalid `ChannelGridRowNumber` -> fail;
7. post-insert target values are incomplete -> transaction fails/rolls back;
8. historical parser artifacts remain compatible with their historical schema rules;
9. existing reviewed-SQLite SHA-256 authority gate remains unchanged;
10. existing production-run / validation-status gate remains unchanged.

## Compatibility Views — No Change

Do not change these objects as part of the first PostgreSQL propagation:

```text
lor_snap.preview_wiring_map_v6
lor_snap.preview_wiring_sorted_v6
lor_snap.preview_wiring_fieldmap_v6
lor_snap.preview_wiring_fieldlead_v6
lor_snap.preview_wiring_circuit_rollup_v6
lor_snap.preview_wiring_fieldonly_v6
```

Reasons:

- FormView compatibility remains an active fallback requirement;
- same-input V7.0.10/V7.0.11 acceptance proved these view shapes/rows remain stable;
- changing their DMX Channel Name meaning would mix source-preservation work with a compatibility-contract change;
- FieldWiring needs a richer, identity-aware read contract anyway.

The new FieldWiring DMX/E1.31 path must be additive beside these views.

## Permanent Display Identity Path

The permanent Display relationship remains:

```text
lor_snap.v_current_dmx_channels dc
    dc.prop_id
        -> lor_snap.v_current_props p.prop_id
            -> p.raw_prop_id
                -> ref.display.lor_prop_id
                    -> ref.display.display_id
```

This identifies the physical Production Database Display.

The source wiring provenance remains separate:

```text
dc.raw_prop_id
dc.channel_name
dc.channel_grid_row_number
```

Do not use `dc.raw_prop_id` as the permanent Display binding for grouped DMX.

## FieldWiring-Specific DMX Read Contract

FieldWiring needs an additive read surface over current authoritative objects. It may be implemented as a database view or as an equivalent read-only query/API contract, but it must not become an independent topology store.

The minimum atomic DMX relationship contract is:

```text
import_run_id
preview_uuid
preview_name
preview_revision
scene_uuid / scene_name when applicable
stage_id / stage_key / stage_name

display_id
display_name
canonical_prop_id
canonical_raw_prop_id

source_raw_prop_id
channel_name
channel_grid_row_number

network
universe
start_channel
end_channel
unknown

device_type
string_type
source = DMX
```

`unknown` remains engineering/source data and is not reinterpreted by this propagation.

### Grain

The atomic grain is one materialized V7.0.11 DMX Channel Grid Row.

Do not pre-collapse E1.31 rows or CR50 rows inside the snapshot table.

Presentation-family aggregation happens after the authoritative atomic rows are selected for the resolved Stage/Preview/Scene package.

## Scene / Stage Scope

The FieldWiring read path must continue to use the resolved permanent Display / Preview / Scene relationships already used by the browser package.

It must not resolve a scanned Display into DMX rows solely by Display Name text.

Display Name remains human-facing.

The controlled route is:

```text
permanent display_id
    -> reconciled LOR identity / Scene membership
        -> current Preview/Scene package
            -> canonical Display's current DMX rows
```

Within grouped DMX, the canonical Display binding selects the Display while the new source fields preserve the individual LOR section/channel detail.

## E1.31 Presentation Contract

For reviewed `device_type = DMX` + `string_type = RGB` cases, the normal technician table is grouped by physical controller and uses:

```text
OUTPUT / PORT
CHANNEL / DISPLAY SECTION
UNIVERSE
PIXELS
CHANNEL RANGE
```

The atomic PostgreSQL row supplies:

```text
Channel / section = dc.channel_name
Universe          = dc.start_universe
Channel range     = dc.start_channel - dc.end_channel
```

Pixel count is derived only when the RGB channel span is valid and divisible by three:

```text
channel_count = end_channel - start_channel + 1
pixel_count   = channel_count / 3
```

Do not store the derived pixel count as a replacement for source addressing.

Examples:

```text
150 channels -> 50 pixels
300 channels -> 100 pixels
450 channels -> 150 pixels
510 channels -> 170 pixels
```

Physical controller identity/output remains a separate resolver boundary supplied by Controller Inventory/current assignment or an isolated temporary reviewed mapping during recovery.

Universe, IP address, Display Name, or source row position must not become permanent controller identity.

## CR50 / DumbRGB Presentation Contract

For CR50 DumbRGB fixtures, the atomic source remains three one-channel rows per fixture.

FieldWiring presentation may group rows by the source fixture identity:

```text
preview_uuid + source_raw_prop_id
```

For a valid CR50 group:

```text
source row count             3 RGB rows
ChannelGridRowNumber         1, 2, 3
Universe                     same fixture universe
DMX start address            channel represented by row 1 / minimum RGB channel
RGB channels                 actual three source channel values in row-number order
physical fixture footprint   5 DMX channels
```

The browser may compact consecutive RGB values for readability:

```text
1,2,3   -> 1-3
6,7,8   -> 6-8
```

It must not synthesize the two excluded function channels or derive a pixel count.

If the expected three-row CR50 pattern is not present, fail safe to engineering/review presentation rather than guessing a fixture address.

## Controller Resolution Boundary

The new DMX read contract carries LOR-authoritative topology. It does not create permanent physical controller identity.

FieldWiring's controller resolver must remain replaceable.

Conceptually it consumes:

```text
current LOR/V7 atomic wiring row(s)
resolved Stage/Scene/Display context
Controller Inventory current assignment
```

and returns, when authoritative:

```text
permanent controller identity
human controller label
exact controller model/family
physical output/port
current address/context
```

Temporary reviewed mappings may remain during engineering recovery but must be centralized and explicitly non-authoritative.

## Development Snapshot Requirement

The browser currently supports an explicit read-only development SQLite snapshot through `FIELDWIRING_DEV_SNAPSHOT`.

That fixture must remain a development/testing artifact only.

Before browser acceptance of the new DMX path, the development snapshot/export process must be verified and updated so it carries the same FieldWiring-specific DMX read contract used by PostgreSQL.

Do not add a second hand-maintained DMX dataset to the development snapshot.

The development fixture must be generated from authoritative PostgreSQL/current-snapshot relationships or from a controlled equivalent fixture builder and preserve the same column meanings.

The exact exporter/generator path must be identified and documented before implementation closeout; this change map does not authorize silently editing an unknown export process.

## Proposed Migration Boundary

The repository currently contains reconciliation migrations through `0036`.

If implementation begins without another migration being added first, the next available migration identifier would be `0037`; verify the repository again immediately before creating it.

A migration for this work should be narrowly limited to:

1. add the three nullable columns to `lor_snap.dmx_channels`;
2. replace `lor_snap.v_current_dmx_channels` with the explicit extended projection;
3. preserve owner/grant/comment conventions already used for current-snapshot interfaces;
4. optionally create the approved FieldWiring-specific read view only if its final query contract has been reviewed separately;
5. perform no reconciliation promotion, Display identity, Controller Inventory, or legacy wiring-view rewrite.

Do not bundle compact ChannelGrid parser expansion into the PostgreSQL migration.

## Repository Definition Files to Maintain

If the migration is approved, update the durable repository definitions that describe the same schema, including at minimum:

```text
Database/Basic_Query_Tools_Dev/DDL_lor_snap.dmx_channels.sql
current-snapshot view definition owner for v_current_dmx_channels
LOR2DB/01_Ingest/postgres_ingest_from_lor_sqlite_v7.py
LOR2DB/01_Ingest/test_postgres_ingest_from_lor_sqlite_v7.py
FieldWiring/Application read-model code/tests
FieldWiring development snapshot fixture/export definition
responsible FieldWiring/PostgreSQL documentation
```

Do not rely only on an applied migration while leaving the repository's reference DDL stale.

## Validation Sequence

Implementation acceptance must occur in this order.

### Gate 1 — migration/schema

Verify:

```text
lor_snap.dmx_channels has the three additive columns
existing PK/FKs unchanged
historical Run 50 rows remain present and nullable for new fields
v_current_dmx_channels explicit projection is correct
legacy preview_wiring_*_v6 definitions unchanged
```

### Gate 2 — ingest tests

Run the ingest automated tests including the new fail-closed DMX schema/value tests.

No production ingest until this gate is green.

### Gate 3 — controlled V7.0.11 production parser artifact

A production-mode V7.0.11 SQLite must be built through the normal controlled LOR2DB parser path after the feature branch/deployment boundary is intentionally handled.

Do not ingest the separate `VERSION_CHECK` acceptance SQLite used during engineering review because current ingest correctly requires `RunMode=PRODUCTION`.

### Gate 4 — PostgreSQL ingest

Ingest the exact reviewed production SQLite digest through the existing authority chain.

Verify:

```text
new import_run parser_version = V7.0.11
dmx row count matches reviewed SQLite
new DMX source-detail fields are complete
canonical prop_id values preserved
```

### Gate 5 — same-data PostgreSQL checks

Representative checks must include:

```text
Mega Tree
Mega Ball
Mega Star
Northern Lights CR50
Mega Cube / Who Matrix limitation visibility
```

For Mega Star, verify distinct source Channel Names survive PostgreSQL while all rows remain attached to the canonical Display.

For Northern Lights, verify the 3-row-per-CR50 / 5-channel-step pattern survives unchanged.

### Gate 6 — legacy compatibility

Confirm FormView-compatible `preview_wiring_*_v6` row counts/shapes/semantics remain unchanged for the same imported snapshot.

### Gate 7 — FieldWiring read contract

Verify the FieldWiring-specific DMX query returns permanent Display identity plus source detail without name-only identity joins.

### Gate 8 — development snapshot

Regenerate the FieldWiring development snapshot through its controlled export/fixture path and verify parity with the PostgreSQL read contract.

### Gate 9 — browser presentation

Only after the data path is accepted, change the renderer.

First browser acceptance cases:

```text
Mega Tree
    one physical 48-output controller context
    Output + Channel/Section + Universe + Pixels + Channel Range

Mega Star
    two reviewed physical controller contexts
    V7.0.11 source Channel Names visible per universe/output relationship

Northern Lights
    CR50 fixture rows grouped from three source RGB rows
    Universe + DMX Start + RGB Channels
    intentional 5-channel stepping preserved
```

Mega Cube and Mt. Crumpit / Who Matrix must remain visibly incomplete until the separate compact-ChannelGrid parser change is reviewed and accepted.

## Stop Conditions

Stop and review if any implementation causes:

- change to existing `dmx_channels.prop_id` canonical relationship;
- change to `ref.display.lor_prop_id` promotion behavior;
- new FK from DMX `raw_prop_id` to physical Display rows;
- legacy `preview_wiring_*_v6` shape or semantic change;
- FormView regression;
- DMX row-count change caused by this propagation alone;
- universe/start/end channel rewrite;
- CR50 gap normalization/fill-in;
- E1.31 universe treated as permanent controller identity;
- compact ChannelGrid expansion introduced implicitly;
- V7.0.11 source fields silently omitted by ingest;
- development snapshot becoming an independent topology authority.

## Rollback Boundary

This change is additive and append-only at the snapshot-data level.

Rollback must preserve historical imported runs.

If a newly imported V7.0.11 run is rejected after ingest, operational current-state rollback should follow the established LOR snapshot/reconciliation authority model rather than deleting historical evidence ad hoc.

Do not drop the new columns merely to make old code work if downstream compatibility can instead ignore nullable additive fields.

The legacy compatibility views are intentionally unchanged to make rollback/fallback to FormView straightforward.

## Out of Scope

This change map does not authorize:

- compact/auto-numbered ChannelGrid expansion;
- Controller Inventory schema design;
- permanent E1.31 controller IDs derived from IP/universe/name;
- FormView modification;
- QR/scan-hub redesign;
- launcher integration;
- FieldWiring production deployment;
- final browser UX acceptance;
- hard-report cutover;
- merge of the entire FieldWiring feature branch to `main`.

## Review Decision Needed Before Implementation

Before code/schema work starts, review and accept or revise these four points:

1. **PostgreSQL snapshot columns:** append nullable `raw_prop_id`, `channel_name`, `channel_grid_row_number` to `lor_snap.dmx_channels`.
2. **Ingest safety:** V7.0.11+ must fail closed when source/target schema or values for those fields are incomplete.
3. **Compatibility boundary:** leave all existing `preview_wiring_*_v6` views unchanged; create a separate FieldWiring DMX read path.
4. **Presentation grain:** keep atomic DMX source rows in PostgreSQL; aggregate only in FieldWiring according to E1.31 versus CR50/DumbRGB rules.

No implementation should begin until those points are accepted.

## Related Documents

- [FieldWiring Dense RGB DMX Additive Change Map](FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md)
- [FieldWiring Dense RGB Parser Extension Checkpoint](FieldWiring_Dense_RGB_Parser_Extension_Checkpoint_2026-08-21.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring / Controller Inventory Handoff](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [LOR XML to MSB Terminology Contract](../../../01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md)
- [LOR SQLite Output Database Structure](../../../01_LOR_System/02_Data_Extraction/LOR_SQLite_Output_Database_Structure.md)

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Created controlled PostgreSQL propagation design after V7.0.11 real-snapshot acceptance, same-input V7.0.10/V7.0.11 regression PASS, live production DMX schema/view inspection, E1.31 field-table acceptance, and CR50 three-source-row / five-channel fixture clarification. |
