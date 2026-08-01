from pathlib import Path
import math
from dataclasses import dataclass

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib.patches import Circle
from IPython.display import display, Markdown, Image as IPImage

# =========================
# Output
# =========================
OUT = Path("/mnt/data/kg_variant2_inflation_sun_tuned_v2")
OUT.mkdir(parents=True, exist_ok=True)

GIF_PATH = OUT / "kg_variant2_inflation_sun_tuned_v2.gif"
PNG_PATH = OUT / "kg_variant2_inflation_sun_tuned_v2_snapshot.png"

# =========================
# Shared base geometry from the previous K/G prototypes
# =========================
PHI = (1 + 5 ** 0.5) / 2

R_RED = np.array([-0.58, -0.12], dtype=float)
R_GOLD = np.array([0.62, -0.34], dtype=float)

theta = math.radians(32)  # direction of the gold straight-wave cascade
L_DIR = np.array([math.cos(theta), math.sin(theta)], dtype=float)
L_DIR = L_DIR / np.linalg.norm(L_DIR)
N_DIR = np.array([-L_DIR[1], L_DIR[0]], dtype=float)

T_MAX = 3.10
FPS = 12
N_FRAMES = 78
TIMES = np.linspace(0.0, T_MAX, N_FRAMES)

XMIN, XMAX = -1.25, 1.25
YMIN, YMAX = -0.95, 1.15

# Base cascades
N_RED = 6
N_GOLD = 6
PERIOD_RED = 0.28
PERIOD_GOLD = 0.28
SPEED_RED = 0.56
SPEED_GOLD = 0.56
LIFE_RED = 2.85
LIFE_GOLD = 2.85

BASE_COLOR_RED = "#c34a4a"
BASE_COLOR_GOLD = "#d8b24a"
RESONANCE_GOLD = "#f0d56a"
NODE_COLOR = "#181818"

# =========================
# Tuned star parameters
# =========================
# Keep the same inflation mechanic (r, φr, φ²r),
# only adjust the primitive:
# - slightly smaller outer radius
# - larger inner ratio
# - phase rotated so the garland direction aligns with a notch, not a spike
BASE_OUTER_RADIUS = 0.045          # ~10% smaller than previous 0.05
INNER_RATIO = 0.58                 # more compact / less spiky
STAR_PHASE = theta - math.pi / 5   # notch aligned with garland direction
STAGE_PERIOD = 0.30                # same 3-stage growth cadence
MAX_STAGE = 3

# =========================
# Waves
# =========================
@dataclass(frozen=True)
class CircleWave:
    index: int
    launch: float

@dataclass(frozen=True)
class LineWave:
    index: int
    launch: float

RED_WAVES = [CircleWave(i, i * PERIOD_RED) for i in range(N_RED)]
GOLD_WAVES = [LineWave(i, i * PERIOD_GOLD) for i in range(N_GOLD)]

def active_red_radius(w: CircleWave, t: float):
    age = t - w.launch
    if age < 0 or age > LIFE_RED:
        return None
    return SPEED_RED * age

def active_gold_offset(w: LineWave, t: float):
    age = t - w.launch
    if age < 0 or age > LIFE_GOLD:
        return None
    return np.dot(N_DIR, R_GOLD) + SPEED_GOLD * age

def line_circle_intersections(center, radius, c):
    """
    Gold-wave line family: N_DIR · x = c
    Red wave: |x - center| = radius
    """
    d_signed = np.dot(N_DIR, center) - c
    d = abs(d_signed)
    if d > radius:
        return []
    foot = center - d_signed * N_DIR
    h = max(0.0, radius**2 - d**2) ** 0.5
    if h < 1e-10:
        return [foot]
    return [foot + h * L_DIR, foot - h * L_DIR]

def all_intersections(t):
    pts = []
    active_circles = []
    active_lines = []

    for cw in RED_WAVES:
        r = active_red_radius(cw, t)
        if r is not None:
            active_circles.append((cw, r))

    for lw in GOLD_WAVES:
        c = active_gold_offset(lw, t)
        if c is not None:
            active_lines.append((lw, c))

    for cw, r in active_circles:
        for lw, c in active_lines:
            hits = line_circle_intersections(R_RED, r, c)
            if not hits:
                continue
            contact_age = max(0.0, t - max(cw.launch, lw.launch))
            for side, p in enumerate(hits):
                pts.append(
                    {
                        "circle_index": cw.index,
                        "line_index": lw.index,
                        "point": p,
                        "side": side,
                        "contact_age": contact_age,
                    }
                )
    return active_circles, active_lines, pts

def draw_base(ax, active_circles, active_lines):
    ax.plot(R_RED[0], R_RED[1], "o", color=NODE_COLOR, ms=5)
    ax.plot(R_GOLD[0], R_GOLD[1], "o", color=NODE_COLOR, ms=5)

    for _, r in active_circles:
        ax.add_patch(Circle(R_RED, r, fill=False, ec=BASE_COLOR_RED, lw=1.55, alpha=0.75))

    for _, c in active_lines:
        p0 = N_DIR * c
        a = p0 - 5 * L_DIR
        b = p0 + 5 * L_DIR
        ax.plot([a[0], b[0]], [a[1], b[1]], color=BASE_COLOR_GOLD, lw=1.35, alpha=0.72)

def star_polygon(center, radius, orientation, inner_ratio):
    pts = []
    for k in range(10):
        ang = orientation + k * math.pi / 5
        rad = radius if k % 2 == 0 else radius * inner_ratio
        pts.append(center + rad * np.array([math.cos(ang), math.sin(ang)]))
    pts.append(pts[0])
    return np.array(pts)

def draw_frame(ax, t):
    active_circles, active_lines, pts = all_intersections(t)

    ax.clear()
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(YMIN, YMAX)
    ax.set_aspect("equal")
    ax.axis("off")

    draw_base(ax, active_circles, active_lines)

    for item in pts:
        p = item["point"]
        stage = min(MAX_STAGE, int(item["contact_age"] / STAGE_PERIOD) + 1)

        for s in range(stage):
            rr = BASE_OUTER_RADIUS * (PHI ** s)
            poly = star_polygon(
                p,
                rr,
                orientation=STAR_PHASE,
                inner_ratio=INNER_RATIO,
            )
            alpha = 0.97 - 0.16 * s
            lw = 1.15 if s == 0 else 1.05
            ax.plot(poly[:, 0], poly[:, 1], color=RESONANCE_GOLD, lw=lw, alpha=alpha)

        ax.plot(p[0], p[1], "o", color=NODE_COLOR, ms=1.5)

    ax.text(
        XMIN + 0.03,
        YMAX - 0.04,
        "К/G — инфляционная звезда, tuned v2\n"
        "меньший внешний радиус, более компактная звезда, фаза на впадину",
        va="top",
        fontsize=9.5,
        color=NODE_COLOR,
    )

# Snapshot
snapshot_index = 54
fig, ax = plt.subplots(figsize=(7.0, 6.0))
draw_frame(ax, TIMES[snapshot_index])
fig.tight_layout()
fig.savefig(PNG_PATH, dpi=150, bbox_inches="tight")
plt.close(fig)

# GIF
fig, ax = plt.subplots(figsize=(7.0, 6.0))
def update(i):
    draw_frame(ax, TIMES[i])
    return []

anim = FuncAnimation(fig, update, frames=len(TIMES), interval=1000 / FPS, blit=False)
anim.save(GIF_PATH, writer=PillowWriter(fps=FPS))
plt.close(fig)

display(Markdown("Сделал новую гифку **К/G инфляционной звезды** с подстроенными параметрами примитива."))
display(IPImage(filename=str(PNG_PATH)))
display(IPImage(filename=str(GIF_PATH)))

print("PNG:", PNG_PATH)
print("GIF:", GIF_PATH)
