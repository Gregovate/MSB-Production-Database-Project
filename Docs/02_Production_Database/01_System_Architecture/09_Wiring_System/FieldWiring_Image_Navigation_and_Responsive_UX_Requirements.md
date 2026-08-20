# FieldWiring Image Navigation and Responsive UX Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted desktop/browser UX baseline; tablet/mobile validation pending |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

FieldWiring wiring images are supplemental visual guidance, but image access and navigation are operationally important when images exist. The browser UI must therefore make images easy to show, hide, page, inspect, and compare with hookup rows without allowing the image area to crowd out the primary hookup data.

## Core Rule

The wiring table / physical hookup information remains the primary field product.

A wiring image must therefore be:

- collapsible / hideable at any time;
- easy to reveal again without leaving the current Stage/Scene/context;
- constrained so it does not consume the entire screen on tablets or phones;
- usable while the operator continues reviewing hookup rows;
- independently scrollable when the image is larger than its viewport; and
- independent of whether the wiring result itself is valid.

Hiding an image must never hide or alter hookup rows.

## Image Placement and Split-Pane Workspace

When a current published wiring image exists, the accepted desktop/browser operator layout is a **split vertical workspace**:

```text
Stage / Scene + Background/Musical context

[ Wiring Image Window ]
[ Show/Hide | Previous | Page X of Y | Next | Fit Width | Fit All | Zoom ]
[ draggable divider ]
[ Independently Scrollable Hookup Table ]
```

The image window remains above the hookup table while the operator scrolls the hookup rows inside the table area. This allows the field worker to compare a wiring drawing with controller/output rows without repeatedly scrolling back to the image.

The image window and hookup table are two views of the same resolved wiring context. They must scroll independently.

The divider between the two panes must allow the operator to resize the image/table allocation **without changing browser zoom or shrinking the entire page**.

If the image is hidden, the hookup table should immediately reclaim the released screen space.

The operator should not have to scroll through every hookup row merely to find the image controls.

## Collapse / Hide Behavior

The image area must provide an obvious Show / Hide control.

Accepted behavior for the current prototype baseline:

```text
Desktop / large browser
    -> image begins expanded
    -> image remains in the upper workspace while hookup rows scroll below
    -> operator may drag the divider to resize the panes

Tablet / phone / narrow viewport
    -> image begins collapsed to preserve wiring-row space
    -> if opened, use a smaller capped image window above the scrollable hookup rows
```

The exact narrow-screen breakpoints and pane heights remain UI implementation details and require real-device testing.

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

The accepted desktop/browser image controls distinguish two fit operations:

### Fit Width

`Fit Width` scales the image to the width of the image viewport.

If the resulting image is taller than the available image pane, the **image viewport itself must scroll vertically**. This is the preferred normal view for inspecting wiring images because labels remain readable while the hookup table stays visible below.

### Fit All

`Fit All` scales the complete image so both its width and height fit inside the current image viewport.

This is a quick orientation view and may make text/labels smaller than `Fit Width`.

### Zoom / Pan

The image viewer must also provide:

- zoom in;
- zoom out; and
- horizontal/vertical scrolling or panning when the zoomed image exceeds the viewport.

Zooming the image must affect only the image content. It must not force the user to change browser zoom and must not resize the entire FieldWiring page.

The image viewport must remain bounded independently of the hookup table.

A later mobile implementation may use native pinch/zoom or a focused/fullscreen viewer if that proves more usable in field testing.

## Resizable Pane Behavior

The desktop/browser workspace must provide a visible divider between the image pane and hookup-table pane.

Dragging the divider must:

- resize the image pane vertically;
- give or reclaim the corresponding space from the hookup table;
- leave normal page text/UI size unchanged;
- retain independent scrolling in both panes; and
- recalculate `Fit All` when necessary so the complete image continues to fit the resized image viewport.

`Fit Width` should remain width-based when the divider moves. The image may therefore become more or less vertically scrollable as the image-pane height changes.

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

## Accepted Prototype Baseline — Church V7

The Stage 15 Church physical-hookup prototype V7 is the accepted **desktop/browser image-workspace baseline** as of 2026-08-19.

The accepted behavior demonstrated by V7 is:

- image placement immediately below the Background/Musical context header;
- dedicated upper image window;
- independently scrollable hookup-table area below;
- independently scrollable image viewport;
- explicit Show / Hide behavior;
- draggable divider between image and hookup-table panes;
- `Page 1 of 1` navigation scaffold that can expand to multiple images;
- working `Fit Width` behavior with image scrolling;
- working `Fit All` behavior showing the complete image in the image viewport;
- zoom controls that operate on the image rather than browser zoom; and
- automatic recovery of image space by the hookup table when the image is hidden.

This acceptance applies to the current desktop/browser interaction model. It does **not** yet mean the tablet/mobile layout is proven. Representative field-device testing remains required before tablet/mobile acceptance.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
