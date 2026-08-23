# Procedure Application

**Status:** PRODUCTION-OPERATIONAL — read-only Procedure field access accepted 2026-08-23

This directory contains the Procedure subsystem application/business logic for Setup, Takedown, and Inspection field-document discovery.

Current protected production route:

```text
https://my.sheboyganlights.org/procedures/
```

Current accepted Production Database application commit:

```text
9a19639ae0af6cd5bbaf162fe236e14c1b88722d
```

Server/runtime authority is maintained in `Gregovate/MSB-Server-Management`, especially `docs/server/Procedure_Production_Runtime.md` and `docs/server/Synology_Protected_Application_Reverse_Proxy.md`.

## Shared Resolver Boundary

The Procedure subsystem does **not** implement Stage/Sub-stage/Scene resolution.

It consumes the production-accepted canonical implementation directly:

```python
from FieldWiring.Application.field_context_resolver import resolve_structured_scope
```

Canonical source:

```text
FieldWiring/Application/field_context_resolver.py
```

The shared resolver owns the current structured field context. Procedure code treats its returned `scope_root` as fixed and does not perform a second filename-, path-, Display-, Stage-, or Scene-resolution pass.

## Procedure Adapter Boundary

The Procedure adapter is:

```text
procedure_documents.py
```

It owns only:

```text
<scope_root>/Procedures/Setup
<scope_root>/Procedures/Takedown
<scope_root>/Procedures/Inspection
```

The Procedure marker contract is the same subsystem-root pattern used by FieldWiring:

```text
<Stage / Sub-stage / Scene root>   marker required
Procedures                         marker required
Inspection                         no separate marker
Setup                              no separate marker
Setup/images                       no separate marker
Takedown                           no separate marker
Takedown/images                    no separate marker
```

The fixed task names are application-controlled. User input cannot become an arbitrary filesystem path.

## Current Document Discovery

- current Procedure documents are PDF files directly in the selected task folder;
- discovery is non-recursive;
- multiple direct PDFs are returned in deterministic case-insensitive name order;
- `Archive` is excluded from current-document discovery;
- `SourceDocs` is excluded from current-document discovery;
- PDFs inside `images` are not Procedure choices;
- supported task-local image assets are discovered separately from `images`;
- no neighboring Stage/Scene or parent-folder fallback is allowed; and
- no per-document PostgreSQL registry is required for current read-only field presentation.

The adapter returns explicit states:

```text
AVAILABLE
NO_CURRENT_DOCUMENTS
TASK_UNAVAILABLE
PROCEDURES_UNAVAILABLE
UNRESOLVED_SCOPE
```

## First Real Fixture

The first observed Google Drive fixture is:

```text
G:\Shared drives\Display Folders\15-Church-Bells-CH
    marker
    Procedures\
        marker
        Setup\
            15 - Church-Nativity-Bells.pdf
```

Observed PDF size:

```text
3,296,464 bytes
```

No marker is required inside `Setup` for this fixture to be valid.

## Production Acceptance — 2026-08-23

Final combined FieldWiring + Procedure regression before deployment:

```text
150 passed in 2.16s
```

Live production-data gate:

```text
/api/stages HTTP 200 in 0.0136 seconds
Top-level Stages: 30
Stage 03 Scenes: ['03-Mega Cube']
Stage 07 Sub-stages: ['07a-Who Forest']
Stage 21 Scenes: ['21-SlidingPenguins', '21-SnowballBears']
Stage 15 Setup status: AVAILABLE
Stage 15 Setup document: 15 - Church-Nativity-Bells.pdf
```

Internal production service:

```text
msb-procedures.service = active
192.168.5.9:8792
{"data_mode":"postgres","status":"ok","version":"V0.1.0"}
```

Protected public route acceptance through Synology:

```text
GET /procedures/api/health -> HTTP 200 / postgres / ok / V0.1.0
HEAD /procedures/          -> HTTP/2 200
HEAD /procedures           -> HTTP/2 301 -> /procedures/
```

Result:

```text
PROCEDURE PRODUCTION DEPLOYMENT: ACCEPTED
```

## Tests

Procedure-specific and shared integration tests live under:

```text
Procedures/Application/test_*.py
```

The final production candidate was accepted together with the complete FieldWiring regression suite so changes to the shared Field Context contract cannot silently diverge between the two applications.

## Remaining Work

The standalone Procedure field-access application is production-operational. Remaining work is separate follow-on scope, including:

- add Procedure actions to the existing Display Scan hub using permanent `display_id` without changing physical QR identity;
- continue human Procedure-document authoring/alignment/archive work in Google `Display Folders`;
- complete any broader PC/phone/tablet operator acceptance needed for the 2026 field workflow; and
- engineer scheduling, pick/load, forklift, Container/Location, and other Setup/Deployment operational workflows separately from Procedure document lookup.

Do not create a second field-context resolver, Procedure-only Google hierarchy, generic document registry, or new Procedure database schema unless a later demonstrated workflow requires it.

## Governing Documentation

Read first:

1. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
2. `Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md`
3. `Docs/00_Project_Overview/06-Operator_UI_Message_Contract.md`
4. `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md`
5. `FieldWiring/Application/field_context_resolver.py`
6. `FieldWiring/Application/field_context_repository.py`
7. `Gregovate/MSB-Server-Management: docs/server/Procedure_Production_Runtime.md`
8. `Gregovate/MSB-Server-Management: docs/server/Synology_Protected_Application_Reverse_Proxy.md`

Historical dated Procedure acceptance documents in `12_Setup_and_Deployment/` remain valid as records of the engineering stages they describe; when they say deployment had not yet occurred, that statement applies to that historical acceptance stage, not the current production state.
