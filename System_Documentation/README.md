# System Documentation

This area defines how MSB project documentation is organized, written, linked, reviewed, and maintained.

It is primarily for documentation maintainers and contributors. Volunteers using operational procedures normally do not need to work in this folder.

## Start Here

| I want to... | Go to |
|---|---|
| Follow reusable MSB documentation rules | [Standards](Standards/README.md) |
| Follow Production Database-specific documentation/governance rules | [Project Rules](Project_Rules/README.md) |
| Start from a controlled document template | [Templates](Templates/README.md) |
| Maintain or validate documentation automatically | [Automation](Automation/README.md) |
| Review remaining repository documentation work | [Repository Documentation Audit](Repository_Documentation_Audit.md) |

## Folder Guide

| Folder | What it contains |
|---|---|
| [Standards](Standards/README.md) | Reusable documentation, portal, linking, Markdown, document-control, SOP, and prompt standards intended to remain consistent across participating MSB repositories |
| [Project Rules](Project_Rules/README.md) | Rules that apply specifically to the MSB Production Database Project and should not be imposed automatically on other repositories |
| [Templates](Templates/README.md) | Controlled starting structures for specific document classes such as Stage Setup Instructions |
| [Automation](Automation/README.md) | Scripts for repository scanning, link validation, and portal maintenance |

## Documentation Governance Model

Use the following hierarchy when a decision is accepted:

```text
Reusable cross-repository rule
    -> System_Documentation/Standards/

Production Database project rule
    -> System_Documentation/Project_Rules/

Subsystem engineering decision
    -> responsible subsystem engineering documentation

Task procedure
    -> responsible operator or field procedure
```

Conversation and working notes are not the durable authority. Material settled decisions must be promoted into the appropriate controlled repository document so another thread or contributor can resume from the repository rather than reconstructing the decision from chat history.

The reusable standards may be synchronized deliberately to other MSB repositories that use the same documentation framework. Project-specific rules remain local.
