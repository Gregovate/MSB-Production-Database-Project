# FieldWiring V7.0.11 Production SQLite Acceptance — 2026-08-21

| Item | Value |
|---|---|
| Status | ACCEPTED FOR CONTROLLED POSTGRESQL INGEST |
| Branch | `agent/fieldwiring-engineering-recovery` |
| LOR version | `6.6.10` |
| Parser | `V7.0.11` |
| Parser run mode | `PRODUCTION` |
| Parser validation | `PASSED` |
| Production SQLite | `G:\Shared drives\MSB Database\database\lor_output_v7_scene.db` |
| Reviewed SQLite SHA-256 | `eb3d20bb5dc5c0433903f0081fb658b4e5a788c66caa2a9497f10b07dcf8794a` |
| PostgreSQL ingest | NOT YET RUN at this checkpoint |

## Purpose

This checkpoint records acceptance of the exact V7.0.11 production SQLite artifact that will be eligible for the controlled PostgreSQL V0.4.2 ingest after migration `0037_add_dmx_source_detail.sql` was installed and post-migration validation passed.

Acceptance is tied to the exact SHA-256 above. A changed SQLite file requires renewed review and a new digest.

## Parser Provenance

The reviewed production artifact reports:

```text
ParserVersion: V7.0.11
RunMode: PRODUCTION
SourceLORVersion: 6.6.10
Status: COMPLETE
ValidationStatus: PASSED
SourceManifestSHA256: 1597bbdee97ca36b697972657e6a330fff92d5ae97a281050ededee03b230bdc
CompatibilityManifestSHA256: 550f3ec9c7345ad7616c4aa488624a8aba37c5a5bb1ca600e32f3790fb93af35
```

Production parser counts:

```text
previews: 33
raw LOR Scene rows: 92
props: 1157
subProps: 1312
dmxChannels: 508
scene_lor_props: 2260
```

The parser's internal validation also reported:

- 0 missing `RawPropID` values in materialized Props/SubProps;
- 0 unresolved Scene membership rows;
- wiring compatibility views rebuilt successfully;
- V7 Scene validation views rebuilt successfully;
- Display Names remained unique across masters; and
- final SQLite contract validation completed successfully.

## Reviewed DMX Source-Detail Contract

The V7.0.11 `dmxChannels` table contains the legacy eight columns followed by:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

Read-only completeness validation of the exact reviewed artifact returned:

```text
total_rows: 508
blank_raw_prop_id: 0
blank_channel_name: 0
invalid_grid_row_number: 0
distinct_source_props: 91
```

This closes the V7.0.11 source-detail completeness gate required by PostgreSQL ingest V0.4.2.

## Mega Star Source-Provenance Evidence

Representative `FT-MegaStar` rows prove that the parser now preserves source PropClass provenance without changing the canonical Display-master relationship.

Examples include:

```text
MS Long Spire 1 4x150
    RawPropID 1b59aa06-0388-4619-abc5-826ea6a40960
    ChannelGridRowNumber 1-4
    Universes 113-116

MS Long Spire 2 4x150
    RawPropID 591edadf-b8d2-4d9f-87ce-f81ff18f354a
    ChannelGridRowNumber 1-4
    Universes 117-120

MS Short Spire 1 2x150
    RawPropID 6b382da4-9af5-4cf7-ae7c-ac77ef5fcbcd
    ChannelGridRowNumber 1-2
    Universes 129-130
```

The source row number restarts locally for each originating PropClass, as required by the terminology and parser contracts.

## Northern Lights / CR50 Acceptance

A corrected topology-based read-only query validated the accepted CR50 source shape:

```text
source_rows: 198
fixture_groups: 66
```

By universe:

```text
Universe 145
    fixtures: 32
    source rows: 96
    first fixture start: 1
    last fixture start: 156

Universe 146
    fixtures: 34
    source rows: 102
    first fixture start: 1
    last fixture start: 166
```

Representative source fixture groups:

```text
NL DS RGB 01
    Universe 145
    RawPropID 5e63b09b-8205-4de1-9edb-783a3d964a87
    source rows 3
    ChannelGridRowNumber 1,2,3
    RGB channels 1,2,3

NL DS RGB 02
    Universe 145
    RawPropID 831f9c49-d9f1-4551-a6e4-e6aaf683492e
    source rows 3
    ChannelGridRowNumber 1,2,3
    RGB channels 6,7,8

NL PS RGB 34
    Universe 146
    RawPropID 6f0e0afd-558b-4300-9d8c-d0a5355fb987
    source rows 3
    ChannelGridRowNumber 1,2,3
    RGB channels 166,167,168
```

This proves the expected CR50 contract:

- three represented RGB source rows per fixture;
- local source row numbers 1-3;
- intentional five-channel fixture addressing step;
- two omitted fixture-function channels are not fabricated; and
- `PreviewId + RawPropID` remains a valid presentation grouping basis for one source fixture context.

## Known Separate Dense-Matrix Limitation

The reviewed artifact also contains compact/auto-numbered dense-matrix source shapes such as `PF-Marquee-DS / Float-Matrix 1024 DS` with sparse universe steps and 512-channel source ranges.

These rows are retained exactly as supplied by LOR. They do not invalidate this source-detail propagation acceptance. They remain part of the previously documented compact/auto-numbered Channel Grid expansion / presentation limitation and must not be normalized or fabricated during PostgreSQL ingest.

## Motion FX Guard Correction

During this production parser attempt, normal same-version Motion FX authoring in `MotionRowDefault.subc` initially triggered the routine parser compatibility guard.

Checker V1.3.1 now keeps same-approved-version Motion FX differences visible as informational evidence instead of treating them as parser-breaking. New-LOR-version compatibility review remains strict.

Local regression evidence after the fix:

```text
test_lor_version_checker.py: 8 passed
test_lor_version_checker_motion_fx.py: 2 passed
test_lor_operator_runner.py: 18 passed
Total: 28 passed, 0 failed
```

No Motion FX authoring was removed or reverted.

## Authorization Boundary

This checkpoint authorizes only the controlled PostgreSQL V0.4.2 ingest of the exact SQLite SHA-256 recorded above.

It does **not** authorize:

- ingesting a different SQLite digest;
- bypassing V0.4.2 source/target fail-closed checks;
- running reconciliation automatically;
- changing `dmx_channels.prop_id` semantics;
- adding a source `RawPropID` foreign key;
- changing legacy `preview_wiring_*_v6` views;
- normalizing CR50 addressing gaps;
- fabricating compact dense-matrix rows;
- changing the FieldWiring browser renderer; or
- merging the FieldWiring branch to `main`.

After ingest, run the established DMX source-detail PostgreSQL validation and verify the new current run before any reconciliation or FieldWiring read-surface work.
