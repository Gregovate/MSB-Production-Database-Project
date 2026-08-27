# MSB Scanner Hardware and Tablet Integration

| Document control | Value |
|---|---|
| Status | CURRENT HARDWARE BASELINE / PARTIAL FIELD ACCEPTANCE COMPLETE |
| Current revision | 2026-08-27 |
| Primary upcoming use | Setup/Deployment scanning |

## Purpose

This document defines the hardware and browser-input strategy for MSB scanning workflows, including rugged tablets, industrial handheld scanners, workshop forklift use, and mobile park workflows.

The scanner is an input device. It does not own Production Database identity or workflow state. Permanent payload and scan-routing rules remain owned by the Labeling and Scanning subsystem.

## Current Hardware Baseline

MSB has procured rugged tablets intended to serve as mobile browser workstations.

The current tested Android host is:

```text
HOTWAV R9 Ultra rugged tablet
Android 15
Bluetooth HID scanner input tested
Primary current role: mobile MSB browser workstation / scanner host
```

MSB purchased one industrial cordless scanner kit:

```text
Zebra DS3678-HD
Kit: DS3678-HD3U4210SFW
Series: Zebra 3600 Ultra-Rugged
Decode type: 1-D / 2-D imager
Variant: High Density (HD)
Connection kit: USB cradle/cable/power kit
Feedback: vibration motor included
Original intended deployment: workshop forklift / shop storage workflows
Secondary candidate deployment: close-range park unloading / trailer receiving
```

Direct Bluetooth HID keyboard pairing from the DS3678-HD to the HOTWAV Android tablet has now been proven operational.

The DS3678-HD failed the practical forklift working-distance acceptance test described below. It remains a valid close-range scanner candidate.

A Zebra DS3678-ER has been ordered for extended-range forklift evaluation. It is not yet accepted; it must be tested with the actual HOTWAV tablet, actual MSB labels, and real forklift/rack distances.

The Zebra is not currently intended to be the primary general-purpose park scanner. Park workflows are expected to rely more heavily on rugged tablets/phones, camera scanning where useful, and GPS/location context.

However, the DS3678-HD may still be a good fit for a **park unloading checkpoint** where an operator is standing beside a trailer or load and can scan Containers/Displays at close range as they are unloaded. That role does not require across-aisle or long-distance scanning and remains separate from forklift-seat range acceptance.

The DS3678-HD is the first real industrial-scanner acceptance platform. Future hardware recommendations must use measured shop and unloading results rather than remain purely conceptual.

## Scanner Capability

The DS3678-HD supports the symbologies required by the current MSB identity direction, including Code 128 and QR-class 2-D codes.

Zebra documents USB HID Keyboard as a supported USB host mode for the DS3678 family. The scanner also supports direct Bluetooth HID keyboard operation.

On 2026-08-27, direct Bluetooth HID from the DS3678-HD to the HOTWAV R9 Ultra Android tablet was verified operational. The scanner successfully behaved as a keyboard input device in the Android browser and populated the focused MSB Scan input field.

This confirms that the MSB browser architecture does not require a custom Zebra Android application or scanner-specific database driver for ordinary barcode capture.

Other Zebra interface modes exist, but do not introduce a more complex scanner protocol unless the real workflow proves HID insufficient.

## Important Range Classification

The purchased scanner is the **HD — High Density** model. It is not the DS3678-ER extended-range model.

Representative Zebra typical working ranges for DS36X8-HD include approximately:

```text
Code 128, 5 mil     -> 0.9 to 7.0 in.
Code 128, 15 mil    -> 0.9 to 23 in.
Code 39, 20 mil     -> 0.25 to 34 in.
Data Matrix, 10 mil -> 1.0 to 9.0 in.
```

Actual range depends on barcode size/density, print quality, contrast, angle, ambient light, and label material.

That range is appropriate for controlled close-range use where the operator can bring the scanner close to the Container or label. It is also compatible with a park unloading role where the scanner operator is standing immediately beside the material being unloaded. It must not be documented as an across-aisle or extended-range scanner.

## Workshop Forklift Acceptance Result — DS3678-HD

The DS3678-HD was field-tested on 2026-08-27 with the HOTWAV R9 Ultra Android tablet using direct Bluetooth HID keyboard input.

Observed result:

```text
Bluetooth HID connection to HOTWAV Android tablet -> PASS
Browser input to MSB Scan page                    -> PASS
Approximate range on ~6-inch Code 128 test code   -> about 4 feet
Forklift working-distance acceptance              -> FAIL
```

The approximately four-foot result was achieved with a large Code 128 test barcode and is still inadequate for the intended forklift/rack workflow.

The DS3678-HD is therefore **not accepted as the workshop forklift scanner**.

Do not spend further engineering effort trying to make the HD optical variant serve an extended-range forklift role. Retain it only where its close-range performance is operationally appropriate.

The ordered DS3678-ER is the next forklift acceptance candidate.

## Workshop Forklift Acceptance Requirement — DS3678-ER

Before accepting the DS3678-ER as the workshop forklift standard, test it from the actual operating position with the actual MSB labels.

Acceptance should include:

- current Container labels;
- current Display labels where relevant to the workflow;
- future rack/location labels only after their final payload/layout is approved;
- laminated labels if used in production;
- actual mounting/holding position from the forklift seat;
- realistic rack/container distances and angles;
- bright shop lighting and darker aisles;
- operator gloves;
- vibration/noise conditions;
- repeated rapid scans rather than one successful demonstration.

If some future workshop task genuinely requires greater range than the ER provides, evaluate a different ER/XR-class device for that task rather than distorting the browser workflow or encouraging unsafe operator reach.

## Park Unloading Acceptance Requirement

The DS3678-HD should still be tested as a separate **close-range unloading scanner** for Setup/Deployment.

That workflow may look like:

```text
trailer / truck arrives
    -> operator stands beside unloading point
        -> each Container/Display is scanned as it comes off
            -> browser validates expected load / destination
                -> Setup workflow records the accepted unloading/receiving event
```

Acceptance should verify:

- direct Bluetooth HID remains reliable in the actual park environment;
- the cradle/power arrangement is practical if used for charging or temporary storage;
- the operator can scan actual Container/Display labels without slowing unloading;
- vibration/feedback is clear enough in outdoor/noisy conditions;
- the workflow can auto-submit or advance without repeated screen touches;
- the scanner can move between workshop and park without creating a fragile reconfiguration process.

This close-range role is distinct from GPS/site placement. The scanner confirms **which asset is being unloaded**; GIS/GPS may then help determine or validate **where that asset belongs**.

## Browser Input Contract

MSB scan applications must support industrial scanners independently of camera scanning.

The verified Android path is:

```text
Zebra scanner
    -> direct Bluetooth HID keyboard input
        -> HOTWAV R9 Ultra Android tablet
            -> focused browser scan field
                -> MSB scan parser/router
```

USB HID through the cradle remains a possible host arrangement where practical, but it is not required for the verified HOTWAV Bluetooth workflow.

The browser workflow must not require camera APIs for normal industrial-scanner operation.

Camera scanning remains a separate input mechanism on phones/tablets. Camera and HID scans must resolve to the same canonical payload and use the same business logic.

## Existing Printed Display and Container Labels

Display and Container labels are already physically printed.

The deployed printed labels currently encode full MSB scan URLs, for example:

```text
https://db.sheboyganlights.org/scan/DISP/7
https://db.sheboyganlights.org/scan/CONT/216
```

These existing labels are a physical compatibility constraint. Scanner/application engineering must continue to support them; replacing or reprinting the existing Display and Container label population is not the remediation path for scanner UX problems.

This deployed fact is distinct from the canonical `TYPE:KEY` identity contract. The current MSB Scan page already accepts both the deployed full URLs and compact canonical values such as:

```text
DISP:7
CONT:216
```

## Bluetooth HID Full-URL Performance Finding

During Android Bluetooth HID testing on 2026-08-27, full URL payloads from the existing printed Display and Container labels were visibly transmitted to the Android browser as keyboard input over several seconds.

This is functionally correct but **not acceptable for repetitive high-volume scanning**.

The delay is an input/UX problem rather than an identity-resolution failure. The scanner decoded the labels correctly and the browser received the correct value.

Candidate remediation is scanner-side data formatting so that an existing printed full URL such as:

```text
https://db.sheboyganlights.org/scan/CONT/216
```

is transmitted over HID as the shorter equivalent:

```text
CONT:216
```

and similarly:

```text
https://db.sheboyganlights.org/scan/DISP/7
```

can be transmitted as:

```text
DISP:7
```

Zebra Advanced Data Formatting / 123Scan is the current candidate mechanism. This is **not yet an accepted scanner configuration** and must be tested before it becomes the controlled MSB scanner setup.

The application identity contract should not be changed merely to compensate for HID keystroke timing.

## Storage Location Label Status

Storage Location labels have **not** yet been printed.

Unlike the already-deployed Display and Container labels, there is therefore no existing Location-label URL compatibility constraint.

Current approved identity direction for discrete workshop/rack locations remains the compact canonical payload:

```text
LOC:<location_code>
```

Example used during scanner testing:

```text
LOC:RB07-B-01
```

Future Storage Location label design should be validated with the DS3678-ER and the actual rack operating distance before production printing.

Do not infer from the existing Display and Container labels that future Storage Location labels must encode a full scan URL.

## Storage Location Scan Route Finding

During 2026-08-27 testing, entering/scanning:

```text
LOC:RB07-B-01
```

on the current MSB Scan page caused the browser to navigate to:

```text
/scan/LOC/RB07-B-01
```

The deployed Directus scan extension returned `ROUTE_NOT_FOUND` because a `/scan/LOC/:key` route is not currently implemented.

This establishes a separate application gap from the scanner hardware work:

```text
LOC payload recognition / client routing -> present
LOC server route                         -> missing
```

Do not print production Storage Location labels until the intended Location scan behavior is implemented and accepted. The missing route must be resolved in the Scan/Setup workflow rather than hidden by scanner-specific behavior.

## Shop Versus Park Input Boundary

The expected deployment model is deliberately different by environment, while still allowing the same industrial scanner to serve a useful close-range park role.

### Workshop / storage

Primary interaction direction:

```text
extended-range Zebra scanner
    -> Container barcode/QR
    -> rack/storage Location barcode/QR
    -> browser workflow
```

The DS3678-ER is the current ordered candidate for this role. This environment uses discrete, already-designed rack/storage locations and favors fast repeated HID scans.

### Park unloading / receiving

Candidate interaction:

```text
Zebra DS3678-HD or accepted equivalent
    -> Container / Display barcode or QR at close range
    -> browser load/unload workflow
    -> expected destination / Setup context
```

This remains a strong candidate use for the HD because the scanner operator can stand beside the trailer/load. It does not depend on long-range aiming from a vehicle seat.

### Park placement / field navigation

Primary interaction is expected to be:

```text
rugged tablet / phone
    -> Display or Container QR when needed
    -> GPS / mapped site-location context
    -> browser workflow
```

Park placement should not be forced into a rack-label scanning model merely for consistency. Site/GIS location identity and GPS validation belong with the Site Infrastructure/GIS and Setup/Deployment contracts.

## Terminator / Auto-Submit Requirement

The controlled scanner suffix/terminator is still pending acceptance.

The eventual shop and unloading Setup scan screens should allow repetitive operation without requiring the operator to touch the screen after every scan. An Enter/Carriage Return style terminator remains the likely direction if it produces the intended browser behavior.

The exact suffix and any Zebra ADF rules must be tested together and then documented as one controlled scanner configuration.

## Tablet / Host Integration

Direct Bluetooth HID between the Zebra DS3678-HD and HOTWAV R9 Ultra Android tablet is now verified.

This removes the previous assumption that the USB cradle must be the communications host for the Android deployment. The cradle may still be used for charging, storage, pairing/configuration, or another accepted operational purpose.

For forklift deployment, verify:

- reliable Bluetooth reconnect behavior after scanner/tablet sleep or power cycling;
- practical charging behavior for both scanner and tablet;
- secure tablet mounting;
- secure scanner/cradle placement;
- vehicle-safe power where charging is provided on the forklift;
- no cabling or mounting that obstructs controls or visibility.

The scanner must not connect directly to PostgreSQL. The browser application interprets the decoded asset payload and communicates with the approved backend over the network.

## Physical Installation

Workshop forklift installation should provide:

- secure scanner cradle mounting or protected placement;
- secure tablet mounting;
- vehicle-safe power for the tablet and scanner cradle when used;
- cable strain relief for any installed charging cables;
- access without obstructing controls or visibility;
- a scanner location that does not encourage use while the forklift is moving;
- practical return-to-cradle/charging behavior.

Park unloading use should favor a simple temporary station or protected mobile host arrangement rather than permanently mounting the scanner to a park location before the real workflow is proven.

## Network Requirement

The field workstation/tablet requires application connectivity throughout the intended workflow areas, including:

- storage/rack aisles;
- workshop staging areas;
- loading zones;
- park unloading/receiving points;
- park Setup/Deployment scan points where online validation is required.

Bluetooth scanner connectivity does not replace application network connectivity.

## Label Compatibility

Canonical identity direction remains:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

Existing printed Display and Container labels use full scan URLs and remain supported deployed artifacts.

`LOC:` is most directly applicable to discrete Production Database location identities such as workshop/rack locations. Park geospatial destinations may use a durable site-location identity resolved through GIS rather than requiring a physical `LOC:` barcode at every destination.

The scanner/application must read the payload as data and route it through the scan platform. Physical labels must not encode annual setup state, load number, destination application, or other transient workflow information.

Future Storage Location label size/density should be chosen from actual DS3678-ER forklift testing rather than theoretical minimum barcode sizes.

## Setup/Deployment Implication

The upcoming Setup project should assume multiple input mechanisms but one business-resolution layer:

```text
shop industrial scanner       -> HID keyboard input
park unloading scanner        -> HID keyboard input where practical
field phone/tablet            -> camera scan and/or GPS context
```

All must resolve permanent Production Database identities. Do not build separate Container or Display business logic based on how the identifier was captured.

GPS is context/measurement, not asset identity.

## Known Open Work

- receive and inspect the ordered DS3678-ER;
- perform actual forklift/rack range acceptance testing with the DS3678-ER;
- test existing printed Container and Display labels at real forklift distances;
- determine and test the controlled scanner suffix/terminator;
- test Zebra ADF / 123Scan shortening of existing full Display and Container scan URLs for Bluetooth HID use;
- verify Bluetooth reconnect behavior after scanner/tablet sleep and power cycling;
- implement and accept the intended `/scan/LOC/:key` application behavior before printing production Location labels;
- design and range-test the future Storage Location labels with the accepted forklift scanner;
- test the DS3678-HD as a close-range park unloading/receiving device;
- determine mounting, cradle power, charging, and cable protection;
- include industrial-scanner input in Setup/Deployment application acceptance tests;
- separately engineer park GPS/site-location behavior with Site Infrastructure/GIS rather than assuming the Zebra scanner replaces field location logic.

## Resume Development

For workshop hardware work, begin with the ordered DS3678-ER when received, the HOTWAV R9 Ultra, the already-printed Display and Container labels, and the real forklift operating position.

Do not repeat Bluetooth HID feasibility reconnaissance; direct Zebra-to-HOTWAV Android Bluetooth HID is already proven.

For scanner configuration work, evaluate Zebra 123Scan/ADF against the existing full-URL Display and Container labels and verify that shortening the HID output does not break the canonical MSB scan behavior.

For Storage Location work, continue from the established fact that Location labels are not yet printed and that the current `/scan/LOC/:key` server route is missing. Implement and accept the intended Location workflow before production Location-label printing.

For park unloading hardware work, retain the DS3678-HD as a close-range candidate and test it beside the trailer/load with the actual park tablet/workstation and normal unloading pace.

For application work, preserve HID keyboard input as a first-class scan path while keeping camera/GPS field input additive.

## Related Documents

- [Labeling and Scanning](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Scan Workflows and Forklift Operations](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
