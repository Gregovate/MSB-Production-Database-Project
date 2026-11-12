"""Read-only live acceptance probe for shared Field Context hierarchy browse.

Engineering-only utility. It reads production PostgreSQL and the mounted
Display Folders tree, reports representative hierarchy cases, and compares a
normal FieldWiring package with the unchanged production API. It performs no
writes.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

APPLICATION = Path(__file__).resolve().parents[1] / "Application"
sys.path.insert(0, str(APPLICATION))

from field_context_browse import resolve_field_hierarchy
from field_context_repository import PostgresFieldContextRepository
from repository import PostgresRepository
from wiring import WiringError, build_wiring_package


def main() -> int:
    failures: list[str] = []

    def check(condition: bool, message: str) -> None:
        if condition:
            print("PASS:", message)
        else:
            print("FAIL:", message)
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
        if len(matches) != 1:
            failures.append(f"Expected exactly one normal Stage {key}; found {len(matches)}")
            print(f"FAIL: Stage {key} normal node count = {len(matches)}")
            return None
        return matches[0]

    def scene_labels(node):
        return [item["label"] for item in (node or {}).get("scenes", [])]

    def substage_labels(node):
        return [item["label"] for item in (node or {}).get("sub_stages", [])]

    print("--- hierarchy summary ---")
    print("normal Stage count:", len(stages))
    print("review-required count:", len(reviews))
    print("normal Stage keys:", [item.get("stage_key") for item in stages])

    print("\n--- Stage 15 Church ---")
    s15 = one_stage("15")
    if s15:
        print("label:", s15["label"])
        print("scope_root:", s15["scope_root"])
        print("scenes:", scene_labels(s15))
        print("root context count:", len(s15.get("contexts") or []))
        check(s15["label"] == "15-Church-Bells-CH", "Stage 15 uses actual folder label")
        check(scene_labels(s15) == [], "Stage 15 Master Musical/Root rows do not create child Scenes")
        check(len(s15.get("contexts") or []) >= 1, "Stage 15 retains root-binding context evidence")

    print("\n--- Stage 07 / Sub-stage 07a ---")
    s07 = one_stage("07")
    if s07:
        print("Stage label:", s07["label"])
        print("Stage scenes:", scene_labels(s07))
        print("Sub-stages:", substage_labels(s07))
        check(s07["label"] == "07-Whoville-WV", "Stage 07 uses actual top-level folder")
        check("07a-Who Forest-WF" in substage_labels(s07), "07a is nested beneath Stage 07")
        check("07-Who People" in scene_labels(s07), "07-Who People is a defined Stage 07 Scene")
        check("07-Who Spiral Tree" in scene_labels(s07), "07-Who Spiral Tree is a defined Stage 07 Scene")
        for item in s07.get("sub_stages", []):
            if item.get("label") == "07a-Who Forest-WF":
                print("07a scope_root:", item.get("scope_root"))
                print("07a scenes:", scene_labels(item))

    print("\n--- Stage 13 defined Scenes ---")
    s13 = one_stage("13")
    if s13:
        labels = scene_labels(s13)
        print("label:", s13["label"])
        print("scenes:", labels)
        expected = {
            "13-Christmas Story",
            "13-Christmas Vacation",
            "13-Christmas With the Kranks",
            "13-Nightmare Before Christmas",
        }
        check(set(labels) == expected, "Stage 13 exposes only the four defined marked child Scene scopes")
        check(not ({"13-Grover Train", "Die Hard", "Static Contactor", "Root"} & set(labels)), "Stage 13 raw LOR groups resolving to Stage root are not child Scenes")

    print("\n--- Stage 21 defined Scene ---")
    s21 = one_stage("21")
    if s21:
        labels = scene_labels(s21)
        print("label:", s21["label"])
        print("scenes:", labels)
        check(labels == ["21-SnowballBears"], "Stage 21 exposes only 21-SnowballBears as a child Scene")
        check("21-Sliding Penguins" not in labels, "21-Sliding Penguins collapses to Stage 21 root")

    print("\n--- Stage 25 root deduplication ---")
    s25 = one_stage("25")
    if s25:
        print("label:", s25["label"])
        print("scenes:", scene_labels(s25))
        print("root context count:", len(s25.get("contexts") or []))
        check(s25["label"] == "25-Racing Arches-RA", "Stage 25 uses actual folder label")
        check(scene_labels(s25) == [], "25-Racing Arches-RA LOR Scene does not duplicate the Stage root")

    print("\n--- Stage 39 / 40 alignment review ---")
    for key in ("39", "40"):
        normal = normal_stage(key)
        findings = [item for item in reviews if str(item.get("stage_key")) == key]
        print("Stage", key, "normal browse nodes:", len(normal))
        for item in normal:
            print(" normal:", item.get("label"), "|", item.get("scope_root"), "| DB:", item.get("database_stage_name"), item.get("database_folder_path"))
        print("Stage", key, "review findings:")
        for finding in findings:
            print(" ", finding.get("code"), "|", finding.get("scope_root"), "|", finding.get("database_folder_path"), "|", finding.get("warnings"))
        check(not normal, f"Stage {key} alignment conflict is not silently promoted into normal browse")
        check(bool(findings), f"Stage {key} alignment issue is surfaced for review")

    print("\n--- Stage 90-94 normal browse exclusion ---")
    for key in ("90", "91", "92", "93", "94"):
        normal = normal_stage(key)
        print(key, "normal nodes:", len(normal))
        check(not normal, f"Stage {key} is not a normal physical browse Stage")

    print("\n--- inventory Display 807 ---")
    c807 = shared.display_context(807)
    print("shared context:", c807)
    check(c807 is not None, "Display 807 resolves shared context")
    if c807:
        check(c807.get("display_name") == "RA-SteelArch-DS-F-03", "Display 807 identity preserved")
        check(str((c807.get("stage") or {}).get("stage_key")) == "25", "Display 807 remains bound to Stage 25")
    shared_ids = [item["display_id"] for item in shared.search_displays("RA-SteelArch-DS-F-03")]
    fw_ids = [item["display_id"] for item in fw.search_displays("RA-SteelArch-DS-F-03")]
    print("shared search:", shared_ids)
    print("FieldWiring search:", fw_ids)
    check(807 in shared_ids, "Shared search includes inventory Display 807")
    check(807 not in fw_ids, "FieldWiring search remains wiring-filtered")
    try:
        build_wiring_package(fw, display_id=807)
    except WiringError as exc:
        print("FieldWiring direct result:", str(exc))
        check(str(exc) == "No applicable field wiring is available for this Display", "Direct Display 807 FieldWiring request keeps explicit no-wiring result")
    else:
        check(False, "Display 807 must not unexpectedly produce a FieldWiring package")

    print("\n--- wired Display 312 candidate vs production ---")
    try:
        candidate = build_wiring_package(fw, display_id=312)
        with urllib.request.urlopen(
            "http://192.168.5.9:8790/api/wiring?display_id=312",
            timeout=10,
        ) as response:
            production = json.load(response)["wiring"]

        def comparable(package):
            return {
                "context": package["context"],
                "images": package["images"],
                "controller_groups": package["controller_groups"],
                "rows": package["rows"],
            }

        check(comparable(candidate) == comparable(production), "Display 312 candidate remains equivalent to production FieldWiring")
        print("scope_type:", candidate["images"]["scope_type"])
        print("scope_root:", candidate["images"]["scope_root"])
        print("wiring_images:", [item["name"] for item in candidate["images"]["wiring_images"]])
    except Exception as exc:
        print("FAIL: Display 312 equivalence raised:", repr(exc))
        failures.append("Display 312 FieldWiring equivalence could not complete")

    print("\n--- representative review findings ---")
    for finding in reviews:
        if str(finding.get("stage_key")) in {"05a", "07a", "39", "40", "90", "91", "92", "93", "94"}:
            print(
                finding.get("stage_key"),
                finding.get("code"),
                "|",
                finding.get("scope_root"),
                "|",
                finding.get("database_folder_path"),
                "|",
                finding.get("warnings"),
            )

    print("\n--- acceptance summary ---")
    if failures:
        print("LIVE ACCEPTANCE: REVIEW REQUIRED")
        for failure in failures:
            print(" -", failure)
        return 1

    print("SHARED FIELD HIERARCHY LIVE ACCEPTANCE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
