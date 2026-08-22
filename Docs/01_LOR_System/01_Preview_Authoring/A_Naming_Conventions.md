# Prop and Display Naming Conventions

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | LOR Preview Authoring |
| Task | Name Displays and channels correctly |
| Audience | Preview authors and programmers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-22 |

## Purpose

Use these rules when creating or editing channels and Displays in LOR.

Correct naming keeps channels together in the LOR grid and keeps the physical Display name consistent with labels and field wiring.

## Two LOR Fields Matter

LOR uses two different fields for two different jobs:

| LOR field | What it is used for |
|---|---|
| **Name** | Channel name used for programming and sorting in the LOR grid |
| **Comment** | Physical MSB Display Name |

Do not use the **Name** field as the physical Display Name.

---

# 1. Name Field — Channel Naming

Use this general format:

```text
<Stage Code> <Controller ID>-<Channel> <Description>
```

Example:

```text
TC 7B-01 Hippo Box
```

## Stage Code

Use the two-letter Stage abbreviation.

Examples:

- `FT` = Festive Trees
- `FC` = Food Collection
- `WW` = Winter Wonderland

## Controller ID

Use the controller Unit ID exactly as assigned.

Examples:

```text
7B
1F
20
```

Use uppercase letters. Do not add unnecessary leading zeroes.

## Channel Number

Always use two digits for AC controller channels:

Correct:

```text
7B-01
7B-02
7B-10
```

Incorrect:

```text
7B-1
7B-2
```

The two-digit format keeps channels in the correct order when LOR sorts them alphabetically.

## Extra Description

Add a short description when it helps identify what the channel controls.

Examples:

```text
TC 7B-01 Hippo Box
TC 7B-04 Hippo Body Mid
TC 7B-05 Hippo Body Full Head
```

For animated Displays, descriptions such as `Lid Open`, `Lid Closed`, `Arm Up`, or `Arm Down` can make programming easier.

---

# 2. Unused Channels — SPARE

Every unused controller channel must still appear in the Preview.

Do not leave unexplained gaps.

Example:

```text
TC 7B-11 Spare
TC 7B-12 Spare
```

For an unused channel:

1. Use the normal Stage, Controller ID, and two-digit channel format.
2. End the channel Name with `Spare`.
3. Use `SPARE` in the Comment field.
4. Keep the channel visible in the Preview.

This makes unused controller capacity easy to see and prevents someone from accidentally assuming a used channel is available.

---

# 3. When a Display Is Moved to Different Channels

When a Display is moved away from an old channel, **do not simply rename the old Display channel to SPARE and do not just hide it**.

LOR can keep information from the old Display attached to that channel even after the name is changed. That can cause the old channel and the moved Display to be treated as the same object later.

For every channel that becomes unused:

1. Delete the old Display channel/Prop from that location.
2. Create a new SPARE channel in its place.
3. Use the normal channel naming format.
4. Use `SPARE` in the Comment field.
5. Keep the new SPARE visible.

The important rule is simple:

> **Moved Display: delete the old channel object and create a new SPARE. Do not just rename or hide the old one.**

If you are unsure whether an old Display object was properly removed, stop and ask before exporting the Preview.

---

# 4. Comment Field — Physical Display Name

The **Comment** field contains the physical MSB Display Name.

Examples:

```text
FC-Arch-01
RA-Arch-DS-01
EC-Elf-P2-06
TC-ChristmasHippo
```

The Comment value should match the name used on the physical Display label and in field documentation.

## Display Name Rules

- No spaces.
- Start with the two-letter Stage code.
- Use hyphens to separate meaningful parts.
- Keep the name stable unless the physical Display identity is intentionally being changed.

General format:

```text
<Stage Code>-<DisplayName>-<Optional Variation>-<Optional Number>-<Optional Color>
```

Examples:

```text
IT-EntryArchWrap-DS
IT-SteelEntryArch-PS
FC-CarCounterArch-Grn
EC-Elf-P2-06
WF-MiniTree-G-04
GG-Elden-20-01
```

Do not run attributes together when a hyphen is needed.

Wrong:

```text
EntryArchWrapDS
SteelEntryArchPS
CarCounterArchGrn
```

Correct:

```text
IT-EntryArchWrap-DS
IT-SteelEntryArch-PS
FC-CarCounterArch-Grn
```

---

# 5. One Physical Display with Several Channels

Several channels may belong to one physical Display.

All of those channels must use the **same Comment value**.

Example:

| Channel Name | Comment |
|---|---|
| `TC 7B-01 Hippo Box` | `TC-ChristmasHippo` |
| `TC 7B-04 Hippo Body Mid` | `TC-ChristmasHippo` |
| `TC 7B-05 Hippo Body Full Head` | `TC-ChristmasHippo` |

The channel Names can be different because they describe different parts of the Display. The Comment stays the same because they belong to the same physical Display.

---

# 6. Several Physical Displays Must Have Separate Names

If several physical panels or units are separate items in storage and setup, each one needs its own Display Name.

Example:

```text
TC-CarolerPanel-01
TC-CarolerPanel-02
TC-CarolerPanel-03
```

Even if they are programmed together, they are still separate physical Displays.

---

# 7. Inventory-Only Displays in LOR

Some physical items need to be listed even though they have no controller or channel assignment.

In LOR, use **Undetermined** for these items.

Examples may include:

- spare physical duplicates;
- supports or stands;
- future expansion pieces; and
- other physical items that need to exist in inventory but are not wired in the Preview.

These items still need a valid Display Name in the Comment field.

## Creating Several Identical Inventory Items

When LOR uses **Max Circuits per Unit** to create several physical items, set the quantity intentionally.

Example:

```text
Comment: FC-WrapStand
Max Circuits per Unit: 32
```

LOR can create:

```text
FC-WrapStand-01
FC-WrapStand-02
...
FC-WrapStand-32
```

### Important

The default value may be larger than the number you actually need.

Always check **Max Circuits per Unit** before saving so you do not accidentally create extra inventory items.

---

# 8. Before You Finish

Check the Preview for the following:

- [ ] Every channel uses the correct Stage code.
- [ ] Controller IDs are correct.
- [ ] AC channels use two digits.
- [ ] Unused channels are shown as SPARE.
- [ ] Moved Displays were removed from their old channels and new SPARE channels were created.
- [ ] Every physical Display has the correct Comment value.
- [ ] Channels belonging to one physical Display use the same Comment.
- [ ] Separate physical Displays have separate Display Names.
- [ ] Inventory-only quantities were checked before saving.

## Expected Result

The LOR grid is easy to read, channels sort correctly, and each physical Display has one clear name that matches field documentation.

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [Preview Authoring Home](README.md)

## Related Engineering

- [Historical LOR Naming Data Contract](C_LOR_Naming_Data_Contract.md)
- [LOR Parser Architecture](../02_Data_Extraction/LOR_Preview_Parser_Architecture.md)

## Revision History

- 2026-08-22 — Rewritten for Preview authors in plain language. Parser, UUID, SQLite, PostgreSQL, and reconciliation details were removed from the operator instructions while preserving the required naming and SPARE rules.
- 2026-08-02 — Previous current naming revision.
