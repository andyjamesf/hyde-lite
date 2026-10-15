#!/usr/bin/env python3
"""Generate the animated README banner docs/images/banner.gif (original work, CC0 1.0).

The Morphing Island over the pixel-art night skyline of the starter wallpapers (tools/gen_wallpapers.py): the
pill is a clock, grows into the bar, then the launcher, then the control centre, and shrinks back. Behind it
the stars twinkle, windows flicker and the antenna lamps blink. The skyline is drawn on a 320x90 grid and
enlarged 4x without smoothing; the island is drawn with antialiasing in Inter (the font the real shell uses,
SIL Open Font Licence). Fixed seeds and no clocks: re-running the script reproduces the committed file.

    python3 tools/gen_banner.py [--out FILE] [--preview DIR]

Needs numpy and Pillow, and the Inter font (Debian/Ubuntu: fonts-inter; Arch: inter-font).
"""
import argparse
import importlib.util
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("gen_wallpapers", HERE / "gen_wallpapers.py")
gw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gw)

GRID_W, GRID_H, SCALE = 320, 90, 4
W, H = GRID_W * SCALE, GRID_H * SCALE  # 1280 x 360
FRAMES, FRAME_MS = 24, 110  # the skyline loops every FRAMES * FRAME_MS = 2640 ms
LAMP = (255, 70, 70)


def base_image():
    """The skyline strip, drawn with the wallpaper generator on a shorter grid."""
    old = gw.PW, gw.PH
    gw.PW, gw.PH = GRID_W, GRID_H
    try:
        img = gw.city(21, (4, 8, 22), (40, 58, 112), (44, 62, 118), gw.COOL + gw.WARM, moon=(0.86, 0.25, (120, 150, 230)),
                      horizon_y=0.74, lit=0.6, height_scale=0.5)
    finally:
        gw.PW, gw.PH = old
    return np.asarray(img).copy()


def find_sprites(base):
    """Star pixels (bright, in the sky), window pixels (bright, in a building) and lamp pixels."""
    h, w, _ = base.shape
    lum = base.astype(int).sum(axis=2)
    stars, windows, lamps = [], [], []
    for y in range(h):
        for x in range(1, w - 1):
            px = tuple(int(v) for v in base[y, x])
            if px == LAMP:
                lamps.append((x, y))
            elif lum[y, x] > 480:
                # a window has a dark building pixel to its left; a star sits in the open sky
                left = int(lum[y, x - 1])
                if left < 200 and y > 12 and lum[y - 1, x] < 260:
                    windows.append((x, y))
                elif y < h * 0.62 and left < 330:
                    stars.append((x, y))
    return stars, windows, lamps


def frames():
    base = base_image()
    stars, windows, lamps = find_sprites(base)
    rng = np.random.default_rng(7)
    # moon pixels are bright and large; keep them still by only animating isolated star pixels
    star_phase = {p: rng.random() * 2 * math.pi for p in stars}
    star_speed = {p: int(rng.integers(1, 3)) for p in stars}
    flicker = {p for p in windows if rng.random() < 0.14}
    # every period divides FRAMES / 2, so the loop closes without a jump
    win_period = {p: int(rng.choice((2, 3, 4, 6, 12))) for p in flicker}
    win_phase = {p: int(rng.integers(0, FRAMES)) for p in flicker}
    off = {p: base[p[1], p[0] - 1].copy() for p in windows}
    out = []
    for t in range(FRAMES):
        f = base.copy()
        for p in stars:
            k = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * star_speed[p] * t / FRAMES + star_phase[p]))
            sky = base[max(p[1] - 1, 0), p[0]].astype(float)
            f[p[1], p[0]] = np.clip(sky + (base[p[1], p[0]].astype(float) - sky) * k, 0, 255)
        for p in flicker:
            if ((t + win_phase[p]) // 2) % win_period[p] == 0:
                f[p[1], p[0]] = off[p]
                if p[1] + 1 < f.shape[0] and tuple(base[p[1] + 1, p[0]]) == tuple(base[p[1], p[0]]):
                    f[p[1] + 1, p[0]] = off[p]
        for p in lamps:
            if (t // 6) % 2:
                f[p[1], p[0]] = base[p[1] + 1, p[0]]
        out.append(Image.fromarray(f.astype(np.uint8)).resize((GRID_W * SCALE, GRID_H * SCALE), Image.NEAREST))
    return out, (len(stars), len(windows), len(flicker), len(lamps))


# --- the island ---------------------------------------------------------------------------------------

SS = 2  # the island is drawn at 2x and reduced, for smooth edges
FONT_DIR = Path("/usr/share/fonts/opentype/inter")
BG, BORDER = (11, 21, 23), (255, 255, 255, 30)
TEXT, DIM, AMBER = (228, 236, 236), (136, 154, 156), (246, 185, 94)
AMBER_BG, TILE, TILE_ON = (58, 47, 28), (24, 36, 38), (62, 50, 30)
CX, TOP = W // 2, 28

_fonts = {}


def font(weight, size):
    key = (weight, size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(str(FONT_DIR / f"Inter-{weight}.otf"), int(size * SS))
    return _fonts[key]


class Pen:
    """Drawing in 1x coordinates onto a 2x layer."""

    def __init__(self, layer):
        self.layer, self.d = layer, ImageDraw.Draw(layer)

    @staticmethod
    def _s(v):
        flat = [c for item in v for c in (item if isinstance(item, tuple) else (item,))]
        return [round(c * SS) for c in flat]

    def rect(self, box, r, fill=None, outline=None, width=1):
        self.d.rounded_rectangle(self._s(box), radius=round(r * SS), fill=fill, outline=outline, width=round(width * SS))

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse(self._s(box), fill=fill, outline=outline, width=round(width * SS))

    def line(self, pts, fill, width=1):
        self.d.line(self._s(pts), fill=fill, width=round(width * SS), joint="curve")

    def arc(self, box, a0, a1, fill, width=1):
        self.d.arc(self._s(box), a0, a1, fill=fill, width=round(width * SS))

    def poly(self, pts, fill):
        self.d.polygon(self._s(pts), fill=fill)

    def text(self, xy, string, weight, size, fill, anchor="lm"):
        self.d.text((xy[0] * SS, xy[1] * SS), string, font=font(weight, size), fill=fill, anchor=anchor)


def wifi_icon(pen, x, y, color):
    for r in (10, 6.5, 3):
        pen.arc((x - r, y + 4 - r, x + r, y + 4 + r), 225, 315, color, 1.6)
    pen.ellipse((x - 1.4, y + 3, x + 1.4, y + 5.8), fill=color)


def battery_icon(pen, x, y, level, color):
    pen.rect((x, y - 6, x + 26, y + 6), 3, outline=color, width=1.4)
    pen.rect((x + 2.5, y - 3.5, x + 2.5 + 21 * level, y + 3.5), 1.5, fill=color)
    pen.rect((x + 27, y - 2.5, x + 29, y + 2.5), 1, fill=color)


def bell_icon(pen, x, y, color):
    pen.arc((x - 6, y - 8, x + 6, y + 4), 180, 360, color, 1.6)
    pen.line([(x - 6, y - 2), (x - 6, y + 3), (x + 6, y + 3), (x + 6, y - 2)], color, 1.6)
    pen.ellipse((x - 1.6, y + 4.5, x + 1.6, y + 7.5), fill=color)


def speaker_icon(pen, x, y, color):
    pen.poly([(x - 6, y - 3), (x - 2, y - 3), (x + 3, y - 7), (x + 3, y + 7), (x - 2, y + 3), (x - 6, y + 3)], color)
    pen.arc((x + 1, y - 5, x + 9, y + 5), 300, 60, color, 1.5)


def s_clock(pen, box):
    pen.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2 + 0.5), "22:13", "Medium", 19, TEXT, "mm")


def s_bar(pen, box):
    x0, y0, x1, y1 = box
    cy = (y0 + y1) / 2
    for i, n in enumerate("12345"):
        cx = x0 + 34 + i * 38
        if n == "3":
            pen.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=AMBER)
            pen.text((cx, cy + 0.5), n, "Bold", 15, BG, "mm")
        else:
            pen.text((cx, cy + 0.5), n, "Medium", 15, DIM, "mm")
    pen.text(((x0 + x1) / 2, cy + 0.5), "22:13", "Medium", 19, TEXT, "mm")
    x = x1 - 26
    pen.text((x, cy), "2h 13m", "Medium", 14, DIM, "rm")
    battery_icon(pen, x - 112, cy, 0.82, TEXT)
    speaker_icon(pen, x - 140, cy, TEXT)
    wifi_icon(pen, x - 172, cy - 3, TEXT)
    bell_icon(pen, x - 204, cy - 1, TEXT)
    pen.text((x - 262, cy), "23°", "Medium", 14, DIM, "rm")


def app_icon(pen, box, letter, color):
    pen.rect(box, 9, fill=color)
    pen.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2 + 0.5), letter, "Bold", 17, BG, "mm")


def s_launcher(pen, box):
    x0, y0, x1, y1 = box
    pen.ellipse((x0 + 26, y0 + 22, x0 + 42, y0 + 38), outline=DIM, width=2)
    pen.line([(x0 + 40, y0 + 36), (x0 + 46, y0 + 42)], DIM, 2)
    pen.text((x0 + 62, y0 + 32), "Search apps…", "Regular", 20, DIM)
    pen.text((x1 - 26, y0 + 32), "= calculate    : clipboard    ? keys", "Regular", 12.5, DIM, "rm")
    pen.line([(x0 + 18, y0 + 62), (x1 - 18, y0 + 62)], (255, 255, 255, 22), 1)
    rows = [("Terminal", "Command line", "T", (138, 180, 248)), ("Browser", "Web", "B", (246, 185, 94)),
            ("Files", "File manager", "F", (129, 201, 149)), ("Editor", "Text editor", "E", (206, 160, 238))]
    for i, (name, sub, letter, color) in enumerate(rows):
        ry = y0 + 74 + i * 52
        if i == 0:
            pen.rect((x0 + 14, ry, x1 - 14, ry + 46), 12, fill=TILE_ON)
        app_icon(pen, (x0 + 26, ry + 5, x0 + 62, ry + 41), letter, color)
        pen.text((x0 + 76, ry + 16), name, "Medium", 17, TEXT)
        pen.text((x0 + 76, ry + 34), sub, "Regular", 12.5, DIM)
        if i == 0:
            pen.text((x1 - 28, ry + 23), "↵", "Medium", 18, AMBER, "rm")


def s_control(pen, box):
    x0, y0, x1, y1 = box
    pen.ellipse((x0 + 24, y0 + 20, x0 + 56, y0 + 52), outline=AMBER, width=2)
    pen.text((x0 + 40, y0 + 37), "h", "Bold", 16, AMBER, "mm")
    pen.text((x0 + 68, y0 + 30), "hyde-lite", "Medium", 16, TEXT)
    pen.text((x0 + 68, y0 + 47), "Up for 2 d 9 h", "Regular", 12, DIM)
    battery_icon(pen, x1 - 54, y0 + 36, 0.81, TEXT)
    pen.text((x1 - 64, y0 + 36), "81%", "Medium", 13, DIM, "rm")
    tiles = [("Wi-Fi", "Connected", True), ("Bluetooth", "On", True), ("Peace mode", "Off", False), ("Night light", "Off", False)]
    for i, (title, sub, on) in enumerate(tiles):
        tx, ty = x0 + 18 + (i % 2) * 192, y0 + 68 + (i // 2) * 74
        pen.rect((tx, ty, tx + 182, ty + 64), 18, fill=TILE_ON if on else TILE, outline=(246, 185, 94, 70) if on else None, width=1)
        pen.ellipse((tx + 12, ty + 12, tx + 52, ty + 52), fill=AMBER if on else (36, 52, 55))
        icon = BG if on else DIM
        if i == 0:
            wifi_icon(pen, tx + 32, ty + 28, icon)
        elif i == 1:
            pen.line([(tx + 27, ty + 25), (tx + 37, ty + 39), (tx + 32, ty + 43), (tx + 32, ty + 21), (tx + 37, ty + 25), (tx + 27, ty + 39)], icon, 1.8)
        elif i == 2:
            bell_icon(pen, tx + 32, ty + 30, icon)
        else:
            pen.arc((tx + 24, ty + 23, tx + 42, ty + 41), 60, 300, icon, 2)
        pen.text((tx + 62, ty + 24), title, "Medium", 15, TEXT)
        pen.text((tx + 62, ty + 43), sub, "Regular", 12, DIM)
    sy = y0 + 68 + 2 * 74 + 18
    pen.rect((x0 + 18, sy, x1 - 18, sy + 34), 17, fill=TILE)
    pen.rect((x0 + 18, sy, x0 + 18 + (x1 - x0 - 36) * 0.55, sy + 34), 17, fill=AMBER)
    speaker_icon(pen, x0 + 40, sy + 17, BG)
    pen.text((x1 - 34, sy + 17), "55%", "Medium", 13, DIM, "rm")


# state: (width, height, corner radius, content painter)
STATES = {
    "clock": (172, 46, 23, s_clock),
    "bar": (880, 52, 26, s_bar),
    "launcher": (620, 292, 28, s_launcher),
    "control": (400, 298, 30, s_control),
}
ORDER = ["clock", "bar", "launcher", "control"]
# GIF stores durations in units of 10 ms, so every duration here is a multiple of 10. The whole show must last a
# whole number of skyline loops (4 x 2640 ms = 10560 ms) so the stars and windows do not jump when it repeats.
HOLD_MS = {"clock": 1650, "bar": 2190, "launcher": 2420, "control": 2300}
MORPH_MS = 500
MORPH_STEP_MS = 50


def ease(p):
    return 4 * p ** 3 if p < 0.5 else 1 - (-2 * p + 2) ** 3 / 2


def timeline():
    """[(duration ms, from state, to state, progress 0..1)], covering exactly 4 skyline loops."""
    steps = []
    for i, name in enumerate(ORDER):
        nxt = ORDER[(i + 1) % len(ORDER)]
        whole, rest = divmod(HOLD_MS[name], FRAME_MS)
        for _ in range(whole):
            steps.append((FRAME_MS, name, name, 0.0))
        if rest:
            steps.append((rest, name, name, 0.0))
        for k in range(MORPH_MS // MORPH_STEP_MS):
            steps.append((MORPH_STEP_MS, name, nxt, (k + 1) / (MORPH_MS // MORPH_STEP_MS)))
    return steps


def island(a, b, p):
    """The island between states a and b at progress p, as an RGBA image of the banner's size (1x)."""
    e = ease(p)
    wa, ha, ra, fa = STATES[a]
    wb, hb, rb, fb = STATES[b]
    w, h, r = wa + (wb - wa) * e, ha + (hb - ha) * e, ra + (rb - ra) * e
    box = (CX - w / 2, TOP, CX + w / 2, TOP + h)
    size = (W * SS, H * SS)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([round(c * SS) for c in box], radius=round(r * SS), fill=255)
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    soft = ImageChops.offset(mask, 0, 9 * SS).filter(ImageFilter.GaussianBlur(11 * SS)).point(lambda v: int(v * 0.6))
    shadow.putalpha(soft)
    pill = Image.new("RGBA", size, (0, 0, 0, 0))
    pill.paste(Image.new("RGBA", size, BG + (255,)), mask=mask)
    pen = Pen(pill)
    pen.rect(box, r, outline=BORDER, width=1)
    for name, fn, alpha in ((a, STATES[a][3], 1 - min(1, p * 2.4)), (b, STATES[b][3], min(1, max(0, (p - 0.55) * 2.4)))):
        if alpha <= 0:
            continue
        # the content is placed on the state's own box, so it does not slide while the pill morphs
        sw, sh = STATES[name][:2]
        own = (CX - sw / 2, TOP, CX + sw / 2, TOP + sh)
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        fn(Pen(layer), own)
        al = ImageChops.multiply(layer.getchannel("A"), mask).point(lambda v, k=alpha: int(v * k))
        layer.putalpha(al)
        pill = Image.alpha_composite(pill, layer)
    out = Image.alpha_composite(shadow, pill).convert("RGBa").resize((W, H), Image.LANCZOS).convert("RGBA")
    return out


def compose():
    bg_frames, counts = frames()
    out, durations, t = [], [], 0
    for dur, a, b, p in timeline():
        bg = bg_frames[(t // FRAME_MS) % FRAMES].convert("RGBA")
        out.append(Image.alpha_composite(bg, island(a, b, p)).convert("RGB"))
        durations.append(dur)
        t += dur
    assert t % (FRAMES * FRAME_MS) == 0, t
    return out, durations, counts


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(HERE.parent / "docs/images/banner.gif"))
    ap.add_argument("--preview", help="also write one PNG per state (and a mid-morph) into this directory")
    args = ap.parse_args()
    imgs, durations, counts = compose()
    # one palette for every frame, built from a sample that includes each state and a morph
    n = len(imgs)
    sample = Image.new("RGB", (W, H * 6))
    for i, idx in enumerate((0, n // 6, n // 3, n // 2, 2 * n // 3, 5 * n // 6)):
        sample.paste(imgs[idx], (0, i * H))
    pal = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    quant = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in imgs]
    quant[0].save(args.out, save_all=True, append_images=quant[1:], duration=durations, loop=0, optimize=True, disposal=1)
    out = Path(args.out)
    print(f"{out.name}: {W}x{H}, {n} frames, {sum(durations) / 1000:.2f} s (every duration a multiple of 10 ms: {all(d % 10 == 0 for d in durations)}), {out.stat().st_size // 1024} kB; "
          f"stars={counts[0]} windows={counts[1]} flickering={counts[2]} lamps={counts[3]}")
    if args.preview:
        d = Path(args.preview)
        d.mkdir(parents=True, exist_ok=True)
        marks = {}
        for i, (_, a, b, p) in enumerate(timeline()):
            marks.setdefault((a, b, round(p, 2) if a != b else 0), i)
        for name in ORDER:
            imgs[marks[(name, name, 0)]].save(d / f"{name}.png")
        imgs[marks[("bar", "launcher", 0.5)]].save(d / "morph-bar-launcher.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
