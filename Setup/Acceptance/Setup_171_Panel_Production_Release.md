# PR455 panel-slot Production release preparation

Status: browser accepted; Production execution pending. October 25, 2026.

Authority: #122 commands #171/#230. Owning design:
[Panel Circuit Design](../../Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Panel_Circuit_Design.md),
October 25 accepted PR455 incremental release. Server authority:
[Production Database Change Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md)
and its Issue37 maintenance companion. Classification: DATABASE-CHANGING.

Accepted application: `0fd7fabd48dce287722112405bafb8e3aa65f637`,
V0.4.22-panel-navigation. PR455 merge: `6a421e47c80bd4e1976a67137fe1686bfa92caac`.
Greg reported PASS and CLEAN EXIT. Exact Setup/FieldWiring/Chromium/PostGIS CI passed.
Current shared/Setup live identities verified at `439ab237beaae4ac648e7590f824a774969cd84f`.

The existing maintenance orchestrator executes this bounded profile:
`setup_171_panel_release.py`, exact manifest `setup_171_panel_release.json`,
committed-byte transport `setup_171_panel_transport.py`, foreground wrapper
`run_setup_171_panel_release.ps1`. Default wrapper invocation is preflight only;
`-Deploy` selects the separately authorized mutation sequence. Do not use the
initial `run_setup_171_release.ps1` for this upgrade.

Only `171_panel_slot_count.sql` runs, followed by its accepted read-only validation.
No source intake, historical schema replay, panel rewrite or component creation.
Setup stays at its existing source. The shared FieldWiring checkout advances to
the exact accepted application after database validation, while writers are fenced.
Existing row fingerprints exclude only the new nullable panel slot-count key.

Run from a clean merged tooling checkout on Greg's laptop. Reuse the existing
review worktree; do not create another. The exact final tooling SHA and complete
PowerShell handoff are recorded in the release-tooling PR after CI. The wrapper
uses one SCP and one foreground SSH, retains the server report/snapshot and removes
its temporary bundle/worktree. Keep the reusable laptop review worktree until
Production closeout; always return to `C:\lor\ImportExport\VSCode`.

On STOP or connection loss: retain output; do not retry or operate the maintenance
dashboard. Review the retained state/report and controller state before any next
action. The runner never automatically calls OFF or restores the database after a
failure. Normal writes resume only after complete frozen validation and controller
ONLINE proof. Do not compare frozen data against later legitimate ONLINE edits.

After server PASS, verify the protected Production panel screen: V0.4.22, existing
inventory, actual slot-count edit, 60 A choice, settings/action colors and panel
return context. Record actual report/snapshot path/hash and final live identity in
application and server closeout records. No live PASS is claimed in this preparation.
