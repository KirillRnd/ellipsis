#!/usr/bin/env python3
"""Build Old Sluice runtime art from protected source assets."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "sprites_orig"
ARENA_OUTPUT_DIR = ROOT / "godot" / "assets" / "arena"
ITEM_OUTPUT_DIR = ROOT / "godot" / "assets" / "items"

BACKGROUND_SOURCES = {
    "arena_blue_guides_bg_new.png": "arena_blue_guides_bg.png",
    "arena_red_fault_bg_new.png": "arena_red_fault_bg.png",
    "arena_gold_boss_bg_new.png": "arena_gold_boss_bg.png",
}

GATE_SOURCE_SIZE = (1161, 973)
GATE_FRAME_SIZE = (1161, 424)
GATE_STATE_BOUNDS = (
    (0, 8, 1161, 430),
    (0, 541, 1161, 965),
)
PICKUP_SOURCE_SIZE = (863, 878)
PICKUP_CROP_PADDING = 12
CROSSBAR_CROP_PADDING = 12
CROSSBAR_TOPDOWN_SOURCE_SIZE = (1533, 166)
CROSSBAR_TOPDOWN_CONTENT_BOUNDS = (0, 0, 1533, 166)
CROSSBAR_INTERLUDE_SOURCE_SIZE = (955, 1166)
CROSSBAR_INTERLUDE_CONTENT_BOUNDS = (5, 6, 950, 1161)
CROSSBAR_DRIVEN_SOURCE_SIZE = (454, 659)
CROSSBAR_DRIVEN_CONTENT_BOUNDS = (5, 6, 449, 654)


def load_rgba(name: str, expected_size: tuple[int, int]) -> Image.Image:
    path = SOURCE_DIR / name
    image = Image.open(path).convert("RGBA")
    if image.size != expected_size:
        raise SystemExit(
            f"{path.relative_to(ROOT)} has size {image.size}, expected {expected_size}"
        )
    return image


def build_backgrounds() -> None:
    ARENA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for source_name, output_name in BACKGROUND_SOURCES.items():
        source_path = SOURCE_DIR / source_name
        image = Image.open(source_path).convert("RGB")
        image.save(ARENA_OUTPUT_DIR / output_name)


def build_gate() -> None:
    source = load_rgba("gate.png", GATE_SOURCE_SIZE)
    frame_width, frame_height = GATE_FRAME_SIZE
    runtime = Image.new(
        "RGBA",
        (frame_width * len(GATE_STATE_BOUNDS), frame_height),
        (0, 0, 0, 0),
    )

    for frame_index, bounds in enumerate(GATE_STATE_BOUNDS):
        state = source.crop(bounds)
        y = (frame_height - state.height) // 2
        runtime.alpha_composite(state, (frame_index * frame_width, y))

    runtime.save(ARENA_OUTPUT_DIR / "gate_two_state_sheet.png")


def keep_largest_alpha_component(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    visited = bytearray(width * height)
    largest_component: list[int] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or pixels[x, y] == 0:
                continue
            visited[index] = 1
            stack = [index]
            component: list[int] = []
            while stack:
                current = stack.pop()
                component.append(current)
                current_y, current_x = divmod(current, width)
                for neighbor_y in range(max(0, current_y - 1), min(height, current_y + 2)):
                    for neighbor_x in range(max(0, current_x - 1), min(width, current_x + 2)):
                        neighbor = neighbor_y * width + neighbor_x
                        if visited[neighbor] or pixels[neighbor_x, neighbor_y] == 0:
                            continue
                        visited[neighbor] = 1
                        stack.append(neighbor)
            if len(component) > len(largest_component):
                largest_component = component

    clean_alpha = Image.new("L", image.size, 0)
    clean_pixels = clean_alpha.load()
    for index in largest_component:
        y, x = divmod(index, width)
        clean_pixels[x, y] = pixels[x, y]

    result = image.copy()
    result.putalpha(clean_alpha)
    transparent = Image.new("RGBA", image.size, (0, 0, 0, 0))
    transparent.alpha_composite(result)
    return transparent


def build_pickup() -> None:
    source = load_rgba(
        "pickup_white_glow_alpha_cropped_fixed.png",
        PICKUP_SOURCE_SIZE,
    )
    cleaned = keep_largest_alpha_component(source)
    bounds = cleaned.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit("Pickup source has no visible alpha component")
    left, top, right, bottom = bounds
    crop_bounds = (
        max(0, left - PICKUP_CROP_PADDING),
        max(0, top - PICKUP_CROP_PADDING),
        min(cleaned.width, right + PICKUP_CROP_PADDING),
        min(cleaned.height, bottom + PICKUP_CROP_PADDING),
    )
    ITEM_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    cleaned.crop(crop_bounds).save(ITEM_OUTPUT_DIR / "pickup_white_glow.png")


def crop_component_with_padding(
    image: Image.Image,
    expected_bounds: tuple[int, int, int, int],
    padding: int,
) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds != expected_bounds:
        raise SystemExit(f"Visible bounds {bounds}, expected {expected_bounds}")
    content = image.crop(bounds)
    runtime = Image.new(
        "RGBA",
        (content.width + padding * 2, content.height + padding * 2),
        (0, 0, 0, 0),
    )
    runtime.alpha_composite(content, (padding, padding))
    return runtime


def build_crossbar() -> None:
    topdown_source = load_rgba(
        "steel_crossbar_topdown_alpha_cropped.png",
        CROSSBAR_TOPDOWN_SOURCE_SIZE,
    )
    topdown = crop_component_with_padding(
        keep_largest_alpha_component(topdown_source),
        CROSSBAR_TOPDOWN_CONTENT_BOUNDS,
        CROSSBAR_CROP_PADDING,
    )

    interlude_source = load_rgba(
        "steel_crossbar_interlude_alpha_cropped.png",
        CROSSBAR_INTERLUDE_SOURCE_SIZE,
    )
    interlude = crop_component_with_padding(
        keep_largest_alpha_component(interlude_source),
        CROSSBAR_INTERLUDE_CONTENT_BOUNDS,
        CROSSBAR_CROP_PADDING,
    )

    driven_source = load_rgba(
        "kovyryalka_driven_alpha_cropped.png",
        CROSSBAR_DRIVEN_SOURCE_SIZE,
    )
    driven = crop_component_with_padding(
        keep_largest_alpha_component(driven_source),
        CROSSBAR_DRIVEN_CONTENT_BOUNDS,
        CROSSBAR_CROP_PADDING,
    )

    ITEM_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    topdown.save(ITEM_OUTPUT_DIR / "steel_crossbar_topdown.png")
    interlude.save(ITEM_OUTPUT_DIR / "steel_crossbar_interlude.png")
    driven.save(ITEM_OUTPUT_DIR / "kovyryalka_driven.png")


def main() -> None:
    builders = {
        "backgrounds": build_backgrounds,
        "gate": build_gate,
        "pickup": build_pickup,
        "crossbar": build_crossbar,
    }
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "targets",
        nargs="*",
        choices=builders,
        help="asset groups to build; omit to build all groups",
    )
    args = parser.parse_args()
    targets = args.targets or list(builders)
    for target in targets:
        builders[target]()


if __name__ == "__main__":
    main()
