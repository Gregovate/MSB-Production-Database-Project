# MSB Production Database Project
## Board Summary
Prepared for MSB Board Review
Period: Feb 20 – Mar 8, 2026

---

# Project Purpose

The MSB Production Database project replaces spreadsheet-based tracking with a centralized system for managing displays, containers, repairs, and testing operations.

The system integrates Light-O-Rama preview data with a structured PostgreSQL database and a web-based operational interface used by volunteers.

---

# Major Milestones

## Infrastructure Deployment

A dedicated production database server was built and PostgreSQL installed.

---

## Database Architecture

A normalized multi-schema architecture was designed separating:

• LOR ingestion data  
• reference inventory data  
• operational workflow data

---

## LOR Data Integration

A custom ingestion pipeline imports Light-O-Rama preview data into the database including:

• display definitions  
• channel assignments  
• stage locations

---

## Inventory Data Model

Reference tables were created for:

• displays  
• containers  
• storage locations  
• stages  
• inventory status tracking

---

## Work Order System

A repair and maintenance tracking system was implemented to allow volunteers to record display issues and generate repair tasks.

---

## Operational Web Interface

Directus was deployed as a web-based interface allowing volunteers to:

• conduct display testing  
• record inspection results  
• report repair issues  
• manage container inventory

---

## Security and Audit Tracking

A role-based security model was implemented for volunteer access.

An audit logging system now tracks all system activity including:

• record creation  
• record updates  
• operational workflow changes

---

# Development Effort

Total development effort to date:

**~223 hours over approximately 17 days**

Work included:

• server infrastructure deployment  
• database architecture design  
• LOR ingestion engineering  
• operational workflow development  
• web interface integration  
• security and audit framework implementation

---

# Current Status

The system is now functioning as an operational prototype.

Core capabilities include:

• centralized display inventory management  
• container tracking  
• testing workflow recording  
• repair and work order tracking  
• volunteer-accessible web interface
• container pull workflow implemented and entering operational testing
• full audit logging implemented for all operational database activity
---

# Next Steps

Planned development includes:

• additional operational dashboards  
• expanded container movement tracking  
• refinement of testing workflows  
• preparation for the 2026 testing season

---

# Summary

The MSB Production Database represents a major modernization of the infrastructure used to manage MSB display inventory and production workflows.

The platform will significantly improve operational efficiency, reduce manual tracking, and support future expansion of the display program.