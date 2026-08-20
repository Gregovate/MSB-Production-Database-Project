# FieldWiring Recovery Validation — 2026-08-20

| Item | Value |
|---|---|
| Status | AUTOMATED RECOVERY GATE PASSED — browser acceptance pending |
| Sub-project | FieldWiring |
| Feature branch | `agent/fieldwiring-engineering-recovery` |
| Tested branch head | `ac78e99f3a7e5ebd6e3a6f4b87c265c029c53c3c` — Document FieldWiring test environment |
| Recovery baseline | `FieldWiring_Accepted_Baseline_Recovery_2026-08-20.md` |
| Schema change | None |

## Windows Development Validation

Validation was run from the project virtual environment on the Windows development workstation after installing the controlled development requirements from:

```text
FieldWiring/Application/requirements-dev.txt
```

Command:

```powershell
python -m pytest .\FieldWiring\Application -q
```

Observed result:

```text
....................... [100%]
23 passed in 1.20s
```

Result: **PASS**.

The 23-test suite includes the recovered physical-presentation regression coverage for:

- device-family discrimination using both `device_type` and `string_type`;
- fail-safe handling of unreviewed RGB address blocks;
- Church mixed RGB topology: Pixie 16 Tree, Pixie 2 Crosses, and two repeated-address Pixie 4 Candy Cane controllers;
- Candyland mixed RGB topology: one reviewed Pixie 16 Lollipop context plus three repeated-address Pixie 4 Candy Cane controllers in the corrected topology fixture;
- stale Candyland third Candy Cane block preservation without silently changing LOR addressing;
- Who Forest eight Pixie 8 controllers with each corresponding Tree Star sharing physical Output 8;
- conventional A/C shared-output preservation;
- Scene package completeness;
- Stage/Scene image-scope rules;
- stale marked-path recovery;
- context mismatch rejection; and
- hard-report expiration/currentness behavior.

## JavaScript Command-Line Check

`node --check` was **NOT RUN** because Node.js is not installed on the Windows development workstation.

Node.js is not a FieldWiring runtime/workstation prerequisite and must not be installed solely for this validation. Browser execution remains part of the real browser acceptance gate.

## Recovery State After Automated Gate

Automated regression validation is now clean. This does **not** by itself mark the recovered browser UI as accepted.

Next acceptance work is hands-on browser validation against the already-approved baseline, in this order:

1. Church Musical mixed-controller presentation;
2. Church Background shared A/C output presentation;
3. image Show/Hide reclaiming the full hookup-pane space;
4. independent image and hookup scrolling plus draggable divider;
5. Candyland Pixie 16 Lollipop presentation and stale/current Candy Cane snapshot behavior;
6. Who Forest eight Pixie 8 groups and eight physical outputs per Tree;
7. responsive/narrow-window hookup behavior;
8. print image + physical hookup document flow; and
9. centralized branding asset display.

Do not make UX improvements during this acceptance pass. Any failure against the accepted baseline is a recovery defect and must be corrected before new feature work resumes.
