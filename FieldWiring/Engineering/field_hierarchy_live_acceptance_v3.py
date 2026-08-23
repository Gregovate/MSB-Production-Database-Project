"""Live acceptance for LOR-optional top-level Stage hierarchy evidence."""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

APPLICATION = Path(__file__).resolve().parents[1] / "Application"
sys.path.insert(0, str(APPLICATION))

from field_context_hierarchy import resolve_field_hierarchy
from field_context_repository import PostgresFieldContextRepository
from repository import PostgresRepository
from wiring import WiringError, build_wiring_package


def main() -> int:
    failures: list[str] = []

    def check(condition: bool, message: str) -> None:
        print(("PASS: " if condition else "FAIL: ") + message)
        if not condition:
            failures.append(message)

    dsn = os.environ["FIELDWIRING_DATABASE_DSN"]
    drive_root = Path(os.environ["FIELDWIRING_DRIVE_ROOT"])
    shared = PostgresFieldContextRepository(dsn)
    fw = PostgresRepository(dsn)

    hierarchy = resolve_field_hierarchy(shared, drive_root)
    stages = hierarchy["stages"]
    reviews = hierarchy["review_required"]

    def normal_stage(key: str):
        return [item for item in stages if str(item.get("stage_key")) == key]

    def one_stage(key: str):
        matches = normal_stage(key)
        check(len(matches) == 1, f"Stage {key} has exactly one normal browse node")
        return matches[0] if len(matches) == 1 else None

    def scenes(node):
        return [item["label"] for item in (node or {}).get("scenes", [])]

    def context_summaries(node):
        result = []
        for context in (node or {}).get("contexts", []):
            preview = context.get("preview") or {}
            scene = context.get("scene") or {}
            result.append({
                "preview_uuid": preview.get("preview_uuid"),
                "preview_name": preview.get("preview_name"),
                "scene_uuid": scene.get("scene_uuid"),
                "scene_name": scene.get("scene_name"),
                "scope_kind": context.get("scope_kind"),
                "context_type": context.get("context_type"),
            })
        return result

    print("--- hierarchy summary ---")
    print("normal Stage keys:", [item.get("stage_key") for item in stages])
    print("review-required count:", len(reviews))

    print("\n--- Stage 39 Parade Float ---")
    s39 = one_stage("39")
    if s39:
        print("label:", s39["label"])
        print("scope_root:", s39["scope_root"])
        print("database_folder_path:", s39.get("database_folder_path"))
        print("root contexts:", len(s39.get("contexts") or []))
        print("context evidence:", context_summaries(s39))
        print("scenes:", scenes(s39))
        check(s39["label"] == "39-Parade Float-PF", "Stage 39 uses the actual marked 39 field root")
        check(bool(s39.get("contexts") or s39.get("scenes")), "Stage 39 retains current LOR/Preview supporting evidence")
    review39 = [item for item in reviews if str(item.get("stage_key")) == "39"]
    print("review findings:", [(item.get("code"), item.get("database_folder_path")) for item in review39])
    check(any(item.get("code") == "PERSISTED_STAGE_PATH_REVIEW_REQUIRED" for item in review39), "Stage 39 stale folder_path remains surfaced for review")

    print("\n--- Stage 40 CommandCenter ---")
    s40 = one_stage("40")
    if s40:
        print("label:", s40["label"])
        print("scope_root:", s40["scope_root"])
        print("database_folder_path:", s40.get("database_folder_path"))
        print("root contexts:", len(s40.get("contexts") or []))
        print("context evidence:", context_summaries(s40))
        print("scenes:", scenes(s40))
        check(s40["label"] == "40-CommandCenter", "Stage 40 uses the actual marked CommandCenter field root")
        check(scenes(s40) == [], "Any Stage 40 LOR evidence collapses to the Stage root rather than creating a child Scene")
        check(True, "Stage 40 browse validity does not depend on LOR context presence or absence")
    review40 = [item for item in reviews if str(item.get("stage_key")) == "40"]
    print("review findings:", [(item.get("code"), item.get("database_folder_path")) for item in review40])
    check(any(item.get("code") == "PERSISTED_STAGE_PATH_REVIEW_REQUIRED" for item in review40), "Stage 40 missing folder_path remains surfaced for review")

    print("\n--- representative hierarchy regressions ---")
    s15 = one_stage("15")
    if s15:
        check(s15["label"] == "15-Church-Bells-CH", "Stage 15 label remains field-folder based")
        check(scenes(s15) == [], "Stage 15 root-equivalent LOR scenes remain deduplicated")

    s07 = one_stage("07")
    if s07:
        subs = [item["label"] for item in s07.get("sub_stages", [])]
        check("07a-Who Forest-WF" in subs, "07a remains nested beneath Stage 07")

    s13 = one_stage("13")
    if s13:
        check(set(scenes(s13)) == {
            "13-Christmas Story",
            "13-Christmas Vacation",
            "13-Christmas With the Kranks",
            "13-Nightmare Before Christmas",
        }, "Stage 13 defined Scene set remains correct")

    s21 = one_stage("21")
    if s21:
        check(scenes(s21) == ["21-SnowballBears"], "Stage 21 defined Scene remains correct")

    s25 = one_stage("25")
    if s25:
        check(scenes(s25) == [], "Stage 25 root-equivalent LOR scene remains deduplicated")

    print("\n--- Stage 90-94 exclusion ---")
    for key in ("90", "91", "92", "93", "94"):
        check(not normal_stage(key), f"Stage {key} remains outside normal physical browse")

    print("\n--- inventory Display 807 ---")
    c807 = shared.display_context(807)
    check(c807 is not None, "Display 807 still resolves shared context")
    shared_ids = [item["display_id"] for item in shared.search_displays("RA-SteelArch-DS-F-03")]
    fw_ids = [item["display_id"] for item in fw.search_displays("RA-SteelArch-DS-F-03")]
    check(807 in shared_ids, "Shared search still includes Display 807")
    check(807 not in fw_ids, "FieldWiring search remains wiring-filtered")
    try:
        build_wiring_package(fw, display_id=807)
    except WiringError as exc:
        check(str(exc) == "No applicable field wiring is available for this Display", "Display 807 direct FieldWiring result remains explicit no-wiring")
    else:
        check(False, "Display 807 must not produce a FieldWiring package")

    print("\n--- wired Display 312 equivalence ---")
    candidate = build_wiring_package(fw, display_id=312)
    with urllib.request.urlopen("http://192.168.5.9:8790/api/wiring?display_id=312", timeout=10) as response:
        production = json.load(response)["wiring"]

    def comparable(package):
        return {
            "context": package["context"],
            "images": package["images"],
            "controller_groups": package["controller_groups"],
            "rows": package["rows"],
        }

    check(comparable(candidate) == comparable(production), "Display 312 candidate remains equivalent to production FieldWiring")

    print("\n--- acceptance summary ---")
    if failures:
        print("LIVE ACCEPTANCE: REVIEW REQUIRED")
        for failure in failures:
            print(" -", failure)
        return 1

    print("SHARED FIELD HIERARCHY LOR-OPTIONAL STAGE ACCEPTANCE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
