# MSB Scanner Hardware and Tablet Integration

| Document control | Value |
|---|---|
| Status | CURRENT HARDWARE BASELINE / FIELD ACCEPTANCE PENDING |
| Current revision | 2026-08-22 |
| Primary upcoming use | Setup/Deployment scanning |

## Purpose

This document defines the hardware and browser-input strategy for MSB scanning workflows, including rugged tablets, industrial handheld scanners, workshop forklift use, and mobile park workflows.

The scanner is an input device. It does not own Production Database identity or workflow state. Permanent payload and scan-routing rules remain owned by the Labeling and Scanning subsystem.

## Current Hardware Baseline

MSB has procured rugged tablets intended to serve as mobile browser workstations.

MSB has also purchased one industrial cordless scanner kit for the **workshop forklift**:

```text
Zebra DS3678-HD
Kit: DS3678-HD3U4210SFW
Series: Zebra 3600 Ultra-Rugged
Decode type: 1-D / 2-D imager
Variant: High Density (HD)
Connection kit: USB cradle/cable/power kit
Feedback: vibration motor included
Intended deployment: workshop forklift / shop storage workflows
```

The Zebra is not currently intended to be the primary park scanner. Park workflows are expected to rely more heavily on rugged tablets/phones, camera scanning where useful, and GPS/location context.

This purchased device is the first real industrial-scanner acceptance platform. Future hardware recommendations should use its measured shop results rather than remain purely conceptual.

## Scanner Capability

The DS3678-HD supports the symbologies required by the current MSB identity direction, including Code 128 and QR-class 2-D codes.

Zebra documents USB HID Keyboard as the default USB host mode for the DS3678 family. This aligns with the MSB browser architecture: a successful scan can arrive at the focused browser control as keyboard input without a custom database/scanner driver.

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

That range may be entirely adequate for controlled workshop/forklift use where the operator can bring the scanner close to the Container or rack-location label. It should not be documented as an across-aisle or extended-range scanner.

## Workshop Forklift Acceptance Requirement

Before accepting the DS3678-HD as the workshop forklift standard, test it from the actual operating position with the actual MSB labels.

Acceptance should include:

- current Container barcode/QR labels;
- existing rack-location labels;
- laminated labels if used in production;
- actual mounting/holding position from the forklift seat;
- realistic rack/container distances and angles;
- bright shop lighting and darker aisles;
- operator gloves;
- vibration/noise conditions;
- repeated rapid scans rather than one successful demonstration.

If some future workshop task genuinely requires multi-foot or across-aisle scanning, evaluate an ER/XR-class device for that task rather than distorting the browser workflow or encouraging unsafe operator reach.

## Browser Input Contract

MSB scan applications must support industrial scanners independently of camera scanning.

The preferred shop baseline is USB/HID keyboard input:

```text
scanner
    -> cordless link to cradle
        -> USB HID keyboard input to workstation/tablet host
            -> focused browser scan field
                -> scan parser/router
```

The browser workflow must not require camera APIs for normal industrial-scanner operation.

Camera scanning remains a separate input mechanism on phones/tablets. Camera and HID scans must resolve to the same canonical payload and use the same business logic.

## Shop Versus Park Input Boundary

The expected deployment model is now deliberately different by environment.

### Workshop / storage

Primary interaction:

```text
Zebra DS3678-HD
    -> Container barcode/QR
    -> rack/storage Location barcode/QR
    -> browser workflow
```

This environment uses discrete, already-designed rack/storage locations and favors fast repeated HID scans.

### Park / field

Primary interaction is expected to be:

```text
rugged tablet / phone
    -> Display or Container QR when needed
    -> GPS / mapped site-location context
    -> browser workflow
```

Park placement should not be forced into a rack-label scanning model merely for consistency. Site/GIS location identity and GPS validation belong with the Site Infrastructure/GIS and Setup/Deployment contracts.

## Terminator / Auto-Submit Requirement

During hardware acceptance, determine and deliberately standardize the scanner suffix used by MSB—normally an Enter/Carriage Return style terminator if that fits the application.

Do not assume the scanner's current suffix configuration.

The eventual shop Setup scan screen should allow repetitive operation without requiring the forklift operator to touch the screen after every scan. The exact behavior must be tested with the DS3678-HD and then documented as the controlled scanner configuration.

## Tablet / Host Integration

The USB cradle must connect to a host that supports the selected USB mode.

Before workshop forklift deployment, verify the actual rugged tablet or mounted workstation provides the required USB host connection, power arrangement, and secure cabling for the cradle.

The scanner should not connect directly to PostgreSQL. The browser application interprets the decoded asset payload and communicates with the approved backend over the network.

## Physical Installation

Workshop forklift installation should provide:

- secure cradle mounting or protected placement;
- secure tablet/workstation mounting;
- vehicle-safe power for the tablet and scanner cradle;
- cable strain relief;
- access without obstructing controls or visibility;
- a scanner location that does not encourage use while the forklift is moving;
- practical return-to-cradle/charging behavior.

## Network Requirement

The field workstation/tablet requires application connectivity throughout the intended workflow areas, including:

- storage/rack aisles;
- workshop staging areas;
- loading zones;
- park Setup/Deployment scan points where online validation is required.

Scanner-to-cradle communication does not replace application network connectivity.

## Label Compatibility

Current identity direction remains:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

`LOC:` is most directly applicable to discrete Production Database location identities such as workshop/rack locations. Park geospatial destinations may use a durable site-location identity resolved through GIS rather than requiring a physical `LOC:` barcode at every destination.

The scanner/application must read the payload as data and route it through the scan platform. Physical labels must not encode annual setup state, load number, destination application, or other transient workflow information.

Label size/density should be chosen from actual DS3678-HD shop testing rather than theoretical minimum barcode sizes.

## Setup/Deployment Implication

The upcoming Setup project should assume multiple input mechanisms but one business-resolution layer:

```text
shop industrial scanner -> HID keyboard input
field phone/tablet       -> camera scan and/or GPS context
```

Both must resolve permanent Production Database identities. Do not build separate Container or Display business logic based on how the identifier was captured.

GPS is context/measurement, not asset identity.

## Known Open Work

- receive and inspect the purchased DS3678-HD kit;
- verify USB HID operation with the actual workshop forklift tablet/workstation;
- determine the controlled scanner suffix/terminator;
- test current Container labels;
- test existing rack-location labels;
- measure practical scan range from the actual workshop forklift position;
- document scanner configuration once accepted;
- determine mounting, cradle power, and cable protection;
- include industrial-scanner input in Setup/Deployment application acceptance tests;
- separately engineer park GPS/site-location behavior with Site Infrastructure/GIS rather than assuming the Zebra scanner is the park solution.

## Resume Development

For workshop hardware work, begin with the purchased Zebra DS3678-HD, existing rack labels, actual Container labels, and the real forklift operating position.

For application work, preserve HID keyboard input as a first-class shop scan path while keeping camera/GPS field input additive.

For the broader workflow, continue from [Setup and Deployment](../12_Setup_and_Deployment/README.md) after the current FieldWiring Scan Integration is closed.

## Related Documents

- [Labeling and Scanning](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Scan Workflows and Forklift Operations](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
