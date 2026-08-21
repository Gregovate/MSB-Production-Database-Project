"""Apply the reviewed V7.0.11 grouped-DMX source-preservation patch locally.

This is a temporary, hash-by-contract patch helper for the canonical parser.
It exists because the parser is a large mission-critical single file and the
remote repository interface replaces whole files rather than applying line
patches. The helper makes only the reviewed additive changes and aborts if the
expected V7.0.10 anchors are not present exactly once.

Scope:
- append RawPropID, ChannelName, ChannelGridRowNumber to dmxChannels;
- preserve existing dmxChannels.PropId and all existing DMX field values;
- populate the new fields from the originating DMX PropClass/ChannelGrid row;
- bump the canonical parser to V7.0.11;
- advance the grouped-DMX regression fixture to validate the additive result.

It does NOT:
- expand compact/auto-numbered ChannelGrid rows;
- change grouped-DMX master selection;
- change compatibility views;
- change PostgreSQL ingest/schema;
- change reconciliation identity.

Run from this Parser directory after pulling the latest feature branch:
    python apply_dense_rgb_dmx_v7011_patch.py

The helper writes timestamped .bak copies before modifying either file and then
runs the focused grouped-DMX regression test. It does not commit or push.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
import shutil
import subprocess
import sys


HERE = Path(__file__).resolve().parent
PARSER = HERE / "parse_props_v7_scene_parser.py"
TEST = HERE / "test_parse_props_grouped_dmx.py"


def fail(message: str) -> None:
    raise SystemExit(f"[FATAL] {message}")


def detect_newline(raw: bytes) -> str:
    return "\r\n" if b"\r\n" in raw else "\n"


def read_exact(path: Path) -> tuple[str, str]:
    raw = path.read_bytes()
    return raw.decode("utf-8"), detect_newline(raw)


def block(text: str, newline: str) -> str:
    return text.replace("\n", newline)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        fail(f"{label}: expected exactly one V7.0.10 anchor, found {count}")
    return text.replace(old, new, 1)


def backup(path: Path, timestamp: str) -> Path:
    out = path.with_name(f"{path.name}.pre-v7.0.11-{timestamp}.bak")
    shutil.copy2(path, out)
    print(f"[OK] Backup: {out.name}")
    return out


def patch_parser() -> None:
    text, nl = read_exact(PARSER)

    if 'PARSER_VERSION = "V7.0.11"' in text:
        fail("Parser already reports V7.0.11; refusing to reapply patch")
    if 'PARSER_VERSION = "V7.0.10"' not in text:
        fail("Canonical parser is not the expected V7.0.10 baseline")
    if "ChannelGridRowNumber INTEGER" in text:
        fail("dmxChannels already contains ChannelGridRowNumber")

    # Header and runtime version.
    text = replace_once(
        text,
        block("# Current Version : 2026-08-13  V7.0.10", nl),
        block("# Current Version : 2026-08-21  V7.0.11", nl),
        "header version",
    )
    text = replace_once(
        text,
        block('PARSER_VERSION = "V7.0.10"  # GAL 2026-08-13: authoritative runtime version', nl),
        block('PARSER_VERSION = "V7.0.11"  # GAL 2026-08-21: additive grouped-DMX source preservation', nl),
        "runtime version",
    )

    changelog_anchor = block("# Changelog\n# ---------\n", nl)
    changelog = block(
        "# Changelog\n"
        "# ---------\n"
        "## 2026-08-21  V7.0.11  (GAL / OpenAI)\n"
        "# • Additive grouped-DMX source preservation in dmxChannels.\n"
        "# • Appended RawPropID, ChannelName, and ChannelGridRowNumber after the\n"
        "#   existing eight DMX columns; existing column order/meanings remain unchanged.\n"
        "# • Preserve the originating PropClass.id, PropClass.Name, and 1-based local\n"
        "#   ChannelGrid row number for each explicitly serialized DMX wiring row.\n"
        "# • Preserve grouped-DMX canonical master selection and dmxChannels.PropId.\n"
        "# • Compact/auto-numbered ChannelGrid expansion remains out of scope.\n"
        "#\n",
        nl,
    )
    text = replace_once(text, changelog_anchor, changelog, "changelog")

    # Keep the inline naming map aligned with the durable terminology contract.
    text = replace_once(
        text,
        block(
            "#   DMX grid (universe) → dmxChannels.(Network, StartUniverse, StartChannel, EndChannel, Unknown)",
            nl,
        ),
        block(
            "#   DMX grid (universe) → dmxChannels.(Network, StartUniverse, StartChannel, EndChannel, Unknown)\n"
            "#   DMX source detail    → dmxChannels.(RawPropID, ChannelName, ChannelGridRowNumber)",
            nl,
        ),
        "inline DMX field map",
    )

    # Additive schema only: append three fields after the existing eight.
    old_schema = block(
        "    CREATE TABLE dmxChannels (\n"
        "        IntDMXChannelID INTEGER PRIMARY KEY AUTOINCREMENT,\n"
        "        PropId TEXT,\n"
        "        Network TEXT,\n"
        "        StartUniverse INTEGER,\n"
        "        StartChannel INTEGER,\n"
        "        EndChannel INTEGER,\n"
        "        Unknown TEXT,\n"
        "        PreviewId TEXT,\n"
        "        FOREIGN KEY (PropId) REFERENCES props (PropID),\n"
        "        FOREIGN KEY (PreviewId) REFERENCES previews (id)\n"
        "    );",
        nl,
    )
    new_schema = block(
        "    CREATE TABLE dmxChannels (\n"
        "        IntDMXChannelID INTEGER PRIMARY KEY AUTOINCREMENT,\n"
        "        PropId TEXT,\n"
        "        Network TEXT,\n"
        "        StartUniverse INTEGER,\n"
        "        StartChannel INTEGER,\n"
        "        EndChannel INTEGER,\n"
        "        Unknown TEXT,\n"
        "        PreviewId TEXT,\n"
        "        RawPropID TEXT,\n"
        "        ChannelName TEXT,\n"
        "        ChannelGridRowNumber INTEGER,\n"
        "        FOREIGN KEY (PropId) REFERENCES props (PropID),\n"
        "        FOREIGN KEY (PreviewId) REFERENCES previews (id)\n"
        "    );",
        nl,
    )
    text = replace_once(text, old_schema, new_schema, "dmxChannels CREATE TABLE")

    # Preserve the source PropClass and a 1-based row number local to that PropClass.
    old_grid = block(
        "        # Parse ChannelGrid into legs\n"
        "        legs = []\n"
        "        cg = norm(prop.get(\"ChannelGrid\"))\n"
        "        if cg:\n"
        "            for seg in cg.split(\";\"):\n"
        "                seg = seg.strip()\n"
        "                if not seg:\n"
        "                    continue\n"
        "                parts = [p.strip() for p in seg.split(\",\")]\n"
        "                if len(parts) >= 5:\n"
        "                    legs.append({\n"
        "                        \"Network\": parts[0],\n"
        "                        \"StartUniverse\": safe_int(parts[1], 0),\n"
        "                        \"StartChannel\":  safe_int(parts[2], 0),\n"
        "                        \"EndChannel\":    safe_int(parts[3], 0),\n"
        "                        \"Unknown\":       parts[4],\n"
        "                    })",
        nl,
    )
    new_grid = block(
        "        # Parse ChannelGrid into legs. Channel Grid Row Number is local\n"
        "        # to this source PropClass and restarts at 1 for the next PropClass.\n"
        "        legs = []\n"
        "        cg = norm(prop.get(\"ChannelGrid\"))\n"
        "        if cg:\n"
        "            channel_grid_row_number = 0\n"
        "            for seg in cg.split(\";\"):\n"
        "                seg = seg.strip()\n"
        "                if not seg:\n"
        "                    continue\n"
        "                channel_grid_row_number += 1\n"
        "                parts = [p.strip() for p in seg.split(\",\")]\n"
        "                if len(parts) >= 5:\n"
        "                    legs.append({\n"
        "                        \"Network\": parts[0],\n"
        "                        \"StartUniverse\": safe_int(parts[1], 0),\n"
        "                        \"StartChannel\":  safe_int(parts[2], 0),\n"
        "                        \"EndChannel\":    safe_int(parts[3], 0),\n"
        "                        \"Unknown\":       parts[4],\n"
        "                        \"RawPropID\":     raw_id,\n"
        "                        \"ChannelName\":   prop.get(\"Name\"),\n"
        "                        \"ChannelGridRowNumber\": channel_grid_row_number,\n"
        "                    })",
        nl,
    )
    text = replace_once(text, old_grid, new_grid, "DMX ChannelGrid collection")

    old_insert = block(
        "                cur.execute(\"\"\"\n"
        "                    INSERT OR REPLACE INTO dmxChannels (\n"
        "                        PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId\n"
        "                    ) VALUES (?, ?, ?, ?, ?, ?, ?)\n"
        "                \"\"\", (\n"
        "                    master[\"PropID\"], leg[\"Network\"], leg[\"StartUniverse\"],\n"
        "                    leg[\"StartChannel\"], leg[\"EndChannel\"], leg[\"Unknown\"], preview_id\n"
        "                ))",
        nl,
    )
    new_insert = block(
        "                cur.execute(\"\"\"\n"
        "                    INSERT OR REPLACE INTO dmxChannels (\n"
        "                        PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId,\n"
        "                        RawPropID, ChannelName, ChannelGridRowNumber\n"
        "                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)\n"
        "                \"\"\", (\n"
        "                    master[\"PropID\"], leg[\"Network\"], leg[\"StartUniverse\"],\n"
        "                    leg[\"StartChannel\"], leg[\"EndChannel\"], leg[\"Unknown\"], preview_id,\n"
        "                    leg[\"RawPropID\"], leg[\"ChannelName\"], leg[\"ChannelGridRowNumber\"]\n"
        "                ))",
        nl,
    )
    text = replace_once(text, old_insert, new_insert, "DMX insert")

    text = replace_once(
        text,
        block(
            "              - Insert a row into `dmxChannels` with (PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown).",
            nl,
        ),
        block(
            "              - Insert a row into `dmxChannels` with the existing Display/master and universe/channel values.\n"
            "              - Also preserve RawPropID, ChannelName, and local ChannelGridRowNumber from the originating PropClass.",
            nl,
        ),
        "process_dmx_props documentation",
    )

    PARSER.write_bytes(text.encode("utf-8"))
    print("[OK] Patched canonical parser to V7.0.11")


def patch_test() -> None:
    text, nl = read_exact(TEST)

    if "GroupedDMXV7011RegressionTests" in text:
        fail("Grouped-DMX test already reports V7.0.11; refusing to reapply patch")
    if "GroupedDMXV7010RegressionTests" not in text:
        fail("Grouped-DMX test is not the expected V7.0.10 baseline fixture")

    text = replace_once(
        text,
        block('"""Regression tests for the V7.0.10 grouped-DMX materialization contract.', nl),
        block('"""Regression tests for the V7.0.11 additive grouped-DMX contract.', nl),
        "test module title",
    )
    text = replace_once(
        text,
        block(
            "These tests intentionally capture the pre-extension behavior before the dense-RGB\n"
            "source-detail fields are added. They protect the existing canonical Display/master\n"
            "relationship, existing DMX row values, and compatibility-view output.",
            nl,
        ),
        block(
            "These tests preserve the V7.0.10 canonical Display/master and legacy DMX values\n"
            "while validating the three V7.0.11 additive source-detail fields. Existing\n"
            "compatibility-view output must remain unchanged.",
            nl,
        ),
        "test module scope",
    )
    text = replace_once(
        text,
        block(
            "# The fixture also records the source mapping that the additive extension must\n"
            "# preserve later. V7.0.10 does not yet store these three values in dmxChannels.",
            nl,
        ),
        block(
            "# Expected source mapping now materialized by V7.0.11 in dmxChannels.\n"
            "# Channel Grid Row Number is 1-based and restarts for each PropClass.",
            nl,
        ),
        "test source-detail comment",
    )
    text = replace_once(
        text,
        "class GroupedDMXV7010RegressionTests(unittest.TestCase):",
        "class GroupedDMXV7011RegressionTests(unittest.TestCase):",
        "test class name",
    )
    text = replace_once(
        text,
        '    """Freeze the existing grouped-DMX contract before additive extension."""',
        '    """Protect the V7.0.10 contract while validating V7.0.11 additions."""',
        "test class docstring",
    )

    old_schema_test = block(
        "    def test_v7010_dmx_schema_is_frozen_before_additive_extension(self) -> None:\n"
        "        \"\"\"Record the exact pre-change dmxChannels table contract.\"\"\"\n"
        "        with closing(sqlite3.connect(self.database)) as connection:\n"
        "            columns = [\n"
        "                row[1]\n"
        "                for row in connection.execute(\"PRAGMA table_info(dmxChannels)\").fetchall()\n"
        "            ]\n"
        "\n"
        "        self.assertEqual(\n"
        "            columns,\n"
        "            [\n"
        "                \"IntDMXChannelID\",\n"
        "                \"PropId\",\n"
        "                \"Network\",\n"
        "                \"StartUniverse\",\n"
        "                \"StartChannel\",\n"
        "                \"EndChannel\",\n"
        "                \"Unknown\",\n"
        "                \"PreviewId\",\n"
        "            ],\n"
        "        )\n"
        "        self.assertNotIn(\"RawPropID\", columns)\n"
        "        self.assertNotIn(\"ChannelName\", columns)\n"
        "        self.assertNotIn(\"ChannelGridRowNumber\", columns)",
        nl,
    )
    new_schema_test = block(
        "    def test_v7011_dmx_schema_appends_source_detail_after_legacy_contract(self) -> None:\n"
        "        \"\"\"Existing eight columns stay first; three source-detail fields append.\"\"\"\n"
        "        with closing(sqlite3.connect(self.database)) as connection:\n"
        "            columns = [\n"
        "                row[1]\n"
        "                for row in connection.execute(\"PRAGMA table_info(dmxChannels)\").fetchall()\n"
        "            ]\n"
        "\n"
        "        legacy_columns = [\n"
        "            \"IntDMXChannelID\",\n"
        "            \"PropId\",\n"
        "            \"Network\",\n"
        "            \"StartUniverse\",\n"
        "            \"StartChannel\",\n"
        "            \"EndChannel\",\n"
        "            \"Unknown\",\n"
        "            \"PreviewId\",\n"
        "        ]\n"
        "        self.assertEqual(columns[:8], legacy_columns)\n"
        "        self.assertEqual(\n"
        "            columns[8:],\n"
        "            [\"RawPropID\", \"ChannelName\", \"ChannelGridRowNumber\"],\n"
        "        )",
        nl,
    )
    text = replace_once(text, old_schema_test, new_schema_test, "schema regression test")

    old_detail_test = block(
        "    def test_fixture_records_future_source_detail_without_changing_v7010(self) -> None:\n"
        "        \"\"\"Keep the agreed future row mapping beside the frozen baseline fixture.\"\"\"\n"
        "        self.assertEqual(\n"
        "            EXPECTED_SOURCE_DETAIL,\n"
        "            [\n"
        "                (PROP_A_RAW_ID, \"MS Long Spire 1 4x150\", 1, 113),\n"
        "                (PROP_A_RAW_ID, \"MS Long Spire 1 4x150\", 2, 114),\n"
        "                (PROP_A_RAW_ID, \"MS Long Spire 1 4x150\", 3, 115),\n"
        "                (PROP_A_RAW_ID, \"MS Long Spire 1 4x150\", 4, 116),\n"
        "                (PROP_B_RAW_ID, \"MS Short Spire 1 2x150\", 1, 129),\n"
        "                (PROP_B_RAW_ID, \"MS Short Spire 1 2x150\", 2, 130),\n"
        "            ],\n"
        "        )",
        nl,
    )
    new_detail_test = block(
        "    def test_grouped_dmx_preserves_lor_prop_channel_name_and_local_grid_row(self) -> None:\n"
        "        \"\"\"Every DMX row retains its originating PropClass and local row.\"\"\"\n"
        "        self._materialize()\n"
        "\n"
        "        with closing(sqlite3.connect(self.database)) as connection:\n"
        "            rows = connection.execute(\n"
        "                \"\"\"\n"
        "                SELECT RawPropID, ChannelName, ChannelGridRowNumber, StartUniverse\n"
        "                FROM dmxChannels\n"
        "                ORDER BY StartUniverse, StartChannel, IntDMXChannelID\n"
        "                \"\"\"\n"
        "            ).fetchall()\n"
        "\n"
        "        self.assertEqual(rows, EXPECTED_SOURCE_DETAIL)",
        nl,
    )
    text = replace_once(text, old_detail_test, new_detail_test, "source-detail regression test")

    TEST.write_bytes(text.encode("utf-8"))
    print("[OK] Advanced grouped-DMX regression fixture to V7.0.11")


def main() -> int:
    for path in (PARSER, TEST):
        if not path.is_file():
            fail(f"Required file not found: {path}")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup(PARSER, timestamp)
    backup(TEST, timestamp)

    patch_parser()
    patch_test()

    print("[INFO] Running focused grouped-DMX regression tests...")
    completed = subprocess.run(
        [sys.executable, "-m", "unittest", "test_parse_props_grouped_dmx.py", "-v"],
        cwd=HERE,
        check=False,
    )
    if completed.returncode != 0:
        print("[FAIL] V7.0.11 patch applied locally but focused regression test failed.")
        print("       Do not commit. Inspect the failure and the timestamped backups.")
        return completed.returncode

    print("[OK] V7.0.11 focused grouped-DMX regression passed.")
    print("[NEXT] Review git diff before committing or pushing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
