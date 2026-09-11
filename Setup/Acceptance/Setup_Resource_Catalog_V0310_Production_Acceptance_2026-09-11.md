# Setup Resource Catalog V0.3.10 Production Acceptance — 2026-09-11

| Document control | Value |
|---|---|
| Status | ACCEPTED PRODUCTION |
| Application | Setup Session |
| Issue | #152 — Add Setup resource catalog sort order and existing-resource editing |
| Implementation PR | #168 |
| Merge commit | `cc4b5767605373504fd993698ce735514bec0d37` |
| Exact deployed runtime | `c2a1820627f1a036d634241cc6aecd1a926a1479` |
| Version | `V0.3.10-resource-catalog` |
| Production migration | `Setup/Database/027_add_setup_resource_catalog_management.sql` |
| Migration blob | `8d65593a3c083ea74b4a35a95bfd6aa8fd617252` |

## Purpose

Record the accepted Production result for Setup reusable resource-catalog management: searchable task assignment, Manager catalog review/editing, normalized duplicate protection, stable resource identity, inactive-resource handling, optional catalog display order, authorization boundaries, deployment evidence, rollback evidence, and protected-route operator acceptance.

## Accepted Operator Behavior

The normal task workflow is intentionally name-oriented:

```text
search existing resource
    -> choose resource
    -> enter task quantity / Required-vs-Preferred / task notes
    -> add or update task requirement
```

The full catalog manager opens only on demand through **Manage Resource Catalog**. It supports searching all catalog rows, including inactive rows, and editing:

- resource name;
- resource type;
- catalog notes;
- active/inactive state; and
- optional numeric `display_order`.

The accepted refinement from the original issue wording is important:

- `display_order` remains a governed catalog field and can be edited;
- the ordinary assignment picker is sorted primarily by meaningful `resource_name`, then type/ID;
- the full Manager catalog defaults to Name sort;
- numeric display order is an advanced/optional review tool, not the normal picker order.

This was accepted because names such as `Ladder-10 Feet`, `Ladder 5 Feet`, `Stake Pounder Short`, and `Stake Pounder Tall` naturally group for operators and proved easier to use than requiring numeric sort maintenance for ordinary selection.

Task-specific quantity, Required-vs-Preferred, and task notes remain separate from catalog-level resource maintenance.

## Database Contract

Migration 027 added:

```text
ref.setup_resource.display_order integer NOT NULL DEFAULT 100
```

with a non-negative constraint and catalog-order index.

It also installs/refreshes narrow governed commands including:

```text
ref.update_setup_resource(text,integer,text,text,text,boolean,integer)
ref.create_setup_resource(text,text,text,text)
ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)
```

Normalized exact duplicate resource names are rejected after trim/case/repeated-whitespace normalization. Existing historical normalized duplicates are reported rather than silently merged. Production had zero normalized duplicate groups at deployment.

An existing inactive resource may be removed from a task relationship, while a new inactive resource assignment remains blocked.

`setup_resource_id` remains stable when a resource is renamed or corrected. Existing task relationships therefore stay attached to the same catalog identity.

## Production Preflight

Immediately before deployment:

```text
live Setup SHA              = 55478f98f760473b65b5d700a84c868285022ab7
live version                = V0.3.9-predecessor-drag
msb-setup.service           = active
resource rows               = 12
task-resource rows          = 32
normalized duplicate groups = 0
display_order column        = absent
update resource command     = absent
broad setup_resource UPDATE = false
broad setup_resource DELETE = false
broad task-resource UPDATE  = false
stable Setup fingerprint    = 7c21041caecac6eb77660238ba3c8cf9
```

The accepted target was fetched explicitly from GitHub. The server checkout's configured `origin/main` tracking ref was stale because that checkout follows a different branch refspec; `FETCH_HEAD` and `ls-remote origin main` both confirmed current GitHub `main` at:

```text
cc4b5767605373504fd993698ce735514bec0d37
```

The exact deployed runtime `c2a182...` existed and was a forward descendant of the live V0.3.9 runtime.

## Regression Gate

The exact runtime candidate `c2a182...` produced:

```text
207 passed
1 failed
```

The single failure was a stale test literal in `test_setup_resource_picker_compact_contract.py` expecting the prior CSS cache token `.1` while the accepted runtime correctly loads `.2`.

The immediately following commit:

```text
be19b4f0e013b16f40673d14364113219d081f01
```

changed only that test file and corrected the assertion to `.2`; there were no runtime/application changes between `c2a182...` and `be19b4f...`.

Production-runtime regression on that test-only derivative passed:

```text
209 passed in 0.48s
```

This establishes the exact V0.3.10 runtime behavior as green while preserving truthful evidence that the exact runtime commit itself still contained one stale literal assertion.

## Rollback Archive

Before migration 027, a custom-format PostgreSQL archive was created and validated:

```text
/home/msbadmin/backups/setup-152/msb-pre-setup-152-20260911T170411.dump
```

Archive size:

```text
15,806,697 bytes
```

SHA256:

```text
b60857bf12eae68922cc309b795e920b3b2aaccd5a928b775527057450a7aa15
```

`pg_restore --list` validation passed using direct stdin redirection.

## Migration 027 Acceptance

Only migration 027 was applied.

Post-migration validation passed for:

- `display_order` present, `NOT NULL`, defaulted to 100 for current rows;
- non-negative constraint present;
- catalog-order index present;
- `ref.update_setup_resource(...)` installed as a governed command;
- `fieldwiring_app` EXECUTE on the narrow resource commands;
- no broad `UPDATE` or `DELETE` on `ref.setup_resource`;
- no broad `UPDATE` on `ref.setup_task_resource`;
- 12 resource rows preserved;
- 32 task-resource relationships preserved;
- zero normalized duplicate groups; and
- stable Setup fingerprint unchanged at `7c21041caecac6eb77660238ba3c8cf9`.

The migration did not rewrite existing governed Setup data merely to introduce catalog management metadata.

## Application Promotion and Runtime Acceptance

The permanent detached Setup checkout was advanced from V0.3.9 to the exact accepted runtime:

```text
/opt/msb-setup
SHA = c2a1820627f1a036d634241cc6aecd1a926a1479
```

Only `msb-setup.service` was restarted for application activation.

Post-restart health:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.10-resource-catalog"}
```

Focused live regression:

```text
29 passed, 1 deselected in 0.20s
```

The one deselected test was the already-proven stale cache-token assertion documented above.

Direct resource-catalog request without protected identity returned:

```text
HTTP 401 = PASS
```

Final governed fingerprint before any legitimate operator write remained:

```text
7c21041caecac6eb77660238ba3c8cf9
```

## Protected Production Browser Acceptance

The real protected Production route was reviewed after deployment:

```text
https://my.sheboyganlights.org/setup/
```

Operator confirmed all nine requested acceptance checks were working, including:

- expected V0.3.10 client/runtime;
- compact searchable resource picker;
- Manage Resource Catalog open/close behavior;
- searchable full catalog;
- legitimate in-place catalog correction;
- save behavior;
- stable existing task-resource relationship after the catalog correction;
- corrected resource name visible in normal selection/search; and
- surrounding Setup workflow remaining operational.

Protected Production browser disposition:

```text
PASS
```

A separate usability improvement was identified during this acceptance: keep the active task name visible while scrolling long task detail. That work is independently tracked in Issue #169 and is not required for #152 acceptance.

## Deferred Independent Work

Issue #152 does not absorb unrelated remaining work:

- #145 — reusable Catalog cleanup before real 2026 Session creation;
- #166 — browser-preview harness should require only one sudo authentication;
- #167 — Extra Materials, KIT assignments, and material-source tracking;
- #169 — keep the active task name visible while reviewing long task detail;
- #141 — task-specific staged material / Pick List release timing; and
- #159 — cross-application palette/theme consistency.

## Current Accepted Boundary

Issue #152 is complete when this acceptance record and current Setup engineering/operator documentation are merged.

The Production runtime remains intentionally pinned to the exact accepted application SHA `c2a182...`; documentation-only closeout commits do not require moving the live application checkout.
