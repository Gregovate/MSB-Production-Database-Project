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
- constrained so it does not consume the entire screen on tablets or phones;
- usable while the operator continues reviewing hookup rows; and
- independent of whether the wiring result itself is valid.

Hiding an image must never hide or alter hookup rows.

## Image Placement and Split-Pane Workspace

When a current published wiring image exists, the preferred operator layout is a **split vertical workspace**:

```text
Stage / Scene + Background/Musical context

[ Wiring Image Window ]
[ Show/Hide | Previous | Page X of Y | Next | Zoom ]

[ Independently Scrollable Hookup Table ]
```

The image window should remain above the hookup table while the operator scrolls the hookup rows inside the table area. This allows the field worker to compare a wiring drawing with controller/output rows without repeatedly scrolling back to the image.

The image window and hookup table are two views of the same resolved wiring context. Scrolling the hookup table must not move the image out of view while sufficient screen space exists for the split workspace.

If the image is hidden, the hookup table should immediately reclaim the released screen space.

The operator should not have to scroll through every hookup row merely to find the image controls.

## Collapse / Hide Behavior

The image area must provide an obvious Show / Hide control.

Recommended behavior for testing:

```text
Desktop / large browser
    -> image may begin expanded
    -> image remains in the upper workspace while hookup rows scroll below

Tablet / phone / narrow viewport
    -> image should begin collapsed or otherwise preserve wiring-row space
    -> if opened, use a smaller capped image window above the scrollable hookup rows
```

The exact breakpoints and pane heights remain UI implementation details and require real-device testing.

The application should preserve the current image page/zoom state when the operator temporarily hides and reopens the image where practical.

## Multiple-Image Navigation

A resolved wiring scope may contain more than one current published wiring image.

The image viewer must support:

- Previous;
- Next;
- visible `Page X of Y` state; and
- deterministic ordering consistent with the accepted Drive resolver / published image contract.

Image navigation occurs inside the upper image window so the operator can change pages without losing the current position in the hookup table.

Navigation must remain inside the already-resolved Stage/Sub-stage/Scene wiring scope. It must not search a parent Stage for replacement images.

## Image Inspection

The operator must be able to inspect detail without making the whole page unusable.

At minimum provide:

- fit-to-view behavior;
- zoom in;
- zoom out; and
- a scrollable/pannable image viewport when zoomed.

The image viewport should be bounded independently of the hookup table. Zooming an image must not force the hookup table completely off-screen.

A later mobile implementation may use native pinch/zoom or a focused/fullscreen viewer if that proves more usable in field testing.

## Responsive Layout

Tablet and phone behavior must be tested on real or representative devices before acceptance.

On narrow screens:

- image area should default to space-saving behavior;
- controller UID / controller role, Output / Plug, Display, and Plug Label / Channel Name remain immediately accessible;
- image controls must not force horizontal scrolling of the hookup table;
- the image viewport should have a capped height;
- the hookup table should retain its own scrollable area when the image is open;
- hiding the image should return the screen area to the hookup data; and
- the operator must always be able to reach the hookup rows without dismissing the entire wiring context.

On very small phone screens, a later implementation may choose a focused image viewer instead of maintaining both panes simultaneously if hands-on testing shows that is more usable.

## Missing-Image Behavior

If no current published wiring image exists:

```text
NO WIRING IMAGE AVAILABLE
```

must be shown clearly while the hookup data remains fully usable.

A same-scope PreviewBackground may be shown separately as context only, following the existing FieldWiring image-scope contract.

## Printing / Offline Reports

The split-pane behavior is a browser interaction pattern only.

Printed/offline hard reports must return to normal document flow rather than preserving nested scroll panes. The image, when present, and the hookup rows should remain printable according to the existing FieldWiring hard-report/currentness contract.

## Prototype Acceptance Notes — Church

The Stage 15 Church physical-hookup prototype is the first UX test bed for this behavior.

The current prototype direction includes:

- image placement immediately below the Background/Musical context header;
- a dedicated image window above the hookup rows;
- an independently scrollable hookup-table area beneath the image;
- explicit Show / Hide behavior;
- desktop-expanded / narrow-screen-collapsed test behavior;
- a `Page 1 of 1` navigation scaffold that can expand to multiple images;
- Fit / zoom controls;
- capped image-pane height; and
- automatic recovery of the image space by the hookup table when the image is hidden.

This responsive behavior is not yet accepted as tablet/mobile proven. It requires hands-on testing on representative field devices.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
