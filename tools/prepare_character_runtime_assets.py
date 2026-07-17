#!/usr/bin/env python3
"""Prepare approved character sources for the Godot runtime.

Raw files under sprites_orig are inputs only. Generated files are written under
godot/assets with fixed 256 px cells, cleaned transparent RGB, and stable pivots.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "sprites_orig"
ACTORS = ROOT / "godot" / "assets" / "actors"
INTERLUDE = ROOT / "godot" / "assets" / "interlude" / "characters"
FRAME_SIZE = 256
ALPHA_THRESHOLD = 8


def clean_transparency(image: Image.Image) -> Image.Image:
    """Remove hidden chroma RGB and suppress green spill in translucent edges."""
    rgba = image.convert("RGBA")
    cleaned: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in rgba.getdata():
        if alpha == 0:
            cleaned.append((0, 0, 0, 0))
            continue
        if green > red * 1.15 and green > blue * 1.15:
            green = min(green, int(max(red, blue) * 1.08))
        cleaned.append((red, green, blue, alpha))
    rgba.putdata(cleaned)
    return rgba


def content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    mask = image.getchannel("A").point(
        lambda value: 255 if value > ALPHA_THRESHOLD else 0
    )
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("No visible sprite content")
    return bbox


def normalize_frame(
    image: Image.Image,
    *,
    max_extent: int = 249,
    vertical_anchor: str = "center",
) -> Image.Image:
    cleaned = clean_transparency(image)
    cropped = cleaned.crop(content_bbox(cleaned))
    scale = min(max_extent / cropped.width, max_extent / cropped.height)
    size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - resized.width) // 2
    if vertical_anchor == "bottom":
        y = FRAME_SIZE - resized.height
    else:
        y = (FRAME_SIZE - resized.height) // 2
    canvas.alpha_composite(resized, (x, y))
    return clean_transparency(canvas)


def split_strip(image: Image.Image, frames: int) -> list[Image.Image]:
    if image.width % frames != 0:
        raise ValueError(f"Strip width {image.width} is not divisible by {frames}")
    width = image.width // frames
    return [
        image.crop((index * width, 0, (index + 1) * width, image.height))
        for index in range(frames)
    ]


def join_strip(frames: list[Image.Image]) -> Image.Image:
    strip = Image.new(
        "RGBA",
        (sum(frame.width for frame in frames), max(frame.height for frame in frames)),
        (0, 0, 0, 0),
    )
    x = 0
    for frame in frames:
        strip.alpha_composite(frame, (x, 0))
        x += frame.width
    return strip


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def main() -> None:
    rahn_dir = ACTORS / "rahn"
    colorless_dir = ACTORS / "colorless"

    rahn_anchor = normalize_frame(
        Image.open(RAW / "rahn_topdown_anchor_alpha_cropped.png")
    )
    save(rahn_anchor, rahn_dir / "rahn_anchor.png")

    move_source = clean_transparency(Image.open(RAW / "rahn_move_sheet.png"))
    move_frames = split_strip(move_source, 4)
    save(join_strip(move_frames), rahn_dir / "rahn_move_sheet.png")

    action_source = clean_transparency(Image.open(RAW / "rahn_action_23_sheet.png"))
    action_two, action_three = split_strip(action_source, 2)
    action_frames = [
        rahn_anchor,
        action_two,
        action_three,
        action_two,
        rahn_anchor,
    ]
    save(join_strip(action_frames), rahn_dir / "rahn_action_sheet.png")

    rahn_defeat = normalize_frame(
        Image.open(RAW / "rahn_defeat_alpha_cropped.png"),
        max_extent=244,
    )
    save(rahn_defeat, rahn_dir / "rahn_defeat_sheet.png")

    colorless_defeat = normalize_frame(
        Image.open(RAW / "death.png"),
        max_extent=249,
    )
    save(colorless_defeat, colorless_dir / "colorless_defeat_sheet.png")

    save(
        clean_transparency(Image.open(RAW / "rahn_resonator_red_alpha_cropped.png")),
        ACTORS / "resonator_red_base.png",
    )
    save(
        clean_transparency(Image.open(RAW / "rahn_interlude_alpha_cropped.png")),
        INTERLUDE / "rahn.png",
    )
    save(
        clean_transparency(Image.open(RAW / "cron_interlude_alpha_cropped_fixed.png")),
        INTERLUDE / "cron.png",
    )
    save(
        clean_transparency(Image.open(RAW / "colorless_interlude_alpha_cropped.png")),
        INTERLUDE / "colorless.png",
    )


if __name__ == "__main__":
    main()
