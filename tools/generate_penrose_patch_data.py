#!/usr/bin/env python3
"""Generate the accepted de Bruijn Penrose tile patch for the Godot renderer."""

from __future__ import annotations

from collections import defaultdict, deque
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "godot" / "scripts" / "dev" / "PenrosePatchData.gd"
PHASES = np.array([0.17, 0.43, 0.69, 0.11, 0.57])
DIRECTIONS = np.array([[np.cos(2 * np.pi * k / 5), np.sin(2 * np.pi * k / 5)] for k in range(5)])


def generate() -> list[np.ndarray]:
    vertices: list[np.ndarray] = []
    vertex_ids: dict[tuple[int, ...], int] = {}
    candidates: list[tuple[list[int], np.ndarray]] = []
    tile_keys: set[tuple[int, ...]] = set()

    def vertex_id(address: np.ndarray) -> int:
        key = tuple(int(v) for v in address)
        if key not in vertex_ids:
            vertex_ids[key] = len(vertices)
            vertices.append(np.sum(np.array(key)[:, None] * DIRECTIONS, axis=0))
        return vertex_ids[key]

    for i in range(5):
        for j in range(i + 1, 5):
            matrix = np.vstack([DIRECTIONS[i], DIRECTIONS[j]])
            for mi in range(-22, 23):
                for mj in range(-22, 23):
                    intersection = np.linalg.solve(matrix, np.array([mi - PHASES[i], mj - PHASES[j]]))
                    if np.linalg.norm(intersection) > 15.0:
                        continue
                    sample = intersection - 1e-4 * (DIRECTIONS[i] + DIRECTIONS[j])
                    address = np.ceil(DIRECTIONS @ sample + PHASES - 1e-6).astype(int)
                    addresses = [address.copy() for _ in range(4)]
                    addresses[1][i] += 1
                    addresses[2][i] += 1
                    addresses[2][j] += 1
                    addresses[3][j] += 1
                    ids = [vertex_id(item) for item in addresses]
                    key = tuple(sorted(ids))
                    if key in tile_keys:
                        continue
                    tile_keys.add(key)
                    points = np.array([vertices[item] for item in ids])
                    candidates.append((ids, points))

    centers = np.array([points.mean(axis=0) for _, points in candidates])
    shift = centers[np.argmin(np.linalg.norm(centers, axis=1))]
    cropped = [(ids, points - shift) for ids, points in candidates if np.linalg.norm(points.mean(axis=0) - shift) <= 7.0]
    edges: dict[tuple[int, int], list[int]] = defaultdict(list)
    for index, (ids, _) in enumerate(cropped):
        for a, b in ((ids[0], ids[1]), (ids[1], ids[2]), (ids[2], ids[3]), (ids[3], ids[0])):
            edges[tuple(sorted((a, b)))].append(index)
    adjacency = defaultdict(set)
    for attached in edges.values():
        if len(attached) == 2:
            adjacency[attached[0]].add(attached[1])
            adjacency[attached[1]].add(attached[0])
    unseen = set(range(len(cropped)))
    components = []
    while unseen:
        start = unseen.pop()
        queue = deque([start])
        component = [start]
        while queue:
            for neighbor in adjacency[queue.popleft()]:
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        components.append(component)
    return [cropped[index][1] for index in max(components, key=len)]


def main() -> None:
    tiles = generate()
    rows = []
    for points in tiles:
        vectors = ", ".join(f"Vector2({x:.7f}, {y:.7f})" for x, y in points)
        rows.append(f"\t\tPackedVector2Array([{vectors}])")
    output = "\n".join([
        "# Generated from accepted_assets/gg_global_grid_reveal_v3_staggered.py. Do not hand-edit.",
        "class_name PenrosePatchData",
        "extends RefCounted\n",
        "static func tiles() -> Array[PackedVector2Array]:",
        "\treturn [\n" + ",\n".join(rows) + "\n\t]",
        "",
    ])
    TARGET.write_text(output, encoding="utf-8", newline="\n")
    print(f"generated {len(tiles)} Penrose rhombs")


if __name__ == "__main__":
    main()
