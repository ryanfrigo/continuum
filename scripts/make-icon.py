"""Draw the app icon: a 4x4 day grid lit along the colour ramp, one day missed.

Colours come from the same OKLCH stops as Shared/HabitPalette.swift, with the
darker ones lifted so the grid holds up on a home screen. Square (row, col) sits at
ramp position (row + col) / 6, like the About screen's mark.

    python3 scripts/make-icon.py
"""
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

# Keep in step with HabitPalette.stops: (position, lightness, chroma, hue)
STOPS = [(0.00, 0.56, 0.17, 32), (0.25, 0.80, 0.15, 72), (0.50, 0.74, 0.17, 150),
         (0.75, 0.66, 0.13, 215), (1.00, 0.58, 0.17, 262)]
FLOOR = 0.70         # darker in-app colours are lifted to this for the icon
MISSED = (1, 2)      # the dark square
BG, EMPTY = (14, 15, 18), (34, 36, 42)
SIZE, ORIGIN, CELL, PITCH, RADIUS = 1024, 195, 125, 170, 28
OUT = Path(__file__).resolve().parent.parent / "continuum/Assets.xcassets/AppIcon.appiconset"


def srgb(l, c, h):
    rad = math.radians(h)
    while True:
        a, b = c * math.cos(rad), c * math.sin(rad)
        l_ = (l + 0.3963377774 * a + 0.2158037573 * b) ** 3
        m_ = (l - 0.1055613458 * a - 0.0638541728 * b) ** 3
        s_ = (l - 0.0894841775 * a - 1.2914855480 * b) ** 3
        lin = [4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
               -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
               -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_]
        if c <= 0 or all(-1e-4 <= v <= 1.0001 for v in lin):
            return tuple(round(255 * (12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055))
                         for v in (max(0, min(1, x)) for x in lin))
        c -= 0.004


def ramp(p):
    i = next(k for k, s in enumerate(STOPS) if s[0] >= p)
    b, a = STOPS[i], STOPS[max(i - 1, 0)]
    t = (p - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0
    l, c, h = (a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return srgb(max(l, FLOOR), c, h)


def draw():
    img = Image.new("RGB", (SIZE, SIZE), BG)
    glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    squares = []
    for r in range(4):
        for c in range(4):
            x, y = ORIGIN + c * PITCH, ORIGIN + r * PITCH
            box = (x, y, x + CELL, y + CELL)
            colour = EMPTY if (r, c) == MISSED else ramp((r + c) / 6)
            squares.append((box, colour))
            if (r, c) != MISSED:
                ImageDraw.Draw(glow).rounded_rectangle(box, RADIUS, fill=colour)
    glow = glow.filter(ImageFilter.GaussianBlur(30)).point(lambda v: v * 0.3)
    img = ImageChops.add(img, glow)
    d = ImageDraw.Draw(img)
    for box, colour in squares:
        d.rounded_rectangle(box, RADIUS, fill=colour)
    return img


icon = draw()
icon.save(OUT / "1024x1024.png")
for name, px in [("20x20@2x", 40), ("20x20@3x", 60), ("29x29@2x", 58), ("29x29@3x", 87),
                 ("40x40@2x", 80), ("40x40@3x", 120), ("60x60@2x", 120), ("60x60@3x", 180)]:
    icon.resize((px, px), Image.LANCZOS).save(OUT / f"{name}.png")
print("wrote", OUT)
