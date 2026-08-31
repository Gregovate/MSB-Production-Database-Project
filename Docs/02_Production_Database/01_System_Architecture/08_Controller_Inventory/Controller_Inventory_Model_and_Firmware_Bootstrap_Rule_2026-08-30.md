# Controller Inventory Model and Firmware Bootstrap Rule — 2026-08-30

Status: CURRENT BOOTSTRAP RULE

## Permanent model naming

Workbook model values are source evidence, not automatically permanent model identities.

For Light-O-Rama equipment, `ref.controller_model.model_code` and `model_name` must correspond to real model designations/names published by Light-O-Rama. If a workbook value is a shorthand, firmware-family name, capitalization variant, or other non-model label, the staging model-reference layer corrects it before permanent Controller Inventory creation.

Examples from the current bootstrap:

- `CTB04-G3` -> `CTB04Dg3` / `CTB04Dg3 Generation 3 Controller (4 channels)`
- `CTB32LG3` -> `CTB32` / `CTB32 Generation 3 Controller Board (16 channels)`; `CTB32LG3` is the firmware family/name, not the permanent model
- `32LD-G3` -> `CTB32` / `CTB32 Generation 3 Controller Board (16 channels)`
- `Pixie2` and `Pixie2D` -> `Pixie2D` / `Pixie2D/Cosmic Color Controller II (RGB smart pixels - 2 ports)`
- `Pixie4` -> `Pixie4D`
- `Pixie8` -> `Pixie8D`
- `Pixie16` -> `Pixie16D`
- `Pixcon16` -> `PixCon16` / `PixCon16 Controller Board (RGB smart pixels - 16 ports)`; recorded 2.0.13 firmware identifies the staged units as MKII hardware revision per LOR

Full vendor names are retained in the model catalog; abbreviated workbook labels remain only as bootstrap/source provenance.

## Firmware bootstrap

Firmware verification is not a prerequisite for completing Controller Inventory because the deployed controllers cannot all be powered until setup season.

- Source firmware classified `RECORDED` is imported exactly as recorded.
- Those controller rows begin as `RECORDED_UNVERIFIED`.
- `New`, `???`, and blank firmware evidence remain `UNKNOWN` and have no installed-firmware FK.
- Field setup changes firmware state to `VERIFIED` and records verification time/person.
- Current vendor firmware is advisory reference metadata, not a promotion gate.
- A recorded historical firmware value is preserved even when absent from a vendor's current download page.

## Vendor references

Light-O-Rama's Controller Firmware Updates page is the authoritative naming/firmware-reference source for the LOR models in this bootstrap.

HolidayCoro does not have an equivalent firmware-reference page identified for the AlphaPix Flex 48. The HolidayCoro product page may be retained as model/product reference evidence, while firmware reference/current version remains null until field verification or a suitable vendor firmware source is established.
