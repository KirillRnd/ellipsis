#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Точная сборка принятого обзора Резонансов.

Принцип:
1. Первые 7 резонансов не перерисовываются и не переинтерпретируются.
   Вставляется целиком точный PNG, ранее созданный ellipse_resonances_all_v2.py.
2. Поздние 6 резонансов вставляются из точных принятых snapshot-файлов.
3. Никакая геометрия, цвет, стадийность или композиция отдельных решений
   в этом скрипте не пересчитывается.

Зависимость: pillow
Запуск:
    python compose_exact_accepted_overview.py
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import textwrap

ROOT = Path(__file__).resolve().parent
ASSET_DIR = ROOT / "accepted_assets"
OUTPUT = ROOT / "ellipse_resonances_exact_restore_v1.png"

ORIGINAL_OVERVIEW = ASSET_DIR / "ellipse_resonances_overview_v2.png"

PANELS = [
    (
        "Ж/З — кусты во всех движущихся пересечениях",
        ASSET_DIR / "yz_resonance_test_v3_colored_flipped_snapshot.png",
    ),
    (
        "Ж/Ж — последовательное заполнение сектора A→B",
        ASSET_DIR / "yy_caustic_resonance_A_to_B_snapshot.png",
    ),
    (
        "G/G — движущаяся плитка Пенроуза",
        ASSET_DIR / "gg_global_grid_reveal_v3_staggered_snapshot.png",
    ),
    (
        "G/Ж — равномерная ромбическая сетка",
        ASSET_DIR / "gold_yellow_rhomb_grid_v2_vertex_anchor_snapshot.png",
    ),
    (
        "К/К — Вороной с невидимым guard-ring",
        ASSET_DIR / "red_red_voronoi_circles_v4_guarded_snapshot.png",
    ),
    (
        "К/G — гирлянда инфляционных звёзд",
        ASSET_DIR / "kg_variant2_inflation_sun_tuned_v2_snapshot.png",
    ),
]

for path in [ORIGINAL_OVERVIEW, *(p for _, p in PANELS)]:
    if not path.exists():
        raise FileNotFoundError(path)

def contain(image: Image.Image, width: int, height: int) -> Image.Image:
    ratio = min(width / image.width, height / image.height)
    resized = image.resize(
        (
            max(1, round(image.width * ratio)),
            max(1, round(image.height * ratio)),
        ),
        Image.Resampling.LANCZOS,
    )
    panel = Image.new("RGB", (width, height), "#fffefb")
    panel.paste(
        resized,
        ((width - resized.width) // 2, (height - resized.height) // 2),
    )
    return panel

original = Image.open(ORIGINAL_OVERVIEW).convert("RGB")
canvas_width = original.width

margin_x = 28
gap_x = 20
panel_width = (canvas_width - 2 * margin_x - 2 * gap_x) // 3
panel_height = 450
header_height = 86
gap_y = 22
bottom_height = header_height + panel_height * 2 + gap_y + 30

canvas = Image.new(
    "RGB",
    (canvas_width, original.height + bottom_height),
    "#fffefb",
)
canvas.paste(original, (0, 0))

draw = ImageDraw.Draw(canvas)

font_candidates = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
]
font_path = next((p for p in font_candidates if Path(p).exists()), None)

if font_path:
    title_font = ImageFont.truetype(font_path, 31)
    panel_font = ImageFont.truetype(font_path, 20)
else:
    title_font = ImageFont.load_default()
    panel_font = ImageFont.load_default()

section_y = original.height + 18
section_title = "Точное дополнение: принятые поздние резонансы"
bbox = draw.textbbox((0, 0), section_title, font=title_font)
draw.text(
    ((canvas_width - (bbox[2] - bbox[0])) // 2, section_y),
    section_title,
    fill="#20242a",
    font=title_font,
)

start_y = original.height + header_height

for index, (label, snapshot_path) in enumerate(PANELS):
    row = index // 3
    col = index % 3
    x = margin_x + col * (panel_width + gap_x)
    y = start_y + row * (panel_height + gap_y)

    label_y = y
    for line in textwrap.wrap(label, width=34):
        draw.text((x + 6, label_y), line, fill="#20242a", font=panel_font)
        label_y += 24

    image_top = y + 54
    image_height = panel_height - 58
    snapshot = Image.open(snapshot_path).convert("RGB")
    panel = contain(snapshot, panel_width, image_height)
    canvas.paste(panel, (x, image_top))

canvas.save(OUTPUT)
print(f"Создано: {OUTPUT}")
