# LOR Approved-Version Maintenance Compatibility Rule — 2026-08-25

| Item | Value |
|---|---|
| Status | HOTFIX CANDIDATE — regression coverage added; Production acceptance pending |
| Checker | `lor_version_checker.py` V1.4.1 |
| Production parser | V7.0.11 |
| Production runner | V1.7.1 |
| Approved LOR version | 6.6.10 |

## Decision

Routine preview authoring under the already-approved Light-O-Rama version is
content maintenance, not a software-version schema migration.

The production operator may therefore:

- add or remove Displays;
- add or remove Scenes and change their membership;
- add or remove Motion FX rows;
- add, intentionally remove, or replace complete `.lorprev` / `PreviewClass` entries in the approved preview set;
- populate or clear nullable text/path attributes;
- use integer or decimal authoring values where LOR emits either representation;
- change record counts or token counts inside parser-ignored delimiter payloads; and
- populate or clear the optional sixth `ChannelGrid` color position.

The compatibility checker continues to inventory these differences. Ordinary
same-version content changes remain informational. A complete preview-set
addition/removal/replacement is retained as `REVIEW` evidence because an
accidentally missing Google Drive file can look the same as an intentional
retirement, but it is not treated as parser-breaking XML and does not stop the
normal approved-version parser run.

## Blocking Boundary

Same-version comparison remains fail-closed for newly encountered XML
vocabulary such as an element, attribute, namespace, or parent/child path that
is absent from the approved folder-wide contract. Removal of an optional
structure is informational because an XML instance no longer exercising a
feature does not remove that feature from the LOR schema.

The separate **Check new version** workflow remains fully strict. When the LOR
software versions differ, element, attribute, ordering, value-shape,
delimiter-layout, and `ChannelGrid` differences remain blocking until reviewed
and resolved.

Malformed XML and duplicate `PreviewClass` identity checks still fail while the
manifest is built, before comparison or parser execution. Across different LOR
software versions, removal of an approved PreviewClass remains `BLOCKING`.

## Triggering Evidence

Adding Displays to `Show Background Stage 30-Santa's Station-QV.lorprev`
introduced values that were not represented in the approved instance sample:

- nullable `PropClass.Tag` and `PropClass.TraditionalColors` text;
- nullable `shape.BackgroundImage` and `shape.CustomGrid` content;
- decimal `shape.OffsetX`, `OffsetY`, `ScaleX`, and `ScaleY` values;
- blank/nonblank optional `PropClass.ChannelGrid` color values; and
- new `shape.CustomGrid` comma/semicolon counts.

None changed the XML vocabulary. The V7 parser stores `Tag` and
`TraditionalColors` as nullable text, accepts the optional sixth `ChannelGrid`
color token, and does not consume the listed `shape` attributes. Treating those
content observations as parser-breaking schema changes was incorrect.

On 2026-10-02, the same gap appeared one level higher during Setup launch. The
old Stage 01 Open/Close sign preview was intentionally removed entirely and two
new RGB-matrix sign previews were added in its place. The checker correctly
classified the two new PreviewClass identities as review evidence, but
incorrectly classified the removed same-version PreviewClass identity as
parser-breaking. V1.4.1 corrects that asymmetry while preserving the stricter
cross-version rule.

## Regression Boundary

`test_lor_version_checker_maintenance.py` verifies:

1. same-version Display addition and the complete triggering value set are informational;
2. same-version Display removal is informational;
3. same-version `CustomGrid` record/token-count changes are informational;
4. one complete old preview removed and two new previews added under the same approved version produces review evidence but no parser-breaking finding;
5. removal of a complete approved PreviewClass remains blocking across different LOR versions;
6. the ordinary content differences remain blocking across different LOR versions; and
7. genuinely new XML vocabulary remains blocking in an approved-version run.

The existing Motion FX tests continue to verify same-version row growth is
informational while different-version comparison remains strict.

## 2026-10-02 Hotfix Boundary

This repair changes only compatibility classification for complete preview-set
membership under the already-approved LOR version. It does not change parser
materialization, SQLite schema, PostgreSQL ingest, reconciliation semantics, or
permanent Display identity rules.

The retired preview must not be restored, renamed, or assigned a reused UUID
merely to satisfy the compatibility guard. The current authored preview set is
the source evidence that reconciliation must review after parsing.
