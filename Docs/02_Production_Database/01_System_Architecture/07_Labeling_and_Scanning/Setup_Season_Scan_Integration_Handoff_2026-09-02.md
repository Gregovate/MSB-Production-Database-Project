# Setup-Season Scan Integration Handoff — 2026-09-02

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Labeling and Scanning / Scan / Setup and Deployment |
| Status | CURRENT WORKING HANDOFF |
| Owner | MSB Technical Team |
| Date | 2026-09-04 |

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

The Zebra ADF correction was first checked in Google Docs, then a printed Controller `1031` label passed the production end-to-end route on 2026-09-03. The Zebra emitted `CTRL:1031`, submitted Enter, and opened Controller 1031 after the operator manually selected the Scan entry field.

This is an input-method normalization convenience. The Scan application must not require Zebra-specific behavior. Manual entry, camera decode, Zebra HID input, and supported legacy/full URLs must converge on the same identity resolution where compatibility is required.

## Current Known Scan Problems

As of the 2026-09-03 reconnaissance:

- the MSB Internal home page at `https://my.sheboyganlights.org/` now provides the obvious supported **Open Scan** entry point; the former discovery/navigation problem is resolved;
- `DISP` is the most developed route;
- `CONT` is accepted for its current purpose: it opens the Directus Container record, where the original design exposes assigned Displays;
- `LOC` does not yet have complete route/resolution behavior; focused implementation is #88;
- production Controller Inventory is deployed at `/fieldwiring/controllers` and accepts `?controller_id=<id>` for exact detail selection;
- the deployed `CTRL` Scan route sends permanent Controller identity to the existing Controller Inventory instead of building a duplicate result page;
- a printed Controller `1031` label passed phone-camera and Zebra DS3678-ER end-to-end routing;
- the tablet does not reliably focus the Scan entry field when the app opens, so the Zebra currently requires an unnecessary operator tap before scanning; this is an input-focus defect under #113;
- iPhone behavior is not accepted merely because a camera preview opens; actual barcode/QR decode and correct routing must be physically verified;
- camera-permission failure/recovery remains #112;
- operator documentation in #67 must follow corrected deployed behavior rather than freezing current defects into SOPs.

## Current-State Matrix

`Source-supported` means the current code path accepts the input. `Input-only verified` means the Zebra emitted the expected value in Google Docs; it is not an end-to-end route acceptance result.

| Type | Manual | Zebra HID | Android camera | iPhone camera | Route exists | Result/actions |
|---|---|---|---|---|---|---|
| `DISP` | Source-supported | Input-only verified in current test pass | Physical decode/routing acceptance not recorded in this pass | Camera may open; real-label decode/routing not accepted | Yes — production | Existing Display hub: Directus record, Testing, Container, Work Orders, Field Wiring, and Procedures |
| `CONT` | Source-supported | End-to-end Container scan reported working; compact ADF output independently verified | Physical decode/routing acceptance not recorded in this pass | Camera may open; real-label decode/routing not accepted | Yes — production | Opens the Directus Container record and its Display assignments; preserve this accepted behavior |
| `LOC` | Landing-page normalization exists, but destination fails because no route exists | Compact ADF output verified only | Not accepted | Not accepted | No | #88 must supply Location resolution and the minimum Setup-owned operator workflow |
| `CTRL` | PASS — compact and full URL entered manually in production | PASS with printed `CTRL:1031`; current tablet requires the entry field to be tapped first | Not classified — a phone-camera decode passed, but its OS was not recorded | Not classified — a phone-camera decode passed, but its OS was not recorded | Yes — production | Redirects to Controller Inventory with `controller_id=<id>`, filters Search, and opens exact detail |

The Controller capture contract is:

```text
phone/tablet camera QR
    -> https://db.sheboyganlights.org/scan/CTRL/<controller_id>

Zebra HID or manual compact entry
    -> CTRL:<controller_id>

both
    -> /scan/CTRL/<controller_id>
    -> https://my.sheboyganlights.org/fieldwiring/controllers?controller_id=<controller_id>
```

Controller Inventory remains the owner of Controller details and actions. Scan only resolves and hands off permanent identity.

## Label-Request Interface Findings

- Controller Inventory and the external LabelPrintService now produce Controller labels; remaining print-service issues stay in that separate workstream.
- No usable operator interface currently exists to select Displays and request their labels. That is a database/label-request UI gap, not part of the bounded `CTRL` Scan route.
- Do not volume-print Controller labels until the Scan route, operator destination, Zebra/camera behavior, and real-world scan distance pass the physical-label gate below.

## Smallest Ordered Repair Plan

1. Repair Scan landing-page focus under #113 so Zebra HID works immediately without selecting the field, then physically retest initial load and return-to-Scan behavior.
2. Complete `LOC` resolution and the minimum Setup-owned operator action under #88; do not infer movement from scan order.
3. Complete OS-specific Android/iPhone decode and camera permission/recovery acceptance under #112.
4. Finish operator SOP review under #67 against the deployed routes and accepted device behavior.
5. Add broader Setup movement/staging/load semantics only where the reconstructed operational process proves they are needed.

Keep #113 as the umbrella and keep #88, #112, and #67 focused; do not create a new issue for each small finding.

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
4. using the current route matrix above instead of reconstructing `DISP`, `CONT`, `LOC`, and `CTRL` state from chat;
5. preserving the now-deployed MSB Internal **Open Scan** entry point;
6. verifying capture methods independently: manual, Zebra HID, Android camera, iPhone camera, including reliable initial input focus for HID;
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
