# LOR System Documentation

This area documents both how people **use** Light-O-Rama Preview workflows and how the underlying LOR systems are **engineered and maintained**.

Those are intentionally separate documentation paths.

## Start Here

| I want to... | Go to |
|---|---|
| Create or update LOR Previews | [Preview Authoring](01_Preview_Authoring/README.md) |
| Understand or change how `.lorprev` data is parsed and structured | [Data Extraction](02_Data_Extraction/README.md) |
| Understand or maintain the controlled Preview merge process | [Preview Merger](03_Preview_Merger/README.md) |
| Understand or maintain FormView wiring and field-documentation behavior | [FormView](04_FormView/README.md) |

## Operator vs Engineering Documentation

**Preview Authoring** is the normal operator path. It is written for Preview authors and programmers who need to create, edit, name, organize, and export LOR Previews without learning parser or database internals.

**Data Extraction, Preview Merger, and FormView engineering documents** preserve the technical detail needed to build, troubleshoot, validate, and continue development of those systems.

Do not move engineering detail into operator procedures merely because the operator task depends on that engineering. Likewise, do not remove needed implementation context from the engineering documents in an attempt to make them operator manuals.

## Folder Guide

| Folder | What it contains |
|---|---|
| [01_Preview_Authoring](01_Preview_Authoring/README.md) | Plain-language operator rules for naming, Preview building, Master Musical Scenes, wiring-image preparation, and Preview import/staging |
| [02_Data_Extraction](02_Data_Extraction/README.md) | `.lorprev` structure, parser architecture, SQLite output design, Folder Alignment, and LOR version compatibility review |
| [03_Preview_Merger](03_Preview_Merger/README.md) | Preview Merger engineering design, current status, and controlled workflow |
| [04_FormView](04_FormView/README.md) | FormView subsystem portal, field-wiring behavior, SQLite dependencies, and recovered engineering architecture |

## Engineering Handoff

When LOR engineering work changes how operators perform a task, update both layers before closing the work:

1. update the engineering document that owns the system decision or implementation behavior;
2. update the affected Preview Authoring/operator procedure in plain language; and
3. review the responsible README portals so the next work session can resume from repository documentation instead of conversation history.

The repository is the durable handoff. Chat and email are not the final documentation authority.

For the 5,000-foot project view, return to the [Project Overview](../00_Project_Overview/README.md).
