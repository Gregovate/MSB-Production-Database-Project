# FieldWiring Field Presentation Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction |
| Sub-project | FieldWiring |
| Predecessor reference | FormView 0.3.1 Wiring View |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

This document records the field-facing presentation requirements for the browser-based FieldWiring application.

The requirements are derived from the current FormView Wiring View and operator review of the actual field information needed while connecting Displays to controllers.

This document defines presentation behavior only. It does not authorize application-code or database-schema changes.

## Field Objective

A technician should be able to answer quickly:

> Which controller and channel does this Display connection use, what is the LOR channel name, and which network applies?

The browser UI must prioritize that task over exposing every engineering field available in the underlying LOR model.

## FormView Controls to Preserve Functionally

FormView currently provides three useful and independent wiring controls:

- **Field wiring mode** — when checked, reduce the detailed wiring model to the practical FIELD connection set; when unchecked, show the fuller wiring map;
- **Displays only** — restrict to master Display/`PROP` rows when an engineering/operator use case requires it;
- **Hide SPAREs** — suppress intentionally unused spare channels.

FieldWiring does not need to reproduce the Tkinter checkboxes literally, but equivalent behavior must remain available.

### Field Wiring checked versus unchecked

The two FormView modes must not be conflated.

**Field Wiring unchecked** presents the fuller wiring map. It may contain Display/master rows, SubProp rows, shared/internal relationships, and other detailed channel records useful for engineering or troubleshooting.

**Field Wiring checked** presents the reduced practical field-connection set. The surviving rows are the connections the technician needs for field hookup.

A surviving field connection may legitimately originate from either a master Display row or a SubProp row. Therefore Field Wiring must not be implemented as `Source = 'PROP'`.

A valid field row can legitimately have:

```text
Source = SUBPROP
ConnectionType = FIELD
```

The practical distinction is:

- **Field Wiring** controls whether the operator sees the reduced FIELD connection set or the fuller wiring map;
- **Displays only** is a separate optional Display/master-row filter;
- **Hide SPAREs** is a separate spare-channel filter.

## Primary Field Information

The normal FieldWiring screen should emphasize only the information required during setup:

1. **Controller**
2. **Channel** — the current `StartChannel`
3. **Channel Name**
4. **Display Name**
5. **Network**
6. **Source classification** — compact visual treatment only

### Controller

Controller UID / unit identifier.

This should remain compact and visually easy to scan while working through a controller.

### Channel

Use the shorter field-facing label **Channel** rather than `StartChannel`.

For normal LOR field wiring this is the physical output/plug number the technician uses.

### Channel Name

The LOR sequencer channel name.

This must remain distinct from Display Name because the wiring drawing uses Channel Names to identify physical connection locations.

### Display Name

The physical Display identity/name.

Display Name does not need to be repeated on every line when consecutive rows belong to the same Display. The UI may group rows under one Display heading or visually merge/suppress repeated Display Name values.

The underlying data must remain row-complete even when the Display label is presented once per group.

### Network

The applicable LOR network remains required field information.

It may be presented compactly because values such as `Regular`, `Aux A`, and similar network identifiers are generally short.

## Compact Display Grouping

To reduce horizontal and vertical real estate, the preferred field presentation may group wiring rows by Display.

Conceptually:

```text
PB-MommaBear
Controller   Ch   Channel Name                    Network
70           1    PB zMomma Body                  Regular
70           2    PB zMomma Head Forward          Regular
70           3    PB zMomma Head Side             Regular

PB-ThrowingBear-DS
Controller   Ch   Channel Name                    Network
70           1    PB 1 LH Bear Body               Regular
70           4    PB LH-1 70-04                   Regular
```

This is presentation grouping only.

It must not alter field-lead identity or collapse separate circuit rows.

### Shared-circuit requirement

If more than one Display legitimately uses the same controller/channel, each Display relationship must remain visible.

Grouping by Display must therefore not deduplicate rows merely because Controller + Channel are the same.

## Source Classification

Source is useful to distinguish the kind of wiring row, but it should not consume a wide text column in the normal field view.

For field presentation, the useful source concepts are:

- **Display** — underlying master `PROP` row;
- **SubProp** — underlying `SUBPROP` row;
- **Spare** — intentionally unused spare channel/row when SPAREs are being shown.

The browser may translate raw engineering values into these plain-language labels without changing the underlying data.

`Spare` is a field presentation classification; the existing FormView data may identify SPARE status from the Display/Channel naming and the Hide SPAREs filter rather than from a literal `Source = 'SPARE'` database value.

### Compact Source presentation

Preferred approach:

- do not dedicate a normal full-width `Source` column;
- use a narrow badge, symbol, or restrained row marker for **Display**, **SubProp**, and **Spare**;
- provide the full underlying engineering value in optional details.

A small textual abbreviation may accompany any color treatment so color is not the only indicator.

Example concept:

```text
D   Display/master row
S   SubProp row
SP  Spare row
```

The exact badge letters/colors are a later UI design decision.

When **Hide SPAREs** is enabled, Spare rows disappear entirely.

## ConnectionType / Field Classification

`ConnectionType` is not a normal field column.

Its practical purpose is to support the Field Wiring reduction logic.

When Field Wiring is checked, the visible result is the FIELD connection set, so repeating `FIELD` on every row wastes horizontal space.

When Field Wiring is unchecked, the operator is intentionally looking at the fuller wiring map; the UI should communicate that mode globally rather than relying on a repetitive ConnectionType column.

Therefore:

- hide `ConnectionType` from the normal compact table;
- show a clear global indication of whether **Field Wiring** is ON or OFF;
- retain ConnectionType in engineering details/data export where useful.

## DeviceType

`DeviceType` is not required in the normal field connection view.

Values such as `LOR` are engineering/device metadata and consume space without helping the normal hookup task.

Therefore DeviceType should be hidden from the normal table and available only in engineering/details views when needed.

## Tag

`LORTag` is optional engineering/programming information.

It should not consume permanent horizontal space in the normal field wiring view.

Preferred behavior:

- hidden by default;
- available through **Engineering details**, expandable row, tooltip/popover, or an optional column control;
- available in engineering/data export where useful.

## Recommended Normal Field Layout

The compact visible data should target approximately:

```text
Src | Controller | Ch | Channel Name | Display | Network
```

where `Src` is only a very narrow source marker, not a full text column.

When grouped by Display, the preferred form is:

```text
Display: <Display Name>
Src | Controller | Ch | Channel Name | Network
```

This removes the largest repeated field from every line while retaining the full connection detail.

On the normal Field Wiring screen:

```text
ConnectionType   hidden
DeviceType       hidden
LORTag           hidden by default
Source           compact marker/badge
Display Name     group heading when practical
```

## Sorting

Normal field order remains controller/plug oriented unless Display grouping is selected.

Ungrouped default:

```text
Controller -> Channel -> Display
```

Grouped-by-Display presentation:

```text
Display group
    -> Controller
        -> Channel
```

Controller ordering must remain hexadecimal-aware.

The application may offer alternate sorts, but the normal field view must be deterministic.

## Phone and Tablet Real-Estate Rule

The normal view should avoid forcing technicians to horizontally scroll across engineering-only columns.

On narrow screens:

- Source should be a very narrow marker;
- Controller and Channel should remain immediately visible;
- Channel Name should receive the largest available width;
- Display should become the group heading rather than a repeated column when practical;
- Network may use a compact badge/short field;
- ConnectionType, DeviceType, and Tag should move to optional details.

The wiring drawing/image remains part of the same field context and must remain practically accessible without consuming all table space.

## Printing / Hard Reports

Hard reports should use the same compact field-oriented data hierarchy rather than reproducing every internal database field.

The normal printed wiring information should emphasize:

```text
Display
Controller
Channel
Channel Name
Network
```

A compact Source marker may be included when useful. ConnectionType, DeviceType, and Tag should normally be omitted from the field printout unless an engineering report explicitly requests them.

Every FieldWiring hard report remains subject to the FieldWiring expiration/currentness contract.

## Acceptance Examples

FieldWiring presentation testing should include at minimum:

1. Field Wiring unchecked, confirming the fuller wiring map remains available;
2. Field Wiring checked, confirming the reduced practical FIELD set;
3. one Display with several sequential channels;
4. one Display whose surviving field connections originate from both `PROP` and `SUBPROP` rows;
5. two Displays sharing the same controller/channel;
6. a Stage with SPARE rows, confirming Hide SPAREs removes them and that they can be identified as Spare when shown;
7. Displays-only mode, confirming it is distinct from Field Wiring mode;
8. Regular and auxiliary network examples;
9. a narrow phone/tablet viewport;
10. a printed/hard report using the compact grouping model;
11. Engineering details showing raw Source, ConnectionType, DeviceType, and LORTag without forcing those fields into the normal view.

## Related Documents

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [Wiring System](README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
