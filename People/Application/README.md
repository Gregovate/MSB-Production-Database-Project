# People Manager Application — V0.2.2 Production / V0.2.3 #395 Candidate

People Manager is live in Production for issue #130.

Production entry point:

```text
https://my.sheboyganlights.org/people/
```

## Production Runtime

```text
application SHA      54e1192309b96c9838676be51a0bfcdb3ac92e06
service              msb-people.service
version              V0.2.2
runtime account      fieldwiring
working directory    /opt/fieldwiring/People/Application
listener             192.168.5.9:8796
environment file     /etc/msb-people/people.env
PostgreSQL role      people_app
PGPASSFILE           /var/lib/fieldwiring/.pgpass
```

The Production Gunicorn service binds explicitly to `192.168.5.9:8796`; Setup owns `8794`. Do not infer a Production listener from the development `backend.py` fallback port.

Server/runtime authority is `Gregovate/MSB-Server-Management`.

## Configuration

Required application setting:

```text
PEOPLE_DATABASE_DSN
```

Production value identifies the dedicated `people_app` login without embedding its password:

```text
host=127.0.0.1 port=5432 dbname=msb user=people_app
```

libpq obtains the password through the protected runtime `.pgpass` file.

## Authentication / Authorization

The application is deployed behind Cloudflare Access and requires the authenticated email from:

```text
Cf-Access-Authenticated-User-Email
```

PostgreSQL independently resolves current Directus role/policy authorization. Only **Manager**, **Administrator**, or equivalent current accepted `admin_access` authority may manage People.

Cloudflare authentication alone does not grant People management access. Human write commands also require the authenticated Directus user to map to a durable `ref.person` actor.

Every create/update request additionally requires:

```text
Content-Type: application/json
X-MSB-People-Command: 1
```

## #395 Silent Human Identity Bootstrap Candidate

The V0.2.3 candidate adds a narrow server-side bootstrap endpoint:

```text
POST /api/identity/bootstrap
Cf-Access-Authenticated-User-Email: <trusted Cloudflare identity>
X-MSB-Identity-Bootstrap: 1
Content-Type: application/json
{}
```

The endpoint is intentionally available **before** existing Directus authorization because creating the missing baseline Directus identity is its only purpose.

It may create a Directus user only when the database status contract proves:

```text
exact normalized @sheboyganlights.org email
+ exactly one active existing ref.person
+ Person.directus_user_id is NULL
+ no Directus user exists for that email
+ exactly one MSB Browser baseline role exists
+ account is not a governed tablet/device/service identity
```

Creation is performed through the supported local Directus Users API with:

```text
status              active
provider            google
external_identifier exact normalized MSB email
role                MSB Browser
```

The role is supplied at creation time so the historical create-event User Onboarding Flow's `role IS NULL` branch does not run. This prevents that legacy Flow from reaching its missing-Person auto-create branch. After Directus creation, the People backend invokes the accepted #385 exact-email reconciliation wrapper to link the already-existing Person.

Existing Directus identities are never re-created or re-roled. A safe existing NULL Person link may be reconciled; an already-correct identity is a no-op.

Tablet/device/service identities are a no-op and never become Persons. Missing/inactive/conflicting human states fail closed before Directus user creation.

### Runtime settings

The candidate adds:

```text
PEOPLE_DIRECTUS_URL
    default: http://127.0.0.1:8055

PEOPLE_DIRECTUS_IDENTITY_TOKEN
    required only for creation of a missing human Directus identity
    server-side only; never exposed to browser JavaScript or committed to Git
```

Directus 11.x requires administrator accountability when manually setting a user's `provider` and `external_identifier` through the Users API. The bootstrap credential must therefore be a dedicated protected runtime credential and may be used only by this narrow endpoint.

The People PostgreSQL role remains least privilege: it receives EXECUTE only on the bootstrap status/reconcile functions and no direct SELECT/INSERT/UPDATE rights on `public.directus_users`.

## Person Contact Write Allowlist

Writable through the governed person command functions:

```text
first_name
last_name
preferred_name
email                -- reserved/current @sheboyganlights.org identity
personal_email
cell_phone
active_flag
```

Protected from ordinary person/contact editing:

```text
directus_user_id
pg_login_name
is_manager
is_team
available_for_work_orders
created_by / updated_by actor fields
```

Capabilities, qualifications, and Setup roles are maintained only through their own governed metadata functions/API routes. There is no People Manager person DELETE or merge route.

## Email Reservation

Manual create uses the established standard:

```text
first initial + last name @ sheboyganlights.org
```

If the standard address collides with current `ref.person` or Directus evidence, the application proposes additional first-name characters and requires explicit exception review before saving an alternate.

This does not prove that an address is provisioned in Google Workspace. Google remains the account/mailbox authority.

## Google Analytics

```text
Measurement ID      G-X08ZTSY0VV
analytics version   2026-09-09.1
```

The Production page view was verified in the MSB Internal Intranet GA4 property on 2026-09-09. Person identity, contact values, `person_id`, authenticated identity, and search text are prohibited from GA4.

## Local Development

```text
python -m pip install -r requirements.txt
python backend.py
```

A local run still needs a database containing the People SQL contract and a Cloudflare-equivalent authenticated request header. The direct `backend.py` development fallback port is not Production runtime authority. Do not add an authorization-bypass mode for convenience.
