# FieldWiring Accepted Baseline Recovery — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING RECOVERY BASELINE — restore before further UX improvement |
| Sub-project | FieldWiring |
| Feature branch | `agent/fieldwiring-engineering-recovery` |
| Accepted pre-application UX checkpoint | `7479d58bcd52849ccf55f182f9d3e4fe74b58233` — Accept FieldWiring V7 image workspace baseline |
| First generic renderer integration | `fa1afe1b12d809e9cf66a6dca2b9dd5dee6dcdcc` — Connect FieldWiring renderer to resolved browser context |
| Recovery audit start head | `ad0e09b6bd304b4da3649388898271af33beeecd` |
| Schema status | No schema change authorized or required by this recovery audit |

## Purpose

This document establishes the durable recovery baseline after browser acceptance testing exposed regressions between the previously accepted Church V7 FieldWiring prototype/contracts and the later generic browser application.

The objective is **not to redesign FieldWiring**. The objective is to restore the generic application to the already-reviewed behavior recorded in this branch before making additional improvements.

Repository history, controlled engineering documents, and regression tests are the authority for this recovery. Conversation memory is not a substitute for committed project evidence.

## Recovery Source Order

Use the following evidence in this order when a current implementation conflicts with prior behavior:

1. accepted FieldWiring engineering contracts/findings committed on this feature branch;
2. explicit acceptance commits and their diffs;
3. current LOR/V7/PostgreSQL topology and the read-only development snapshot;
4. current Controller Inventory source evidence where the physical interpretation was already reviewed;
5. current application implementation;
6. screenshots/operator observations as regression evidence.

A later generic implementation does not override an earlier accepted contract merely because it is executable code.

## Key Chronology

The physical-controller and field-presentation engineering was established **before** the generic browser renderer was connected.

Important pre-application checkpoints include:

- `1dce0d7962e242782e57567cc2bd983c9f6170af` — duplicate RGB Unit IDs clarified as positive evidence of additional physical Pixie controllers;
- `4c55d299da9c598ee7c7b49955ab1b80eeb14400` — duplicate RGB addresses carried into Controller Inventory boundaries;
- `4f9211d610408afb7357b1c4c2fd2f96856bd367` — Candyland corrected live pattern recorded as three repeated Pixie 4 blocks;
- `b994182befeaeda39bb63787aa4e5005f27884d2` — E1.31 dense RGB presentation contract established;
- `8a3a224e51db36480d70314532613f88b72b3bb0` — E1.31 added as a separate FieldWiring presentation family;
- `fd645942351a67da9e2cff87f4dbcb9ad2730e89` — E1.31 added to the FieldWiring subsystem contract;
- `63913c6ed3c1d6f8a3845fe327c035fa37a81086` — DMX/DumbRGB separated from DMX/RGB E1.31 presentation;
- `05052337c5543fcc0d298d66d5e0704cb71407f1` — A/C Unit-ID, shared-output, and multi-controller findings recorded;
- `610b8efd1189866addb7f8bbb2709147ce0f5d52` — image navigation/responsive UX documented;
- `03c858917d8cc734ef356defdaed9af38a37daa8` — split-pane image workspace defined;
- `7479d58bcd52849ccf55f182f9d3e4fe74b58233` — Church V7 desktop/browser image workspace explicitly accepted.

The browser application scaffold began later at `0347b4369f253ac944fa9b0a909c71dd9fc8c65b`.

The first generic renderer integration was `fa1afe1b12d809e9cf66a6dca2b9dd5dee6dcdcc`.

## Confirmed Integration Regression

The physical-presentation implementation introduced at `fa1afe1...` did not fully implement the already-accepted controller contracts.

In particular, its `wiring_presentation.py`:

- classifies every `device_type = DMX` row as one generic `DMX` family before considering `string_type`, even though the accepted contract requires `DMX + DumbRGB` and `DMX + RGB` to be different field families;
- treats a multi-row RGB Display as one controller with ordinal outputs, which is valid for reviewed cases such as the Church Tree and Crosses;
- places every remaining one-row RGB Display from the entire resolved Scene into one global sequence and only derives Pixie groups if that entire sequence forms one clean repeated block;
- therefore cannot correctly handle a mixed Scene containing several independent RGB controller patterns.

This explains why isolated fixture tests can pass while real Church, Candyland, and Who Forest browser results are wrong.

## Accepted Presentation Families

The accepted discriminator is:

```text
LOR + Traditional
    -> conventional A/C controller / numbered physical output

LOR + RGB
    -> Pixie controller / numbered physical RGB output

DMX + DumbRGB
    -> DMX fixture/network hookup

DMX + RGB — reviewed dense RGB cases
    -> E1.31 network / intelligent pixel-controller hookup
```

The generic compatibility-view `Controller` value does not have one physical meaning across these families.

## Accepted A/C Behavior

Normal A/C field presentation retains the useful LOR Unit ID and Network at controller level.

`StartChannel` is the physical Output / Plug for conventional A/C controllers.

One physical controller output may have multiple separate Display/Channel Name relationships. These must be shown as **one Output / Plug row with multiple connection entries**, not repeated as several apparent physical outputs.

Accepted example:

```text
A/C CONTROLLER · UNIT ID 41
Network: Regular

Output / Plug | Display              | Plug Label / Channel Name
1             | CH-Steeple-LH-Base   | CH 41-01 Steeple LH
              | CH-Steeple-LH-Top    | CH 41-01 Steeple LH-Top
              | CH-Steeple-RH-Base   | CH 41-01 Steeple RH
              | CH-Steeple-RH-Top    | CH 41-01 Steeple RH-Top
```

The atomic connection rows remain intact underneath the grouped presentation.

## Accepted LOR RGB / Pixie Patterns

### Church Tree

```text
CH-RGBTree-16x100-180
one physical Pixie 16
logical Unit IDs 30-3F
physical Outputs 1-16
```

### Church Crosses

```text
CH-RGBCross-LH -> one Pixie 2 -> Outputs 1-2
CH-RGBCross-RH -> one Pixie 2 -> Outputs 1-2
```

### Church Candy Canes

Two physical Pixie 4 controllers intentionally share the same programmed address block:

```text
Pixie group 1
    Output 1 -> CH-RGBCandyCane-01 -> Unit ID 21
    Output 2 -> CH-RGBCandyCane-02 -> Unit ID 22
    Output 3 -> CH-RGBCandyCane-03 -> Unit ID 23
    Output 4 -> CH-RGBCandyCane-04 -> Unit ID 24

Pixie group 2
    Output 1 -> CH-RGBCandyCane-05 -> Unit ID 21
    Output 2 -> CH-RGBCandyCane-06 -> Unit ID 22
    Output 3 -> CH-RGBCandyCane-07 -> Unit ID 23
    Output 4 -> CH-RGBCandyCane-08 -> Unit ID 24
```

The repeated `21-24` block is positive evidence of the second physical Pixie controller. It is not an addressing error.

### Candyland Candy Canes

The intended/current live Preview pattern is three physical Pixie 4 controllers using the same `21-24` block:

```text
01-04 -> 21,22,23,24
05-08 -> 21,22,23,24
09-12 -> 21,22,23,24
```

The live Preview correction of Candy Cane 12 from `22` to `24` is recorded in commit `4f9211d...`.

A stale development snapshot must not be silently rewritten by FieldWiring. The corrected value becomes development authority only through the normal parser/import cycle.

### Candyland RGB Lollipops — Recovered Pixie 16 Context

The Master Musical Preview itself establishes one contiguous `Aux C` LOR-RGB address block for the eight RGB Lollipop Displays:

```text
CL-Lollipop-Small-01 -> UID 50       -> physical Output 1
CL-Lollipop-Large-02 -> UIDs 51-52   -> physical Outputs 2-3
CL-Lollipop-Large-03 -> UIDs 53-54   -> physical Outputs 4-5
CL-Lollipop-Large-04 -> UIDs 55-56   -> physical Outputs 6-7
CL-Lollipop-Small-05 -> UID 57       -> physical Output 8
CL-Lollipop-Large-06 -> UIDs 58-59   -> physical Outputs 9-10
CL-Lollipop-Small-07 -> UID 5A       -> physical Output 11
CL-Lollipop-Small-08 -> UID 5B       -> physical Output 12
```

This is the previously reviewed **single Pixie 16 controller context with 12 currently used outputs**, not eight independent physical controllers. The unused Pixie 16 outputs remain unused; FieldWiring must not fabricate connections for them.

The separate `CL-LollipopStick-01` through `CL-LollipopStick-08` Displays are `LOR + Traditional` A/C relationships and remain in the A/C presentation family. They must not be merged into the RGB Pixie controller merely because they share the word `Lollipop` in their Display names.

### Who Forest

Eight distinct physical Pixie 8 controller contexts are confirmed by current V7 topology plus the 2025 controller inventory:

```text
WF-Tree-01 -> 50-57
WF-Tree-02 -> 58-5F
WF-Tree-03 -> 60-67
WF-Tree-04 -> 68-6F
WF-Tree-05 -> 70-77
WF-Tree-06 -> 78-7F
WF-Tree-07 -> 80-87
WF-Tree-08 -> 88-8F
```

Each controller must present physical Outputs 1-8 rather than exposing each Unit ID as a separate controller or collapsing the Scene into one `Other hookup` group.

Each Tree also has a corresponding RGB Star inside the same LOR address block. Current source conflicts such as Tree 4 network history remain visible and are not silently corrected.

### Santa's Workshop

Current V7 contains two accepted Pixie 8-style Tree contexts:

```text
SW-TreeRGB-LH -> 10-17
SW-TreeRGB-RH -> 18-1F
```

## Accepted DMX / E1.31 Boundary

`device_type = DMX` is not a sufficient physical-presentation discriminator.

```text
DMX + DumbRGB
    -> DMX fixture/network family

DMX + RGB
    -> reviewed E1.31 dense RGB family
```

Accepted dense-RGB examples include:

- Mega Tree — universes 1-48, physically one 48-output AlphaPix;
- Mega Ball — universes 49-64, physically one PixCon;
- Mega Cube — physically three PixCon controllers; generic compatibility row count is not controller count;
- Mega Star — universes 113-140 remain engineering addressing until physical mapping is authoritative;
- Mt. Crumpit Matrix — large universe blocks remain engineering addressing, not controller labels.

Raw universes are not physical-controller identities.

## Accepted Image Workspace Behavior

The Church V7 desktop/browser workspace accepted at `7479d58...` requires:

- upper image pane and lower independently scrollable hookup pane;
- independently scrollable image viewport;
- Show / Hide;
- Previous / Next and Page X/Y;
- Fit Width;
- Fit All;
- image-only zoom;
- draggable divider;
- desktop image initially expanded;
- narrow/mobile image initially collapsed;
- when image is hidden, the hookup pane immediately reclaims the released space;
- print/offline output returns to normal document flow rather than preserving nested scroll panes.

## Accepted Print Behavior

Printed/hard reports must reproduce the same physical hookup interpretation as the screen and remain subject to currentness/expiration controls.

When images exist, both published wiring image(s) and hookup rows remain printable.

The print layout must not preserve the browser split-pane scroll containers.

## Browser Lookup / Navigation State

The Browser Lookup V3 model is accepted. Display lookup and Stage/Scene browse converge on one resolved wiring context.

Current integration work has additionally proven:

- Stage/Scene browsing across the development snapshot works;
- Church Background / Static and Musical contexts can resolve to the same Stage documentation owner while selecting separate `Wiring\BackgroundStage` and `Wiring\MusicalStage` branches;
- light/dark mode works;
- centralized branding remains required;
- repeated opening of FieldWiring should not create an uncontrolled stack of browser tabs during normal lookup use.

A `Whole Stage` option is shown only when the current source actually provides a Stage/Root context. It must not be fabricated for a Stage that only has Scene contexts.

## Current Recovery Matrix

| Area | Accepted baseline | Current generic application at audit start | Recovery status |
|---|---|---|---|
| Browser Display lookup | Browser Lookup V3 | Working | PASS |
| Stage/Scene browse | Browser Lookup V3 | Working across development snapshot | PASS |
| Background/Musical Stage-owner branch selection | Current Drive contract | Working for Church after resolver repair | PASS |
| Drive image discovery | Same-scope published image rules | Working for Church | PASS |
| Light/dark mode | Accepted browser UX | Working | PASS |
| Centralized logo assets | `webassets.sheboyganlights.org` | Asset path repaired during testing; revalidate | VERIFY |
| Image Show/Hide | Hidden image returns pane space immediately | Regressed during integration/testing; later patch requires acceptance re-test | VERIFY |
| Independent image/hookup scrolling | Accepted V7 split pane | Current sizing/scroll behavior reported wrong in real browser | FAIL |
| A/C controller grouping | Unit ID + Network + one row per physical Output with all connection rows | Current rendering does not match accepted table | FAIL |
| Church Pixie 16 Tree | one Pixie 16, Outputs 1-16 | Current browser case observed correct | PASS |
| Church Pixie 2 Crosses | separate Pixie 2 contexts | Must be regression-tested in mixed Scene | VERIFY |
| Church two Pixie 4 Candy Cane groups | two groups, Outputs 1-4 each | Collapsed to `Other hookup` in real Church Scene | FAIL |
| Candyland three Pixie 4 Candy Cane groups | three groups, Outputs 1-4 each after controlled snapshot refresh | Collapsed to `Other hookup`; current dev snapshot may also be stale for Cane 12 | FAIL / SNAPSHOT REVIEW |
| Candyland RGB Lollipop Pixie 16 | one Pixie 16 context, Outputs 1-12 currently used across eight RGB Displays | Generic app split by individual Display row counts | FAIL |
| Who Forest eight Pixie 8 controllers | eight groups, Outputs 1-8 | Collapsed/misinterpreted as `Other hookup` | FAIL |
| Santa's Workshop Pixie 8 Trees | two groups, Outputs 1-8 | Not yet revalidated in generic app | VERIFY |
| DMX + DumbRGB family | separate DMX fixture/network family | Current classifier collapses every DMX row together | FAIL |
| DMX + RGB / E1.31 family | separate dense-RGB family | Current classifier collapses every DMX row together | FAIL |
| Print images + hookup | normal document flow with same physical interpretation | Improved but still reported inefficient/wrong while controller grouping is wrong | FAIL |
| Engineering details | raw addressing available but secondary | Present | PASS / VERIFY CONTENT |

## Root Cause at Recovery Start

The first generic renderer integration introduced a simplified physical-presentation classifier that did not implement the full pre-existing contracts.

This is the primary recovery defect.

Subsequent browser/CSS work must not be used to compensate for incorrect upstream controller groups.

## Recovery Gates

Before further UX improvement work, the generic application must pass these gates:

1. restore device-family discrimination, including `DMX + DumbRGB` versus `DMX + RGB`;
2. restore mixed-Scene Pixie classification without one global repeated-RGB sequence assumption;
3. prove Church contains its accepted A/C, Pixie 2, Pixie 4, and Pixie 16 physical presentation simultaneously;
4. prove Candyland contains its three repeated Pixie 4 groups and the separate RGB Lollipop Pixie 16 context without mixing the A/C Lollipop sticks into it;
5. prove Who Forest resolves eight Pixie 8 contexts with Outputs 1-8;
6. prove Candyland repeated Pixie 4 behavior against an authoritative refreshed snapshot or explicitly surface stale snapshot inconsistency without patching it;
7. preserve every atomic field-lead connection row through grouping;
8. only after controller-group tests pass, revalidate the accepted split-pane, narrow-screen, and print behavior;
9. keep FormView available as fallback/reference until FieldWiring is explicitly accepted.

## No-Redesign Rule

During this recovery:

- do not redesign PostgreSQL schema;
- do not invent permanent Controller Inventory identities;
- do not change LOR topology;
- do not rewrite stale snapshot data inside FieldWiring;
- do not redesign the Google Drive hierarchy;
- do not replace the deployed QR/scan identity contract;
- do not redesign the accepted Church V7 workspace merely to simplify implementation.

Any proposed change outside the accepted baseline must be separated from recovery work and explicitly reviewed after the baseline is restored.
