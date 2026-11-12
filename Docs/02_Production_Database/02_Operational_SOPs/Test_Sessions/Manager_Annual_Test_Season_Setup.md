# Manager Annual Test Season Setup

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Testing |
| Task | Prepare the annual container/display testing season |
| Audience | Managers / Database Administrator |
| Status | DRAFT |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-08-09 |
| Keywords | annual testing, season setup, test sessions, manager, Directus, Production Database |

## Purpose

Use this procedure to prepare the Production Database for a new annual container/display testing season.

This procedure is intentionally separate from the volunteer Container Testing procedure. Volunteers should begin from the testing records and views prepared for the active season; they should not perform annual season initialization.

## Current State

The 2026 testing season was launched manually during system development.

A complete repeatable annual setup procedure has not yet been captured and verified. This document remains **DRAFT** until the actual database and Directus steps required to start a new season are documented and tested.

Do not infer or invent annual startup steps from the old Container Testing SOP.

## Known Requirements To Verify

The previous operator document indicates that annual setup involved season-related data and creation of testing records, but those statements predate the current documentation standards and must be verified against the implemented system before use.

The manager procedure must eventually document, at minimum, how to:

- identify the season that is ending and the season that is beginning;
- establish the correct active testing season in the Production Database;
- create or initialize the required container test-session records for that season;
- confirm which containers require testing;
- verify that the Directus **Containers Not Started** view shows the expected starting population;
- verify that all new test sessions begin in the intended initial status;
- validate the season launch before volunteers begin testing;
- record who performed the launch and when.

## Before This Procedure Becomes CURRENT

The responsible manager/database administrator must perform a controlled review of the current PostgreSQL implementation and Directus configuration and document the exact annual-start process.

The finished procedure must be tested on a safe/non-production rehearsal or at the next controlled season initialization before being marked **CURRENT**.

## Related Documents

- [Test Session Operational SOPs](README.md)
- [Testing System Engineering Handoff](../../01_System_Architecture/05_Testing_System/README.md)
- [Container Testing & Repair SOP](A_Container_Testing_and_Repair_SOP.md)
