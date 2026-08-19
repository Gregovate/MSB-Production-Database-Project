# FieldWiring Image Navigation and Responsive UX Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted operator UX direction |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

FieldWiring wiring images are supplemental visual guidance, but image access and navigation are operationally important when images exist. The browser UI must therefore make images easy to show, hide, page, and inspect without allowing the image area to crowd out the primary hookup data.

## Core Rule

The wiring table / physical hookup information remains the primary field product.

A wiring image must therefore be:

- collapsible / hideable at any time;
- easy to reveal again without leaving the current Stage/Scene/context;
- constrained so it does not consume the entire screen on tablets or phones; and
- independent of whether the wiring result itself is valid.

Hiding an image must never hide or alter hookup rows.

## Image Placement

When a current published wiring image exists, the image control should appear near the top of the resolved Background/Musical context, before the long controller/output list.

The operator should not have to scroll through every hookup row merely to find the image controls.

## Collapse / Hide Behavior

The image area must provide an obvious Show / Hide control.

Recommended behavior for testing:

```text
Desktop / large browser
    -> image may begin expanded

Tablet / phone / narrow viewport
    -> image should begin collapsed or otherwise preserve wiring-row space
```

The exact breakpoint remains a UI implementation detail and requires real-device testing.

The application should preserve the current image page/zoom state when the operator temporarily hides and reopens the image where practical.

## Multiple-Image Navigation

A resolved wiring scope may contain more than one current published wiring image.

The image viewer must support:

- Previous;
- Next;
- visible `Page X of Y` state; and
- deterministic ordering consistent with the accepted Drive resolver / published image contract.

Navigation must remain inside the already-resolved Stage/Sub-stage/Scene wiring scope. It must not search a parent Stage for replacement images.

## Image Inspection

The operator must be able to inspect detail without making the whole page unusable.

At minimum provide:

- fit-to-view behavior;
- zoom in;
- zoom out; and
- a scrollable/pannable image viewport when zoomed.

A later mobile implementation may use native pinch/zoom or a focused/fullscreen viewer if that proves more usable in field testing.

## Responsive Layout

Tablet and phone behavior must be tested on real or representative devices before acceptance.

On narrow screens:

- image area should default to space-saving behavior;
- controller UID / controller role, Output / Plug, Display, and Plug Label / Channel Name remain immediately accessible;
- image controls must not force horizontal scrolling of the hookup table;
- the image viewport should have a capped height rather than pushing wiring rows far below the fold; and
- hiding the image should return the screen area to the hookup data.

## Missing-Image Behavior

If no current published wiring image exists:

```text
NO WIRING IMAGE AVAILABLE
```

must be shown clearly while the hookup data remains fully usable.

A same-scope PreviewBackground may be shown separately as context only, following the existing FieldWiring image-scope contract.

## Prototype Acceptance Notes — Church

The Stage 15 Church physical-hookup prototype is the first UX test bed for this behavior.

The current prototype direction includes:

- image placement immediately below the Background/Musical context header;
- explicit Show / Hide behavior;
- desktop-expanded / narrow-screen-collapsed test behavior;
- a `Page 1 of 1` navigation scaffold that can expand to multiple images;
- Fit / zoom controls; and
- a capped image viewport so hookup rows remain reachable.

This responsive behavior is not yet accepted as tablet/mobile proven. It requires hands-on testing on representative field devices.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
