# FieldWiring PostgreSQL Run 51 Ingest Checkpoint — 2026-08-21

| Item | Value |
|---|---|
| Status | PRODUCTION INGEST COMPLETE — POST-INGEST VALIDATION PENDING |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Import run | `51` |
| Parser | `V7.0.11` |
| Parser mode | `PRODUCTION` |
| Source LOR version | `6.6.10` |
| Ingest | `V0.4.2` |
| Production reconciliation | NOT STARTED |

## Reviewed SQLite Authority

The production SQLite artifact reviewed and approved for this ingest was:

```text
G:\Shared drives\MSB Database\database\lor_output_v7_scene.db
```

Reviewed SHA-256:

```text
eb3d20bb5dc5c0433903f0081fb658b4e5a788c66caa2a9497f10b07dcf8794a
```

The parser completed at `2026-08-21T15:09:54-05:00` and the ingest identified the parser actor as `Greg@MSB-OFFICE-PC`.

## SQLite Acceptance Evidence Before Ingest

The reviewed V7.0.11 production artifact passed:

- parser status `COMPLETE`;
- validation status `PASSED`;
- 33 previews;
- 92 raw LOR Scene rows;
- 1,157 props;
- 1,312 subprops;
- 508 DMX rows;
- 2,260 scene/prop memberships;
- zero missing raw PropClass UUIDs;
- zero unresolved Scene memberships;
- 508/508 DMX rows with nonblank `RawPropID`;
- 508/508 DMX rows with nonblank `ChannelName`;
- 508/508 DMX rows with positive `ChannelGridRowNumber`.

Representative dense RGB evidence preserved source Channel Names, source RawPropID values, and local Channel Grid Row Numbers.

Northern Lights CR50 acceptance matched the approved fixture contract exactly:

```text
198 source rows
66 physical fixture groups
Universe 145: 32 fixtures / 96 source rows / fixture starts 1..156
Universe 146: 34 fixtures / 102 source rows / fixture starts 1..166
```

Each CR50 fixture retained three source rows with local grid rows `1,2,3`, and the intentional five-channel address stepping remained visible.

## Production Ingest Result

The normal LOR2DB production ingest completed successfully and created:

```text
import_run_id=51
```

Observed ingest gates/results:

```text
[OK] Raw PropClass UUID schema contract verified.
[OK] SQLite raw PropClass UUID values are complete.
[OK] V7.0.11+ DMX source-detail schema contract verified.
[OK] SQLite V7.0.11+ DMX source-detail values are complete.
[OK] previews: inserted 33 rows
[OK] scenes: inserted 92 rows
[OK] props: inserted 1157 rows
[OK] sub_props: inserted 1312 rows
[OK] dmx_channels: inserted 508 rows
[OK] scene_lor_props: inserted 2260 rows
[OK] Postgres raw PropClass UUID values are complete.
[OK] Postgres V7.0.11+ DMX source-detail values are complete.
[DONE] Snapshot ingest complete. import_run_id=51
```

Run summary reported:

```text
run=51
previews=33
scenes=92
props=1157
sub_props=1312
dmx=508
scene_lor_props=2260
field_wiring=2189
```

## Next Controlled Gate

Before reconciliation, FieldWiring rendering changes, development snapshot regeneration, or any branch cutover, run the read-only validation:

```text
LOR2DB/02_Reconciliation/reconciliation/validation/32_dmx_source_detail_validation.sql
```

Required post-ingest checks include:

- Run 51 is current;
- parser version is V7.0.11;
- current DMX row count is 508;
- all three DMX source-detail fields are populated for the current run;
- V7.0.11+ completeness violation counts are zero;
- `v_current_dmx_channels` ownership/grants remain correct;
- existing PK/FK contract remains unchanged;
- protected legacy view definitions remain unchanged;
- row-count differences caused by legitimate preview authoring are reviewed as data changes rather than assumed regressions.

Do **not** begin reconciliation until this post-ingest validation is accepted.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Recorded production Run 51 V7.0.11 / ingest V0.4.2 completion and deferred all downstream work pending read-only post-ingest validation. |
