# Setup Stage / Scene Material and Presentation — Production Acceptance — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session |
| Status | ACCEPTED PRODUCTION |
| Owner | MSB Production Database engineering |
| Production application SHA | `9791a6b5a9739c1107746ecbe3cf3ebb558f38bd` |
| Repository merge | PR #144 / merge commit `96613aae4e5084dab2f735bc3dbcc8e13433109e` |

## Purpose

Preserve the accepted Production evidence for the Setup Stage/Scene material-resolution and Stage-oriented presentation change so the result does not depend on chat history or PR comments.

## Accepted Behavior

Production now uses the following reusable-task material contract:

```text
Setup task
    -> existing work scope = Stage or real Scene
    -> Uses Display / Container Material = yes/no

if no
    -> no LOR-derived Displays/Containers

if yes + real Scene
    -> exact current ref.lor_scene_display membership

if yes + Stage
    -> current Stage LOR groups classified as Stage-level
    -> true child Scenes excluded

resolved Displays
    -> current ref.display.container_id
    -> deduplicated Containers
```

There is no operator-facing LOR Preview/Stage/Scene material-source selector. Programming-only LOR groups remain valid LOR objects but do not automatically become Setup Scenes.

Production presentation also now provides:

- Stage-oriented grouping in **Plan / Schedule** and **Perform Work**;
- `Stage-level / General` and `Scene — ...` subgroup headings in Stage view;
- an explicit switch back to **Planned order** without changing the underlying annual planning-order model; and
- the existing global Setup search across Reusable Task Catalog, Plan / Schedule, and Perform Work.

## Disposable / Browser Acceptance

The exact candidate was exercised against a disposable current-Production clone before Production mutation.

Final accepted candidate:

```text
9791a6b5a9739c1107746ecbe3cf3ebb558f38bd
```

Final browser-review result:

```text
Production Setup fingerprint before = 2f8f105d247118a80f8b7337ae799e89
Production Setup fingerprint after  = 2f8f105d247118a80f8b7337ae799e89
live Setup SHA before               = f39174c21bb7382c50b6d70d68a2bab1cb7bb098
live Setup SHA after                = f39174c21bb7382c50b6d70d68a2bab1cb7bb098
exit status                         = 0
```

Retained browser report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Stage_Scene_Browser_Preview_20260910T235121.txt
```

Operator-visible acceptance confirmed:

- Stage 01 Catalog shows Stage-level plus only the real Scenes `01-Entrance Arch` and `01-Front Gate`;
- Stage-level material resolves automatically when the material checkbox is enabled;
- `02-Mega Tree` resolves only its Scene material rather than all Stage 02 material;
- Perform Work shows real Scene grouping;
- Plan / Schedule and Perform Work search operate correctly.

## Required Material Partition Evidence

Disposable current-Production-clone validation proved:

| Stage | Stage-level Displays | child-Scene Displays | Total | Overlap |
|---|---:|---:|---:|---:|
| 00 | 11 | 0 | 11 | 0 |
| 01 | 7 | 7 | 14 | 0 |
| 02 | 10 | 22 | 32 | 0 |
| 13 | 9 | 29 | 38 | 0 |
| 16 | 66 | 0 | 66 | 0 |

## Production Preflight

Immediately before Production mutation:

```text
exact candidate Setup/Application regression = 154 passed
material column already exists               = false
material setter already exists               = false
display_status SELECT already exists          = false
Production business fingerprint              = 798e59ae47a5e313d45cd23e9fdc3c4a
```

## Production Migration and Deployment

Migration applied:

```text
Setup/Database/025_add_setup_display_material_requirement.sql
```

The migration added:

- `ref.setup_task.requires_display_material boolean NOT NULL DEFAULT false`;
- governed `ref.set_setup_task_display_material_requirement(...)`;
- `EXECUTE` for `fieldwiring_app` on the governed setter; and
- the additional read-only `SELECT` on `ref.display_status` required by automatic active-Display resolution.

Least-privilege validation passed. `fieldwiring_app` did not receive broad direct DML on `ref.setup_task`.

Business-data fingerprint after migration remained:

```text
798e59ae47a5e313d45cd23e9fdc3c4a
```

The Setup application worktree advanced from:

```text
f39174c21bb7382c50b6d70d68a2bab1cb7bb098
```

to:

```text
9791a6b5a9739c1107746ecbe3cf3ebb558f38bd
```

Only `msb-setup.service` was restarted.

Post-restart health:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.5-stage-scene-material-review"}
```

Live deployed regression:

```text
154 passed
```

Direct request without the protected identity boundary:

```text
HTTP 401
```

Final Production business fingerprint remained:

```text
798e59ae47a5e313d45cd23e9fdc3c4a
```

## Rollback Evidence

Validated rollback archive:

```text
/home/msbadmin/backups/setup-stage-scene-material/msb_pre_setup_stage_scene_material_20260911T000157.dump
```

Deployment report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Stage_Scene_Production_Deployment_20260911T000157.txt
```

## Post-Deployment Finding

Production review confirmed that a reusable task can exist without a 2025 annual row. `Setup Panels` is one such current reusable task and therefore does not appear in the 2025 Plan / Schedule view even though its reusable definition and material resolution are valid.

The annual Session creation command seeds every **active** reusable task into a newly created Setup Session. Therefore reusable Catalog cleanup is a hard gate before creating 2026; otherwise reconstruction duplicates will be propagated into the 2026 annual plan.

Tracked in Issue #145.

## Related Authority

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md`
- Issue #122 — Setup Session engineering umbrella
- Issue #145 — reusable Catalog cleanup gate before 2026
- PR #144 — accepted implementation and Production evidence
