# Controller Bootstrap Source Loader

The initial Controller Inventory reconstruction uses a generated reconciliation CSV created from:

```text
Controller Inventory & Testing 2026(7).xlsx
lor_output_v7_scene(20260830-185521).db
```

The current CSV contains 177 deployed-controller candidates.

`load_controller_reconciliation_csv.py` validates the CSV before any database write.

Default mode:

```text
python load_controller_reconciliation_csv.py controller_reconciliation_20260830.csv
```

Expected current output includes:

```text
rows=177
firmware_recorded=172
firmware_unknown_or_verify=5
v7_matched=152
v7_review_required=25
mode=VALIDATE_ONLY
database_writes=0
```

To load only the temporary staging table after database script 001 is installed:

```text
set CONTROLLER_DATABASE_DSN=<secured PostgreSQL DSN>
python load_controller_reconciliation_csv.py controller_reconciliation_20260830.csv --apply
```

`--apply` writes only `stage.controller_bootstrap`; it allocates zero permanent Controller IDs.

Reloading the same source file/row updates source-evidence columns without replacing operator review state, derived year, permanent Display relationships, or proposed Controller-ID order.
