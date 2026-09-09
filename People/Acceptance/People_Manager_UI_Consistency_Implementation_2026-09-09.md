# People Manager UI Consistency Implementation — 2026-09-09

The operator browser review identified unacceptable inconsistency between People Manager and the established MSB browser applications.

Corrected browser candidate:

```text
de549757c8d040d34494304a08944f7f4b444b30
```

Disposable-accepted database/backend candidate remains:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

The browser launcher fails closed if `People/Database`, `People/Application/backend.py`, or `People/Application/people.js` differ between those SHAs. Therefore the re-review is limited to presentation/theme/static-regression changes while retaining the accepted database/API behavior.

Implemented presentation corrections:

- official MSB blue logo and shared `site-header` / `brand` shell;
- shared `msb-theme` Light / Dark mode behavior;
- FieldWiring / Controller color variables, card borders, buttons, spacing, and typography;
- 1280px application width and compact 390px sticky People list;
- separated detail cards for Contact Information, Capabilities, Qualifications, Setup/Takedown roles, and reusable-task leadership;
- protected system state moved from the middle of the edit workflow to a collapsed technical-details card at the bottom;
- current database relationships also collapsed at the bottom;
- regression coverage for the shared shell/theme and corrected layout.

No Production mutation is authorized by this implementation.
