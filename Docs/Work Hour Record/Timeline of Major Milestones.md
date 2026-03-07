# MSB Production Database Project
### Project Timeline & Milestones
Prepared for MSB Board Review  
Period Covered: February 20 – March 4, 2026

---

# Project Overview

The MSB Production Database project is a major infrastructure initiative designed to replace spreadsheet-based tracking and fragmented data sources with a centralized operational system for managing displays, containers, testing, repairs, and inventory.

The system integrates Light-O-Rama preview data with a structured PostgreSQL database and a web-based operational interface used by production volunteers.

This project is intended to support:

• Display testing  
• Repair tracking  
• Container and pallet management  
• Inventory control  
• Production workflow coordination  

The goal is to provide a reliable operational system capable of supporting the growing scale and complexity of the MSB display inventory.

---

# Timeline of Major Milestones

## Feb 20 — Infrastructure Deployment
A dedicated production database server was built and PostgreSQL was installed.

This established the technical foundation required to move MSB production data out of spreadsheets and into a structured database system.

Outcome:

• Production database server operational  
• PostgreSQL environment configured  
• System architecture confirmed

---

## Feb 21 – Feb 22 — System Architecture & Data Model Design
The core database architecture and schema strategy were designed.

The system was divided into separate schemas to isolate data sources and responsibilities:

**lor_snap**  
Light-O-Rama ingestion snapshots

**ref**  
Reference data (displays, containers, stages, status tables)

**ops**  
Operational workflow tables (testing, work orders, repairs)

**stage**  
Raw spreadsheet imports used for reconciliation

This architecture ensures that LOR-derived data cannot accidentally overwrite operational records.

Outcome:

• Formalized database architecture  
• Normalized display and stage modeling  
• Defined ingestion pipeline from LOR preview files

---

## Feb 23 — LOR Data Import
Display data from the Light-O-Rama preview files was successfully imported into the system.

The ingestion pipeline parses preview files and materializes display objects, channels, and stage assignments into the database.

Outcome:

• Displays successfully imported from LOR
• Preview wiring data extracted
• Display inventory materialized in Postgres

---

## Feb 24 — Parser Debugging
A bug was discovered in the preview parsing script that affected channel grid handling.

The parser was corrected and the ingestion pipeline was re-tested to ensure reliable data extraction.

Outcome:

• Parser stabilized
• Wiring map views created for channel verification
• Reliable ingestion pipeline established

---

## Feb 25 — Testing & Data Validation Framework
A testing and validation framework was developed to ensure that imported data matches the physical display inventory.

Validation procedures were created for:

• Display counts  
• Channel ranges  
• Stage alignment  
• Inventory reconciliation

Outcome:

• Data validation procedures defined
• Testing checkpoints established

---

## Feb 26 — Operational Database Development
Work began on expanding the system beyond ingestion into a true operational database.

New tables were introduced to support:

• Work orders
• Repair tracking
• Maintenance history
• Inventory relationships

Outcome:

• Operational schema created
• System expanded beyond data ingestion

---

## Feb 27 — Data Integrity & Model Stabilization
Reference tables and relationships were refined to correct normalization issues discovered during testing.

Stage relationships and status references were stabilized.

Outcome:

• Reference data layer stabilized
• Relationships verified

---

## Feb 28 — Work Order System & Spare Channel Refactor
A work order and repair tracking system was designed.

Additionally, spare lighting channels were removed from the main display tables and placed into a dedicated reference table.

This change prevents spares from corrupting inventory data.

Outcome:

• Work order framework created
• Spare channels properly normalized
• Repair tracking structure introduced

---

## Mar 1 – Mar 4 — Operational Interface Development
Directus was deployed as the operational web interface for the system.

Directus provides a secure web UI for volunteers to interact with the database.

The following operational workflows were designed:

• Display testing sessions  
• Container testing dashboards  
• Repair reporting  
• Work order queues  

A role-based security model was implemented to ensure volunteers only see and modify appropriate data.

Defined user roles:

• Admin  
• Manager  
• Production Crew  
• Browser

Outcome:

• Operational web interface deployed
• Volunteer workflows modeled
• Role-based permissions implemented

---

# Project Impact

In just under two weeks, the MSB Production Database project has transitioned from concept to a functional operational platform.

The system now provides:

• Centralized display inventory management  
• Structured ingestion of Light-O-Rama preview data  
• Repair and work order tracking capability  
• Container and pallet tracking foundation  
• Web-based operational interface for volunteers  

This system is expected to significantly improve production efficiency and reduce the manual tracking currently required for managing display assets.

---

# Total Development Effort

**Total Hours:** ~168 hours  
**Time Period:** Feb 20 – Mar 4, 2026

Approximate breakdown:

Infrastructure Setup: 6 hrs  
Architecture & Design: 38 hrs  
Data Ingestion & Parser Debugging: 30 hrs  
Data Validation & Integrity: 26 hrs  
Operational Database Development: 40 hrs  
Operational UI & Workflow Design: 28 hrs

---

# Next Development Phase

Planned next steps include:

• Completing Directus dashboards for production crews  
• Implementing container movement tracking  
• Finalizing testing session workflows  
• Expanding repair ticket functionality  
• Preparing the system for use during the 2026 testing season

---

# Summary

The MSB Production Database represents a major modernization of the production infrastructure used to manage the display inventory and maintenance workflow.

The system provides a scalable, structured platform that will support both current operations and future expansion of the MSB display program.