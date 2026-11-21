#!/usr/bin/env python3
"""Генерирует иконку приложения 1024x1024 без внешних ассетов.

Запуск: python3 scripts/make-icon.py
Требуется Pillow. Результат: Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4
S = SIZE * SCALE

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

BACKGROUND_TOP = (18, 22, 34)
BACKGROUND_BOTTOM = (32, 38, 59)
KEY = (43, 50, 71)
KEY_EDGE = (63, 73, 102)
ACCENT = (255, 107, 87)
ACCENT_EDGE = (255, 146, 128)


def gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    image = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return image


def rounded(size, radius, color, edge=None, edge_width=0):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=color, outline=edge, width=edge_width)
    return image


def main() -> None:
    canvas = gradient(S, BACKGROUND_TOP, BACKGROUND_BOTTOM).convert("RGBA")

    cols, rows = 3, 2
    key_size = int(196 * SCALE)
    gap = int(38 * SCALE)
    radius = int(46 * SCALE)
    edge = max(int(2 * SCALE), 1)

    grid_w = cols * key_size + (cols - 1) * gap
    grid_h = rows * key_size + (rows - 1) * gap
    x0 = (S - grid_w) // 2
    y0 = (S - grid_h) // 2

    accent_index = (rows - 1) * cols + 1

    # Мягкое свечение под акцентной клавишей.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    ax = x0 + (accent_index % cols) * (key_size + gap)
    ay = y0 + (accent_index // cols) * (key_size + gap)
    pad = int(26 * SCALE)
    glow_draw.rounded_rectangle(
        [ax - pad, ay - pad, ax + key_size + pad, ay + key_size + pad],
        radius=radius + pad,
        fill=ACCENT + (110,),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(int(30 * SCALE)))
    canvas.alpha_composite(glow)

    for row in range(rows):
        for col in range(cols):
            index = row * cols + col
            x = x0 + col * (key_size + gap)
            y = y0 + row * (key_size + gap)
            if index == accent_index:
                layer = rounded(key_size, radius, ACCENT + (255,), ACCENT_EDGE + (255,), edge)
            else:
                layer = rounded(key_size, radius, KEY + (255,), KEY_EDGE + (255,), edge)
            canvas.alpha_composite(layer, (x, y))

    icon = canvas.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, "PNG")
    print(f"Готово: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()