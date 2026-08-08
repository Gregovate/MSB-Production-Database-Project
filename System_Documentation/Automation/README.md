# Documentation Automation

This area is reserved for tools that help keep the repository documentation consistent as the project grows.

The current Python files are **placeholders and are not yet implemented**. Do not assume they perform repository changes or validation until their behavior is documented and tested.

## Planned Tools

| File | Planned purpose |
|---|---|
| `scan_repository.py` | Inspect repository structure and identify documentation coverage, missing portals, and organization issues |
| `verify_links.py` | Check internal Markdown links, README portal navigation, image references, and known stale path patterns |
| `generate_portals.py` | Support repeatable generation or updating of approved navigation indexes where automation is appropriate |

## Planned Link Validation Workflow

The automated link checker should mirror the documented manual process.

### Pass 1 — Known Moved Paths

Report current documentation that still references approved former locations or superseded application URLs.

Historical/archive material may retain old paths when they are part of the historical record and clearly marked noncurrent.

### Pass 2 — README Portal Verification

For current README portals, verify:

- every internal Markdown link resolves;
- child portals are linked directly to `README.md` when appropriate;
- Related Systems and Related Documents links resolve;
- image references resolve;
- current external application URLs do not use known superseded locations.

The validator should report failures with the source file, broken target, and reason so a maintainer can correct the responsible document.

## Generated Content

Automation may eventually generate or update clearly identified navigation sections and repository indexes, but generated content must have an approved ownership and format contract first.

The separately published production `index.html` pages are **not** part of automatic rewriting at this stage. They require separate review and likely redesign before automation rules are defined for them.

## Automation Rules

Automation should support the documentation standards, not replace editorial review.

Before any tool is allowed to modify repository documentation automatically, it should:

- preserve manually written technical and operational content;
- follow the [README Portal Standard](../Standards/README_Portal_Standard.md);
- follow the [Linking and Navigation Standard](../Standards/Linking_and_Navigation_Standard.md);
- use relative links for repository navigation;
- report proposed changes before destructive edits;
- distinguish current documentation from archived historical material;
- avoid guessing replacement destinations for ambiguous broken links;
- be tested against the repository before production use.

## Related Documents

- [Documentation Standards](../Standards/Documentation_Standards.md)
- [Linking and Navigation Standard](../Standards/Linking_and_Navigation_Standard.md)
- [Repository Documentation Audit](../Repository_Documentation_Audit.md)
