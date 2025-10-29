# Naming Conventions

---
title: Prop and Display Naming Conventions
version: 2025-10-29
author: Greg Liebig / Engineering Innovations, LLC
---

# Prop and Display Naming Conventions

These conventions ensure consistent naming across **LOR sequencing**, **display database records**, and **physical labels** used in the field.  
Following these rules keeps previews, wiring maps, and channel assignments aligned and machine-readable.

---

## 1. Purpose

There are two main naming layers:

1. **LOR Channel Naming Convention** — how channels are named for sequencing and motion order.
2. **Display Naming Convention** — how physical displays and sub-props are identified in the database and in the field.

---

## 2. LOR Channel Naming Convention

Light-O-Rama sorts channels alphabetically.  
To keep multi-channel motion props in proper order, use the format:

LL DisplayOrAbbrev UID-Channel Description

pgsql
Copy code

| Element | Description |
|----------|-------------|
| **LL** | Two-letter abbreviation of the stage or display group. Used to group all channels belonging to that preview. |
| **Display / Abbreviation** | Display name or short form that ties all channels for that prop together. |
| **UID** | Unit ID (controller address). |
| **Channel** | Channel or port number on that controller. |
| **Description** | Brief functional name (e.g., *Head Bob*, *Left Arm 1*, *Red*). |

**Example**

EC Cond L28-15 Conductor Head

yaml
Copy code

### ⚠️ Note
If the **UID** or **channel** changes, the preview and harness labels must be updated.  
This is why display-level naming (below) is used as the true database key.

---

## 3. Display Naming Convention

Every display, sub-prop, and panel we build, maintain, and store must have a **unique identifier**.

That identifier:
- Appears on the **physical label** attached to the display.
- Is stored in the **Comment field** in LOR.
- Allows every channel to trace back to the correct physical panel.

---

### 3.1 Displays and Sub-Props

| Term | Definition |
|------|-------------|
| **Display** | The complete physical panel (e.g., Conductor, Note, or Elf). |
| **Sub-Prop** | Any individual motion element belonging to that Display. All sub-props share the exact same **Display Name** in the Comment field. |

**Example**

> *ElfConductor* is one display panel with multiple sub-props controlling arms, head, etc.  
> Each sub-prop still uses `ElfConductor` in its Comment field.

---

### 3.2 Single-Channel Displays

Some displays have only one lighting element. Each must still have a unique identifier.

**Examples**

| Pattern | Display Names |
|----------|----------------|
| **Elves** (4 patterns × 8 each) | `Elf-P1-1 … Elf-P1-8`, `Elf-P2-1 … Elf-P2-8`, `Elf-P3-1 … Elf-P3-8`, `Elf-P4-1 … Elf-P4-8` |
| **Notes** (4 patterns × 2 each) | `Note-A-1, Note-A-2`, `Note-B-1, Note-B-2`, `Note-C-1, Note-C-2`, `Note-D-1, Note-D-2` |

---

### 3.3 Multi-Channel Displays (LOR or DMX)

For props with multiple channels inside one panel, the **Display Name** remains identical across all channels.

**Example**

| Channel | Description | Comment |
|----------|--------------|----------|
| `EC Cond L28-15` | Conductor Head | Conductor |
| `EC CondHeadBob` | Head Bob | Conductor |
| `EC Cond LH 1 L28-09` | Left Hand Position 1 | Conductor |
| `EC Cond LH 2 L28-10` | Left Hand Position 2 | Conductor |
| `EC Cond LH 3 L28-11` | Left Hand Position 3 | Conductor |
| `EC Cond RH 1 L28-14` | Right Hand Position 1 | Conductor |
| `EC Cond RH 2 L28-13` | Right Hand Position 2 | Conductor |
| `EC Cond RH 3 L28-12` | Right Hand Position 3 | Conductor |

---

## 4. Display Name Format

<LL>-<DisplayName>-<Variation>-<Sequence>-<Color>

yaml
Copy code

| Segment | Meaning |
|----------|---------|
| **LL** | Two-letter stage abbreviation (optional). |
| **DisplayName** | **Required.** The prop or panel name in CamelCase, no spaces. Examples: `Elf`, `Note`, `CandyCane`, `MiniTree`. |
| **Variation** | Distinguishes multiple versions of a display (location, pattern, section, etc.). Examples: `DS`, `PS`, `A`, `B`, `C`, `P1`, `P2`, `LH`, `RH`, `M`, `F`. |
| **Sequence** | Instance number of that variation. Always pad to two digits (`01`, `02`, …). |
| **Color** | Optional one-letter suffix appended to the sequence (`R`, `G`, `B`, `W`, `Y`). Use full color name only when clarity requires. |

---

### Examples

| Type | Example | Description |
|------|----------|-------------|
| Pattern-based | `EC-Elf-P2-06` | Elf, Pattern 2, unit #6 |
| Pattern-based | `EC-Note-B-01` | Note, Pattern B, unit #1 |
| Color-based | `ST-Star-Red-01` | Red Star, unit #1 |
| Color-based | `WF-MiniTree-G-04` | Green Mini-Tree, unit #4 |
| Location-based | `RA-Arch-DS-01` | Arch on Driver Side, unit #1 |
| Location-based | `RA-Arch-PS-01` | Arch on Passenger Side, unit #1 |
| Single panel | `EC-ElfConductor` | One panel with multiple sub-props |

---

### 4.1 DeviceType = None

When a prop’s **DeviceType** is `None` (display-only object):
- Omit the `<Seq>` portion.
- Color or variation can still be used if helpful for identification.

---

### 4.2 MaxChannels Field

The `MaxChannels` field defines how many channels belong to a display.
- Minimum = 1  
- Upper limit can exceed 16 (use as needed).

---

## 5. Inventory and Physical Labels

Every display label in the field should:
- Match the **Comment field** value in LOR.
- Use a printed or engraved tag with the display name and unit number.
- Remain consistent through wiring harnesses and storage bins.

This identifier forms the link between:
- The **physical prop**
- The **preview database**
- The **inventory and maintenance system**

---

## ✅ Summary

This standard keeps all names **consistent, human-readable, and machine-safe** across:
- LOR sequencing software
- Preview parser database
- Wiring maps and Excel reports
- Field labeling and inventory control

---

> **Revision History**  
> - GAL 25-10-29 — Initial merge from legacy Google Doc and repo naming_conventions.md  
> - GAL 25-10-30 — Formatting cleanup, added DeviceType = Non