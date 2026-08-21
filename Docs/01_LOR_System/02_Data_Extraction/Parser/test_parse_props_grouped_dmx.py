"""Regression tests for the V7.0.10 grouped-DMX materialization contract.

These tests intentionally capture the pre-extension behavior before the dense-RGB
source-detail fields are added. They protect the existing canonical Display/master
relationship, existing DMX row values, and compatibility-view output.

The proposed additive fields are documented in:
Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/
FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md

Do not change the legacy expectations in this file merely to make a future parser
change pass. If the existing relationship or values change, review the architecture.
"""

from __future__ import annotations

from contextlib import closing
import sqlite3
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import parse_props_v7_scene_parser as parser


PREVIEW_ID = "11111111-1111-4111-8111-111111111111"
PROP_A_RAW_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
PROP_B_RAW_ID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

# The fixture also records the source mapping that the additive extension must
# preserve later. V7.0.10 does not yet store these three values in dmxChannels.
EXPECTED_SOURCE_DETAIL = [
    (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 1, 113),
    (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 2, 114),
    (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 3, 115),
    (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 4, 116),
    (PROP_B_RAW_ID, "MS Short Spire 1 2x150", 1, 129),
    (PROP_B_RAW_ID, "MS Short Spire 1 2x150", 2, 130),
]

GROUPED_DMX_XML = f"""<?xml version="1.0"?>
<PreviewClass id="{PREVIEW_ID}" Name="Dense RGB Test Preview">
  <PropClass
      id="{PROP_A_RAW_ID}"
      Name="MS Long Spire 1 4x150"
      Comment="Mega Star"
      DeviceType="DMX"
      ChannelGrid="DMX,113,1,510,0;DMX,114,1,510,0;DMX,115,1,510,0;DMX,116,1,510,0"
      Parm2="600" />
  <PropClass
      id="{PROP_B_RAW_ID}"
      Name="MS Short Spire 1 2x150"
      Comment="Mega Star"
      DeviceType="DMX"
      ChannelGrid="DMX,129,1,510,0;DMX,130,1,510,0"
      Parm2="300" />
</PreviewClass>
"""


class GroupedDMXV7010RegressionTests(unittest.TestCase):
    """Freeze the existing grouped-DMX contract before additive extension."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.database = self.root / "grouped-dmx-v7010.db"

        self.original_db_file = parser.DB_FILE
        self.original_reports_dir = parser.REPORTS_DIR
        self.original_db_path = getattr(parser, "DB_PATH", None)

        parser.DB_FILE = self.database
        parser.REPORTS_DIR = self.root / "reports"
        if hasattr(parser, "DB_PATH"):
            parser.DB_PATH = self.database

        # Keep collision state isolated if another parser test imported the module
        # first in the same unittest process.
        for name in ("_PROPID_COLLISIONS", "_SUBPROPID_COLLISIONS"):
            value = getattr(parser, name, None)
            if hasattr(value, "clear"):
                value.clear()

        parser.setup_database()
        with closing(sqlite3.connect(self.database)) as connection:
            connection.execute(
                "INSERT INTO previews (id, Name) VALUES (?, ?)",
                (PREVIEW_ID, "Dense RGB Test Preview"),
            )
            connection.commit()

    def tearDown(self) -> None:
        parser.DB_FILE = self.original_db_file
        parser.REPORTS_DIR = self.original_reports_dir
        if hasattr(parser, "DB_PATH"):
            parser.DB_PATH = self.original_db_path

    def _materialize(self) -> None:
        root = ET.fromstring(GROUPED_DMX_XML)
        parser.process_dmx_props(PREVIEW_ID, root)

    def test_grouped_dmx_preserves_one_canonical_master_and_all_legacy_rows(self) -> None:
        """Two Channel Names sharing one Display Name remain one Display master."""
        self._materialize()

        expected_master = parser.scoped_id(PREVIEW_ID, PROP_A_RAW_ID)
        with closing(sqlite3.connect(self.database)) as connection:
            props_rows = connection.execute(
                """
                SELECT PropID, RawPropID, Name, LORComment, DeviceType
                FROM props
                ORDER BY PropID
                """
            ).fetchall()
            dmx_rows = connection.execute(
                """
                SELECT PropId, Network, StartUniverse, StartChannel,
                       EndChannel, Unknown, PreviewId
                FROM dmxChannels
                ORDER BY StartUniverse, StartChannel, IntDMXChannelID
                """
            ).fetchall()

        self.assertEqual(
            props_rows,
            [
                (
                    expected_master,
                    PROP_A_RAW_ID,
                    "MS Long Spire 1 4x150",
                    "Mega Star",
                    "DMX",
                )
            ],
        )
        self.assertEqual(
            dmx_rows,
            [
                (expected_master, "DMX", 113, 1, 510, "0", PREVIEW_ID),
                (expected_master, "DMX", 114, 1, 510, "0", PREVIEW_ID),
                (expected_master, "DMX", 115, 1, 510, "0", PREVIEW_ID),
                (expected_master, "DMX", 116, 1, 510, "0", PREVIEW_ID),
                (expected_master, "DMX", 129, 1, 510, "0", PREVIEW_ID),
                (expected_master, "DMX", 130, 1, 510, "0", PREVIEW_ID),
            ],
        )

    def test_v7010_dmx_schema_is_frozen_before_additive_extension(self) -> None:
        """Record the exact pre-change dmxChannels table contract."""
        with closing(sqlite3.connect(self.database)) as connection:
            columns = [
                row[1]
                for row in connection.execute("PRAGMA table_info(dmxChannels)").fetchall()
            ]

        self.assertEqual(
            columns,
            [
                "IntDMXChannelID",
                "PropId",
                "Network",
                "StartUniverse",
                "StartChannel",
                "EndChannel",
                "Unknown",
                "PreviewId",
            ],
        )
        self.assertNotIn("RawPropID", columns)
        self.assertNotIn("ChannelName", columns)
        self.assertNotIn("ChannelGridRowNumber", columns)

    def test_existing_wiring_view_remains_canonical_master_output(self) -> None:
        """Freeze the FormView-compatible DMX projection before extension."""
        self._materialize()
        parser.create_wiring_views_v6(self.database)

        with closing(sqlite3.connect(self.database)) as connection:
            columns = [
                row[1]
                for row in connection.execute(
                    "PRAGMA table_info(preview_wiring_map_v6)"
                ).fetchall()
            ]
            rows = connection.execute(
                """
                SELECT PreviewName, DisplayName, LORName, Network, Controller,
                       StartChannel, EndChannel, DeviceType, Source, LORTag
                FROM preview_wiring_map_v6
                WHERE Source = 'DMX'
                ORDER BY CAST(Controller AS INTEGER), StartChannel
                """
            ).fetchall()

        self.assertEqual(
            columns,
            [
                "PreviewName",
                "DisplayName",
                "LORName",
                "Network",
                "Controller",
                "StartChannel",
                "EndChannel",
                "DeviceType",
                "Source",
                "LORTag",
            ],
        )
        self.assertEqual(len(rows), len(EXPECTED_SOURCE_DETAIL))
        self.assertEqual(
            rows,
            [
                (
                    "Dense RGB Test Preview",
                    "Mega-Star",
                    "MS Long Spire 1 4x150",
                    "DMX",
                    str(universe),
                    1,
                    510,
                    "DMX",
                    "DMX",
                    None,
                )
                for universe in (113, 114, 115, 116, 129, 130)
            ],
        )

        # This is intentionally the V7.0.10 limitation: the legacy view can only
        # show the canonical master's Channel Name for all grouped DMX rows.
        self.assertEqual({row[2] for row in rows}, {"MS Long Spire 1 4x150"})

    def test_fixture_records_future_source_detail_without_changing_v7010(self) -> None:
        """Keep the agreed future row mapping beside the frozen baseline fixture."""
        self.assertEqual(
            EXPECTED_SOURCE_DETAIL,
            [
                (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 1, 113),
                (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 2, 114),
                (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 3, 115),
                (PROP_A_RAW_ID, "MS Long Spire 1 4x150", 4, 116),
                (PROP_B_RAW_ID, "MS Short Spire 1 2x150", 1, 129),
                (PROP_B_RAW_ID, "MS Short Spire 1 2x150", 2, 130),
            ],
        )


if __name__ == "__main__":
    unittest.main()
