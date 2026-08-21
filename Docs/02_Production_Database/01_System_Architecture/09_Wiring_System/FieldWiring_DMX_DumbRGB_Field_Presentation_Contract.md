# FieldWiring DMX / DumbRGB Field Presentation Contract

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction |
| Sub-project | FieldWiring |
| Current revision | 2026-08-21 |
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

The operator-facing presentation must describe the physical hookup the volunteer actually performs. DMX universe/channel values are also important field addressing information for CR50 fixtures and must be presented according to the fixture contract rather than being mislabeled as physical controller/output instructions.

---

## `device_type = DMX` Does Not Define One Physical Family

Current MSB data also contains reviewed dense RGB Displays whose LOR representation is:

```text
device_type = DMX
string_type = RGB
```

Those Displays use the E1.31 network and intelligent pixel controllers such as AlphaPix/PixCon hardware. They are **not** the same physical hookup as the Northern Lights DumbRGB fixtures.

Therefore FieldWiring must not use `device_type = DMX` by itself as the normal-presentation discriminator.

For the reviewed current cases:

```text
DMX + DumbRGB
    -> DMX fixture/network presentation

DMX + RGB
    -> E1.31 dense RGB / intelligent pixel-controller presentation
```

The E1.31 rules are defined separately in [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md).

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

## Current V7.0.11 Snapshot Evidence

The accepted V7.0.11 snapshot confirms the Northern Lights Scene contains Props with:

```text
device_type = DMX
string_type = DumbRGB
```

The current DMX-channel materialization carries values including:

```text
RawPropID
ChannelName
ChannelGridRowNumber
network
start_universe
start_channel
end_channel
```

The real Northern Lights V7.0.11 acceptance output proves an important source-shape detail: each CR50 fixture is represented by **three separate one-channel DMX rows**, one for each RGB channel. `StartChannel` and `EndChannel` are equal on each of those rows.

For example:

```text
NL-DS-01
    Grid Row 1 -> U145 channel 1
    Grid Row 2 -> U145 channel 2
    Grid Row 3 -> U145 channel 3

NL-DS-02
    Grid Row 1 -> U145 channel 6
    Grid Row 2 -> U145 channel 7
    Grid Row 3 -> U145 channel 8
```

The same five-channel step continues throughout the accepted Northern Lights data. The acceptance set contains:

```text
NL-DS-01 through NL-DS-32 -> Universe 145
NL-PS-01 through NL-PS-34 -> Universe 146
```

which is 66 physical CR50 fixture contexts represented by 198 RGB source rows.

This is not three physical fixture outputs. It is three RGB-control source rows for one 5-channel fixture address.

The legacy-compatible `preview_wiring_fieldlead_v6` view exposes those DMX values through its generic wiring columns. In that compatibility view, values such as universe `145` and the fixture's individual RGB channel rows are DMX addressing evidence. They are **not** proof that the volunteer is looking for a physical controller numbered `145` with numbered output plugs matching those channels.

This distinction is critical for the browser replacement because FormView's generic controller/channel grid can be technically faithful to the parsed data while still being misleading as a physical hookup instruction.

---

## CR50 Fixture Addressing Rule

This rule applies to **all CR50 fixtures**, not only Northern Lights.

A CR50 is physically a **5-channel DMX fixture**. MSB intentionally includes only the three RGB control channels in the LOR Channel Grid. The additional two fixture-function channels, including strobe and another auxiliary function, are deliberately excluded from the grid.

The V7.0.11 source rows therefore legitimately appear as three one-channel records per fixture:

```text
CR50 fixture 1
    source row 1 -> channel 1
    source row 2 -> channel 2
    source row 3 -> channel 3
    channels 4-5 intentionally omitted from the MSB Channel Grid

CR50 fixture 2
    source row 1 -> channel 6
    source row 2 -> channel 7
    source row 3 -> channel 8
    channels 9-10 intentionally omitted from the MSB Channel Grid

CR50 fixture 3
    source row 1 -> channel 11
    source row 2 -> channel 12
    source row 3 -> channel 13
    channels 14-15 intentionally omitted from the MSB Channel Grid
```

The gaps are **intentional addressing behavior**, not missing parser data and not channels that FieldWiring should synthesize or close.

### Fixture-level grouping rule

FieldWiring may aggregate the three RGB source rows into one technician-facing CR50 fixture instruction, but that aggregation is presentation logic only. The underlying source rows remain authoritative and unchanged.

Within a Preview, `PreviewId + RawPropID` identifies the originating source PropClass/fixture context. For a valid CR50 fixture group:

```text
DMX fixture start address
    = StartChannel on ChannelGridRowNumber 1
    = lowest of the three represented RGB channel numbers

RGB channels
    = the three actual source channel values ordered by ChannelGridRowNumber

Physical fixture footprint
    = 5 DMX channels
```

If the three represented RGB channels are consecutive, the browser may compact them for readability:

```text
1,2,3   -> 1-3
6,7,8   -> 6-8
11,12,13 -> 11-13
```

FieldWiring must **not** infer or insert the two omitted fixture-function channels merely to create a continuous five-channel record. It must also not derive CR50 fixture count from the number of DMX source rows; three source rows represent one fixture.

This CR50 rule is especially important during DMX addressing and troubleshooting because a technician must be able to distinguish an intentional 5-channel fixture step from accidentally missing channels.

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

DMX + RGB — reviewed dense RGB cases
    -> E1.31 network / intelligent pixel-controller presentation
```

The DMX/DumbRGB presentation must not teach the operator that DMX universe values are physical controller identities or that DMX channel numbers are numbered controller plugs.

For CR50 fixtures, however, universe, DMX start address, and the RGB channel range are meaningful field addressing information and belong in the normal fixture table.

---

## Operator-Facing DMX/DumbRGB Result

The normal field result should emphasize the information the field crew actually needs.

For CR50 fixtures, the accepted technician-facing columns are conceptually:

```text
FIXTURE / CHANNEL
UNIVERSE
DMX START ADDRESS
RGB CHANNELS
```

Example:

```text
FIXTURE / CHANNEL      UNIVERSE   DMX START   RGB CHANNELS
CR50 fixture 1         145        1           1-3
CR50 fixture 2         145        6           6-8
CR50 fixture 3         145        11          11-13
```

The normal view must not display a pixel count for CR50/DumbRGB fixtures. The RGB source rows represent three color-control channels, not an addressable-pixel quantity.

Location / visual guidance may still use the current same-scope wiring/context image when available.

Additional raw source/device metadata belongs in Engineering Details or a troubleshooting view unless a specific workflow proves that it belongs in the normal field table.

The current V7 snapshot uses LOR network aliases alongside DMX universe data. FieldWiring must not automatically relabel those values without first defining how the physical DMX network is labeled in the park.

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

E1.31 dense RGB row
    generic Controller may also be universe addressing across one or more
    intelligent pixel controllers, not a physical controller identity
```

FieldWiring must interpret the row using current Prop/SubProp/device metadata before rendering the normal operator view.

For CR50 specifically, the compatibility data must not be normalized into consecutive 3-channel fixtures. The intentional two-channel gaps are part of the physical 5-channel DMX addressing scheme.

---

## Acceptance Requirements

At minimum, DMX/DumbRGB FieldWiring testing must prove:

1. `16-Northern Lights-NL` is classified as a DMX/DumbRGB presentation family rather than A/C, Pixie, or E1.31 dense RGB;
2. values such as DMX universe `145` / `146` are not presented as physical controller labels;
3. CR50 fixtures are treated as 5-channel DMX devices even though only the three RGB channels are present in the LOR Channel Grid;
4. the V7.0.11 three-row source representation is preserved: one source row per represented RGB channel with local Channel Grid Row Numbers 1-3;
5. FieldWiring groups those three source rows into one fixture instruction by source fixture identity rather than treating them as three fixtures or three physical plugs;
6. CR50 normal rows show fixture/channel, universe, DMX start address, and actual RGB channel range;
7. intentional two-channel CR50 gaps are preserved and are not filled, renumbered, or reported as missing data;
8. no pixel count is derived or displayed for CR50/DumbRGB fixtures;
9. DMX channel values are not presented as numbered physical controller plugs unless a separate device-specific contract proves that relationship;
10. the operator can identify the applicable Display/fixture and DMX-network hookup without treating universe as physical controller identity;
11. raw network/source/device metadata remains available under Engineering Details for troubleshooting;
12. `device_type = DMX` + `string_type = RGB` reviewed dense Displays route to the separate E1.31 presentation contract rather than this DumbRGB contract;
13. a missing wiring image does not invalidate the DMX field result; and
14. no change is made to the authoritative LOR topology merely to simplify presentation.

---

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
