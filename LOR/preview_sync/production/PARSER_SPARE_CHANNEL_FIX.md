# Renamed SPARE channel authoring — parser V7.0.12

Issue #299 / PR #300. A SPARE channel may be renamed for sponsor-sign use while
its Display Comment remains SPARE. PASS 0 formerly recognized SPARE using Name;
auto-grouping then grouped the renamed masters under another SPARE master.
Existing explicit children pointed at the demoted masters, failing the final
SQLite foreign-key audit. The prior production SQLite remained preserved.

Use the Display Comment as the SPARE authority, retaining legacy Name fallback
only when Comment is blank. Explicit SPARE children remain under their XML
master and are not also inserted as independent masters. Exclude SPARE from
Display grouping consistently, including case/whitespace normalization in the
canonicalization/audit SQL. A physical Display Comment takes precedence over an
old channel Name containing SPARE.

Preserve UUIDs, both Regular/22 channels 15 and 16, explicit child links, source
exports and existing physical-display grouping. Do not assign sponsor Display
names, create containers/pallets, or change PostgreSQL. Ingest remains separate.

Five tests run the actual parser in disposable TEST mode: renamed independent
SPARE masters with explicit children, Comment normalization, assigned Display
identity with legacy SPARE Name, distinct Display Comments, and rejection of a
truly missing explicit master. All passed. Windows installer preflight and real
34-preview parser run remain operator pending.
