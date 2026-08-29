# Procedure Application

**Status:** PRODUCTION-OPERATIONAL — canonical Stage/Sub-stage Setup resolution accepted 2026-08-28

This directory contains the Procedure subsystem application/business logic for Setup, Takedown, and Inspection field-document discovery.

Current protected production route:

```text
https://my.sheboyganlights.org/procedures/
```

Current accepted Production Database application commit:

```text
718fe0d2ccdee0c99225680ee2048e9d29a767e8
```

Immediate application rollback point for the current shared checkout:

```text
d0acdfb7d781ab7cc43edfd348dc7eb6285fd358
```

Server/runtime authority is maintained in `Gregovate/MSB-Server-Management`, especially `docs/server/Procedure_Production_Runtime.md`, `docs/server/FieldWiring_Production_Runtime.md`, and `docs/server/Setup_Resolver_Canonical_Root_Production_Acceptance_2026-08-28.md`.

## Shared Resolver Boundary

The Procedure subsystem does **not** implement a second Stage/Sub-stage/Scene filesystem resolver.

It consumes the production-accepted canonical structured-scope implementation directly:

```python
from FieldWiring.Application.field_context_resolver import resolve_structured_scope
```

Canonical source:

```text
FieldWiring/Application/field_context_resolver.py
```

The shared hierarchy owns Stage/Sub-stage/Scene presentation identity and canonical owner-path evidence. The shared structured-scope resolver validates the selected physical root. Procedure code does not perform a second filename-, path-, Display-, Stage-, or Scene-resolution pass.

For controlled Stage/Sub-stage browse, Procedure identifies the selected owner by permanent `stage_id`, consumes the shared hierarchy's `scope_path_evidence`, and then delegates to `resolve_structured_scope()` for physical validation. It does not reconstruct a directory from `stage_key + stage_name` and does not perform a loose `NNa-*` filesystem search.

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

The first observed Google Drive fixture was:

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

## Production Acceptance — 2026-08-28 Canonical Setup Root

Production Database PR `#91` repaired a whole-Sub-stage Procedure lookup failure where stale persisted Stage path evidence could end in:

```text
07a-Who Forest
```

while current LOR path evidence and the established Google Drive hierarchy identify the real Sub-stage as:

```text
07a-Who Forest-WF
```

`07a-Who Forest-WF` remains a **Sub-stage**, not a Scene. Same-prefix Scene names are not used as loose Sub-stage filesystem matches.

The merged and deployed application commit is:

```text
718fe0d2ccdee0c99225680ee2048e9d29a767e8
```

Detached production-environment regression before live mutation:

```text
161 passed in 2.47s
```

Live shared hierarchy acceptance:

```text
Stage 07:          07-Whoville-WV
Sub-stage 07a:     07a-Who Forest-WF
07a scope type:    SUBSTAGE
07a path evidence: G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF
```

FieldWiring and Procedure returned identical 07a owner identity and canonical path evidence.

Live Stage 07 Setup root:

```text
/mnt/msb-display-folders/07-Whoville-WV/Procedures/Setup
```

Current direct PDFs, matched exactly by the Procedure API:

```text
07 - Whoville.pdf
07b - Mount Crumpit .pdf
```

Live Sub-stage 07a Setup root:

```text
/mnt/msb-display-folders/07-Whoville-WV/07a-Who Forest-WF/Procedures/Setup
```

Current direct PDF, matched exactly by the Procedure API:

```text
07a - Who Forest Trees Setup Instructions.pdf
```

Final result:

```text
FILESYSTEM / API AGREEMENT: PASS
SHARED ROOT AGREEMENT: PASS
FINAL PRODUCTION ACCEPTANCE: PASS
DEPLOYMENT ACCEPTED
```

The first live filesystem validation attempt was deliberately not accepted because it enumerated the mounted task folder as `msbadmin`, which lacks the `msb-docs-read` traversal rights of the `fieldwiring` runtime account. A wrapper control-flow flaw also allowed a misleading success message after that failed assertion. Final acceptance was rerun under the correct runtime account with strict failure semantics and passed.

Detailed server/runtime evidence is in `Gregovate/MSB-Server-Management: docs/server/Setup_Resolver_Canonical_Root_Production_Acceptance_2026-08-28.md`.

## Historical Production Acceptance — 2026-08-23 Initial Procedure Deployment

The original Procedure production deployment used application commit:

```text
9a19639ae0af6cd5bbaf162fe236e14c1b88722d
```

Original combined FieldWiring + Procedure regression:

```text
150 passed in 2.16s
```

The original live gate established the Procedure service, Stage browse, Stage 15 Setup document resolution, and the protected public route.

Internal production service remains:

```text
msb-procedures.service = active
192.168.5.9:8792
{"data_mode":"postgres","status":"ok","version":"V0.1.0"}
```

Protected public route remains:

```text
GET /procedures/api/health -> HTTP 200 / postgres / ok / V0.1.0
HEAD /procedures/          -> HTTP/2 200
HEAD /procedures           -> HTTP/2 301 -> /procedures/
```

## Display Scan Entry Contract

The Procedure page already owns operator task selection:

```text
What do you need to do?
    Setup
    Takedown
    Inspection
```

Its existing deep-link behavior accepts permanent Display identity:

```text
/procedures/?display_id=<permanent display_id>
```

and optionally a task parameter when another approved caller has a reason to preselect one:

```text
/procedures/?display_id=<permanent display_id>&task=Setup
/procedures/?display_id=<permanent display_id>&task=Takedown
/procedures/?display_id=<permanent display_id>&task=Inspection
```

For the current Display Scan integration, the agreed UX is **one `Procedures` button** on the Display scan hub. It passes only `display_id` and leaves Setup/Takedown/Inspection selection inside this existing Procedure page. Scan does not duplicate these three task buttons and does not call the Procedure API merely to decide whether the button should render.

Source candidate branch and implementation commit recorded for that separate Scan integration work:

```text
agent/procedure-scan-action
333f7c20a26e8ed2a0460ddbf309c167bffa2992
```

The standalone Procedure resolver behavior documented here is independent of that Scan link.

## Tests

Procedure-specific and shared integration tests live under:

```text
Procedures/Application/test_*.py
```

Shared Field Context changes must be accepted together with the relevant FieldWiring regression suite so the two applications cannot silently diverge on Stage/Sub-stage/Scene scope.

## Remaining Work

The standalone Procedure field-access application is production-operational. Remaining work is separate follow-on scope, including:

- continue human Procedure-document authoring/alignment/archive work in Google `Display Folders`;
- complete any broader PC/phone/tablet operator acceptance needed for the 2026 field workflow; and
- engineer scheduling, pick/load, forklift, Container/Location, and other Setup/Deployment operational workflows separately from Procedure document lookup.

Do not create a second field-context resolver, Procedure-only Google hierarchy, generic document registry, or new Procedure database schema unless a later demonstrated workflow requires it.

## Governing Documentation

Read first:

1. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
2. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/10_Setup_Resolver_Canonical_Documentation_Root_2026-08-28.md`
3. `Docs/00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md`
4. `Docs/00_Project_Overview/06-Operator_UI_Message_Contract.md`
5. `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md`
6. `FieldWiring/Application/field_context_hierarchy.py`
7. `FieldWiring/Application/field_context_resolver.py`
8. `FieldWiring/Application/field_context_repository.py`
9. `Gregovate/MSB-Server-Management: docs/server/Procedure_Production_Runtime.md`
10. `Gregovate/MSB-Server-Management: docs/server/FieldWiring_Production_Runtime.md`
11. `Gregovate/MSB-Server-Management: docs/server/Setup_Resolver_Canonical_Root_Production_Acceptance_2026-08-28.md`

Historical dated Procedure acceptance documents remain valid as records of the engineering stages they describe; statements that deployment had not yet occurred apply to those historical stages, not the current production state.
