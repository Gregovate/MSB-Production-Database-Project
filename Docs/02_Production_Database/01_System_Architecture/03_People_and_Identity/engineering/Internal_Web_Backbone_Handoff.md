# People Manager — Internal Web Backbone Handoff

| Document Control | Value |
|---|---|
| Document Type | Source Subsystem Handoff |
| Source Repository | `Gregovate/MSB-Production-Database-Project` |
| Source Subsystem | Production Database — People and Identity |
| Status | READY FOR BACKBONE INTEGRATION |
| Last Reviewed | 2026-09-09 |
| Source Issue | Production Database #130 |
| Backbone Issue | `Gregovate/MSB-Internal-Web-Backbone` #16 |
| Live People URL | `https://my.sheboyganlights.org/people/` |

## Purpose

This handoff tells `Gregovate/MSB-Internal-Web-Backbone` how to expose the accepted live People Manager from the Production intranet page.

The Backbone is a navigation/presentation layer. It does not become the authority for People procedures, database behavior, identity contracts, capabilities, qualifications, or application implementation.

## Source Authority

Canonical People operator portal:

```text
Docs/02_Production_Database/02_Operational_SOPs/People/README.md
```

Primary plain-English operator procedure:

```text
Docs/02_Production_Database/02_Operational_SOPs/People/People_Manager_Operator_Procedure.md
```

Engineering authority:

```text
Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/README.md
Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/README.md
People/README.md
People/Acceptance/People_Manager_Production_Acceptance_2026-09-09.md
```

## Verified Application Entry Point

The accepted Production People Manager route is:

```text
https://my.sheboyganlights.org/people/
```

Production acceptance proved the protected Synology route, V0.2.0 backend health, HTTP 401 without trusted identity, normal Cloudflare-authenticated Manager access, and live Production rendering.

Temporary localhost/browser-preview URLs such as `http://127.0.0.1:8795/` are acceptance artifacts and must never become Backbone dependencies.

## Production Page Task Intent

The Production intranet should expose People Manager by the operator task, not by implementation details.

The task should make it clear that this is where a Manager/Administrator can:

- find an existing volunteer/contact;
- add or maintain a person/contact record;
- activate/reactivate or mark a person inactive;
- maintain capabilities;
- maintain formal qualifications and expiration/evidence information;
- maintain Setup/Takedown participation and Captain/Advisor eligibility; and
- review existing reusable-task Captain/Alternate/Advisor responsibilities.

A suitable task-oriented label is **People / Volunteers** or **People Manager**. Final wording should fit the existing Production page without redesigning unrelated navigation.

## Preferred Navigation Behavior

1. The Production page should link primarily to `https://my.sheboyganlights.org/people/`.
2. A secondary **How to use People Manager** or equivalent procedure link may point to the canonical People Operational SOP portal when that improves discoverability.
3. Existing unrelated Production application links and committee information must remain unchanged unless separately authorized.
4. The visible Production page version indicator must be updated according to Backbone Project Rules.

## Operator Tasks That Must Be Discoverable

```text
Find or add a volunteer/contact
Update a person's contact information
Mark someone inactive or reactivate a returning person
Record skills/capabilities
Record formal training/qualifications
Record Setup/Takedown participation or Captain/Advisor eligibility
See a person's current reusable-task leadership responsibility
```

Do not expose separate links for every People database table or API endpoint.

## Content To Exclude From Normal Operator Navigation

Do not expose these as normal Production-page choices:

- `People/Database/*` migrations;
- Flask/Python/JavaScript/CSS implementation files;
- `People/Acceptance/*` engineering harnesses/reports;
- engineering design/reconnaissance documents;
- Directus role UUIDs or onboarding implementation details;
- PostgreSQL functions/tables;
- temporary preview ports/URLs; or
- GitHub issue/PR history as the operator workflow.

Engineering/history remains available from the source repository for maintainers but is not ordinary operator navigation.

## Compatibility / Ownership Boundaries

- `ref.person` remains Production Database authority for the durable person identity.
- Google Workspace remains authority for whether a reserved MSB email account/mailbox has actually been provisioned.
- Directus remains role/policy authorization authority.
- People Manager maintenance is limited to Manager / Administrator or equivalent accepted `admin_access` authority.
- Setup remains authority for actual reusable-task Captain/Alternate/Advisor assignments.
- People Manager shows those leadership relationships read-only.
- The Backbone must not create a second People data store or duplicate editable People procedures.

## Analytics Boundary

The People application owns its direct GA4 integration using measurement ID `G-X08ZTSY0VV`, analytics version `2026-09-09.1`.

The direct Production `MSB People Manager` page view was verified in the MSB Internal Intranet GA4 property on 2026-09-09.

The Backbone must not add person identity, search text, email, phone, `person_id`, authenticated identity, or other People record identifiers to its analytics.

If the Production page records an anonymous navigation event for choosing People Manager, it should record only a bounded destination/task classification, not the person being managed.

## Acceptance Criteria

Backbone integration is `VERIFIED` only when all of the following are true:

```text
[x] Production People Manager deployment is complete and live route is known
[x] this handoff contains the exact verified live People application entry point
[x] matching MSB-Internal-Web-Backbone issue exists — #16
[x] People direct GA4 page view verified by source Production closeout
[ ] current Backbone source and currently published Production page reconciled before editing
[ ] Production page contains a clear task-oriented People / People Manager entry
[ ] the entry opens https://my.sheboyganlights.org/people/
[ ] operator procedure is discoverable where appropriate
[ ] unrelated Production navigation/content is preserved
[ ] engineering/acceptance/runtime files are not exposed as normal operator choices
[ ] visible Production page version indicator is updated and verified live
[ ] Backbone live link has been tested after deployment
[ ] Backbone issue records PR/commit/deployment evidence and is marked VERIFIED
[ ] this source handoff is updated from READY to VERIFIED as the return handoff
```

## Return Handoff

After Backbone deployment verification, update this document with:

```text
Live People application URL: https://my.sheboyganlights.org/people/
Backbone issue: #16
Backbone PR: #<number>
Backbone merge/deployment revision: <revision>
Production page version verified: <version>
Status: VERIFIED
Verified date: <date>
```

Do not mark this handoff `VERIFIED` merely because the Backbone source change has merged.
