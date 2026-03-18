# MSB Database — Documentation Index

Welcome to the documentation hub for the **Making Spirits Bright Production Database Project**.

This folder contains the detailed documentation for the **Making Spirits Bright Production Database Project** — including preview build procedures, operator guides, and developer references.

The MSB Database system integrates:
- Light-O-Rama (LOR) previews and channel data
- Wiring and stage maps
- Inventory and maintenance tracking
- SQL and Excel reporting automation

All documents here are maintained under version control to ensure consistent processes between **ShowPC**, **OfficePC**, and field operators.

---

---

## 📘 Core Documents

- [00 Project Overview](./docs/00_Project_Overview.md)
- [Project Overview (Narrative)](./Project_Overview.md)

### LOR System
- [01 Naming Conventions](./01_LOR_System/01_Naming_Conventions.md)
- [Building a Preview (How-To)](./01_LOR_System/building_preview_howto.md)
- [Preview Import Workflow](./01_LOR_System/Preview_Import_Workflow.md)
- [Preview Merger — Reference](./01_LOR_System/preview_merger_reference.md)
- [Core Comparison Logic](./01_LOR_System/Core_Comparison_Logic.md)
- [Database Structure (LOR)](./01_LOR_System/03_Database_Structure.md)
- [Quickstart (Operators)](./01_LOR_System/quickstart_operator.md)
- [Reporting History](./01_LOR_System/reporting_history.md)
- [Workflow v6 Readme](./01_LOR_System/workflow_v_6_readme.md)

---

## 🗄 Production Database

- [Production Overview](./02_Production_Database/Production_Overview.md)

---

## 🧰 Support & Setup

- [Troubleshooting](./01_LOR_System/Troubleshooting.md)

### Setup Guides
- [Install SQLite](./Setup/install_sqlite.md)
- [Install SQLite DB Browser](./Setup/install_sqlite_db_browser.md)

---

## 🗂 Reference / Archive

- [Database Cheat Sheet](./01_LOR_System/database_cheatsheet.md)
- [Processing Rules](./01_LOR_System/ProcessingRules.md)
- [Legacy Planning Notes 2023](./archive/legacy_planning_notes_2023.md)

---
```
Docs/
│
├── 00_Project_Overview.md
│
├── 01_LOR_System/
│   ├── Naming_Conventions.md
│   ├── Preview_Import_Workflow.md
│   ├── Preview_Merger_Reference.md
│   ├── Building_Preview_HowTo.md
│   ├── Processing_Rules.md
│   ├── Core_Comparison_Logic.md
│   ├── Workflow_v6_Readme.md
│   ├── Reporting_History.md
│   ├── Troubleshooting.md
│   └── database_cheatsheet.md
│
├── 02_Production_Database/
│   ├── Production_Overview.md
│   ├── Data_Contract_LOR_to_Production.md
│   ├── Database_Structure.md
│   ├── Ingestion_Process.md
│   ├── Display_Model.md
│   ├── Storage_Model.md
│   ├── Maintenance_Model.md
│   ├── Kit_and_Inventory_Model.md
│   ├── Controller_Model.md
│   └── Reporting_and_Views.md
│
├── 03_Integration/
│   ├── LOR_Snapshot_Model.md
│   ├── DisplayKey_Normalization.md
│   ├── Validation_and_QA.md
│   ├── Change_Control.md
│   └── Versioning_Strategy.md
│
├── 04_Operations/
│   ├── Operator_Quickstart.md
│   ├── Annual_Startup_Process.md
│   ├── Annual_Shutdown_Process.md
│   ├── Maintenance_Season_Workflow.md
│   └── Field_Wiring_Tablet_App.md
│
├── images/
└── Setup/
```
> **Revision History**  
> - GAL 25-10-29 — Initial merge of documentation index and project overview.  
> - GAL 25-10-30 — Added integrated intro paragraph and internal navigation links.