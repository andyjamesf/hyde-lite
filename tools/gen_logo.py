#!/usr/bin/env python3
"""Generate docs/images/logo.gif, the README logo (original work, CC0 1.0).

"HYDE LITE" in pixel-art letters in a night sky, with the city standing in front of them, so the bottom of the
letters disappears behind the buildings, like the depth effect of a phone lock screen. The stars twinkle, shooting
stars cross the sky (passing behind the letters too), a glint sweeps over the letters, and the windows and antenna
lamps of the city flicker. The skyline is the one of the starter wallpapers (tools/gen_wallpapers.py, drawn on a
320x100 grid and enlarged 4x without smoothing), so every pixel is a crisp square.

The loop is seamless: every cycle divides the loop length, and every shooting star finishes inside it. Fixed seeds
and no clocks: re-running the script reproduces the committed file.

    python3 tools/gen_logo.py [--out FILE] [--preview DIR]

Needs numpy and Pillow.
"""
import argparse
import importlib.util
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("gen_wallpapers", HERE / "gen_wallpapers.py")
gw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gw)

GRID_W, GRID_H, SCALE = 320, 100, 4
FRAMES, FRAME_MS = 96, 90                  # 8.64 s per loop; 2 * every flicker period divides FRAMES
LAMP = (255, 70, 70)
MOON = (0.93, 0.22)

GLYPHS = {
    "H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "Y": ["X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."],
    "D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
    "E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
    "L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
    "I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
    "T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
}
# word, colour at the top of the letters, colour at the bottom
WORDS = [("HYDE", (240, 246, 255), (150, 180, 240)), ("LITE", (255, 236, 205), (240, 160, 120))]
FONT_PX, LETTER_GAP, WORD_GAP = 5, 1, 3    # a letter pixel is FONT_PX grid pixels; gaps in letter pixels
LETTERS_TOP = 6
HEIGHT_SCALE = 0.55                        # how tall the buildings are, 1.0 being the wallpapers' skyline
SHADOW = (8, 14, 36)

# shooting stars: start x, start y, velocity (grid pixels per frame), first frame, frames
SHOOTING = [(268, 3, -5.0, 2.0, 8, 17), (36, 2, 4.6, 1.8, 52, 18), (170, 4, -3.2, 1.3, 80, 14)]
TRAIL = 10


def layout():
    """[(x, y, colour)] of every grid pixel of the letters, and the left edge of the text."""
    letter_w = 5 * FONT_PX
    total = sum(len(w) for w, _, _ in WORDS) * letter_w + (sum(len(w) - 1 for w, _, _ in WORDS)) * LETTER_GAP * FONT_PX \
        + (len(WORDS) - 1) * WORD_GAP * FONT_PX
    x0 = (GRID_W - total) // 2
    pixels, x = [], x0
    for word, top, bottom in WORDS:
        for k, letter in enumerate(word):
            rows = GLYPHS[letter]
            for r, line in enumerate(rows):
                for c, ch in enumerate(line):
                    if ch != "X":
                        continue
                    for dy in range(FONT_PX):
                        t = (r * FONT_PX + dy) / (len(rows) * FONT_PX - 1)
                        colour = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
                        pixels += [(x + c * FONT_PX + dx, LETTERS_TOP + r * FONT_PX + dy, colour) for dx in range(FONT_PX)]
            x += letter_w + (LETTER_GAP * FONT_PX if k < len(word) - 1 else 0)
        x += WORD_GAP * FONT_PX
    return pixels, x0, total


def scene():
    """The sky and the buildings as arrays: sky (H, W, 3) and the buildings' RGBA."""
    old = gw.PW, gw.PH
    gw.PW, gw.PH = GRID_W, GRID_H
    try:
        sky, fg = gw.city(31, (4, 8, 22), (40, 58, 112), (44, 62, 118), gw.COOL + gw.WARM, moon=(MOON[0], MOON[1], (120, 150, 230)),
                          horizon_y=0.8, lit=0.62, height_scale=HEIGHT_SCALE, layered=True)
    finally:
        gw.PW, gw.PH = old
    return np.asarray(sky).astype(np.int16), np.asarray(fg).astype(np.int16)


def sprites(sky, fg):
    h, w, _ = sky.shape
    lum = sky.sum(axis=2)
    mx, my = MOON[0] * GRID_W, MOON[1] * GRID_H
    stars = [(x, y) for y in range(2, int(h * 0.7)) for x in range(1, w - 1)
             if lum[y, x] > 480 and lum[y, x - 1] < 330 and (x - mx) ** 2 + (y - my) ** 2 > 13 ** 2]
    alpha, flum = fg[..., 3] > 0, fg[..., :3].sum(axis=2)
    windows, lamps = [], []
    for y in range(h):
        for x in range(1, w):
            if not alpha[y, x]:
                continue
            if tuple(fg[y, x, :3]) == LAMP:
                lamps.append((x, y))
            elif flum[y, x] > 480 and alpha[y, x - 1] and flum[y, x - 1] < 200:
                windows.append((x, y))
    return stars, windows, lamps


def blend(frame, x, y, colour, a):
    if 0 <= x < GRID_W and 0 <= y < GRID_H and a > 0:
        frame[y, x] = np.clip(frame[y, x] * (1 - a) + np.array(colour) * a, 0, 255)


def frames():
    sky, fg = scene()
    stars, windows, lamps = sprites(sky, fg)
    letters, _, _ = layout()
    rng = np.random.default_rng(7)
    phase = {p: rng.random() * 2 * math.pi for p in stars}
    speed = {p: int(rng.integers(1, 4)) for p in stars}
    rnd = random.Random(3)
    flicker = {p: (rnd.choice((2, 3, 4, 6, 8, 12, 16)), rnd.randrange(FRAMES)) for p in windows if rnd.random() < 0.16}
    body = {p: fg[p[1], p[0] - 1, :3].copy() for p in windows}
    mask = fg[..., 3] > 0
    out = []
    for t in range(FRAMES):
        f = sky.astype(np.float64)
        for p in stars:
            k = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * speed[p] * t / FRAMES + phase[p]))
            above = sky[max(p[1] - 1, 0), p[0]]
            f[p[1], p[0]] = above + (sky[p[1], p[0]] - above) * k
        for sx, sy, vx, vy, t0, dur in SHOOTING:
            if not 0 <= t - t0 < dur:
                continue
            hx, hy = sx + vx * (t - t0), sy + vy * (t - t0)
            for k in range(TRAIL):
                a = (1 - k / TRAIL) ** 1.6
                blend(f, round(hx - vx * k * 0.32), round(hy - vy * k * 0.32), (235, 244, 255), a * (0.95 if k else 1.0))
            blend(f, round(hx) + (1 if vx > 0 else -1), round(hy), (255, 255, 255), 0.9)
        # the letters, with a glint that crosses them once per loop
        glint = -30 + (GRID_W + 60) * min(max((t - 36) / 34, 0), 1) if 36 <= t <= 70 else None
        for x, y, _ in letters:
            if y + 1 < GRID_H and x + 1 < GRID_W:
                blend(f, x + 1, y + 1, SHADOW, 0.45)
        for x, y, colour in letters:
            c = np.array(colour, float)
            if glint is not None and abs((x + (y - LETTERS_TOP) * 0.6) - glint) < 7:
                c = np.clip(c + 70, 0, 255)
            f[y, x] = c
        # the city in front
        city = fg[..., :3].astype(np.float64).copy()
        for p, (period, ph) in flicker.items():
            if ((t + ph) // 2) % period == 0:
                city[p[1], p[0]] = body[p]
        for p in lamps:
            if (t // 12) % 2:
                city[p[1], p[0]] = fg[p[1] + 1, p[0], :3]
        f[mask] = city[mask]
        img = Image.fromarray(np.clip(f, 0, 255).astype(np.uint8))
        out.append(img.resize((GRID_W * SCALE, GRID_H * SCALE), Image.NEAREST))
    return out, (len(stars), len(windows), len(flicker), len(lamps))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(HERE.parent / "docs/images/logo.gif"))
    ap.add_argument("--preview", help="also write a few frames as PNG into this directory")
    args = ap.parse_args()
    imgs, counts = frames()
    n = len(imgs)
    sample = Image.new("RGB", (imgs[0].width, imgs[0].height * 6))
    for i, k in enumerate((0, 14, 30, 50, 60, 84)):
        sample.paste(imgs[k], (0, i * imgs[0].height))
    pal = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    quant = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in imgs]
    out = Path(args.out)
    quant[0].save(out, save_all=True, append_images=quant[1:], duration=FRAME_MS, loop=0, optimize=True, disposal=1)
    print(f"{out.name}: {imgs[0].width}x{imgs[0].height}, {n} frames, {n * FRAME_MS / 1000:.2f} s, {out.stat().st_size // 1024} kB; "
          f"stars={counts[0]} windows={counts[1]} flickering={counts[2]} lamps={counts[3]}")
    if args.preview:
        d = Path(args.preview)
        d.mkdir(parents=True, exist_ok=True)
        for k in (0, 14, 60):
            imgs[k].save(d / f"frame{k:02d}.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
