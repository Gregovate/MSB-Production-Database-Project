# Setup-Season Scan Integration Handoff — 2026-09-02

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Labeling and Scanning / Scan / Setup and Deployment |
| Status | CURRENT WORKING HANDOFF |
| Owner | MSB Technical Team |
| Date | 2026-09-02 |

## Purpose

Preserve the current cross-system boundary and resume point for getting MSB Scan, physical labels, scanner hardware, and Setup/Deployment ready to work together for Setup season without collapsing them into one implementation workstream.

Primary coordination issue: **#113 — Prepare Scan application and Setup-season scanning integration**.

Focused work remains in:

- **#88** — Setup-critical Location scan resolution and movement workflow;
- **#112** — camera permission failure/recovery;
- **#67** — Scan operator documentation and intranet discovery.

LabelPrintService V4 remains a separate implementation workstream in `Gregovate/MSB_LabelPrintService`.

## End-to-End Boundary

```text
Production Database identity / label request
    -> MSB_LabelPrintService / physical label
    -> Zebra scanner, phone camera, or manual entry
    -> canonical captured identifier
    -> Scan application identity resolution
    -> Setup/Deployment or other owning operational workflow
```

Each layer has a different owner:

- Production Database owns authoritative identities and operational data;
- Labeling and Scanning owns the permanent label/payload/scan contract;
- LabelPrintService owns physical-print rendering/runtime behavior;
- scanner/camera/manual entry are capture methods only;
- Scan resolves captured identity and presents valid task entry points;
- Setup/Deployment owns the business meaning of movement, staging, loading, delivery, park placement, and related operational state.

Do not move transaction meaning into scanner programming or physical labels.

## Canonical Captured Identifiers

Current compact identifiers are:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
CTRL:<controller_id>
```

Zebra scanners have been configured to report compact canonical values for deployed Display/Container/Location scanning instead of typing the full scan URL.

This is an input-method normalization convenience. The Scan application must not require Zebra-specific behavior. Manual entry, camera decode, Zebra HID input, and supported legacy/full URLs must converge on the same identity resolution where compatibility is required.

## Current Known Scan Problems

As of this handoff:

- reaching the Scan application is cumbersome and needs one obvious supported operator entry point;
- `DISP` is the most developed route;
- `CONT` exists but has limited result/actions;
- `LOC` does not yet have complete route/resolution behavior; focused implementation is #88;
- `CTRL` needs a Scan route/result now that permanent Controller Inventory IDs exist;
- iPhone behavior is not accepted merely because a camera preview opens; actual barcode/QR decode and correct routing must be physically verified;
- camera-permission failure/recovery remains #112;
- operator documentation in #67 must follow corrected deployed behavior rather than freezing current defects into SOPs.

## Setup-Season Direction

Setup requires more than document lookup. The system must be prepared to use permanent Display, Container, Location, and eventually Controller identity for field operations including location awareness and park movement.

The Scan application should resolve identity; it must not invent movement semantics.

Setup/Deployment must explicitly define what accepted scan interactions mean, such as:

- locating or confirming a Container;
- locating or confirming a Display;
- associating an asset/container with a current park or staging location;
- validating expected destination;
- recording a meaningful pull, staging, load, delivery, placement, or relocation event where the Setup workflow actually requires it.

Do not infer a destructive state change solely from scan order.

## Physical-Label Gate

Display and Container labels already exist operationally and must not be invalidated casually.

Before volume printing new Location or Controller labels:

1. verify the canonical identity/payload;
2. verify the corresponding Scan route/result;
3. verify the intended operator workflow;
4. test actual Zebra/camera behavior and useful range with the real label design;
5. confirm compatibility expectations for existing labels and devices.

## Resume Order

A new Scan engineering thread should begin by:

1. reading this handoff and Issue #113;
2. refreshing current remote `main` before editing;
3. inventorying current `Scan/directus-extension-scan/` source and current deployed Scan baseline/runbook;
4. documenting the current route matrix for `DISP`, `CONT`, `LOC`, and `CTRL` before changing code;
5. resolving the operator entry/navigation problem;
6. verifying capture methods independently: manual, Zebra HID, Android camera, iPhone camera;
7. implementing/accepting focused route gaps without redesigning LabelPrintService;
8. continuing #88 for Setup-critical Location and movement semantics;
9. updating #67 operator docs only after actual device/route acceptance.

## Non-Goals for the Scan Thread

Do not:

- redesign LabelPrintService V4 unless the Scan work proves an interface defect;
- move the root `Scan/` application merely for repository organization;
- replace permanent identities with annual Setup-session identity;
- encode transient load, staging, delivery, or park state into permanent labels;
- make the Scan resolver dependent on Zebra configuration;
- finalize operator documentation against known-bad Scan behavior.
