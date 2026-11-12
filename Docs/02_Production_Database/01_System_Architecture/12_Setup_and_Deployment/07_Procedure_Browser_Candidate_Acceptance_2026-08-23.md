# Procedure Browser Candidate Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | **ACCEPTED ENGINEERING CHECKPOINT — local browser candidate, not deployed** |
| Branch | `feature/setup-takedown-procedures` |
| Shared DB context | `FieldWiring/Application/field_context_repository.py` |
| Shared filesystem resolver | `FieldWiring/Application/field_context_resolver.py` |
| Procedure orchestration | `Procedures/Application/procedure_context.py` |
| Procedure task adapter | `Procedures/Application/procedure_documents.py` |
| Procedure backend | `Procedures/Application/backend.py` |
| Procedure browser host | `Procedures/Application/browser.py` |
| Procedure client | `Procedures/Application/procedure.js` |

## Purpose

This checkpoint records acceptance of the first local Procedure browser candidate after the API/backend boundary was accepted.

The browser remains a thin presentation client over the already-tested Procedure API. It does not contain PostgreSQL relationship SQL, Stage/Scene filesystem resolution, Procedure task-folder discovery, or arbitrary Drive-path construction.

## Accepted browser behavior

The browser candidate supports:

- Setup / Takedown / Inspection task selection;
- current Display search through the task-neutral shared field-context repository;
- inventory-only/non-wired Displays as valid Procedure entry points;
- controlled Stage / Scene browsing;
- explicit Whole Stage selection;
- explicit Scene/Preview choice when the shared database layer returns multiple current candidates;
- current Procedure PDF links through the guarded HTTP API;
- supporting Procedure images through the guarded HTTP API;
- clear unavailable/missing-document states;
- permanent Display deep-link input such as `?display_id=<id>&task=Setup` for future Scan integration.

The browser does not widen FieldWiring search or import FieldWiring eligibility rules.

## Browser/API boundary

The JavaScript client uses only the tested Procedure API contract:

```text
/api/displays
/api/displays/<display_id>/context
/api/stages
/api/procedures
/api/procedure/document
/api/procedure/image
```

The asset route is constructed generically in the client as `api/procedure/${kind}` and is called only with the fixed kinds `document` and `image`.

The client does not receive or construct Google Drive paths. Asset links contain only current entry context, task, optional explicit Preview/Scene choice, and current filename. The backend re-resolves that context and serves only a filename rediscovered in the current direct task result.

## Automated acceptance evidence

Browser-shell suite:

```text
python -m pytest .\Procedures\Application\test_browser.py -q
.....                                                                                  [100%]
5 passed in 0.22s
```

Complete Procedure suite:

```text
python -m pytest .\Procedures\Application -q
.....................................                                                  [100%]
37 passed in 0.43s
```

Combined FieldWiring + Procedure regression:

```text
python -m pytest .\FieldWiring\Application .\Procedures\Application -q
...................................................................................... [ 85%]
...............                                                                        [100%]
101 passed in 2.83s
```

This confirms the browser candidate is regression-clean against the accepted shared Field Context and FieldWiring code on the Procedure branch.

## Important test correction during acceptance

The first browser test run produced one failure because the test expected literal strings:

```text
api/procedure/document
api/procedure/image
```

inside `procedure.js`.

The client intentionally builds those routes dynamically through:

```javascript
api/procedure/${kind}
```

with the fixed kinds `document` and `image`.

The test was corrected to verify the actual client contract rather than altering working browser behavior. No backend, resolver, SQL, filesystem, or file-serving behavior changed for that correction.

## What this checkpoint does not accept

This remains a local engineering acceptance only. It does not yet accept or deploy:

- a live Procedure service on `msb-prod-db`;
- a protected `my.sheboyganlights.org` Procedure route;
- Synology/reverse-proxy changes;
- systemd/runtime configuration;
- Scan-hub Procedure actions;
- production browser behavior on desktop/phone/tablet;
- print/offline Procedure acceptance;
- any new Procedure schema.

## Next engineering gate

The next gate is a real integration run using:

```text
current PostgreSQL
    +
current shared Display Folders filesystem
    +
Procedure browser/backend candidate
```

The first live candidate should prove at minimum:

1. a known current Setup example such as Church resolves to its current PDF;
2. an inventory-only/non-wired Display can enter Procedure context without being eligible for FieldWiring;
3. current PDF serving works through the guarded HTTP endpoint;
4. Archive and SourceDocs remain unreachable through normal Procedure endpoints;
5. multiple-context behavior is presented explicitly rather than guessed;
6. no production FieldWiring behavior changes as a side effect.

Server deployment/proxy/runtime work remains a separate later handoff after the live candidate is accepted.
