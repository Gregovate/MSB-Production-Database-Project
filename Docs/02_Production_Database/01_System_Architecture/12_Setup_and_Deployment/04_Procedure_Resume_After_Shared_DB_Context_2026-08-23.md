# Procedure Resume Checkpoint After Shared Database Context — 2026-08-23

Status: **READY TO RESUME ENGINEERING**

The Procedure subsystem pause is cleared.

Production-accepted shared prerequisites now include:

```text
FieldWiring/Application/field_context_repository.py
FieldWiring/Application/field_context_resolver.py
```

Production FieldWiring commit used to accept the shared database-context layer:

```text
decb4eb7030a35bab3fc2e778fcf271463044044
```

Acceptance evidence:

```text
64 passed in production checkout
fieldwiring.service active
Display 807 shared context PASS
Display 807 FieldWiring task separation PASS
Display 312 FieldWiring post-deploy PASS
```

When `feature/setup-takedown-procedures` resumes, first refresh it against current `main`. Preserve its accepted `procedure_documents.py` second-caller work, but route permanent Display/Stage/Scene/Preview database facts through `field_context_repository.py` rather than FieldWiring's task-filtered `repository.py` or copied SQL.

Required chain:

```text
permanent Display / manual Stage/Scene selection
    -> shared field_context_repository
    -> shared field_context_resolver.resolve_structured_scope(...)
    -> fixed scope_root
    -> Procedure task adapter
    -> Procedures/Setup | Procedures/Takedown | Procedures/Inspection
```

FieldWiring-specific wiring eligibility remains downstream and must not be imported into Procedure identity/context resolution.
