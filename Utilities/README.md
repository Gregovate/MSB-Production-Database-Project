# Utilities

This folder contains active tools that support more than one MSB subsystem or do not belong to a single application or database component.

## Ownership Rule

A utility should live here only when it is genuinely cross-system.

If a tool primarily serves one subsystem, keep it with that subsystem instead. This prevents `Utilities/` from becoming a miscellaneous storage area and keeps implementation close to the documentation and system that own it.

## Maintenance

When adding a current utility:

- document what system or systems use it;
- identify its normal entry point;
- link to the related subsystem documentation when useful;
- move superseded utilities to the appropriate archive rather than leaving obsolete tools mixed with current ones.

For repository documentation-maintenance tools, use [System Documentation Automation](../System_Documentation/Automation/README.md) instead of this folder.
