#!/usr/bin/env python3
"""Render RepoAssets/muse-banner.png from real device screenshots.

Usage: python3 scripts/make_banner.py IOS_SCREENSHOT.png ANDROID_SCREENSHOT.png

Needs Pillow and macOS system fonts (SF Pro). The banner is drawn at 2x
(2200x800) for high-density screens; both phones keep a margin on every side
so nothing touches or crosses the banner edge.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 2200, 800
BG = (6, 19, 28, 255)
SF = "/System/Library/Fonts/SFNS.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"


def font(size, weight="Regular", path=SF):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return f


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def background():
    img = Image.new("RGBA", (W, H), BG)
    grid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(grid)
    for x in range(0, W, 88):
        g.line([(x, 0), (x, H)], fill=(255, 255, 255, 12), width=2)
    for y in range(0, H, 88):
        g.line([(0, y), (W, y)], fill=(255, 255, 255, 12), width=2)
    img = Image.alpha_composite(img, grid)
    # radial vignette
    vignette = Image.new("L", (W, H), 0)
    v = ImageDraw.Draw(vignette)
    steps = 60
    for i in range(steps):
        t = i / steps
        rx, ry = W * (0.95 - 0.6 * t), H * (1.5 - 0.9 * t)
        v.ellipse([W / 2 - rx, H / 2 - ry, W / 2 + rx, H / 2 + ry], fill=int(200 * t))
    vignette = vignette.filter(ImageFilter.GaussianBlur(60))
    black = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    img = Image.composite(img, black, vignette.point(lambda p: min(255, p + 55)))
    return img


def phone(screen_path, height, notch):
    """Frame a real screenshot; corner radius and cutout follow the device's own proportions."""
    screen = Image.open(screen_path).convert("RGBA")
    sw = int(height * screen.width / screen.height)
    screen = screen.resize((sw, height), Image.LANCZOS)
    # iPhone 17: 55 pt corners on a 402 pt wide screen; Pixel 7: ~50 px on 1080 px.
    radius = round(sw * (0.137 if notch == "island" else 0.05))
    bezel = 14
    frame = Image.new("RGBA", (sw + 2 * bezel, height + 2 * bezel), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], radius + bezel, fill=(16, 16, 22, 255),
                        outline=(255, 255, 255, 40), width=3)
    screen.putalpha(rounded_mask(screen.size, radius))
    frame.alpha_composite(screen, (bezel, bezel))
    cx = frame.width / 2
    if notch == "island":
        # Dynamic Island: 125x37 pt, 11 pt from the top of an 874 pt tall screen.
        w, h, top = sw * 125 / 402, height * 37 / 874, height * 11 / 874
        d.rounded_rectangle([cx - w / 2, bezel + top, cx + w / 2, bezel + top + h], h / 2, fill=(0, 0, 0, 255))
    elif notch == "punch":
        # Pixel 7 camera hole sits inside the status bar: centre ~2.4 % down, ~2.6 % of the width across.
        r, cy = sw * 0.013, bezel + height * 0.024
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 255))
    shadow = Image.new("RGBA", (frame.width + 120, frame.height + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([60, 70, 60 + frame.width, 70 + frame.height], radius + bezel,
                                             fill=(0, 0, 0, 200))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    shadow.alpha_composite(frame, (60, 60))
    return shadow


def pill(draw, x, y, text):
    f = font(26, "Semibold", MONO)
    w = draw.textlength(text, font=f) + 48
    draw.rounded_rectangle([x, y, x + w, y + 60], 30, fill=(255, 255, 255, 14), outline=(255, 255, 255, 30), width=2)
    draw.text((x + 24, y + 14), text, font=f, fill=(255, 255, 255, 215))
    return x + w


def main(ios_shot, android_shot):
    img = background()
    # Translucent text and pills go on their own layer: ImageDraw replaces
    # pixels instead of blending, so drawing them straight onto the canvas
    # would make every alpha fill opaque.
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    x0, y0 = 168, 196
    dot = Image.new("RGBA", (80, 80), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse([28, 28, 52, 52], fill=(74, 222, 128, 255))
    glow = dot.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(glow, (x0 - 28, y0 - 30))
    img.alpha_composite(dot, (x0 - 28, y0 - 30))
    d.text((x0 + 36, y0 - 16), "LOCAL · PRIVATE · SYSTEM-WIDE", font=font(30, "Semibold"),
           fill=(255, 255, 255, 175), spacing=4)
    d.text((x0 - 8, y0 + 40), "MuseDPI", font=font(168, "Regular"), fill=(223, 245, 241, 255))
    d.text((x0, y0 + 250), "DPI bypass for iOS and Android", font=font(46, "Regular"), fill=(255, 255, 255, 178))
    d.text((x0, y0 + 314), "on-device ByeDPI core — no remote VPN server", font=font(36, "Regular"),
           fill=(255, 255, 255, 112))
    nx = pill(d, x0, y0 + 392, "iOS 14+")
    pill(d, nx + 20, y0 + 392, "Android 5+")
    img.alpha_composite(layer)

    # Two phones, fully inside the canvas with >= 48 px (24 pt) of air at top and bottom.
    ph = H - 2 * 76 - 28
    ios = phone(ios_shot, ph, "island")
    android = phone(android_shot, ph, "punch")
    # phone() pads each frame with 60 px of shadow on every side.
    android_left = W - 150 - (android.width - 120)
    ios_left = android_left - 56 - (ios.width - 120)
    img.alpha_composite(ios, (ios_left - 60, 76 - 60))
    img.alpha_composite(android, (android_left - 60, 76 - 60 + 14))

    mask = rounded_mask((W, H), 48)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    out.save(os.path.join(ROOT, "RepoAssets/muse-banner.png"), optimize=True)
    print("RepoAssets/muse-banner.png", out.size)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
