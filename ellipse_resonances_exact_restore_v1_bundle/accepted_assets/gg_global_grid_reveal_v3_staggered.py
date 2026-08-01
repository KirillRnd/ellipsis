from pathlib import Path
import math
from dataclasses import dataclass
import hashlib

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from IPython.display import display, Markdown, Image as IPImage

OUT = Path("/mnt/data/gg_global_grid_reveal_v3_staggered")
OUT.mkdir(parents=True, exist_ok=True)

GIF_PATH = OUT / "gg_global_grid_reveal_v3_staggered.gif"
PNG_PATH = OUT / "gg_global_grid_reveal_v3_staggered_snapshot.png"

PHI = (1 + 5**0.5) / 2

COLOR_WAVE = "#c8a24a"
COLOR_TILE = "#f0d66a"
COLOR_INTERSECTION = "#5d4b18"
COLOR_NODE = "#202020"

FPS = 12
N_FRAMES = 156
T_MAX = 3.35
TIMES = np.linspace(0.0, T_MAX, N_FRAMES)

XMIN, XMAX = -1.25, 1.15
YMIN, YMAX = -0.95, 1.10

# ------------------------------------------------------------
# Resonators and straight-wave cascades
# ------------------------------------------------------------
R1 = np.array([-0.78, -0.22], dtype=float)
R2 = np.array([0.56, -0.12], dtype=float)

ANGLE_A = 28.0
ANGLE_B = 118.0

n1 = np.array([math.cos(math.radians(ANGLE_A)), math.sin(math.radians(ANGLE_A))], dtype=float)
n2 = np.array([math.cos(math.radians(ANGLE_B)), math.sin(math.radians(ANGLE_B))], dtype=float)

d1 = np.array([-n1[1], n1[0]], dtype=float)
d2 = np.array([-n2[1], n2[0]], dtype=float)

N_WAVES = 7
WAVE_PERIOD = 0.22
WAVE_SPEED_A = 0.72
WAVE_SPEED_B = 0.72
BASE_HALF_LEN = 0.07
HALF_LEN_GROWTH = 0.56
WAVE_LIFETIME = 2.75

@dataclass(frozen=True)
class Wave:
    family: int
    index: int
    launch: float
    origin: np.ndarray
    normal: np.ndarray
    tangent: np.ndarray
    speed: float

def smoothstep(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)

def unit(theta: float) -> np.ndarray:
    return np.array([math.cos(theta), math.sin(theta)], dtype=float)

def wave_state(wave: Wave, t: float):
    age = t - wave.launch
    if age < 0.0 or age > WAVE_LIFETIME:
        return None
    center = wave.origin + wave.speed * age * wave.normal
    half_len = BASE_HALF_LEN + HALF_LEN_GROWTH * age
    a = center - half_len * wave.tangent
    b = center + half_len * wave.tangent
    return center, half_len, a, b

def segment_intersection(p1, p2, q1, q2):
    r = p2 - p1
    s = q2 - q1
    denominator = r[0] * s[1] - r[1] * s[0]
    if abs(denominator) < 1e-9:
        return None
    qp = q1 - p1
    tr = (qp[0] * s[1] - qp[1] * s[0]) / denominator
    ts = (qp[0] * r[1] - qp[1] * r[0]) / denominator
    if 0.0 <= tr <= 1.0 and 0.0 <= ts <= 1.0:
        return p1 + tr * r
    return None

waves_a = [
    Wave(0, k, k * WAVE_PERIOD, R1, n1, d1, WAVE_SPEED_A)
    for k in range(N_WAVES)
]
waves_b = [
    Wave(1, k, k * WAVE_PERIOD, R2, n2, d2, WAVE_SPEED_B)
    for k in range(N_WAVES)
]
wave_pairs = [(a, b) for a in waves_a for b in waves_b]

# ------------------------------------------------------------
# All finite-segment intersections
# ------------------------------------------------------------
intersection_points = np.full((N_FRAMES, len(wave_pairs), 2), np.nan, dtype=float)
first_frame_by_pair = np.full(len(wave_pairs), -1, dtype=int)

first_global_frame = None
first_global_point = None

for frame_index, t in enumerate(TIMES):
    for pair_index, (wa, wb) in enumerate(wave_pairs):
        sa = wave_state(wa, t)
        sb = wave_state(wb, t)
        if sa is None or sb is None:
            continue
        point = segment_intersection(sa[2], sa[3], sb[2], sb[3])
        if point is None:
            continue
        intersection_points[frame_index, pair_index] = point
        if first_frame_by_pair[pair_index] < 0:
            first_frame_by_pair[pair_index] = frame_index
        if first_global_frame is None:
            first_global_frame = frame_index
            first_global_point = point.copy()

FIRST_TIME = float(TIMES[first_global_frame])
FIRST_POINT = first_global_point.copy()

# ------------------------------------------------------------
# Moving global grid velocity
# ------------------------------------------------------------
velocity_matrix = np.vstack([n1, n2])
velocity_rhs = np.array([WAVE_SPEED_A, WAVE_SPEED_B], dtype=float)
GRID_VELOCITY = np.linalg.solve(velocity_matrix, velocity_rhs)

def grid_origin(t: float) -> np.ndarray:
    return FIRST_POINT + GRID_VELOCITY * (t - FIRST_TIME)

# ------------------------------------------------------------
# Local coordinates of all intersections in the moving frame
# ------------------------------------------------------------
pair_local_positions = np.full((len(wave_pairs), 2), np.nan, dtype=float)

for pair_index in range(len(wave_pairs)):
    valid_frames = np.where(~np.isnan(intersection_points[:, pair_index, 0]))[0]
    if len(valid_frames) == 0:
        continue
    local_samples = np.array([
        intersection_points[fi, pair_index] - grid_origin(float(TIMES[fi]))
        for fi in valid_frames
    ])
    pair_local_positions[pair_index] = local_samples.mean(axis=0)

# ------------------------------------------------------------
# Automatic scale from actual intersection lattice step
# ------------------------------------------------------------
cascade_spacing_a = WAVE_SPEED_A * WAVE_PERIOD
cascade_spacing_b = WAVE_SPEED_B * WAVE_PERIOD

STEP_VECTOR_A = np.linalg.solve(velocity_matrix, np.array([cascade_spacing_a, 0.0], dtype=float))
STEP_VECTOR_B = np.linalg.solve(velocity_matrix, np.array([0.0, cascade_spacing_b], dtype=float))

TYPICAL_INTERSECTION_STEP = math.sqrt(
    np.linalg.norm(STEP_VECTOR_A) * np.linalg.norm(STEP_VECTOR_B)
)

TILE_EDGE = 0.42 * TYPICAL_INTERSECTION_STEP
TILE_REVEAL_TIME = 0.13

# Slightly larger reveal neighborhood than v2.
REVEAL_RADIUS = 1.18 * TYPICAL_INTERSECTION_STEP
REVEAL_DELAY_PER_TILE = 0.055  # sequential reveal cadence

# ------------------------------------------------------------
# One hidden Penrose grid in LOCAL moving-grid coordinates
# ------------------------------------------------------------
line_angle_a = math.atan2(d1[1], d1[0])
line_angle_b = math.atan2(d2[1], d2[0])

def interpolate_unoriented_angle(a: float, b: float) -> float:
    difference = (b - a + math.pi / 2.0) % math.pi - math.pi / 2.0
    return a + 0.5 * difference

GRID_BASE_ANGLE = interpolate_unoriented_angle(line_angle_a, line_angle_b)
GRID_DIRECTIONS = np.array(
    [unit(GRID_BASE_ANGLE + 2.0 * math.pi * k / 5.0) for k in range(5)],
    dtype=float,
)
GRID_PHASES = np.array([0.17, 0.43, 0.69, 0.11, 0.57], dtype=float)
GRID_EPS = 1e-6

active_local_positions = pair_local_positions[~np.isnan(pair_local_positions[:, 0])]
LOCAL_CROP_RADIUS = max(1.25, float(np.linalg.norm(active_local_positions, axis=1).max() + 0.65))

def generate_penrose_patch():
    integer_limit = 22
    grid_radius = 15.0
    vertex_ids = {}
    vertices = []
    candidate_tiles = []
    tile_keys = set()

    def get_vertex_id(address: np.ndarray) -> int:
        key = tuple(int(v) for v in address)
        if key not in vertex_ids:
            vertex_ids[key] = len(vertices)
            local_position = np.sum(np.array(key, dtype=float)[:, None] * GRID_DIRECTIONS, axis=0) * TILE_EDGE
            vertices.append(local_position)
        return vertex_ids[key]

    for i in range(5):
        for j in range(i + 1, 5):
            matrix = np.vstack([GRID_DIRECTIONS[i], GRID_DIRECTIONS[j]])
            if abs(np.linalg.det(matrix)) < 1e-9:
                continue
            for mi in range(-integer_limit, integer_limit + 1):
                for mj in range(-integer_limit, integer_limit + 1):
                    rhs = np.array([mi - GRID_PHASES[i], mj - GRID_PHASES[j]], dtype=float)
                    pentagrid_intersection = np.linalg.solve(matrix, rhs)
                    if np.linalg.norm(pentagrid_intersection) > grid_radius:
                        continue
                    sample = pentagrid_intersection - 1e-4 * (GRID_DIRECTIONS[i] + GRID_DIRECTIONS[j])
                    values = GRID_DIRECTIONS @ sample + GRID_PHASES
                    base_address = np.ceil(values - GRID_EPS).astype(int)

                    addresses = [base_address.copy() for _ in range(4)]
                    addresses[1][i] += 1
                    addresses[2][i] += 1
                    addresses[2][j] += 1
                    addresses[3][j] += 1

                    vids = [get_vertex_id(address) for address in addresses]
                    tile_key = tuple(sorted(vids))
                    if tile_key in tile_keys:
                        continue
                    tile_keys.add(tile_key)

                    points = np.array([vertices[vid] for vid in vids + [vids[0]]], dtype=float)
                    center = points[:4].mean(axis=0)

                    candidate_tiles.append({"vids": vids, "points": points, "center": center})

    centers = np.array([tile["center"] for tile in candidate_tiles])
    origin_tile_index = int(np.argmin(np.linalg.norm(centers, axis=1)))
    origin_shift = centers[origin_tile_index].copy()

    cropped_tiles = []
    for tile in candidate_tiles:
        local_points = tile["points"] - origin_shift
        local_center = tile["center"] - origin_shift
        if np.linalg.norm(local_center) > LOCAL_CROP_RADIUS:
            continue
        cropped_tiles.append({"vids": tile["vids"], "points": local_points, "center": local_center})

    # Largest exact edge-connected component.
    edge_to_tiles = {}
    for tile_index, tile in enumerate(cropped_tiles):
        v = tile["vids"]
        edges = ((v[0], v[1]), (v[1], v[2]), (v[2], v[3]), (v[3], v[0]))
        for a, b in edges:
            edge_to_tiles.setdefault(tuple(sorted((a, b))), []).append(tile_index)

    adjacency = {idx: set() for idx in range(len(cropped_tiles))}
    for attached in edge_to_tiles.values():
        if len(attached) == 2:
            a, b = attached
            adjacency[a].add(b)
            adjacency[b].add(a)

    visited = set()
    components = []
    for start in range(len(cropped_tiles)):
        if start in visited:
            continue
        stack = [start]
        visited.add(start)
        comp = []
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for nb in adjacency[cur]:
                if nb not in visited:
                    visited.add(nb)
                    stack.append(nb)
        components.append(comp)

    largest_component = max(components, key=len)
    old_to_new = {old: new for new, old in enumerate(largest_component)}
    final_tiles = [cropped_tiles[old] for old in largest_component]

    final_adjacency = {i: set() for i in range(len(final_tiles))}
    for old in largest_component:
        ni = old_to_new[old]
        for old_nb in adjacency[old]:
            if old_nb in old_to_new:
                final_adjacency[ni].add(old_to_new[old_nb])

    return final_tiles, final_adjacency

GLOBAL_TILES, TILE_ADJACENCY = generate_penrose_patch()
TILE_CENTERS_LOCAL = np.array([tile["center"] for tile in GLOBAL_TILES], dtype=float)

# ------------------------------------------------------------
# Reveal schedule:
# - slightly larger radius
# - tiles appear one-by-one instead of all at once
# ------------------------------------------------------------
tile_birth_times = np.full(len(GLOBAL_TILES), np.inf, dtype=float)

for pair_index, birth_frame in enumerate(first_frame_by_pair):
    if birth_frame < 0:
        continue

    birth_time = float(TIMES[birth_frame])
    local_intersection = pair_local_positions[pair_index]

    distances = np.linalg.norm(TILE_CENTERS_LOCAL - local_intersection, axis=1)
    nearby_tiles = np.where(distances <= REVEAL_RADIUS)[0]

    # Always ensure the nearest tile is included as the immediate seed.
    nearest_tile = int(np.argmin(distances))
    if nearest_tile not in nearby_tiles:
        nearby_tiles = np.concatenate([nearby_tiles, np.array([nearest_tile])])

    # Remove duplicates and sort by distance, then by angle for a stable local "unfolding".
    unique_tiles = sorted(set(int(i) for i in nearby_tiles))
    scored = []
    for tile_index in unique_tiles:
        vec = TILE_CENTERS_LOCAL[tile_index] - local_intersection
        angle = math.atan2(vec[1], vec[0])
        scored.append((distances[tile_index], angle, tile_index))
    scored.sort()

    for order, (_, _, tile_index) in enumerate(scored):
        scheduled_time = birth_time + order * REVEAL_DELAY_PER_TILE
        if tile_index == nearest_tile:
            scheduled_time = birth_time - 0.10
        tile_birth_times[tile_index] = min(tile_birth_times[tile_index], scheduled_time)

# ------------------------------------------------------------
# Drawing
# ------------------------------------------------------------
def draw_parent_waves(ax, t: float):
    ax.plot(R1[0], R1[1], "o", color=COLOR_NODE, markersize=5)
    ax.plot(R2[0], R2[1], "o", color=COLOR_NODE, markersize=5)

    for wave in waves_a + waves_b:
        state = wave_state(wave, t)
        if state is None:
            continue
        a, b = state[2], state[3]
        ax.plot([a[0], b[0]], [a[1], b[1]], color=COLOR_WAVE, linewidth=1.8)

def draw_revealed_moving_grid(ax, t: float):
    origin = grid_origin(t)
    for tile, birth_time in zip(GLOBAL_TILES, tile_birth_times):
        if not math.isfinite(birth_time) or t < birth_time:
            continue
        alpha = smoothstep((t - birth_time) / TILE_REVEAL_TIME)
        world_points = tile["points"] + origin
        ax.plot(world_points[:, 0], world_points[:, 1], color=COLOR_TILE, linewidth=1.75, alpha=alpha)

def draw_current_intersections(ax, frame_index: int):
    points = intersection_points[frame_index]
    valid = ~np.isnan(points[:, 0])
    if not np.any(valid):
        return
    visible_points = points[valid]
    ax.scatter(visible_points[:, 0], visible_points[:, 1], s=8, color=COLOR_INTERSECTION, zorder=5)

def draw_frame(ax, frame_index: int):
    t = float(TIMES[frame_index])

    ax.clear()
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(YMIN, YMAX)

    draw_parent_waves(ax, t)
    draw_revealed_moving_grid(ax, t)
    draw_current_intersections(ax, frame_index)

    ax.text(
        XMIN + 0.03, YMAX - 0.04,
        "G/G — moving global Penrose grid\n"
        "larger reveal radius + staggered one-by-one reveal",
        va="top", fontsize=9.6, color=COLOR_NODE
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

animation = FuncAnimation(fig, update, frames=N_FRAMES, interval=1000/FPS, blit=False)
animation.save(GIF_PATH, writer=PillowWriter(fps=FPS))
plt.close(fig)

display(Markdown(
    "Сделал новую итерацию:\n\n"
    "1. **Чуть увеличил радиус проявления** вокруг каждого пересечения.\n"
    "2. **Плитки больше не проявляются всем пучком сразу** — теперь они включаются по одной, "
    "с коротким ритмическим интервалом."
))
display(IPImage(filename=str(PNG_PATH)))
display(IPImage(filename=str(GIF_PATH)))

print("Typical intersection step:", round(TYPICAL_INTERSECTION_STEP, 5))
print("Tile edge:", round(TILE_EDGE, 5))
print("Reveal radius:", round(REVEAL_RADIUS, 5))
print("Per-tile reveal delay:", round(REVEAL_DELAY_PER_TILE, 4))
print("Revealed tiles:", int(np.isfinite(tile_birth_times).sum()))
print("GIF MD5:", hashlib.md5(GIF_PATH.read_bytes()).hexdigest())
print("PNG:", PNG_PATH)
print("GIF:", GIF_PATH)
