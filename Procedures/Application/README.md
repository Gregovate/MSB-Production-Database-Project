# Procedure Application

**Status:** SECOND-CALLER READ-ONLY PROOF ACCEPTED — not deployed

This directory contains the Procedure subsystem application/business logic for Setup, Takedown, and Inspection field-document discovery.

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

The first adapter is:

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

For the first read-only proof:

- current Procedure documents are PDF files directly in the selected task folder;
- discovery is non-recursive;
- multiple direct PDFs are returned in deterministic case-insensitive name order;
- `Archive` is excluded from current-document discovery;
- `SourceDocs` is excluded from current-document discovery;
- PDFs inside `images` are not Procedure choices;
- supported task-local image assets are discovered separately from `images`;
- no neighboring Stage/Scene or parent-folder fallback is allowed;
- no per-document PostgreSQL registry is required for this proof.

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

## Acceptance Evidence — 2026-08-23

Procedure-specific regression:

```text
9 passed in 0.16s
```

Combined FieldWiring + Procedure regression:

```text
63 passed in 2.05s
```

The real Church fixture was then resolved through the same canonical shared resolver and the Procedure adapter:

```text
status:           AVAILABLE
scope_type:       STAGE
scope_root:       G:\Shared drives\Display Folders\15-Church-Bells-CH
procedures_root:  G:\Shared drives\Display Folders\15-Church-Bells-CH\Procedures
task_root:        G:\Shared drives\Display Folders\15-Church-Bells-CH\Procedures\Setup
document:         15 - Church-Nativity-Bells.pdf
size:             3296464 bytes
warnings:         none
```

Result:

```text
CHURCH PROCEDURE SECOND-CALLER PROOF: PASS
```

This accepts the read-only Procedure adapter boundary as the second caller of `field_context_resolver.resolve_structured_scope(...)`. It does **not** constitute browser, server-runtime, or production deployment acceptance.

## Tests

Procedure-specific tests are in:

```text
test_procedure_documents.py
```

From the repository root and active project virtual environment:

```powershell
python -m pytest .\Procedures\Application\test_procedure_documents.py -q
```

The tests verify:

- the adapter imports the exact canonical shared resolver callable;
- Stage-scope Setup discovery using only the Stage and `Procedures` markers;
- refusal to consume an unmarked `Procedures` root;
- direct-only PDF discovery;
- exclusion of `Archive`, `SourceDocs`, and image-folder PDFs;
- supporting image discovery;
- deterministic multiple-PDF ordering;
- explicit no-document and missing-task states;
- invalid task/path rejection; and
- Scene-scope Procedure discovery through the shared resolver.

## Not Implemented Yet

The accepted second-caller proof does **not** yet provide:

- a browser backend or protected public route;
- PostgreSQL/manual Display lookup orchestration for Procedures;
- PDF/image HTTP serving endpoints;
- field presentation pages;
- scan-hub integration;
- production deployment/runtime configuration.

Those are the next engineering layers and must preserve the accepted resolver/adapter boundary.

## Governing Documentation

Read first:

1. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
2. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
3. `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/02_Procedure_Second_Caller_Acceptance_2026-08-23.md`
4. `FieldWiring/Application/field_context_resolver.py`
5. `Docs/00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md`
6. `Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md`
