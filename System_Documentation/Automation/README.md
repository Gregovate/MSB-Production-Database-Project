# Documentation Automation

This area is reserved for tools that help keep the repository documentation consistent as the project grows.

The current Python files are **placeholders and are not yet implemented**. Do not assume they perform repository changes or validation until their behavior is documented and tested.

## Planned Tools

| File | Planned purpose |
|---|---|
| `scan_repository.py` | Inspect repository structure and identify documentation coverage or organization issues |
| `verify_links.py` | Check internal Markdown links and report missing or stale targets |
| `generate_portals.py` | Support repeatable generation or updating of navigation indexes where automation is appropriate |

## Automation Rules

Automation should support the documentation standards, not replace editorial review.

Before any tool is allowed to modify repository documentation automatically, it should:

- preserve manually written technical and operational content;
- follow the [README Portal Standard](../Standards/README_Portal_Standard.md);
- use relative links for repository navigation;
- report proposed changes before destructive edits;
- distinguish current documentation from archived historical material;
- be tested against the repository before production use.

## Related Documents

- [Documentation Standards](../Standards/Documentation_Standards.md)
- [Linking and Navigation Standard](../Standards/Linking_and_Navigation_Standard.md)
- [Repository Documentation Audit](../Repository_Documentation_Audit.md)
