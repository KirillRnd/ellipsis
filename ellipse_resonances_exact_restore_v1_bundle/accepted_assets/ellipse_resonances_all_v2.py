#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Эллипс — единый скрипт прототипов принятых Резонансов.

Генерирует:
  01_FF_lissajous.gif
  02_FS_projection.gif
  03_SS_delaunay.gif
  04_SG_circumcircles.gif
  05_GG_rosette.gif
  06_ZG_radial_fourier.gif
  07_ZZ_gielis_leaves.gif
  ellipse_resonances_overview.png

Принятые конструкции:
  Ф/Ф — фигура Лиссажу 2:1.
  Ф/С — проекция движения Лиссажу 2:1 на прямую между узлами.
  С/С — рёбра триангуляции Делоне по узлам пересечения волн.
  С/Г — описанные окружности треугольников Делоне, рёбра скрыты.
  Г/Г — вложенная шестилепестковая розетка; внешний слой касается узлов.
  З/Г — радиальный Фурье в каждом реальном пересечении спирали и круга;
        направление от зелёного, максимум 3 стадии, шаг роста — полвитка.
  З/З — фиксированный лист Гиелиса в каждом реальном пересечении двух спиралей;
        рост каждые пол-оборота, максимум 4 стадии, центрирование по центру;
        выше оси листья направлены вверх, ниже — вниз.

Скрипт автономен: два согласованных мастер-контура листьев встроены
как сжатые массивы координат.

Зависимости:
  numpy
  matplotlib
  scipy
  pillow

Пример:
  python ellipse_resonances_all.py --output-dir resonance_output

Быстрый тест:
  python ellipse_resonances_all.py --output-dir test --frames 24 --fps 8
"""

from __future__ import annotations

import argparse
import base64
import math
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
import numpy as np
from scipy.spatial import Delaunay

# ---------------------------------------------------------------------------
# Встроенные принятые мастер-контуры
# ---------------------------------------------------------------------------

_RADIAL_FOURIER_B64 = """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"""
_GIELIS_B64 = """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"""


def decode_curve(payload: str, points: int = 480) -> np.ndarray:
    raw = zlib.decompress(base64.b64decode(payload.encode("ascii")))
    curve = np.frombuffer(raw, dtype=np.float32).reshape(points, 2).astype(float)
    return curve


RADIAL_FOURIER_MASTER = decode_curve(_RADIAL_FOURIER_B64)
GIELIS_MASTER = decode_curve(_GIELIS_B64)


# ---------------------------------------------------------------------------
# Палитра
# ---------------------------------------------------------------------------

BG = "#fffefb"
INK = "#20242a"
NODE = "#34383d"

PURPLE = "#8d4bd6"
PURPLE_LIGHT = "#c39aea"
BLUE = "#3979d2"
BLUE_LIGHT = "#9fc2ed"
CYAN = "#37a9d6"
CYAN_LIGHT = "#9bd8ed"
GREEN = "#2f9054"
GREEN_LIGHT = "#a7d4b3"

EDGE_COLORS = ["#2868b2", "#41906b", "#8a5bc4", "#d07b42", "#2d8795"]


# ---------------------------------------------------------------------------
# Общие вспомогательные функции
# ---------------------------------------------------------------------------

def smoothstep(x: float | np.ndarray) -> float | np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def cross2(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return a[..., 0] * b[..., 1] - a[..., 1] * b[..., 0]


def circle_xy(center: np.ndarray, radius: float, samples: int = 500) -> tuple[np.ndarray, np.ndarray]:
    t = np.linspace(0.0, 2.0 * np.pi, samples)
    return center[0] + radius * np.cos(t), center[1] + radius * np.sin(t)


def circle_intersections(
    c0: np.ndarray,
    r0: float,
    c1: np.ndarray,
    r1: float,
    eps: float = 1e-9,
) -> list[np.ndarray]:
    delta = c1 - c0
    distance = float(np.linalg.norm(delta))
    if distance < eps:
        return []
    if distance > r0 + r1 + eps:
        return []
    if distance < abs(r0 - r1) - eps:
        return []

    a = (r0 * r0 - r1 * r1 + distance * distance) / (2.0 * distance)
    h2 = r0 * r0 - a * a
    if h2 < -eps:
        return []

    h = math.sqrt(max(h2, 0.0))
    midpoint = c0 + (a / distance) * delta
    perpendicular = np.array([-delta[1], delta[0]]) / distance

    p = midpoint + h * perpendicular
    q = midpoint - h * perpendicular
    if np.linalg.norm(p - q) < 1e-7:
        return [p]
    return [p, q]


def configure_axis(
    ax: plt.Axes,
    title: str,
    xlim: tuple[float, float] = (-4.0, 4.0),
    ylim: tuple[float, float] = (-3.4, 3.4),
) -> None:
    ax.clear()
    ax.set_aspect("equal")
    ax.set_xlim(*xlim)
    ax.set_ylim(*ylim)
    ax.axis("off")
    ax.set_facecolor(BG)
    ax.set_title(title, fontsize=14, pad=10)


def draw_resonator(ax: plt.Axes, center: np.ndarray, color: str) -> None:
    ax.plot(center[0], center[1], marker="o", markersize=7.5, color=color, zorder=10)


def center_curve(curve: np.ndarray) -> np.ndarray:
    return curve - curve.mean(axis=0)


def fourier_lowpass_curve(master: np.ndarray, keep_harmonics: int = 3) -> np.ndarray:
    z = master[:, 0] + 1j * master[:, 1]
    coeff = np.fft.fft(z)
    filtered = np.zeros_like(coeff)
    filtered[0] = coeff[0]
    filtered[1 : keep_harmonics + 1] = coeff[1 : keep_harmonics + 1]
    filtered[-keep_harmonics:] = coeff[-keep_harmonics:]
    zf = np.fft.ifft(filtered)
    return center_curve(np.column_stack([zf.real, zf.imag]))


RADIAL_FOURIER_SMOOTH = fourier_lowpass_curve(RADIAL_FOURIER_MASTER, 3)
GIELIS_SMOOTH = fourier_lowpass_curve(GIELIS_MASTER, 3)


def stage_curve(master: np.ndarray, smooth_master: np.ndarray, maturity: float) -> np.ndarray:
    q = float(smoothstep(maturity))
    return center_curve(smooth_master + q * (master - smooth_master))


def rotate_scale_translate(
    curve: np.ndarray,
    center: np.ndarray,
    scale: float,
    angle: float = 0.0,
) -> np.ndarray:
    c = math.cos(angle)
    s = math.sin(angle)
    x = scale * curve[:, 0]
    y = scale * curve[:, 1]
    return np.column_stack(
        [
            c * x - s * y + center[0],
            s * x + c * y + center[1],
        ]
    )


def dedupe_points(points: Iterable[np.ndarray], threshold: float = 0.045) -> list[np.ndarray]:
    result: list[np.ndarray] = []
    for point in points:
        if all(np.linalg.norm(point - existing) >= threshold for existing in result):
            result.append(np.asarray(point, dtype=float))
    return result


def polygon_circumcircle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> tuple[np.ndarray, float] | None:
    matrix = np.array(
        [
            [2.0 * (b[0] - a[0]), 2.0 * (b[1] - a[1])],
            [2.0 * (c[0] - a[0]), 2.0 * (c[1] - a[1])],
        ]
    )
    rhs = np.array(
        [
            b[0] ** 2 + b[1] ** 2 - a[0] ** 2 - a[1] ** 2,
            c[0] ** 2 + c[1] ** 2 - a[0] ** 2 - a[1] ** 2,
        ]
    )
    det = float(np.linalg.det(matrix))
    if abs(det) < 1e-8:
        return None
    center = np.linalg.solve(matrix, rhs)
    radius = float(np.linalg.norm(center - a))
    return center, radius


def save_animation(
    draw_frame: Callable[[plt.Axes, int], None],
    output_path: Path,
    frames: int,
    fps: int,
    dpi: int,
    figsize: tuple[float, float] = (6.0, 6.0),
) -> None:
    fig, ax = plt.subplots(figsize=figsize, facecolor=BG)

    def update(frame_index: int):
        draw_frame(ax, frame_index)
        return []

    animation = FuncAnimation(
        fig,
        update,
        frames=frames,
        interval=1000 / max(fps, 1),
        blit=False,
    )
    animation.save(output_path, writer=PillowWriter(fps=fps), dpi=dpi)
    plt.close(fig)


# ---------------------------------------------------------------------------
# 1. Ф/Ф — Лиссажу 2:1
# ---------------------------------------------------------------------------

def draw_ff(ax: plt.Axes, phase: float, title: str = "Ф/Ф — Лиссажу 2:1") -> None:
    configure_axis(ax, title)
    c1 = np.array([-1.55, 0.0])
    c2 = np.array([1.55, 0.0])
    radius = 1.82 + 0.33 * phase

    for center, color in ((c1, PURPLE_LIGHT), (c2, PURPLE)):
        x, y = circle_xy(center, radius)
        ax.plot(x, y, color=color, linewidth=1.3, alpha=0.52)
        draw_resonator(ax, center, color)

    intersections = circle_intersections(c1, radius, c2, radius)
    if len(intersections) != 2:
        return

    a_node, b_node = sorted(intersections, key=lambda p: p[1], reverse=True)
    midpoint = 0.5 * (a_node + b_node)
    d = float(np.linalg.norm(c2 - c1))

    longitudinal = max(radius - d / 2.0, 0.03) * 1.25
    transverse = 0.5 * float(np.linalg.norm(a_node - b_node))

    psi = np.linspace(0.0, 2.0 * np.pi, 700)
    x = midpoint[0] + longitudinal * np.sin(2.0 * psi)
    y = midpoint[1] + transverse * np.sin(psi)
    ax.plot(x, y, color=PURPLE, linewidth=2.0, alpha=0.88)

    active_phase = 8.0 * np.pi * phase
    active_x = midpoint[0] + longitudinal * math.sin(2.0 * active_phase)
    active_y = midpoint[1] + transverse * math.sin(active_phase)
    ax.plot(active_x, active_y, marker="o", markersize=5.5, color="#f0c7ff", zorder=12)

    ax.plot(
        [a_node[0], b_node[0]],
        [a_node[1], b_node[1]],
        marker="o",
        linestyle="None",
        markersize=3.8,
        color=NODE,
        alpha=0.65,
    )


# ---------------------------------------------------------------------------
# 2. Ф/С — проекция Лиссажу на прямую между узлами
# ---------------------------------------------------------------------------

def draw_fs(ax: plt.Axes, phase: float, title: str = "Ф/С — проекция Лиссажу 2:1") -> None:
    configure_axis(ax, title)
    c_purple = np.array([-1.55, 0.0])
    c_blue = np.array([1.55, 0.0])
    radius = 1.82 + 0.33 * phase

    for center, color in ((c_purple, PURPLE), (c_blue, BLUE)):
        x, y = circle_xy(center, radius)
        ax.plot(x, y, color=color, linewidth=1.3, alpha=0.52)
        draw_resonator(ax, center, color)

    intersections = circle_intersections(c_purple, radius, c_blue, radius)
    if len(intersections) != 2:
        return

    a_node, b_node = sorted(intersections, key=lambda p: p[1], reverse=True)
    ax.plot(
        [a_node[0], b_node[0]],
        [a_node[1], b_node[1]],
        color="#6b65be",
        linewidth=2.3,
        alpha=0.88,
    )
    ax.plot(
        [a_node[0], b_node[0]],
        [a_node[1], b_node[1]],
        marker="o",
        linestyle="None",
        markersize=3.8,
        color=NODE,
        alpha=0.65,
    )

    # Проекция быстрой координаты Лиссажу 2:1.
    s = 0.5 * (1.0 + math.sin(8.0 * np.pi * phase))
    q = (1.0 - s) * a_node + s * b_node
    ax.plot(q[0], q[1], marker="o", markersize=6.0, color="#ebe8ff", zorder=12)


# ---------------------------------------------------------------------------
# 3–4. С/С и С/Г — общий набор узлов и Делоне
# ---------------------------------------------------------------------------

def blue_node_geometry(phase: float) -> tuple[np.ndarray, list[tuple[np.ndarray, float]], list[tuple[np.ndarray, float]]]:
    c_left = np.array([-2.0, 0.0])
    c_right = np.array([2.0, 0.0])

    base = 1.62 + 0.16 * math.sin(2.0 * np.pi * phase)
    left_radii = [base + 0.00, base + 0.72, base + 1.44]
    right_radii = [base + 0.08, base + 0.80, base + 1.52]

    left_circles = [(c_left, r) for r in left_radii]
    right_circles = [(c_right, r) for r in right_radii]

    # Для С/С и С/Г учитываем ВСЕ реальные точки резонанса
    # между тремя фронтами слева и тремя фронтами справа.
    points: list[np.ndarray] = []
    for left_radius in left_radii:
        for right_radius in right_radii:
            points.extend(
                circle_intersections(
                    c_left,
                    left_radius,
                    c_right,
                    right_radius,
                )
            )

    nodes = np.array(dedupe_points(points, threshold=0.05))
    return nodes, left_circles, right_circles


def draw_blue_sources(
    ax: plt.Axes,
    left_circles: list[tuple[np.ndarray, float]],
    right_circles: list[tuple[np.ndarray, float]],
) -> None:
    for center, radius in left_circles:
        x, y = circle_xy(center, radius)
        ax.plot(x, y, color=BLUE_LIGHT, linewidth=1.0, alpha=0.42)
    for center, radius in right_circles:
        x, y = circle_xy(center, radius)
        ax.plot(x, y, color="#b8b4e8", linewidth=1.0, alpha=0.42)

    draw_resonator(ax, left_circles[0][0], BLUE)
    draw_resonator(ax, right_circles[0][0], "#6d6b85")


def draw_ss(ax: plt.Axes, phase: float, title: str = "С/С — рёбра Делоне") -> None:
    configure_axis(ax, title, xlim=(-5.0, 5.0), ylim=(-3.6, 3.6))
    nodes, left_circles, right_circles = blue_node_geometry(phase)
    draw_blue_sources(ax, left_circles, right_circles)

    if len(nodes) < 3:
        return
    triangulation = Delaunay(nodes)
    edges: set[tuple[int, int]] = set()
    for simplex in triangulation.simplices:
        for i, j in ((0, 1), (1, 2), (2, 0)):
            edge = tuple(sorted((int(simplex[i]), int(simplex[j]))))
            edges.add(edge)

    for edge_index, (i, j) in enumerate(sorted(edges)):
        ax.plot(
            [nodes[i, 0], nodes[j, 0]],
            [nodes[i, 1], nodes[j, 1]],
            color=EDGE_COLORS[edge_index % len(EDGE_COLORS)],
            linewidth=2.0,
            alpha=0.95,
        )
    ax.plot(nodes[:, 0], nodes[:, 1], "o", markersize=4.0, color=NODE, alpha=0.74)


def draw_sg(ax: plt.Axes, phase: float, title: str = "С/Г — описанные окружности") -> None:
    configure_axis(ax, title, xlim=(-5.0, 5.0), ylim=(-3.6, 3.6))
    nodes, left_circles, right_circles = blue_node_geometry(phase)
    draw_blue_sources(ax, left_circles, right_circles)

    if len(nodes) < 3:
        return
    triangulation = Delaunay(nodes)
    for triangle_index, simplex in enumerate(triangulation.simplices):
        result = polygon_circumcircle(nodes[simplex[0]], nodes[simplex[1]], nodes[simplex[2]])
        if result is None:
            continue
        center, radius = result
        if radius > 2.2:
            continue
        x, y = circle_xy(center, radius)
        ax.plot(
            x,
            y,
            color=EDGE_COLORS[triangle_index % len(EDGE_COLORS)],
            linewidth=1.8,
            alpha=0.9,
        )
    ax.plot(nodes[:, 0], nodes[:, 1], "o", markersize=4.0, color=NODE, alpha=0.74)


# ---------------------------------------------------------------------------
# 5. Г/Г — принятая шестилепестковая розетка
# ---------------------------------------------------------------------------

GG_LAUNCH_TIMES = [0.00, 0.14, 0.30, 0.48]
GG_BASE_SPEED = 1.22
GG_K = 6


def gg_front_params(age: float, layer_index: int) -> tuple[float, float, float, float]:
    age01 = float(np.clip(age / (1.0 - GG_LAUNCH_TIMES[layer_index]), 0.0, 1.0))
    growth = float(smoothstep(age01))
    radius = 0.18 + GG_BASE_SPEED * age
    a = (0.06 + 0.08 * layer_index) * growth
    b = (0.02 + 0.03 * layer_index) * growth
    phi = 0.7 * age + 0.35 * layer_index
    return radius, a, b, phi


def gg_radius(theta: np.ndarray, radius: float, a: float, b: float, phi: float) -> np.ndarray:
    return (
        radius
        + a * np.cos(GG_K * theta + phi)
        + b * np.cos(2 * GG_K * theta + 0.5 * phi)
    )


def draw_gg(ax: plt.Axes, phase: float, title: str = "Г/Г — шестилепестковая розетка") -> None:
    configure_axis(ax, title)
    c1 = np.array([-1.7, 0.0])
    c2 = np.array([1.7, 0.0])
    wave_radius = 1.82 + 0.55 * phase

    for center, color in ((c1, CYAN_LIGHT), (c2, CYAN)):
        x, y = circle_xy(center, wave_radius)
        ax.plot(x, y, color=color, linewidth=1.25, alpha=0.42)
        draw_resonator(ax, center, color)

    intersections = circle_intersections(c1, wave_radius, c2, wave_radius)
    if len(intersections) != 2:
        return

    node_top, node_bottom = sorted(intersections, key=lambda p: p[1], reverse=True)
    midpoint = 0.5 * (node_top + node_bottom)
    half_separation = 0.5 * float(np.linalg.norm(node_top - node_bottom))

    active: list[tuple[int, float, float, float, float]] = []
    for j, launch in enumerate(GG_LAUNCH_TIMES):
        age = phase - launch
        if age <= 0.0:
            continue
        radius, a, b, phi = gg_front_params(age, j)
        active.append((j, radius, a, b, phi))

    if not active:
        return

    theta = np.linspace(0.0, 2.0 * np.pi, 1500)
    _, outer_radius, outer_a, outer_b, outer_phi = active[0]
    radial_outer = gg_radius(theta, outer_radius, outer_a, outer_b, outer_phi)
    peak_index = int(np.argmax(radial_outer))
    peak_theta = theta[peak_index]
    peak_radius = radial_outer[peak_index]

    rotation = np.pi / 2.0 - peak_theta
    scale = half_separation / max(float(peak_radius), 1e-9)

    colors = ["#1f95ba", "#36a985", "#67b95d", "#d16b72"]
    for layer_number, (_, radius, a, b, phi) in enumerate(active):
        radial = gg_radius(theta, radius, a, b, phi)
        x = scale * radial * np.cos(theta)
        y = scale * radial * np.sin(theta)
        c = math.cos(rotation)
        s = math.sin(rotation)
        xr = c * x - s * y + midpoint[0]
        yr = s * x + c * y + midpoint[1]
        ax.plot(
            xr,
            yr,
            linewidth=2.0,
            color=colors[layer_number % len(colors)],
            alpha=0.94,
        )

    ax.plot(
        [node_top[0], node_bottom[0]],
        [node_top[1], node_bottom[1]],
        marker="o",
        linestyle="None",
        markersize=3.6,
        color=NODE,
        alpha=0.62,
    )


# ---------------------------------------------------------------------------
# Ветви пересечений для З/Г и З/З
# ---------------------------------------------------------------------------

@dataclass
class BranchPoint:
    branch_id: int
    point: np.ndarray
    parameter: float = 0.0
    accumulated: float = 0.0


def match_branches(
    previous: dict[int, BranchPoint],
    current_points: list[tuple[np.ndarray, float]],
    next_branch_id: int,
    threshold: float,
) -> tuple[dict[int, BranchPoint], int, list[int]]:
    candidates: list[tuple[float, int, int]] = []
    for branch_id, previous_point in previous.items():
        for current_index, (point, parameter) in enumerate(current_points):
            distance = float(np.linalg.norm(previous_point.point - point))
            if distance < threshold:
                candidates.append((distance, branch_id, current_index))
    candidates.sort(key=lambda item: item[0])

    used_previous: set[int] = set()
    used_current: set[int] = set()
    current_map: dict[int, BranchPoint] = {}
    new_ids: list[int] = []

    for _, branch_id, current_index in candidates:
        if branch_id in used_previous or current_index in used_current:
            continue
        used_previous.add(branch_id)
        used_current.add(current_index)
        point, parameter = current_points[current_index]
        previous_point = previous[branch_id]
        accumulated = previous_point.accumulated + abs(parameter - previous_point.parameter)
        current_map[branch_id] = BranchPoint(
            branch_id,
            point,
            parameter,
            accumulated,
        )

    for current_index, (point, parameter) in enumerate(current_points):
        if current_index in used_current:
            continue
        branch_id = next_branch_id
        next_branch_id += 1
        current_map[branch_id] = BranchPoint(
            branch_id,
            point,
            parameter,
            0.0,
        )
        new_ids.append(branch_id)

    return current_map, next_branch_id, new_ids


def stage_config(
    event_count: int,
    max_stage: int,
    scales: dict[int, float],
    maturities: dict[int, float],
) -> dict[int, tuple[float, float, int]]:
    event_count = max(0, min(event_count, max_stage))
    result: dict[int, tuple[float, float, int]] = {}
    for born in range(1, max_stage + 1):
        stage = min(event_count - born + 1, max_stage) if born <= event_count else 0
        result[born] = (scales[stage], maturities[stage], stage)
    return result


# ---------------------------------------------------------------------------
# 6. З/Г — спираль + круг, радиальный Фурье
# ---------------------------------------------------------------------------

def spiral_circle_intersections(
    green_center: np.ndarray,
    blue_center: np.ndarray,
    pitch: float,
    theta_end: float,
    phase: float,
    circle_radius: float,
    samples: int = 600,
) -> list[tuple[np.ndarray, float]]:
    if theta_end <= 1e-6:
        return []

    theta = np.linspace(0.0, theta_end, samples)
    radius = pitch * theta
    x = green_center[0] + radius * np.cos(theta + phase)
    y = green_center[1] + radius * np.sin(theta + phase)
    points = np.column_stack([x, y])

    distance_error = np.linalg.norm(points - blue_center, axis=1) - circle_radius

    roots: list[tuple[np.ndarray, float]] = []
    for i in range(len(theta) - 1):
        f0 = distance_error[i]
        f1 = distance_error[i + 1]
        if f0 == 0.0:
            q = 0.0
        elif f0 * f1 > 0.0:
            continue
        else:
            q = abs(f0) / max(abs(f0) + abs(f1), 1e-12)

        theta_root = theta[i] + q * (theta[i + 1] - theta[i])
        radius_root = pitch * theta_root
        point = green_center + radius_root * np.array(
            [math.cos(theta_root + phase), math.sin(theta_root + phase)]
        )
        roots.append((point, float(theta_root)))

    deduped: list[tuple[np.ndarray, float]] = []
    for point, parameter in roots:
        if all(
            np.linalg.norm(point - existing_point) >= 0.05
            or abs(parameter - existing_parameter) >= 0.18
            for existing_point, existing_parameter in deduped
        ):
            deduped.append((point, parameter))
    return deduped


@dataclass
class ZGFrame:
    green_spiral: np.ndarray
    blue_radius: float
    intersections: list[tuple[np.ndarray, float]]
    branches: list[BranchPoint]


def prepare_zg(frames: int) -> tuple[list[ZGFrame], np.ndarray, np.ndarray]:
    green_center = np.array([-1.35, -0.85])
    blue_center = np.array([1.25, -0.25])
    pitch = 0.12
    theta_full = 6.0 * np.pi

    time_values = np.linspace(0.0, 4.7, frames)
    previous: dict[int, BranchPoint] = {}
    next_branch_id = 0
    output: list[ZGFrame] = []

    for time in time_values:
        growth = min(max(time / 0.8, 0.0), 1.0)
        theta_end = theta_full * growth
        phase = -2.0 * np.pi * 0.82 * time
        blue_radius = 0.18 + 0.78 * time

        theta = np.linspace(0.0, theta_end, 500)
        radial = pitch * theta
        green_spiral = np.column_stack(
            [
                green_center[0] + radial * np.cos(theta + phase),
                green_center[1] + radial * np.sin(theta + phase),
            ]
        )

        intersections = spiral_circle_intersections(
            green_center,
            blue_center,
            pitch,
            theta_end,
            phase,
            blue_radius,
        )
        current, next_branch_id, _ = match_branches(
            previous,
            intersections,
            next_branch_id,
            threshold=0.38,
        )
        output.append(
            ZGFrame(
                green_spiral=green_spiral,
                blue_radius=blue_radius,
                intersections=intersections,
                branches=list(current.values()),
            )
        )
        previous = current

    return output, green_center, blue_center


def draw_zg_prepared(
    ax: plt.Axes,
    frame: ZGFrame,
    green_center: np.ndarray,
    blue_center: np.ndarray,
    title: str = "З/Г — радиальный Фурье, 3 стадии",
) -> None:
    configure_axis(ax, title, xlim=(-4.0, 4.0), ylim=(-3.3, 4.0))

    ax.plot(
        frame.green_spiral[:, 0],
        frame.green_spiral[:, 1],
        color=GREEN,
        linewidth=1.45,
        alpha=0.55,
    )
    circle_x, circle_y = circle_xy(blue_center, frame.blue_radius)
    ax.plot(circle_x, circle_y, color=CYAN, linewidth=1.45, alpha=0.58)
    draw_resonator(ax, green_center, GREEN)
    draw_resonator(ax, blue_center, CYAN)

    if frame.intersections:
        points = np.array([point for point, _ in frame.intersections])
        ax.plot(points[:, 0], points[:, 1], "o", markersize=3.0, color=NODE, alpha=0.24)

    scales = {0: 0.0, 1: 0.58, 2: 0.86, 3: 1.15}
    maturities = {0: 0.0, 1: 0.30, 2: 0.58, 3: 1.00}

    for branch in frame.branches:
        # Рождение даёт стадию 1; дальше один шаг на каждые π пути по спирали.
        events = min(3, int(branch.accumulated // np.pi) + 1)
        config = stage_config(events, 3, scales, maturities)

        direction = branch.point - green_center
        norm = float(np.linalg.norm(direction))
        if norm < 1e-8:
            direction = np.array([0.0, 1.0])
        else:
            direction /= norm
        angle = math.atan2(direction[1], direction[0]) - np.pi / 2.0

        ax.plot(
            branch.point[0],
            branch.point[1],
            marker="o",
            markersize=3.8,
            color=NODE,
            alpha=0.55,
        )

        for _, (scale, maturity, stage) in sorted(
            config.items(),
            key=lambda item: item[1][0],
            reverse=True,
        ):
            if stage == 0:
                continue
            curve = stage_curve(RADIAL_FOURIER_MASTER, RADIAL_FOURIER_SMOOTH, maturity)
            placed = rotate_scale_translate(curve, branch.point, scale, angle)
            linewidth = {1: 1.55, 2: 1.82, 3: 2.15}[stage]
            alpha = {1: 0.64, 2: 0.79, 3: 0.95}[stage]
            ax.plot(
                placed[:, 0],
                placed[:, 1],
                color="#33a870",
                linewidth=linewidth,
                alpha=alpha,
            )


# ---------------------------------------------------------------------------
# 7. З/З — две спирали, лист Гиелиса во всех реальных пересечениях
# ---------------------------------------------------------------------------

def polyline_intersections_vectorized(poly1: np.ndarray, poly2: np.ndarray) -> list[np.ndarray]:
    if len(poly1) < 2 or len(poly2) < 2:
        return []

    p = poly1[:-1]
    r = poly1[1:] - poly1[:-1]
    q = poly2[:-1]
    s = poly2[1:] - poly2[:-1]

    qp = q[None, :, :] - p[:, None, :]
    denominator = cross2(r[:, None, :], s[None, :, :])
    valid = np.abs(denominator) > 1e-10

    t = np.zeros_like(denominator)
    u = np.zeros_like(denominator)
    t[valid] = cross2(qp[valid], np.broadcast_to(s[None, :, :], qp.shape)[valid]) / denominator[valid]
    u[valid] = cross2(qp[valid], np.broadcast_to(r[:, None, :], qp.shape)[valid]) / denominator[valid]

    mask = valid & (t >= 0.0) & (t <= 1.0) & (u >= 0.0) & (u <= 1.0)
    indices = np.argwhere(mask)

    points = [p[i] + t[i, j] * r[i] for i, j in indices]
    return dedupe_points(points, threshold=0.05)


@dataclass
class ZZBranch:
    branch_id: int
    point: np.ndarray
    birth_time: float


@dataclass
class ZZFrame:
    spiral1: np.ndarray
    spiral2: np.ndarray
    intersections: list[np.ndarray]
    branches: list[ZZBranch]
    time: float


def prepare_zz(frames: int) -> tuple[list[ZZFrame], np.ndarray, np.ndarray]:
    c1 = np.array([-1.45, -0.90])
    c2 = np.array([1.45, -0.90])
    pitch = 0.12
    theta_full = 6.0 * np.pi

    times = np.linspace(0.0, 4.55, frames)
    previous_points: dict[int, np.ndarray] = {}
    birth_times: dict[int, float] = {}
    next_branch_id = 0
    output: list[ZZFrame] = []

    for time in times:
        growth = min(max(time / 1.0, 0.0), 1.0)
        theta_end = theta_full * growth
        theta = np.linspace(0.0, theta_end, 280)
        radial = pitch * theta
        phase1 = -2.0 * np.pi * time
        phase2 = np.pi + 2.0 * np.pi * time

        spiral1 = np.column_stack(
            [
                c1[0] + radial * np.cos(theta + phase1),
                c1[1] + radial * np.sin(theta + phase1),
            ]
        )
        spiral2 = np.column_stack(
            [
                c2[0] + radial * np.cos(-theta + phase2),
                c2[1] + radial * np.sin(-theta + phase2),
            ]
        )

        intersections = polyline_intersections_vectorized(spiral1, spiral2)
        current_points = [(point, 0.0) for point in intersections]

        previous_as_branches = {
            branch_id: BranchPoint(branch_id, point, 0.0, 0.0)
            for branch_id, point in previous_points.items()
        }
        matched, next_branch_id, new_ids = match_branches(
            previous_as_branches,
            current_points,
            next_branch_id,
            threshold=0.34,
        )
        for new_id in new_ids:
            birth_times[new_id] = time

        branches = [
            ZZBranch(branch_id, branch.point, birth_times.get(branch_id, time))
            for branch_id, branch in matched.items()
        ]
        output.append(
            ZZFrame(
                spiral1=spiral1,
                spiral2=spiral2,
                intersections=intersections,
                branches=branches,
                time=time,
            )
        )
        previous_points = {branch_id: branch.point for branch_id, branch in matched.items()}

    return output, c1, c2


def draw_zz_prepared(
    ax: plt.Axes,
    frame: ZZFrame,
    c1: np.ndarray,
    c2: np.ndarray,
    title: str = "З/З — лист Гиелиса во всех пересечениях",
) -> None:
    configure_axis(ax, title, xlim=(-3.8, 3.8), ylim=(-3.2, 4.0))

    ax.plot(frame.spiral1[:, 0], frame.spiral1[:, 1], color=GREEN_LIGHT, linewidth=1.35, alpha=0.58)
    ax.plot(frame.spiral2[:, 0], frame.spiral2[:, 1], color=GREEN_LIGHT, linewidth=1.35, alpha=0.58)
    draw_resonator(ax, c1, GREEN)
    draw_resonator(ax, c2, GREEN)

    axis_y = 0.5 * (c1[1] + c2[1])
    ax.plot([c1[0], c2[0]], [axis_y, axis_y], color=INK, linewidth=0.7, alpha=0.12)

    if frame.intersections:
        points = np.array(frame.intersections)
        ax.plot(points[:, 0], points[:, 1], "o", markersize=2.8, color=NODE, alpha=0.22)

    scales = {0: 0.0, 1: 0.72, 2: 1.02, 3: 1.31, 4: 1.60}
    maturities = {0: 0.0, 1: 0.30, 2: 0.56, 3: 0.80, 4: 1.00}

    for branch in frame.branches:
        age = max(frame.time - branch.birth_time, 0.0)
        # Каждые пол-оборота = 0.5 единицы времени в этой нормировке.
        events = min(4, int(age // 0.5) + 1)
        config = stage_config(events, 4, scales, maturities)

        orientation = 1.0 if branch.point[1] >= axis_y else -1.0
        ax.plot(
            branch.point[0],
            branch.point[1],
            marker="o",
            markersize=3.6,
            color=NODE,
            alpha=0.52,
        )

        for _, (scale, maturity, stage) in sorted(
            config.items(),
            key=lambda item: item[1][0],
            reverse=True,
        ):
            if stage == 0:
                continue
            curve = stage_curve(GIELIS_MASTER, GIELIS_SMOOTH, maturity).copy()
            curve[:, 1] *= orientation
            placed = rotate_scale_translate(curve, branch.point, scale, 0.0)
            linewidth = {1: 1.48, 2: 1.68, 3: 1.90, 4: 2.15}[stage]
            alpha = {1: 0.62, 2: 0.72, 3: 0.84, 4: 0.96}[stage]
            ax.plot(
                placed[:, 0],
                placed[:, 1],
                color=GREEN,
                linewidth=linewidth,
                alpha=alpha,
            )


# ---------------------------------------------------------------------------
# Генерация GIF и общего листа
# ---------------------------------------------------------------------------

def frame_phase(index: int, frames: int) -> float:
    if frames <= 1:
        return 0.0
    return index / (frames - 1)


def make_overview(
    output_path: Path,
    zg_frames: list[ZGFrame],
    zg_green: np.ndarray,
    zg_blue: np.ndarray,
    zz_frames: list[ZZFrame],
    zz_c1: np.ndarray,
    zz_c2: np.ndarray,
    dpi: int,
) -> None:
    fig, axes = plt.subplots(2, 4, figsize=(19, 9.5), facecolor=BG)
    fig.suptitle("Эллипс — принятые Резонансы", fontsize=22, y=0.99)

    draw_ff(axes[0, 0], 0.72)
    draw_fs(axes[0, 1], 0.72)
    draw_ss(axes[0, 2], 0.62)
    draw_sg(axes[0, 3], 0.62)
    draw_gg(axes[1, 0], 0.92)
    draw_zg_prepared(
        axes[1, 1],
        zg_frames[min(int(len(zg_frames) * 0.82), len(zg_frames) - 1)],
        zg_green,
        zg_blue,
    )
    draw_zz_prepared(
        axes[1, 2],
        zz_frames[min(int(len(zz_frames) * 0.86), len(zz_frames) - 1)],
        zz_c1,
        zz_c2,
    )

    axes[1, 3].axis("off")
    axes[1, 3].text(
        0.02,
        0.95,
        "Последовательность:\n"
        "Ф/Ф → Ф/С → С/С → С/Г → Г/Г → З/Г → З/З\n\n"
        "Кривые З/Г и З/З используют\n"
        "зафиксированные мастер-контуры.",
        transform=axes[1, 3].transAxes,
        va="top",
        fontsize=15,
        color=INK,
        linespacing=1.45,
    )

    plt.tight_layout(rect=(0.01, 0.01, 0.99, 0.965))
    fig.savefig(output_path, dpi=dpi, facecolor=BG)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("ellipse_resonance_output"),
        help="Каталог вывода.",
    )
    parser.add_argument(
        "--frames",
        type=int,
        default=72,
        help="Число кадров в каждой GIF.",
    )
    parser.add_argument(
        "--fps",
        type=int,
        default=10,
        help="Частота кадров GIF.",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=115,
        help="DPI GIF и общего листа.",
    )
    parser.add_argument(
        "--overview-only",
        action="store_true",
        help="Создать только единую статическую картинку.",
    )
    args = parser.parse_args()

    if args.frames < 8:
        raise ValueError("--frames должен быть не меньше 8")
    if args.fps < 1:
        raise ValueError("--fps должен быть положительным")

    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    print("Подготовка З/Г...")
    zg_frames, zg_green, zg_blue = prepare_zg(args.frames)
    print("Подготовка З/З...")
    zz_frames, zz_c1, zz_c2 = prepare_zz(args.frames)

    overview_path = output_dir / "ellipse_resonances_overview.png"
    make_overview(
        overview_path,
        zg_frames,
        zg_green,
        zg_blue,
        zz_frames,
        zz_c1,
        zz_c2,
        args.dpi,
    )
    print(f"Создано: {overview_path}")

    if args.overview_only:
        return

    jobs: list[tuple[str, Callable[[plt.Axes, int], None]]] = [
        (
            "01_FF_lissajous.gif",
            lambda ax, i: draw_ff(ax, frame_phase(i, args.frames)),
        ),
        (
            "02_FS_projection.gif",
            lambda ax, i: draw_fs(ax, frame_phase(i, args.frames)),
        ),
        (
            "03_SS_delaunay.gif",
            lambda ax, i: draw_ss(ax, frame_phase(i, args.frames)),
        ),
        (
            "04_SG_circumcircles.gif",
            lambda ax, i: draw_sg(ax, frame_phase(i, args.frames)),
        ),
        (
            "05_GG_rosette.gif",
            lambda ax, i: draw_gg(ax, frame_phase(i, args.frames)),
        ),
        (
            "06_ZG_radial_fourier.gif",
            lambda ax, i: draw_zg_prepared(ax, zg_frames[i], zg_green, zg_blue),
        ),
        (
            "07_ZZ_gielis_leaves.gif",
            lambda ax, i: draw_zz_prepared(ax, zz_frames[i], zz_c1, zz_c2),
        ),
    ]

    for filename, draw_function in jobs:
        path = output_dir / filename
        print(f"Генерация: {filename}")
        save_animation(
            draw_function,
            path,
            args.frames,
            args.fps,
            args.dpi,
        )

    print("Готово.")


if __name__ == "__main__":
    main()
