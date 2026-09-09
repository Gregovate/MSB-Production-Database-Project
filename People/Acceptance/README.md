# People Manager Acceptance

People Manager must be proven against a disposable database restored from the current Production database before any Production mutation.

## Governing Runtime Authority

Disposable PostgreSQL orchestration is owned by:

```text
Gregovate/MSB-Server-Management
docs/server/PostgreSQL_Disposable_Acceptance_Standard.md
```

User-facing browser review is governed by:

```text
Gregovate/MSB-Server-Management
docs/server/Pre_Production_Browser_Review_Runbook.md
```

Production deployment, if later explicitly approved, is separately governed by:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
```

The files in this `People/Acceptance/` folder provide only People-specific candidate migrations, assertions, browser-review entry/cleanup pieces, and retained evidence. Do not invent alternate SSH, Docker, PostgreSQL clone, readiness, preview-process, cleanup, or Production deployment behavior here.

## Current accepted database/backend gate

Exact People metadata application/database candidate accepted by the 2026-09-09 current-Production disposable-clone gate:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Server report:

```text
/tmp/MSB_People_Manager_Disposable_20260909-183640.txt
```

Production `ref.person` fingerprint remained unchanged:

```text
47f494107952a84f30a406374b8d01d7
```

Accepted clone behavior includes:

- least-privilege People metadata boundary;
- person create + reserved MSB email;
- same-person deactivate/reactivate;
- capability catalog + person capability;
- formal qualification dates/evidence;
- Setup/Takedown participation and eligibility roles;
- existing reusable-task leadership visible but not directly writable by `people_app`;
- metadata actor/audit stamping; and
- no normal People delete function.

## Current browser-review candidate

Browser review found the initial People presentation inconsistent with the established MSB browser applications. That finding is retained in:

```text
People_Manager_UI_Consistency_Browser_Finding_2026-09-09.md
```

The corrected browser candidate is:

```text
de549757c8d040d34494304a08944f7f4b444b30
```

The browser launcher independently proves that `People/Database`, `People/Application/backend.py`, and `People/Application/people.js` are unchanged from the disposable-accepted SHA before it starts this presentation-only correction.

The corrected UI now follows the established MSB application conventions:

- official Making Spirits Bright blue logo and shared application header;
- shared `msb-theme` Dark / Light behavior;
- FieldWiring / Controller style color tokens, cards, borders, buttons, and compact typography;
- sticky compact People list at left and separated detail cards at right;
- Contact, Capabilities, Qualifications, Setup/Takedown roles, and reusable-task leadership separated into distinct cards;
- protected system state moved to a collapsed technical-details block at the bottom; and
- current database relationships also collapsed as technical details rather than occupying the primary edit flow.

Run browser review from a clean Windows worktree:

```powershell
git pull
.\People\Acceptance\run_people_manager_browser_preview.ps1 -PreviewPort 8795
```

`8795` is only an example operator-selected candidate port; the runner verifies it is unused. Production Setup permanently owns `8794`, which must never be used or cleaned as a preview port.

Do not open the browser until the runner prints:

```text
BROWSER REVIEW READY
```

Then open the localhost URL printed by the runner.

Minimum browser review now includes:

1. shared MSB logo/header/button treatment and Dark / Light mode;
2. compact list/detail layout with clear card separation and no large protected-state block in the middle of editable content;
3. search and Include inactive;
4. person create/edit/deactivate/reactivate and reserved email;
5. capability catalog + assignment + notes + deactivate/reactivate;
6. qualification catalog + completed/valid/expiry dates + role + certificate + evidence + notes + active state;
7. Setup Volunteer, Takedown Volunteer, Captain Candidate, and Advisor Candidate persistence;
8. read-only reusable-task Captain/Alternate/Advisor visibility;
9. protected Directus-linked identity behavior;
10. duplicate and MSB-email collision review; and
11. no person delete or merge action in this candidate.

If the preview is interrupted, use:

```powershell
.\People\Acceptance\run_people_manager_browser_preview_cleanup.ps1 -PreviewPort 8795
```

Never pass a Production listener such as `8794` to cleanup.

The browser-review disposition must be one of:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
CHANGES REQUIRED — RETURN TO ENGINEERING
REVIEW INCOMPLETE — NO PRODUCTION APPROVAL
```

A browser-review PASS still does not authorize Production deployment.
