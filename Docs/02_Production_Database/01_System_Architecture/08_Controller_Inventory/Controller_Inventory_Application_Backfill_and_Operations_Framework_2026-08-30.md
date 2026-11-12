# Controller Inventory Application, Backfill, and Operations Framework — 2026-08-30

| Document control | Value |
|---|---|
| Status | CURRENT PRE-DDL APPLICATION / WORKFLOW FRAMEWORK |
| Subsystem | Controller Inventory |
| Current phase | Physical-controller backfill planning and application workflow design |
| PostgreSQL DDL | NOT AUTHORIZED by this document |
| Parent authority | [Controller Inventory Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md) |

## Purpose

This document records the accepted real-world Controller Inventory operating model so the subsystem is designed around the actual backfill, assignment, setup, takedown, inventory-stock, labeling, model, firmware, and reconciliation workflows rather than around direct table editing.

The Controller Inventory subsystem is not merely a `ref.controller` table and it is not merely a FieldWiring lookup. It is the permanent physical asset-management workflow for managed show-control hardware.

The difficult initial problem is the existing physical-controller backfill. Once that backfill exists, adding a new controller and assigning it to a new or existing Display should be much simpler. The initial application design must therefore make the backfill workflow become the normal future assignment workflow rather than creating a disposable spreadsheet-import process.

## Current Point A

The current system has:

```text
LOR / approved V7 snapshot
    -> authoritative current wiring, addressing, output, universe,
       Preview/Scene/Display and SPARE facts

ref.display
    -> permanent Display identity

ref.stage
    -> permanent Stage identity

ref.location
    -> existing governed physical-location framework / LOC codes

working Controller spreadsheet
    -> temporary physical-grouping reconstruction evidence
```

The current system does **not** yet have:

```text
permanent controller_id inventory
controller-to-Display assignments
controller labels
available-controller stock workflow
controller reconciliation against new LOR ingests
controller model administration workflow
firmware maintenance workflow
controller setup/takedown workflow
```

## Target Point B

The target operating model is:

```text
permanent physical controller inventory
        +
canonical controller models / firmware compatibility
        +
current ref.location location
        +
current controller-to-Display / deployment relationships
        +
current approved LOR/V7 wiring
        +
controller reconciliation/currentness state
        ->
Controller Inventory application
        ->
FieldWiring / setup / takedown / stock / label / maintenance consumers
```

The permanent physical identity remains only:

```text
ref.controller.controller_id
```

with scan payload:

```text
CTRL:<controller_id>
```

Do not reintroduce `controller_key`, `CL-###`, Network/UID, IP, universe, Stage, Display, workbook row, or any other parallel permanent controller identity.

## Application Requirement — Directus Table Editing Is Not the Operational Workflow

Directus may remain useful for administration, inspection, or emergency data work, but editing the underlying tables directly is not an acceptable normal Controller Inventory workflow.

The normal Controller Inventory workflow requires one application experience that can simultaneously present:

- Stage / Display / current LOR wiring context;
- assigned physical controllers;
- missing or partially assigned physical controller contexts;
- available/unassigned physical controller stock;
- add-controller and add-model actions;
- current `ref.location` location;
- setup / pickup / physical-placement notes;
- controller assignment/unassignment/replacement actions;
- label printing;
- reconciliation/currentness state relative to the approved LOR/V7 snapshot; and
- model/firmware status where relevant.

These are coordinated operations across several governed relationships and cannot be reduced safely to one Directus collection grid.

## Main Stage / Display Assignment Workbench

The central Controller application screen should be Stage/Display-centered while showing physical controller contexts rather than merely asking whether a Display has any controller row.

Conceptually:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ CONTROLLER INVENTORY — STAGE / DISPLAY                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│ Stage: [17-Candyland-CL]      Search Display: [____________________]         │
│ Show: Assigned | Missing | Partial | Review Required                         │
├────────────────────────────────────────────┬─────────────────────────────────┤
│ CURRENT PHYSICAL CONTROLLER CONTEXTS       │ AVAILABLE CONTROLLERS           │
│                                            │                                 │
│ Candy Canes 1-4          ASSIGNED          │ CTRL:142  Pixie4  AVAILABLE     │
│ Aux A / UID 21-24                          │ LOC: <ref.location>              │
│ Displays 01-04                             │ Firmware: ...                   │
│ CTRL:101 Pixie4                            │ [Assign] [View] [Print]         │
│                                            │                                 │
│ Candy Canes 5-8          MISSING           │ CTRL:167  Pixie4  AVAILABLE     │
│ Aux A / UID 21-24                          │ LOC: <ref.location>              │
│ Displays 05-08                             │ [Assign] [View] [Print]         │
│ [Assign Existing] [Add Controller]         │                                 │
│                                            │ [+ Add Controller]              │
│ Candy Canes 9-12         ASSIGNED          │ [+ Add Controller Model]        │
│ Aux A / UID 21-24                          │                                 │
│ CTRL:109 Pixie4                            │                                 │
└────────────────────────────────────────────┴─────────────────────────────────┘
```

This workbench is both:

1. the initial physical-controller backfill tool; and
2. the permanent future assignment workflow after new Displays/controllers are added.

## Controller Coverage State

The application must not reduce controller coverage to `Display has controller = yes/no`.

A Display or physical controller context may require zero, one, or multiple physical controllers. The application therefore needs conceptual states such as:

```text
ASSIGNED
MISSING
PARTIAL
REVIEW_REQUIRED
NOT_APPLICABLE
```

Example: a Display such as `FT-MegaStar` may legitimately need two permanent physical controller assignments. One assigned controller must therefore result in `PARTIAL`, not `ASSIGNED`.

## Current 2026 Workbook Bootstrap Boundary

The current working `Controller Inventory & Testing 2026(7).xlsx` list contains **deployed/assigned controllers only**. It is not a mixed deployed-plus-spares inventory and it contains no known spare/available controller rows.

Therefore the initial Controller Inventory bootstrap must not classify any workbook row as `AVAILABLE` or spare merely because its permanent `display_id` relationship has not yet been resolved in the application. An unresolved workbook assignment remains a deployed-controller backfill/review problem, not evidence that the physical controller is stock.

Available/unassigned inventory begins empty for this bootstrap and is populated later only when an actual unassigned/spare physical controller is discovered or deliberately added through the Controller Inventory workflow.

The workbook's deployed/assigned meaning is separate from the controller's current physical location. A controller can remain assigned to its Display(s) while its current `ref.location` is workshop/storage between setup seasons.

## Available / Spare Controller Stock

A permanent physical controller can exist without any Stage or Display assignment.

Example:

```text
CTRL:142
Model: Pixie4
Status: AVAILABLE
LOC: <ref.location LOC code>
Display assignment: none
Stage assignment: none
```

This allows spare physical hardware to receive permanent IDs and labels immediately and supports an authoritative stock report.

The application must support at least:

```text
Available Controllers
    filter by model/family
    current installed firmware if known
    current ref.location
    verification state
    assignment compatibility/context where useful
    Assign
    View
    Print/Reprint Label
```

The existence of spare/unassigned controllers is a first-class inventory requirement, not an exceptional case.

## `ref.location` — Physical Location Authority

The Controller subsystem must use the existing:

```text
ref.location
```

LOC framework for the controller's current physical location.

Do not create a controller-specific competing storage-location table or free-text location authority.

The following are deliberately different facts:

```text
controller_id
    permanent physical identity

ref.location
    where the physical controller can currently be found

Stage
    current show/deployment organizational context

Display relationship
    which physical Display(s) the controller currently serves

LOR Network/UID/IP/universe
    current show wiring/address configuration
```

All may change independently while `controller_id` remains permanent.

The existing LOC framework needs further operational refinement, but Controller Inventory should consume that common framework rather than block its initial implementation on a full LOC redesign.

## Setup / Physical Placement Notes

MSB already uses notes describing where a controller is physically placed once deployed in the park. These notes are operationally important for both setup and takedown.

A setup/deployment relationship therefore needs a human-readable placement note in addition to the governed `ref.location` LOC code.

Examples:

```text
North side behind Candy Cane group
Inside gray enclosure behind tree
Mounted on south side of arch
Screwed to panelboard
```

The note does not replace `ref.location`; it supplements it with field placement detail.

## Add Controller Workflow

A user must be able to add a controller directly from the assignment/backfill application without leaving the workflow for Directus.

Conceptual flow:

```text
Add Controller
    -> select manufacturer/model
    -> if model missing, Add Controller Model
    -> PostgreSQL generates controller_id
    -> optional serial number
    -> optional installed firmware when known
    -> status (normally AVAILABLE for stock)
    -> current ref.location
    -> verification state
    -> save
    -> print CTRL:<controller_id> label
    -> optionally assign immediately
```

Unknown model, serial number, firmware, or other powered-only facts must not prevent creation of a permanent controller asset when the physical device itself is known to exist.

Those facts remain null / verification-required until confirmed.

## Controller Labels

Physical labels are permanent asset labels and must not encode mutable deployment as identity.

Accepted identity payload:

```text
CTRL:<controller_id>
```

A label may also display useful human-readable model information, but Network, UID, Stage, Display, IP, universe, or LOC must not become permanent identity encoded into the controller ID.

The Controller application must support initial label printing and reprinting.

## Controller-to-Display Assignment

The accepted relationship is many-to-many:

```text
one controller -> zero, one, or many Displays
one Display    -> zero, one, or many controllers
```

The application must support:

- assigning one controller to multiple Displays;
- assigning multiple controllers to one Display;
- replacing a controller while preserving the permanent Display identity;
- removing a controller from deployment without deleting its permanent inventory record; and
- retaining physical/controller contexts when current LOR addressing is intentionally duplicated.

Example opposite-direction cases already represented in current engineering evidence include:

```text
Candy Cane Pixie groups
    one physical controller -> multiple Displays

FT-MegaStar
    one Display -> multiple physical controllers
```

## Stage Assignment / Deployment Context

Stage is useful current deployment/context information but is not permanent controller identity.

A controller may be:

```text
AVAILABLE
    Stage = none
    Display = none
    LOC = warehouse/storage location

DEPLOYED
    Stage = current Stage
    Display(s) = current physical relationships
    LOC = park/deployment location

REPAIR
    Stage = none or dispositioned
    Display = none or review-required
    LOC = repair/workshop location
```

The exact future table representation remains a DDL decision. This document establishes the operational fact separation.

## Setup Workflow

Before setup, an available controller may look like:

```text
CTRL:237
Pixie4
Status: AVAILABLE
LOC: warehouse electronics shelf
```

When deployed:

```text
CTRL:237
Status: DEPLOYED
Stage: Candyland
Displays: Candy Canes 5-8
LOC: Candyland deployment LOC
Placement note: North side behind Candy Cane rack
```

The Controller application should be able to produce setup/pick lists showing:

```text
controller ID
model
pickup/current LOC
target Stage / Display group
target deployment LOC
placement/setup note
```

## Takedown / Retrieval Workflow

The same current deployment data must support takedown.

A Stage retrieval view/report should show all physical controllers expected to be recovered, including:

```text
controller ID
model
park/deployment LOC
placement note
current Stage/Display group
return/storage LOC when selected
```

After retrieval, the application should support a controlled `Return to Inventory` operation that conceptually:

```text
removes the current deployment/Display assignment when appropriate
sets status to AVAILABLE
moves current location to the selected ref.location stock LOC
preserves controller_id
preserves firmware history
preserves Work Order references
```

Retirement is not deletion.

## Ingest / Reconciliation Survival

Controller Inventory must survive normal LOR/V7 parser ingest and Display/Stage reconciliation.

Permanent controller-to-Display relationships must use permanent Production Database identities such as `display_id`, not LOR Prop UUID, name, UID, or spreadsheet row.

Normal flow:

```text
LOR Preview changes
    -> parser
    -> LOR2DB ingest
    -> Stage/Display reconciliation
    -> permanent display_id remains / new display_id is created through normal governance
    -> Controller reconciliation checks current controller assignments against the new approved snapshot
```

A new LOR ingest must **not** delete and rebuild permanent controller assets or blindly destroy current controller-to-Display relationships.

Controller reconciliation outcomes conceptually include:

```text
CURRENT
    controller relationship remains consistent with the current approved snapshot

WIRING_CHANGED
    permanent controller relationship may remain, but current mapping requires review

NEW_CONTROLLER_CONTEXT / NEEDS_ASSIGNMENT
    current LOR/Display evidence requires a physical controller assignment not yet present

PARTIAL
    some but not all required physical controller contexts are assigned

ASSIGNED_DISPLAY_RECYCLED / NEEDS_DISPOSITION
    prior Display relationship no longer represents an active current deployment

AMBIGUOUS / REVIEW_REQUIRED
    evidence is insufficient to safely determine physical controller mapping
```

No ingest may silently invent permanent `controller_id` values, automatically return physical controllers to stock, or silently guess ambiguous physical assignments.

## Snapshot Provenance / Currentness

The controller assignment/resolution system must retain enough provenance to determine whether the physical mapping was reviewed against the current approved LOR/V7 snapshot.

Conceptually:

```text
current approved LOR/V7 run = X
controller mapping reconciled against = X
    -> CURRENT

current approved LOR/V7 run = Y
controller mapping reconciled against = X
    -> review/reconciliation evaluation required
```

This is currentness/provenance, not a requirement to preserve historical deployment assignment rows.

## Backfill Workflow

The first-season backfill should use the same permanent workflow that future additions will use.

For each proposed real physical controller:

```text
review current physical-grouping evidence
    -> determine one physical device exists
    -> create controller_id
    -> assign known model if supportable, otherwise leave verification-required
    -> assign known firmware if actually known, otherwise null
    -> assign current ref.location
    -> assign Display(s)/Stage when supportable
    -> preserve ambiguity where not supportable
    -> print permanent controller label
    -> physically verify later as needed
```

The backfill does **not** require every controller fact to be perfect before the asset can exist.

The application must therefore tolerate and visibly surface:

```text
unknown exact model
unknown firmware
unknown serial number
missing Display assignment
partial multi-controller Display assignment
review-required wiring-source relationship
unverified physical grouping
```

This allows useful inventory/labeling work to proceed while the harder physical verification continues.

## Known Real-World Backfill Cases the Application Must Represent

### Repeated-address Pixie groups

Candyland and Church contain multiple physical Pixie controllers using the same programmed UID block.

The application must show separate physical controller contexts and must not collapse them into one controller because Network/UID is identical.

### Multi-controller Display

`FT-MegaStar` is a current example where one Display spans multiple physical controller contexts. The application must show `PARTIAL` if only one required physical controller is assigned.

### Conventional controller serving multiple Displays

HWY42/current conventional controller contexts include cases where one physical controller serves multiple current Display relationships. The application must support one controller row assigned to several Displays.

### Glistening Grove non-wired physical copies

Some physical controller-bearing Glistening Grove copies appear as `DeviceType=None` and do not carry their own direct LOR address rows.

The application must be able to show:

```text
physical controller assigned
Display assigned
direct LOR wiring = none
wiring-source resolution = review-required / reviewed
```

Do not infer a wiring source solely from a name suffix such as `-02 -> -01`.

### Unknown exact model

A known physical controller may be inventoried, assigned, located, and labeled while its exact canonical model remains verification-required.

## Controller Model Administration

The Controller application requires an administrative model workflow.

A missing model must be addable without leaving the controller-add/backfill process.

The canonical model record conceptually needs enough controlled information for:

```text
manufacturer
canonical exact model
hardware revision/generation when required
generic controller/device family
physical output/resource capability
output type
addressing semantics/family
Display-assignment capability
firmware compatibility
source / notes metadata
```

Exact models remain distinct. `PixCon16` and `Pixie16` are different devices.

Free-text workbook spelling must not become permanent production authority.

## Firmware Workflow

Firmware management is required but must not block the initial controller inventory and label backfill.

A controller may be created as:

```text
Installed firmware = UNKNOWN
```

and verified later.

The eventual Controller application needs:

```text
controller/model
installed firmware
compatible firmware versions
current/recommended firmware for the exact model/revision
firmware verification/update status
firmware update history
person/date/notes
optional Work Order relationship
```

Do not determine firmware currency by naive string comparison. Compatibility/current status must follow controlled manufacturer/model firmware authority.

Useful application states include:

```text
CURRENT
UPDATE_AVAILABLE / UPDATE_RECOMMENDED
VERIFY_INSTALLED_VERSION
MODEL_REQUIRED
INCOMPATIBLE / REVIEW_REQUIRED
```

## Work Orders

Repairs, troubleshooting, parts replacement, and maintenance remain owned by the Work Order subsystem and should link to permanent `controller_id`.

Controller Inventory must not create a competing repair-history subsystem.

## Application Views / Navigation

The eventual Controller application should support at least these operational views:

| View | Purpose |
|---|---|
| Stage / Display | Browse physical controller contexts, assignments, missing/partial/review states |
| Missing Controllers | Work queue for controller contexts requiring assignment |
| Available Stock | Unassigned physical controllers, model/firmware/location, assign action |
| All Controllers | Complete permanent physical asset inventory |
| Controller Detail | Model, firmware, LOC, current assignment, verification, labels, Work Orders |
| Setup / Deployment | Pickup LOC, target Stage/Display, deployment LOC, placement notes |
| Takedown / Retrieval | Controllers to recover, park LOC, placement note, return-to-stock action |
| Reconciliation | Assignments requiring review after current approved LOR/V7 changes |
| Needs Verification | Unknown model/firmware/grouping/wiring-source facts |
| Models | Canonical controller/device model administration |
| Firmware | Compatibility, installed versions, update requirements/history |
| Labels | Initial label printing and reprinting |
| Retired | Retained permanent records for retired assets |

These views may be delivered incrementally. They describe the target workflow and must inform DDL so the initial data model does not prevent later implementation.

## Implementation Sequence — Do Not Let the Full App Block Initial Inventory

### Milestone 1 — Inventory Core

Provide the minimum durable Production Database foundation for:

```text
permanent controller_id
canonical model reference
controller status
verification state
current ref.location
controller-to-Display many-to-many relationship
firmware catalog/history foundation
audit fields
reconciliation/currentness foundation
```

The exact final table/column names remain subject to DDL review.

### Milestone 2 — Backfill / Assignment Workbench

Implement the minimum Controller application needed to begin real inventory work:

```text
browse Stage / Display / physical controller contexts
show Assigned / Missing / Partial / Review Required
show available controllers on the same workflow
add controller
add model
assign / unassign / replace controller
update ref.location
capture setup/placement note
print/reprint controller label
```

**Real controller backfill, permanent ID creation, labeling, and assignment may begin at this milestone.**

The full later application must not block this milestone.

### Milestone 3 — Reconciliation Integration

Add post-ingest currentness/reconciliation workflow for:

```text
new Displays / physical controller contexts
changed wiring
partial assignments
recycled/removed Display disposition
ambiguous mappings
```

Do not move destructive controller behavior into ordinary LOR ingest.

### Milestone 4 — Operational Inventory

Add/refine:

```text
available-stock reporting
setup deployment lists
takedown retrieval lists
location movements
repair/retire integration
Work Order links
```

### Milestone 5 — Firmware Management

Add/refine:

```text
model/firmware compatibility
current/recommended manufacturer firmware
firmware verification/update dashboard
firmware update recording/history
```

### Milestone 6 — FieldWiring Resolver

Replace temporary FieldWiring physical-controller mappings with the authoritative Controller Inventory read/resolution interface, including family-specific and E1.31/output cases as established by accepted Controller Inventory evidence.

## DDL Consequences Already Established by This Workflow

The first Controller Inventory migration must not assume:

```text
one controller = one Display
one Display = one controller
Network + UID = permanent controller identity
Stage = controller identity
ref.location = Stage
one controller must already be assigned
model must always be known at asset creation
firmware must always be known at asset creation
LOR ingest owns controller assignment lifecycle
```

The initial DDL must permit a physical controller to exist as an available stock asset with no Display/Stage assignment, while preserving the ability to assign it later without changing `controller_id`.

The DDL must also support current physical location via `ref.location`, many-to-many Display relationships, unknown/verification-required facts, controlled model/firmware references, and snapshot reconciliation/currentness.

## Remaining Pre-DDL Questions

This application framework does not by itself settle every table shape. Remaining design questions include:

- exact current deployment/Stage relationship representation;
- whether setup/placement note belongs on a current deployment record or another accepted relationship;
- exact representation of current Controller-to-LOR resolution/provenance;
- exact E1.31 physical-controller/output mapping representation;
- exact Glistening Grove reviewed wiring-source relationship representation;
- controller status and verification lookup values;
- exact firmware-history/current-installed representation;
- integration details with the existing label printing service;
- how Controller QR scans route into the eventual Controller application; and
- exact `ref.location` movement/update workflow and any needed LOC-system improvements.

These questions should be settled by walking real backfill/controller lifecycle cases through the proposed model before final DDL is authorized.

## Rule Established

> Build the minimum authoritative Controller Inventory core and Backfill/Assignment Workbench early enough to create permanent controller IDs, print labels, inventory spare stock, assign controllers to real Displays/Stages, and maintain current `ref.location`. Do not wait for the complete firmware/setup/takedown/FieldWiring feature set before beginning the physical backfill. At the same time, the first DDL must preserve the full accepted lifecycle so the initial inventory does not need to be rebuilt when those later application views are added.
