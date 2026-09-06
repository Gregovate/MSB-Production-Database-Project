# Setup and Deployment

## Current State

**Status: DOCUMENTATION ACTIVE / PROCEDURE FIELD ACCESS PRODUCTION-OPERATIONAL**

This subsystem covers planning, scheduling, staging, loading, scanning, and moving tested displays and containers from storage to the park for annual setup, plus takedown-related field documentation where it belongs with the same Stage material.

The Stage-oriented folder structure already exists. Setup/Takedown instructions are being organized into those existing Stage folders and use the same Stage-oriented convention already used by Wiring documentation.

The operational database/application workflow for scheduling, pick lists, load order, and forklift scanning is not yet fully engineered. No operator procedure should imply those planned functions are implemented until verified from the current database/application.

**Current Setup Session engineering is owned here by Setup and Deployment.** Start with [Setup Session 2026 Planning Direction — 2026-09-04](11_Setup_Session_2026_Planning_Direction_2026-09-04.md) for the current planning direction under issue [#122](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122). Scan issues #88 and #113 remain integration dependencies and do not own the annual Setup business workflow. The 2026 Setup Session scope deliberately defers detailed KIT/small-component inventory so the first production workflow can be built from existing Display/Container relationships and proven larger physical dependencies without forcing non-LOR materials into Display identity.

**FieldWiring, Display Scan, and the standalone Procedure application are accepted production baselines.** Procedure is production-operational at `https://my.sheboyganlights.org/procedures/` and uses the shared Field Context resolver plus the existing read-only Google `Display Folders` mount. Do not rediscover or redesign those accepted systems merely to continue Setup/Deployment work.

The bounded **Procedure Display Scan Integration** is accepted production behavior: the Display scan hub passes permanent `display_id` to `/procedures/?display_id=<display_id>`, and Setup/Takedown/Inspection selection remains inside Procedure. Controller Inventory V0.4.0 is also merged and production-operational. Human Procedure-document authoring/alignment and the broader scheduling/pick/load/forklift workflow remain separate work streams.

MSB has purchased a **Zebra DS3678-HD cordless ultra-rugged 1-D/2-D scanner kit** for the workshop forklift. It uses the Zebra 3600-series USB cradle and supports USB HID keyboard input. Because this is the **HD (High Density)** variant rather than an ER/XR extended-range model, its actual suitability from the forklift seat must be tested with real MSB Container and Storage Location labels before it is accepted as the final forklift-distance standard. See [Scanner Hardware and Tablet Integration](../07_Labeling_and_Scanning/Scanner_Hardware_and_Tablet_Integration.md).

## Design Intent

The Setup and Deployment subsystem will provide a repeatable operational plan for moving displays and containers from storage to the park while keeping field instructions easy to find from the same established Stage organization used by Wiring.

Testing answers:

> Is this display/container ready?

Setup and Deployment answers:

> What should we work on next, what physical assets do we need for it, what has already moved, where does it go, and what actually got done?
