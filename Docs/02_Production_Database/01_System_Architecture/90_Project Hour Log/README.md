# Project Hour Log

This area preserves a practical estimate of engineering effort for the MSB Production Database project.

It is not intended to be a precise employee timecard. The project has involved long development, testing, troubleshooting, documentation, deployment, and design sessions that were not consistently timed minute-by-minute. The goal is to preserve credible milestone-level effort for project history and board reporting without creating false precision.

## Current Historical Record

- [Daily Project Summary](Daily%20Project%20Summary.md) contains the detailed early project record from February 20 through March 15, 2026.
- That record estimates approximately **325 hours** through March 15, 2026.

The early daily record is useful historical evidence, but future updates should use the milestone method below rather than attempting to reconstruct a daily timecard after the fact.

## Work-Hour Recording Rule

Use the Project Hour Log as a **milestone effort record**.

For each material project milestone, record:

- date or date range;
- milestone or major work area;
- concise description of what was accomplished;
- estimated hours spent;
- whether the estimate is recorded contemporaneously or reconstructed later;
- evidence used for a reconstructed estimate when useful, such as Git commits, deployment dates, test runs, project notes, documentation history, or known work sessions.

Prefer a reasonable rounded estimate or range over false precision.

Examples of appropriate milestones include:

- LOR parser or ingest generation changes;
- reconciliation-engine development and production validation;
- Directus/testing/work-order workflow development;
- labeling and scanning implementation;
- server/deployment work directly attributable to this project;
- major documentation/audit/restructure work;
- setup/deployment subsystem design;
- significant debugging or production recovery work.

Do not create an hour entry for every minor commit or documentation correction.

## Estimation Guidance

When reconstructing historical effort:

1. Start with any contemporaneous hour records already present.
2. Identify major development milestones and date ranges from repository history and project documentation.
3. Use commits and deployment/test evidence to establish that work occurred; do not treat commit count as hours.
4. Estimate the actual working sessions required to produce, test, debug, document, and deploy the milestone.
5. Use conservative rounded figures when evidence is incomplete.
6. Mark reconstructed estimates as approximate.
7. Keep a cumulative project estimate suitable for board-level reporting.

The purpose is to answer, credibly, **approximately how much engineering effort has gone into the system**, not to claim payroll-grade accuracy.

## Board Reporting

For board reporting, summarize effort by major milestone or system area rather than presenting a long daily ledger.

A board-level summary should normally include:

- project period;
- major systems or milestones delivered;
- approximate hours for each major area;
- cumulative estimated project hours;
- a short note that hours are engineering estimates reconstructed from contemporaneous logs and project history where exact tracking was not available.

## Resume Updating This Log

The next update should reconstruct the period after March 15, 2026 using the repository history and the major implementation milestones already documented across the Production Database, LOR2DB, Directus workflows, testing, work orders, labeling/scanning, and the current documentation audit.

Keep the existing February–March daily summary as historical evidence. Do not rewrite its dates or hours merely to fit the newer milestone format.