# MSB PostgreSQL Read-Only MCP

**Status:** DRAFT scaffold — not deployed and not connected to production.

## Purpose

This utility provides a deliberately narrow Model Context Protocol (MCP) server for read-only engineering access to the current MSB PostgreSQL state.

It exists to remove the repeated copy/paste loop between ChatGPT and database tools while preserving the Production Database authority and safety boundaries.

This is **not** the FieldWiring application. It is a cross-system engineering connector that can support FieldWiring verification and other approved Production Database inspection work.

## Safety Boundary

The server is intentionally limited:

- no arbitrary SQL tool;
- no `INSERT`, `UPDATE`, `DELETE`, `MERGE`, DDL, or procedure-call tool;
- every exposed MCP tool is marked read-only/non-destructive;
- every PostgreSQL connection sets new transactions to read-only;
- every query has a short statement timeout and lock timeout;
- the service never commits a database transaction;
- deployment must use a dedicated PostgreSQL role whose grants are SELECT-only;
- credentials are supplied through environment configuration and are never committed to Git.

The MCP annotations are descriptive hints, not the security boundary. The real security controls are the fixed SELECT queries, read-only transaction mode, and the future dedicated PostgreSQL SELECT-only role.

## Current Tools

### `get_current_snapshot_summary`

Returns the current `lor_snap` import run and counts for current previews, scenes, props, sub-props, DMX rows, Scene membership, and field-wiring leads.

### `find_display`

Searches the permanent `ref.display` collection by human-facing Display Name, optionally constrained by Stage key.

Returns normal operator context such as:

- `display_id`;
- Display Name;
- Stage key/name/short code;
- Display status.

It does not expose LOR UUIDs.

### `get_display_current_context`

Uses the existing current reconciliation/occurrence layer to resolve a permanent `display_id` into its current LOR Preview and Scene occurrences.

Normal output is human-facing:

- Display Name;
- Stage;
- Preview Name;
- Scene Name when applicable;
- current identity/reconciliation classification.

LOR UUIDs remain internal plumbing and are not returned.

### `get_current_field_wiring`

Returns the current `preview_wiring_fieldlead_v6` rows for one permanent `display_id`, optionally for one Preview Name.

### `get_scene_field_wiring`

Starts from one permanent `display_id`, resolves its current Scene membership from the current snapshot, and returns the field-lead wiring package for the Displays in that Scene.

This is an engineering verification tool for the FormView-to-FieldWiring conversion. It does not define the final FieldWiring API contract.

### `describe_relation`

Engineering-only inspection of relation columns and deployed view definitions in the allowlisted schemas:

- `lor_snap`;
- `ops`;
- `ref`.

It cannot execute arbitrary SQL.

## Existing Database Objects Reused

This scaffold intentionally uses the objects that already exist:

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

The connector does not create a new wiring table or a second identity system.

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

Normal MCP output should use Display Name, Stage, Preview Name, and Scene Name where useful. Raw LOR Prop/Scene/Preview UUIDs are not intended as operator-facing information.

## Prerequisites

Deployment target should be a host that can reach `msb-prod-db`. The preferred first deployment is directly on the database host with the MCP server bound to localhost.

Runtime requirements:

- Python 3.10 or newer;
- MCP Python SDK v2;
- Psycopg 3;
- a PostgreSQL credential that will later be replaced/confirmed as a dedicated SELECT-only MCP role.

## Local Installation

From this folder:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

On Windows PowerShell, activate with:

```powershell
.\.venv\Scripts\Activate.ps1
```

## Configuration

Copy the values in `config.example.env` into the protected runtime environment. The application does not automatically load that example file.

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

## Run Locally

```bash
python server.py
```

The default MCP endpoint is:

```text
http://127.0.0.1:8000/mcp
```

The service uses Streamable HTTP and is intended to remain bound to localhost when Secure MCP Tunnel runs on the same host.

## Development Test

With the MCP CLI/Inspector available from `mcp[cli]`, the server can be inspected before any ChatGPT connection is created.

Do not test against production with a write-capable credential as the long-term configuration. The deployment gate is a dedicated PostgreSQL SELECT-only role.

## Secure MCP Tunnel — Later Deployment Gate

No tunnel is configured by this scaffold.

After the local MCP server is validated and the dedicated read-only PostgreSQL role is in place, OpenAI `tunnel-client` can connect the private localhost MCP endpoint to ChatGPT without opening a new inbound public firewall rule.

That is a separate deployment step and must not be performed until the database grants and service behavior have been reviewed.

## Not Yet Done

This scaffold does **not**:

- create or modify a PostgreSQL role;
- change grants;
- install Python packages on `msb-prod-db`;
- install or configure `tunnel-client`;
- create a ChatGPT custom MCP connection;
- change the FieldWiring database schema;
- change FormView;
- change the V7 parser.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_PostgreSQL_Readiness_Audit.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_View_Inventory_and_Read_Model_Decision.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md`
