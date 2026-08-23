# Procedure Second-Caller Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | ACCEPTED ENGINEERING CHECKPOINT — read-only adapter, not deployed |
| Branch | `feature/setup-takedown-procedures` |
| Shared resolver | `FieldWiring/Application/field_context_resolver.py` |
| Canonical callable | `resolve_structured_scope(...)` |
| Procedure adapter | `Procedures/Application/procedure_documents.py` |

## Purpose

This checkpoint records acceptance of the first Procedure subsystem implementation as the second caller of the production-accepted shared Stage/Sub-stage/Scene resolver.

It does not authorize a second resolver implementation and does not change FieldWiring behavior.

## Accepted architecture

The accepted path is:

```text
Stage / Scene / Preview facts
        ↓
field_context_resolver.resolve_structured_scope(...)
        ↓
fixed marked Stage / Sub-stage / Scene scope_root
        ↓
Procedure adapter
        ↓
validate <scope_root>/Procedures marker
        ↓
select exact fixed task child
        ↓
Setup | Takedown | Inspection
        ↓
direct current-PDF discovery only
```

The Procedure adapter owns only Procedure-specific behavior after the shared resolver fixes the scope.

It does not copy or reimplement the resolver and does not use FieldWiring's `Wiring/BackgroundStage` or `Wiring/MusicalStage` adapter logic.

## Marker contract verified

The accepted Procedure marker pattern is:

```text
<Stage / Sub-stage / Scene root>   marker required
Procedures                         marker required
Setup                              no separate marker
Takedown                           no separate marker
Inspection                         no separate marker
Setup/images                       no separate marker
Takedown/images                    no separate marker
```

The `Procedures` marker guards the fixed child task branches.

`Archive` and `SourceDocs` are excluded by application behavior and folder role, not by additional child markers.

## Automated acceptance evidence

Procedure-only regression executed from the project virtual environment:

```text
python -m pytest .\Procedures\Application\test_procedure_documents.py -q
.........                                                                 [100%]
9 passed in 0.16s
```

Combined FieldWiring + Procedure regression:

```text
python -m pytest .\FieldWiring\Application .\Procedures\Application -q
...............................................................           [100%]
63 passed in 2.05s
```

This confirms the Procedure adapter tests pass and the accepted FieldWiring suite remains green with Procedures consuming the same shared resolver.

## Real Church fixture acceptance

The first real filesystem proof used:

```text
G:\Shared drives\Display Folders\15-Church-Bells-CH
```

Observed required markers:

```text
Stage marker:      True
Procedures marker: True
```

Observed current Setup PDF:

```text
G:\Shared drives\Display Folders\15-Church-Bells-CH\Procedures\Setup\15 - Church-Nativity-Bells.pdf
```

Observed size:

```text
3,296,464 bytes
```

The actual Procedure second-caller execution returned:

```text
status:           AVAILABLE
scope_type:       STAGE
scope_root:       G:\Shared drives\Display Folders\15-Church-Bells-CH
procedures_root:  G:\Shared drives\Display Folders\15-Church-Bells-CH\Procedures
task_root:        G:\Shared drives\Display Folders\15-Church-Bells-CH\Procedures\Setup
documents:
  - 15 - Church-Nativity-Bells.pdf | 3296464 bytes
images:
warnings:

CHURCH PROCEDURE SECOND-CALLER PROOF: PASS
```

No warnings were produced.

## Accepted behaviors

The checkpoint accepts these Procedure adapter behaviors:

- consumes the exact canonical shared resolver callable;
- treats the returned structured `scope_root` as fixed;
- validates the marked `Procedures` subsystem root;
- selects only exact fixed task names: `Setup`, `Takedown`, `Inspection`;
- requires no marker on those task folders;
- discovers only direct PDFs as current Procedure documents;
- excludes `Archive` from current-document discovery;
- excludes `SourceDocs` from current-document discovery;
- treats `images` as supporting assets rather than Procedure choices;
- returns multiple direct current PDFs deterministically when present;
- returns explicit missing/unavailable states rather than searching neighboring scopes;
- rejects arbitrary task/path input.

## Not yet accepted

This checkpoint does not yet accept or deploy:

- a Procedure browser/backend service;
- manual Display/Stage/Scene lookup orchestration;
- PDF/image HTTP serving;
- field presentation pages;
- protected `my.sheboyganlights.org` routing;
- Scan-hub Procedure actions;
- Procedure production runtime configuration;
- new PostgreSQL Procedure schema or per-document registry.

## Next engineering gate

The next implementation layer should be the minimal browser/backend integration around this already-accepted adapter.

That work must preserve:

```text
shared resolver owns structured scope
Procedure adapter owns Procedures/<task>
browser/backend owns lookup orchestration, HTTP serving, and presentation
```

Do not move Stage/Sub-stage/Scene resolution into the browser/backend layer and do not add a second resolver.

## Governing documents

- `00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
- `01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
- `Procedures/Application/README.md`
- `FieldWiring/Application/field_context_resolver.py`
