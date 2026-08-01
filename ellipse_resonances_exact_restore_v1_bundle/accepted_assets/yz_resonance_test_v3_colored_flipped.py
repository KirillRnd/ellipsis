import math
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from IPython.display import display, Image as IPImage, Markdown

OUT_DIR = Path("/mnt/data")
GIF_PATH = OUT_DIR / "yz_resonance_test_v3_colored_flipped.gif"
PNG_PATH = OUT_DIR / "yz_resonance_test_v3_colored_flipped_snapshot.png"

# ============================================================
# Ж/З — тест резонанса v3
#
# Изменения:
# 1) кусты одним жёлто-зелёным цветом;
# 2) зелёная спираль — зелёная;
# 3) жёлтые волны — жёлтые;
# 4) кусты ниже линии между резонаторами разворачиваются вниз.
# ============================================================

FPS = 12
N_FRAMES = 144

# Colors
COLOR_Y = "#d4c95f"       # yellow waves
COLOR_G = "#6fa06f"       # green spiral
COLOR_BUSH = "#a8be4d"    # yellow-green bushes
COLOR_NODE = "#202020"

LINEWIDTH_WAVE = 1.5
LINEWIDTH_RESONANCE = 1.9

# -------------------------
# Helpers
# -------------------------
def smoothstep(value: float) -> float:
    value = float(np.clip(value, 0.0, 1.0))
    return value * value * (3.0 - 2.0 * value)

def wrap_degrees(angle: float) -> float:
    return (angle + 180.0) % 360.0 - 180.0

def unit(angle_deg: float) -> np.ndarray:
    a = math.radians(angle_deg)
    return np.array([math.cos(a), math.sin(a)], dtype=float)

def direction_angle(a: np.ndarray, b: np.ndarray) -> float:
    d = b - a
    return math.degrees(math.atan2(d[1], d[0]))

def geometric_lengths(distance: float, count: int, ratio: float) -> list[float]:
    first = distance * (1.0 - ratio) / (1.0 - ratio**count)
    return [first * ratio**i for i in range(count)]

# -------------------------
# Accepted Ж/З bush from v5 pass A
# -------------------------
@dataclass(frozen=True)
class LocalSeg:
    start: np.ndarray
    end: np.ndarray
    birth: float
    duration: float

def build_local_shoot(
    *,
    start: np.ndarray,
    parent_angle: float,
    target: np.ndarray,
    count: int,
    ratio: float,
    split_angle: float,
    steering: float,
    alternation: float,
    phase: int,
):
    points = [np.array(start, dtype=float)]
    angles = []
    lengths = geometric_lengths(float(np.linalg.norm(target - start)), count, ratio)
    angle = parent_angle + split_angle
    geom = []

    for idx, length in enumerate(lengths):
        if idx > 0:
            desired = direction_angle(points[-1], target)
            correction = steering * wrap_degrees(desired - angle)
            angle = angle + correction + alternation * ((-1) ** (idx + phase))
        next_point = points[-1] + length * unit(angle)
        toward_target = target - points[-1]
        actual_step = next_point - points[-1]
        if float(np.dot(toward_target, actual_step)) <= 0.0:
            angle = direction_angle(points[-1], target)
            next_point = points[-1] + length * unit(angle)
        geom.append((points[-1].copy(), next_point.copy(), angle))
        points.append(next_point.copy())
        angles.append(angle)
    return np.vstack(points), angles, geom

def build_local_resonance_segments():
    targets = {
        "M1": np.array([0.00, 1.00]),
        "M2": np.array([-0.32, 0.80]),
        "M3": np.array([0.31, 0.79]),
        "M4": np.array([-0.56, 0.56]),
        "M5": np.array([0.55, 0.62]),
    }

    M1_pts, M1_ang, M1_geom = build_local_shoot(
        start=np.array([0.0, 0.0]),
        parent_angle=90.0,
        target=targets["M1"],
        count=6,
        ratio=0.96,
        split_angle=0.0,
        steering=0.70,
        alternation=1.5,
        phase=0,
    )
    M2_pts, M2_ang, M2_geom = build_local_shoot(
        start=M1_pts[1],
        parent_angle=M1_ang[0],
        target=targets["M2"],
        count=4,
        ratio=0.82,
        split_angle=34.0,
        steering=0.65,
        alternation=2.5,
        phase=0,
    )
    M3_pts, M3_ang, M3_geom = build_local_shoot(
        start=M1_pts[2],
        parent_angle=M1_ang[1],
        target=targets["M3"],
        count=4,
        ratio=0.82,
        split_angle=-32.0,
        steering=0.65,
        alternation=2.5,
        phase=1,
    )
    M4_pts, M4_ang, M4_geom = build_local_shoot(
        start=M2_pts[1],
        parent_angle=M2_ang[0],
        target=targets["M4"],
        count=3,
        ratio=0.76,
        split_angle=24.0,
        steering=0.65,
        alternation=3.0,
        phase=1,
    )
    M5_pts, M5_ang, M5_geom = build_local_shoot(
        start=M3_pts[1],
        parent_angle=M3_ang[0],
        target=targets["M5"],
        count=3,
        ratio=0.76,
        split_angle=-24.0,
        steering=0.65,
        alternation=3.0,
        phase=0,
    )

    growth_order = [
        ("M1", 0), ("M2", 0), ("M1", 1), ("M3", 0), ("M2", 1),
        ("M1", 2), ("M4", 0), ("M3", 1), ("M2", 2), ("M1", 3),
        ("M5", 0), ("M4", 1), ("M3", 2), ("M2", 3), ("M1", 4),
        ("M5", 1), ("M4", 2), ("M3", 3), ("M1", 5), ("M5", 2),
    ]
    births = {key: i * 0.072 for i, key in enumerate(growth_order)}
    duration = 0.105

    out = []
    for geom in (M1_geom, M2_geom, M3_geom, M4_geom, M5_geom):
        for idx, (start, end, _) in enumerate(geom):
            out.append(LocalSeg(start=start, end=end, birth=births[("M1", idx)] if False else 0, duration=duration))
    # Need exact birth order again in original sequence
    exact = []
    by_name = {"M1": M1_geom, "M2": M2_geom, "M3": M3_geom, "M4": M4_geom, "M5": M5_geom}
    for shoot in ("M1", "M2", "M3", "M4", "M5"):
        pass
    exact = []
    for shoot_name, geom in by_name.items():
        for idx, (start, end, _) in enumerate(geom):
            exact.append((shoot_name, idx, start, end))
    result = []
    for shoot_name, idx, start, end in exact:
        result.append(LocalSeg(start=start, end=end, birth=births[(shoot_name, idx)], duration=duration))
    return result

LOCAL_BUSH = build_local_resonance_segments()

# -------------------------
# Yellow resonator (Ж): widening cascade, +20% expansion
# -------------------------
Y_CENTER = np.array([-0.96, 0.00])
WAVE_PERIOD = 0.19
WAVE_SPEED = 0.80
WAVE_HALFHEIGHT0 = 0.12      # +20%
WAVE_GROWTH = 0.528          # +20%
N_WAVES = 10
WAVE_LIFETIME = 2.45

def yellow_front_state(t: float, k: int):
    launch = k * WAVE_PERIOD
    age = t - launch
    if age < 0 or age > WAVE_LIFETIME:
        return None
    x = Y_CENTER[0] + WAVE_SPEED * age
    half_h = WAVE_HALFHEIGHT0 + WAVE_GROWTH * age
    return x, half_h

# -------------------------
# Green resonator (З): Archimedean spiral
# -------------------------
G_CENTER = np.array([0.28, 0.04])
SPIRAL_GROW_T = 0.72
SPIRAL_MAX_TURNS = 3.0
SPIRAL_A = 0.070
SPIRAL_ROT_SPEED = -68.0

def spiral_polyline(t: float):
    turns = min(SPIRAL_MAX_TURNS, SPIRAL_MAX_TURNS * (t / SPIRAL_GROW_T))
    if turns <= 0:
        return np.empty((0, 2))
    theta_max = 2 * math.pi * turns
    n = max(200, int(160 * turns))
    theta = np.linspace(0.0, theta_max, n)

    if t <= SPIRAL_GROW_T:
        rot_deg = -25.0 * (t / SPIRAL_GROW_T) * turns
    else:
        rot_deg = -25.0 * SPIRAL_MAX_TURNS + SPIRAL_ROT_SPEED * (t - SPIRAL_GROW_T)
    rot = math.radians(rot_deg)

    r = SPIRAL_A * theta
    x = r * np.cos(theta + rot) + G_CENTER[0]
    y = r * np.sin(theta + rot) + G_CENTER[1]
    return np.column_stack([x, y])

# -------------------------
# Intersections and tracks
# -------------------------
def find_wave_spiral_intersections(x_wave: float, half_h: float, poly: np.ndarray):
    pts = []
    if len(poly) < 2:
        return pts
    y_min = -half_h
    y_max = half_h
    for p0, p1 in zip(poly[:-1], poly[1:]):
        x0, y0 = p0
        x1, y1 = p1
        if (x0 - x_wave) * (x1 - x_wave) > 0:
            continue
        if abs(x1 - x0) < 1e-8:
            continue
        u = (x_wave - x0) / (x1 - x0)
        if 0.0 <= u <= 1.0:
            y = y0 + u * (y1 - y0)
            if (Y_CENTER[1] + y_min) <= y <= (Y_CENTER[1] + y_max):
                pts.append(np.array([x_wave, y], dtype=float))
    pts_sorted = sorted(pts, key=lambda p: p[1])
    unique = []
    for p in pts_sorted:
        if not unique or np.linalg.norm(p - unique[-1]) > 0.035:
            unique.append(p)
    return unique

@dataclass
class Track:
    wave_id: int
    birth: float
    positions_by_frame: dict = field(default_factory=dict)

FRAME_TIMES = np.linspace(0.0, 2.55, N_FRAMES)

tracks = []
active_by_wave = {k: [] for k in range(N_WAVES)}

for fi, t in enumerate(FRAME_TIMES):
    poly = spiral_polyline(t)
    for k in range(N_WAVES):
        state = yellow_front_state(t, k)
        current_points = []
        if state is not None:
            x_wave, half_h = state
            current_points = find_wave_spiral_intersections(x_wave, half_h, poly)

        prev_track_ids = active_by_wave[k]
        used_indices = set()
        new_active = []

        for track_id in prev_track_ids:
            track = tracks[track_id]
            prev_positions = [track.positions_by_frame[fj] for fj in sorted(track.positions_by_frame.keys()) if fj < fi]
            if not prev_positions:
                continue
            prev_pos = prev_positions[-1]
            best_idx = None
            best_dist = 999
            for idx, pt in enumerate(current_points):
                if idx in used_indices:
                    continue
                dist = np.linalg.norm(pt - prev_pos)
                if dist < best_dist:
                    best_dist = dist
                    best_idx = idx
            if best_idx is not None and best_dist < 0.18:
                track.positions_by_frame[fi] = current_points[best_idx]
                used_indices.add(best_idx)
                new_active.append(track_id)

        for idx, pt in enumerate(current_points):
            if idx in used_indices:
                continue
            track = Track(wave_id=k, birth=t, positions_by_frame={fi: pt})
            tracks.append(track)
            new_active.append(len(tracks) - 1)

        active_by_wave[k] = new_active

tracks = [tr for tr in tracks if len(tr.positions_by_frame) >= 2]

# -------------------------
# Bush orientation relative to resonator-connecting line
# -------------------------
LINE_VEC = G_CENTER - Y_CENTER

def point_is_below_resonator_line(p: np.ndarray) -> bool:
    rel = p - Y_CENTER
    cross = LINE_VEC[0] * rel[1] - LINE_VEC[1] * rel[0]
    return cross < 0

# -------------------------
# Drawing
# -------------------------
XMIN, XMAX = -1.18, 1.08
YMIN, YMAX = -0.95, 1.30
BUSH_SCALE = 0.48

def draw_yellow(ax, t: float):
    ax.plot(Y_CENTER[0], Y_CENTER[1], "o", color=COLOR_NODE, markersize=4)
    for k in range(N_WAVES):
        state = yellow_front_state(t, k)
        if state is None:
            continue
        x_wave, half_h = state
        ax.plot(
            [x_wave, x_wave],
            [Y_CENTER[1] - half_h, Y_CENTER[1] + half_h],
            linewidth=LINEWIDTH_WAVE,
            color=COLOR_Y,
        )

def draw_green(ax, t: float):
    ax.plot(G_CENTER[0], G_CENTER[1], "o", color=COLOR_NODE, markersize=4)
    poly = spiral_polyline(t)
    if len(poly) > 1:
        ax.plot(poly[:, 0], poly[:, 1], linewidth=LINEWIDTH_WAVE, color=COLOR_G)

def draw_bush_at(ax, root: np.ndarray, local_age: float):
    flip_down = point_is_below_resonator_line(root)
    for seg in LOCAL_BUSH:
        progress = smoothstep((local_age - seg.birth) / seg.duration)
        if progress <= 0:
            continue
        start_local = seg.start.copy()
        end_local = seg.start + progress * (seg.end - seg.start)
        if flip_down:
            start_local = np.array([start_local[0], -start_local[1]])
            end_local = np.array([end_local[0], -end_local[1]])
        start = root + BUSH_SCALE * start_local
        end = root + BUSH_SCALE * end_local
        ax.plot(
            [start[0], end[0]],
            [start[1], end[1]],
            linewidth=LINEWIDTH_RESONANCE,
            solid_capstyle="round",
            color=COLOR_BUSH,
        )

def draw_resonances(ax, fi: int, t: float):
    for track in tracks:
        pos = track.positions_by_frame.get(fi)
        if pos is None:
            continue
        local_age = t - track.birth
        if local_age < 0:
            continue
        ax.plot(pos[0], pos[1], "o", color=COLOR_NODE, markersize=3)
        draw_bush_at(ax, pos, local_age)

def draw_frame(ax, fi: int, t: float):
    ax.clear()
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(YMIN, YMAX)

    draw_yellow(ax, t)
    draw_green(ax, t)
    draw_resonances(ax, fi, t)

    ax.text(
        XMIN + 0.03, YMAX - 0.04,
        "Ж/З — тест резонанса v3\n"
        "жёлтые волны, зелёная спираль, одинаковые жёлто-зелёные кусты\n"
        "кусты ниже линии резонаторов развёрнуты вниз",
        va="top",
        fontsize=9.6,
        color=COLOR_NODE,
    )

snapshot_frame = int(0.72 * (N_FRAMES - 1))
snapshot_time = FRAME_TIMES[snapshot_frame]

fig, ax = plt.subplots(figsize=(7.2, 7.2))
draw_frame(ax, snapshot_frame, snapshot_time)
fig.tight_layout()
fig.savefig(PNG_PATH, dpi=150, bbox_inches="tight")
plt.close(fig)

fig, ax = plt.subplots(figsize=(7.2, 7.2))
def update(frame_index: int):
    draw_frame(ax, frame_index, FRAME_TIMES[frame_index])
    return []
ani = FuncAnimation(fig, update, frames=N_FRAMES, interval=1000 / FPS, blit=False)
ani.save(GIF_PATH, writer=PillowWriter(fps=FPS))
plt.close(fig)

display(Markdown(
    "Сделал **v3**: перекрасил элементы по ролям и перевернул вниз те кусты, "
    "чьи точки резонанса лежат **ниже линии**, соединяющей жёлтый и зелёный резонаторы."
))
display(IPImage(filename=str(PNG_PATH)))
display(IPImage(filename=str(GIF_PATH)))

print("TRACKS:", len(tracks))
print("PNG:", PNG_PATH)
print("GIF:", GIF_PATH)
