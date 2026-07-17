#!/usr/bin/env python3
"""Create 1280x720 runtime copies of approved artbook location backgrounds."""

from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ARTBOOK = ROOT / "artbook"
OUTPUT = ROOT / "godot" / "assets" / "interlude" / "backgrounds"
SIZE = (1280, 720)
BACKGROUNDS = {
    "old_sluice_entry.png": "blue_enter.png",
    "resonator_system.png": "blue_town.png",
    "steel_crossbar.png": "second_focus.png",
    "rahn_meeting.png": "red_zone.png",
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for output_name, source_name in BACKGROUNDS.items():
        source_path = ARTBOOK / source_name
        with Image.open(source_path) as source:
            runtime = ImageOps.fit(
                source.convert("RGB"),
                SIZE,
                method=Image.Resampling.LANCZOS,
                centering=(0.5, 0.5),
            )
            runtime.save(OUTPUT / output_name, optimize=True)
        print(f"{source_name} -> {output_name} ({SIZE[0]}x{SIZE[1]})")


if __name__ == "__main__":
    main()
