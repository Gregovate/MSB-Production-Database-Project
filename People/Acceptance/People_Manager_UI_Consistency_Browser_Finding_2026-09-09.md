# People Manager UI Consistency Browser Finding — 2026-09-09

| Item | Value |
|---|---|
| Browser review disposition | **CHANGES REQUIRED — RETURN TO ENGINEERING** |
| Disposable-accepted database/backend SHA | `deaa9157282e59e8acd6a7da2a82fc9296e44f20` |
| Browser candidate with poor layout | `2de2d244ec7259e52f9d312587a86ef38c7f512f` |
| Corrected browser candidate | `de549757c8d040d34494304a08944f7f4b444b30` |
| Production mutation | NONE |
| Preview writes | disposable current-Production clone only |

## Operator finding

The People metadata workflows were present, but the browser layout did not match the established MSB application shell and was not acceptable for Production use.

Observed problems included:

- no Making Spirits Bright application logo / shared header treatment;
- no shared Dark / Light mode behavior;
- button styling inconsistent with FieldWiring / Controller / Setup applications;
- weak visual separation between major person-management sections;
- protected, non-editable system state occupying a large block in the middle of the editable workflow;
- excessive whitespace and poor use of desktop width;
- overall list/detail organization inconsistent with established MSB management screens.

## Correction

The People Manager presentation was rebuilt against the existing FieldWiring / Controller / Setup browser conventions:

- shared `site-header` / `brand` shell and official MSB blue logo;
- shared `msb-theme` Dark / Light preference behavior;
- same light/dark color tokens, card borders, button treatment, compact typography, and 1280px application width used by the existing management apps;
- sticky compact People list at left and clearly separated detail cards at right;
- Contact Information, Capabilities, Qualifications, Setup/Takedown roles, and reusable-task leadership are distinct cards;
- protected system state moved to a collapsed technical-details block at the bottom of the editable workflow;
- current database relationships also moved to a collapsed technical-details block;
- browser regression coverage now asserts the shared shell/theme and compact layout contract.

No `People/Database`, `People/Application/backend.py`, or `People/Application/people.js` behavior changed from the disposable-accepted SHA. The browser launcher independently verifies that invariant before starting the corrected candidate.

## Re-review

Run the governed browser review against exact corrected browser candidate:

```text
de549757c8d040d34494304a08944f7f4b444b30
```

The preview must still use the same current-Production disposable clone boundary and must not advance to Production until the operator accepts the corrected UI and workflows.
