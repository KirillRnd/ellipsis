import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from IPython.display import display, Image as IPImage, Markdown

OUT_DIR = Path("/mnt/data")
GIF_PATH = OUT_DIR / "yy_caustic_resonance_A_to_B.gif"
PNG_PATH = OUT_DIR / "yy_caustic_resonance_A_to_B_snapshot.png"

# ------------------------------------------------------------
# Ж/Ж — альтернативный вариант
#
# Отличие от принятого предыдущего прототипа:
# резонансные волны появляются НЕ от центра к краям,
# а ПОСЛЕДОВАТЕЛЬНО от семейства A к семейству B.
#
# База сохранена:
# - веер рождается в момент первого реального пересечения;
# - веер живёт, пока существует пересечение;
# - все резонансные прямые проходят через точку пересечения;
# - углы равномерно заполняют сектор между A и B.
# ------------------------------------------------------------

FPS = 12
N_FRAMES = 140
T_MAX = 2.75

COLOR_WAVE = "#d4c95f"        # жёлтые родительские волны
COLOR_RESONANCE = "#fff06a"   # яркие жёлтые резонансные волны
COLOR_NODE = "#202020"

LINEWIDTH_WAVE = 1.8
LINEWIDTH_RESONANCE = 2.4

# Резонаторы
R1 = np.array([-0.62, -0.18], dtype=float)  # A
R2 = np.array([ 0.46, -0.10], dtype=float)  # B

# Направления движения каскадов
n1 = np.array([math.cos(math.radians(32)),  math.sin(math.radians(32))], dtype=float)
n2 = np.array([math.cos(math.radians(118)), math.sin(math.radians(118))], dtype=float)

# Направления самих волн
d1 = np.array([-n1[1], n1[0]], dtype=float)
d2 = np.array([-n2[1], n2[0]], dtype=float)

def angle_of(v):
    return math.atan2(v[1], v[0])

theta1 = angle_of(d1)
theta2 = angle_of(d2)

# Параметры каскадов
N_WAVES = 8
WAVE_PERIOD = 0.22
WAVE_SPEED = 0.72
BASE_HALF_LEN = 0.10
HALF_LEN_GROWTH = 0.48
WAVE_LIFETIME = 2.15

# Параметры резонансного веера
N_RESONANCE_LINES = 13
SWEEP_DELAY = 0.035        # задержка между соседними резонансными волнами A -> B
FAN_FADE_TIME = 0.95
FAN_PLATEAU_TIME = 0.22
CENTER_LENGTH_BOOST = 1.18

@dataclass
class Wave:
    family_id: int
    index: int
    launch: float
    origin: np.ndarray
    normal: np.ndarray
    tangent: np.ndarray

waves_1 = [Wave(1, k, k * WAVE_PERIOD, R1, n1, d1) for k in range(N_WAVES)]
waves_2 = [Wave(2, k, k * WAVE_PERIOD, R2, n2, d2) for k in range(N_WAVES)]
pairs = list(zip(waves_1, waves_2))  # только k <-> k

def smoothstep(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)

def wave_state(wave: Wave, t: float):
    age = t - wave.launch
    if age < 0.0 or age > WAVE_LIFETIME:
        return None
    center = wave.origin + WAVE_SPEED * age * wave.normal
    half_len = BASE_HALF_LEN + HALF_LEN_GROWTH * age
    a = center - half_len * wave.tangent
    b = center + half_len * wave.tangent
    return {
        "center": center,
        "half_len": half_len,
        "a": a,
        "b": b,
    }

def segment_intersection(p1, p2, q1, q2):
    r = p2 - p1
    s = q2 - q1
    denom = r[0] * s[1] - r[1] * s[0]
    if abs(denom) < 1e-9:
        return None
    qp = q1 - p1
    t = (qp[0] * s[1] - qp[1] * s[0]) / denom
    u = (qp[0] * r[1] - qp[1] * r[0]) / denom
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return p1 + t * r
    return None

def interp_angle(theta_a, theta_b, s):
    diff = (theta_b - theta_a + math.pi) % (2 * math.pi) - math.pi
    return theta_a + s * diff

# Предрасчёт реальных точек пересечения и моментов рождения резонанса
times = np.linspace(0.0, T_MAX, N_FRAMES)
pair_frame_points = {pair_idx: [None] * N_FRAMES for pair_idx in range(len(pairs))}
pair_frame_births = {pair_idx: [None] * N_FRAMES for pair_idx in range(len(pairs))}

for pair_idx, (wa, wb) in enumerate(pairs):
    active = False
    current_birth = None

    for fi, t in enumerate(times):
        sa = wave_state(wa, t)
        sb = wave_state(wb, t)

        p = None
        if sa is not None and sb is not None:
            p = segment_intersection(sa["a"], sa["b"], sb["a"], sb["b"])

        pair_frame_points[pair_idx][fi] = p

        if p is not None:
            if not active:
                active = True
                current_birth = t
            pair_frame_births[pair_idx][fi] = current_birth
        else:
            active = False
            current_birth = None
            pair_frame_births[pair_idx][fi] = None

def draw_resonators(ax):
    ax.plot(R1[0], R1[1], "o", color=COLOR_NODE, markersize=5)
    ax.plot(R2[0], R2[1], "o", color=COLOR_NODE, markersize=5)

def draw_parent_wave(ax, wave: Wave, t: float):
    st = wave_state(wave, t)
    if st is None:
        return
    a, b = st["a"], st["b"]
    ax.plot([a[0], b[0]], [a[1], b[1]], color=COLOR_WAVE, linewidth=LINEWIDTH_WAVE)

def draw_resonance_fan(ax, pair_idx: int, t: float, frame_index: int):
    p = pair_frame_points[pair_idx][frame_index]
    birth = pair_frame_births[pair_idx][frame_index]
    if p is None or birth is None:
        return

    wa, wb = pairs[pair_idx]
    sa = wave_state(wa, t)
    sb = wave_state(wb, t)
    if sa is None or sb is None:
        return

    ax.plot(p[0], p[1], "o", color=COLOR_NODE, markersize=3)

    resonance_age = t - birth
    if resonance_age < 0:
        return

    appear = smoothstep(min(1.0, resonance_age / FAN_PLATEAU_TIME))
    fade = 1.0
    if resonance_age > FAN_PLATEAU_TIME:
        fade = 1.0 - smoothstep(min(1.0, (resonance_age - FAN_PLATEAU_TIME) / FAN_FADE_TIME))
    global_amp = appear * fade
    if global_amp <= 0.0:
        return

    parent_base_half = 0.88 * min(sa["half_len"], sb["half_len"])

    for i in range(N_RESONANCE_LINES):
        s = i / (N_RESONANCE_LINES - 1)

        # Главное отличие: последовательное рождение от A к B.
        local_age = resonance_age - i * SWEEP_DELAY
        if local_age <= 0:
            continue

        local_amp = smoothstep(min(1.0, local_age / 0.10)) * fade
        if local_amp <= 0:
            continue

        theta = interp_angle(theta1, theta2, s)
        direction = np.array([math.cos(theta), math.sin(theta)], dtype=float)

        center_peak = 1.0 + (CENTER_LENGTH_BOOST - 1.0) * (1.0 - abs(2.0 * s - 1.0))
        half_len = parent_base_half * center_peak * local_amp

        A = p - half_len * direction
        B = p + half_len * direction
        ax.plot([A[0], B[0]], [A[1], B[1]], color=COLOR_RESONANCE, linewidth=LINEWIDTH_RESONANCE)

def draw_frame(ax, t: float, frame_index: int):
    ax.clear()
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_xlim(-1.25, 1.15)
    ax.set_ylim(-0.95, 1.10)

    draw_resonators(ax)

    for w in waves_1:
        draw_parent_wave(ax, w, t)
    for w in waves_2:
        draw_parent_wave(ax, w, t)

    for pair_idx in range(len(pairs)):
        draw_resonance_fan(ax, pair_idx, t, frame_index)

    ax.text(
        -1.20,
        1.05,
        "Ж/Ж — альтернативный каустический резонанс\n"
        "резонансные волны рождаются последовательно от A к B",
        va="top",
        fontsize=10,
        color=COLOR_NODE,
    )

snapshot_frame = int(0.57 * (N_FRAMES - 1))
snapshot_time = times[snapshot_frame]

fig, ax = plt.subplots(figsize=(7.2, 6.6))
draw_frame(ax, snapshot_time, snapshot_frame)
fig.tight_layout()
fig.savefig(PNG_PATH, dpi=150, bbox_inches="tight")
plt.close(fig)

fig, ax = plt.subplots(figsize=(7.2, 6.6))
def update(frame_index: int):
    draw_frame(ax, times[frame_index], frame_index)
    return []

ani = FuncAnimation(fig, update, frames=N_FRAMES, interval=1000 / FPS, blit=False)
ani.save(GIF_PATH, writer=PillowWriter(fps=FPS))
plt.close(fig)

display(Markdown(
    "Сделал **альтернативный вариант Ж/Ж**.\n\n"
    "Здесь резонансные волны рождаются **последовательно от A к B**, "
    "вместо схемы «из центра к краям». Остальная база сохранена: веер привязан к "
    "**реальной точке пересечения**, движется вместе с ней и равномерно заполняет сектор."
))
display(IPImage(filename=str(PNG_PATH)))
display(IPImage(filename=str(GIF_PATH)))

print("PNG:", PNG_PATH)
print("GIF:", GIF_PATH)
