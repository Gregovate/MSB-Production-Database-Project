# Processing Rules for LOR Preview Parsing (v6)

## Objective
Parse `*.lorprev` files, extract `PreviewClass` and `PropClass`, and persist to SQLite so each physical **Display** has one master row in `props`, with any additional legs/channels represented in `subProps` / `dmxChannels`.
- **Display Name** = XML `Comment`
- **Channel Name** = XML `Name`

## Goals
- One master row per Display in `props` when applicable.
- Preserve **Channel Name** and **Display Name** exactly as in the XML.
- Provide wiring (Network/Controller/Channels) via SQL views—no name mutation in storage.

## Definitions
- **Preview**: One stage per `.lorprev` (exactly one `PreviewClass` per file).
- **Display**: Physical asset we build/store/maintain; keyed by **Display Name** (`LORComment`).
- **Channel Name**: Sequencer label (`Name` in XML). **Never changed** by parser.
- **UID**: LOR controller ID (hex). (DMX uses Universe separately.)
- **id**: LOR-assigned UUID on each `PropClass`.

---

## Database (existing tables)
- `previews` — one per preview file.
- `props` — master rows (LOR / DMX / None). Includes grid columns: `Network`, `UID`, `StartChannel`, `EndChannel`, `Unknown`, `Color`, etc.
- `subProps` — subordinate rows linked to a master (`MasterPropId`).
- `dmxChannels` — one row per DMX `ChannelGrid` leg linked to its parent prop (`PropId`).

> No base-schema changes required by these rules.

---

## ID Scoping (preview-scoped keys)
LOR can reuse `PropClass.id` across previews. All stored keys are **scoped by PreviewId** to avoid cross-preview overwrites and to keep re-runs idempotent:

- **Scoped prop id:**  
  `{PreviewId}:{RawPropId}`
- **Scoped subprop id (auto materialized):**  
  `{MasterScopedId}-{UID}-{Start:02d}`
- **DeviceType=None instances:**  
  `{PreviewId}:{RawPropId}:{i:02d}`

Used consistently in:
- `props.PropID`
- `subProps.MasterPropId`, `subProps.SubPropID`
- `dmxChannels.PropId`

---

## Processing Order & Rules

### PASS 0 — SPARE (LOR single-grid)
Scope: `DeviceType='LOR'` and **single** `ChannelGrid` leg (no `;`), and `Name` contains “spare” (case-insensitive).

- Insert directly into `props` with its single grid.
- **Do not** group by Display Name.
- **Never** change `Name` or `Comment`.

---

### PASS 0B — Manual subprops (MasterPropId set)
Scope: XML rows with `MasterPropId` (manually assigned subprops), **single-grid**.

Rules:
- Compare subprop `LORComment` vs. master `LORComment`.
- **Promote the first** subprop per unique `LORComment` (that differs from master) to a full **`props`** row.
- Any **subsequent** manual subprop with the **same** `LORComment` remains in **`subProps`** linked to that master.
- If the subprop’s grid is empty, **inherit master’s grid** (“uses same channels”).
- **Never** change `Name` or `Comment`.

Result: physical items (e.g., `PO-RoofBallandPost`, `PO-IcicleLights`) get one PROP each; extra drawing legs stay as SUBPROP.

---

### PASS 1 — Auto group (LOR single-grid)
Scope: Remaining LOR single-grid rows (not SPARE; not manual subprops).

- **Group by `LORComment`** (Display Name).
- **Master selection**: row with the lowest `StartChannel`.
- **Master → `props`** (with its grid).
- **Others → `subProps`** with full grid;  
  `SubPropID = {master_id}-{UID}-{Start:02d}`.
- **Names preserved**: `Name` and `LORComment` are stored exactly as in XML.

---

### LOR multi-grid (separate handler)
Scope: `DeviceType='LOR'` and `ChannelGrid` contains `;` (multiple legs).

- Retain the original prop in **`props`** (master).
- Materialize **each leg** as a **`subProps`** row with its own `Network/UID/Start/End/Color`, linked via `MasterPropId`.
- `SubPropID` follows `{master_id}-{UID}-{Start:02d}`.
- **Names/Comments unchanged**.

---

### DMX
- Insert one **`props`** row per DMX prop (scoped `PropID`).
- Split `ChannelGrid` by `;` and insert each leg into **`dmxChannels`** with the same scoped `PropId`.
- In wiring views, **Color = 'RGB'** for DMX.

---

### DeviceType = "None" (non-wired inventory)
- For **each** such `PropClass`, create **N instances** where `N = max(1, int(MaxChannels))`.
- **Instance `PropID`**: `{PreviewId}:{RawPropId}:{i:02d}`
- **Instance `LORComment`** (Display Name): `"<Comment>-<i:02d>"`  
  (e.g., `FTString-01-Red-01`, `-02`, …).
- Carry attributes (e.g., `TraditionalColors` → `Color`); wiring fields are **NULL**.
- Included in wiring views as `Source='PROP'` and `DeviceType='None'`.

---

## Naming Invariants
- **Channel_Name** = XML `Name` (Sequencer label) → **never modified**.
- **Display_Name** = XML `Comment` (inventory key) → **never modified**.
- **Suggested_Name** (views only, not stored) is dashified and may append:
  - Side/hand (DS/PS/LH/RH) inferred from `LORComment`/`Tag`
  - Group letter (from `Tag`)
  - Disambiguator (e.g., `-UID-Start` for LOR, `-U<Universe>:<Channel>` for DMX)  
  DeviceType=None uses the suffixed `Display_Name`.

---

## Wiring Views (v6)

We create two views:

- **`preview_wiring_map_v6`** — unified map across `props`, `subProps`, `dmxChannels`, and `DeviceType=None`.
- **`preview_wiring_sorted_v6`** — convenience ordering.

**Columns (order):**
- `PreviewName`, `Source` (`PROP`/`SUBPROP`/`DMX`)
- `Channel_Name` (raw `Name`), `Display_Name` (raw `LORComment`), `Suggested_Name`
- `Network`, `Controller` (UID for LOR, Universe for DMX), `StartChannel`, `EndChannel`
- `Color` (`RGB` for DMX; pass-through otherwise), `DeviceType`, `LORTag`

**Sort (final view):**
```sql
ORDER BY
  PreviewName COLLATE NOCASE,
  Network     COLLATE NOCASE,
  Controller,
  StartChannel;
```

**Row sources:**
- LOR masters → `Source='PROP'`
- LOR subprops → `Source='SUBPROP'`
- DMX → `Source='DMX'`, `Color='RGB'`, `Controller=Universe`
- DeviceType=None → `Source='PROP'`, no wiring values

---

## Debugging & Validation

- Masters per display:
```sql
SELECT PreviewId, LORComment, COUNT(*) AS rows
FROM props
GROUP BY PreviewId, LORComment
ORDER BY rows DESC;
```

- Manual subprop promotion check:
```sql
SELECT LORComment, COUNT(*) FROM props    GROUP BY LORComment;
SELECT LORComment, COUNT(*) FROM subProps GROUP BY LORComment;
```

- DMX legs per prop:
```sql
SELECT PropId, COUNT(*) FROM dmxChannels GROUP BY PropId;
```

- DeviceType=None instances:
```sql
SELECT PropID, Name, LORComment, DeviceType, Color
FROM props
WHERE DeviceType='None'
ORDER BY LORComment;
```

---

**Notes**
- All inserts use preview-scoped IDs and `INSERT OR REPLACE`, so re-processing the same previews is safe and idempotent.
- Base schema remains unchanged; views handle presentation/derivations.
