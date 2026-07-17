#!/usr/bin/env python3
"""Build Old Sluice runtime art from protected source assets."""

from __future__ import annotations

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


def main() -> None:
    build_backgrounds()
    build_gate()
    build_pickup()


if __name__ == "__main__":
    main()
