# Procedure Subsystem — Shared Resolver Extraction Handoff — 2026-08-22

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING HANDOFF ADDENDUM — shared resolver architecture accepted |
| Parent handoff | `00_Procedure_System_Field_Context_Handoff_2026-08-22.md` |
| Shared resolver branch | `agent/shared-field-context-resolver-extraction` |
| Code-regression-tested commit | `b7fcd0333f2cb023026643c292b1d615cf5ceb6a` |
| Live-equivalence-tested branch head | `dcedc36c8d3ad0955fa793e8817c4a88d3535014` |

## Why this addendum exists

The parent Procedure handoff correctly established that Procedures must reuse FieldWiring's proven Stage/Sub-stage/Scene resolver, but at that time the proven logic was still embedded inside:

```text
FieldWiring/Application/wiring_images.py
```

That location statement is now superseded.

This addendum does not change the resolver algorithm or the Procedure task rules already established by the parent handoff.

## Canonical resolver source

The proven structured-scope implementation has now been extracted to:

```text
FieldWiring/Application/field_context_resolver.py
```

Canonical callable:

```python
resolve_structured_scope(...)
```

The module is task-neutral. It remains physically beside FieldWiring so the existing production Python/systemd deployment model does not need to change merely for packaging. The Procedure implementation must consume this same canonical implementation as its second caller; it must not copy the resolver into a Procedure-owned file.

## What Procedures receive from the shared resolver

The shared resolver fixes the current marked structured root from existing Stage/Scene/Preview facts and controlled filesystem evidence.

It preserves the proven behavior for:

- Windows-to-Linux Display Folders path translation;
- marked Stage/Scene roots;
- stale path recovery;
- canonical Scene matching;
- bounded Scene search;
- ambiguity rejection;
- `SourceDocs` protection;
- conservative fallback behavior;
- visible warnings rather than unsafe guessing.

The Procedure subsystem must treat the returned `scope_root` as fixed before selecting Procedure content.

## What Procedures own after resolution

After the shared resolver returns the structured context, the Procedure adapter owns only Procedure-specific work:

```text
<scope_root>/Procedures/Setup
<scope_root>/Procedures/Takedown
<scope_root>/Procedures/Inspection
```

The Procedure adapter owns:

- Procedure/task marker validation;
- direct current-PDF discovery;
- supporting `images` behavior;
- exclusion of `Archive` from normal field presentation;
- exclusion of `SourceDocs` from normal field presentation;
- missing-document states;
- multiple-current-document presentation when allowed;
- Procedure browser presentation and later scan actions.

It must not re-resolve Stage/Scene from filenames or independently crawl neighboring hierarchy.

## Do not copy FieldWiring's task adapter

The Procedure subsystem reuses the structured resolver, **not** the Wiring-specific adapter.

Do not copy or call FieldWiring rules that select:

```text
Wiring/BackgroundStage
Wiring/MusicalStage
```

Do not apply FieldWiring image-marker rules to Procedure folders.

The intended architecture is:

```text
                    shared structured resolver
                              |
                fixed Stage/Sub-stage/Scene root
                       /                   \
                      /                     \
          FieldWiring adapter           Procedure adapter
          Wiring/<context>              Procedures/<task>
```

## Acceptance evidence

The extracted resolver and FieldWiring adapter were tested together from an isolated server worktree.

Complete FieldWiring regression result:

```text
54 passed in 1.01s
```

A transient candidate FieldWiring service was then run from the resolver branch on `127.0.0.1:8791` while the unchanged production service remained on `192.168.5.9:8790`.

Both used the same production read-only PostgreSQL configuration and mounted Google `Display Folders` tree.

For live Display `312`, production and candidate matched on:

- `scope_type`;
- `scope_root`;
- warning text;
- Wiring image list;
- relative image path; and
- image URL.

Result:

```text
RESOLVER EQUIVALENCE: PASS
```

The shared resolver extraction is therefore accepted as the common architecture boundary.

## Procedure implementation gate

The prior gate preventing substantive Procedure resolver work is now cleared for engineering/development.

Procedure engineering should begin from:

1. this addendum;
2. `00_Procedure_System_Field_Context_Handoff_2026-08-22.md`;
3. the canonical `field_context_resolver.py` implementation;
4. the Procedure marker/current-document rules already defined in the parent handoff.

The first Procedure proof must demonstrate a **second caller of the same resolver**, not a second implementation of it.

Production deployment of the FieldWiring extraction remains a separate server-management step. Procedure production deployment must not substitute a copied resolver merely because that server update is still pending.

## Related FieldWiring acceptance record

See:

```text
../09_Wiring_System/FieldWiring_Shared_Structured_Scope_Resolver_Extraction_2026-08-22.md
```
