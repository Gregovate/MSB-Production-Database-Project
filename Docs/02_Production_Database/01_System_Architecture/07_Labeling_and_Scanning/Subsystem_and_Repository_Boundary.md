# Labeling and Scanning — Subsystem and Repository Boundary

| Document control | Value |
|---|---|
| Status | CURRENT BOUNDARY RULE |
| Revision | 2026-08-27 |
| Owner | Labeling and Scanning subsystem |
| Purpose | Prevent repository location from being confused with system ownership |

## Core Rule

**Repository location is not subsystem ownership.**

The MSB Labeling and Scanning subsystem, the MSB Production Database project, and the MSB Label Print Service are separate engineering boundaries even though they integrate closely and some Labeling and Scanning documentation/source currently lives inside `Gregovate/MSB-Production-Database-Project`.

Do not collapse these boundaries in design documents, starter prompts, issue scopes, branch planning, or implementation decisions.

The three boundaries are:

```text
Labeling and Scanning subsystem
    = cross-system labeling / payload / scanning contract

MSB Production Database
    = authoritative database records, database implementation,
      and database-hosted application integration

MSB Label Print Service / PRINT-SERVER
    = external physical-printing runtime and Brother implementation
```

## 1. Labeling and Scanning Subsystem

Labeling and Scanning is a **logical MSB subsystem**.

Its controlled engineering documentation currently lives under:

```text
Gregovate/MSB-Production-Database-Project
Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/
```

That repository placement is a documentation and source-control organization choice. It does **not** make Labeling and Scanning synonymous with the Production Database.

### Labeling and Scanning owns the cross-system contract

This subsystem owns or governs the engineering contract for:

- permanent label/scan identity conventions;
- canonical machine-readable payload conventions such as `DISP:`, `CONT:`, and `LOC:`;
- compatibility requirements for already-deployed physical labels;
- QR/barcode payload and symbology requirements;
- human-readable versus machine-readable label-content rules;
- logical label-profile requirements;
- scan input normalization expectations;
- scanner/tablet behavior and field acceptance requirements;
- the shared scan-routing boundary from a physical identifier to the appropriate MSB application/workflow;
- the integration contract between database-backed print requests and the external LabelPrintService;
- cross-system rules that must remain valid regardless of which repository contains a particular implementation file.

### Labeling and Scanning does not own every implementation

Implementation of the subsystem is intentionally distributed.

Examples:

```text
Production Database repository
    -> PostgreSQL identity / request state
    -> Directus-facing database integration
    -> Git-controlled Scan application source

MSB_LabelPrintService repository
    -> Brother templates
    -> b-PAC rendering
    -> Windows printer mapping
    -> PRINT-SERVER runtime

MSB-Server-Management repository
    -> deployed server/runtime administration
    -> reverse proxy / service deployment / recovery
```

A distributed implementation does not transfer subsystem ownership to any one implementation repository.

## 2. MSB Production Database Boundary

`Gregovate/MSB-Production-Database-Project` is the authoritative project for the Production Database and database-dependent application integration.

It owns the actual database implementation for items such as:

- `ref.display.display_id` and Display records;
- Container records and `container_id`;
- governed Storage Location data/keys where implemented;
- database relationships used by labeling/scanning;
- label-print request state stored in PostgreSQL;
- label batch/history/audit objects stored in PostgreSQL;
- database-side functions/views/schema needed to implement an approved Labeling and Scanning contract;
- Git-controlled Scan application source currently maintained with the Production Database project because it directly resolves Production Database identities and data.

The Production Database remains authoritative for its asset records and database state.

### The Production Database does not automatically own

The repository does **not** automatically own these merely because they interact with database records:

- Brother `.lbx` templates;
- PRINT-SERVER filesystem paths;
- Brother b-PAC behavior;
- Windows printer queue names;
- printer/media preflight;
- print-spooler verification;
- LabelPrintService startup/recovery;
- scanner hardware configuration;
- the overall Labeling and Scanning subsystem contract.

Database schema or application code must implement the approved Labeling and Scanning contract rather than silently redefining that contract as a side effect of a database change.

## 3. MSB Label Print Service / PRINT-SERVER Boundary

`Gregovate/MSB_LabelPrintService` is a separate repository and an **External Supporting Subsystem**.

Its production runtime is the dedicated PRINT-SERVER environment.

It consumes Production Database state and the Labeling and Scanning contract to produce physical labels.

### LabelPrintService owns

- `label_poll_service_v3.py` and successor print-runtime source;
- Brother b-PAC interaction;
- `.lbx` template source/runtime handling;
- printer-specific template mappings;
- Windows printer queue mappings;
- printer/media/runtime preflight;
- runtime SQL/CSV/template path handling owned by the service;
- Windows spooler verification;
- service logging;
- FAILED-batch/no-double-print protections implemented by the service;
- PRINT-SERVER startup, local runtime behavior, and service-specific recovery documentation;
- future raster/image rendering implementation when an approved Labeling and Scanning profile requires it.

### LabelPrintService does not own

- permanent Display/Container/Location identity;
- canonical identity policy;
- the authoritative Production Database record;
- business scan routing;
- a second asset resolver;
- a competing label-profile authority;
- Directus/database schema merely because the service consumes it.

If LabelPrintService is unavailable, physical printing stops. The Production Database remains authoritative and the Labeling and Scanning contract remains the governing integration boundary.

## 4. Scan Application Boundary

The current Scan application source happens to be maintained inside `MSB-Production-Database-Project`, while its behavior is part of the Labeling and Scanning subsystem contract.

That distinction must remain explicit.

The current Scan implementation may:

- read Production Database identity/data;
- accept supported physical/input payload forms;
- normalize old full URLs and compact canonical values;
- route a resolved identity to Display/Container/task workflows.

Its source location does not make all Labeling and Scanning decisions database-owned decisions.

Changes to canonical payload behavior, compatibility, new label types, or scan normalization must be reviewed as Labeling and Scanning changes even when the code change occurs in the Production Database repository.

## 5. Label-Profile Boundary

A future governed label-profile model crosses these boundaries and therefore must not be designed as a print-server-only or database-only feature.

The intended separation is:

```text
Labeling and Scanning
    -> defines the logical profile contract and approved behavior

Production Database
    -> stores governed profile identity/assignment and print-request state
       when PostgreSQL is the approved implementation location

LabelPrintService
    -> maps logical profiles to physical printer/template/media/rendering details
```

Raw printer names, local paths, and `.lbx` filenames must not be put into business asset tables merely because PostgreSQL stores a profile assignment.

Likewise, LabelPrintService configuration must not become the only authority for which logical label profile a Display, Container, Location, or Wiring workflow requires.

## 6. Documentation Ownership

Documentation must follow the same separation.

### Labeling and Scanning engineering documentation

Keep cross-system payload, scan, label-profile, hardware/scanner, and integration contracts here:

```text
Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/
```

This is the current controlled documentation home for the subsystem, not evidence that the subsystem equals the database project.

### Production Database implementation documentation

Keep schema/database-specific implementation details with the responsible Production Database architecture area when they are broader database concerns.

Labeling and Scanning documents should link to those details instead of duplicating them.

### LabelPrintService engineering/runtime documentation

Keep Brother, b-PAC, printer, template-runtime, spooler, PRINT-SERVER, failure/recovery, and service implementation details in:

```text
Gregovate/MSB_LabelPrintService
```

The Labeling and Scanning subsystem should record the integration requirement and link to the service's implementation authority rather than copying its runbook.

### Operator documentation

Keep operator procedures separate from engineering architecture in accordance with MSB documentation standards.

## 7. Thread / Branch Start Rule

Any future engineering thread touching labels, scanning, QR payloads, scanner hardware, print requests, templates, or printers must establish scope using these questions before changing anything:

1. Is this a **Labeling and Scanning contract** change?
2. Is this a **Production Database implementation** change?
3. Is this a **LabelPrintService / PRINT-SERVER implementation** change?
4. Does the work cross more than one boundary and therefore require coordinated changes/documentation in more than one repository?

Do not assume the repository currently being edited determines the answer.

If a change crosses boundaries, keep the commits/PRs separate by repository and link them through the owning subsystem documentation instead of merging unrelated branches or moving implementation into one repository for convenience.

## 8. Examples

### Change QR payload from full URL to `DISP:323`

This is first a **Labeling and Scanning contract** decision.

Implementation may then require:

- Production Database print-request/profile changes;
- LabelPrintService rendering changes;
- Scan regression/compatibility testing.

It is not automatically a database-only or print-server-only change.

### Change Brother template path

This is a **LabelPrintService runtime** change unless it changes the logical label profile contract.

It does not require adding the path to `ref.display`.

### Add `/scan/LOC/:key`

This is a **Labeling and Scanning behavior** change implemented in Scan source currently stored in the Production Database repository.

Any database queries/schema used by the route remain Production Database implementation concerns.

### Add `ref.label_profile`

The need and logical meaning of the profile belong to **Labeling and Scanning**.

The table itself, keys, FKs, audit fields, and database governance are **Production Database implementation** concerns.

Physical template/printer mapping remains **LabelPrintService** implementation.

## Related Documents

- [Labeling and Scanning](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Label Payload and Profile Architecture](Label_Payload_and_Profile_Architecture.md)
- [Label Creation and Printing](Label_Creation_and_Printing.md)
- [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md)
