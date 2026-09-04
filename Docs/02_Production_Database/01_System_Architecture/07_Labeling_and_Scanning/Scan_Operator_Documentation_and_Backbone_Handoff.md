# Scan Operator Documentation and Backbone Handoff

| Document Control | Value |
|---|---|
| Document Type | Engineering / Documentation Handoff |
| System | Labeling and Scanning |
| Status | CURRENT — placement decision accepted; operator content in progress |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-08-24 |
| Related Work | Production Database issue #67 |

## Purpose

Preserve the accepted documentation ownership and presentation boundary for the MSB Scan system so future documentation work does not have to reconstruct the decision from chat history.

This handoff is intentionally limited to Scan. It does not settle the broader documentation-tree question for the older LOR umbrella system.

## Accepted Scan Documentation Boundary

The application remains at the repository root:

```text
Scan/
```

Do not move the application merely to make documentation folders look uniform.

Scan engineering documentation remains in the established Production Database engineering area:

```text
Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/
```

Scan operator documentation is owned in the established Production Database operational area:

```text
Docs/02_Production_Database/02_Operational_SOPs/Scanning/
```

The Production Database operator index remains:

```text
Docs/02_Production_Database/02_Operational_SOPs/README.md
```

That README is the source-side operator table of contents. `Scanning/README.md` is the Scan-specific operator introduction/task index.

## Accepted Operator Document Set

The first Scan operator set covers:

1. introduction to the Scan system;
2. manual Scan entry;
3. QR/code types and meanings;
4. phone/tablet camera setup;
5. what to do after scanning an item.

Current source paths are:

```text
Docs/02_Production_Database/02_Operational_SOPs/Scanning/
├── README.md
├── Use_Scan_Manually.md
├── QR_Code_Types_and_Meanings.md
├── Set_Up_Phone_or_Tablet_for_Scanning.md
├── What_To_Do_After_You_Scan.md
└── images/
```

## Image Ownership

Screenshots used by these Scan operator documents must remain physically close to the Markdown that uses them.

For this Scan operator set, the local image owner is:

```text
Docs/02_Production_Database/02_Operational_SOPs/Scanning/images/
```

Do not place new Scan operator screenshots in a generic global image bucket when the image is owned only by this operator documentation.

This is a Scan-specific application of the broader documentation-image locality discussion tracked under documentation reconciliation issue #49.

## Operator Mental Model

Volunteers must not be expected to know or navigate:

- repository folder paths;
- branches or commits;
- GitHub engineering navigation;
- the distinction between application source folders and documentation folders.

Those structures exist for maintainers.

The volunteer mental model should be task-oriented, for example:

```text
Scanning
    -> About Scan
    -> Scan something manually
    -> Understand the QR codes
    -> Set up my phone/tablet
    -> What do I do after I scan something?
```

## One Authoritative Document Source

The Production Database repository remains the authoritative editable source for the Scan operator Markdown.

`my.sheboyganlights.org` is the normal discovery/presentation/search layer.

The intranet must not create a second independently maintained copy of the operator manual. A rendered or automatically published presentation derived from the authoritative Markdown is acceptable; a separate hand-maintained HTML/manual copy is not.

## Existing Backbone Capability Verified

The current `Gregovate/MSB-Internal-Web-Backbone` repository already contains a Docsify documentation reader at:

```text
my/read/
```

Its current `my/read/index.html` loads the Docsify search plugin and exposes a `Search docs…` search box.

Therefore the remaining engineering problem is not to build a documentation reader/search engine from scratch. It is to define and implement a controlled single-source publication/rendering path from authoritative Production Database operator Markdown into the existing Backbone reader/search experience.

## Search / Discovery Direction

Normal volunteer search should prioritize current operator material using metadata such as:

- Document Type;
- System;
- Task;
- Audience;
- Status;
- Owner;
- Last Reviewed;
- Keywords.

Engineering contracts, implementation notes, dated acceptance records, compatibility pointers, and historical material must not appear as equivalent normal operator task choices.

Useful Scan search intents include:

- scan a display;
- scan a container;
- QR code;
- enter a scan manually;
- set up phone camera;
- field wiring;
- procedures;
- testing;
- work orders.

## Current Verified Scan Boundary Used By The Operator Draft

The current Scan application verifies:

- the **MSB Scan** page;
- **Scan code or paste URL**;
- **Go**;
- **Scan with Camera**;
- current Display Scan landing behavior;
- current Container Scan landing behavior; and
- deployed Controller handoff to exact Controller Inventory Search/detail from manual, phone-camera, and Zebra input.

The approved identity standard includes `DISP`, `CONT`, `LOC`, and `CTRL`, but the operator documentation must distinguish approved identity types from workflows actually deployed and accepted.

Do not document a complete `LOC` workflow until it is implemented and verified. The deployed `CTRL` route and physical Controller `1031` phone-camera/Zebra result may be documented. Keep the tablet initial-focus defect visible until the repair is deployed and physically accepted, and do not claim separate Android/iPhone acceptance until the tested operating systems are recorded.

## Remaining Acceptance Work

Before the Scan operator set becomes CURRENT:

1. review the wording with an operator/volunteer audience in mind;
2. capture current screenshots from the real Scan UI;
3. physically verify phone/tablet camera permission and successful scanning on the device types volunteers use;
4. physically verify Zebra scanning works immediately after Scan opens without first tapping the entry field;
5. add those screenshots under `Scanning/images/` and verify Markdown rendering;
6. complete the Backbone single-source publication/rendering decision;
7. create/link the corresponding Backbone implementation work when the source-side package is ready;
8. verify volunteer search/navigation on deployed `my.sheboyganlights.org`.

## Related Documents

- [Labeling and Scanning Engineering Handoff](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Production Database Operator Scan Guide](../../02_Operational_SOPs/Scanning/README.md)
