# Controller Inventory Model and Firmware Authority — 2026-08-30

| Item | Value |
|---|---|
| Status | CURRENT PRODUCTION AUTHORITY |
| Issue | #110 |
| Permanent model authority | `ref.controller_model` |
| Permanent firmware authority | `ref.controller_firmware_version` |
| Physical installed firmware | `ref.controller.installed_firmware_version_id` |

## Purpose

This document began as the bootstrap normalization rule and now records the continuing production authority for Controller model/revision and firmware maintenance.

The retired Controller spreadsheet is migration evidence only. It is not the naming or firmware authority and will not be updated after migration.

## Canonical model rule

A physical Controller references a controlled canonical manufacturer model. Spreadsheet abbreviations, typos, capitalization variations, and historical shorthand are provenance only and must not become separate production models when they describe the same manufacturer product.

For Light-O-Rama equipment, canonical terminology comes from manufacturer documentation. Existing accepted normalization examples include:

- `CTB04-G3` -> `CTB04Dg3`;
- `CTB32LG3` / `32LD-G3` -> accepted `CTB32` model terminology where supported by reviewed hardware evidence;
- `Pixie2` / `Pixie2D` -> accepted `Pixie2D` family terminology;
- `Pixie4` -> `Pixie4D`;
- `Pixie8` -> `Pixie8D`;
- `Pixie16` -> `Pixie16D`; and
- `Pixcon16` -> `PixCon16`.

Exact hardware families remain distinct. In particular, `PixCon16` and `Pixie16D` are different devices and must never be collapsed merely because both can control pixels.

## Hardware revision rule

When a manufacturer revision changes firmware compatibility or operational capability, the Controller model/revision representation must preserve that distinction strongly enough to prevent incompatible firmware selection.

Current accepted example: PixCon16 hardware revision matters because Original and MKII units use different firmware families. Existing staged 2.0.13 evidence identified the accepted migrated PixCon16 units as MKII during bootstrap review.

Unknown/ambiguous revision evidence must remain unresolved rather than being guessed.

## Manufacturer authority

Manufacturer documentation is the external naming/firmware reference authority.

For Light-O-Rama equipment, use Light-O-Rama's published firmware/model references.

For HolidayCoro equipment, use HolidayCoro model/generation-specific manufacturer sources. Do not infer an AlphaPix/Flex CPU or firmware family merely from broad assembled-product wording when several controller CPU options are possible.

Manufacturer references are compare/review input. They must not destructively rewrite historical Controller records merely because a vendor page changes later.

## Firmware catalog rule

The firmware catalog must support multiple valid historical/published versions for a model/revision. It is not only a `latest firmware` lookup.

A physical Controller references a controlled firmware-version row rather than storing an operational free-text value such as:

```text
1.05
v1.05
V1.05
```

The UI must present firmware choices valid for the selected exact model/revision, and PostgreSQL remains the final enforcement boundary for model/firmware compatibility.

Technicians must not be required to memorize which firmware family belongs to which hardware revision.

## Installed vs published firmware

These are different facts:

- **installed firmware** — what is currently on the physical Controller;
- **published/known valid firmware** — controlled catalog rows for that model/revision;
- **latest/recommended firmware** — current manufacturer guidance, which may change.

Older valid/observed firmware rows may remain necessary to represent existing hardware accurately even when they are no longer shown on a manufacturer's current download page.

## Initial migration firmware state

The accepted bootstrap preserved source firmware evidence without pretending it had been physically verified:

- source firmware classified `RECORDED` was migrated as recorded;
- those controllers began as `RECORDED_UNVERIFIED`;
- `New`, `???`, and blank source evidence remained `UNKNOWN` with no installed-firmware FK;
- field/powered verification may later move firmware state to `VERIFIED` and record the verifying person/time/note.

Firmware verification was not a prerequisite for assigning permanent Controller identity.

## Catalog may include models not currently owned

The controlled manufacturer model catalog may include a supported/published model even when MSB owns zero physical units of that model. A catalog row is not proof of inventory ownership.

Physical ownership exists only when a permanent `ref.controller` row exists.

## Controller Management behavior

The browser-native Manager workflow must use controlled lookups rather than raw IDs or free-text model/firmware authority.

For Add/Edit Controller:

```text
select exact Model
    -> show only compatible Firmware choices
    -> preserve UNKNOWN/unverified state when the physical fact is not known
    -> PostgreSQL validates compatibility on save
```

Adding or maintaining model/firmware lookup rows may remain a simple administrative/reference task where Directus is adequate, but the Controller operational workflow belongs in the Controller Management browser.

## Rule established

> Permanent Controller model/revision names and valid firmware versions come from controlled manufacturer-backed reference data, not the retired migration spreadsheet. A physical Controller references canonical model and firmware rows, firmware compatibility is enforced rather than left to technician memory, and unknown physical facts remain unknown until verified.
