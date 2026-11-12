# People Identity Reconciliation Production Acceptance — 2026-10-13

| Document Control | Value |
|---|---|
| Status | ACCEPTED — PRODUCTION LIVE |
| Source Issue | #385 |
| Implementation PR | #386 |
| Visible People version | `V0.2.2` |
| Accepted runtime candidate | `2c9a2937079f817dafd5119584aaffc77b51357d` |
| Merged/deployed main SHA | `bb8dfa498c5b4bbecfc3693f68c4066c1e08242e` |
| Migration | `People/Database/005_reconcile_directus_person_identity.sql` |
| Migration blob | `88442b8f4150513fd6af581e2ea90004c6f27658` |
| Service | `msb-people.service` |
| Acceptance date | 2026-10-13 |

## Purpose

Record the accepted Production deployment of the durable Directus-to-Person exact-email reconciliation contract that fixes recurring protected-application failures when a real Google-backed Directus identity exists but `ref.person.directus_user_id` is still NULL.

Identity reconciliation does not grant authorization. Current Directus role/policy state remains the authorization authority.

## Disposable Current-Production Acceptance — PASS

Authoritative report:

```text
/tmp/MSB_Identity_Reconcile_Disposable_20261013-183254.txt
```

Exact-candidate regression:

```text
26 passed
```

Disposable acceptance proved:

- migration 005 applies cleanly to a current Production clone;
- exact safe identities self-reconcile through Setup movement, Setup management, Setup execution, Setup inventory, People management, and Controller management actor boundaries;
- already-correct identities are idempotent no-ops;
- Directus role is unchanged;
- provider mismatch fails closed;
- external identifier mismatch fails closed;
- inactive Person fails closed;
- missing exact-email Person fails closed;
- conflicting Person link fails closed;
- Directus UUID ownership conflict fails closed;
- reconciliation update audit attribution resolves to the real Person;
- reconciliation helpers remain internal to application roles; and
- non-human tablet/device/service identities cannot reconcile to a Person.

Explicit non-human exclusions accepted in this release:

```text
tablet-*@sheboyganlights.org
printservice@sheboyganlights.org
production-1@sheboyganlights.org
```

Production `ref.person` fingerprint before/after disposable acceptance:

```text
9dca556251712a3824cda436b0300fc8
```

unchanged.

The read-only Production snapshot before deployment identified exact safe unlinked human examples including:

```text
abubb@sheboyganlights.org
jhodzinski@sheboyganlights.org
pneils@sheboyganlights.org
```

and separately exposed `printservice@sheboyganlights.org` as a non-human Directus account that must never become a human Person actor.

## Governed Production Deployment — PASS

The Production wrapper completed under:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
docs/server/Production_Database_Maintenance_Mode.md
```

Deployment marker:

```text
PEOPLE IDENTITY RECONCILIATION PRODUCTION DEPLOYMENT: PASS
PEOPLE IDENTITY RECONCILIATION PRODUCTION WRAPPER: PASS
```

Final Production identity:

```text
Visible version:       V0.2.2
Final checkout:        bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
Migration:             People/Database/005_reconcile_directus_person_identity.sql
Frozen Person FP:      9dca556251712a3824cda436b0300fc8
Frozen Directus FP:    1333a30c3f2f35fa1864e979c200c177
```

Validated rollback snapshot:

```text
/home/msbadmin/backups/postgres/msb-pre-people-identity-reconcile-20261013T183854.dump
```

Deployment report:

```text
/tmp/MSB_People_Identity_Reconcile_Production_Deploy_20261013T183854.txt
```

The runner returned Production to ONLINE state with exit status 0.

## Production Behavior

The accepted Production behavior is:

```text
human selects own sheboyganlights.org Google account
    -> Cloudflare authentication
    -> existing Directus user/role/policy authorization
    -> exact-email Person reconciliation if safe and link is NULL
    -> protected command continues as that human
```

The reconciler may create only the missing durable UUID relationship on an already-existing active Person. It does not:

- create a Person;
- reactivate a Person;
- change Directus role;
- change Directus policies;
- promote Browser to Production Crew;
- promote anyone to Manager/Administrator; or
- guess identity by name or personal email.

Shared tablet/device/service identities remain non-human and are rejected from Person reconciliation.

## Operational Result

An already-authorized human whose Directus UUID link is missing no longer requires a one-off backend repair. The next protected actor path performs the same accepted exact-email reconciliation automatically when all fail-closed conditions pass.

This specifically addresses the recurring failure class observed for users such as Adam Biebel, Mark Hayon, and Paul Neils while preserving existing Directus authorization.

**PEOPLE IDENTITY RECONCILIATION PRODUCTION ACCEPTANCE: PASS**
