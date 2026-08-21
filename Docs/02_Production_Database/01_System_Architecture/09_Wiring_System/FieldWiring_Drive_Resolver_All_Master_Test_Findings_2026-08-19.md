# FieldWiring Drive Resolver — All Master Musical Scene Test Findings

| Item | Value |
|---|---|
| Date | 2026-08-19 |
| Test | `run_resolver_test.ps1 -AllMasterScenes` |
| Snapshot | Current development `fieldwiring_snapshot.db` based on V7 parser state |
| Scope | Read-only resolver test against current mapped `Display Folders` hierarchy |
| First run | 18 Scenes tested; 12 RESOLVED; 6 UNRESOLVED |
| Confirming rerun after Stage-anchor recovery fix | 18 Scenes tested; 14 RESOLVED; 4 UNRESOLVED |
| Browser implementation status | Still gated; visual fallback order remains under test |

## Purpose

This document records the full-Master-Musical resolver testing after the controlled Stage/Scene structural markers and marked application-source folders were populated across the current Google Drive hierarchy.

The test separates four different kinds of conditions:

1. valid current resolver behavior;
2. stale LOR/Drive path evidence that can be recovered deterministically;
3. stale Production Database Stage folder-path evidence; and
4. genuinely missing published material in the marked source structure.

The test must not convert legacy loose files into current FieldWiring content merely because the file still exists and LOR points to it.

## Confirmed High-Level Result

After correcting the stale persisted Stage-anchor handling, the all-Master rerun tested 18 Scenes:

```text
14 RESOLVED
 4 UNRESOLVED
```

The rerun confirmed the expected behavior:

- `07a-Who Forest-WF` now resolves through exact current marked pointer evidence while still reporting the stale persisted Stage/Substage path.
- `17-Candyland-CL` now resolves through exact current marked pointer evidence while still reporting the stale persisted Stage folder spelling.
- `16-Northern Lights-NL`, `18-Dancing Forest-DF`, `19-Santa's Workshop-SW`, and `22-Glistening Grove-GG` remain unresolved because the marked current source structure contains no directly published image.

This confirms that the earlier 12/18 result contained two false negatives caused by stale persisted Stage-path anchors, while the remaining four gaps are real publication/alignment gaps under the new source-folder contract.

## Conditions That Resolve Correctly

Examples include:

- `02-Fred's Stars` — stale stored folder suffix recovered to the current Scene; Scene Musical Wiring selected.
- `02-Mega Tree` — same stale-suffix recovery pattern; Scene Musical Wiring selected.
- `03-Mega Cube-MC` — Scene resolved and its marked `Wiring\MusicalStage` contains `Mega Cube Wiring.jpg`, selected ahead of PreviewBackground.
- `05-Festive Trees-FT` — Stage Musical Wiring selected directly.
- `05a-Mega Star-MS` — Substage resolved from the deep legacy pointer; no Substage published image exists, so the current test rule selects Stage Musical Wiring.
- `07a-Who Forest-WF` — stale persisted Substage path is tolerated; exact marked current pointer resolves the Substage and selects `WhoForest-Tagged.jpg`.
- `08-Elf Choir-EC` — Stage Musical Wiring selected directly.
- `10-Stars-ST` — current LOR pointer is still a loose Stage-root image, but the resolver uses it only as navigation evidence and selects the marked Stage Musical Wiring source instead.
- `15-Church-CH` — Stage Musical Wiring selected directly.
- `17-Candyland-CL` — stale persisted Stage folder spelling is tolerated; current marked Stage Wiring is recovered from exact pointer evidence and contains five published images.
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

The guard stops before `SourceDocs` and does not use the source images as published FieldWiring content.

Both cases then fall through under the current visual fallback hypothesis to the marked Stage `PreviewBackground` folder.

This is mechanically valid under the current test order, but it is **not accepted as final FieldWiring behavior**. The Stage `PreviewBackground` contains generic Stage images (`Matrix-House.jpg`, `NorthHwySigns.jpg`) that may not be an appropriate field-wiring visual for those musical Scenes.

The Stage-level `07-Whoville-WV` Scene also currently resolves to the same Stage PreviewBackground because no published Musical Wiring image exists.

These three Stage-PreviewBackground selections are the strongest evidence that the current binary resolver result is conflating two different questions:

1. did the resolver find the correct Stage/Substage/Scene context; and
2. does that context contain an appropriate published FieldWiring visual package?

The scope can be correct even when the wiring visual is missing or unsuitable.

## Confirmed Stale Persisted Stage Folder Recovery

### `07a-Who Forest-WF`

Stored Stage/Substage anchor:

```text
07-Whoville-WV\07a-Who Forest
```

Current exact marked pointer/root:

```text
07-Whoville-WV\07a-Who Forest-WF
```

The rerun recovers the top-level Stage from the exact current marked pointer, retains the more-specific Substage scope, and selects:

```text
07a-Who Forest-WF\Wiring\MusicalStage\WhoForest-Tagged.jpg
```

while preserving a warning that the persisted folder path is stale.

### `17-Candyland-CL`

Stored Stage anchor:

```text
17-Candy Land-CL
```

Current exact marked pointer/root:

```text
17-Candyland-CL
```

The rerun recovers the current Stage and selects the marked Stage `Wiring\MusicalStage`, which currently contains five published images.

The rerun also exposed a minor harness-reporting issue: the successful Candyland recovery retained the old pre-recovery warning `No candidate folder contained...` even though the rebuilt candidates contained five images and a candidate was selected. The harness was corrected after the rerun so that stale pre-recovery candidate warnings are recalculated after Stage-anchor recovery.

This reporting cleanup does not change the 14/18 result or any Drive resolution decision.

## Four Genuine Current Publication Gaps

These four Stage-level Scenes remain unresolved under the current test rule:

```text
16-Northern Lights-NL
18-Dancing Forest-DF
19-Santa's Workshop-SW
22-Glistening Grove-GG
```

Each has an exact LOR `BackgroundFile` pointing to a loose legacy image directly beneath the Stage root:

```text
16-Northern Lights-NL\66 Light Layout.JPG
18-Dancing Forest-DF\DF GPS Layout 2020.jpg
19-Santa's Workshop-SW\Bathroom 20121005_173411.jpg
22-Glistening Grove-GG\2020-11-05 16.44.53.jpg
```

Those files remain usable as legacy/navigation evidence, but under the new controlled source contract they are **not current FieldWiring content**.

For all four Stages, the marked current candidates contain no directly published image in:

```text
Wiring\MusicalStage
PreviewBackground
```

Therefore the missing-visual condition is real until Folder Alignment or wiring-document cleanup places an appropriate current visual in the marked source structure.

The resolver must not restore the old behavior of presenting these loose root files merely to make the test pass.

## Fallback Order Still Not Accepted

The all-Master tests give enough evidence to keep the current fallback ladder explicitly under test.

### `05a-Mega Star-MS`

The Substage is correctly resolved, but neither Substage Musical Wiring nor Substage PreviewBackground has a published image. The current test rule selects Stage Musical Wiring.

That may be the correct inheritance behavior, but it should be accepted deliberately rather than assumed.

### Stage 07 PreviewBackground fallthrough

`07-Who Characters`, `07-Who Spiral Tree`, and `07-Whoville-WV` currently select Stage PreviewBackground because no usable published Musical Wiring image is available under the selected scope/fallback chain.

The available Stage PreviewBackground images are generic context images rather than proven wiring drawings.

This demonstrates that "find the first marked folder with an image" is not sufficient to establish a successful **FieldWiring visual** result.

A likely next design refinement is to report **scope resolution** and **published wiring-visual availability** separately instead of using one binary `RESOLVED/UNRESOLVED` status. That design change is not yet accepted merely by this test report.

## What the Confirming Rerun Proves

```text
V7 Master Musical Scene enumeration:          PROVEN
Stage/Scene/Substage scope resolution:         PROVEN FOR CURRENT TEST SET
Structural root marker enforcement:            PROVEN
Marked helper-source enforcement:              PROVEN
SourceDocs exclusion:                          PROVEN
Loose legacy file exclusion:                   PROVEN
Stale Scene-folder recovery:                    PROVEN
Stale persisted Stage folder recovery:          PROVEN FOR CURRENT TEST CASES
Published visual completeness:                  GAPS FOUND (16, 18, 19, 22)
Visual fallback order:                          STILL UNDER TEST
Browser implementation gate:                    NOT YET
```

## Next Engineering Decision

Do not run a new parser merely to improve this test result.

The next decision is semantic rather than another path-resolution fix:

- whether `PreviewBackground` should count as a successful FieldWiring visual fallback or only as context/navigation material;
- whether Stage/Substage Wiring inheritance such as `05a-Mega Star-MS -> Stage Wiring` is the intended field behavior; and
- whether the resolver/test status should separate `scope resolved` from `published wiring visual found`.

Only after that is decided should the harness candidate-selection/result model be changed and the browser implementation gate reconsidered.
