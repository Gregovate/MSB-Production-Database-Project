# Core Comparison Logic — How `lor_core.core_items_from_lorprev` Detects Changes

_Companion to **Preview Merger — Reference (v1)**_  
_Added in build GAL 2025-10-19 to support multi-user merge consistency._

---

## Purpose
`lor_core.core_items_from_lorprev()` defines **what counts as a real change** between two `.lorprev` files during the merge process.  
It provides a **normalized “core signature”** for each preview so that the merger can decide when a preview must be re-staged.

This logic is the single source of truth for **multi-user merge comparisons**—every operator’s export is evaluated the same way, regardless of who created it or how LOR wrote the XML.

---

## 1. Source fields read from each `.lorprev`
Each preview contains one `<PreviewClass>` root and multiple `<PropClass>` entries.  
For every `<PropClass>`, the function reads:

| Field | From Attribute | Normalized As | Purpose |
|-------|----------------|---------------|----------|
| DeviceType | `DeviceType` | upper-case (`""` → `"NONE"`) | Determines parsing rule |
| DisplayName | `Comment` | lower-case / trimmed | DB “group-by” key |
| ChannelName | `Name` | lower-case / trimmed | Individual channel label |
| ChannelGrid | `ChannelGrid` | split into semicolon-delimited legs | Wiring layout for LOR/DMX |

File metadata such as author, revision, and timestamps are **not** part of the core.

---

## 2. Core tuple rules

Each prop contributes one or more normalized tuples to the preview’s **core set**.

| DeviceType | Tuple form | Notes |
|-------------|-------------|-------|
| **NONE** | `("NONE", comment, name)` | Logical “display only” props. Grouped by Comment + Name. |
| **LOR** | `("LOR", network, uid, start, end, color)` | One per leg in `ChannelGrid`. Detects wiring topology changes. |
| **DMX** | `("DMX", network, universe, start, end)` | One per leg. Detects DMX patch differences. |
| **Other / Unknown** | `(<DEV>, comment, name)` | Fallback when type is unrecognized. |

If a LOR/DMX prop has **no ChannelGrid**, a placeholder tuple is added so “missing wiring” is still detectable.

---

## 3. Multiplicity and order
- Every tuple is counted; duplicates are preserved using an ordinal suffix.  
  → Changes in the **number** of identical props (added/removed copies) are detected.  
- Order within the file does **not** matter.

---

## 4. Label-health tracking
To catch “blank label” fixes that don’t alter wiring, the function also adds synthetic tuples:

```
("LBLMISS", <DeviceType>, "COMMENT", i)
("LBLMISS", <DeviceType>, "NAME", i)
```

These markers ensure that filling in a previously blank Comment or Name field triggers a stage event.

---

## 5. Comparison process
1. Build the full multiset of tuples for both author and staged previews.  
2. Hash and compare the sets.  
3. If any tuple differs — new, missing, or changed — the core is **different**, and the preview **stages**.

---

## 6. What changes are detected

| Change type | DeviceType=None | LOR | DMX |
|--------------|-----------------|-----|-----|
| **Comment (DisplayName)** | ✅ (key change) | ❌ (unless blank ↔ filled) | ❌ (unless blank ↔ filled) |
| **Name (ChannelName)** | ✅ | ❌ (unless blank ↔ filled) | ❌ (unless blank ↔ filled) |
| **Fix blank Comment** | ✅ | ✅ (via `LBLMISS`) | ✅ (via `LBLMISS`) |
| **Fix blank Name** | ✅ | ✅ (via `LBLMISS`) | ✅ (via `LBLMISS`) |
| **Change UID / Universe** | n/a | ✅ | ✅ |
| **Change Start / End channel** | n/a | ✅ | ✅ |
| **Change Color (LOR only)** | n/a | ✅ | n/a |
| **Add / remove leg** | n/a | ✅ | ✅ |
| **DeviceType change (e.g., LOR → NONE)** | ✅ | ✅ | ✅ |
| **Re-order props** | Ignored | Ignored | Ignored |

✅ = difference detected → preview will stage  
❌ = ignored (labels only)

---

## 7. Examples

| Scenario | Detected? | Why |
|-----------|------------|----|
| Add a new “Mailbox” prop to Post Office | ✅ | New `(NONE, comment, name)` tuple |
| Fix blank Comment on a LOR prop | ✅ | `LBLMISS` count drops |
| Rename a LOR prop “Star-Left”→“Left Star” | ❌ | Same wiring; label change only |
| Shift StartChannel 100→112 | ✅ | ChannelGrid tuple changed |
| Controller UID change 0A→0B | ✅ | UID field changed |
| Add/remove DMX leg | ✅ | Multiplicity changed |
| Change DeviceType =LOR→None | ✅ | Tuple family differs |

---

## 8. Stats returned
`core_items_from_lorprev()` also returns summary stats used in reports:

```python
{
  "props_total": int,
  "props_none": int,
  "legs_lor": int,
  "legs_dmx": int,
  "missing_comment": int,
  "missing_name": int
}
```

These feed CSV columns such as:
`PropCountAuthor`, `PropCountStaged`, `MissingComment*`, `MissingName*`.

---

## 9. Integration points

- **preview_merger.py**  
  Calls `lor_core.core_items_from_lorprev()` inside `diff_core_fields()`.  
  The result determines whether a winner differs from what’s staged.

- **parse_props_v6.py**  
  Remains the database builder; untouched.  
  `lor_core` simply mirrors its grouping logic for comparison only.

---

## 10. Rationale
- Centralizes “core diff” logic in one module (`lor_core.py`) to prevent drift.  
- Matches how `parse_props_v6` builds database records.  
- Eliminates false negatives for `DeviceType=None` props and label-repair scenarios.  
- Keeps staging deterministic across all users and systems.

---

## 11. Future extension ideas
- Optional “label-text hash” for non-blank LOR/DMX labels if we decide those should also trigger staging.  
- Configurable ignore lists (e.g., controller renumbering without wiring move).  
- Per-prop diff logging for debugging complex previews.

---

> **In short:**  
> A preview stages when its *meaningful wiring or display structure* changes — not when just metadata or file order does.
