# Controller V0.4.0 Disposable Browser Operator Acceptance — 2026-09-03

| Item | Value |
|---|---|
| Status | OPERATOR ACCEPTED IN DISPOSABLE PRODUCTION-CLONE PREVIEW |
| Issue | #110 |
| Application version | `V0.4.0` |
| Accepted application candidate | `63be47f40be78f608416935ed0583287da9d90e6` |
| Preview identity | `gliebig@sheboyganlights.org` / Administrator context |
| Preview database | Disposable clone of current production PostgreSQL |
| Production mutation | None from browser-preview acceptance |

## Acceptance statement

The operator reviewed the Controller Inventory `V0.4.0` browser candidate in the disposable production-clone preview and accepted the current design for this version.

The accepted UI slice is:

- Controller planning screens;
- Controller Add/Edit maintenance screens;
- grouped Controller maintenance form design;
- current programmed-configuration maintenance presentation;
- firmware maintenance/verification presentation;
- physical Controller state maintenance presentation;
- contextual field help using small `?` controls for non-obvious fields;
- clarified **Physically Attached to Display** wording/help, distinct from logical Controller-to-Display assignment state;
- unsaved-change protection on Controller maintenance forms;
- distinct Print Label action treatment from the primary blue Save Controller action;
- single Add Controller action after correction of the duplicate-script-load defect.

The operator described the result as acceptable for the current version and did not request a redesign of the planning, editing/maintenance, or contextual-help experience.

## Version authority

`FieldWiring/Application/backend.py` identifies this Controller management application slice as:

```text
V0.4.0
```

The exact application candidate reviewed and accepted is:

```text
63be47f40be78f608416935ed0583287da9d90e6
```

Later commits that only repair the disposable-preview harness do not change the accepted application candidate unless application files themselves change and are re-accepted.

## Preserved design decisions

Do not regress the following accepted behavior without new operator review:

- Controller editing stays browser-native rather than moving back to Directus relationship editing;
- Save Controller remains the primary blue database-save action;
- Print Label remains visually distinct from Save Controller;
- Controller-to-Display assignment state is separate from the physical `is_display_attached` fact;
- `is_display_attached` is presented as **Physically Attached to Display**;
- non-obvious fields use concise in-context `?` help rather than permanent explanatory paragraphs;
- closing a dirty maintenance form warns before discarding unsaved changes;
- planning and maintenance forms continue to use governed lookup values rather than raw foreign-key IDs;
- PostgreSQL remains final validation/audit authority and `fieldwiring_app` receives no broad Controller table DML.

## Remaining work is not a rejection of V0.4.0 UX

The following remain separate follow-up workstreams and do not block this operator acceptance of the `V0.4.0` planning/maintenance/help design:

- offline/printable Controller reports for firmware upgrades, verification, Stage/Display field lists, and exception work;
- physical Controller label template/profile and LabelPrintService Controller routing;
- final Production Crew / Read Only capability acceptance;
- production deployment of the accepted application candidate through the governed deployment gate;
- final plain-English operator procedures after the deployed UI is stable.

Production deployment is a separate controlled action. This preview acceptance does not itself authorize or perform a production deployment.
