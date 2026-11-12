# FieldWiring Operational SOPs

These procedures are for people using the production **Field Wiring** browser. They describe the deployed V0.4.0 screens in normal operator language and intentionally avoid database-engineering detail.

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Open FieldWiring and confirm I have access | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#open-fieldwiring) |
| Find wiring for a specific Display | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#find-wiring-for-a-display) |
| Browse wiring by Stage, Sub-stage, or Scene | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#browse-by-stage--sub-stage--scene) |
| Read the Field Hookup information | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#read-the-field-hookup) |
| Use the wiring image and image controls | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#use-the-wiring-image) |
| Switch between Background / Static and Musical wiring when offered | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#switch-wiring-context-when-offered) |
| Open Field Wiring after scanning a Display | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#open-field-wiring-from-a-display-scan) |
| Print or save a field copy | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#print-or-save-a-field-copy) |
| Know what to do when the wiring or image looks wrong | [FieldWiring Operator Procedure](FieldWiring_Operator_Procedure.md#if-something-is-wrong) |

## Current Production Version

```text
FieldWiring / Controller Inventory V0.4.0
```

FieldWiring is the current MSB field-wiring system. Former FormView instructions are not the current operating procedure.

Screenshots are intentionally **not required for the first procedure revision**. Screenshot placeholders are included in the main procedure so current production screenshots can be added later without rewriting the instructions.

## Access

FieldWiring is available to authorized production users at:

```text
https://my.sheboyganlights.org/fieldwiring/
```

If the site does not open or you are told that you do not have access, contact the MSB Database Administrator or the person coordinating Production access. Do not use another person's login.

## Scope Boundary

FieldWiring shows the current approved wiring information used by the field crew. Use the **Field Hookup** information as the primary wiring instruction. Wiring images are supplemental location/context guidance.

If the actual Controller, Display, plug, or wiring in front of you does not agree with FieldWiring, stop and report the mismatch rather than changing connections to force them to agree.

The wire-label selection/printing workflow is still under development and is not part of this current operator procedure.

For engineering ownership and system behavior, use the [Wiring System architecture](../../01_System_Architecture/09_Wiring_System/README.md).
