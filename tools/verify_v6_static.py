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


def require_balanced_delimiters(source: str, label: str) -> None:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[tuple[str, int]] = []
    quote: str | None = None
    escaped = False
    line = 1
    index = 0
    while index < len(source):
        character = source[index]
        if character == "\n":
            line += 1
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            index += 1
            continue
        if character in ('"', "'"):
            quote = character
        elif character == "#":
            newline = source.find("\n", index)
            index = len(source) if newline < 0 else newline
            continue
        elif character in "([{":
            stack.append((character, line))
        elif character in ")]}":
            require(bool(stack) and stack[-1][0] == pairs[character], f"{label} has unmatched {character} on line {line}")
            stack.pop()
        index += 1
    require(quote is None, f"{label} has an unterminated string")
    if stack:
        raise AssertionError(f"{label} has an unclosed {stack[-1][0]} from line {stack[-1][1]}")


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
        "scripts/dev/InfinitePenroseGrid.gd",
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
    infinite_penrose = (GODOT / "scripts" / "dev" / "InfinitePenroseGrid.gd").read_text(encoding="utf-8")

    require_balanced_delimiters(renderer, "DeveloperResonanceRenderer.gd")
    require_balanced_delimiters(room, "DeveloperRoom.gd")
    require_balanced_delimiters(infinite_penrose, "InfinitePenroseGrid.gd")

    require("ContinuousCascadeButton" in room, "Developer room needs a toggleable continuous cascade")
    fire_volley = room.split("func _fire_volley()", 1)[1].split("\n\nfunc ", 1)[0]
    require(fire_volley.count('_spawn_wave(source, "short", false)') == 1, "Manual volley must create one short front per resonator")
    require("CASCADE_COUNT" not in room, "Manual volley must not be expanded into a cascade")

    require(curve_data.count("Vector2(") == 1920, "Expected four complete accepted 480-point contour tables")
    require("_RADIAL_FOURIER_B64" in (ROOT / "tools" / "generate_resonance_curve_data.py").read_text(encoding="utf-8"), "Radial curve must come from the accepted payload")
    for coefficient in ("0.58", "0.86", "1.15", "0.30", "1.02", "1.31", "1.60", "0.56", "0.80"):
        require(coefficient in renderer, f"Missing accepted staged-curve coefficient {coefficient}")

    for bush_coefficient in ("0.96", "0.82", "0.76", "34.0", "-32.0", "24.0", "-24.0"):
        require(bush_coefficient in renderer, f"Missing accepted Z/Y bush coefficient {bush_coefficient}")
    require('var rotation := float(yellow_wave["angle"]) + PI' in renderer, "Z/Y bushes must be rotated 180 degrees along the yellow wave")
    require('var branch_names := ["M1", "M2", "M3", "M4", "M5"]' in renderer, "Z/Y must retain all five source branches")
    require("const BUSH_INITIAL_COMPLETED_BRANCHES := 1" in renderer, "Z/Y animation must start directly from its second branch step")
    require("ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL / float(branch_segments.size())" in renderer, "Each Z/Y branch must divide one cascade period among its segments")
    require('float(segment["growth_duration"])' in renderer, "Z/Y segment animation must use its cascade-derived duration")
    require('var age := float(group.get("effect_age", 0.0))' in renderer, "Z/Y growth must start when its resonance first becomes visible")
    require('"effect_age": maxf(0.0, pair_age - float(_resonance_birth_ages[resonance_key]))' in room, "Developer room must track resonance-local effect age")
    require("_resonance_birth_ages.clear()" in room, "Clearing the room must clear resonance growth clocks")
    require("each bush branch grows for exactly one cascade period" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover sequential Z/Y branch timing")
    require("branching bush animation starts directly from its second step" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover the requested Z/Y start phase")

    for yy_contract in (
        "const YY_LINE_COUNT := 13",
        "const YY_LINE_DELAY := 0.035",
        "const YY_LINE_REVEAL_TIME := 0.10",
        "const YY_PLATEAU_TIME := 0.22",
        "const YY_FADE_TIME := 0.95",
        "float(line_index) / float(YY_LINE_COUNT - 1)",
    ):
        require(yy_contract in renderer, f"Missing accepted Y/Y sector-fan contract: {yy_contract}")
    require('resonance["id"] == "yy" and first["volley_index"] != second["volley_index"]' not in room, "Y/Y must render every real A_i/B_j intersection")
    require('"volley_index": _current_volley_index' in room, "Every developer wave must retain its shared volley index")
    require("yellow resonance accepts real intersections across different cascade indices" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover all real Y/Y cascade intersections")

    for gy_contract in (
        "const GY_TILE_DELAY := 0.05",
        "const GY_TILE_REVEAL_TIME := 0.13",
        "const GY_REVEAL_MANHATTAN_RADIUS := 2",
        'state["u"] = step_yellow / 3.0',
        'state["v"] = step_gold / 3.0',
        "_solve_normal_system(normal_gold, normal_yellow, Vector2(ResonanceCatalog.GAME_WAVE_SPEED, ResonanceCatalog.GAME_WAVE_SPEED))",
        "_nearest_lattice_vertex(local, u, v)",
        'state["tile_births"][tile_key] = minf',
    ):
        require(gy_contract in renderer, f"Missing accepted G/Y global rhomb-grid contract: {gy_contract}")
    require('"gy":\n\t\t\t_render_rhombic_grid' in renderer, "G/Y must keep drawing one persistent global grid between intersections")
    require('"global_state": global_state' not in room, "Global state must be shared by reference rather than copied into group literals")
    require('group["global_state"] = global_state' in room, "All G/Y intersections must reveal one shared global grid")
    require("global straight-wave grids solve both normal velocity constraints" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover global grid velocity")
    require("rhomb grid anchors an intersection to its nearest lattice vertex" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover G/Y vertex anchoring")
    require("repeated rhomb cascades land exactly three grid edges apart" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover stable G/Y alignment across repeated cascades")

    for coefficient in ("1.45 * local_step", "0.95 * local_step", "2.9 * local_step"):
        require(coefficient in renderer, f"Missing accepted grid/Voronoi coefficient {coefficient}")
    for gg_contract in (
        "const GG_TILE_EDGE_SCALE := 0.42",
        "const GG_REVEAL_RADIUS_SCALE := 1.18",
        "const GG_TILE_DELAY := 0.055",
        "const GG_TILE_REVEAL_TIME := 0.13",
        "GG_TILE_EDGE_SCALE * typical_step",
        "GG_REVEAL_RADIUS_SCALE * float(state[\"typical_step\"])",
        "_interpolate_unoriented_angle(tangent_a.angle(), tangent_b.angle())",
        'state["tile_births"][tile_key] = minf',
    ):
        require(gg_contract in renderer, f"Missing accepted G/G global Penrose contract: {gg_contract}")
    require('"gold_gold":\n\t\t\t_render_penrose_grid' in renderer, "G/G must keep drawing one persistent global Penrose grid between intersections")
    require("Penrose reveal uses transformed global tile centers" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover global Penrose tile transforms")
    for infinite_contract in (
        "const PHASES := [0.17, 0.43, 0.69, 0.11, 0.57]",
        "const DUAL_SCALE := 2.5",
        "var pentagrid_center := (center + ORIGIN_SHIFT) / DUAL_SCALE",
        "for first_family in range(5)",
        "for second_family in range(first_family + 1, 5)",
        "base_address.append(ceili(",
        'tiles["|".join(vertex_keys)] = points',
    ):
        require(infinite_contract in infinite_penrose, f"Missing infinite de Bruijn pentagrid contract: {infinite_contract}")
    require("INFINITE_PENROSE.tiles_around(local_center, visible_radius + 8.0)" in renderer, "G/G must stream a moving window of the infinite pentagrid")
    require("Penrose pentagrid generates tiles around arbitrarily distant visible regions" in (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8"), "Developer smoke test must cover conditionally infinite G/G generation")
    require("Geometry2D.triangulate_delaunay" in renderer, "K/K must use guarded Delaunay dual segments")
    require('preload("res://scripts/dev/ResonanceCurveData.gd")' in renderer, "Curve tables must be loaded explicitly without the editor class cache")
    require('preload("res://scripts/dev/InfinitePenroseGrid.gd")' in renderer, "Infinite Penrose generator must be loaded explicitly without the editor class cache")
    require(renderer.count("ResonanceCurveData.") == 1, "Renderer must only mention the curve class name inside its preload path")
    require(renderer.count("InfinitePenroseGrid.") == 1, "Renderer must only mention the infinite Penrose class name inside its preload path")


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
    wave = (GODOT / "scripts" / "Wave.gd").read_text(encoding="utf-8")
    catalog = (GODOT / "scripts" / "dev" / "ResonanceCatalog.gd").read_text(encoding="utf-8")
    room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    renderer = (GODOT / "scripts" / "dev" / "DeveloperResonanceRenderer.gd").read_text(encoding="utf-8")
    main_interval = re.search(r"const RESONATOR_VOLLEY_INTERVAL := (.+)", main)
    dev_interval = re.search(r"const GAME_RESONATOR_VOLLEY_INTERVAL := (.+)", catalog)
    require(main_interval is not None and dev_interval is not None, "Both game and developer volley intervals must be declared")
    require(main_interval.group(1).strip() == dev_interval.group(1).strip(), "Developer x1 cascade timing must exactly match the main game")
    main_speed = re.search(r"const SHARED_SPEED := (.+)", wave)
    dev_speed = re.search(r"const GAME_WAVE_SPEED := (.+)", catalog)
    require(main_speed is not None and dev_speed is not None, "Both game and developer wave speeds must be declared")
    require(main_speed.group(1).strip() == dev_speed.group(1).strip(), "Developer wave speed must exactly match the main game")
    require("const GAME_CASCADE_SPACING := GAME_WAVE_SPEED * GAME_RESONATOR_VOLLEY_INTERVAL" in catalog, "Cascade spacing must derive from the shared speed and period")
    require("const CASCADE_PERIOD := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL" in room, "Developer cascade must use the shared game-rate value")
    require("const WAVE_SPEED := ResonanceCatalog.GAME_WAVE_SPEED" in room, "Developer waves must use the shared game speed")
    require(renderer.count("ResonanceCatalog.GAME_CASCADE_SPACING") == 2, "Straight-wave resonance grids must use the shared cascade spacing")


def verify_spiral_modes() -> None:
    room = (GODOT / "scripts" / "DeveloperRoom.gd").read_text(encoding="utf-8")
    geometry = (GODOT / "scripts" / "dev" / "DeveloperWaveGeometry.gd").read_text(encoding="utf-8")
    smoke = (GODOT / "tests" / "developer_room_smoke.gd").read_text(encoding="utf-8")
    require("const SPIRAL_MAX_TURNS := 3.0" in geometry, "Long spiral must stop growing at three turns")
    require("const SPIRAL_SHORT_TURNS := 1.5" in geometry, "Short spiral must remain one and a half turns long")
    require("const SPIRAL_TURN_SPACING := ResonanceCatalog.GAME_CASCADE_SPACING" in geometry, "Spiral turn spacing must equal circle cascade spacing")
    require("const SPIRAL_PITCH := SPIRAL_TURN_SPACING / TAU" in geometry, "Archimedean pitch must derive from the required turn spacing")
    require("const SPIRAL_POINT_CROSSINGS_PER_SOURCE_PER_CASCADE := 1.0" in geometry, "Each spiral source must cross a fixed point once per cascade")
    require("const SPIRAL_OMEGA := TAU * SPIRAL_POINT_CROSSINGS_PER_SOURCE_PER_CASCADE / ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL" in geometry, "Spiral animation speed must derive from the shared circle cascade period")
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
    require("each spiral crosses a fixed point once per circle cascade period" in smoke, "Developer smoke test must cover per-source spiral-to-circle frequency synchronization")
    require("two green resonators produce two fixed-point crossings per cascade period" in smoke, "Developer smoke test must cover the requested two crossings for a resonator pair")
    require("spiral turn spacing equals circle cascade spacing" in smoke, "Developer smoke test must cover spatial spiral-to-circle synchronization")
    require("spiral head and circle fronts share one radial speed" in smoke, "Developer smoke test must cover radial speed synchronization")
    require("continuous cascade does not stack long spirals" in smoke, "Developer smoke test must cover held spiral persistence")
    require("each straight resonator emits one line per cascade step" in smoke, "Developer smoke test must cover both straight resonator colors")
    require("straight cascade fronts use the shared circle spacing" in smoke, "Developer smoke test must cover straight-wave cascade spacing")


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
