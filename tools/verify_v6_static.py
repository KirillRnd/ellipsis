#!/usr/bin/env python3
"""Static verification for the Ellipse 6.0 development sandbox.

This intentionally does not launch Godot. It validates source structure,
accepted resonance assets, input actions and scene routing.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
BUNDLE = ROOT / "ellipse_resonances_exact_restore_v1_bundle"
ASSETS = BUNDLE / "accepted_assets"

EXPECTED_PAIRS = {
    "0:0": "ff",
    "0:1": "fs",
    "1:1": "ss",
    "1:2": "sg",
    "2:2": "gg",
    "2:3": "zg",
    "3:3": "zz",
    "3:4": "yz",
    "4:4": "yy",
    "4:5": "gy",
    "5:5": "gold_gold",
    "5:6": "kg",
    "6:6": "kk",
}

EXPECTED_ACTIONS = {
    "move_left",
    "move_right",
    "move_up",
    "move_down",
    "dash",
    "crossbar",
    "place_resonator",
    "resonator_volley",
    "toggle_pause_menu",
    "dev_color_previous",
    "dev_color_next",
    "dev_remove_last",
    "dev_clear",
    "dev_toggle_simulation",
    "dev_slower",
    "dev_faster",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_catalog() -> None:
    path = GODOT / "scripts" / "dev" / "ResonanceCatalog.gd"
    text = path.read_text(encoding="utf-8")
    colors_block, resonances_block = text.split("const RESONANCES :=", maxsplit=1)
    geometries = re.findall(r'"geometry": "(circle|spiral|line)"', colors_block)
    require(len(geometries) == 7, "ResonanceCatalog must contain seven colors")
    require(set(geometries) == {"circle", "spiral", "line"}, "All three wave geometries must exist")
    pairs = dict(re.findall(r'"(\d:\d)": \{"id": "([a-z_]+)"', resonances_block))
    require(pairs == EXPECTED_PAIRS, f"Unexpected resonance matrix: {pairs}")

    renderer = (GODOT / "scripts" / "dev" / "DeveloperResonanceRenderer.gd").read_text(encoding="utf-8")
    for resonance_id in EXPECTED_PAIRS.values():
        require(f'"{resonance_id}"' in renderer, f"Renderer is missing {resonance_id}")


def verify_bundle() -> None:
    manifest = json.loads((BUNDLE / "accepted_sources_manifest.json").read_text(encoding="utf-8"))
    late = manifest["accepted_late_resonances"]
    require(len(late) == 6, "Manifest must contain six late resonances")
    for entry in late:
        for kind in ("generator", "snapshot", "gif"):
            filename = Path(entry[kind]).name
            path = ASSETS / filename
            require(path.is_file(), f"Missing accepted {kind}: {filename}")
            require(sha256(path) == entry[f"{kind}_sha256"], f"Hash mismatch: {filename}")
    require((ASSETS / "ellipse_resonances_all_v2.py").is_file(), "Missing generator for first seven resonances")


def verify_project() -> None:
    project = (GODOT / "project.godot").read_text(encoding="utf-8")
    require('run/main_scene="res://scenes/MainMenu.tscn"' in project, "MainMenu must be the startup scene")
    for action in EXPECTED_ACTIONS:
        require(re.search(rf"(?m)^{re.escape(action)}=\{{", project) is not None, f"Missing Input Map action: {action}")
    for relative in (
        "scenes/MainMenu.tscn",
        "scenes/DeveloperRoom.tscn",
        "main.tscn",
        "assets/ui/main_menu/Ellipsis.png",
        "scripts/MainMenu.gd",
        "scripts/DeveloperRoom.gd",
    ):
        require((GODOT / relative).is_file(), f"Missing runtime file: {relative}")

    developer_room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    require("func _input(event: InputEvent)" in developer_room, "DeveloperRoom must receive GUI-consumed pointer input")
    require("get_viewport().get_mouse_position()" in developer_room, "DeveloperRoom must track the live mouse position")
    require("func _unhandled_input" not in developer_room, "DeveloperRoom cursor must not depend on unhandled GUI input")


def main() -> int:
    checks = (verify_catalog, verify_bundle, verify_project)
    try:
        for check in checks:
            check()
    except (AssertionError, KeyError, ValueError, OSError) as error:
        print(f"verify_v6_static: FAIL: {error}", file=sys.stderr)
        return 1
    print("verify_v6_static: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
