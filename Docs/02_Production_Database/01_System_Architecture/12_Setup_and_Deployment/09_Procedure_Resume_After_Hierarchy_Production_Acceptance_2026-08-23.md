# Procedure Resume Checkpoint After Shared Hierarchy Production Acceptance — 2026-08-23

Status: **READY TO RESUME ENGINEERING**

The shared field-context hierarchy prerequisite is merged, deployed, and production accepted.

Current accepted production application commit:

```text
060de4546cbaa3cbcec7b70978d17d6db0d3ed44
```

Canonical shared components:

```text
FieldWiring/Application/field_context_repository.py
FieldWiring/Application/field_context_resolver.py
FieldWiring/Application/field_context_browse.py
FieldWiring/Application/field_context_hierarchy.py
```

Production evidence:

```text
74 passed
SHARED FIELD HIERARCHY LOR-OPTIONAL STAGE ACCEPTANCE: PASS
Shared Field Context hierarchy refinement: DEPLOYED AND VERIFIED
```

When `feature/setup-takedown-procedures` resumes:

1. fetch current `origin/main`;
2. merge current `origin/main` into the Procedure branch;
3. preserve the accepted Procedure browser/orchestration/document work;
4. use `field_context_hierarchy.resolve_field_hierarchy(...)` for Stage/Sub-stage/Scene browse;
5. retain permanent Display lookup through `field_context_repository.py`;
6. keep Procedure task/document discovery downstream of the resolved field scope.

Do not render raw `repository.stages()` as field browse.

Do not promote unprefixed Display/component/group folders into Stage/Sub-stage/Scene hierarchy nodes.

The final hierarchy rule follows the released Google Drive and Folder Alignment contracts; no new Scene classification rule was introduced during the Stage 39/40 refinement.
