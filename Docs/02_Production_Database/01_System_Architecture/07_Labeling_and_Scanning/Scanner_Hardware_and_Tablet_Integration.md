# MSB Scanner Hardware and Tablet Integration

| Document control | Value |
|---|---|
| Status | CURRENT HARDWARE BASELINE / FIELD ACCEPTANCE PENDING |
| Current revision | 2026-08-22 |
| Primary upcoming use | Setup/Deployment Container and Storage Location scanning |

## Purpose

This document defines the hardware and browser-input strategy for MSB scanning workflows, including rugged tablets, industrial handheld scanners, forklift use, and later Setup/Deployment scanning.

The scanner is an input device. It does not own Production Database identity or workflow state. Permanent payload and scan-routing rules remain owned by the Labeling and Scanning subsystem.

## Current Hardware Baseline

MSB has procured rugged tablets intended to serve as mobile browser workstations.

MSB has also purchased one industrial cordless scanner kit for the workshop forklift:

```text
Zebra DS3678-HD
Kit: DS3678-HD3U4210SFW
Series: Zebra 3600 Ultra-Rugged
Decode type: 1-D / 2-D imager
Variant: High Density (HD)
Connection kit: USB cradle/cable/power kit
Feedback: vibration motor included
Intended location: workshop forklift
```

This purchased device is now the first real industrial-scanner acceptance platform. Future hardware recommendations should use its field results rather than remaining purely conceptual.

## Scanner Capability

The DS3678-HD supports the symbologies required by the current MSB identity direction, including Code 128 and QR/Data Matrix-class 2-D codes.

Zebra documents USB HID Keyboard as the default USB host mode for the DS3678 family. This aligns with the MSB browser architecture: a successful scan can arrive at the focused browser control as keyboard input without a custom database/scanner driver.

Other Zebra interface modes exist, but do not introduce a more complex scanner protocol unless the actual Setup workflow proves HID insufficient.

## Important Range Classification

The purchased scanner is the **HD — High Density** model. It is not the DS3678-ER extended-range model.

That distinction matters for forklift design.

Representative Zebra typical working ranges for DS36X8-HD include approximately:

```text
Code 128, 5 mil   -> 0.9 to 7.0 in.
Code 128, 15 mil  -> 0.9 to 23 in.
Code 39, 20 mil   -> 0.25 to 34 in.
Data Matrix, 10 mil -> 1.0 to 9.0 in.
```

Actual range depends on barcode size/density, print quality, contrast, angle, ambient light, and label material.

Therefore the previous general assumption that the forklift scanner must provide long-distance rack scanning is **not yet proven by the purchased hardware**. Do not document the DS3678-HD as an extended-range scanner.

## Forklift Acceptance Requirement

Before treating the purchased DS3678-HD as the final forklift standard, test it from the actual operating position with the actual MSB labels.

Acceptance should include:

- current Container barcode/QR labels;
- planned Storage Location labels;
- laminated labels if used in production;
- actual mounting/holding position from the forklift seat;
- realistic rack/container distances and angles;
- bright shop lighting and darker aisles;
- operator gloves;
- vibration/noise conditions;
- repeated rapid scans rather than one successful demonstration.

If normal forklift operation requires multi-foot or across-aisle scanning that the HD model cannot reliably perform, evaluate an ER/XR-class scanner rather than compensating with unsafe operator reach or oversized application assumptions.

## Browser Input Contract

MSB scan applications must support industrial scanners independently of camera scanning.

The preferred baseline is USB/HID keyboard input:

```text
scanner
    -> cordless link to cradle
        -> USB HID keyboard input to workstation/tablet host
            -> focused browser scan field
                -> scan parser/router
```

The browser workflow must not require camera APIs for normal industrial-scanner operation.

Camera scanning remains useful on phones/tablets for occasional QR lookup, but high-volume Setup/Deployment scanning must work with a dedicated scanner and keyboard-style input.

## Terminator / Auto-Submit Requirement

During hardware acceptance, determine and deliberately standardize the scanner suffix used by MSB—normally an Enter/Carriage Return style terminator if that fits the application.

Do not assume the scanner's current suffix configuration.

The eventual Setup scan screen should allow repetitive operation without requiring the forklift operator to touch the screen after every scan. The exact behavior must be tested with the DS3678-HD and then documented as the controlled scanner configuration.

## Tablet / Host Integration

The USB cradle must connect to a host that supports the selected USB mode.

Before forklift deployment, verify the actual rugged tablet or mounted workstation provides the required USB host connection, power arrangement, and secure cabling for the cradle.

The scanner should not connect directly to PostgreSQL. The browser application interprets the decoded asset payload and communicates with the approved backend over the network.

## Physical Installation

Forklift installation should provide:

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
- other Setup/Deployment scan points.

Scanner-to-cradle communication does not replace application network connectivity.

## Label Compatibility

Current identity direction remains:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

The scanner/application must read the payload as data and route it through the scan platform. Physical labels must not encode annual setup state, load number, destination application, or other transient workflow information.

Label size/density should be chosen from actual DS3678-HD field testing rather than theoretical minimum barcode sizes. A barcode that decodes on a desk may still be unsuitable from the forklift.

## Setup/Deployment Implication

The upcoming Setup project is expected to use industrial scanning heavily. Its application design should therefore assume two independent input mechanisms:

```text
industrial scanner -> keyboard/HID input
phone/tablet camera -> camera decoder
```

Both must produce the same canonical payload for the same asset/location and feed the same application-level resolver.

Do not build separate business logic for camera scans versus hardware-scanner scans.

## Known Open Work

- receive and inspect the purchased DS3678-HD kit;
- verify USB HID operation with the actual forklift tablet/workstation;
- determine the controlled scanner suffix/terminator;
- test current Container labels;
- produce/test representative Storage Location labels;
- measure practical scan range from the actual forklift position;
- decide whether the HD model is adequate or whether an ER/XR model is needed for some forklift tasks;
- document scanner configuration once accepted;
- determine mounting, cradle power, and cable protection;
- include industrial-scanner input in Setup/Deployment application acceptance tests.

## Resume Development

For hardware work, begin with the purchased Zebra DS3678-HD, actual MSB labels, and the real forklift operating position. Record measured results rather than assuming capability from the 3600-series family name.

For application work, preserve HID keyboard input as a first-class scan path while keeping camera scanning additive.

For the broader workflow, continue from [Setup and Deployment](../12_Setup_and_Deployment/README.md) after the current FieldWiring Scan Integration is closed.

## Related Documents

- [Labeling and Scanning](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Scan Workflows and Forklift Operations](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
