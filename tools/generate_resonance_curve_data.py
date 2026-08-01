#!/usr/bin/env python3
"""Generate Godot curve tables from the accepted v2 resonance source."""

from __future__ import annotations

import ast
import base64
import zlib
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ellipse_resonances_exact_restore_v1_bundle" / "accepted_assets" / "ellipse_resonances_all_v2.py"
TARGET = ROOT / "godot" / "scripts" / "dev" / "ResonanceCurveData.gd"


def string_constant(name: str) -> str:
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == name for target in node.targets):
            return ast.literal_eval(node.value)
    raise KeyError(name)


def decode(name: str) -> np.ndarray:
    raw = zlib.decompress(base64.b64decode(string_constant(name).encode("ascii")))
    return np.frombuffer(raw, dtype=np.float32).reshape(480, 2).astype(float)


def lowpass(points: np.ndarray, harmonics: int = 3) -> np.ndarray:
    result = np.empty_like(points)
    for axis in range(2):
        spectrum = np.fft.fft(points[:, axis])
        filtered = np.zeros_like(spectrum)
        filtered[: harmonics + 1] = spectrum[: harmonics + 1]
        filtered[-harmonics:] = spectrum[-harmonics:]
        result[:, axis] = np.fft.ifft(filtered).real
    return result


def packed_function(name: str, points: np.ndarray) -> str:
    rows = ",\n\t\t".join(f"Vector2({x:.8f}, {y:.8f})" for x, y in points)
    return f"static func {name}() -> PackedVector2Array:\n\treturn PackedVector2Array([\n\t\t{rows},\n\t])\n"


def main() -> None:
    radial = decode("_RADIAL_FOURIER_B64")
    gielis = decode("_GIELIS_B64")
    output = "\n".join(
        [
            "# Generated from accepted_assets/ellipse_resonances_all_v2.py. Do not hand-edit.",
            "class_name ResonanceCurveData",
            "extends RefCounted\n",
            packed_function("radial_master", radial),
            packed_function("radial_smooth", lowpass(radial)),
            packed_function("gielis_master", gielis),
            packed_function("gielis_smooth", lowpass(gielis)),
        ]
    )
    TARGET.write_text(output, encoding="utf-8", newline="\n")
    print(f"generated {TARGET.relative_to(ROOT)} ({len(output)} chars)")


if __name__ == "__main__":
    main()
