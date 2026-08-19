# FieldWiring Drive Resolver — All Master Musical Scene Test Findings

| Item | Value |
|---|---|
| Date | 2026-08-19 |
| Test | `run_resolver_test.ps1 -AllMasterScenes` |
| Snapshot | Current development `fieldwiring_snapshot.db` based on V7 parser state |
| Scope | Read-only resolver test against current mapped `Display Folders` hierarchy |
| Result before harness correction | 18 Scenes tested; 12 RESOLVED; 6 UNRESOLVED |
| Browser implementation status | Still gated; visual fallback order remains under test |

## Purpose

This document records the first full-Master-Musical resolver test after the controlled Stage/Scene structural markers and marked application-source folders were populated across the current Google Drive hierarchy.

The test is intended to separate four different kinds of conditions:

1. valid current resolver behavior;
2. stale LOR/Drive path evidence that can be recovered deterministically;
3. stale Production Database Stage folder-path evidence;
4. genuinely missing published material in the marked source structure.

The test must not convert legacy loose files into current FieldWiring content merely because the file still exists and LOR points to it.

## High-Level Result

The first all-Master run tested 18 Scenes.

```text
12 RESOLVED
 6 UNRESOLVED
```

The six unresolved results are not all the same type. Two exposed a harness/Stage-anchor handling issue with stale persisted `ref.stage.folder_path` evidence. Four correctly exposed current folders that have no published `.jpg/.jpeg/.png` image in their marked `Wiring\MusicalStage` or marked `PreviewBackground` source locations.

The result therefore proves the value of the marker boundary: the resolver no longer succeeds merely because a loose legacy image exists somewhere under the Stage root.

## Conditions That Resolved Correctly

Examples that resolved cleanly include:

- `02-Fred's Stars` — stale stored folder suffix recovered to the current Scene; Scene Musical Wiring selected.
- `02-Mega Tree` — same stale-suffix recovery pattern; Scene Musical Wiring selected.
- `03-Mega Cube-MC` — Scene resolved and its marked `Wiring\MusicalStage` now contains the published `Mega Cube Wiring.jpg`, which was selected ahead of PreviewBackground.
- `05-Festive Trees-FT` — Stage Musical Wiring selected directly.
- `05a-Mega Star-MS` — Substage resolved from the deep legacy pointer; no Substage published image exists, so the current test rule selected Stage Musical Wiring.
- `08-Elf Choir-EC` — Stage Musical Wiring selected directly.
- `10-Stars-ST` — the current LOR pointer is still a loose Stage-root image, but the resolver used it only as navigation evidence and selected the marked Stage Musical Wiring source instead.
- `15-Church-CH` — Stage Musical Wiring selected directly.
- `25-Racing Arches-RA` — Stage Musical Wiring selected directly.

These cases demonstrate that a legacy/loose LOR pointer does not itself become FieldWiring content. Once scope is known, the resolver returns to the marked source structure.

## `SourceDocs` Boundary Remains Effective

The current snapshot still contains legacy pointers for:

```text
07-Who Characters
07-Who Spiral Tree
```

that enter:

```text
Wiring\MusicalStage\SourceDocs
```

The guard stopped before `SourceDocs` and did not use the source images as published FieldWiring content.

Both cases then fell through under the current visual fallback hypothesis to the marked Stage `PreviewBackground` folder.

This is mechanically valid under the current test order, but it is **not accepted as final FieldWiring behavior**. The Stage `PreviewBackground` contains generic Stage images (`Matrix-House.jpg`, `NorthHwySigns.jpg`) that may not be an appropriate field-wiring visual for those specific musical Scenes.

These cases are strong evidence that the visual fallback order remains too permissive to finalize without operator review.

## Unresolved Type 1 — Stale Persisted Stage Folder Path

Two cases exposed stale `ref.stage.folder_path` evidence rather than missing current Drive content.

### `07a-Who Forest-WF`

Current exact LOR pointer resolves beneath:

```text
07-Whoville-WV\07a-Who Forest-WF
```

and the marked Substage `Wiring\MusicalStage` contains:

```text
WhoForest-Tagged.jpg
```

However, the persisted Stage/Substage folder anchor used by the harness was:

```text
07-Whoville-WV\07a-Who Forest
```

which does not exist.

The first marked-source guard required both the stale persisted anchor and the correctly resolved Substage root to have structural markers, causing a false UNRESOLVED result even though the current exact pointer and current marked Substage source were usable.

### `17-Candyland-CL`

The current exact LOR pointer resolves beneath:

```text
17-Candyland-CL
```

while the persisted Stage folder path used by the harness was:

```text
17-Candy Land-CL
```

The persisted path does not exist, so the first guard rejected the valid current marked folder reached by the exact pointer.

### Harness correction

The test guard was corrected after this run so that when a persisted Stage folder path does not resolve, it may recover the top-level Stage anchor from the exact current LOR pointer **only when all of the following are true**:

- the pointer itself resolves;
- it is beneath the configured `Display Folders` root;
- the first folder beneath `Display Folders` matches the numeric Stage key;
- that Stage folder exists; and
- that Stage folder carries the structural marker.

The recovery is reported as a warning and does not rewrite PostgreSQL, LOR, or Google Drive.

This keeps stale Production Database path evidence visible for Folder Alignment cleanup while preventing the browser resolver from failing solely because a persisted path spelling is stale.

A rerun is required to confirm that `07a-Who Forest-WF` and `17-Candyland-CL` now resolve under this corrected test behavior.

## Unresolved Type 2 — No Published Image in Marked Source Structure

Four Stage-level Scenes correctly remained unresolved because their current marked source folders contain no directly published image:

```text
16-Northern Lights-NL
18-Dancing Forest-DF
19-Santa's Workshop-SW
22-Glistening Grove-GG
```

Each currently has an exact LOR `BackgroundFile` pointing to a loose legacy image directly beneath the Stage root, for example:

```text
16-Northern Lights-NL\66 Light Layout.JPG
18-Dancing Forest-DF\DF GPS Layout 2020.jpg
19-Santa's Workshop-SW\Bathroom 20121005_173411.jpg
22-Glistening Grove-GG\2020-11-05 16.44.53.jpg
```

Those loose images remain valid legacy/navigation evidence, but under the new controlled source contract they are **not current FieldWiring content**.

For all four Stages, the marked candidates currently contain no directly published image in:

```text
Wiring\MusicalStage
PreviewBackground
```

Therefore UNRESOLVED is the correct result until Folder Alignment or wiring-document cleanup places an appropriate current visual in the marked source structure.

The resolver must not restore the old behavior of presenting these loose root files merely to make the test pass.

## Fallback Order Still Not Accepted

The all-Master run gives enough evidence to keep the current fallback ladder explicitly under test.

Particularly important cases are:

### `05a-Mega Star-MS`

The Substage is correctly resolved, but neither Substage Musical Wiring nor Substage PreviewBackground has a published image. The current test rule selects Stage Musical Wiring.

That may be the correct inheritance behavior, but it should be accepted deliberately rather than assumed.

### `07-Who Characters` and `07-Who Spiral Tree`

The current test rule ultimately selects generic Stage PreviewBackground images after SourceDocs is blocked and no published Musical Wiring image exists.

This proves that "find the first marked folder with an image" is not sufficient by itself to establish that the visual is appropriate for FieldWiring.

The FieldWiring visual fallback contract therefore remains unresolved even though Stage/Scene/Substage scope resolution and marker enforcement are working.

## What This Test Proves

The all-Master run supports the following conclusions:

```text
V7 Master Musical Scene enumeration:         PROVEN
Stage/Scene/Substage scope resolution:        WORKING
Structural root marker enforcement:           WORKING
Marked helper-source enforcement:             WORKING
SourceDocs exclusion:                         WORKING
Loose legacy file exclusion:                  WORKING
Stale Scene-folder recovery:                   WORKING
Stale persisted Stage folder recovery:         HARNESS CORRECTED; RERUN REQUIRED
Published visual completeness:                 GAPS FOUND
Visual fallback order:                         STILL UNDER TEST
Browser implementation gate:                   NOT YET
```

## Next Test

After pulling the harness correction, rerun:

```powershell
.\Utilities\FieldWiring_Drive_Resolver_Test\run_resolver_test.ps1 -AllMasterScenes
```

Expected engineering question for the rerun:

- do `07a-Who Forest-WF` and `17-Candyland-CL` now resolve through the exact marked current pointer evidence while still reporting the stale persisted folder path;
- do `16`, `18`, `19`, and `22` remain unresolved because their marked source locations genuinely have no published image; and
- do any additional candidate selections change unexpectedly.

Do not perform a new parser run solely for this retest. The current stale `07-Who Characters` snapshot remains useful for proving the legacy-boundary behavior until the operator is ready for the next controlled parser/snapshot cycle.
