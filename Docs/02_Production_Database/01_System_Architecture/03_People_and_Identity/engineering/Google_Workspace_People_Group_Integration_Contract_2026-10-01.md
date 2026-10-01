# Google Workspace / People Group Integration Contract — 2026-10-01

| Document Control | Value |
|---|---|
| Document Type | Engineering Design Contract |
| System | People and Identity / Google Workspace / Directus |
| Status | DESIGN — integration not implemented |
| Owner | Production Database / People and Identity |
| Related | Issue #130 |

## Purpose

Define how a future Google Workspace integration may complement the MSB People system without making Google Workspace the authority for volunteers who do not have Google accounts.

## Core Boundary

The People database remains the complete person/contact authority.

Google Workspace is authoritative only for real Google Workspace identities and Google-managed group membership.

These populations are not identical.

Examples:

```text
Setup helper without Google account
    -> exists in ref.person
    -> may have SETUP_VOLUNTEER
    -> may receive email via personal_email
    -> does not exist in Google Workspace

Google Workspace user not in Production
    -> exists in Google Workspace
    -> may exist in ref.person
    -> may receive baseline Browser database access
    -> is not automatically Production Crew or Setup

Production Crew Google user
    -> exists in Google Workspace
    -> should exist in ref.person
    -> Google Production Crew group may inform Directus Production Crew authorization
```

## Desired Integration

A future integration should expose Google Workspace account/group state as an external identity fact linked by exact Sheboygan Lights email.

Useful synchronized facts include:

```text
Google account exists
Google account active/suspended
Google primary email
Google group memberships
last synchronization timestamp/status
```

Do not copy Google passwords, authentication secrets, or mailbox content into PostgreSQL.

## Group Mapping

Google groups may be mapped to MSB system roles only when the ownership semantics are deliberately equivalent.

Example candidate mapping:

```text
Google Workspace Production Crew group
    -> Directus Production Crew authorization
```

This mapping should be deterministic and centrally configured. An ordinary People Manager must not choose arbitrary Directus roles.

People-only operational groups such as:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

must continue to work for people without Google accounts. Google Workspace therefore cannot be the sole authority for these role groups.

A future integration may optionally mirror selected People role cohorts into matching Google Groups for communication convenience, but the direction and authority must be explicit per group.

## Reconciliation Model

The intended comparison is:

```text
Google account/group state
        +
ref.person / People role state
        ->
reconciliation view
```

The system should surface mismatches such as:

- Google Production Crew member has no Person;
- Person has real MSB Google email but no matching Google account;
- Google Production Crew member lacks intended Directus Production Crew authorization;
- Directus Production Crew user no longer belongs to the authoritative Google group;
- Setup/Takedown role exists for a person with no Google account — valid, not an error.

Do not silently repair conflicts without a governed policy.

## Provisioning / Authorization Direction

For database application access:

```text
real Google Workspace account
    -> eligible for Google authentication
    -> baseline MSB Browser may be provisioned

authoritative Production Crew group membership
    -> may deterministically authorize Production Crew role

Manager / Administrator
    -> separate privileged governance
    -> never assigned by ordinary People Manager role choice
```

## Current Tooling Limitation

As of 2026-10-01, the available ChatGPT Google connectors in this workstream provide Gmail, Calendar, Drive, and Contacts functionality, but no connected Google Workspace Admin / Directory group-management source is available here.

A production integration would therefore require an explicit Google Workspace Admin/Directory API integration or another approved system connector. It must not be inferred from Gmail/Contacts data.

## Immediate Priority

Before implementing Google synchronization:

1. complete the People population so all relevant Production Crew and Setup/Takedown participants exist;
2. use the People role/group selector to audit role membership;
3. establish the role-to-email communication cohort;
4. define which Google groups are authoritative for database authorization versus merely communication; and
5. then design the controlled Google Workspace reconciliation/synchronization boundary.
