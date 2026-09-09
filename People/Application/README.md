# People Manager Application — Milestone 1

Branch-only candidate application for issue #130.

## Configuration

Required:

```text
PEOPLE_DATABASE_DSN
```

The database login is `people_app`. Create that LOGIN separately with a secured password. The Milestone 1 database contract grants it function execution only; it does not receive direct `ref.person` table DML or Directus system-table access.

Optional:

```text
PORT=8794
```

## Authentication / Authorization

The application must be deployed behind Cloudflare Access. It requires the authenticated email from:

```text
Cf-Access-Authenticated-User-Email
```

PostgreSQL independently resolves current Directus role/policy authorization. Only Manager, Administrator, or equivalent current `admin_access` authority may manage People.

Every create/update request also requires:

```text
Content-Type: application/json
X-MSB-People-Command: 1
```

## Milestone 1 Write Allowlist

Writable through the governed command functions:

```text
first_name
last_name
preferred_name
email                -- reserved/current @sheboyganlights.org identity
personal_email
cell_phone
active_flag
```

Explicitly not writable here:

```text
directus_user_id
pg_login_name
is_manager
is_team
available_for_work_orders
created_by / updated_by actor fields
capabilities / qualifications / Setup roles
```

There is no DELETE route.

## Email Reservation

Manual create uses the established standard:

```text
first initial + last name @ sheboyganlights.org
```

The UI asks PostgreSQL for candidate addresses. If the standard address collides with current `ref.person` or Directus evidence, the application proposes additional first-name characters and requires explicit exception review before saving an alternate.

This is a PostgreSQL/Directus collision check only. It does not prove that an address is free or provisioned in Google Workspace. Google remains the user-management authority.

## Run Locally

```text
python -m pip install -r requirements.txt
python backend.py
```

A local run still needs a database containing the candidate SQL contract and a Cloudflare-equivalent authenticated request header. Do not add an authorization-bypass mode for Production convenience.
