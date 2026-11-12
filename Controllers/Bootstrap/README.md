# Controller Bootstrap Source Loader

The initial Controller Inventory reconstruction used a generated reconciliation CSV created from the Controller Inventory workbook and the approved V7/LOR comparison material.

The original bootstrap loaded 177 deployed-controller candidates into temporary `stage.*` objects. Those stage objects were later removed after permanent Controller Inventory promotion.

## Preserved Recovery Evidence — 2026-08-31

During FieldWiring integration review, a permanent-model gap was found: the first promotion preserved physical `controller_id` and Controller-to-Display relationships, but did not carry the physical controller's reviewed Network / Unit-ID / address configuration into `ref.controller`.

The original workbook was re-opened and reconciled against the accepted permanent `controller_id` sequence. The resulting 177-row recovery evidence is now preserved at:

```text
Controllers/Bootstrap/Evidence/controller_programmed_configuration_recovery_20260831.csv
```

That file preserves, per permanent Controller ID:

- original Excel row number;
- original controller/display name evidence;
- original Network evidence;
- original Unit-ID/address evidence;
- normalized current LOR Network;
- First UID, UID Count, and calculated ending UID where applicable;
- management IP for the nine E1.31 controllers represented in the workbook;
- canonical permanent model code; and
- the original `For What` grouping evidence needed to distinguish repeated-address physical controllers.

The permanent database recovery is implemented by:

```text
Controllers/Database/014_restore_controller_programmed_configuration.sql
```

Do not delete this recovery evidence after migration. It is the durable audit bridge between the original physical inventory workbook and the permanent Controller IDs.

## Historical Loader

`load_controller_reconciliation_csv.py` validated the original generated bootstrap CSV before temporary stage writes.

Historical validation output was:

```text
rows=177
firmware_recorded=172
firmware_unknown_or_verify=5
v7_matched=152
v7_review_required=25
mode=VALIDATE_ONLY
database_writes=0
```

The original `--apply` workflow wrote only `stage.controller_bootstrap` and allocated zero permanent Controller IDs. It is retained as historical bootstrap tooling; the permanent Controller Inventory is now the operational authority.