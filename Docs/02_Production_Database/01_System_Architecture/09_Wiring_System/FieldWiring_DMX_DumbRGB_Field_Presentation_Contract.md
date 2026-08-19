# FieldWiring DMX / DumbRGB Field Presentation Contract

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Schema status | No schema change authorized |

## Purpose

FieldWiring must not force every LOR-controlled Display into the conventional A/C-controller or Pixie-controller hookup model.

MSB also has Displays whose current LOR data is represented as:

```text
device_type = DMX
string_type = DumbRGB
```

For these Displays, the field task may be a DMX-network connection rather than plugging a Display into one numbered output of an A/C or Pixie controller.

The operator-facing presentation must describe the physical hookup the volunteer actually performs. Raw DMX universe/channel values remain important engineering data, but they must not be mislabeled as physical controller/output instructions.

---

## Northern Lights Is the Initial Acceptance Case

Stage / Scene:

```text
16-Northern Lights-NL
```

is the initial accepted example for this presentation family.

Operator clarification on 2026-08-19 established:

- the Northern Lights fixtures are Dumb RGB flood lights;
- there is no normal A/C/Pixie-style controller-output hookup for the field crew;
- the practical field connection is the DMX network cable; and
- these fixtures are treated operationally as being on a DMX network.

This is why Northern Lights is a poor example for evaluating A/C-versus-Pixie controller/output presentation. It is useful instead as the first DMX/DumbRGB acceptance case.

---

## Current V7 Snapshot Evidence

The current development V7 snapshot confirms the Northern Lights Scene contains Props with:

```text
device_type = DMX
string_type = DumbRGB
```

The current DMX-channel materialization carries values including:

```text
network
start_universe
start_channel
end_channel
```

For example, `NL-DS-01` is currently represented by three DMX channels in universe `145`, starting at channels `1`, `2`, and `3`.

The legacy-compatible `preview_wiring_fieldlead_v6` view exposes those DMX values through its generic wiring columns. In that compatibility view, values such as:

```text
Controller = 145
StartChannel = 1 / 2 / 3
```

are DMX universe/channel addressing evidence. They are **not** proof that the volunteer is looking for a physical controller numbered `145` with numbered output plugs `1`, `2`, and `3`.

This distinction is critical for the browser replacement because FormView's generic controller/channel grid can be technically faithful to the parsed data while still being misleading as a physical hookup instruction.

---

## Field Presentation Rule

FieldWiring must choose the operator presentation family from the current topology/device evidence rather than applying one universal `Controller / Channel` layout.

For the currently accepted cases:

```text
Traditional LOR
    -> conventional A/C physical-output presentation

RGB LOR
    -> Pixie physical-output presentation

DMX + DumbRGB
    -> DMX network / fixture presentation
```

The DMX/DumbRGB presentation must not teach the operator that DMX universe values are physical controller identities or that DMX channel numbers are numbered controller plugs.

---

## Operator-Facing DMX/DumbRGB Result

The normal field result should emphasize the information the field crew actually needs.

Conceptually:

```text
Display / Fixture
    NL-DS-01

Connection
    DMX network

Location / visual guidance
    current same-scope wiring/context image when available
```

Additional field-facing network identification may be added when the actual physical cable/network labeling contract is confirmed.

Raw technical addressing such as:

```text
LOR network alias
DMX universe
DMX start/end channel
source/device metadata
```

belongs in Engineering Details or a troubleshooting view unless a specific field workflow proves that the installer needs it.

The current V7 snapshot uses LOR network aliases such as `Aux A` / `Aux B` alongside DMX universe data. FieldWiring must not automatically relabel those values without first defining how the physical DMX network is labeled in the park.

---

## Wiring Images Remain Supplemental

A Northern Lights wiring image may still be useful for rough physical orientation or layout.

It is not required to make the DMX hookup valid.

The same general FieldWiring image rule applies:

```text
wiring / hookup data     PRIMARY
published image          OPTIONAL
same-scope context image OPTIONAL
```

If no current image exists, the field result must remain usable.

---

## Relationship to FormView Compatibility Views

The current V7/PostgreSQL compatibility layer intentionally preserves the legacy wiring-view shape used by FormView.

That compatibility is useful for parity testing, but it does not mean every generic column has the same physical meaning for every device family.

In particular:

```text
Traditional LOR row
    Controller / StartChannel can correspond closely to physical hookup

Pixie RGB row
    raw Unit ID is logical addressing and must be translated to physical output

DMX/DumbRGB row
    generic Controller / StartChannel may represent DMX universe/channel addressing,
    not a physical controller/output hookup
```

FieldWiring must interpret the row using current Prop/SubProp/device metadata before rendering the normal operator view.

---

## Acceptance Requirements

At minimum, DMX/DumbRGB FieldWiring testing must prove:

1. `16-Northern Lights-NL` is classified as a DMX/DumbRGB presentation family rather than A/C or Pixie;
2. values such as DMX universe `145` / `146` are not presented as physical controller labels;
3. DMX channel values are not presented as numbered physical output plugs unless a separate device-specific contract proves that relationship;
4. the operator can identify the applicable Display/fixture and DMX-network hookup without understanding the raw addressing model;
5. raw universe/channel/network information remains available under Engineering Details for troubleshooting;
6. a missing wiring image does not invalidate the DMX field result; and
7. no change is made to the authoritative LOR topology merely to simplify presentation.

---

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
