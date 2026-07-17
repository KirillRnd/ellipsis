#!/usr/bin/env python3
"""Build Old Sluice runtime art from protected source assets."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "sprites_orig"
ARENA_OUTPUT_DIR = ROOT / "godot" / "assets" / "arena"

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


def main() -> None:
    build_backgrounds()
    build_gate()


if __name__ == "__main__":
    main()
