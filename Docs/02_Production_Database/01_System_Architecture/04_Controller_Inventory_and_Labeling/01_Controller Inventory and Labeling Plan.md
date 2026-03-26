# MSB Controller Inventory and Labeling Plan
**Project Folder:** Controller_Inventory_and_Labeling  
**Document:** Part 1 — Inventory Design and Labeling  
**Status:** Planning (Phase 1)  
**Purpose:** Define the data model direction and labeling strategy for controller assets.

---

## 1. Purpose

This document establishes the Phase 1 plan for managing controller hardware used by MSB.

Controllers represent complex technical assets that require:

- unique identification
- configuration tracking
- deployment management
- repair tracking
- physical labeling
- future scan workflows

This document addresses both:

1) Controller inventory database design direction  
2) Controller labeling standards  

---

## 2. Scope

Applies to all electronic controllers used in MSB operations, including but not limited to:

- lighting controllers
- pixel controllers
- power controllers
- network interface modules
- custom control hardware

Specific controller types will be defined in the inventory system.

---

## 3. Why Controllers Require Special Handling

Unlike containers or locations, controllers:

- have electrical and network configuration
- may be repaired or reconfigured
- may move between displays
- have firmware and version dependencies
- may require documentation and diagrams
- must be uniquely traceable over time

They function more like IT equipment than storage objects.

---

## 4. Controller Identification Standard

Each controller shall have a permanent machine identifier using the format:

`CTRL:<controller_key>`

Example:

`CTRL:CL-042`

This identifier must be:

- globally unique
- stable over the controller’s lifetime
- independent of deployment location
- printed on the physical unit

---

## 5. Controller Key Structure

The controller key should be human-manageable and stable.

Example format:

`CL-042`

Where:

- CL = controller class or general designation
- 042 = sequential unique number

Exact format may evolve, but the key must remain short and readable.

---

## 6. Inventory Database Design Direction

The controller inventory should support lifecycle management, not just a simple list.

### 6.1 Core Controller Record

Each controller should have a master record containing:

- controller_key (e.g., CL-042)
- controller_type
- manufacturer
- model
- serial_number (if available)
- acquisition_date
- status (active, spare, repair, retired)
- notes

---

### 6.2 Controller Type Classification

Controller types should be categorized to support filtering and reporting.

Examples:

- Pixel Controller
- AC Controller
- Power Distribution Unit
- Network Switch
- Custom Controller

---

### 6.3 Deployment Tracking

Controllers may be assigned to displays or installations.

The system should track:

- current assignment (if any)
- deployment location
- date assigned
- date removed

Historical assignments should be preserved.

---

### 6.4 Configuration Tracking (Future)

Controllers often have configuration settings that affect operation.

Future fields may include:

- IP address
- universe/channel mapping
- port assignments
- firmware version
- power requirements

Phase 1 does not require full configuration modeling but should allow expansion.

---

### 6.5 Repair and Maintenance History (Future)

Controllers may require repair.

Future capabilities should include:

- repair events
- maintenance actions
- parts replaced
- testing results
- responsible personnel

---

## 7. Controller Labeling Requirements

Controller labels must provide both operational identification and technical access.

Each controller label should include:

- human-readable controller key
- machine-readable barcode
- QR code for record access
- durable material suitable for installation environment

---

## 8. Barcode Standard

Controllers should use a Code 128 barcode encoding:

`CTRL:<controller_key>`

Example:

`CTRL:CL-042`

Reasons:

- compact and reliable
- fast scanning with industrial scanners
- suitable for inventory operations
- readable from moderate distance

---

## 9. QR Code Standard

Controllers benefit from direct access to detailed records.

QR codes should encode a stable scan URL:

`https://db.sheboyganlights.org/scan/CTRL/<controller_key>`

Example:

`https://db.sheboyganlights.org/scan/CTRL/CL-042`

This should resolve to a controller information page or record view.

Directus admin URLs should not be embedded directly.

---

## 10. Dual-Code Strategy

Controllers should include BOTH:

- Code 128 barcode (operational scanning)
- QR code (technical access)

This provides flexibility for different use cases.

---

## 11. Label Placement Guidelines

Labels should be placed where they remain visible after installation.

Avoid:

- undersides of units
- removable covers
- high-heat areas
- surfaces likely to be obstructed by cables

If feasible, consider:

- one external label
- optional internal backup label

---

## 12. Label Durability

Controller labels should withstand:

- outdoor exposure
- heat from electronics
- moisture
- abrasion
- handling during installation and removal

Laminated industrial labels are recommended.

---

## 13. Scan Workflow Use Cases

Controller labels should support future workflows such as:

- repair intake
- installation verification
- configuration lookup
- deployment tracking
- swap operations
- testing documentation

---

## 14. Relationship to Other Systems

Controller management will integrate with:

- display inventory
- storage management
- work order system
- testing workflows
- future scanning interfaces

The controller system should not be tightly coupled to any single deployment scenario.

---

## 15. Future Expansion Considerations

The system should be designed so it can later support:

- detailed configuration modeling
- network topology mapping
- firmware management
- automated testing records
- cable mapping
- spare parts tracking

---

## 16. Summary

Controllers are complex technical assets that require both structured inventory management and robust labeling.

Key Phase 1 principles:

- each controller has a permanent unique identifier
- labels include both Code 128 and QR codes
- inventory design supports lifecycle tracking
- configuration and repair tracking are planned for future phases
- labeling enables both operational and technical workflows

This document establishes the foundation for a dedicated controller management subsystem.

---