# Production Database System Overview

| Document Control | Value |
|---|---|
| Document Type | Project Overview |
| System | MSB Production Database |
| Audience | Project contributors, managers, engineers |
| Status | CURRENT |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-08-09 |
| Keywords | production database, system overview, PostgreSQL, LOR, operations |

## Purpose

The MSB Production Database exists to provide permanent identity, relationships, history, and operational access across production information that was historically maintained in separate files, applications, drawings, spreadsheets, and specialized equipment datasets.

PostgreSQL is the durable identity, relationship, history, and operational integration layer. Specialized tools remain in use where they are the appropriate source or working environment.

## Authority Boundaries

### Light-O-Rama (LOR)

LOR remains authoritative for show topology and wiring configuration, including:

- previews and props;
- controller assignments;
- channel numbers and ranges;
- DMX/network assignments; and
- show wiring topology.

LOR UUIDs may be stored for traceability but are not Production Database permanent identity.

### PostgreSQL Production Database

PostgreSQL is authoritative for production identities and operational relationships, including areas such as:

- permanent Display identity;
- Containers and Storage Locations;
- Testing history;
- Work Orders;
- People and audit attribution;
- label/scan identity and operational state;
- physical controller inventory as that subsystem is implemented;
- physical network and site-infrastructure history as those subsystems are integrated; and
- future Setup and Deployment scheduling/history.

A repository or application boundary does not change data authority.

## LOR-to-Production Flow

The controlled upstream path is:

`LOR previews -> LOR2DB parser/ingest -> immutable LOR snapshot -> reconciliation -> controlled promotion -> PostgreSQL operational data`

The Production Database consumes and enriches LOR-derived information. It does not independently redefine LOR controller, channel, network, or wiring topology.

## Why Permanent Identity Matters

Operational history must survive changes in source files, application interfaces, and LOR-generated identifiers.

The Production Database therefore uses permanent MSB identities such as `display_id` for operational relationships and history. LOR source identifiers remain useful for traceability and reconciliation but do not replace permanent Production identity.

## Major Operational Areas

The current architecture is organized into subsystem owners rather than one monolithic application:

- Database Foundation;
- LOR2DB Ingest;
- People and Identity;
- Containers and Storage;
- Testing System;
- Work Orders;
- Labeling and Scanning;
- Controller Inventory;
- Wiring System;
- Network Infrastructure;
- Site Infrastructure / GIS; and
- planned Setup and Deployment.

See the [Production Database System Architecture](../02_Production_Database/01_System_Architecture/README.md) for the current engineering handoff for each subsystem.

## Application Model

PostgreSQL is the system of record. User interfaces and supporting applications may change as operational needs become clearer.

Current patterns include:

- **Directus** for graphical PostgreSQL presentation/editing, users/roles, bookmarks, selected operator workflows, and Directus Flows;
- **dedicated task-focused applications** where repetitive work needs a simpler UI;
- **LabelPrintService** as an external supporting service for physical label printing; and
- **future field/presentation applications** that consume Production Database data while preserving upstream authority boundaries.

Directus is an important implementation platform, but it is not the universal application layer for every operational task.

## Physical Operations Goal

The Production Database is intended to answer operational questions consistently over time, including:

- What is this physical asset?
- Where is it stored?
- What is assigned to it?
- Has it been tested?
- What work remains?
- What was repaired and when?
- What label or scan identity belongs to it?
- How does it relate to the current show design?
- When should it move to the park, and in what load/setup order?

The database should reduce dependence on tribal knowledge without replacing specialized tools that remain useful for authoring, testing, surveying, or visualization.

## Related Documents

- [Project Overview](README.md)
- [LOR System Overview](00_LOR_System_Overview.md)
- [Production Database Documentation](../02_Production_Database/README.md)
- [Production Database System Architecture](../02_Production_Database/01_System_Architecture/README.md)
- [LOR2DB](../../LOR2DB/README.md)
