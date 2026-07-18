#!/usr/bin/env python3
"""Prepare approved character sources for the Godot runtime.

Raw files under sprites_orig are inputs only. Generated files are written under
godot/assets with fixed 256 px cells, cleaned transparent RGB, and stable pivots.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageStat


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "sprites_orig"
ACTORS = ROOT / "godot" / "assets" / "actors"
INTERLUDE = ROOT / "godot" / "assets" / "interlude" / "characters"
FRAME_SIZE = 256
RAHN_CELL_SIZE = 288
ALPHA_THRESHOLD = 8
RAHN_ACTION_SCALE = 0.92
RAHN_REGISTRATION_BOX = (95, 95, 161, 165)
RAHN_REGISTRATION_RADIUS = 18


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


def scale_canvas_frame(image: Image.Image, scale: float) -> Image.Image:
    """Scale a fixed-size frame around its pivot without changing its cell."""
    size = max(1, round(FRAME_SIZE * scale))
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    offset = ((FRAME_SIZE - size) // 2, (FRAME_SIZE - size) // 2)
    canvas.alpha_composite(resized, offset)
    return clean_transparency(canvas)


def rahn_registration_shift(
    reference: Image.Image,
    candidate: Image.Image,
) -> tuple[int, int]:
    """Match the stable head/torso patch and return candidate pixel offset."""
    reference_rgb = Image.new("RGB", reference.size, (0, 0, 0))
    reference_rgb.paste(reference.convert("RGB"), mask=reference.getchannel("A"))
    candidate_rgb = Image.new("RGB", candidate.size, (0, 0, 0))
    candidate_rgb.paste(candidate.convert("RGB"), mask=candidate.getchannel("A"))
    reference_crop = reference_rgb.crop(RAHN_REGISTRATION_BOX)
    left, top, right, bottom = RAHN_REGISTRATION_BOX
    best_score = float("inf")
    best_shift = (0, 0)
    for y_shift in range(-RAHN_REGISTRATION_RADIUS, RAHN_REGISTRATION_RADIUS + 1):
        for x_shift in range(-RAHN_REGISTRATION_RADIUS, RAHN_REGISTRATION_RADIUS + 1):
            candidate_crop = candidate_rgb.crop(
                (
                    left - x_shift,
                    top - y_shift,
                    right - x_shift,
                    bottom - y_shift,
                )
            )
            difference = ImageChops.difference(reference_crop, candidate_crop)
            rms = ImageStat.Stat(difference).rms
            score = sum(channel * channel for channel in rms)
            if score < best_score:
                best_score = score
                best_shift = (x_shift, y_shift)
    return best_shift


def place_rahn_frame(
    image: Image.Image,
    reference: Image.Image,
) -> Image.Image:
    """Register into a padded cell so alignment never clips extended limbs."""
    shift = rahn_registration_shift(reference, image)
    padding = (RAHN_CELL_SIZE - FRAME_SIZE) // 2
    canvas = Image.new(
        "RGBA",
        (RAHN_CELL_SIZE, RAHN_CELL_SIZE),
        (0, 0, 0, 0),
    )
    canvas.alpha_composite(image, (padding + shift[0], padding + shift[1]))
    return clean_transparency(canvas)


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

    rahn_anchor_source = normalize_frame(
        Image.open(RAW / "rahn_topdown_anchor_alpha_cropped.png"),
        max_extent=198,
    )

    move_source = clean_transparency(Image.open(RAW / "rahn_move_sheet.png"))
    move_sources = split_strip(move_source, 4)
    rahn_reference = move_sources[0]
    move_frames = [
        place_rahn_frame(frame, rahn_reference)
        for frame in move_sources
    ]
    save(join_strip(move_frames), rahn_dir / "rahn_move_sheet.png")

    action_source = clean_transparency(Image.open(RAW / "rahn_action_23_sheet.png"))
    action_two_source, action_three_source = [
        scale_canvas_frame(frame, RAHN_ACTION_SCALE)
        for frame in split_strip(action_source, 2)
    ]
    rahn_anchor = place_rahn_frame(rahn_anchor_source, rahn_reference)
    save(rahn_anchor, rahn_dir / "rahn_anchor.png")
    action_two = place_rahn_frame(action_two_source, rahn_reference)
    action_three = place_rahn_frame(action_three_source, rahn_reference)
    action_frames = [
        rahn_anchor,
        action_two,
        action_three,
        action_two,
        rahn_anchor,
    ]
    save(join_strip(action_frames), rahn_dir / "rahn_action_sheet.png")

    rahn_defeat_source = normalize_frame(
        Image.open(RAW / "rahn_defeat_alpha_cropped.png"),
        max_extent=244,
    )
    rahn_defeat = place_rahn_frame(rahn_defeat_source, rahn_reference)
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
