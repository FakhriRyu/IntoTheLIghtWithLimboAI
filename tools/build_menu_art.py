#!/usr/bin/env python3
"""Buat tekstur efek main menu dengan gaya pixel art (dithering Bayer):
  light_rays.png  berkas cahaya miring dari langit kanan atas
  vignette.png    tepi layar menggelap
  glow.png        bulatan cahaya lembut untuk sumber cahaya di cakrawala

Semua putih/hitam dengan alpha bertingkat; warnanya diatur dari Godot lewat
modulate. Ukuran 640x480 sama dengan viewport, jadi tiap piksel = 1 piksel layar.

Pemakaian:  python3 tools/build_menu_art.py   (butuh Pillow)
Keluaran:   Assets/menu/*.png
"""
import math, os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "Assets", "menu")
W, H = 640, 480

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
LEVELS = 6


def dither(v, x, y):
    """Kuantisasi 0..1 ke beberapa tingkat dengan ordered dithering."""
    v = max(0.0, min(1.0, v)) * LEVELS
    base = math.floor(v)
    frac = v - base
    if frac > (BAYER4[y % 4][x % 4] + 0.5) / 16.0:
        base += 1
    return min(base, LEVELS) / LEVELS


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def light_rays():
    # titik asal berkas di luar layar, kanan atas
    ox, oy = 590.0, -160.0
    # (sudut tengah dalam derajat dari arah bawah, lebar, kekuatan)
    beams = [(6, 2.5, 0.45), (13, 4.0, 0.8), (20, 2.0, 0.5),
             (26, 3.5, 0.75), (33, 1.8, 0.4), (39, 3.0, 0.55)]
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            dx, dy = x - ox, y - oy
            ang = math.degrees(math.atan2(-dx, dy))  # 0 = lurus ke bawah, + = ke kiri
            dist = math.hypot(dx, dy)
            v = 0.0
            for c, w, k in beams:
                d = abs(ang - c) / w
                v += k * max(0.0, 1.0 - d * d)
            # memudar menjauhi sumber dan ke arah tanah
            v *= smooth(1.0 - (dist - 200) / 520) * smooth(1.0 - (y - 300) / 180)
            a = dither(min(v, 1.0) * 0.6, x, y)
            px[x, y] = (255, 255, 255, int(a * 255))
    im.save(os.path.join(OUT, "light_rays.png"))


def vignette():
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            nx, ny = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            d = math.hypot(nx * 0.85, ny)
            v = smooth((d - 0.55) / 0.75)
            # bagian bawah sedikit lebih gelap, menegaskan tanah
            v = max(v, smooth((y - 400) / 80) * 0.6)
            px[x, y] = (0, 0, 0, int(dither(v, x, y) * 255))
    im.save(os.path.join(OUT, "vignette.png"))


def glow():
    # ukuran asli (tidak di-scale di Godot) supaya pola dither tetap 1 piksel
    gw, gh = 512, 400
    im = Image.new("RGBA", (gw, gh))
    px = im.load()
    for y in range(gh):
        for x in range(gw):
            d = math.hypot((x - gw / 2 + 0.5) / (gw / 2), (y - gh / 2 + 0.5) / (gh / 2))
            v = (1.0 - min(d, 1.0)) ** 2.2
            px[x, y] = (255, 255, 255, int(dither(v, x, y) * 255))
    im.save(os.path.join(OUT, "glow.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    light_rays()
    vignette()
    glow()
    print("ok ->", OUT)
