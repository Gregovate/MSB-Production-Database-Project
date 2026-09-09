# People Manager Production Acceptance — 2026-09-09

| Document Control | Value |
|---|---|
| Status | ACCEPTED — PRODUCTION LIVE |
| Source Issue | #130 |
| Production PR | #135 |
| Production application SHA | `54e1192309b96c9838676be51a0bfcdb3ac92e06` |
| Application version | `V0.2.0` |
| Service | `msb-people.service` |
| Listener | `192.168.5.9:8796` |
| Public route | `https://my.sheboyganlights.org/people/` |
| PostgreSQL role | `people_app` |
| Runtime account | `fieldwiring` |
| Acceptance date | 2026-09-09 |

## Purpose

Record the completed Production deployment and live acceptance of the MSB People Manager after current-Production disposable acceptance and governed pre-Production browser review.

The accepted Production deployment followed the Server Management Production Database change and protected Flask application service procedures. The public `/people/` route was then installed through the established Synology protected reverse-proxy workflow.

## Accepted Candidate Boundaries

Accepted database/backend candidate:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Final browser-accepted presentation candidate:

```text
4724185fe8cd8831a59c61ea40df61073abbb0c6
```

Production deployed application SHA:

```text
54e1192309b96c9838676be51a0bfcdb3ac92e06
```

The Production wrapper re-verified acceptance ancestry and proved that the accepted People database/API runtime boundary had not changed before mutation.

## Production Backend Deployment — PASS

Production server report:

```text
/tmp/MSB_People_Manager_Production_Deploy_20260909T221415.txt
```

Validated rollback PostgreSQL archive:

```text
/home/msbadmin/backups/postgres/msb-pre-people-manager-20260909T221415.dump
SHA256 8da9827cda2b7e5a061e953d9c16b6ee46318fb52d5eb3f6e2086e621d976d87
```

Detached Production-runtime regression:

```text
274 passed in 2.67s
DETACHED CANDIDATE REGRESSION: PASS
```

Accepted database changes:

```text
People/Database/001_create_people_manager_contract.sql
People/Database/002_harden_people_search_phone_filter.sql
People/Database/003_create_people_metadata_contract.sql
```

Production validation proved:

```text
people_app LOGIN created with password kept out of logs
people_app libpq authentication PASS
people_app has narrow governed function EXECUTE only
no broad ref.person DML
no broad People metadata table DML
no direct Directus system-table access
no metadata seed rows created
ref.person unchanged
```

Production `ref.person` fingerprint before/after:

```text
47f494107952a84f30a406374b8d01d7
```

The shared Production checkout advanced from:

```text
72f5b7164f31753a33e5c2a9d83d9a7a6909a417
```

to the exact accepted Production target:

```text
54e1192309b96c9838676be51a0bfcdb3ac92e06
```

FieldWiring, Procedures, and Setup remained healthy after the checkout advance.

## Accepted Permanent Runtime

```text
service                  = msb-people.service
service state            = active / enabled
runtime account          = fieldwiring
working directory        = /opt/fieldwiring/People/Application
Python / Gunicorn        = /opt/fieldwiring/.venv
listener                 = 192.168.5.9:8796
environment              = /etc/msb-people/people.env
PostgreSQL role           = people_app
PGPASSFILE                = /var/lib/fieldwiring/.pgpass
public route              = https://my.sheboyganlights.org/people/
```

Accepted health payload included:

```json
{"capability_contract":true,"delete_exposed":false,"directus_identity_edit_exposed":false,"google_provisioning_exposed":false,"merge_exposed":false,"person_table":true,"qualification_contract":true,"search_contract":true,"setup_role_contract":true,"status":"ok","version":"V0.2.0"}
```

Authentication boundary:

```text
missing Cloudflare identity -> HTTP 401
accepted Manager identity   -> authorized
```

## Firewall Boundary — PASS

Production UFW permits the People backend only from the Synology reverse proxy:

```text
8796/tcp ALLOW IN 192.168.5.4  # Synology to MSB People
```

The backend listener was not opened broadly to the LAN or Internet.

## Synology `/people/` Route — PASS

The permanent protected route is:

```text
https://my.sheboyganlights.org/people/
    -> Synology 192.168.5.4
    -> 192.168.5.9:8796
```

Accepted nginx rollback backup:

```text
/root/msb-nginx-backups/user.conf.pre-people-20260909T173958
```

Final route acceptance proved:

```text
/people/api/health        -> HTTP 200 / V0.2.0
/people                   -> HTTP 301 to /people/
/people/                  -> People Manager rendered
/people/api/access        -> HTTP 401 without injected identity
FieldWiring route         -> healthy
Procedures route          -> healthy
Setup route               -> healthy
```

### Synology execution finding

The first workstation-driven route attempt did not mutate nginx. Windows OpenSSH `scp` initially attempted SFTP and the Synology rejected that subsystem; the wrapper was corrected to force legacy SCP with `-O`.

A second workstation-driven attempt successfully copied and launched the route script but stalled at the script's interactive `sudo -v` inside nested SSH. The stuck process tree was terminated before the nginx backup/configuration phase. No route mutation had occurred at that stop point.

The final route deployment was therefore completed from the established normal administrative workflow: a regular PowerShell SSH session to:

```text
ssh msbad@192.168.5.4 -p 22222
```

and a bounded interactive-shell deployment block following the Server Management SSH safety and Synology reverse-proxy procedures. This is the accepted operational pattern for future Synology nginx changes that require interactive `sudo`.

## Live Browser Acceptance — PASS

The operator opened the real Production application through the normal Cloudflare-authenticated path:

```text
https://my.sheboyganlights.org/people/
```

The People Manager rendered Production data and accepted the Manager identity. Search and person detail loaded successfully through the live route.

People Manager remains limited to current Directus Manager / Administrator or equivalent accepted `admin_access` authority. Cloudflare authentication by itself does not grant People management access.

## Google Analytics Acceptance — PASS

The deployed People application uses:

```text
Measurement ID       G-X08ZTSY0VV
analytics asset      People/Application/static/analytics.js
analytics version    2026-09-09.1
```

The operator verified the live GA4 property showed:

```text
MSB People Manager — 1 view
```

This proves the direct Production People page view reached the MSB Internal Intranet GA4 property.

The deployed analytics contract:

```text
allow_google_signals=false
allow_ad_personalization_signals=false
manual sanitized page_view
no person name/email/phone/person_id/authenticated identity/search text in GA4
```

GA4 remains aggregate application-usage telemetry, not a People audit log.

## Final Acceptance

```text
current-Production disposable acceptance    PASS
pre-Production browser review               ACCEPTED
Production database/backend deployment      PASS
People permanent service                    PASS
source-limited UFW                          PASS
Synology protected /people/ route           PASS
Cloudflare-authenticated live browser        PASS
GA4 Production page view                    PASS
existing protected application regressions  PASS
```

**PEOPLE MANAGER PRODUCTION ACCEPTANCE: PASS**

The remaining People closeout activity is Production intranet/index integration through `Gregovate/MSB-Internal-Web-Backbone#16`, followed by the return-handoff update.