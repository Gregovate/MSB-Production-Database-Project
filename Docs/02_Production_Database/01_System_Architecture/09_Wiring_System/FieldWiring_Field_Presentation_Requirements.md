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

FormView currently provides three useful wiring filters:

- **Field wiring mode** — reduce the detailed wiring model to one practical field lead per Display/circuit relationship;
- **Displays only** — restrict to master `PROP` rows when an engineering/operator use case requires it;
- **Hide SPAREs** — suppress intentionally unused channels.

FieldWiring does not need to reproduce the Tkinter checkboxes literally, but equivalent behavior must remain available.

### Important distinction: Field Wiring is not PROP-only

Field Wiring mode removes duplicate/internal wiring detail. It must not be implemented simply as `Source = 'PROP'`.

A surviving practical field connection may legitimately have:

```text
Source = SUBPROP
ConnectionType = FIELD
```

when that SubProp row contains the physical channel leg that must be connected.

Therefore:

- **Field Wiring** means one practical field connection per Display/circuit relationship;
- **Displays only** is a separate optional `PROP` filter;
- internal/subordinate rows that do not represent another practical connection are suppressed by the field-lead data contract.

## Primary Field Columns

The normal FieldWiring screen should emphasize only the information required during setup:

1. **Controller**
2. **Channel** — the current `StartChannel`
3. **Channel Name**
4. **Display Name**
5. **Network**

These are the primary field-use columns.

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

The underlying data must remain row-complete even when the display label is presented once per group.

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

This is a presentation grouping only.

It must not alter the field-lead identity or collapse separate circuit rows.

### Shared-circuit requirement

If more than one Display legitimately uses the same controller/channel, each Display relationship must remain visible.

Grouping by Display must therefore not deduplicate rows merely because Controller + Channel are the same.

## Source

`Source` (`PROP`, `SUBPROP`, `DMX`, etc.) is useful engineering provenance but is not a primary field instruction.

Preferred presentation options, in order of field compactness:

1. omit Source from the normal field table and expose it in row details/engineering mode;
2. show Source as a very small badge/icon;
3. use restrained source-specific visual coding with a legend.

If color is used, color must be supplemental rather than the only way Source is communicated. The interface must remain understandable for users with color-vision limitations and on monochrome/poor-quality printouts.

Source must never be used to imply that a `SUBPROP` field-lead row is invalid. A SubProp may be the source of a legitimate FIELD connection.

## Tag

`LORTag` is optional engineering/programming information.

It should not consume permanent horizontal space in the normal field wiring view.

Preferred behavior:

- hidden by default;
- available through an **Engineering details**, expandable row, tooltip/popover, or optional column control;
- available in engineering/data export where useful.

## ConnectionType and DeviceType

`ConnectionType` and `DeviceType` are useful for validation and troubleshooting but are not normal setup columns.

Normal Field Wiring mode already implies the user is looking at practical FIELD connections.

Therefore these fields should normally be hidden from the compact field table and made available through details/engineering mode.

## Recommended Normal Field Layout

The compact table should target approximately:

```text
Controller | Ch | Channel Name | Display | Network
```

or, when grouped by Display:

```text
Display: <Display Name>
Controller | Ch | Channel Name | Network
```

The grouped version is preferred when it materially reduces repeated text and improves phone/tablet readability.

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

- Controller and Channel should remain immediately visible;
- Channel Name should receive the largest available width;
- Display may become the group heading rather than a repeated column;
- Network may use a compact badge/short field;
- Source, ConnectionType, DeviceType, and Tag should move to optional details.

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

Engineering provenance such as Source or Tag may be included only when it materially helps the report and does not compromise field readability.

Every FieldWiring hard report remains subject to the FieldWiring expiration/currentness contract.

## Acceptance Examples

FieldWiring presentation testing should include at minimum:

1. one Display with several sequential channels;
2. one Display whose surviving field leads originate from both `PROP` and `SUBPROP` rows;
3. two Displays sharing the same controller/channel;
4. a Stage with SPARE rows, confirming they are hidden in the normal field view;
5. Displays-only mode, confirming it is distinct from Field Wiring mode;
6. Regular and auxiliary network examples;
7. a narrow phone/tablet viewport;
8. a printed/hard report using the compact grouping model.

## Related Documents

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [Wiring System](README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
