# TODO: Light Curtain (8 Strands) / Matrix-Vertical-Rectangle Special-Case
**Date:** 2025-08-23  
**Status:** Defer changes until impact review (do not modify parser yet)

## Context
Passenger-side wiring is reversed vs driver-side for Light Curtain panels. We see a single duplicate wiring “remnant” (e.g., `FT-PS Group B` at 21-09) because a **group header** row is inserted *in addition to* the per-row legs. The sub-props themselves were derived correctly; we want to avoid emitting the extra header row and standardize naming.

## Scope (when to apply)
- **Tag contains** `Light Curtain (8 Strands)` (primary gate).  
- *(Later, if we ingest it)* also gate when **Shape == `Matrix-Vertical-Rectangle`** (traditional strings). The current DB **does not** store Shape; see Notes below.

## Proposed Plan (V6 parser)
Implement inside `process_lor_multiple_channel_grids(...)` **only when the Tag gate matches**:

1. **Pre-parse all ChannelGrid legs**, collect: `Network, UID, StartChannel, EndChannel, Color, label`.
2. Select **master leg** = the leg with the **lowest `StartChannel`** (or your preferred rule).
3. Insert the **master prop** into `props` using that master leg’s wiring fields; **do not** create a `subProps` row for the same leg.
4. **Do not insert a group-header subProp** (e.g., `FT-PS Group B`) — **only** emit per-row legs such as `… Yellow 21-09`.
5. **De-duplicate** before insert using a set keyed on `(Network, UID, StartChannel, EndChannel)`.
6. **Dashify** subProp names (display only): spaces → dashes. Example: `FT-PS-Group-B-Yellow-21-09`.

### Pseudocode sketch
```python
seen = set()  # (Network, UID, StartChannel, EndChannel)
master_idx = min(range(len(legs)), key=lambda i: legs[i]["StartChannel"] or 10**9)

# insert master into props from legs[master_idx]

for i, leg in enumerate(legs):
    if i == master_idx:
        continue  # skip master leg as subprop
    if is_group_header_name(leg["label"]):  # e.g., "FT-PS Group B"
        continue  # skip header row
    key = (leg["Network"], leg["UID"], leg["StartChannel"], leg["EndChannel"])
    if key in seen:
        continue
    seen.add(key)
    name = dashify(compose_name(...))  # replace spaces with dashes
    # insert into subProps(...)
```

## Safety Net (SQL de-dup view)
Use this view for charts if needed until everyone runs the parser fix:
```sql
DROP VIEW IF EXISTS preview_wiring_dedup_v6;
CREATE VIEW preview_wiring_dedup_v6 AS
SELECT
  PreviewName,
  DisplayName,
  MIN(LORName)   AS LORName,      -- stable representative
  Network,
  Controller,
  StartChannel,
  EndChannel,
  MIN(DeviceType) AS DeviceType,
  MIN(Source)     AS Source,
  MIN(LORTag)     AS LORTag
FROM preview_wiring_map_v6
GROUP BY
  PreviewName, DisplayName, Network, Controller, StartChannel, EndChannel;
```

## Acceptance Criteria
- No duplicate “boundary” leg (e.g., **no extra row at 21‑09** for `FT‑PS Group B`).
- SubProp names are **dashified** (no spaces).
- For each Who/Festive Trees panel, leg count matches the expected **8 + 8** (DS and PS).

## Test Queries
```sql
-- 1) Duplicates (should be empty after parser fix)
SELECT DisplayName, Network, Controller, StartChannel, EndChannel, COUNT(*) AS cnt
FROM preview_wiring_map_v6
GROUP BY DisplayName, Network, Controller, StartChannel, EndChannel
HAVING COUNT(*) > 1;

-- 2) Boundary check around PS 21-09
SELECT DisplayName, LORName, Network, Controller, StartChannel, EndChannel, Source
FROM preview_wiring_map_v6
WHERE DisplayName LIKE '%FT-PS%'
  AND Controller = '21'
  AND StartChannel BETWEEN 8 AND 10
ORDER BY StartChannel;

-- 3) Leg counts per display in a preview
SELECT PreviewName, DisplayName, COUNT(*) AS legs
FROM preview_wiring_map_v6
WHERE PreviewName = '<<PUT YOUR PREVIEW NAME HERE>>'
GROUP BY PreviewName, DisplayName
ORDER BY legs DESC;

-- 4) Sorted wiring list for one preview (matches chart sort)
SELECT PreviewName, DisplayName, LORName, Network, Controller,
       StartChannel, EndChannel, DeviceType, Source, LORTag
FROM preview_wiring_sorted_v6
WHERE PreviewName = '<<PUT YOUR PREVIEW NAME HERE>>'
ORDER BY DisplayName, Network, Controller, StartChannel;
```




## Affected Displays (apply this TODO to all of these)
**Last updated:** 2025-08-23

- `FT-Wraps-DS`
- `FT-Wraps-PS`
- `Pinwheel-DS`
- `Pinwheel-PS`
- `RacingArches`

### Temporary gating rule (until Shape is available)
Apply the parser fix when **either**:
1) `Tag` contains one of: `Light Curtain (8 Strands)`, `Wraps`, `Pinwheel`, `RacingArches`, **or**
2) `DisplayName` (aka LOR Comment) contains one of the listed display tokens above.

> This keeps the change tightly scoped to the known-problem displays while we evaluate broader impact.

### Quick audit queries for these displays
```sql
-- 1) Find duplicates (should be empty once fix is applied)
SELECT DisplayName, Network, Controller, StartChannel, EndChannel, COUNT(*) AS cnt
FROM preview_wiring_map_v6
WHERE DisplayName LIKE '%FT-Wraps-DS%'
   OR DisplayName LIKE '%FT-Wraps-PS%'
   OR DisplayName LIKE '%Pinwheel-DS%'
   OR DisplayName LIKE '%Pinwheel-PS%'
   OR DisplayName LIKE '%RacingArches%'
GROUP BY DisplayName, Network, Controller, StartChannel, EndChannel
HAVING COUNT(*) > 1
ORDER BY DisplayName, Controller, StartChannel;

-- 2) Leg counts per display (sanity check)
SELECT DisplayName, COUNT(*) AS legs
FROM preview_wiring_map_v6
WHERE DisplayName LIKE '%FT-Wraps-DS%'
   OR DisplayName LIKE '%FT-Wraps-PS%'
   OR DisplayName LIKE '%Pinwheel-DS%'
   OR DisplayName LIKE '%Pinwheel-PS%'
   OR DisplayName LIKE '%RacingArches%'
GROUP BY DisplayName
ORDER BY DisplayName;

-- 3) Sorted wiring for just these displays in one preview
SELECT PreviewName, DisplayName, LORName, Network, Controller, StartChannel, EndChannel, DeviceType, Source
FROM preview_wiring_sorted_v6
WHERE PreviewName = '<<PUT YOUR PREVIEW NAME HERE>>'
  AND (DisplayName LIKE '%FT-Wraps-DS%'
    OR DisplayName LIKE '%FT-Wraps-PS%'
    OR DisplayName LIKE '%Pinwheel-DS%'
    OR DisplayName LIKE '%Pinwheel-PS%'
    OR DisplayName LIKE '%RacingArches%')
ORDER BY DisplayName, Network, Controller, StartChannel;
```


## Notes
- **Shape field:** The current schema does **not** persist Shape. If we want to gate by Shape as well, extend the parser to read Shape from the XML and add a column (e.g., `props.Shape`, `subProps.Shape`). Default to `NULL` and only populate when present so existing logic isn’t impacted.
- **Impact control:** This TODO deliberately limits changes to the **Tag-gated** case to avoid affecting unrelated wiring.
- **Do not implement yet:** Keep as a TODO until we review broader wiring impact.
