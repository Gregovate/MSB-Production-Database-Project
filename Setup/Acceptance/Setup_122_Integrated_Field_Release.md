# #122 integrated field release — review checkpoint

| Control | Value |
|---|---|
| Owner | #122; #171 map, #88 movement, #175 field presentation |
| Updated | 2026-10-10 |
| Status | Engineering verified; disposable/operator acceptance pending |
| Integration vehicle | Existing PR #318 / docs/171-symbol-type-mapping |
| Baseline main | 38f6f9427007470cbc02b3e2d23a97450d4414ba |
| Setup / Field Wiring | V0.3.61-home-map / V0.4.1-gis-entry |

## Included and deliberately retained work

| PR | Disposition |
|---|---|
| #318 | Shared map, Field Wiring entry, source reconciliation, compact controls, volunteer summaries |
| #309 | Guided ordinary Container Empty / Not Empty / Not Sure checks, remaining-name selection, explicit HERE removal, prior-location inference, Return Empty; migration 070 required |
| #308 | Current/missing-location wording and Home hidden when usable GPS exists; inferred provenance retained |
| #321 | Existing Container-to-map links; printable geographic inset still unfinished |
| #301/#302 launch debug | Already merged; preserve current-main scanner/scheduling behavior |
| #324/#325 | Latest recorded Production scheduling behavior preserved |
| #319 | CSV validation/import vehicle remains separate; raw-FLW map adapter already in #318; durable DB importer not completed |
| #291 | Guarded empty Work Day deletion remains separate, requires its own migration/acceptance; not silently included |
| #266 | Offline Training rehearsal open; not merged wholesale; real tablet/Zebra acceptance remains outstanding |
| #271 | Old readiness/responsive branch needs supersession closeout against accepted main; not merged wholesale |
| #272 | Branch head already ancestor of main; stale open PR needs administrative closeout with existing acceptance evidence |
| #229 | Earlier GIS reconnaissance superseded in scope by current GIS authority; closure requires inclusion/evidence review |
| #300 | LOR two-PC sync is a separate deployment target, not this web release |
| #230 | Reference editor/power metadata remains unfinished and explicitly deferred by owner for today's map |

Open-PR search returned these eleven open PRs: 229, 266, 271, 272, 291,
300, 308, 309, 318, 319, 321. This is an open-PR inventory, not a claim that
all historical launch issues have been closed or every acceptance criterion met.

## Preview tooling correction

The imported #309 wrapper ran standalone disposable acceptance and then the
browser launcher, causing a second dump/restore. The existing browser runner
already applies MigrationPaths and ValidationPaths before readiness. The wrapper
now calls that runner once after local application regression: one initial current
Production capture, SQL acceptance and browser review on that same clone. Existing
resume-on-tunnel-loss behavior is retained. No new runner, port or dependency.
The initial clone capture and eventual Production rollback snapshot are distinct
requirements; neither is removed. This fixes the concrete duplicated path found;
it does not establish the identity of the previously discussed tooling commit.

Use the existing `run_setup_88_contents_browser_review.ps1 -CandidateSha <exact SHA>`
from a clean map-branch checkout. It pins this integration branch, V0.3.61,
070 and its validation, and existing port 8898. Open only at BROWSER REVIEW READY.

## Nearest-reference contract

The curated `setup_location_references.json` (2026-stage-reference-20261003.1)
is the existing GPX/ExpertGPS-derived Stage set. Fetch refreshes localStorage;
offline uses cached data. No new Drop Points or fabricated thresholds are added.
The closest of three suggestions is green and labelled Nearest; alternatives
are neutral. Every current fix reranks; stale/off GPS removes suggestions.
Selection remains explicit and does not confirm placement or unload.

## Required operator review — disposable only

1. Check Client V0.3.61 and current scheduling/Perform Work behavior.
2. Open /fieldwiring/ then Park Map; check Field Wiring default layers. Open
   /setup/locate/ and check Setup defaults, Containers/displays, network selection,
   cleared search, collapsed/reopened controls and a Container deep link.
3. Record Location: ordinary loaded Container → Not Empty → All still here;
   confirm no Display removal. Repeat at another stop.
4. Fewer remain: select remaining Display Names, inspect PRIOR location review;
   cancel once, then confirm in clone. Check resulting map/report evidence.
5. Test explicit HERE group removal separately; Empty/Return Home must show home
   and empty status. Standalone Display/Pallet keeps its protected location-only flow.
6. Not Sure stays unresolved with retained evidence; it is not a completed Manager
   resolution tool. Historical errors are not automatically repaired by this release.
7. GPS Nearest rank/color changes as location changes; no auto-selection. Real
   tablet/Zebra/offline behavior still requires device evidence.
8. End with CLEAN EXIT and retain the report plus operator findings.

## Deployment and closeout gates

No Production mutation has occurred. This is migration-bearing because of 070;
use current Server Management database-change/maintenance authority, not a
source-only Setup installer. Field Wiring source publication also needs its
shared-checkout/Procedures boundary preserved. Read current authorities and live
baseline before preparing the governed deployment; do not invent a multi-app runner.

After browser acceptance: exact authorization, accepted repository integration,
maintenance/freeze/validated rollback snapshot, approved migration and application
promotion, validation and ONLINE proof, protected operator checks, exact deployed
identity, deployment-log/runtime updates and owning PR/issue dispositions. Keep
#88 delayed review, historical correction and takedown gaps open. Update #122's
checkpoint before deployment and at closeout; never call this engineering pass a
completed release.


## October 10 Home map correction and real round-trip evidence

Greg reported reusable preview CLEAN EXIT at 11:18 CDT for the preceding V0.3.60
candidate. Laptop controls and Container deep link were accepted; this does not
constitute acceptance of every guided-unload case or the new V0.3.61 candidate.

Production query results supplied by Greg prove session 2 C046 picked event 103,
park drop 116, returned Home 186 (RA09-B-01); C050 picked 106, drop 114, returned
188 (RA10-C-01). Returns occurred October 9 around 14:18 Chicago time without GPS.
All 16 displays per Container are DETACHED and still reference their respective
park drop GPS, accuracy 10.3/10.5 feet. No repair or repeat scan is needed for these
records. Greg confirms Tom physically unloaded at the park drop. This is current
state proof, not proof of the time the detach transition was written.

V0.3.61 maps confirmed Home returns to the supplied Workshop reference, preserves
rack labels in search/popup, and identifies the map anchor as reference-derived,
not captured GPS. Detached display positions remain event-derived. Unobserved
containers remain expected/unconfirmed Workshop; no park Stage named Workshop is
substituted. Failed refresh retains the current in-memory snapshot. Persistent
offline reopening and refresh-control placement remain outstanding.

Focused browser recheck: C046/C050 search and deep links show Workshop/rack;
all 32 displays remain in park; fail an asset refresh and confirm markers/search
remain. Cover-sheet pagination/material links still need separate resolution.
Production remains unchanged; migration 070 remains required for the integrated
release even though this follow-up itself changes no database records/schema.

Engineering validation for V0.3.61: 752 Setup/Application plus combined GIS preview
tests passed. Broader Setup/Acceptance discovery exposed six pre-existing failures
in the older report-read/source-only deployment contracts; the same six reproduce
on unchanged bef48eae. These old exact-report query contracts do not match the
integrated map inventory query. They remain unresolved and must not be reported
as passing deployment gates. The integrated migration/browser wrapper is unchanged
except its expected release version.
