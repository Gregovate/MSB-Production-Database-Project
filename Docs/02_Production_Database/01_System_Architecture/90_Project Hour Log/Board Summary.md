# MSB Production Database Project
## Board Summary
Prepared for MSB Board Review
Period: Feb 20 – Mar 6, 2026

---

# Project Purpose

The MSB Production Database project replaces spreadsheet-based inventory tracking with a centralized operational system for managing displays, containers, repairs, and testing activities.

The system integrates Light-O-Rama preview data with a structured PostgreSQL database and a web-based interface used by production volunteers.

The goal is to improve reliability, reduce manual tracking, and support the growing scale of the MSB display inventory.

---

# Major Milestones

## Infrastructure Deployment

A dedicated production database server was built and PostgreSQL was installed to support the system.

---

## Database Architecture

A normalized multi-schema database architecture was designed to separate:

• Light-O-Rama ingestion data  
• reference inventory data  
• operational production workflows

---

## LOR Data Integration

A data ingestion pipeline was implemented to import Light-O-Rama preview information into the database, including:

• displays  
• channels  
• stage assignments

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

A work order system was designed to track:

• display repairs  
• maintenance activities  
• testing issues identified during inspection

---

## Operational Interface

Directus was deployed to provide a web-based operational interface for volunteers.

The interface allows production volunteers to:

• conduct display testing  
• record inspection results  
• report repair issues  
• manage container inventory

---

# Development Effort

Total development effort to date:

**~200 hours over 15 days**

Work included:

• server infrastructure deployment  
• database architecture design  
• data ingestion engineering  
• operational workflow development  
• web interface integration

---

# Current Status

The system is now functioning as an operational prototype.

Core capabilities include:

• centralized display inventory management  
• container tracking  
• testing workflow recording  
• repair and work order tracking  
• volunteer-accessible web interface

---

# Next Steps

Planned development includes:

• refinement of volunteer dashboards  
• expansion of container location tracking  
• improvements to testing workflows  
• preparation for the 2026 testing season

---

# Summary

The MSB Production Database project represents a significant modernization of the infrastructure used to manage the MSB display inventory and production workflow.

The system will improve reliability, reduce manual tracking, and provide a scalable platform for managing future display growth.