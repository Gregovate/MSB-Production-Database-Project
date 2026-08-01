# V7 Reconciliation Development Workspace

This folder is reserved for the development work needed to validate the scene-aware V7 pipeline introduced by the LOR 6.6.4 XML/schema changes.

Its scope is deliberately narrow: prove that scene-aware parser output can be ingested into PostgreSQL and reconciled against existing production records reliably, without errors or incorrect identity decisions that could damage production data.

This is the validation bridge between a successful `lor_snap` ingest and an approved production procedure. It is not the full LOR import pipeline and is not the routine operator workflow.

Files here may include:

- one-time preflight and evidence queries;
- run-specific reconciliation scripts;
- candidate validation queries;
- temporary or proposed DDL;
- design notes supporting development decisions;
- scripts that require review before any production use.

Typical questions answered here include:

- Did the V7 parser and ingester preserve the required preview, prop, and scene relationships?
- Can stage context formerly supplied by individual musical preview IDs be recovered safely from scenes?
- Do stage and display candidates resolve to the correct permanent production identities?
- Are malformed, missing, ambiguous, or conflicting records stopped before promotion?
- Will a proposed P1, P2, or future P3 revision preserve existing production IDs and PostgreSQL-owned data?

This folder also contains `LOR_Display_Reconciliation_SQL_Design.md`. That file
is the technical design record for the reconciliation and promotion work. It is
development-facing documentation, not an operator procedure or deployment
instruction, and belongs in this folder with the SQL it explains.

## Important Boundary

Content in this folder is **not automatically production-ready and is not the normal operator-facing production workflow**. Its location does not authorize deployment.

Documents in this folder must not be treated as operator-facing instructions
unless they are deliberately rewritten and placed in the appropriate permanent
operations or deployment-documentation location.

Before a database object or repeatable procedure becomes production SQL:

1. Validate and approve the design and results.
2. Move or rewrite the final production version in the appropriate permanent location under `Postgres_sql/`.
3. Update the applicable operating or deployment documentation.
4. Preserve only reconciliation material that remains useful as development history or repeatable validation evidence.

Temporary DDL used to create or test an object may remain here while development is active, but it must not be treated as the authoritative deployed definition after the production object and permanent source are established.
