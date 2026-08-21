# FieldWiring A/C UID, Shared-Output, and Multi-Controller Findings — 2026-08-19

| Item | Value |
|---|---|
| Status | ENGINEERING FINDINGS — current V7 snapshot evidence |
| Sub-project | FieldWiring |
| Scope | Traditional A/C presentation and connection-row grouping |
| Schema status | No schema change authorized |

## Purpose

This document records field-presentation findings from operator review of the Church prototype plus targeted current-snapshot inspection of Stage 23 Peanuts and Stage 24 Traditional Christmas.

The objective is to preserve the practical A/C-controller information volunteers actually use while avoiding assumptions that one Display maps to one controller or one controller output maps to one Display.

## A/C Unit ID Is Important Normal Field Information

For conventional LOR A/C controllers, the Unit ID remains useful to the field operator and should not be hidden as engineering-only data.

The normal FieldWiring presentation should therefore keep the A/C Unit ID visible alongside the controller role and numbered Output / Plug.

Conceptually:

```text
A/C Controller
    Unit ID 41
    Output 1
        Display A -> Plug Label / Channel Name
        Display B -> Plug Label / Channel Name
```

For this controller family:

```text
Unit ID       -> useful controller identifier
StartChannel  -> physical numbered output / outlet
Channel Name  -> field-facing plug label text
```

A future permanent Controller Inventory identity may enrich this display, but it should not force removal of the LOR Unit ID when the Unit ID remains useful to installation/troubleshooting.

## Pixel-Controller Boundary Remains Different

The same visibility rule must not be generalized blindly to Pixel/Pixie controllers.

For Pixie controllers, raw Unit IDs may represent logical RGB-output addressing within one physical controller and may intentionally repeat across more than one physical controller.

Therefore:

```text
Traditional A/C
    Unit ID is normal field information

Pixie / RGB
    Unit ID or Unit-ID range is addressing evidence
    physical controller/output interpretation is separate
```

This distinction allows FieldWiring to preserve useful A/C addressing without recreating the misleading FormView behavior for Pixel controllers.

## Atomic Connection Row

The connection relationship is the atomic field result that must never be lost.

A connection row carries, as applicable:

```text
resolved Stage / Scene + Background/Musical context
physical controller role or A/C Unit ID
physical Output / Plug
Display
Plug Label / Channel Name
Network
raw engineering addressing/provenance
```

This supports both directions of the real field relationship:

1. one controller output may feed multiple Display connections; and
2. one Display may use multiple controllers.

The browser may group these same rows By Controller or By Display without changing the underlying connection set.

## Church — Shared A/C Output Example

The Church Background prototype demonstrates that one A/C output may feed several separate Display connections.

For Unit ID `41`, Output `1` currently includes multiple separate relationships, including:

```text
CH-Steeple-LH-Base -> CH 41-01 Steeple LH
CH-Steeple-LH-Top  -> CH 41-01 Steeple LH-Top
CH-Steeple-RH-Base -> CH 41-01 Steeple RH
CH-Steeple-RH-Top  -> CH 41-01 Steeple RH-Top
```

FieldWiring must keep every Display/Channel Name relationship visible even though the controller/output pair is shared.

This also means plug-label printing should operate on the individual connection/label candidate rather than assuming one printed label per controller output.

## Stage 23 Peanuts — Shared Controllers and Shared Outputs

Current V7 snapshot inspection of:

```text
Show Background Stage 23 Peanuts
```

shows three principal conventional A/C Unit IDs in current use:

```text
77
78
79
```

Each current promoted Peanuts Display is associated with one of those Unit IDs in the current snapshot, but the controllers serve multiple Displays and some outputs are explicitly shared by multiple Display relationships.

Examples on Unit ID `79` include:

```text
Output 2
    PN-DancingPeanuts     -> PN GB 79-02 Boy 1 Legs 1
    PN-SchroederAndLucy   -> PN SL 79-02 Lucy Foot 1

Output 3
    PN-DancingPeanuts     -> PN GB 79-03 Boy 1 Legs 2
    PN-SchroederAndLucy   -> PN SL 79-03 Lucy Foot 2

Output 4
    PN-DancingPeanuts     -> PN GB 79-04 Boy 1 Legs 3
    PN-SchroederAndLucy   -> PN SL 79-04 Lucy Foot 3

Output 9
    PN-Pigpen             -> PN PP 79-09 Body
    PN-SchroederAndLucy   -> PN SL 79-01 Lucy Body Dress
```

Peanuts is therefore an important acceptance case for:

> one A/C controller output -> multiple Display/Channel Name connection rows.

The current snapshot does not show a promoted Peanuts Display spanning multiple controller Unit IDs; its primary value here is shared-controller/shared-output validation.

## Stage 24 Traditional Christmas — Displays Can Span Multiple Controllers

Current V7 snapshot inspection of:

```text
Show Background Stage 24 Traditional Christmas
```

proves the reverse relationship as well: one Display may require more than one controller.

### `TC-BruceTheSpruce`

Current field-lead rows span three controller Unit IDs on Aux E:

```text
7C / Output 1 -> TC 7C-01 Bruce Tree
91 / Output 1 -> TC 91-92 Bruce Face
92 / Output 1 -> TC-BruceTheSpruce 92-01
```

Therefore one Display may appear in three controller contexts.

### `TC-FryingSanta`

Current field-lead rows span:

```text
Aux F / Unit ID 41 / Output 1
    TC Frying Santa 41 01-147 6 Grill fire

Regular / Unit ID 7D / Outputs 1-8
    Beard
    Arm Down
    Grill open
    Arm Mid
    Arm Up
    Close handle
    Tongue Right
    Tongue left
```

This is another direct acceptance case for:

> one Display -> multiple controller/network contexts.

## Stage 24 Shared Outputs Also Exist

Traditional Christmas simultaneously contains shared controller outputs, so both relationship directions occur within the same Stage.

Examples include:

```text
Regular / Unit ID 7A / Output 16
    TC-Snowman-Child
    TC-Snowman-Dad
    TC-Snowman-Mom

Regular / Unit ID 7B / Output 8
    TC-CarolerPanel-01
    TC-CarolerPanel-02
    TC-CarolerPanel-03

Regular / Unit ID 7B / Output 9
    TC-CarolerPanel-01
    TC-CarolerPanel-02
    TC-CarolerPanel-03

Regular / Unit ID 7B / Output 10
    TC-CarolerPanel-01
    TC-CarolerPanel-02
    TC-CarolerPanel-03
```

Therefore Traditional Christmas is a strong test Stage for the full many-to-many hookup model.

## Presentation Consequence

The recommended normal controller-oriented view may remain:

```text
A/C CONTROLLER · UNIT ID 7B
Network: Regular

Output / Plug | Display             | Plug Label / Channel Name
8             | Caroler Panel 01    | ...
              | Caroler Panel 02    | ...
              | Caroler Panel 03    | ...
9             | Caroler Panel 01    | ...
              | Caroler Panel 02    | ...
              | Caroler Panel 03    | ...
```

A Display-oriented alternate view can present the same atomic connection rows as:

```text
TC-BruceTheSpruce
    Aux E / Unit ID 7C / Output 1
    Aux E / Unit ID 91 / Output 1
    Aux E / Unit ID 92 / Output 1
```

Neither view is a different source of truth. They are alternate groupings of the same current connection rows.

## Acceptance Requirements Added

FieldWiring presentation testing should include:

1. an A/C controller whose Unit ID is visible in the normal field view;
2. one A/C output connected to multiple Display/Channel Name rows;
3. one Display spanning multiple controller Unit IDs;
4. one Display spanning more than one network/controller context;
5. Stage 23 Peanuts as a shared-output acceptance case;
6. Stage 24 Traditional Christmas as a combined shared-output + multi-controller Display acceptance case; and
7. proof that controller-oriented and Display-oriented grouping preserve the same underlying connection rows without deduplication.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring Channel / Plug Label Printing Requirements](FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
