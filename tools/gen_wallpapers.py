#!/usr/bin/env python3
"""Generate the starter wallpapers in Wallpapers/ (original work, released under CC0 1.0).

Pixel-art night cityscapes. Each picture is drawn on a 320x200 grid with a small palette (sky bands with
ordered dithering, stars, an optional moon, three layers of buildings with lit windows, an optional
reflecting harbour) and then enlarged 8x with nearest-neighbour scaling to 2560x1600, so every pixel stays
a crisp square. Fixed seeds: re-running the script reproduces the committed files.

    python3 tools/gen_wallpapers.py [--out DIR] [--only NAME]

Needs numpy and Pillow.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

PW, PH, SCALE = 320, 200, 8

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) + 0.5) / 16


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def sky(top, horizon, horizon_y, bands=9):
    """Vertical gradient quantised to `bands` colours, with ordered dithering between neighbouring bands."""
    img = np.zeros((PH, PW, 3), np.uint8)
    for y in range(PH):
        t = min(1.0, y / (PH * horizon_y)) ** 1.5 * (bands - 1)
        lo, frac = int(t), t - int(t)
        for x in range(PW):
            band = lo + (1 if frac > BAYER4[y % 4, x % 4] else 0)
            img[y, x] = mix(top, horizon, min(band, bands - 1) / (bands - 1))
    return Image.fromarray(img)


def draw_stars(d, rng, horizon_y, n=70):
    for _ in range(n):
        x, y = int(rng.integers(0, PW)), int(rng.random() ** 1.6 * PH * horizon_y * 0.8)
        v = int(rng.integers(150, 255))
        d.point((x, y), fill=(v, v, min(255, v + 10)))
        if rng.random() < 0.12:  # a few twinkling crosses
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                d.point((x + dx, y + dy), fill=(110, 110, 130))


def draw_moon(d, cx, cy, r, tint):
    d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=mix((0, 0, 0), tint, 0.18))
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=mix((0, 0, 0), tint, 0.35))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(238, 238, 226))
    d.ellipse([cx - r + 2, cy - r + 3, cx - r + 5, cy - r + 6], fill=(214, 214, 204))  # crater
    d.ellipse([cx + 1, cy + 1, cx + 3, cy + 3], fill=(220, 220, 210))


def draw_layer(d, rng, base_y, body, trim, win_cols, lit, widths, heights):
    x = -int(rng.integers(0, 8))
    while x < PW:
        bw, bh = int(rng.integers(*widths)), int(rng.integers(*heights))
        top = base_y - bh
        d.rectangle([x, top, x + bw - 1, PH], fill=body)
        d.line([x, top, x + bw - 1, top], fill=trim)  # lit roof edge
        kind = rng.random()
        if kind < 0.2:  # stepped crown
            sw = max(4, int(bw * rng.uniform(0.4, 0.7)))
            sh = int(rng.integers(3, 11))
            sx = x + (bw - sw) // 2
            d.rectangle([sx, top - sh, sx + sw - 1, top], fill=body)
            d.line([sx, top - sh, sx + sw - 1, top - sh], fill=trim)
        elif kind < 0.32:  # antenna with a red lamp
            ax = x + bw // 2
            h = int(rng.integers(5, 16))
            d.line([ax, top - h, ax, top], fill=body)
            if rng.random() < 0.7:
                d.point((ax, top - h - 1), fill=(255, 70, 70))
        for wy in range(top + 3, min(PH, base_y + 40), 4):
            row_on = rng.random() < 0.88
            for wx in range(x + 2, x + bw - 2, 3):
                if row_on and rng.random() < lit:
                    d.point((wx, wy), fill=win_cols[int(rng.integers(0, len(win_cols)))])
                    if rng.random() < 0.5:
                        d.point((wx, wy + 1), fill=win_cols[int(rng.integers(0, len(win_cols)))])
        x += bw + int(rng.integers(0, 3))


def city(seed, top, horizon, haze, win_cols, moon=None, water=False, horizon_y=0.8, lit=0.55, day=False, height_scale=1.0, layered=False):
    """layered=True returns (sky, buildings): the sky with its stars and moon, and the skyline and ground on a
    transparent layer of their own, so something can be put between them (the README logo does)."""
    rng = np.random.default_rng(seed)
    img = sky(top, horizon, horizon_y)
    d = ImageDraw.Draw(img)
    if not day:
        draw_stars(d, rng, horizon_y)
    if moon:
        draw_moon(d, int(PW * moon[0]), int(PH * moon[1]), 7, moon[2])
    ground = int(PH * (0.80 if water else 0.92))
    dark = (30, 34, 52) if day else (6, 8, 16)
    fg = Image.new("RGBA", img.size, (0, 0, 0, 0)) if layered else None
    target = ImageDraw.Draw(fg) if layered else d
    layers = [(ground - 16, 0.55, 0.30, (9, 16), (30, 80)), (ground - 7, 0.78, 0.55, (11, 20), (36, 100)), (ground, 0.92, 0.80, (14, 26), (28, 84))]
    for base_y, shade, wlit, widths, heights in layers:
        heights = (max(2, int(heights[0] * height_scale)), max(3, int(heights[1] * height_scale)))
        body = mix(haze, dark, shade)
        trim = mix(haze, dark, shade - 0.30)
        draw_layer(target, rng, base_y, body, trim, win_cols if not day else [mix(c, haze, 0.6) for c in win_cols], lit * wlit * (0.4 if day else 1), widths, heights)
    if water:
        arr = np.asarray(img).copy()
        h = PH - ground
        refl = arr[ground - h:ground][::-1].astype(np.float32)
        for r in range(h):
            shift = int(round(1.4 * np.sin(r * 0.9)))
            row = np.roll(refl[r], shift, axis=0) * (0.60 - 0.35 * r / h)
            if r % 2:  # scanline gaps give the water its ripple
                row *= 0.65
            arr[ground + r] = np.clip(row + np.array(horizon, np.float32) * 0.10, 0, 255).astype(np.uint8)
        img = Image.fromarray(arr)
    else:
        target.rectangle([0, ground, PW, PH], fill=mix(haze, dark, 0.97))
    return (img, fg) if layered else img


WARM = [(255, 214, 140), (255, 190, 110), (255, 232, 180)]
COOL = [(170, 210, 255), (200, 230, 255), (255, 240, 200)]
NEON = [(255, 90, 170), (90, 220, 255), (255, 210, 90), (160, 120, 255)]
GREEN = [(150, 255, 190), (255, 240, 170), (190, 255, 240)]

SPECS = {
    "City Midnight": lambda: city(11, (4, 8, 22), (34, 52, 104), (44, 62, 118), COOL, moon=(0.74, 0.17, (120, 150, 230))),
    "City Neon": lambda: city(12, (10, 4, 28), (120, 44, 124), (96, 44, 128), NEON, lit=0.62),
    "City Amber": lambda: city(13, (14, 8, 18), (158, 78, 62), (116, 64, 74), WARM, moon=(0.2, 0.2, (255, 190, 140))),
    "City Harbour": lambda: city(14, (4, 10, 24), (30, 84, 126), (34, 74, 112), COOL + WARM, water=True, moon=(0.62, 0.15, (150, 190, 255))),
    "City Emerald": lambda: city(15, (4, 14, 18), (24, 96, 94), (30, 86, 84), GREEN, lit=0.5),
    "City Dawn": lambda: city(16, (22, 26, 60), (236, 136, 114), (138, 96, 126), WARM, horizon_y=0.84),
    "City Day": lambda: city(17, (96, 150, 214), (214, 228, 240), (150, 170, 196), WARM, horizon_y=0.86, day=True),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "Wallpapers"))
    ap.add_argument("--only", help="render a single wallpaper by name")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(exist_ok=True)
    for name, make in SPECS.items():
        if args.only and args.only != name:
            continue
        path = out / f"{name}.png"
        make().resize((PW * SCALE, PH * SCALE), Image.NEAREST).save(path, optimize=True)
        print(f"{path.name}  {path.stat().st_size // 1024} kB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
