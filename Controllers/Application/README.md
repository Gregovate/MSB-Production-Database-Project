# Controller Inventory Bootstrap Workbench

Initial engineering application for Issue #110.

## Scope

This browser edits only Controller-owned bootstrap/review data in:

```text
stage.controller_bootstrap
stage.controller_bootstrap_display
```

It reads existing governed data from:

```text
ref.display
ref.controller_model
```

It may read `ref.controller*` for post-promotion inspection.

The browser deliberately does **not** expose the permanent bootstrap promotion. Permanent IDs 1001+ can only be allocated through the separately reviewed SQL promotion gate.

## Configuration

Required:

```text
CONTROLLER_DATABASE_DSN
```

For authenticated write deployment behind Cloudflare Access, also configure:

```text
CONTROLLER_OPERATORS=email1@example.org,email2@example.org
```

If `CONTROLLER_OPERATORS` is omitted, the application treats writes as engineering-local mode. Do not deploy that mode as the production Controller application.

Optional:

```text
PORT=8792
```

## Run

```text
python -m pip install -r requirements.txt
python backend.py
```

## Workflow

The workbench supports:

- staged candidate search/filter;
- visible model/UID/year/grouping evidence;
- permanent Display lookup by `display_id`;
- M:N `SERVES` relationships;
- one reviewed `WIRING_SOURCE` relationship for cases such as a non-wired physical copy;
- operator-reviewed `year_deployed` override;
- READY / REVIEW_REQUIRED / SKIPPED state;
- blocker enforcement before READY;
- preparation and review of staged proposed IDs beginning at 1001.

Any edit to a Display relationship returns the candidate to `REVIEW_REQUIRED` and clears its proposed bootstrap order. This prevents a stale reviewed ID order from surviving a changed physical mapping.
