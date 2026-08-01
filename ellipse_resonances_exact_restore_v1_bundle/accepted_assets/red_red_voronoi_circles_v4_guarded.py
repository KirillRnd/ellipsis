from pathlib import Path
import math
from dataclasses import dataclass
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib.patches import Circle
from scipy.spatial import Delaunay

OUT = Path(__file__).resolve().parent
GIF_PATH = OUT / "red_red_voronoi_circles_v4_guarded.gif"
PNG_PATH = OUT / "red_red_voronoi_circles_v4_guarded_snapshot.png"

FPS = 12
N_FRAMES = 90
T_MAX = 3.15
TIMES = np.linspace(0.0, T_MAX, N_FRAMES)

XMIN, XMAX = -1.18, 1.18
YMIN, YMAX = -0.82, 1.12

COLOR_WAVE = "#cf4f4f"
COLOR_VORONOI = "#ee6767"
COLOR_POINT = "#7a1010"
COLOR_NODE = "#202020"

R_A = np.array([-0.64, -0.34], dtype=float)
R_B = np.array([0.64, -0.34], dtype=float)
BASELINE_Y = float(R_A[1])

N_WAVES = 7
WAVE_PERIOD = 0.235
WAVE_SPEED = 0.6
WAVE_LIFETIME = 3.05

EPS = 1e-09
POINT_MERGE_EPS = 1e-05
GUARD_DISTANCE_FACTOR = 1.45
GUARD_EDGE_STEP_FACTOR = 0.95
MAX_SEGMENT_LENGTH_FACTOR = 2.9
MIDLINE_BAND = 0.045
RESONATOR_CLEARANCE = 0.14

@dataclass(frozen=True)
class CircleWave:
    family: str
    index: int
    launch: float
    center: np.ndarray

def wave_radius(wave, t):
    age = t - wave.launch
    if age < 0.0 or age > WAVE_LIFETIME:
        return None
    return WAVE_SPEED * age

waves_a = [CircleWave("A", i, i * WAVE_PERIOD, R_A) for i in range(N_WAVES)]
waves_b = [CircleWave("B", i, i * WAVE_PERIOD, R_B) for i in range(N_WAVES)]

def circle_circle_intersections(c0, r0, c1, r1):
    delta = c1 - c0
    d = float(np.linalg.norm(delta))
    if d < EPS or d > r0 + r1 + EPS or d < abs(r0 - r1) - EPS:
        return []
    a = (r0 * r0 - r1 * r1 + d * d) / (2.0 * d)
    h2 = r0 * r0 - a * a
    if h2 < -EPS:
        return []
    h = math.sqrt(max(0.0, h2))
    e = delta / d
    midpoint = c0 + a * e
    perp = np.array([-e[1], e[0]], dtype=float)
    if h <= 1e-8:
        return [midpoint]
    return [midpoint + h * perp, midpoint - h * perp]

def active_radii(t):
    ra = [r for w in waves_a if (r := wave_radius(w, t)) is not None]
    rb = [r for w in waves_b if (r := wave_radius(w, t)) is not None]
    return ra, rb

def active_sites(t):
    ra, rb = active_radii(t)
    points = []
    for radius_a in ra:
        for radius_b in rb:
            points.extend(circle_circle_intersections(R_A, radius_a, R_B, radius_b))
    if not points:
        return np.empty((0, 2), dtype=float)
    points = sorted(points, key=lambda p: (p[0], p[1]))
    unique = []
    for point in points:
        if not unique or all(np.linalg.norm(point - other) >= POINT_MERGE_EPS for other in unique):
            unique.append(point)
    return np.array(unique, dtype=float)

def split_clusters(points):
    if len(points) == 0:
        return []
    upper = points[points[:, 1] >= BASELINE_Y]
    lower = points[points[:, 1] < BASELINE_Y]
    clusters = []
    if len(upper):
        clusters.append(upper)
    if len(lower):
        clusters.append(lower)
    return clusters

def polygon_area(poly):
    x = poly[:, 0]
    y = poly[:, 1]
    return 0.5 * float(np.sum(x * np.roll(y, -1) - y * np.roll(x, -1)))

def convex_hull(points):
    pts = sorted(set(map(tuple, np.asarray(points, dtype=float))))
    if len(pts) <= 1:
        return np.asarray(pts, dtype=float)
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower = []
    for point in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 1e-12:
            lower.pop()
        lower.append(point)
    upper = []
    for point in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 1e-12:
            upper.pop()
        upper.append(point)
    hull = np.asarray(lower[:-1] + upper[:-1], dtype=float)
    if len(hull) >= 3 and polygon_area(hull) < 0:
        hull = hull[::-1]
    return hull

def median_nearest_neighbor_distance(points):
    if len(points) < 2:
        return 0.0
    delta = points[:, None, :] - points[None, :, :]
    dist = np.linalg.norm(delta, axis=2)
    dist[dist < 1e-10] = np.inf
    nearest = np.min(dist, axis=1)
    finite = nearest[np.isfinite(nearest)]
    return float(np.median(finite)) if len(finite) else 0.0

def normalized(v):
    n = float(np.linalg.norm(v))
    return v / n if n > 1e-12 else np.zeros_like(v)

def outward_vertex_bisector(hull, i):
    n = len(hull)
    prev_pt = hull[(i - 1) % n]
    curr_pt = hull[i]
    next_pt = hull[(i + 1) % n]
    e_prev = normalized(curr_pt - prev_pt)
    e_next = normalized(next_pt - curr_pt)
    n_prev = np.array([e_prev[1], -e_prev[0]], dtype=float)
    n_next = np.array([e_next[1], -e_next[0]], dtype=float)
    bis = normalized(n_prev + n_next)
    if np.linalg.norm(bis) < 1e-12:
        centroid = np.mean(hull, axis=0)
        bis = normalized(curr_pt - centroid)
    return bis

def build_guard_ring(cluster):
    if len(cluster) == 0:
        return np.empty((0, 2), dtype=float), 0.0
    s = median_nearest_neighbor_distance(cluster)
    if s <= 1e-9:
        s = 0.12
    hull = convex_hull(cluster)
    if len(hull) == 1:
        center = hull[0]
        d = GUARD_DISTANCE_FACTOR * s
        angles = np.linspace(0, 2 * np.pi, 6, endpoint=False)
        guards = center + d * np.column_stack([np.cos(angles), np.sin(angles)])
        return guards, s
    d = GUARD_DISTANCE_FACTOR * s
    step = GUARD_EDGE_STEP_FACTOR * s
    guards = []
    for i in range(len(hull)):
        bis = outward_vertex_bisector(hull, i)
        guards.append(hull[i] + d * bis)
    for i in range(len(hull)):
        a = hull[i]
        b = hull[(i + 1) % len(hull)]
        edge = b - a
        length = float(np.linalg.norm(edge))
        if length < 1e-12:
            continue
        outward = normalized(np.array([edge[1], -edge[0]], dtype=float))
        n_inner = max(0, int(math.floor(length / step)) - 1)
        for k in range(n_inner):
            t = (k + 1) / (n_inner + 1)
            p = (1 - t) * a + t * b
            guards.append(p + d * outward)
    if len(guards) == 0:
        return np.empty((0, 2), dtype=float), s
    unique = []
    for g in guards:
        if not unique or all(np.linalg.norm(g - q) > 1e-6 for q in unique):
            unique.append(g)
    return np.array(unique, dtype=float), s

def circumcenter(a, b, c):
    matrix = 2.0 * np.vstack([b - a, c - a])
    if abs(np.linalg.det(matrix)) < 1e-10:
        return None
    rhs = np.array([np.dot(b, b) - np.dot(a, a), np.dot(c, c) - np.dot(a, a)], dtype=float)
    return np.linalg.solve(matrix, rhs)

def point_segment_distance(point, a, b):
    ab = b - a
    denom = float(np.dot(ab, ab))
    if denom < 1e-12:
        return float(np.linalg.norm(point - a))
    t = np.clip(np.dot(point - a, ab) / denom, 0.0, 1.0)
    projection = a + t * ab
    return float(np.linalg.norm(point - projection))

def is_horizontal_midline_segment(a, b):
    direction = b - a
    length = float(np.linalg.norm(direction))
    if length < 1e-12:
        return False
    horizontalness = abs(direction[1]) / length
    midpoint_y = 0.5 * (a[1] + b[1])
    return horizontalness < 0.22 and abs(midpoint_y - BASELINE_Y) < MIDLINE_BAND

def guarded_voronoi_segments_for_cluster(cluster):
    if len(cluster) < 2:
        return [], np.empty((0, 2), dtype=float)
    guards, local_step = build_guard_ring(cluster)
    if len(guards) == 0:
        return [], np.empty((0, 2), dtype=float)
    all_points = np.vstack([cluster, guards])
    n_real = len(cluster)
    tri = Delaunay(all_points, qhull_options="QJ")
    simplices = tri.simplices
    centers = []
    for simplex in simplices:
        centers.append(circumcenter(all_points[simplex[0]], all_points[simplex[1]], all_points[simplex[2]]))
    edge_to_triangles = {}
    for tri_index, simplex in enumerate(simplices):
        for edge in (tuple(sorted((simplex[0], simplex[1]))), tuple(sorted((simplex[1], simplex[2]))), tuple(sorted((simplex[2], simplex[0])))):
            edge_to_triangles.setdefault(edge, []).append(tri_index)
    max_length = MAX_SEGMENT_LENGTH_FACTOR * local_step if local_step > 0 else np.inf
    segments = []
    for edge, attached in edge_to_triangles.items():
        if len(attached) != 2:
            continue
        i, j = edge
        i_real = i < n_real
        j_real = j < n_real
        if not (i_real or j_real):
            continue
        c0 = centers[attached[0]]
        c1 = centers[attached[1]]
        if c0 is None or c1 is None:
            continue
        length = float(np.linalg.norm(c1 - c0))
        if length > max_length:
            continue
        if is_horizontal_midline_segment(c0, c1):
            continue
        if point_segment_distance(R_A, c0, c1) < RESONATOR_CLEARANCE:
            continue
        if point_segment_distance(R_B, c0, c1) < RESONATOR_CLEARANCE:
            continue
        segments.append((c0, c1))
    return segments, guards

FRAME_DATA = []
for t in TIMES:
    radii_a, radii_b = active_radii(float(t))
    sites = active_sites(float(t))
    clusters = split_clusters(sites)
    segments = []
    for cluster in clusters:
        cluster_segments, _ = guarded_voronoi_segments_for_cluster(cluster)
        segments.extend(cluster_segments)
    FRAME_DATA.append((radii_a, radii_b, sites, segments))

def draw_frame(ax, frame_index):
    radii_a, radii_b, sites, segments = FRAME_DATA[frame_index]
    ax.clear()
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(YMIN, YMAX)
    ax.plot(R_A[0], R_A[1], "o", color=COLOR_NODE, markersize=5)
    ax.plot(R_B[0], R_B[1], "o", color=COLOR_NODE, markersize=5)
    for radius in radii_a:
        ax.add_patch(Circle(R_A, radius, fill=False, edgecolor=COLOR_WAVE, linewidth=1.55, alpha=0.72))
    for radius in radii_b:
        ax.add_patch(Circle(R_B, radius, fill=False, edgecolor=COLOR_WAVE, linewidth=1.55, alpha=0.72))
    for p0, p1 in segments:
        ax.plot([p0[0], p1[0]], [p0[1], p1[1]], color=COLOR_VORONOI, linewidth=1.38)
    if len(sites):
        ax.scatter(sites[:, 0], sites[:, 1], s=9, color=COLOR_POINT, zorder=5)
    ax.text(XMIN + 0.03, YMAX - 0.04,
            "К/К — реальные точки + невидимое кольцо ограничителей\n"
            "крайние точки снова участвуют, но без внешних лучей и крупных доменов",
            va="top", fontsize=9.1, color=COLOR_NODE)

snapshot_frame = int(0.72 * (N_FRAMES - 1))
fig, ax = plt.subplots(figsize=(7.2, 6.6))
draw_frame(ax, snapshot_frame)
fig.tight_layout()
fig.savefig(PNG_PATH, dpi=150, bbox_inches="tight")
plt.close(fig)

fig, ax = plt.subplots(figsize=(7.2, 6.6))
def update(frame_index):
    draw_frame(ax, frame_index)
    return []
animation = FuncAnimation(fig, update, frames=N_FRAMES, interval=1000 / FPS, blit=False)
animation.save(GIF_PATH, writer=PillowWriter(fps=FPS))
plt.close(fig)

print("PNG:", PNG_PATH)
print("GIF:", GIF_PATH)
