# FieldWiring PostgreSQL DMX Propagation Implementation Checkpoint — 2026-08-21

| Item | Value |
|---|---|
| Status | IMPLEMENTED AND LOCALLY TESTED ON FEATURE BRANCH — NOT DEPLOYED |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Production database | UNCHANGED — Run 50 / parser V7.0.10 / ingest V0.4.1 remains current |
| Production migration | NOT APPLIED |
| Production ingest | NOT RUN |
| Browser renderer | UNCHANGED |

## Purpose

This checkpoint records completion of the feature-branch implementation and local automated-test gate for propagation of parser V7.0.11 grouped-DMX source detail into PostgreSQL.

It does **not** authorize running the migration against production, running a V7.0.11 production ingest, changing the FieldWiring browser renderer, cutting over from FormView, or merging the FieldWiring branch to `main`.

## Implemented Branch Artifacts

### PostgreSQL migration

`LOR2DB/02_Reconciliation/reconciliation/migrations/0037_add_dmx_source_detail.sql`

The migration is additive and limited to:

- adding nullable `raw_prop_id TEXT`;
- adding nullable `channel_name TEXT`;
- adding nullable `channel_grid_row_number INTEGER`;
- explicitly appending those fields to `lor_snap.v_current_dmx_channels`;
- preserving the existing `dmx_channels.prop_id` canonical Display-master relationship;
- preserving existing primary and foreign keys;
- adding no foreign key from source `raw_prop_id` to `lor_snap.props`;
- changing no `preview_wiring_*_v6` compatibility view;
- reasserting the established current-view owner `msbadmin` and `SELECT` grant to `directus_app`; and
- introducing no Controller Inventory identity or physical-controller mapping.

Historical pre-V7.0.11 snapshots remain valid with NULL values in the additive columns. No historical backfill is performed.

Implementation commits:

```text
bafb3742b1d384b32e29066a7d6a98b103e1d4ea
Add PostgreSQL DMX source detail propagation

82fba6ae542af767688892c0ff02b48c0a3bd9f5
Preserve DMX current-view ownership and grant
```

### Read-only validation SQL

`LOR2DB/02_Reconciliation/reconciliation/validation/32_dmx_source_detail_validation.sql`

The validation checks the additive column/view contract and is intended to be run after migration installation before any V7.0.11 production ingest. It also verifies the expected view owner and `directus_app` SELECT privilege.

Relevant commits:

```text
5b2c97955add2207d78e7b31d1304270b5e7a552
Create DMX source-detail validation

71ed1a7695a4deecf554782f075d2e3061c8fb70
Validate DMX current-view ownership and grant
```

### Reference DDL

`Database/Basic_Query_Tools_Dev/DDL_lor_snap.dmx_channels.sql`

The repository reference DDL now includes the same three nullable source-detail columns so the durable schema definition does not remain stale after the migration artifact was created.

Update commit:

```text
1358c8fa751c6c80a3c47d9ff476abfd1e8382ea
```

### PostgreSQL ingest V0.4.2

`LOR2DB/01_Ingest/postgres_ingest_from_lor_sqlite_v7.py`

The ingest version is now `V0.4.2` on this feature branch.

For parser V7.0.11 and later it now fails closed when:

- SQLite `dmxChannels` lacks `RawPropID`, `ChannelName`, or `ChannelGridRowNumber`;
- PostgreSQL `lor_snap.dmx_channels` lacks `raw_prop_id`, `channel_name`, or `channel_grid_row_number`;
- a materialized SQLite DMX row has blank source RawPropID;
- a materialized SQLite DMX row has blank ChannelName;
- a materialized SQLite DMX row has NULL/nonpositive ChannelGridRowNumber; or
- the inserted PostgreSQL snapshot loses any required source-detail value before commit.

The V7.0.11 requirement is version-gated. V7.0.10 and earlier parser artifacts retain their historical schema contract and are not retroactively required to contain these fields.

Positive but noncontiguous `ChannelGridRowNumber` values remain valid because a malformed nonblank serialized Channel Grid entry can intentionally produce a source-position gap.

Implementation commit:

```text
8ab3c10d89cdc0be173e3da4c579ef85ebaad714
Fail closed on V7.0.11 DMX source detail
```

## Development Snapshot Export Trace

The existing FieldWiring development exporter is:

```text
Utilities/MSB_Postgres_MCP/export_fieldwiring_snapshot.py
```

It exports `lor_snap.v_current_dmx_channels` dynamically from the live view column metadata / `SELECT *` contract.

Therefore no exporter code change is required merely to carry the three new DMX fields. Once the production current-DMX view exposes them, a regenerated development snapshot will carry them automatically.

This does **not** mean the FieldWiring application currently consumes them. The application read query and renderer remain later gates.

## Automated Tests Added

### Ingest safety tests

`LOR2DB/01_Ingest/test_postgres_ingest_from_lor_sqlite_v7.py`

The expanded suite covers:

- existing reviewed-SQLite SHA-256 authority behavior;
- existing production parser-run requirement;
- existing parser validation-status requirement;
- V7.0.10 backward compatibility;
- V7.0.11 version boundary;
- missing SQLite DMX source-detail fields;
- missing PostgreSQL DMX source-detail fields;
- blank/invalid V7.0.11 DMX source values;
- acceptance of positive noncontiguous Channel Grid Row Numbers;
- target-side completeness validation;
- exact generic normalized-name mapping for `RawPropID`, `ChannelName`, and `ChannelGridRowNumber`; and
- existing import-run/idempotency safety behavior.

Relevant commits:

```text
c822e3083f0d1cd5a3a367513a1d545a82323830
Test V7.0.11 DMX ingest safety contract

ada68e3ae05ea191adab624b7d49e900e4b7658f
Freeze DMX source detail column mapping test
```

### Migration contract tests

`LOR2DB/01_Ingest/test_dmx_source_detail_migration.py`

The static migration tests verify that migration `0037`:

- adds exactly the approved additive source-detail fields;
- explicitly extends `v_current_dmx_channels`;
- keeps the canonical `prop_id` relationship;
- does not add a source-RawPropID foreign key;
- does not rewrite legacy `preview_wiring_*_v6` compatibility views;
- preserves the established `msbadmin` owner and `directus_app` SELECT grant; and
- has a matching read-only validation artifact.

Relevant commits:

```text
b1a39cc445d63ffcf6463a46fac30e761d084174
Test DMX propagation migration contract

c8674cf0773ecd7c142ace724c57b1c7d6892c1a
Test DMX current-view ownership and grant
```

## Local Test Acceptance

After pulling the feature branch, the operator ran from:

```text
C:\lor\ImportExport\VSCode
```

Commands:

```powershell
python .\LOR2DB\01_Ingest\test_postgres_ingest_from_lor_sqlite_v7.py
python .\LOR2DB\01_Ingest\test_dmx_source_detail_migration.py
```

Observed results:

```text
Ran 16 tests in 0.442s
OK

Ran 5 tests in 0.043s
OK
```

After the migration was tightened to reassert current-view ownership and grants, the operator pulled the follow-up and reran the migration-contract suite:

```text
Ran 6 tests in 0.051s
OK
```

Final local automated gate:

```text
16 ingest tests passed
6 migration-contract tests passed
22 tests passed total
0 tests failed
```

Status: **PASS**.

No CI workflow was attached to the branch head for this checkpoint; the acceptance evidence is the operator-run local test result above.

## Compatibility Boundary Still in Force

The following remain unchanged and are not to be repurposed for V7.0.11 grouped-DMX source detail:

```text
lor_snap.preview_wiring_map_v6
lor_snap.preview_wiring_sorted_v6
lor_snap.preview_wiring_fieldmap_v6
lor_snap.preview_wiring_fieldlead_v6
lor_snap.preview_wiring_circuit_rollup_v6
lor_snap.preview_wiring_fieldonly_v6
```

FormView remains the maintained fallback until FieldWiring is proven.

## Controller Inventory Boundary Still in Force

This propagation adds only LOR-authoritative source wiring provenance.

It does not define permanent physical controller identity, E1.31 controller assignment, controller model, or physical output ownership.

Those requirements remain handed off to the Controller Inventory project. FieldWiring must keep its future controller-resolution interface replaceable so Controller Inventory can provide authoritative identity/current assignment without being forced to duplicate LOR universe/channel topology.

Any new FieldWiring discovery affecting controller identity, model, outputs, assignment, duplicate-address grouping, E1.31 resolution, or the required Controller Inventory read interface must be reflected in the Controller Inventory handoff documentation before the associated FieldWiring milestone is considered fully documented.

## Known Separate Limitation

Mega Cube and Mt. Crumpit / Who Matrix still have the separate compact/auto-numbered Channel Grid expansion issue.

Migration `0037` and ingest V0.4.2 intentionally do not solve or conceal that parser limitation. Missing compact rows must not be fabricated by PostgreSQL or FieldWiring.

## Next Controlled Gate — Migration Review

The branch implementation/test gate is complete.

Before production execution, review migration `0037` specifically for:

1. exact additive table changes;
2. current-view replacement behavior and dependency safety;
3. preservation of existing view ownership/grants;
4. historical Run 50 behavior after the new nullable columns exist;
5. rollback/fallback behavior while FormView remains active; and
6. execution/validation order.

The ownership/grant convention has now been explicitly incorporated into migration `0037` and its validation/test artifacts.

Only after the remaining production preflight checks are accepted should migration `0037` be considered for production execution.

Do **not** run the V7.0.11 production parser/ingest as part of the migration installation itself.

## Stop Conditions

Stop before deployment if review finds any requirement to:

- change `dmx_channels.prop_id` semantics;
- backfill historical source detail from guesses;
- add a foreign key from DMX `raw_prop_id` to canonical Display Props;
- change a legacy `preview_wiring_*_v6` definition;
- treat universe/IP/name as permanent controller identity;
- normalize CR50 addressing gaps;
- fabricate compact Channel Grid rows; or
- make the development snapshot an independent wiring authority.

## Related Documents

- [FieldWiring PostgreSQL DMX Propagation Change Map](FieldWiring_PostgreSQL_DMX_Propagation_Change_Map_2026-08-21.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring / Controller Inventory Handoff](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Recorded feature-branch PostgreSQL DMX propagation implementation, exporter trace, ingest V0.4.2 fail-closed boundary, tightened current-view owner/grant preservation, and operator-run final 16/16 + 6/6 local test PASS. No production deployment authorized or performed. |
