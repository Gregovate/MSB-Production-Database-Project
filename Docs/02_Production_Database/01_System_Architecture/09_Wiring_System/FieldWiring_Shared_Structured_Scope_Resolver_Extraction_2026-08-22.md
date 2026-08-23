# FieldWiring Shared Structured-Scope Resolver Extraction — 2026-08-22

| Document control | Value |
|---|---|
| Status | ARCHITECTURE ACCEPTED — production deployment pending |
| Branch | `agent/shared-field-context-resolver-extraction` |
| Code-regression-tested commit | `b7fcd0333f2cb023026643c292b1d615cf5ceb6a` |
| Live-equivalence-tested branch head | `dcedc36c8d3ad0955fa793e8817c4a88d3535014` |
| Production baseline during test | `c71d0e50de9917a384ec8cfc836202e7aa2885db` |
| Primary caller | FieldWiring |
| Planned second caller | Procedure subsystem |

## Purpose

The proven structured Stage/Sub-stage/Scene filesystem resolver was originally embedded in `FieldWiring/Application/wiring_images.py`. That made future field-document applications vulnerable to implementing competing Display/Stage/Scene hierarchy logic.

This change finishes the original architecture boundary by extracting that proven resolver into one task-neutral component while preserving FieldWiring behavior.

## Canonical Shared Component

The canonical implementation is now:

```text
FieldWiring/Application/field_context_resolver.py
```

The module is task-neutral even though it remains physically co-located with the current first caller. This location intentionally avoids introducing a new Python package, `PYTHONPATH`, systemd, or deployment-layout change merely for folder organization.

Future callers must consume this same implementation rather than copy its algorithm into a Procedure-, Testing-, or other task-specific module. A broader packaging move, if ever needed, is a separate deployment decision and must not fork the resolver.

## Shared Resolver Owns

`field_context_resolver.py` owns only structured hierarchy resolution:

- Windows `G:\Shared drives\Display Folders\...` evidence translation to the configured server-visible root;
- marked Stage root validation;
- stale Stage-path recovery from safe exact path evidence;
- canonical current Scene-name matching;
- bounded Scene matching;
- marker validation for candidate structured roots;
- ambiguity rejection;
- `SourceDocs` truncation/protection;
- conservative Stage fallback when no distinct Scene folder exists;
- existing warning behavior, with caller-supplied legacy wording where needed.

The resolver answers:

> Which current marked Stage/Sub-stage/Scene root owns this field context?

It does not choose Wiring, Procedure, Setup, Takedown, Inspection, or other task content.

## FieldWiring Still Owns

`FieldWiring/Application/wiring_images.py` remains the FieldWiring adapter and still owns:

- `Musical` -> `Wiring/MusicalStage` selection;
- non-Musical/background -> `Wiring/BackgroundStage` selection;
- marked `Wiring` source validation;
- direct wiring-image enumeration;
- same-scope marked `PreviewBackground` image enumeration;
- FieldWiring image payload/URL construction;
- safe image delivery;
- hard rejection of `SourceDocs` image requests;
- FieldWiring-specific warning wording.

No parent Wiring-image fallback was added. No Procedure content rule was added to FieldWiring.

## Important Preserved Behavior

During direct resolver testing, one initially surprising legacy classification was confirmed and intentionally preserved.

For a Scene name such as:

```text
15-Church-CH
```

canonical matching also includes:

```text
15-Church
```

If path evidence enters `SourceDocs`, traversal is stopped before `SourceDocs`. When the resolver subsequently walks the safe ancestor chain, the marked Stage root `15-Church` may therefore be returned with the existing `SCENE` scope classification.

This is existing production resolver behavior. The returned path remains the marked Stage root and no `SourceDocs` content is traversed or presented. Changing that classification would be a resolver redesign and is outside this extraction.

## Regression Gate

The candidate was tested from a detached server worktree:

```text
/var/tmp/fieldwiring-resolver-test
```

The production checkout remained untouched at:

```text
/opt/fieldwiring
```

The first full run produced:

```text
53 passed, 1 failed
```

The sole failure was a newly added test that incorrectly expected the legacy canonical-name case above to become `STAGE`. A direct diagnostic confirmed the extracted module matched the pre-existing resolver behavior. The test was corrected; the implementation was not redesigned.

Final full regression result at `b7fcd0333f2cb023026643c292b1d615cf5ceb6a`:

```text
54 passed in 1.01s
```

## Live Production-Data Equivalence Gate

After the complete regression suite passed, the branch was launched from the detached worktree as a transient candidate service on:

```text
127.0.0.1:8791
```

The existing production FieldWiring service remained unchanged on:

```text
192.168.5.9:8790
```

Both services used the same production read-only PostgreSQL configuration and the same mounted read-only Google `Display Folders` filesystem.

Health matched exactly:

```text
{"data_mode":"postgres","status":"ok","version":"V0.2.0"}
```

A live `BridgeBell` lookup selected permanent Display:

```text
display_id = 312
```

Production and candidate then returned identical resolver-specific values:

```text
scope_type = STAGE
scope_root = /mnt/msb-display-folders/15-Church-Bells-CH
warnings = [BackgroundFile points directly into the current Stage Wiring branch; the marked Stage root is the FieldWiring documentation scope.]
wiring image = RGB Plus Prop Stage 15 Church-Tagged.jpg
relative path = 15-Church-Bells-CH/Wiring/MusicalStage/RGB Plus Prop Stage 15 Church-Tagged.jpg
```

Result:

```text
RESOLVER EQUIVALENCE: PASS
```

The transient candidate service was stopped automatically after the comparison. Production remained on its existing checkout throughout the test.

## Acceptance Decision

The shared structured-scope resolver extraction is **architecture accepted** because all required behavior-preservation gates passed:

1. one task-neutral structured-scope implementation exists;
2. FieldWiring delegates structured hierarchy resolution to it;
3. Wiring branch/image logic remains outside it;
4. existing warning behavior remains intact;
5. `SourceDocs` remains protected;
6. bounded matching and ambiguity rejection remain intact;
7. the complete FieldWiring regression suite passes: `54 passed`;
8. live production-data resolver output matches the current production service;
9. Procedure implementation is directed to call this same component rather than copy or redesign it.

Production deployment of the extracted module is a separate server-change step and is not represented as complete by this document.

## Production Deployment Caution

At acceptance-test time, the live `/opt/fieldwiring` checkout was still at:

```text
c71d0e50de9917a384ec8cfc836202e7aa2885db
```

The resolver branch is based on newer current `main` history. Therefore deployment must not be described as a resolver-only one-commit update. The full repository gap must be reviewed explicitly before moving the live checkout and restarting FieldWiring.

## Procedure Handoff

The Procedure subsystem may now consume the accepted shared resolver as its second caller in engineering/development work.

The intended flow is:

```text
Display / Stage / Scene context
        -> field_context_resolver.resolve_structured_scope(...)
        -> fixed structured scope_root
        -> Procedure adapter
        -> Procedures/Setup | Procedures/Takedown | Procedures/Inspection
```

Procedure marker validation, PDF discovery, `images`, `Archive`, and task-specific `SourceDocs` exclusions remain Procedure-adapter responsibilities.

Procedure production deployment must not fork or substitute another resolver implementation.

## Related Documents

- `FieldWiring_Drive_Context_Resolver_Engineering_Design.md`
- `../12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
- `../12_Setup_and_Deployment/01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
- `../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md`
