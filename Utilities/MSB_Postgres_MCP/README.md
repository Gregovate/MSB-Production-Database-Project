# MSB PostgreSQL Read-Only MCP

**Status:** ENGINEERING VALIDATION — the read-only MCP server and Secure MCP Tunnel have been validated on `msb-prod-db`. ChatGPT Pro currently does not expose the documented custom-MCP/tunnel registration control in this account, so the SQLite FieldWiring snapshot exporter below is the active engineering bridge.

## Purpose

This utility provides deliberately narrow read-only engineering access to the current MSB PostgreSQL state.

It exists to remove the repeated copy/paste loop between ChatGPT and database tools while preserving the Production Database authority and safety boundaries.

This is **not** the FieldWiring application. It is a cross-system engineering connector that supports FormView-to-FieldWiring verification and other approved Production Database inspection work.

The intended long-term path remains the MCP server. The SQLite snapshot exporter is a temporary engineering bridge while the ChatGPT custom-MCP registration surface is unavailable.

## Safety Boundary

The MCP server and snapshot exporter are intentionally limited:

- no arbitrary SQL tool;
- no `INSERT`, `UPDATE`, `DELETE`, `MERGE`, DDL, or procedure-call tool against PostgreSQL;
- MCP tools are marked read-only/non-destructive;
- PostgreSQL connections use read-only transactions;
- the deployed PostgreSQL account is the dedicated SELECT-only `msb_mcp_readonly` role;
- queries use short statement and lock timeouts;
- PostgreSQL transactions are rolled back, never committed;
- credentials are supplied through protected runtime configuration and are never committed to Git;
- the snapshot exporter writes only to its local SQLite output file.

The MCP annotations are descriptive hints, not the security boundary. The real security controls are the fixed SELECT queries, read-only PostgreSQL transaction mode, and the dedicated SELECT-only database role.

## Current MCP Tools

### `get_current_snapshot_summary`

Returns the current `lor_snap` import run and counts for current previews, scenes, props, sub-props, DMX rows, Scene membership, and field-wiring leads.

### `find_display`

Searches permanent `ref.display` identity by human-facing Display Name, optionally constrained to one Stage key.

### `get_display_current_context`

Uses the existing reconciliation/occurrence layer to resolve a permanent `display_id` into current LOR Preview and Scene occurrences.

### `get_current_field_wiring`

Returns current `preview_wiring_fieldlead_v6` rows for one permanent `display_id`, optionally for one Preview Name.

### `get_scene_field_wiring`

Starts from one permanent `display_id`, resolves current Scene membership, and returns the field-lead wiring package for the Displays in that Scene.

### `describe_relation`

Engineering-only inspection of relation columns and deployed view definitions in the allowlisted schemas:

- `lor_snap`;
- `ops`;
- `ref`.

It cannot execute arbitrary SQL.

## Existing Database Objects Reused

Both the MCP tools and the snapshot exporter reuse the current database objects that already exist:

```text
lor_snap.v_current_run
lor_snap.v_current_previews
lor_snap.v_current_scenes
lor_snap.v_current_props
lor_snap.v_current_sub_props
lor_snap.v_current_dmx_channels
lor_snap.v_current_scene_lor_props
lor_snap.v_display_lor_occurrence
lor_snap.preview_wiring_fieldlead_v6
ops.v_lor_display_reconciliation
ref.display
ref.display_status
ref.stage
```

The utility does not create a new PostgreSQL wiring table or a second identity system.

## FieldWiring SQLite Snapshot Export

`export_fieldwiring_snapshot.py` exports the current engineering read model into one portable SQLite database so FieldWiring analysis and testing can continue without repeated manual PostgreSQL query relays.

The export is intentionally a **snapshot**, not a replacement database and not a new history model.

### Consistency

The exporter uses one PostgreSQL `REPEATABLE READ`, read-only transaction for the complete export. This keeps all exported relations on one consistent PostgreSQL source snapshot.

Current-state views are exported as-is. Relations that can contain multiple import runs are explicitly filtered to the `import_run_id` returned by `lor_snap.v_current_run`:

```text
lor_snap.v_display_lor_occurrence
ops.v_lor_display_reconciliation
```

### SQLite table names

PostgreSQL schema-qualified relation names are stored with a double underscore:

```text
lor_snap.v_current_previews
    -> lor_snap__v_current_previews

ops.v_lor_display_reconciliation
    -> ops__v_lor_display_reconciliation

ref.display
    -> ref__display
```

### Snapshot metadata

Every output database also contains:

```text
_snapshot_manifest
_snapshot_relations
_snapshot_columns
_snapshot_view_definitions
```

These tables record the source database/user, export time, current `import_run_id`, source row counts, PostgreSQL column metadata, and deployed view definitions. `PRAGMA integrity_check` must pass before the temporary export file is promoted to the final `.db` file.

### Run on `msb-prod-db`

The exporter uses the same protected `MSB_PG_DSN` configuration as the MCP service.

```bash
cd /opt/msb-postgres-mcp
set -a
source config.env
set +a
./.venv/bin/python export_fieldwiring_snapshot.py
```

With no `--output`, it creates a file such as:

```text
fieldwiring_snapshot_run_50_20260818T213000Z.db
```

To choose a path explicitly:

```bash
./.venv/bin/python export_fieldwiring_snapshot.py \
  --output /opt/msb-postgres-mcp/fieldwiring_snapshot.db
```

Existing files are not overwritten unless `--force` is explicitly supplied.

### When to regenerate

Regenerate the snapshot after an approved PostgreSQL/LOR import changes `lor_snap.v_current_run`. A single exported file can be reused for analysis and application testing while that source import remains current.

The snapshot is an engineering bridge only. FieldWiring production behavior must ultimately read the authoritative current PostgreSQL state rather than treating an exported SQLite copy as the production source of truth.

## Human vs Internal Identity

The connector follows the current MSB rule:

```text
QR scan
    -> permanent display_id

manual search
    -> Display Name + Stage
    -> selected display_id

internal database resolution
    -> existing LOR/reconciliation relationships
    -> current snapshot
```

Normal field-facing output should use Display Name, Stage, Preview Name, and Scene Name where useful. Raw LOR Prop/Scene/Preview UUIDs are internal plumbing. The engineering SQLite snapshot may retain those internal identifiers where required to preserve current joins, but they are not intended for the FieldWiring user interface.

## Runtime Requirements

- Python 3.10 or newer;
- MCP Python SDK v2;
- Psycopg 3;
- Python standard-library `sqlite3` for the snapshot exporter;
- dedicated PostgreSQL SELECT-only credentials.

Install from this folder with:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## MCP Configuration

Required:

```text
MSB_PG_DSN
```

Optional:

```text
MSB_MCP_HOST=127.0.0.1
MSB_MCP_PORT=8000
```

Do not commit a populated password or DSN.

The default MCP endpoint is:

```text
http://127.0.0.1:8000/mcp
```

It is intended to remain bound to localhost while Secure MCP Tunnel runs on the same host.

## Current Deployment Note

The localhost MCP server, six read-only tools, dedicated PostgreSQL role, Secure MCP Tunnel authentication, and tunnel runtime health have been validated on `msb-prod-db`.

The remaining MCP blocker is on the ChatGPT product side: this Pro account currently redirects the documented connector settings route into the Plugins UI without exposing the documented custom MCP `Create` / `Connection: Tunnel` control.

Do not redesign the PostgreSQL connector or open a public inbound MCP port to work around that UI issue. Continue engineering work through the snapshot exporter until the supported ChatGPT registration surface is available.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_PostgreSQL_Readiness_Audit.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_View_Inventory_and_Read_Model_Decision.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md`
