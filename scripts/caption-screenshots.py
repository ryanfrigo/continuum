#!/usr/bin/env python3
"""Caption raw simulator captures into App Store screenshots.

    python3 scripts/caption-screenshots.py <raw_dir> <out_dir>

Raw captures are 1320x2868 PNGs from an iPhone 16 Pro Max simulator (see
continuumTests/SeedShots.swift for the data). Output is the same size, the
6.9" display App Store Connect takes, named NN_name.png so
scripts/asc-screenshots.mjs uploads them in order.
"""
import colorsys
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
FONT = "/System/Library/Fonts/SFNSMono.ttf"

# The app's colour for a habit kept up at 85% for 66 days (Shared/HabitPalette.swift
# at 0.85): the azure between its cyan and blue stops
ACCENT = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(187 / 360, 0.74, 0.92))
WHITE = (242, 244, 245)
GREY = (122, 130, 138)

# raw capture, output name, headline (white), headline (accent), small line,
# and optionally a region of the capture (px) to magnify over the phone
SHOTS = [
    ("home.png", "01_consistency.png", "Miss a day.", "Nothing resets.", "one number per habit", None),
    ("comeback.png", "02_never_miss_twice.png", "Missed yesterday?", "Don't miss twice.", None, None),
    ("stats.png", "03_week_by_week.png", "12 weeks.", "Watch it climb.", None, None),
    ("graduation.png", "04_66_days.png", "66 days.", "Most of them.", None, None),
    # The half-traced border is invisible at thumbnail size, so the held card is magnified
    ("hold_final.png", "05_hold.png", "Hold to mark", "the day.", "harder to do by accident", (20, 1030, 660, 1628)),
]


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def background():
    """Dark slate like the app, with a soft accent glow where the phone sits."""
    img = Image.new("RGB", (W, H), (9, 11, 13))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.05, H * 0.28, W * 0.95, H * 0.62), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    tint = Image.new("RGB", (W, H), ACCENT)
    return Image.composite(tint, img, glow.point(lambda v: int(v * 0.22)))


def phone(raw, width):
    """The capture with the screen's rounded corners, a thin bezel and a shadow."""
    scale = width / raw.width
    screen = raw.resize((width, round(raw.height * scale)), Image.LANCZOS)
    radius = round(165 * scale)            # 55pt display corners at 3x
    bezel = 12
    body = Image.new("RGBA", (screen.width + bezel * 2, screen.height + bezel * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, body.width - 1, body.height - 1), radius + bezel, fill=(26, 30, 34, 255))
    d.rounded_rectangle((1, 1, body.width - 2, body.height - 2), radius + bezel - 1, outline=(66, 74, 82, 255), width=2)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen.width - 1, screen.height - 1), radius, fill=255)
    body.paste(screen, (bezel, bezel), mask)
    return body


def callout(raw, box, width):
    """A region of the capture, magnified, with an accent edge so it reads as a zoom."""
    region = raw.crop(box)
    region = region.resize((width, round(region.height * width / region.width)), Image.LANCZOS)
    card = Image.new("RGBA", (region.width + 16, region.height + 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((0, 0, card.width - 1, card.height - 1), 56, fill=ACCENT + (255,))
    mask = Image.new("L", region.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, region.width - 1, region.height - 1), 48, fill=255)
    card.paste(region, (8, 8), mask)
    return card


def compose(raw_path, headline, accent, small, zoom=None):
    img = background().convert("RGBA")
    d = ImageDraw.Draw(img)

    big = font(108, "Bold")
    y = 170
    for text, colour in ((headline, WHITE), (accent, ACCENT)):
        x = (W - d.textlength(text, font=big)) / 2
        d.text((x, y), text, font=big, fill=colour)
        y += 132
    if small:
        f = font(40, "Medium")
        d.text(((W - d.textlength(small, font=f)) / 2, y + 16), small, font=f, fill=GREY)

    raw = Image.open(raw_path).convert("RGB")
    device = phone(raw, 1000)
    top = 640
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        ((W - device.width) / 2, top + 30, (W + device.width) / 2, top + device.height + 30), 160, fill=(0, 0, 0, 200))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(50)))
    img.alpha_composite(device, ((W - device.width) // 2, top))

    if zoom:
        card = callout(raw, zoom, 1040)
        y = 1560
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle(
            ((W - card.width) / 2, y, (W + card.width) / 2, y + card.height), 56, fill=ACCENT + (150,))
        img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(40)))
        img.alpha_composite(card, ((W - card.width) // 2, y))
    return img.convert("RGB")


def main(raw_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for raw, out, headline, accent, small, zoom in SHOTS:
        compose(os.path.join(raw_dir, raw), headline, accent, small, zoom).save(os.path.join(out_dir, out), optimize=True)
        print(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
