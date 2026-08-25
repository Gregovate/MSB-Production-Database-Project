# LOR Approved-Version Maintenance Compatibility Rule — 2026-08-25

| Item | Value |
|---|---|
| Status | IMPLEMENTED AND LOCALLY TESTED |
| Checker | `lor_version_checker.py` V1.4.0 |
| Production parser | V7.0.11 |
| Approved LOR version | 6.6.10 |

## Decision

Routine preview authoring under the already-approved Light-O-Rama version is
content maintenance, not a software-version schema migration.

The production operator may therefore:

- add or remove Displays;
- add or remove Scenes and change their membership;
- add or remove Motion FX rows;
- populate or clear nullable text/path attributes;
- use integer or decimal authoring values where LOR emits either representation;
- change record counts or token counts inside parser-ignored delimiter payloads; and
- populate or clear the optional sixth `ChannelGrid` color position.

The compatibility checker continues to inventory these differences, but it
records them as informational evidence and does not stop the approved-version
parser run.

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
manifest is built, before comparison or parser execution.

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

## Regression Boundary

`test_lor_version_checker_maintenance.py` verifies:

1. same-version Display addition and the complete triggering value set are informational;
2. same-version Display removal is informational;
3. same-version `CustomGrid` record/token-count changes are informational;
4. the same differences remain blocking across different LOR versions; and
5. genuinely new XML vocabulary remains blocking in an approved-version run.

The existing Motion FX tests continue to verify same-version row growth is
informational while different-version comparison remains strict.
