# People Manager

This area owns the application/database implementation for the global People and Identity manager tracked by issue #130.

## Current State

Milestone 1 is a branch-only candidate. It is **not installed in Production**.

The first vertical slice is intentionally limited to the existing `ref.person` authority:

- manager-authorized person search and detail;
- create/edit contact information;
- active/inactive lifecycle;
- collision-safe reserved `@sheboyganlights.org` identity candidates;
- strong duplicate review before create/identity-changing edits;
- protected Directus/PostgreSQL identity fields;
- dynamic visibility of current foreign-key relationships; and
- no browser hard-delete action.

Google Workspace provisioning, Directus role management, capabilities, qualifications, Setup roles, and governed person merge remain later milestones.

## Folder Guide

| Folder | Purpose |
|---|---|
| `Application/` | Flask browser/API and static People Manager UI |
| `Database/` | Least-privilege PostgreSQL functions and grants |
| `Acceptance/` | Disposable/current-Production-clone acceptance artifacts |

## Engineering Authority

Read the People/Identity engineering handoff first:

`Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/README.md`

The current Production Directus onboarding behavior is documented in:

`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`

## Production Boundary

Nothing in this directory authorizes a Production mutation. Production deployment requires the repository-owned runbook and a separate explicit Production gate.
