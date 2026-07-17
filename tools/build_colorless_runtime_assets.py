#!/usr/bin/env python3
"""Build Colorless runtime sheets from protected source assets."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "sprites_orig"
OUTPUT_DIR = ROOT / "godot" / "assets" / "actors" / "colorless"
CELL_SIZE = 256
PLACE_RESONATOR_SCALE = 1.05
PLACE_RESONATOR_OFFSET = (0, 12)
CROSSBAR_EMPTY_HANDS_SCALE = 0.80
CROSSBAR_EMPTY_HANDS_OFFSET = (0, -25)


def load_rgba(name: str, expected_size: tuple[int, int]) -> Image.Image:
    path = SOURCE_DIR / name
    image = Image.open(path).convert("RGBA")
    if image.size != expected_size:
        raise SystemExit(
            f"{path.relative_to(ROOT)} has size {image.size}, expected {expected_size}"
        )
    return image


def save_rgba(image: Image.Image, name: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT_DIR / name)


def build_idle() -> None:
    anchor = load_rgba("colorless_anchor_v1.png", (CELL_SIZE, CELL_SIZE))
    candidates = load_rgba(
        "colorless_idle_keyframes_v2.png",
        (CELL_SIZE * 2, CELL_SIZE),
    )
    runtime = Image.new("RGBA", candidates.size, (0, 0, 0, 0))
    runtime.alpha_composite(anchor, (0, 0))
    runtime.alpha_composite(
        candidates.crop((CELL_SIZE, 0, CELL_SIZE * 2, CELL_SIZE)),
        (CELL_SIZE, 0),
    )
    save_rgba(runtime, "colorless_idle_sheet.png")


def copy_compatible_sheet(
    source_name: str,
    output_name: str,
    frame_count: int,
    frame_height: int = CELL_SIZE,
) -> None:
    image = load_rgba(source_name, (CELL_SIZE * frame_count, frame_height))
    save_rgba(image, output_name)


def scale_frame_around_pivot(
    frame: Image.Image,
    scale: float,
    offset: tuple[int, int] = (0, 0),
) -> Image.Image:
    scaled_size = tuple(round(dimension * scale) for dimension in frame.size)
    scaled = frame.resize(scaled_size, Image.Resampling.LANCZOS)
    position = (
        (CELL_SIZE - scaled.width) // 2 + offset[0],
        (CELL_SIZE - scaled.height) // 2 + offset[1],
    )
    result = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    result.alpha_composite(scaled, position)
    return result


def build_place_resonator() -> None:
    source = load_rgba(
        "colorless_place_resonator_two_state_sheet.png",
        (CELL_SIZE * 2, CELL_SIZE),
    )
    runtime = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for frame_index in range(2):
        frame = source.crop(
            (
                frame_index * CELL_SIZE,
                0,
                (frame_index + 1) * CELL_SIZE,
                CELL_SIZE,
            )
        )
        normalized = scale_frame_around_pivot(
            frame,
            PLACE_RESONATOR_SCALE,
            PLACE_RESONATOR_OFFSET,
        )
        runtime.alpha_composite(normalized, (frame_index * CELL_SIZE, 0))
    save_rgba(runtime, "colorless_place_resonator_two_state_sheet.png")


def build_crossbar_empty_hands() -> None:
    frame_names = (
        "colorless_crossbar_empty_hands_intermediate_01_alpha.png",
        "colorless_crossbar_empty_hands_06_alpha.png",
    )
    runtime = Image.new(
        "RGBA",
        (CELL_SIZE * len(frame_names), CELL_SIZE),
        (0, 0, 0, 0),
    )
    for frame_index, frame_name in enumerate(frame_names):
        frame = load_rgba(frame_name, (CELL_SIZE, CELL_SIZE))
        normalized = scale_frame_around_pivot(
            frame,
            CROSSBAR_EMPTY_HANDS_SCALE,
            CROSSBAR_EMPTY_HANDS_OFFSET,
        )
        runtime.alpha_composite(normalized, (frame_index * CELL_SIZE, 0))
    save_rgba(runtime, "colorless_crossbar_empty_hands_two_state_sheet.png")


def main() -> None:
    build_idle()
    copy_compatible_sheet(
        "colorless_move_keyframes_v1.png",
        "colorless_move_sheet.png",
        4,
    )
    copy_compatible_sheet(
        "colorless_hit_keyframes_v2.png",
        "colorless_hit_sheet.png",
        2,
    )
    copy_compatible_sheet(
        "colorless_dash_keyframes_v8.png",
        "colorless_dash_sheet.png",
        3,
        frame_height=512,
    )
    build_place_resonator()
    build_crossbar_empty_hands()


if __name__ == "__main__":
    main()
