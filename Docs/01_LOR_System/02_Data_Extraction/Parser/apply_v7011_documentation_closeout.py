"""Apply the V7.0.11 documentation-maintenance closeout locally.

This temporary helper updates only documentation already touched by the grouped-DMX
reverse-engineering work. It promotes the durable record from proposed/unimplemented
V7.0.10 language to the implemented and manually validated V7.0.11 state.

Validation evidence recorded by this closeout:
- pre-change grouped-DMX baseline: 4 tests PASS against unchanged V7.0.10;
- post-change focused grouped-DMX regression: 4 tests PASS;
- full Parser unittest discovery: 33 tests PASS;
- git diff --check: clean;
- implementation commit: 9d2bd7af59840e983425efd1a8f0fa7ff6cc0871.

The helper does not modify parser code, tests, PostgreSQL, FormView, or schema outside
the already-implemented SQLite V7.0.11 parser change. It removes itself and the
one-time parser patch helper after successful documentation updates so neither looks
like a normal long-term engineering tool.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]

FILES = {
    "data_readme": ROOT / "Docs/01_LOR_System/02_Data_Extraction/README.md",
    "terms": ROOT / "Docs/01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md",
    "arch": ROOT / "Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md",
    "sqlite": ROOT / "Docs/01_LOR_System/02_Data_Extraction/LOR_SQLite_Output_Database_Structure.md",
    "xmlspec": ROOT / "Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_File_Structure_Specification.md",
    "change_map": ROOT / "Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md",
    "checkpoint": ROOT / "Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_Parser_Extension_Checkpoint_2026-08-21.md",
    "wiring_readme": ROOT / "Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md",
}

PARSER = HERE / "parse_props_v7_scene_parser.py"
TEST = HERE / "test_parse_props_grouped_dmx.py"
OLD_HELPER = HERE / "apply_dense_rgb_dmx_v7011_patch.py"
SELF = Path(__file__).resolve()
IMPLEMENTATION_SHA = "9d2bd7af59840e983425efd1a8f0fa7ff6cc0871"


def fail(message: str) -> None:
    raise SystemExit(f"[FATAL] {message}")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        fail(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE | re.DOTALL)
    if count != 1:
        fail(f"{label}: expected exactly one regex anchor, found {count}")
    return new_text


def insert_revision(text: str, entry: str, label: str) -> str:
    anchor = "| Date | Author | Change |\n|---|---|---|\n"
    return replace_once(text, anchor, anchor + entry + "\n", label)


def assert_clean_start() -> None:
    result = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=True
    )
    if result.stdout.strip():
        fail("working tree is not clean; commit/stash unrelated work before documentation closeout")
    parser_text = read(PARSER)
    test_text = read(TEST)
    if 'PARSER_VERSION = "V7.0.11"' not in parser_text:
        fail("canonical parser is not V7.0.11")
    if "GroupedDMXV7011RegressionTests" not in test_text:
        fail("grouped-DMX regression fixture is not the V7.0.11 version")


def patch_data_readme(text: str) -> str:
    return replace_once(
        text,
        "`Parser/parse_props_v7_scene_parser.py` V7.0.10. The current approved LOR version",
        "`Parser/parse_props_v7_scene_parser.py` V7.0.11. The current approved LOR version",
        "Data Extraction current parser baseline",
    )


def patch_terms(text: str) -> str:
    text = replace_once(
        text,
        "| Functional baseline | `parse_props_v7_scene_parser.py` V7.0.10 |",
        "| Functional baseline | `parse_props_v7_scene_parser.py` V7.0.11 |",
        "terminology baseline",
    )
    text = replace_once(
        text,
        "| position of a Channel Grid Row within its PropClass | not currently stored as a dedicated field | Channel Grid Row Number | Human-readable 1-based position within that PropClass; numbering restarts for the next PropClass |",
        "| position of a DMX Channel Grid Row within its PropClass | `dmxChannels.ChannelGridRowNumber` | Channel Grid Row Number | 1-based source position within that PropClass; numbering restarts for the next PropClass |",
        "terminology row number mapping",
    )
    text = replace_once(
        text,
        "For grouped DMX Displays, several `PropClass` records can share one Display Name (`PropClass.Comment`). The current V7.0.10 parser intentionally materializes one canonical Display master in `props` and attaches all grouped DMX wiring rows to that master through `dmxChannels.PropId`.",
        "For grouped DMX Displays, several `PropClass` records can share one Display Name (`PropClass.Comment`). The current V7.0.11 parser intentionally materializes one canonical Display master in `props` and attaches all grouped DMX wiring rows to that master through `dmxChannels.PropId`. V7.0.11 additionally preserves the originating LOR Prop ID, Channel Name, and local Channel Grid Row Number on each `dmxChannels` row.",
        "terminology grouped DMX current behavior",
    )
    text = replace_once(text, "## Proposed DMX Provenance Field Names", "## Current DMX Provenance Field Names — V7.0.11", "terminology provenance heading")
    text = replace_once(
        text,
        "Dependency inspection of V7.0.10 established that the first additive grouped-DMX extension does not need abstract source/component field names.\n\nThe proposed fields are:",
        "V7.0.11 implements the first additive grouped-DMX source-detail extension without abstract source/component field names.\n\nThe current fields are:",
        "terminology provenance intro",
    )
    text = replace_once(text, "| Proposed `dmxChannels` field | Controlled meaning | Source |", "| Current `dmxChannels` field | Controlled meaning | Source |", "terminology provenance table header")
    text = replace_once(
        text,
        "These are proposed fields only until the parser schema is changed and validated.",
        "These fields are implemented in parser V7.0.11 and validated by the grouped-DMX regression fixture while preserving the existing canonical Display/master relationship.",
        "terminology provenance implemented state",
    )
    text = replace_once(
        text,
        "See [FieldWiring Dense RGB DMX Additive Change Map](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md) for the controlled proposed implementation boundary.",
        "See [FieldWiring Dense RGB DMX Additive Change Map](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md) for the controlled implementation and validation boundary.",
        "terminology change-map wording",
    )
    text = insert_revision(
        text,
        f"| 2026-08-21 | GAL / OpenAI | Promoted grouped-DMX provenance terminology to the implemented V7.0.11 contract after 33 parser tests passed; implementation commit `{IMPLEMENTATION_SHA[:7]}`. |",
        "terminology revision",
    )
    return text


def patch_arch(text: str) -> str:
    text = replace_once(text, "| Functional baseline | `parse_props_v7_scene_parser.py` V7.0.10 |", "| Functional baseline | `parse_props_v7_scene_parser.py` V7.0.11 |", "architecture baseline")
    text = replace_once(
        text,
        "SQLite connections and retries bounded, transient Windows sharing locks before\natomic publication, including short-lived Google Drive inspection locks.\nFuture parser changes must be reviewed against this architecture.",
        "SQLite connections and retries bounded, transient Windows sharing locks before\natomic publication, including short-lived Google Drive inspection locks. V7.0.11\nadditively preserves grouped-DMX source LOR Prop ID, Channel Name, and local Channel\nGrid Row Number without changing the canonical Display/master relationship.\nFuture parser changes must be reviewed against this architecture.",
        "architecture version summary",
    )
    text = replace_once(text, "The current V7.0.10 DMX path groups source `PropClass` rows", "The current V7.0.11 DMX path groups source `PropClass` rows", "architecture DMX version")
    pattern = r"#### Current grouped-DMX source-detail limitation\n\n.*?Compact/auto-numbered ChannelGrid expansion is a separate later change and must not be combined with the first source-preservation patch\."
    replacement = """#### V7.0.11 grouped-DMX source-detail preservation

V7.0.11 preserves the existing Display/master relationship and universe/channel values and additionally stores the originating LOR Prop ID, Channel Name, and local Channel Grid Row Number on each `dmxChannels` row.

For a Display such as Mega Star, multiple source PropClasses can still share:

```text
PropClass.Comment = Mega Star
```

while retaining different Channel Names in `PropClass.Name` and separate local Channel Grid Rows. `dmxChannels.PropId` continues to identify the canonical Mega Star Display master; `dmxChannels.RawPropID`, `ChannelName`, and `ChannelGridRowNumber` preserve which source row supplied each DMX wiring relationship.

The existing eight DMX columns remain first and unchanged, and the legacy wiring-view shapes remain unchanged. The V7.0.11 implementation passed the focused grouped-DMX regression and the full 33-test Parser suite.

Compact/auto-numbered ChannelGrid expansion remains a separate later change and was not included in V7.0.11."""
    text = regex_once(text, pattern, replacement, "architecture grouped DMX implementation section")
    text = replace_once(
        text,
        "For the proposed grouped-DMX extension, `dmxChannels.RawPropID` would use the same source meaning — the originating LOR Prop ID — but as wiring-row provenance rather than as another physical Display master. That proposal remains unimplemented in V7.0.10.",
        "In V7.0.11, `dmxChannels.RawPropID` uses the same source meaning — the originating LOR Prop ID — as wiring-row provenance rather than as another physical Display master. It does not replace the canonical `dmxChannels.PropId` relationship.",
        "architecture RawPropID current behavior",
    )
    text = insert_revision(
        text,
        f"| 2026-08-21 | GAL / OpenAI | Documented implemented V7.0.11 grouped-DMX source preservation and successful 33-test validation; implementation commit `{IMPLEMENTATION_SHA[:7]}`. |",
        "architecture revision",
    )
    return text


def patch_sqlite(text: str) -> str:
    text = replace_once(text, "| Current Parser Baseline | V7.0.10 |", "| Current Parser Baseline | V7.0.11 |", "SQLite baseline")
    text = replace_once(text, "Current V7.0.10 responsibilities", "Current V7.0.11 responsibilities", "SQLite DMX responsibilities heading")
    text = replace_once(
        text,
        "- Preview identity;\n- parser materialization of DMX Channel Grid Rows.",
        "- Preview identity;\n- originating LOR Prop ID through `RawPropID`;\n- originating Channel Name through `ChannelName`;\n- local source Channel Grid Row Number through `ChannelGridRowNumber`;\n- parser materialization of DMX Channel Grid Rows.",
        "SQLite DMX responsibilities",
    )
    text = replace_once(text, "V7.0.10 intentionally chooses one canonical Display master", "V7.0.11 intentionally chooses one canonical Display master", "SQLite grouped DMX version")
    pattern = r"### Current V7\.0\.10 limitation\n\n.*?Compact/auto-numbered ChannelGrid expansion remains a separate change because it can intentionally alter materialized DMX row counts\."
    replacement = """### V7.0.11 source-detail preservation

V7.0.11 retains which source `PropClass` supplied each grouped DMX Channel Grid Row while preserving the existing canonical Display/master relationship.

Current appended fields are:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

| Current field | Meaning |
|---|---|
| `RawPropID` | originating LOR Prop ID (`PropClass.id`) that supplied the DMX Channel Grid Row |
| `ChannelName` | originating Channel Name (`PropClass.Name`) |
| `ChannelGridRowNumber` | 1-based source position of the nonblank serialized Channel Grid entry within that PropClass; numbering restarts for the next PropClass |

`PreviewId + RawPropID` identifies the originating source PropClass within the parser snapshot. `RawPropID` is wiring-row provenance and does not create another physical Display relationship or foreign key to `props`.

The original eight `dmxChannels` columns remain first and retain their V7.0.10 meanings. Existing compatibility views continue to use the canonical `PropId -> props.PropID` relationship and were regression-tested unchanged.

Compact/auto-numbered ChannelGrid expansion remains a separate change because it can intentionally alter materialized DMX row counts."""
    text = regex_once(text, pattern, replacement, "SQLite DMX implementation section")
    text = replace_once(text, "The proposed DMX source-detail fields do not replace either relationship.", "The V7.0.11 DMX source-detail fields do not replace either relationship.", "SQLite relationship wording")
    text = replace_once(text, "The first source-detail extension is intentionally designed so these existing view shapes and rows can remain unchanged during regression testing.", "The V7.0.11 source-detail extension leaves these existing view shapes and rows unchanged; the grouped-DMX regression fixture verifies that compatibility contract.", "SQLite view wording")
    text = replace_once(text, "The first grouped-DMX source-detail extension must preserve those existing compatibility view contracts unless a separately reviewed downstream change is approved.", "V7.0.11 preserves those existing compatibility view contracts; any later downstream view change requires separate review.", "SQLite compatibility wording")
    text = replace_once(
        text,
        "- **2026-08-21:** Documented the existing grouped-DMX `PropId -> props.PropID` contract, current loss of source LOR Prop ID / Channel Name / local Channel Grid Row Number, and the proposed additive source-detail fields while keeping V7.0.10 as the implemented schema baseline.",
        f"- **2026-08-21:** Promoted the grouped-DMX source-detail fields to the implemented V7.0.11 SQLite contract after the focused and full 33-test parser suites passed; implementation commit `{IMPLEMENTATION_SHA[:7]}`.\n- **2026-08-21:** Documented the pre-change grouped-DMX `PropId -> props.PropID` contract and the V7.0.10 source-detail gap before implementation.",
        "SQLite revision notes",
    )
    return text


def patch_xmlspec(text: str) -> str:
    text = replace_once(text, "Functional parser baseline:\n\n`V7.0.10`", "Functional parser baseline:\n\n`V7.0.11`", "XML spec parser baseline")
    text = replace_once(text, "Several DMX source PropClasses can share one Display Name (`PropClass.Comment`). V7.0.10 groups", "Several DMX source PropClasses can share one Display Name (`PropClass.Comment`). V7.0.11 groups", "XML spec grouped DMX version")
    pattern = r"### Current V7\.0\.10 source-detail limitation\n\n.*?\[FieldWiring Dense RGB DMX Additive Change Map\]\(\.\./\.\./02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21\.md\)\."
    replacement = """### V7.0.11 source-detail preservation

V7.0.11 keeps the canonical Display/master relationship and DMX addressing while also retaining which grouped source PropClass supplied each materialized row.

For each explicitly serialized DMX Channel Grid Row, `dmxChannels` now preserves:

```text
RawPropID             -> PropClass.id / LOR Prop ID
ChannelName           -> PropClass.Name / Channel Name
ChannelGridRowNumber  -> local source Channel Grid Row position
```

These fields are additive. `dmxChannels.PropId` still points to the canonical materialized Display master and is not repurposed as source provenance.

See [FieldWiring Dense RGB DMX Additive Change Map](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md) for the controlled implementation and regression boundary."""
    text = regex_once(text, pattern, replacement, "XML spec DMX implementation section")
    text = replace_once(
        text,
        "Do not flatten row numbering across all PropClasses that share one Display Name.",
        "Do not flatten row numbering across all PropClasses that share one Display Name. V7.0.11 increments the row number for each nonblank semicolon-delimited source entry before validating whether that entry has enough fields to materialize; a malformed nonblank source entry can therefore leave a gap. This is intentional because the number represents source position, not a synthetic count of successful database inserts.",
        "XML spec row-number source-position nuance",
    )
    text = insert_revision(
        text,
        f"| 2026-08-21 | GAL / OpenAI | Documented implemented V7.0.11 grouped-DMX source preservation, including source-position row-number semantics, after 33 parser tests passed; implementation commit `{IMPLEMENTATION_SHA[:7]}`. |",
        "XML spec revision",
    )
    return text


def patch_change_map(text: str) -> str:
    text = replace_once(text, "| Status | REGRESSION FIXTURE ADDED — NOT YET EXECUTED; NO PARSER CODE CHANGE |", "| Status | IMPLEMENTED AND TESTED — V7.0.11 SQLITE COMPLETE; POSTGRESQL PROPAGATION PENDING |", "change-map status")
    text = replace_once(text, "| Parser baseline | V7.0.10 |", "| Parser baseline | V7.0.11 |", "change-map parser baseline")
    text = replace_once(text, "This document records the exact proposed additive change boundary", "This document records the exact additive change boundary and implemented V7.0.11 result", "change-map purpose wording")
    text = replace_once(text, "It is a design/change map only. It does not describe an implemented schema change.", "It originated as the pre-implementation change map and now records the implemented SQLite V7.0.11 contract and its validation evidence. PostgreSQL propagation remains a separate later step.", "change-map implemented state")
    pattern = r"The pre-change grouped-DMX regression fixture is:\n\n- \[`test_parse_props_grouped_dmx\.py`\].*?Do not treat the baseline as test-proven until that fixture is run successfully against unchanged V7\.0\.10\."
    replacement = f"""The grouped-DMX regression fixture is:

- [`test_parse_props_grouped_dmx.py`](../../../01_LOR_System/02_Data_Extraction/Parser/test_parse_props_grouped_dmx.py)

Validation was executed manually from the repository working copy:

```text
V7.0.10 pre-change baseline fixture  -> 4 tests PASS
V7.0.11 focused grouped-DMX fixture  -> 4 tests PASS
V7.0.11 full Parser unittest discover -> 33 tests PASS
git diff --check                    -> clean
implementation commit               -> {IMPLEMENTATION_SHA}
```

The focused regression confirms the original canonical Display/master relationship, existing DMX row values, and compatibility-view output remain unchanged while the three source-detail fields are added."""
    text = regex_once(text, pattern, replacement, "change-map validation intro")
    text = replace_once(text, "Current V7.0.10 `dmxChannels` fields are:", "Pre-change V7.0.10 `dmxChannels` fields were:", "change-map prechange fields wording")
    text = replace_once(text, "The proposed change must not alter:", "V7.0.11 was required not to alter, and regression testing confirmed preservation of:", "change-map preserved contract")
    text = replace_once(text, "## Current Information Loss", "## Problem Addressed by V7.0.11", "change-map problem heading")
    text = replace_once(text, "V7.0.10 intentionally materializes", "V7.0.10 intentionally materialized", "change-map problem tense")
    text = replace_once(text, "After current grouped-DMX materialization", "Before V7.0.11 grouped-DMX source preservation", "change-map problem result tense")
    text = replace_once(text, "## Proposed Additive SQLite Fields", "## Implemented Additive SQLite Fields — V7.0.11", "change-map fields heading")
    text = replace_once(text, "| Proposed SQLite field | Human meaning | LOR XML source | Rule |", "| Implemented SQLite field | Human meaning | LOR XML source | Rule |", "change-map fields table")
    text = replace_once(text, "Proposed resulting table order:", "Current V7.0.11 table order:", "change-map table order")
    text = replace_once(text, "## Proposed Parser Population Rule", "## Implemented Parser Population Rule", "change-map population heading")
    pattern = r"## Parser Test Impact\n\n.*?## PostgreSQL Ingest Impact"
    replacement = f"""## Parser Test Impact

The controlled regression fixture is `Docs/01_LOR_System/02_Data_Extraction/Parser/test_parse_props_grouped_dmx.py`.

V7.0.11 validation proved:

1. multiple DMX `PropClass` rows sharing one Display Name still produce one canonical `props` master;
2. existing master selection and every legacy `dmxChannels.PropId` remain unchanged;
3. the original eight DMX columns stay first and retain their values;
4. `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` append after the legacy contract;
5. local row numbering restarts for each source PropClass;
6. the existing FormView-compatible wiring view keeps the same columns and rows;
7. the full Parser suite passes 33 tests.

Manual validation result: `33 tests PASS`; implementation commit `{IMPLEMENTATION_SHA}`.

The generic parser-output comparison still treats intentional table-schema changes as blocking when comparing different parser versions, so it is not a replacement for this semantic regression fixture.

## PostgreSQL Ingest Impact"""
    text = regex_once(text, pattern, replacement, "change-map parser tests current state")
    pattern = r"## Implementation Sequence After Approval\n\n```text\n.*?```\n\n## Stop Conditions"
    replacement = """## Next Validation / Propagation Sequence

```text
1. Build a new V7.0.11 SQLite snapshot from the approved Preview set.
2. Inspect real grouped/dense-RGB rows directly for Mega Star, Mega Cube, Mega Tree, and Whoville Matrix.
3. Confirm legacy wiring/report view output remains operational against the real snapshot.
4. If SQLite acceptance passes, add matching additive columns to `lor_snap.dmx_channels` and inspect `lor_snap.v_current_dmx_channels` before exposing them.
5. Validate PostgreSQL ingest without changing the canonical `prop_id` relationship or reconciliation identity path.
6. Build the FieldWiring read model from the accepted PostgreSQL source detail.
7. Review compact/auto-numbered ChannelGrid expansion as a separate controlled change.
```

## Stop Conditions"""
    text = regex_once(text, pattern, replacement, "change-map next sequence")
    text = text.replace("Also stop before parser implementation if the new baseline regression fixture has not been run successfully against V7.0.10.\n\n", "")
    text = insert_revision(
        text,
        f"| 2026-08-21 | GAL / OpenAI | Recorded implemented V7.0.11 SQLite source preservation, 4-test pre-change baseline PASS, 33-test full-suite PASS, clean diff check, and implementation commit `{IMPLEMENTATION_SHA[:7]}`. |",
        "change-map revision",
    )
    return text


def patch_checkpoint(text: str) -> str:
    text = replace_once(text, "| Status | REGRESSION FIXTURE ADDED — BASELINE RUN REQUIRED; NO PARSER CODE CHANGE YET |", "| Status | V7.0.11 IMPLEMENTED AND TESTED — SQLITE VALIDATION COMPLETE; POSTGRESQL PROPAGATION PENDING |", "checkpoint status")
    text = replace_once(text, "| Parser baseline | V7.0.10 |", "| Parser baseline | V7.0.11 |", "checkpoint parser baseline")
    pattern = r"The pre-change grouped-DMX regression fixture is now committed at:\n\n- \[Grouped-DMX V7\.0\.10 Regression Test\].*?No V7\.0\.10 parser code or schema has been changed yet\."
    replacement = f"""The grouped-DMX regression fixture is maintained at:

- [Grouped-DMX V7.0.11 Regression Test](../../../01_LOR_System/02_Data_Extraction/Parser/test_parse_props_grouped_dmx.py)

The original fixture first passed 4 tests against unchanged V7.0.10. After the additive parser change, the focused fixture again passed 4 tests and the complete Parser unittest discovery passed 33 tests. `git diff --check` was clean.

V7.0.11 implementation commit: `{IMPLEMENTATION_SHA}`."""
    text = regex_once(text, pattern, replacement, "checkpoint implementation validation intro")
    text = replace_once(text, "### Controlled proposed field names after inspection", "### Controlled implemented field names — V7.0.11", "checkpoint implemented field names")
    pattern = r"## Regression Fixture Added\n\n.*?## Required Regression Principle"
    replacement = f"""## Regression and Implementation Validation

The grouped-DMX regression fixture at `Docs/01_LOR_System/02_Data_Extraction/Parser/test_parse_props_grouped_dmx.py` first froze and passed the unchanged V7.0.10 behavior, then validated V7.0.11.

Validated results:

```text
pre-change V7.0.10 focused fixture -> 4 tests PASS
post-change V7.0.11 focused fixture -> 4 tests PASS
full Parser unittest discovery      -> 33 tests PASS
git diff --check                    -> clean
implementation commit               -> {IMPLEMENTATION_SHA}
```

The test preserves the canonical Display master, legacy DMX row values, and compatibility-view output while proving `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` are populated from the originating source PropClass/Channel Grid Row.

## Required Regression Principle"""
    text = regex_once(text, pattern, replacement, "checkpoint regression current state")
    pattern = r"## Next Engineering Step\n\n.*?## Related Durable Decisions"
    replacement = """## Next Engineering Step

The parser implementation/test gate is complete. The next gate is real-snapshot acceptance before PostgreSQL propagation:

```text
1. Run V7.0.11 against the approved Preview set and produce a new SQLite snapshot.
2. Inspect grouped/dense-RGB rows directly for Mega Star, Mega Cube, Mega Tree, and Whoville Matrix.
3. Confirm legacy FormView/wiring-view output remains operational against the real snapshot.
4. If SQLite acceptance passes, extend `lor_snap.dmx_channels` additively with matching PostgreSQL fields.
5. Inspect and control the authoritative `lor_snap.v_current_dmx_channels` definition before exposing the fields downstream.
6. Validate ingest and preserve the canonical `prop_id` / reconciliation identity chain.
7. Resume the FieldWiring PostgreSQL read model and browser presentation work.
8. Review compact/auto-numbered ChannelGrid expansion separately.
```

Broad FieldWiring UX work remains downstream of accepted dense-RGB data.

## Related Durable Decisions"""
    text = regex_once(text, pattern, replacement, "checkpoint next step")
    pattern = r"## Stop Point\n\nAt this updated checkpoint:\n\n.*?The next engineering action is to run the grouped-DMX baseline fixture against unchanged V7\.0\.10\."
    replacement = f"""## Stop Point

At this updated checkpoint:

- the V7.0.10 dependency inspection and baseline regression are complete;
- parser V7.0.11 is implemented on the feature branch;
- the original eight DMX columns and canonical `PropId` relationship remain unchanged;
- `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` are appended and regression-tested;
- the full Parser suite passes 33 tests and `git diff --check` is clean;
- implementation commit is `{IMPLEMENTATION_SHA}`;
- PostgreSQL `lor_snap.dmx_channels` has not yet been changed for these new fields;
- compact/auto-numbered ChannelGrid expansion remains separate.

The next engineering action is to build and inspect a real V7.0.11 SQLite snapshot from the approved Preview set before any PostgreSQL propagation."""
    text = regex_once(text, pattern, replacement, "checkpoint stop point")
    text = insert_revision(
        text,
        f"| 2026-08-21 | GAL / OpenAI | Recorded V7.0.11 implementation and validation: pre-change 4-test PASS, full 33-test PASS, clean diff check, implementation commit `{IMPLEMENTATION_SHA[:7]}`; advanced next gate to real SQLite snapshot acceptance before PostgreSQL propagation. |",
        "checkpoint revision",
    )
    return text


def patch_wiring_readme(text: str) -> str:
    text = replace_once(
        text,
        "Dense-RGB engineering recovery has now proven one parser data-preservation gap before the browser presentation layer can be considered complete: grouped DMX rows retain the canonical Display/master relationship but do not currently retain the originating LOR PropClass/Channel Name and local Channel Grid Row Number for every `dmxChannels` row. The exact additive change boundary is documented and **V7.0.10 remains unchanged**. A grouped-DMX baseline regression fixture has been added, but it must be run successfully against unchanged V7.0.10 before the parser/schema is modified.",
        "Dense-RGB engineering recovery has now implemented the additive parser source-preservation fix in V7.0.11. Grouped DMX rows retain the same canonical Display/master relationship and now also preserve the originating LOR Prop ID, Channel Name, and local Channel Grid Row Number in `dmxChannels`. The unchanged V7.0.10 baseline fixture passed first, the V7.0.11 focused regression passed, and the full Parser suite passed 33 tests. PostgreSQL propagation has not yet been performed.",
        "Wiring README current state",
    )
    text = replace_once(text, "[Grouped-DMX V7.0.10 Regression Test]", "[Grouped-DMX V7.0.11 Regression Test]", "Wiring README test label")
    pattern = r"Dense-RGB inspection has established and documented the current grouped-DMX information-loss boundary\..*?11\. preserve the future Channel Name -> 1/2-inch plug-label workflow as a controlled LabelPrintService integration rather than a manual printer-software task\."
    replacement = f"""Dense-RGB inspection established the grouped-DMX information-loss boundary and V7.0.11 now implements the approved additive source preservation. The canonical Display/master relationship remains unchanged while each explicit DMX Channel Grid Row carries `RawPropID`, `ChannelName`, and `ChannelGridRowNumber`.

Validation is complete at the parser-unit level: the pre-change V7.0.10 focused fixture passed 4 tests, V7.0.11 focused regression passed, and the full Parser suite passed 33 tests. Implementation commit: `{IMPLEMENTATION_SHA}`.

Current engineering focus is therefore **real V7.0.11 SQLite snapshot acceptance before PostgreSQL propagation**:

1. run V7.0.11 against the approved Preview set;
2. inspect Mega Star, Mega Cube, Mega Tree, and Whoville Matrix source-detail rows directly;
3. confirm existing FormView/wiring compatibility output remains operational;
4. after SQLite acceptance, propagate `raw_prop_id`, `channel_name`, and `channel_grid_row_number` additively into `lor_snap.dmx_channels` and inspect the current-snapshot DMX view contract;
5. preserve the existing PostgreSQL reconciliation identity path and canonical `prop_id` relationship;
6. resume the FieldWiring operator read/presentation layer using the accepted PostgreSQL source detail;
7. reuse the existing authenticated Display scan hub and permanent `display_id` entry;
8. resolve the correct Stage/Sub-stage/Scene and Background/Musical context;
9. classify the physical presentation family from current device/string metadata and Controller Inventory relationships; and
10. preserve the future Channel Name -> 1/2-inch plug-label workflow as a controlled LabelPrintService integration rather than a manual printer-software task."""
    text = regex_once(text, pattern, replacement, "Wiring README resume state")
    return text


PATCHERS = {
    "data_readme": patch_data_readme,
    "terms": patch_terms,
    "arch": patch_arch,
    "sqlite": patch_sqlite,
    "xmlspec": patch_xmlspec,
    "change_map": patch_change_map,
    "checkpoint": patch_checkpoint,
    "wiring_readme": patch_wiring_readme,
}


def main() -> None:
    assert_clean_start()

    originals = {key: read(path) for key, path in FILES.items()}
    patched: dict[str, str] = {}

    # Build every change in memory first. If any expected anchor is missing,
    # no documentation file is written.
    for key, text in originals.items():
        patched[key] = PATCHERS[key](text)

    for key, path in FILES.items():
        path.write_text(patched[key], encoding="utf-8", newline="")
        print(f"[OK] Updated: {path.relative_to(ROOT)}")

    if OLD_HELPER.exists():
        OLD_HELPER.unlink()
        print(f"[OK] Removed one-time parser patch helper: {OLD_HELPER.name}")

    # Self-remove so the closeout helper does not remain a normal project tool.
    SELF.unlink()
    print(f"[OK] Removed one-time documentation closeout helper: {SELF.name}")

    check = subprocess.run(["git", "diff", "--check"], cwd=ROOT, text=True)
    if check.returncode != 0:
        fail("git diff --check reported a problem")

    print("[OK] Documentation closeout applied; git diff --check clean.")
    print("[NEXT] Review git status and documentation diff before committing.")


if __name__ == "__main__":
    main()
