# LOR Motion FX Compatibility Rule — 2026-08-21

| Item | Value |
|---|---|
| Status | ACCEPTED — IMPLEMENTED AND LOCALLY TESTED ON FEATURE BRANCH |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Checker | `lor_version_checker.py` V1.3.1 |
| Production parser | V7.0.11 |
| Scope | Motion FX / `MotionRowDefault` XML authoring changes |

## Decision

`MotionRowDefault` / Motion FX rows are normal Light-O-Rama preview-authoring content. Changes to Motion FX row data, including `MotionRowDefault.subc` comma/semicolon-encoded records, must not block routine parser execution when the preview folder is still using the already-approved LOR software version.

The V7 production parser does not consume `MotionRowDefault` data as part of its Preview, Scene, Display, ChannelGrid, wiring, or identity contract.

Therefore:

- Motion FX XML remains inventoried by the compatibility checker so the source change stays visible as engineering evidence.
- When the baseline and live preview folder use the **same approved LOR version**, blocking findings involving `MotionRowDefault` are downgraded to informational evidence.
- When comparing **different LOR software versions**, the compatibility checker remains strict; Motion FX structural changes are not automatically waived because they may reflect a software-format change.
- No Motion FX authoring should be removed, reverted, or redesigned merely to satisfy the parser compatibility guard.
- Parser-sensitive structures such as `PreviewClass`, `Scene`, `PropClass`, `ChannelGrid`, IDs, ordering relationships, and materialized parser output remain governed by their existing compatibility rules.

## Triggering Incident

A routine LOR2DB **Run Parser** attempt on approved LOR 6.6.10 was blocked after the current Master Musical Preview changed from the 2026-08-11 export to the 2026-08-20 export.

The guard reported:

```text
MotionRowDefault.subc: New semicolon record count: 275
```

The change was intentional Motion FX authoring for Mt. Crumpit, not a LOR software-version format change and not a parser contract change.

The parser was stopped before the production SQLite publication step, so the existing published SQLite remained intact.

## Implementation

`Docs/01_LOR_System/02_Data_Extraction/Parser/lor_version_checker.py`

Checker version changed from V1.3.0 to V1.3.1.

Implementation commit:

```text
a0c7645937887d7a486e84181efa36d3a5c43456
Allow same-version Motion FX authoring changes
```

## Regression Tests

A focused Motion FX regression test was added:

`Docs/01_LOR_System/02_Data_Extraction/Parser/test_lor_version_checker_motion_fx.py`

It verifies both required boundaries:

1. same-version `MotionRowDefault.subc` growth to 275 semicolon records is nonblocking and remains visible as informational evidence;
2. the same structural difference across different LOR software versions remains blocking under the new-version compatibility gate.

Test creation commit:

```text
8a2ffd76ff6bbb4bcd3782b017c0b5b1ff005018
Test Motion FX compatibility boundary
```

## Local Acceptance — 2026-08-21

Operator-run local results from the repository root:

```text
python .\Docs\01_LOR_System\02_Data_Extraction\Parser\test_lor_version_checker.py
Ran 8 tests in 0.151s
OK

python .\Docs\01_LOR_System\02_Data_Extraction\Parser\test_lor_version_checker_motion_fx.py
Ran 2 tests in 0.045s
OK

python .\Docs\01_LOR_System\02_Data_Extraction\Parser\test_lor_operator_runner.py
Ran 18 tests in 0.768s
OK
```

Total acceptance for this guard change:

```text
28 tests passed
0 failed
```

## Operational Requirement

The Windows LOR operator runner imports the checker when its process starts. After pulling V1.3.1, restart the managed runner before using the LOR2DB page. The approved LOR version/state record is not reinitialized and the existing pairing/token remains unchanged.

After restart, retry the normal current-version **Run Parser** operation. The existing Motion FX authoring must remain in place.
