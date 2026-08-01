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


def verify_exact_restorations() -> None:
    renderer = (GODOT / "scripts" / "dev" / "DeveloperResonanceRenderer.gd").read_text(encoding="utf-8")
    room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    curve_data = (GODOT / "scripts" / "dev" / "ResonanceCurveData.gd").read_text(encoding="utf-8")
    penrose_data = (GODOT / "scripts" / "dev" / "PenrosePatchData.gd").read_text(encoding="utf-8")

    require("ContinuousCascadeButton" in room, "Developer room needs a toggleable continuous cascade")
    fire_volley = room.split("func _fire_volley()", 1)[1].split("\n\nfunc ", 1)[0]
    require(fire_volley.count('_spawn_wave(source, "short", false)') == 1, "Manual volley must create one short front per resonator")
    require("CASCADE_COUNT" not in room, "Manual volley must not be expanded into a cascade")

    require(curve_data.count("Vector2(") == 1920, "Expected four complete accepted 480-point contour tables")
    require("_RADIAL_FOURIER_B64" in (ROOT / "tools" / "generate_resonance_curve_data.py").read_text(encoding="utf-8"), "Radial curve must come from the accepted payload")
    for coefficient in ("0.58", "0.86", "1.15", "0.30", "1.02", "1.31", "1.60", "0.56", "0.80"):
        require(coefficient in renderer, f"Missing accepted staged-curve coefficient {coefficient}")

    for bush_coefficient in ("0.96", "0.82", "0.76", "34.0", "-32.0", "24.0", "-24.0", "0.072", "0.105"):
        require(bush_coefficient in renderer, f"Missing accepted Z/Y bush coefficient {bush_coefficient}")
    require('yellow_wave["angle"]' in renderer, "Z/Y bushes must align to the yellow wave tangent")

    require(penrose_data.count("PackedVector2Array([") == 189, "Expected accepted 189-rhomb Penrose component")
    for coefficient in ("0.42 * typical_step", "1.18 * typical_step", "/ 0.055", "1.45 * local_step", "0.95 * local_step", "2.9 * local_step"):
        require(coefficient in renderer, f"Missing accepted grid/Voronoi coefficient {coefficient}")
    require("Geometry2D.triangulate_delaunay" in renderer, "K/K must use guarded Delaunay dual segments")
    require('preload("res://scripts/dev/ResonanceCurveData.gd")' in renderer, "Curve tables must be loaded explicitly without the editor class cache")
    require('preload("res://scripts/dev/PenrosePatchData.gd")' in renderer, "Penrose tables must be loaded explicitly without the editor class cache")
    require(renderer.count("ResonanceCurveData.") == 1, "Renderer must only mention the curve class name inside its preload path")
    require(renderer.count("PenrosePatchData.") == 1, "Renderer must only mention the Penrose class name inside its preload path")


def verify_developer_presets() -> None:
    room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    preset_block = room.split("const PRESETS := [", 1)[1].split("\n]", 1)[0]
    pairs = re.findall(r'"pair": Vector2i\((\d), (\d)\)', preset_block)
    expected = [tuple(key.split(":")) for key in EXPECTED_PAIRS]
    require(pairs == expected, f"Preset menu must contain all 13 resonance pairs in order: {pairs}")
    require(preset_block.count('"positions":') == 13, "Every preset needs two configured positions")
    require(preset_block.count('"angles":') == 13, "Every preset needs two configured wave angles")
    require('name = "ResonancePresetMenu"' in room, "Developer room needs a visible preset menu")
    require("func _load_preset(index: int)" in room, "Preset selection must rebuild the sandbox")
    require("_spawn_resonator(colors[source_index]" in room, "Preset must place both configured colors")


def verify_developer_timing() -> None:
    main = (GODOT / "scripts" / "Main.gd").read_text(encoding="utf-8")
    catalog = (GODOT / "scripts" / "dev" / "ResonanceCatalog.gd").read_text(encoding="utf-8")
    room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    renderer = (GODOT / "scripts" / "dev" / "DeveloperResonanceRenderer.gd").read_text(encoding="utf-8")
    main_interval = re.search(r"const RESONATOR_VOLLEY_INTERVAL := (.+)", main)
    dev_interval = re.search(r"const GAME_RESONATOR_VOLLEY_INTERVAL := (.+)", catalog)
    require(main_interval is not None and dev_interval is not None, "Both game and developer volley intervals must be declared")
    require(main_interval.group(1).strip() == dev_interval.group(1).strip(), "Developer x1 cascade timing must exactly match the main game")
    require("const CASCADE_PERIOD := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL" in room, "Developer cascade must use the shared game-rate value")
    require(renderer.count("118.0 * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL") == 2, "Grid spacing must follow the actual developer cascade cadence")


def verify_spiral_modes() -> None:
    room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    geometry = (GODOT / "scripts" / "dev" / "DeveloperWaveGeometry.gd").read_text(encoding="utf-8")
    smoke = (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8")
    require("const SPIRAL_MAX_TURNS := 3.0" in geometry, "Long spiral must stop growing at three turns")
    require("const SPIRAL_SHORT_TURNS := 1.5" in geometry, "Short spiral must remain one and a half turns long")
    require("const SPIRAL_CROSSINGS_PER_CASCADE := 2.0" in geometry, "Spiral frequency must define two fixed-point crossings per cascade")
    require("const SPIRAL_OMEGA := TAU * SPIRAL_CROSSINGS_PER_CASCADE / ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL" in geometry, "Spiral animation speed must derive from the shared circle cascade period")
    require("const SPIRAL_GROW_TIME := TAU * SPIRAL_MAX_TURNS / SPIRAL_OMEGA" in geometry, "Long spiral growth time must follow its synchronized angular speed")
    require("head = minf(live_head, TAU * SPIRAL_MAX_TURNS)" in geometry, "Long spiral head must stop at 6 pi")
    require("tail = maxf(0.0, head - TAU * SPIRAL_SHORT_TURNS)" in geometry, "Short spiral must use a sliding 3 pi window")
    require("tail_at_stop + SPIRAL_OMEGA * (age - stop_age)" in geometry, "Stopped short spiral must erase its remaining tail")
    require('var chirality := 1.0 if mode == "long" else float(wave.get("spiral_chirality", 1.0))' in geometry, "Long spiral must use the source rotation direction instead of mirrored resonator chirality")
    require('rotation := float(wave["angle"]) - chirality * phase_head' in geometry, "Rotation must exactly compensate head parameter motion")
    require("var radius := SPIRAL_PITCH * theta" in geometry, "Short spiral radius must use absolute theta")
    require('_spawn_wave(source, "long", true)' in room, "Held cascade must maintain a persistent long spiral")
    require("if not _has_long_spiral(source.sequence_id)" in room, "Cascade must not stack long spirals")
    require('wave.get("spiral_mode", "") == "long"' in room, "Persistent long spiral must be tracked per resonator")
    require("short spiral window remains exactly 1.5 turns" in smoke, "Developer smoke test must cover short spiral length")
    require("short spiral tail detaches from the center" in smoke, "Developer smoke test must cover the absolute-theta tail")
    require("short spiral head stays on its fixed emission ray" in smoke, "Developer smoke test must cover alpha = beta - head")
    require("long spiral stops growing at three turns" in smoke, "Developer smoke test must cover long spiral growth cap")
    require("long spiral rotation does not mirror with resonator direction" in smoke, "Developer smoke test must cover canonical long-spiral rotation direction")
    require("spiral crosses a fixed point twice per circle cascade period" in smoke, "Developer smoke test must cover spiral-to-circle frequency synchronization")
    require("continuous cascade does not stack long spirals" in smoke, "Developer smoke test must cover held spiral persistence")


def main() -> int:
    checks = (verify_catalog, verify_bundle, verify_project, verify_exact_restorations, verify_developer_presets, verify_developer_timing, verify_spiral_modes)
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
