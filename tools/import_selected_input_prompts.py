#!/usr/bin/env python3
"""Copy only the approved Kenney keyboard and mouse prompts into runtime."""

from pathlib import Path
from shutil import copy2


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "sprites_orig"
    / "kenney_input-prompts_1.5"
    / "Keyboard & Mouse"
    / "Default"
)
OUTPUT = ROOT / "godot" / "assets" / "ui" / "input_prompts"
APPROVED = (
    "keyboard_w.png",
    "keyboard_a.png",
    "keyboard_s.png",
    "keyboard_d.png",
    "keyboard_space.png",
    "keyboard_e.png",
    "mouse_left.png",
    "mouse_right.png",
)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename in APPROVED:
        source = SOURCE / filename
        if not source.is_file():
            raise FileNotFoundError(source)
        destination = OUTPUT / filename
        copy2(source, destination)
        print(f"{source.name} -> {destination.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
