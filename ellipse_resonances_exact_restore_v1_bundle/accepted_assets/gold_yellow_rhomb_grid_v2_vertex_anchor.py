
from pathlib import Path
import math
from dataclasses import dataclass

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

OUT = Path(__file__).resolve().parent
GIF_PATH = OUT / "gold_yellow_rhomb_grid_v2_vertex_anchor.gif"
PNG_PATH = OUT / "gold_yellow_rhomb_grid_v2_vertex_anchor_snapshot.png"

FPS = 12
N_FRAMES = 156
T_MAX = 3.45
TIMES = np.linspace(0.0, T_MAX, N_FRAMES)

XMIN, XMAX = -1.18, 1.18
YMIN, YMAX = -0.78, 1.16

COLOR_GOLD = "#c6a34a"
COLOR_YELLOW = "#e0cf42"
COLOR_GRID = "#efd56c"
COLOR_POINT = "#5b4a1b"
COLOR_NODE = "#202020"

R_GOLD = np.array([-0.72, -0.40], dtype=float)
R_YELLOW = np.array([ 0.72, -0.40], dtype=float)

LINE_ANGLE_GOLD = math.radians(150.0)
LINE_ANGLE_YELLOW = math.radians(30.0)

d_gold = np.array([math.cos(LINE_ANGLE_GOLD), math.sin(LINE_ANGLE_GOLD)])
d_yellow = np.array([math.cos(LINE_ANGLE_YELLOW), math.sin(LINE_ANGLE_YELLOW)])

n_gold = np.array([math.cos(math.radians(60.0)), math.sin(math.radians(60.0))])
n_yellow = np.array([math.cos(math.radians(120.0)), math.sin(math.radians(120.0))])

N_WAVES = 7
PERIOD = 0.235
SPEED_GOLD = 0.66
SPEED_YELLOW = 0.66
BASE_HALF_LEN = 0.065
HALF_LEN_GROWTH = 0.54
WAVE_LIFETIME = 2.85

TILE_FADE_TIME = 0.13
PER_TILE_DELAY = 0.050
REVEAL_MANHATTAN_RADIUS = 2


@dataclass(frozen=True)
class Wave:
    family: str
    index: int
    launch: float
    origin: np.ndarray
    normal: np.ndarray
    tangent: np.ndarray
    speed: float


def smoothstep(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def wave_state(wave: Wave, t: float):
    age = t - wave.launch
    if age < 0.0 or age > WAVE_LIFETIME:
        return None

    center = wave.origin + wave.speed * age * wave.normal
    half_len = BASE_HALF_LEN + HALF_LEN_GROWTH * age

    a = center - half_len * wave.tangent
    b = center + half_len * wave.tangent
    return center, a, b


def segment_intersection(p1, p2, q1, q2):
    r = p2 - p1
    s = q2 - q1
    denom = r[0] * s[1] - r[1] * s[0]
    if abs(denom) < 1e-9:
        return None

    qp = q1 - p1
    tr = (qp[0] * s[1] - qp[1] * s[0]) / denom
    ts = (qp[0] * r[1] - qp[1] * r[0]) / denom

    if 0.0 <= tr <= 1.0 and 0.0 <= ts <= 1.0:
        return p1 + tr * r
    return None


gold_waves = [Wave("G", k, k * PERIOD, R_GOLD, n_gold, d_gold, SPEED_GOLD) for k in range(N_WAVES)]
yellow_waves = [Wave("Ж", k, k * PERIOD, R_YELLOW, n_yellow, d_yellow, SPEED_YELLOW) for k in range(N_WAVES)]
wave_pairs = [(wg, wy) for wg in gold_waves for wy in yellow_waves]

intersection_points = np.full((N_FRAMES, len(wave_pairs), 2), np.nan, dtype=float)
first_frame_by_pair = np.full(len(wave_pairs), -1, dtype=int)

first_global_frame = None
first_global_point = None

for frame_index, t in enumerate(TIMES):
    for pair_index, (wg, wy) in enumerate(wave_pairs):
        sg = wave_state(wg, t)
        sy = wave_state(wy, t)
        if sg is None or sy is None:
            continue

        p = segment_intersection(sg[1], sg[2], sy[1], sy[2])
        if p is None:
            continue

        intersection_points[frame_index, pair_index] = p

        if first_frame_by_pair[pair_index] < 0:
            first_frame_by_pair[pair_index] = frame_index

        if first_global_frame is None:
            first_global_frame = frame_index
            first_global_point = p.copy()

if first_global_frame is None:
    raise RuntimeError("No real intersections were generated.")

FIRST_TIME = float(TIMES[first_global_frame])
FIRST_POINT = first_global_point.copy()

velocity_matrix = np.vstack([n_gold, n_yellow])
velocity_rhs = np.array([SPEED_GOLD, SPEED_YELLOW], dtype=float)
GRID_VELOCITY = np.linalg.solve(velocity_matrix, velocity_rhs)


def grid_origin(t: float) -> np.ndarray:
    return FIRST_POINT + GRID_VELOCITY * (t - FIRST_TIME)


pair_local_positions = np.full((len(wave_pairs), 2), np.nan, dtype=float)
for pair_index in range(len(wave_pairs)):
    valid_frames = np.where(~np.isnan(intersection_points[:, pair_index, 0]))[0]
    if len(valid_frames) == 0:
        continue
    samples = np.array([
        intersection_points[fi, pair_index] - grid_origin(float(TIMES[fi]))
        for fi in valid_frames
    ])
    pair_local_positions[pair_index] = samples.mean(axis=0)

spacing_gold = SPEED_GOLD * PERIOD
spacing_yellow = SPEED_YELLOW * PERIOD

step_vector_gold = np.linalg.solve(
    velocity_matrix,
    np.array([spacing_gold, 0.0], dtype=float),
)
step_vector_yellow = np.linalg.solve(
    velocity_matrix,
    np.array([0.0, spacing_yellow], dtype=float),
)

typical_intersection_step = math.sqrt(
    np.linalg.norm(step_vector_gold) * np.linalg.norm(step_vector_yellow)
)

TILE_EDGE = typical_intersection_step / 3.0

u = TILE_EDGE * d_gold
v = TILE_EDGE * d_yellow

raw_angle = abs(LINE_ANGLE_GOLD - LINE_ANGLE_YELLOW) % math.pi
ACUTE_RHOMB_ANGLE = min(raw_angle, math.pi - raw_angle)

# Build local uniform rhomb grid.
I_MIN, I_MAX = -24, 24
J_MIN, J_MAX = -24, 24

tiles = []
tile_index_by_ij = {}

for i in range(I_MIN, I_MAX + 1):
    for j in range(J_MIN, J_MAX + 1):
        p0 = i * u + j * v
        points = np.array([
            p0,
            p0 + u,
            p0 + u + v,
            p0 + v,
            p0,
        ], dtype=float)
        center = p0 + 0.5 * (u + v)

        if np.linalg.norm(center) > 1.75:
            continue

        tile_index_by_ij[(i, j)] = len(tiles)
        tiles.append({"ij": (i, j), "points": points, "center": center})

# Vertex-anchor correction:
# Previously local origin sat at a tile center.
# Now local origin sits exactly on a rhomb vertex.
# So the first real intersection equals one corner of the seed rhomb.
for tile in tiles:
    tile["points"] = tile["points"]  # explicit: no center shift
    tile["center"] = tile["center"]

tile_centers = np.array([tile["center"] for tile in tiles], dtype=float)

tile_birth_times = np.full(len(tiles), np.inf, dtype=float)

for pair_index, birth_frame in enumerate(first_frame_by_pair):
    if birth_frame < 0:
        continue

    birth_time = float(TIMES[birth_frame])
    local_p = pair_local_positions[pair_index]

    # Because the intersection is a vertex anchor, choose the seed tile whose
    # one of vertices is nearest to the local intersection.
    best_tile = None
    best_dist = float("inf")
    for idx, tile in enumerate(tiles):
        d = np.min(np.linalg.norm(tile["points"][:4] - local_p[None, :], axis=1))
        if d < best_dist:
            best_dist = d
            best_tile = idx

    nearest_tile = int(best_tile)
    seed_i, seed_j = tiles[nearest_tile]["ij"]

    candidates = []
    for di in range(-REVEAL_MANHATTAN_RADIUS, REVEAL_MANHATTAN_RADIUS + 1):
        for dj in range(-REVEAL_MANHATTAN_RADIUS, REVEAL_MANHATTAN_RADIUS + 1):
            shell = abs(di) + abs(dj)
            if shell > REVEAL_MANHATTAN_RADIUS:
                continue
            ij = (seed_i + di, seed_j + dj)
            tile_index = tile_index_by_ij.get(ij)
            if tile_index is None:
                continue
            angle = math.atan2(dj, di) if (di != 0 or dj != 0) else -math.pi
            candidates.append((shell, angle, tile_index))

    candidates.sort(key=lambda x: (x[0], x[1]))

    for order, (_, _, tile_index) in enumerate(candidates):
        scheduled = birth_time + order * PER_TILE_DELAY
        if tile_index == nearest_tile:
            scheduled = birth_time - 0.10
        tile_birth_times[tile_index] = min(tile_birth_times[tile_index], scheduled)


def draw_waves(ax, t: float):
    ax.plot(R_GOLD[0], R_GOLD[1], "o", color=COLOR_NODE, markersize=5)
    ax.plot(R_YELLOW[0], R_YELLOW[1], "o", color=COLOR_NODE, markersize=5)

    for wave in gold_waves:
        state = wave_state(wave, t)
        if state is None:
            continue
        a, b = state[1], state[2]
        ax.plot([a[0], b[0]], [a[1], b[1]], color=COLOR_GOLD, linewidth=1.8)

    for wave in yellow_waves:
        state = wave_state(wave, t)
        if state is None:
            continue
        a, b = state[1], state[2]
        ax.plot([a[0], b[0]], [a[1], b[1]], color=COLOR_YELLOW, linewidth=1.8)


def draw_grid(ax, t: float):
    origin = grid_origin(t)
    for tile, birth in zip(tiles, tile_birth_times):
        if not math.isfinite(birth) or t < birth:
            continue
        alpha = smoothstep((t - birth) / TILE_FADE_TIME)
        pts = tile["points"] + origin
        ax.plot(
            pts[:, 0],
            pts[:, 1],
            color=COLOR_GRID,
            linewidth=1.65,
            alpha=alpha,
        )


def draw_intersections(ax, frame_index: int):
    points = intersection_points[frame_index]
    valid = ~np.isnan(points[:, 0])
    if not np.any(valid):
        return
    visible = points[valid]
    ax.scatter(
        visible[:, 0],
        visible[:, 1],
        s=8,
        color=COLOR_POINT,
        zorder=5,
    )


def draw_frame(ax, frame_index: int):
    t = float(TIMES[frame_index])

    ax.clear()
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(YMIN, YMAX)

    draw_waves(ax, t)
    draw_grid(ax, t)
    draw_intersections(ax, frame_index)

    ax.text(
        XMIN + 0.03,
        YMAX - 0.04,
        "G/Ж — равномерная наклонная ромбическая сетка\n"
        "первый ромб привязан углом к точке пересечения",
        va="top",
        fontsize=9.5,
        color=COLOR_NODE,
    )


snapshot_frame = int(0.68 * (N_FRAMES - 1))

fig, ax = plt.subplots(figsize=(7.2, 6.6))
draw_frame(ax, snapshot_frame)
fig.tight_layout()
fig.savefig(PNG_PATH, dpi=150, bbox_inches="tight")
plt.close(fig)

fig, ax = plt.subplots(figsize=(7.2, 6.6))
def update(frame_index: int):
    draw_frame(ax, frame_index)
    return []

animation = FuncAnimation(
    fig,
    update,
    frames=N_FRAMES,
    interval=1000 / FPS,
    blit=False,
)
animation.save(GIF_PATH, writer=PillowWriter(fps=FPS))
plt.close(fig)

print("GIF:", GIF_PATH)
print("PNG:", PNG_PATH)
print("First intersection:", round(FIRST_TIME, 4))
print("Grid velocity:", np.round(GRID_VELOCITY, 5))
print("Rhomb angle:", round(math.degrees(ACUTE_RHOMB_ANGLE), 2))
print("Tile edge:", round(TILE_EDGE, 5))
print("Revealed tiles:", int(np.isfinite(tile_birth_times).sum()))
