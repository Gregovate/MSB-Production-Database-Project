# Setup #206 live Pick demand correction

Reviewed: 2026-10-06. Owners #206/#122. Status: test candidate, Production unchanged. Build V0.3.40-live-pick-demand. No migrations.

Greg reports CONT:12 (Sledder panels/stands/net-light frame, RB07-B-01, Stage 11) shown as Scheduled to Pick, Pick By 2026-10-05, Needed For 2026-10-06, but online Workshop Pick rejects it. Container was added this morning. Screenshots establish a disagreement, not an independently inspected Production database root cause.

Code defect: focused Pick validation maps explicit task displays and a task's direct Scene, while the visible Pick projection uses the installed material-resolution/ownership extensions, including Stage-level LOR membership. Focused mapping misses now consult the authoritative full live physical Pick projection before rejection. Normal focused-demand hits avoid the full projection. Reconciliation retains the physical identity, active delay, and movement observation; movement API still rejects delayed/already outbound assets. No permission bypass or movement write is performed by demand resolution.

Client also refreshes cached demand once before an online rejection, addressing a tab left open while demand/container membership changes. Refresh failure stops with an error; offline cached validation remains unchanged. Scanner shell cache v18 and exact asset pin updated; footer Updated 2026-10-06 and client/server identity synchronized.

Verification: 683 Setup/Application tests; direct JavaScript stale-tab refresh execution; scanner/worker JavaScript syntax; whitespace checks. Five new regressions exercise missing explicit container mapping, delay/movement preservation, normal fast path, and identity mismatch. Full projection on a focused miss costs more than a normal scan; replacing the independent optimized mapping with a common bounded resolver remains a performance follow-up.

Operator acceptance: disposable current-Production browser preview, verify matching V0.3.40 identity, scan CONT:12; exactly one PICKED event, correct container, no manager dependency. Confirm delayed/already-picked assets remain rejected. Keep a tab open, change material demand in the clone, then scan and verify refreshed eligibility. End preview CLEAN EXIT. Production deployment requires Greg's testing approval.

Greg's fallback request remains an operator-level accountable override, not a manager-only planning override; it is not implemented by this candidate. His preferred correction is eliminating this erroneous rejection.
