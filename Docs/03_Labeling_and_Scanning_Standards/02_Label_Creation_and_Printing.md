# MSB Label Creation and Printing Plan
**Project Folder:** Labeling_and_Scanning_Standards  
**Document:** Part 1 — Label Creation and Printing  
**Status:** Planning (Phase 1)  
**Purpose:** Define how labels are created, printed, tracked, and controlled to prevent duplicates and errors.

---

## 1. Purpose

This document defines the Phase 1 approach for creating and printing asset labels for MSB operations.

It establishes:

- which assets receive labels
- how labels are generated
- how many labels are printed
- how print jobs are tracked
- how duplicate printing is prevented
- how printing failures are handled
- how the Brother industrial printer will be used

This section intentionally focuses ONLY on label creation and printing.

Scanning workflows and hardware are covered in later documents.

---

## 2. Assets Included in Phase 1

Label printing will initially support:

- Displays
- Containers
- Storage Locations

A future expansion will include:

- Controllers

---

## 3. Label Printing Goals

The label system must:

- allow users to select specific items to print
- support batch printing
- produce durable industrial labels
- prevent accidental duplicate labels
- support intentional reprints when necessary
- handle printer errors or stock shortages
- remain simple for volunteers to use

CSV export workflows are explicitly not part of the design.

---

## 4. Printer Hardware

The system will use:

**Brother P-Touch PT-P950NW Industrial Network Label Printer**

Key capabilities:

- up to 36 mm laminated labels
- USB, Ethernet, Wi-Fi connectivity
- durable outdoor-rated labels
- barcode and QR printing
- batch printing capability

All label layouts must be compatible with this printer.

---

## 5. Label Identification Standard

Every label shall represent a machine-readable asset identifier in the format:

`TYPE:KEY`

Examples:

- CONT:587
- LOC:RA-01-A-03
- DISP:251
- CTRL:CL-042

The identifier must appear:

- in machine-readable barcode form
- in human-readable text form (where space allows)

---

## 6. Label Quantity Rules

### 6.1 Containers

Containers require **two labels per container**.

Reason:
Containers may be stored facing either direction, so labels must be visible regardless of orientation.

This rule is enforced by the system and should not rely on the user remembering to print duplicates.

---

### 6.2 Displays

Displays require **one label per display**.

---

### 6.3 Storage Locations

Storage locations require **one label per location**.

---

### 6.4 Controllers (Future)

Controllers are expected to require **one label per unit**, subject to future design decisions.

---

## 7. Label Content Requirements

Each label must include:

- a human-readable identifier
- a machine-readable barcode or QR code
- sufficient contrast for industrial scanning
- durability appropriate for the environment

Additional descriptive text may be included where space permits.

---

## 8. Label Creation Workflow

Labels will not be typed manually into the printer.

Instead, labels will be generated from system data.

### Intended workflow:

1. User selects records within the system
2. User chooses a label type
3. System generates a print job
4. Printer produces labels automatically

This ensures consistency and prevents transcription errors.

---

## 9. Batch Printing

The system must support printing labels for:

- a single item
- multiple selected items
- an entire filtered list
- operational batches (e.g., containers for a pallet)

Batch printing should produce one print job containing multiple job items.

---

## 10. Print Job Tracking

All printing actions must be tracked.

This prevents accidental duplication and allows recovery from failures.

### Print job tracking must record:

- who requested the print
- when it was requested
- what label type was printed
- which items were included
- the number of labels requested
- the printer used
- job status
- any error messages

---

## 11. Per-Item Print Tracking

Each item within a print job must also track its own outcome.

This allows detection of partial failures.

Example situations:

- printer ran out of tape mid-job
- labels jammed
- printer offline
- power loss

---

## 12. Current Label Status

Each labeled asset should track whether it currently has a valid label.

Suggested lifecycle states:

- NEEDS_LABEL
- PRINT_QUEUED
- PRINTED
- PRINT_FAILED
- NEEDS_REPRINT

This allows the system to present user-friendly views such as:

- Items needing labels
- Successfully labeled items
- Items requiring reprint

---

## 13. Duplicate Prevention

The system must prevent accidental reprinting of labels that are already valid.

If a user attempts to print a label for an item already marked as PRINTED, the system should:

- warn the user, or
- require explicit confirmation

---

## 14. Reprint Handling

Reprints must be supported because labels can be:

- damaged
- lost
- applied incorrectly
- printed with incorrect data
- affected by printer issues

When a reprint occurs, the system should capture a reason.

Example reasons:

- Damaged label
- Lost label
- Printer error
- Tape ran out
- Data updated
- Test print

---

## 15. Handling Print Failures

If a print job fails or is only partially completed, affected items must not be marked as successfully printed.

Failed items should transition to:

PRINT_FAILED or NEEDS_REPRINT

This allows operators to retry safely without duplicating successful labels.

---

## 16. Label Layout Management

Label layouts should be defined centrally and not recreated manually for each print.

Layouts must account for:

- tape width limitations
- barcode size requirements
- readability at distance (for logistics labels)
- durability considerations

Future enhancements may include multiple layouts per asset type.

---

## 17. Network Printing Considerations

Because the printer supports network connectivity, the system should be designed so that printing can occur from designated workstations without direct USB connection.

Centralized printing reduces configuration complexity and supports shared use.

---

## 18. User Experience Requirements

The printing process must be simple and reliable:

- minimal manual steps
- clear success/failure feedback
- no need for users to adjust printer settings
- no need for users to calculate label quantities
- predictable results

This is critical for volunteer-driven operations.

---

## 19. Future Expansion Considerations

The printing system should be designed so that it can later support:

- additional asset types (e.g., Controllers)
- alternative label sizes
- new templates
- multiple printers
- automated label generation during workflows

---

## 20. Summary

This document establishes the foundation for controlled label creation and printing.

Key principles:

- labels are generated from system data
- printing is tracked and auditable
- duplicates are prevented by design
- container labels are printed in pairs
- failures are handled safely
- the system remains easy for users to operate

Subsequent documents will define:

- barcode standards
- scanning workflows
- hardware requirements
- mobile operation design

---