title: Prop and Display Naming Conventions
Filename: A_Naming_Conventions.md
version: 2026-02-22
author: Greg Liebig / Engineering Innovations, LLC
---

# Prop and Display Naming Conventions

These conventions ensure consistent naming across:

- **LOR sequencing (Channel Grid)**
- **Display database records (Postgres / SQLite)**
- **Physical labels used in the field**
- **Field wiring exports**

If naming rules are not followed, channels scatter in the grid, wiring reports drift from reality, and physical labels no longer match database records.

This document prevents chaos.

---

## 1. Two Separate Naming Layers in LOR

LOR uses two different fields that serve different purposes:

| Field | Purpose | Spaces Allowed | Used as Database Key |
|--------|----------|----------------|----------------------|
| **Name** | Channel grid sorting & programming | Yes | No |
| **Comment** | Physical display identifier | No | Yes |

These fields must not be confused.

---

## 2. LOR Name Field (Channel Naming Convention)

The **Name field controls alphabetical sorting inside the LOR grid.**

LOR sorts strictly alphabetically.  
Improper numbering or inconsistent formatting causes channels to scatter.

### 2.1 Required Structure

Recommended format:

`<LL> <Group> <UID>-<CH> <Description>`

Example:

`TC 7B-01 Hippo Box`

---

### 2.2 UID and Channel Rules (CRITICAL)

**UID**
- Controller ID in HEX
- Uppercase
- No leading zero padding
- Example: `7B`, `1F`, `20`

**Channel**
- Always 2-digit padded
- `01–16`
- Even if wiring exports show a single digit

Correct:
- `7B-01`
- `7B-02`
- `7B-10`

Incorrect:
- `7B-1`
- `7B-2`

If channels are not padded, alphabetical sorting breaks:

Wrong order:

- 7B-1
- 7B-10
- 7B-11
- 7B-2


Correct order:

- 7B-01
- 7B-02
- 7B-03
- 7B-10

---

### 2.3 Real Example (Hippo + Carolers)

![Channel Grid Example](Docs/images/naming_conventions_channel_grid.png)

This grid shows:

- One multi-state animated display (Hippo)
- Three physical panels (CarolerPanel-01..03)
- Proper grouping by padded channel numbers

The naming works because:
- All channels begin with consistent stage prefix
- Channels are padded
- Related elements sort together

### 2.4 Unused Channels (SPARE Rule — REQUIRED)

Any unused channel on a controller must be explicitly added to the preview.

Do NOT leave gaps.

Unused channels must:

- Follow the exact same naming structure
- Use the same Stage and Group prefix
- Use correct HEX UID
- Use 2-digit padded channel number
- End with the word `Spare`

Example:

TC 7B-11 Spare  
TC 7B-12 Spare  

Why this is required:

- Makes unused capacity immediately visible in the Channel Grid
- Prevents accidental reuse of a channel already assumed to be empty
- Keeps controllers fully documented
- Allows quick identification of expansion space during programming

Unused channels must remain in the preview even if no physical wiring exists.

When a Spare channel is later assigned to a display:
- Rename the channel
- Update wiring documentation
- Remove the `Spare` designation
  
---

## 3. Comment Field (Display Identifier)

The **Comment field defines the Display Name** used for:

- Physical labels
- Database joins
- Wiring exports
- Inventory tracking
- Maintenance records

This is the true identity of the physical display.

---

### 3.1 Comment Field Rules

- No spaces allowed
- Must start with 2-letter stage abbreviation
- Use hyphen as structural separator
- Must remain stable over time

Examples:

Standard stages:
- `FT-Arch-01`
- `RA-Arch-DS-01`
- `EC-Elf-P2-06`

GG stage (numeric prefix allowed):
- `GG20-Elden`
- `GG20-Elden-01`
- `GG30-V2Elden`
- `GG30-V2Elden-01`

---

### 3.2 Displays vs Sub-Props

| Term | Definition |
|------|------------|
| **Display** | One physical panel or unit |
| **Sub-Prop** | Logical motion element within a display |

All sub-props must share the exact same **Comment value** as their parent display.

Example:

| Channel Name | Comment |
|--------------|---------|
| `TC 7B-01 Hippo Box` | `ChristmasHippo` |
| `TC 7B-04 Hippo Body Mid` | `ChristmasHippo` |
| `TC 7B-05 Hippo Body Full Head` | `ChristmasHippo` |

---

### 3.3 Example – Multi-Panel Display (Caroler)

![Visualization Example](Docs/images/naming_conventions_visualization.png)

Three physical panels:

- `CarolerPanel-01`
- `CarolerPanel-02`
- `CarolerPanel-03`

Each has its own Comment value.

Even if programming groups them visually, they remain separate physical units in inventory and wiring.

---

## 4. Display Name Format (Comment Field)

`<Stage>-<DisplayName>-<Variation>-<Sequence>-<Color>`

| Segment | Meaning |
|----------|---------|
| Stage | Two-letter stage code |
| DisplayName | CamelCase, no spaces |
| Variation | Optional location/version identifier |
| Sequence | Always 2-digit padded |
| Color | Optional suffix |

Examples:

- `EC-Elf-P2-06`
- `RA-Arch-DS-01`
- `WF-MiniTree-G-04`
- `GG20-Elden-01`

---

### 4.1 DeviceType = Undetermined (Inventory-Only Displays)

![Undetermined DeviceType Example](Docs/images/naming_conventions_undetermined.png)

In the LOR preview editor, DeviceType is set to:

Undetermined

During SQLite parsing and Postgres ingestion, this becomes:

DeviceType = None

Operationally, both represent the same thing:

A physical inventory item with no controller assignment and no channel grid usage.

---

#### Use Cases

- Physical duplicates of programmed displays
- Arch supports
- Wrap stands
- Frame stands
- Future expansion inventory
- Volunteer Trailer Steps
- Igloo wagon for No Left Turn
- Attional displays were we duplicate the controllers for programming simplification like Emojis

---

#### Quantity Creation (Max Circuits per Unit)

When creating inventory-only items:

- Set "Max Circuits per Unit" equal to the required quantity.
- LOR automatically generates suffixed records:
  - `-01`, `-02`, `-03`, etc.

Example:

Comment:
`FC-WrapStand`

Max Circuits per Unit:
`32`

Generated records:
- `FC-WrapStand-01`
- `FC-WrapStand-02`
- ...
- `FC-WrapStand-32`

If Max Circuits per Unit = 1:
- No suffix is added.

---

#### ⚠️ Critical Warning

The default value for "Max Circuits per Unit" is 16.

If not changed intentionally, LOR will create 16 inventory records automatically.

This will:

- Inflate inventory counts
- Pollute the database
- Require manual cleanup

Always verify this value before saving.

---

#### Rules

Inventory-only entries:

- Must follow full Comment naming rules
- Must not contain Network, UID, or ChannelGrid
- Must represent real physical inventory

These entries appear in database ingestion but do not affect wiring exports.
---

## 5. Field Wiring Alignment

![Field Wiring Example](Docs/images/naming_conventions_field_wiring.png)

Field wiring exports rely on the Comment value.

If Comment naming is incorrect:
- Wiring sheets become inaccurate
- Displays cannot be located in the field
- Maintenance records break

---

## 6. Inventory and Physical Labels

Every display label must:

- Match the Comment field exactly
- Be permanently attached to the display
- Match database and wiring documentation

The Comment value is the backbone of:

- Physical inventory
- Storage tracking
- Repair history
- Field setup instructions

---

## ✅ Summary

| Field | Controls | Critical Rule |
|--------|----------|--------------|
| Name | Programming & Grid Sorting | Pad channels to 2 digits |
| Comment | Physical Identity | No spaces, stable, structured |

Naming consistency prevents:

- Channel grid chaos
- Lost programming
- Wiring mismatches
- Inventory drift

---

> **Revision History**
> - GAL 25-10-29 — Initial merge  
> - GAL 25-10-30 — Formatting cleanup  
> - GAL 26-02-22 — Major clarification: separated Name vs Comment logic, added UID padding rule, added real-world examples with grid and wiring screenshots