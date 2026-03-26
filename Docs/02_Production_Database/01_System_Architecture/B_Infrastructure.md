# B — MSB Database Infrastructure (2026) — Reference Appendix
Last updated: 2026-02-20  
Owner: MSB Production Crew  
Status: Active Build (Phase 1)

---

## 1. Goals

Infrastructure must support:
- stable Postgres hosting (Phase 1 foundation)
- remote admin + remote DB access (ZeroTier routing)
- repeatable deployments (Docker compose)
- automated backups + tested restore
- room to add an app/API later without rework

---

## 2. Naming and Endpoints

### Recommended public hostname pattern
- `db.sheboyganlights.org` → MSB database application endpoint (future app/UI)
- Postgres itself should not be directly “internet exposed”.

This keeps adoption clean:
- users go to `my.sheboyganlights.org` for docs/info
- “database tooling/app” can live at `db.sheboyganlights.org` when it exists
- pgAdmin is admin-only and should stay on your machines, not public-facing

---

## 3. Network Reality (Current)

### Core server
- Ubuntu host: `msb-prod-db`
- LAN: `192.168.5.0/24` (office network segment you route to)
- ZeroTier routed admin network: `192.168.191.0/24`

### ZeroTier routing (as-built)
- you have routed access between workshop ↔ park via managed routes
- DB host is reachable from laptop over ZeroTier (validated by ping)

(Keep the routing details in a separate “Network Routing Appendix” if it grows.)

---

## 4. Cloudflare / DNS / Proxying Rules (Practical)

### DNS record rule
- **Any hostname protected by Cloudflare Access must be PROXIED (orange cloud).**
- DNS-only records will not be protected by Access.

### Cloudflare Access rule
- Disable “email one-time pin code” login.
- Enforce Google authentication (Workspace or allowed Google accounts only).

(Reason: the “code” login bypasses your required identity model.)

---

## 5. Service Hosting Model

### Recommended runtime
Docker on `msb-prod-db` for:
- Postgres
- App/API container (future)
- optional workers/scheduled jobs (future) 【turn12file13†B_Infrastructure.md†L3-L8】

### Port exposure policy (non-negotiable)
- **Postgres (5432):** NOT exposed to the internet.
  - Prefer LAN/ZeroTier only.
- **App/API:** internal HTTP port, reachable from reverse proxy if needed.
- **SSH:** MSB LAN only (or admin VLAN only). 【turn12file13†B_Infrastructure.md†L9-L14】

---

## 6. Firewall / Docker Reality Check

Docker port publishing can bypass UFW in some cases, depending on how rules are set.

Operational rule:
- If you publish ports, assume you must also enforce restrictions at:
  - UFW **and/or**
  - iptables in the `DOCKER-USER` chain

(If you don’t need a port reachable, do not publish it.)

---

## 7. Postgres Structure (Conceptual)

### Staging schema
- `lor_stage` (or `lor_raw`): 1:1 import of LOR output SQLite tables
  - keep raw structure stable
  - do not “clean” during ingestion 【turn12file13†B_Infrastructure.md†L17-L22】

### Operational schema
- `msb` (or `public` with clear table naming): storage, pallets, maintenance, documents, etc. 【turn12file13†B_Infrastructure.md†L23-L25】

### Views for field wiring
Views join staging + mapping tables to output:
- display wiring chart results
- controller/network summaries
- per-display setup requirements (including non-LOR components) 【turn12file13†B_Infrastructure.md†L26-L31】

---

## 8. LOR Ingestion (Conceptual)

### Source of truth for LOR export
- SQLite file: `lor_output_v6.db` 【turn12file13†B_Infrastructure.md†L36-L38】

### Ingestion rules
- repeatable and idempotent (upsert/replace strategy)
- ingestion produces:
  - updated staging tables
  - refreshed wiring views/materializations 【turn12file13†B_Infrastructure.md†L39-L44】

### Scheduling
- run on a controlled cadence:
  - after sequencing changes
  - at least weekly during build season
- keep a dated snapshot archive of `lor_output_v6.db` for rollback/debugging 【turn12file13†B_Infrastructure.md†L45-L50】

---

## 9. Backups and Restore

### Non-negotiable
If backups aren’t automated and restore isn’t tested, this isn’t production. 【turn12file13†B_Infrastructure.md†L55-L57】

### Backup targets
- Synology is the backup destination (file share or rsync target). 【turn12file13†B_Infrastructure.md†L58-L60】

### What must be backed up
- Postgres database dumps (nightly)
- app configuration (env files, compose files)
- ingestion logs (failures must be visible)
- archived `lor_output_v6.db` snapshots 【turn12file13†B_Infrastructure.md†L61-L66】

### Retention (starting point)
- daily: 30 days
- weekly: 3 months
- monthly: 12 months 【turn12file13†B_Infrastructure.md†L67-L71】

### Restore drill
- quarterly: restore Postgres dump to a test DB and validate core queries 【turn12file13†B_Infrastructure.md†L72-L74】

---

## 10. Monitoring and Logging (Minimal)

Minimum needed:
- disk usage monitoring (avoid “disk full”)
- service uptime checks (Postgres, app)
- ingestion job success/failure logging
- reverse proxy health (Synology logs) 【turn12file13†B_Infrastructure.md†L77-L84】

---

## 11. Operator Notes (Practical)

### Admin access workflow
- use SSH for server management
- recommended from Windows:
  - Windows Terminal (SSH)
  - VS Code Remote-SSH (best for editing/config + copy/paste)
- remote admin access uses ZeroTier routing 【turn12file13†B_Infrastructure.md†L89-L95】

Allowed admin source networks (as-built target state):
- 192.168.191.0/24 (ZeroTier)
- 192.168.5.0/24 (Office LAN) 【turn12file13†B_Infrastructure.md†L94-L98】

TODO (security hardening later):
- tighten SSH (remove “Anywhere”; restrict to admin networks)
- confirm DOCKER-USER chain enforces any published ports as needed 【turn12file13†B_Infrastructure.md†L98-L100】

---

## 12. TODO List (Explicitly Deferred)

These are intentionally *not* solved yet (don’t block Phase 1 ingestion):

- Synology off-site replication / cross-site storage workflow
- Cloudflare Access polish (branding, app launcher organization)
- Dedicated `db.sheboyganlights.org` app/UI container
- Role-based access model for users (read-only vs editors) beyond initial admin
- Barcode scanning system + workflows