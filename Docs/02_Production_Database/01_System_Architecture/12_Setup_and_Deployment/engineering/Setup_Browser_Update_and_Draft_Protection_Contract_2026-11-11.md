# Setup browser update and draft protection

| Document control | Value |
|---|---|
| Status | Engineering draft; no implementation or deployment claimed |
| Owner | #486, coordinated by #205 under #122 |
| Baseline | main c91a5b20385cd8ecec83ef14524378fd6b9153e8 |
| Production | fdf1549e4215c305cb82b3e6e70e327ade574dd2 / V0.3.111 |
| Reviewed | 2026-11-11 America/Chicago |

## Observed problem and evidence

An already-open Setup tab retained old report/task presentation until refresh
throughout PR482/483 testing. Greg reports recurring confusion for Rick.
Presentation-only releases legitimately kept V0.3.111 while asset pins changed.
This is confirmed stale executing code, not proof of an HTTP-cache defect.

Current setup_catalog_dirty_guard.js ensureServerBuild compares only health.version
with CLIENT_BUILD. It runs on guard installation and before governed commands;
there is no periodic/focus/visibility deployment detector in that guard.
production_backend.py health returns status, version and data_mode, without a UI
revision. Main-page/static no-store prevents reuse on a later request; it cannot
replace code already loaded in an open tab. Existing unload/dirty protection
tracks reusable task, physical effort and annual review; complete Report Work,
scheduling, readiness and other dialog draft coverage has not been established.

## Required behavior

1. Detect changed deployed UI even when the human version stays unchanged.
2. Show a persistent, accessible Update available notice, independent from
   transient business alerts; display correctly in both themes and small windows.
3. Check at initial load, restored visibility/focus, reconnection and a bounded
   visible-tab interval. Deduplicate overlapping checks; avoid polling hidden tabs.
4. Never auto-reload, auto-submit, discard or fabricate an operational entry.
5. Keep existing identity/permission/version write guards. A network failure,
   maintenance page, expired session or malformed health response is not a new build.
6. Distinguish deployed-code revision from stale operational data. Existing Refresh
   current actions still reloads data and must not falsely promise updated code.

## Revision mechanism

Proposed source-only implementation: Python computes a deterministic UI artifact
revision once per application process from the exact served main HTML and its
local runtime JS/CSS dependencies. Use an explicit, tested allowlist derived from
existing served assets. Exclude documentation/tests, Git metadata, timestamps,
secrets and operational data. No Git subprocess, Node, new service or database.
Include human version plus artifact revision in no-store health and embed that
same process revision in the served main document before its scripts execute.
The client retains its loaded document revision; compare against server revision,
not the current asset URL or a same-version badge. A documentation-only commit
must not trigger the notice. Deployment source SHA remains release evidence;
the artifact revision is a freshness indicator, not a replacement release identity.

## Draft protection and command boundary

Do not implement a generic Save-and-reload that assumes the existing Catalog
save action covers every screen. Inventory each editable form and pending-save
state before connecting reload to it. Required inventory: reusable Catalog,
annual review/effort, Report Work and correction, scheduling/new Captain/crew
staffing, annual readiness, Planning Info, task creation/feedback and other main
page dialogs. Standalone scanner/offline pages are a separate inventory.

The notice itself is non-destructive. Reload is permitted immediately only when
there is proven no draft, no save in flight and no active scanner/queue operation
within its supported boundary. With an edit open, retain inputs and stay on the
page. Offer that form's existing guarded save/cancel route where compatible.
Never clear another form's dirty state because an unrelated API command succeeded.

An incompatible human-version change may already prevent the draft from saving.
Do not tell the operator to save if that command is rejected. Before enabling
reload in that state, design and test an explicit recoverable draft handoff scoped
to identity, season, task/assignment and form schema. Restore only after reloading,
revalidating identity/record/permissions and operator review; never auto-write.
Until a form has this protection, keep reload disabled for its open draft and
explain why. No silent storage of credentials, tokens, arbitrary form payloads or
unbounded historical notes. Exact storage/retention and restore format remain
implementation gates, not decided by this draft.

Same-version presentation updates must not unnecessarily prevent a compatible
save merely because assets changed. Human-version command compatibility and UI
freshness are distinct checks; do not weaken the current incompatible-version
write refusal. Draft protection must work before making any refresh automatic.

## Scope and acceptance

First candidate owns the main protected Setup page only. Inventory Pick List,
Record Location, service-worker/offline and other applications independently;
do not claim a systemwide repair from one page. Do not change current business
calculations, scanner sync, records, maintenance or deployment infrastructure.

Acceptance matrix must cover same-version presentation deploy, different-version
deploy, documentation-only commit, initial load, hidden/refocused tab, two tabs,
reconnection, offline/auth/maintenance/malformed health, clean page, every dirty
form, successful/failed/in-flight save, cancelled reload, explicit draft recovery,
identity/season/record change, and both themes/mobile notice. Python tests only;
real browser cases use the existing disposable preview and operator workflow.
No Production test records or new runtime dependency.

## Next implementation gates

- Complete editable-form/pending-save inventory and identify current state owners.
- Specify the exact artifact allowlist and identity/draft handoff schema.
- Add source-only implementation and meaningful Python regression without Node.
- Exact candidate through existing reusable disposable browser preview; confirm
  old-tab behavior across a controlled disposable source change, not just refresh.
- CLEAN EXIT and separate Production approval. Current Production stays unchanged.
