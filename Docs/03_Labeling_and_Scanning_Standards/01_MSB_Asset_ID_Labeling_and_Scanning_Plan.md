# MSB Asset ID, Labeling, and Scanning Plan
**Project Folder:** Labeling_and_Scanning_Standards  
**Document Version:** Phase 1 Draft  
**Status:** Planning  
**Purpose:** Define the initial asset identification, barcode, label printing, and scan workflow standards for MSB operations.

---

## 1. Purpose

This document defines the Phase 1 plan for:

- asset identification standards
- barcode and QR code standards
- label printing standards
- print tracking requirements
- scanner hardware direction
- forklift and tablet scan workflows
- future support for controller management

This plan is intended to prevent confusion, duplicate label printing, and incompatible scanning workflows before implementation begins.

---

## 2. Scope for Phase 1

The initial label-printing and scanning system will support these asset types:

- Displays
- Containers
- Storage Locations

A future expansion is expected for:

- Controllers

---

## 3. Core Design Goals

The system must:

- uniquely identify all labeled assets
- support both 1-D and 2-D scanning
- work with rugged tablets already purchased
- support cordless industrial scanners for forklift use
- allow users to print labels by selection or in batches
- track label printing so duplicates are not accidentally printed
- support future scan workflows without redoing labels
- remain user friendly for volunteers and production staff

---

## 4. Asset Identification Standard

Every scannable asset shall have a machine-readable identifier using this format:

`TYPE:KEY`

Where:

- `TYPE` = standardized asset prefix
- `KEY` = stable unique identifier for that asset

This format is required so scanners and software can immediately determine what kind of asset was scanned.

---

## 5. Standard Prefixes

The following prefixes are approved for Phase 1 and immediate planning:

| Asset Type | Prefix | Example |
|------------|--------|---------|
| Container | CONT | CONT:587 |
| Storage Location | LOC | LOC:RA-01-A-03 |
| Display | DISP | DISP:251 |
| Controller | CTRL | CTRL:CL-042 |

### Notes
- Do **not** use single-letter prefixes.
- Single-letter codes do not scale well and will create collisions.
- All future barcode and QR code logic should use these standardized prefixes.

---

## 6. Key Rules by Asset Type

### 6.1 Containers
Use the stable internal container ID.

Example:

`CONT:587`

### 6.2 Displays
Use the stable internal display ID.

Example:

`DISP:251`

### 6.3 Storage Locations
Use the operational location code, since this is the real working identifier used by people.

Example:

`LOC:RA-01-A-03`

### 6.4 Controllers
Use a structured controller key.

Example:

`CTRL:CL-042`

---

## 7. Barcode and QR Code Standards

### 7.1 General Standard
The system will support:

- 1-D barcodes
- 2-D QR codes

This is required because forklift and warehouse workflows need fast scan performance, while technical and mobile workflows benefit from QR navigation.

---

## 8. Barcode Type by Asset

### 8.1 Containers
**Primary:** Code 128

Reason:
- better for forklift and warehouse scanning
- better distance performance
- compact and reliable

### 8.2 Storage Locations
**Primary:** Code 128

Reason:
- locations are operational scan targets
- likely to be scanned from a distance
- better for repeated warehouse scanning

### 8.3 Displays
**Primary:** QR Code

Reason:
- useful for opening the display record directly
- better suited to tablet or phone workflows
- display records are more informational than pure logistics objects

### 8.4 Controllers
**Primary:** Code 128  
**Secondary:** QR Code

Reason:
- controller management benefits from both quick ID scanning and deep technical record access

---

## 9. QR Code Standard

QR codes should not store raw copied Directus admin URLs from the browser.

Do **not** use URLs like:

`https://db.sheboyganlights.org/admin/content/display/251?bookmark=59`

These are brittle and tied to Directus UI internals.

### Approved future pattern

Use a stable redirect-style scan URL:

`https://db.sheboyganlights.org/scan/<TYPE>/<KEY>`

Examples:

- `https://db.sheboyganlights.org/scan/DISP/251`
- `https://db.sheboyganlights.org/scan/CTRL/CL-042`

### Benefits
- labels remain valid even if Directus paths change
- future scan behavior can change without reprinting labels
- easier to support mobile and tablet workflows later

---

## 10. Label Printing Standards

### 10.1 General Standard
Labels will not be produced by CSV export workflow.

The desired workflow is:

- user selects records
- user prints labels directly
- print jobs are tracked
- duplicates are prevented unless intentionally reprinted

### 10.2 Container Labels
Containers require **2 labels per container** by default.

Reason:
- containers may be stored facing forward or backward
- labels should be visible regardless of orientation

This is a system rule and should not rely on the user remembering to print two.

### 10.3 Display Labels
Displays require **1 label** by default.

### 10.4 Storage Location Labels
Storage locations require **1 label** by default.

### 10.5 Controller Labels
Controllers are expected to require **1 label** by default, with final layout and placement to be determined later.

---

## 11. Label Printing Workflow Design

The system should support:

- print selected labels
- print batch labels
- prevent duplicate printing
- allow reprints with a reason
- recover from failed print attempts
- support partial print failures

This means the label system must track both:

- print job history
- current label status on the asset

---

## 12. Recommended Data Design Direction

The following design direction is recommended for implementation.

### 12.1 Print Job Tracking
Create a print-job structure using:

- one job header record for each print batch
- one job item record for each selected asset in that batch

Conceptually this means:

- `label_print_job`
- `label_print_job_item`

### 12.2 Current Label Status on Assets
Track whether each asset currently:

- needs a label
- is queued for print
- has been printed
- failed printing
- needs reprint

This should exist on the actual assets that receive labels.

Suggested lifecycle values:

- NEEDS_LABEL
- PRINT_QUEUED
- PRINTED
- PRINT_FAILED
- NEEDS_REPRINT

### 12.3 Reprint Reason Tracking
If a label is reprinted, the system should capture why.

Examples:
- damaged
- lost
- printer error
- label stock ran out
- wrong label applied
- data changed
- test print

---

## 13. Directus Flow Role

Directus Flow is expected to be used as the workflow orchestrator, not the entire printing system.

### Directus Flow should handle:
- selection intake
- duplicate prevention checks
- print job creation
- print job item creation
- passing print requests to a print service
- updating print statuses after result

### External print service should handle:
- label layout rendering
- barcode/QR generation
- communication with Brother printer
- printer-specific result handling

This split keeps the system maintainable.

---

## 14. Scanner Hardware Direction

### 14.1 Existing Rugged Tablets
The rugged tablets already purchased should serve as:

- scan interface screen
- mobile workstation
- forklift display device
- browser-based app platform

These tablets are suitable for close-range scanning by camera if needed, but camera scanning is not enough for forklift distance work.

### 14.2 Forklift Scanning Requirement
Forklift workflows require a **cordless industrial scanner** with both 1-D and 2-D support.

This is necessary because forklift operators need to scan at distance and cannot rely on the tablet camera.

### 14.3 Scanner Capability Requirement
Approved hardware direction should support:

- cordless operation
- rugged industrial use
- 1-D barcode scanning
- 2-D QR scanning
- integration with tablet workflow
- keyboard wedge or equivalent simple input mode if possible

---

## 15. Scan Workflow Requirements

The future scanning system should support these workflows:

### 15.1 Scan Container → Show Home Location
Example:
- scan `CONT:587`
- system shows its home location

### 15.2 Scan Location → Show Assigned Container
Example:
- scan `LOC:RA-01-A-03`
- system shows what belongs there

### 15.3 Scan Location + Container → Validate Match
Example:
- scan location
- scan container
- system compares
- display clear result

Expected result:
- OK if they match
- warning or error if they do not

### 15.4 Reverse Scan Order
The system should work in either order:

- location then container
- container then location

This means the scan interface must maintain temporary state between scans.

---

## 16. Forklift Workflow Direction

The target forklift workflow is:

- rugged tablet mounted on forklift
- cordless industrial scanner used by operator
- scan-aware web application running on tablet
- database lookup over Wi-Fi
- large high-contrast feedback for operators

This will support:

- retrieval
- put-away
- validation
- future movement logging

---

## 17. Controller Label Planning

Controllers are not part of the first build, but this asset type is important and must be planned now so the identification standard does not conflict later.

Controller labels should support:

- unique controller identification
- technical record lookup
- future QR navigation
- future Code 128 logistics/inventory scanning

Approved identifier format for planning:

`CTRL:<controller_key>`

Example:

`CTRL:CL-042`

---

## 18. Future Reserved Prefixes

These are not implemented yet, but should be reserved to avoid collisions:

| Future Asset | Prefix |
|--------------|--------|
| Pallet | PAL |
| Rack | RACK |
| Endpoint | END |
| Work Order | WO |
| Test Session | TS |

---

## 19. Phase 1 Implementation Priorities

Recommended order of work:

1. finalize asset ID and prefix standard
2. finalize label content for Displays, Containers, and Storage Locations
3. define print job and label status tracking structure
4. define Directus Flow orchestration approach
5. define print service approach for Brother printer
6. test actual label sizes and scan performance
7. purchase scanner hardware aligned with 1-D and 2-D requirements
8. build tablet-based scan interface
9. expand later to Controllers

---

## 20. Immediate Decisions Now Locked In

The following planning decisions are approved for this document:

- use `TYPE:KEY` machine-readable format
- use `CONT`, `LOC`, `DISP`, and `CTRL` prefixes
- support both 1-D and 2-D scanning
- use Code 128 for Containers and Storage Locations
- use QR for Displays
- plan for both Code 128 and QR for Controllers
- print 2 labels per Container by default
- track print history and current label status
- use Directus Flow as orchestrator, not as the printer engine
- use rugged tablets as the scan screen platform
- use cordless industrial scanners for forklift workflows

---

## 21. Summary

This plan establishes the foundation for a controlled, scalable MSB labeling and scanning system.

It prevents common problems such as:

- duplicate labels
- confusing barcode meanings
- scanner incompatibility
- brittle Directus-only URLs
- poor forklift usability
- future prefix collisions

This document should be treated as the baseline planning standard before implementation begins.

---