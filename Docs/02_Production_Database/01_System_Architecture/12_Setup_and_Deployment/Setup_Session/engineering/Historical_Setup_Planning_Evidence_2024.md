# Historical Setup Planning Evidence — 2024

| Document control | Value |
|---|---|
| Status | CURRENT HISTORICAL RECONNAISSANCE — planning evidence only; not actual-execution history |
| System | Setup Session |
| Parent system | Setup and Deployment |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |

## Purpose

Preserve usable historical planning evidence recovered from the Microsoft Project file supplied during Setup Session reconnaissance:

`MSB Setup 2024 Master.mpp`

The file is useful for understanding how MSB previously planned Setup work by date, sequence, Stage/setup area, and task. It is **not** evidence that the scheduled work actually occurred on the planned dates.

This distinction matters because the future Setup Session is intended to preserve planned-versus-actual history rather than allowing the final schedule to overwrite the original plan.

## Source-file character

Inspection of the native Microsoft Project `.mpp` established that this is a **rolling master project**, not a clean 2024-only historical snapshot.

Observed file metadata includes:

- internal document title: `MSB Setup 2022`;
- template: `MSB Setup Template`;
- last saved by Greg Liebig;
- last saved on `2024-09-03 18:42`;
- Microsoft Project native MPP structure containing task data carried across multiple seasons.

The task data includes legacy 2022/2023 material as well as explicit 2024 scheduled entries. Therefore later historical analysis must select the relevant season deliberately rather than treating every row in the master file as 2024.

The September 3 save date is also strong evidence that the later September/October 2024 dates described below are **planned schedule dates** rather than proof of completed work.

## Recoverable 2024 planned schedule examples

A conservative native-file extraction recovered the following explicit 2024 scheduled task entries.

| Planned start | Planned finish | Task |
|---|---|---|
| 2024-09-07 08:00 | 2024-09-07 17:00 | Put Covers on all Park Traffic Signs |
| 2024-09-30 08:00 | 2024-10-02 14:30 | 5 Hang Mega Tree Lights |
| 2024-09-30 08:00 | 2024-09-30 17:00 | 3 Setup Claymation Panels |
| 2024-09-30 08:00 | 2024-09-30 17:00 | 02-Mega Cube Setup |
| 2024-10-01 08:00 | 2024-10-02 12:00 | 3 Setup Car Counter Arches |
| 2024-10-01 08:00 | 2024-10-01 08:45 | 2 Stack Steeples |
| 2024-10-01 08:00 | 2024-10-14 17:00 | 5 Setup Train Panels |
| 2024-10-01 08:00 | 2024-10-02 17:00 | 6 Locate & Setup Quarry Entrance Panels |
| 2024-10-02 08:00 | 2024-10-02 10:00 | Setup Food Collection Tent and Sign |
| 2024-10-02 10:00 | 2024-10-02 12:00 | 24-Food Collection |
| 2024-10-02 10:00 | 2024-10-02 12:00 | 2 Setup Lane Arches |
| 2024-10-02 12:00 | 2024-10-02 14:30 | Food Collection Huts |
| 2024-10-03 08:00 | 2024-10-11 17:00 | Food Collection Traffic Lanes |
| 2024-10-12 08:00 | 2024-10-12 17:00 | 3 Spool out harnesses |

The native project also contains additional task names covering the broader Setup process, including Food Collection, Festive Trees, Post Office, Whoville, Who Forest, Elf Choir, Heat Mister/Old Man Winter, Stars, Sledders, Winter Wonderland, Icicle Tunnel, Church, Northern Lights, Candyland, Dancing Forest, Santa's Workshop, Polar Bear Playground, Traditional Christmas, Racing Arches, Magic Igloo, Quarry, staging, trailers, infrastructure work, debugging, sequencing, VIP/opening work, and other operational tasks.

Do not infer current Stage identity or exact modern terminology merely from these historical task names. The file predates the current Scene model and contains naming conventions from its own planning era.

## What this historical plan proves about the planner

Even this partial 2024 schedule demonstrates that Setup planning is not simply:

```text
one day -> one Stage
```

The historical plan includes:

- several tasks planned for the same day;
- multiple tasks within one broad Setup area;
- tasks that span more than one day;
- short tasks mixed with much longer work;
- Stage/setup work mixed with infrastructure, traffic-control, harness, staging, and other supporting work;
- work expressed at different practical granularities rather than one rigid hierarchy level.

That supports the current requirement for a flexible daily/work-package planner rather than a single Stage/date field.

For example, the October 2 plan grouped several Food Collection-related tasks into one day while still preserving distinct tasks and times:

```text
2024-10-02
    Setup Food Collection Tent and Sign
    Food Collection
    Setup Lane Arches
    Food Collection Huts
```

This is useful precedent for a future Setup Session day that contains multiple related work items under one broad Stage/setup area.

## Historical plan versus actual execution

This source provides **plan evidence**.

It does not establish:

- whether each task actually occurred on the scheduled date;
- actual start/finish time;
- actual crew size;
- whether work was moved because of weather or volunteer availability;
- whether a multi-day planned task really consumed that many field days;
- which planned tasks were skipped, combined, split, or performed early/late;
- actual trailer trips or transport burden.

Those facts require another source such as a later Project update, calendar history, messages/email, photos, volunteer records, or direct recollection.

The future Setup Session should preserve both sides explicitly:

```text
planned work/date/sequence
    != actual work/date/sequence
```

Historical reconstruction should likewise label evidence as `planned`, `actual`, or `uncertain/inferred` rather than collapsing them.

## Scene-model boundary

Scenes are new to the current Production Database workflow and should not be retroactively imposed on this 2024 plan.

The historical task names should be preserved as written. Where useful, later reconciliation may associate a historical task with a current Stage/Scene/Display identity, but that mapping should be explicit and reviewable.

For 2024 evidence:

```text
historical task wording
    -> preserve source wording
        -> optional reviewed mapping to current Stage/Scene identity
```

Do not rewrite the source history to make it appear that the current Scene taxonomy existed in 2024.

## Planning implications for 2026

This source supports several candidate planner requirements already emerging from current-process reconnaissance:

- annual Setup Session context;
- flexible work days;
- multiple work items per day;
- Stage-level planning with finer task/work-item detail where needed;
- non-Stage supporting work in the same planner;
- planned start/order/duration as useful planning aids without making the schedule rigid;
- ability to replan while retaining the original plan where historical learning matters;
- actual execution captured separately;
- future comparison of planned effort versus actual effort.

It also reinforces that the first Setup planner should not depend on the new Scene hierarchy for every work item. The real planning vocabulary may include Stage, Display, Scene, infrastructure/support tasks, and practical work descriptions.

## Further historical reconstruction

If later evidence becomes available, useful next comparisons include:

1. a 2025 Setup plan or schedule;
2. 2024/2025 calendar entries showing actual volunteer work dates;
3. dated photos or messages that show what was actually being installed;
4. actual volunteer/crew records where available;
5. any updated/final Microsoft Project file containing actual dates or percent-complete information.

The purpose is not to build a perfect historical archive before 2026 Setup. The goal is to obtain enough real evidence to avoid designing the first planner entirely from memory and to establish what planned-versus-actual history is worth capturing going forward.

## Native MPP ingestion caution

The native `.mpp` is readable as historical evidence, but direct MPP ingestion should not become a production dependency for Setup Session.

If exact Microsoft Project fields such as baselines, predecessors, resources, actual dates, or custom fields need to be reconciled later, a controlled Microsoft Project XML export is preferable for transparent field-level verification.

The Production Database should model the actual Setup business process, not Microsoft Project's internal file format.

## Related documents

- [Setup Session subsystem](../README.md)
- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Park Area Naming and Orientation Reconnaissance — 2026-09-03](Park_Area_Naming_and_Orientation_Reconnaissance_2026-09-03.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
