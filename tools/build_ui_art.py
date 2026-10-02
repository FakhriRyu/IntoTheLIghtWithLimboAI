#!/usr/bin/env python3
"""Buat aset UI pixel art untuk HUD player, layar pilih upgrade, dan menu:

  HUD (Scenes/UI/player_hud.tscn)
    hud_portrait_back.png   isi wajik potret (juga dipakai sebagai mask clip)
    hud_portrait_ring.png   bingkai wajik + sirip baja + permata
    hud_bar_<n>.png         bingkai bar bersudut miring (hp, light, dash, xp)
    hud_bar_<n>_fill.png    isi bar abu-abu bertekstur; warnanya dari tint Godot
    hud_level_chip.png      chip level berbentuk panah

  Kartu upgrade (Scenes/UI/level_up_screen.tscn)
    card_panel.png          panel kartu ukuran pas (CARD_SIZE di level_up_screen.gd)
    card_glow.png           pendar putih di sekeliling kartu terpilih (di-modulate)
    card_icon_frame.png     wajik tempat ikon; cincinnya putih, di-modulate warna rarity
    pip_on.png / pip_off.png  penanda tumpukan upgrade
    slot_frame.png          wajik kecil untuk daftar upgrade di layar akhir run

  Menu (pause, pengaturan, run over; dipakai Assets/ui/pixel_theme.tres)
    panel.png               panel 9-patch (margin 10)
    button.png / button_focus.png   tombol 9-patch (margin 5)
    slider_*.png            jalur, isi, dan kenop slider volume
    btn_pause*.png          tombol jeda di HUD

  Boss bar (Scenes/UI/boss_health_bar.tscn)
    boss_bar_frame.png      bingkai besi hitam berduri + tetesan darah
    boss_bar_fill.png       isi bar abu-abu bertekstur; warnanya dari tint Godot
    boss_bar_tick.png       penanda ambang fase 2 yang menancap di bar
    boss_crest.png          lambang wajik bertanduk berisi tengkorak
    boss_crest_eyes.png     overlay mata tengkorak (di-modulate supaya berpendar)

  Ikon
    icons/<id>.png          ikon 16x16 tiap upgrade di Scripts/Core/upgrades.gd

Semua digambar per piksel (tanpa anti-alias) supaya cocok dengan viewport 640x480.

Pemakaian:  python3 tools/build_ui_art.py   (butuh Pillow)
Keluaran:   Assets/ui/*.png, Assets/ui/icons/*.png
"""
import os, random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "Assets", "ui")
ICON_OUT = os.path.join(OUT, "icons")

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
INK = "07080c"  # garis luar paling gelap


# ------------------------------------------------------------------ helper

def rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def bayer(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def pick(colors, t, x, y):
    """Pilih warna dari gradasi `colors` (0..1) dengan ordered dithering."""
    t = max(0.0, min(1.0, t)) * (len(colors) - 1)
    i = int(t)
    if i < len(colors) - 1 and (t - i) > bayer(x, y):
        i += 1
    return colors[i]


def region(w, h, fn):
    return {(x, y) for y in range(h) for x in range(w) if fn(x, y)}


N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def erode(m):
    return {(x, y) for (x, y) in m if all((x + dx, y + dy) in m for dx, dy in N4)}


def dilate(m):
    return m | {(x + dx, y + dy) for (x, y) in m for dx, dy in N4}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = rgba(c) if isinstance(c, str) else c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def save(self, *parts):
        self.im.save(os.path.join(OUT, *parts))


def poly_mask(w, h, pts):
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon(pts, fill=1)
    px = im.load()
    return {(x, y) for y in range(h) for x in range(w) if px[x, y]}


# ------------------------------------------------------------------ HUD

def bar(name, w, h, border=True, seed=1):
    """Bingkai bar dengan ujung kanan miring "/" dan tekstur isinya."""
    shape = region(w, h, lambda x, y: x <= w - 1 - y)
    c = Canvas(w, h)
    m1 = erode(shape)
    for p in shape - m1:
        c.set(*p, INK)
    inner = m1
    if border:
        m2 = erode(m1)
        for (x, y) in m1 - m2:
            c.set(x, y, "6f7b95" if y == 1 else "272c3a" if y == h - 2 else "434b60")
        inner = m2
    top = min(y for _, y in inner)
    for (x, y) in inner:
        c.set(x, y, "0c070b" if y == top else "170e15")
    c.save(f"hud_bar_{name}.png")

    # isi: abu-abu bertekstur (diwarnai lewat tint_progress), ukuran = area dalam
    ox = min(x for x, _ in inner)
    oy = top
    fw = max(x for x, _ in inner) - ox + 1
    fh = max(y for _, y in inner) - oy + 1
    rng = random.Random(seed)
    cells = {}
    f = Canvas(fw, fh)
    for (x, y) in inner:
        fx, fy = x - ox, y - oy
        if fh <= 3:
            v = 1.0 if fy == 0 else 0.78
        elif fy == 0:
            v = 1.0
        elif fy == fh - 1:
            v = 0.58
        else:
            key = (fx // 3, fy // 2)
            if key not in cells:
                cells[key] = rng.random()
            # bercak gelap-terang seperti tekstur darah/cahaya pada referensi
            v = 0.74 + (cells[key] - 0.5) * 0.26 + (0.08 if fy == 1 else 0.0)
            v = pick([0.6, 0.7, 0.8, 0.9], (v - 0.6) / 0.3, fx, fy)
        g = int(255 * max(0.0, min(1.0, v)))
        f.set(fx, fy, (g, g, g, 255))
    f.save(f"hud_bar_{name}_fill.png")


def diamond_faces(x, y, cx, cy, tl, tr, bl, br):
    if y < cy:
        return tl if x <= cx else tr
    return bl if x <= cx else br


def portrait():
    W, H, cx, cy, R = 68, 64, 36, 32, 27
    d = lambda x, y: abs(x - cx) + abs(y - cy)

    back = Canvas(W, H)
    for y in range(H):
        for x in range(W):
            if d(x, y) <= R - 4:
                t = (y - (cy - R)) / (2 * R)
                back.set(x, y, pick(["26385a", "1b2944", "121c31", "0b111f"], t, x, y))
    back.save("hud_portrait_back.png")

    ring = Canvas(W, H)
    # sirip baja: dua di sudut kiri, satu di sisi kanan atas
    fins = [
        [(12, 30), (6, 21), (3, 13), (3, 5), (8, 13), (13, 20), (19, 24)],
        [(12, 34), (8, 39), (6, 45), (11, 41), (16, 38)],
        [(48, 17), (53, 11), (59, 4), (57, 12), (55, 21)],
    ]
    fin = set()
    for pts in fins:
        fin |= poly_mask(W, H, pts)
    for p in dilate(fin) - fin:
        ring.set(*p, INK)
    for (x, y) in fin:
        edge = (x, y - 1) not in fin or (x - 1, y) not in fin
        ring.set(x, y, "6a7590" if edge else "3a4259")

    for y in range(H):
        for x in range(W):
            k = R - d(x, y)
            if k == 0 or k == 4:
                ring.set(x, y, INK)
            elif k == 1:
                ring.set(x, y, diamond_faces(x, y, cx, cy, "b4bed2", "818ca4", "5a6379", "3d4457"))
            elif k == 2:
                ring.set(x, y, diamond_faces(x, y, cx, cy, "6e7991", "5b657b", "444c5f", "313746"))
            elif k == 3:
                ring.set(x, y, diamond_faces(x, y, cx, cy, "4c556a", "424a5d", "343a4a", "272c38"))
    # paku keling di tiga sudut
    for (x, y) in [(cx, cy - R + 2), (cx - R + 2, cy), (cx + R - 2, cy)]:
        ring.set(x, y, "d8e0ee")
        ring.set(x + 1, y, "3d4457")
    # permata biru di sudut bawah (seperti referensi)
    gx, gy = cx, cy + R - 2
    for y in range(gy - 4, gy + 5):
        for x in range(gx - 4, gx + 5):
            k = abs(x - gx) + abs(y - gy)
            if k == 4:
                ring.set(x, y, INK)
            elif k <= 3:
                col = "e4fbff" if (y < gy and x <= gx and k >= 2) else "64d4ff" if y <= gy else "2f72c8"
                ring.set(x, y, col)
    ring.save("hud_portrait_ring.png")


def level_chip():
    w, h = 34, 15
    mid = h // 2
    shape = region(w, h, lambda x, y: x <= w - 1 - abs(y - mid))
    c = Canvas(w, h)
    m1 = erode(shape)
    m2 = erode(m1)
    for p in shape - m1:
        c.set(*p, INK)
    for (x, y) in m1 - m2:
        c.set(x, y, "6c9ad6" if y <= mid else "2f5089")
    for (x, y) in m2:
        c.set(x, y, pick(["22427a", "183262", "0f2146"], (y - 2) / (h - 4), x, y))
    c.save("hud_level_chip.png")


# ------------------------------------------------------------------ kartu

CARD_W, CARD_H, CHAMFER = 156, 236, 6
GLOW_PAD = 6


def card_shape(w, h, ch, inset=0):
    def f(x, y):
        dx = min(x, w - 1 - x) - inset
        dy = min(y, h - 1 - y) - inset
        return dx >= 0 and dy >= 0 and dx + dy >= ch
    return region(w, h, f)


def card_panel():
    w, h = CARD_W, CARD_H
    c = Canvas(w, h)
    s0 = card_shape(w, h, CHAMFER)
    s1 = erode(s0)
    s2 = erode(s1)
    s3 = erode(s2)
    for p in s0 - s1:
        c.set(*p, "05060b")
    for (x, y) in s1 - s2:
        c.set(x, y, "5b6692" if y <= 1 else "3d4566" if y < h // 2 else "2b3150")
    for p in s2 - s3:
        c.set(*p, "0a0c16")
    for (x, y) in s3:
        c.set(x, y, pick(["1f2542", "1a1f38", "15192e", "111426"], y / h, x, y))
    # garis hias dalam dengan sudut terpotong
    deco = card_shape(w, h, 4, inset=6)
    for p in deco - erode(deco):
        c.set(*p, "2a3255")
    # pemisah di bawah nama + rarity, dengan wajik kecil di tengah
    dy = 80
    for x in range(26, w - 26):
        c.set(x, dy, "2e3760")
    for y in range(dy - 3, dy + 4):
        for x in range(w // 2 - 3, w // 2 + 4):
            k = abs(x - w // 2) + abs(y - dy)
            if k == 3:
                c.set(x, y, "0a0c16")
            elif k < 3:
                c.set(x, y, "6a78b0" if y < dy else "45507e")
    c.save("card_panel.png")


def card_glow():
    w, h = CARD_W + GLOW_PAD * 2, CARD_H + GLOW_PAD * 2
    c = Canvas(w, h)
    base = {(x + GLOW_PAD, y + GLOW_PAD) for (x, y) in card_shape(CARD_W, CARD_H, CHAMFER)}
    inner = erode(erode(base))
    for (x, y) in base - inner:
        c.set(x, y, (255, 255, 255, 255))
    ring = base
    for k in range(1, GLOW_PAD + 1):
        grown = dilate(ring)
        a = (1.0 - k / (GLOW_PAD + 1)) ** 1.4
        for (x, y) in grown - ring:
            if a > bayer(x, y):
                c.set(x, y, (255, 255, 255, 150 if k > 1 else 230))
        ring = grown
    c.save("card_glow.png")


def icon_frame(R=31, name="card_icon_frame"):
    n = R * 2 + 1
    cx = cy = R
    c = Canvas(n, n)
    for y in range(n):
        for x in range(n):
            k = R - (abs(x - cx) + abs(y - cy))
            if k < 0:
                continue
            if k == 0 or k == 3:
                c.set(x, y, INK)
            elif k == 1:
                c.set(x, y, diamond_faces(x, y, cx, cy, "ffffff", "e6e6e6", "c4c4c4", "a0a0a0"))
            elif k == 2:
                c.set(x, y, diamond_faces(x, y, cx, cy, "d6d6d6", "c2c2c2", "a4a4a4", "848484"))
            else:
                t = (abs(x - cx) + abs(y - cy)) / (R - 4)
                c.set(x, y, pick(["262636", "1b1b28", "12121c", "0b0b12"], t, x, y))
    c.save(name + ".png")


def pips():
    for name, fill in (("pip_on", "ffffff"), ("pip_off", "3a3f55")):
        c = Canvas(7, 7)
        for y in range(7):
            for x in range(7):
                k = abs(x - 3) + abs(y - 3)
                if k == 3:
                    c.set(x, y, INK)
                elif k < 3:
                    c.set(x, y, fill)
        c.save(name + ".png")


# ------------------------------------------------------------------ menu (pause, pengaturan, run over)

def framed(w, h, ch, outline, border, body, border_bottom=None, inner=None):
    """Kotak bersudut terpotong: garis luar, bingkai 1px, isi rata (aman di-9-patch)."""
    c = Canvas(w, h)
    s0 = card_shape(w, h, ch)
    s1 = erode(s0)
    s2 = erode(s1)
    for p in s0 - s1:
        c.set(*p, outline)
    for (x, y) in s1 - s2:
        c.set(x, y, border if border_bottom is None or y < h // 2 else border_bottom)
    rest = s2
    if inner:
        s3 = erode(s2)
        for p in s2 - s3:
            c.set(*p, inner)
        rest = s3
    for p in rest:
        c.set(*p, body)
    return c


def menu_panel():
    # 9-patch 32x32, margin 10 (lihat pixel_theme.tres)
    c = framed(32, 32, CHAMFER, "05060b", "4a5480", "171b30", "2b3150", inner="0a0c16")
    deco = card_shape(32, 32, 4, inset=6)
    for p in deco - erode(deco):
        c.set(*p, "2a3255")
    c.save("panel.png")


def menu_buttons():
    # 9-patch 24x18, margin 5
    framed(24, 18, 3, "05060b", "39405f", "141829", "262b45").save("button.png")
    framed(24, 18, 3, "05060b", "ffd45a", "3a2f2a", "c98f2e", inner="1a1420").save("button_focus.png")


def slider_parts():
    # 9-patch 16x8, margin 4 di semua sisi
    framed(16, 8, 2, "05060b", "2b3150", "0c070b").save("slider_track.png")
    fill = framed(16, 8, 2, "05060b", "ffe27a", "ffb53c", "c9661b")
    fill.save("slider_fill.png")
    for name, body, hi in (("slider_grabber", "e9dcb4", "fffbea"), ("slider_grabber_hl", "ffd45a", "fffbea")):
        c = Canvas(11, 11)
        for y in range(11):
            for x in range(11):
                k = abs(x - 5) + abs(y - 5)
                if k == 5:
                    c.set(x, y, INK)
                elif k < 5:
                    c.set(x, y, hi if (y < 5 and x <= 5 and k >= 3) else body)
        c.save(name + ".png")


def pause_button():
    for name, border, bottom in (("btn_pause", "4a5480", "2b3150"), ("btn_pause_hover", "ffd45a", "c98f2e")):
        c = framed(22, 22, 4, "05060b", border, "171b30", bottom, inner="0a0c16")
        for x0 in (7, 12):
            for y in range(6, 16):
                for x in range(x0, x0 + 3):
                    c.set(x, y, "fffbea" if x == x0 else "e9dcb4")
        c.save(name + ".png")


# ------------------------------------------------------------------ boss bar
# Health bar bos (Scenes/UI/boss_health_bar.tscn): besi hitam berduri, darah, tengkorak.

BOSS_W, BOSS_BODY_H = 300, 17   # badan bar (tanpa duri)
BOSS_PAD_X, BOSS_PAD_Y = 6, 5   # ruang untuk duri ujung (kiri/kanan) dan duri atas/bawah


def boss_bar_shape():
    """Badan bar: segi enam pipih, ujung kiri-kanan runcing 45 derajat (koordinat kanvas)."""
    mid = BOSS_BODY_H // 2
    return {(x + BOSS_PAD_X, y + BOSS_PAD_Y)
            for y in range(BOSS_BODY_H) for x in range(BOSS_W)
            if abs(y - mid) <= x <= BOSS_W - 1 - abs(y - mid)}


def boss_bar():
    W, H = BOSS_W + BOSS_PAD_X * 2, BOSS_BODY_H + BOSS_PAD_Y * 2
    oy, mid = BOSS_PAD_Y, BOSS_PAD_Y + BOSS_BODY_H // 2
    c = Canvas(W, H)

    body = boss_bar_shape()
    m1 = erode(body)
    m2 = erode(m1)
    channel = erode(m2)

    # duri: atas mengarah ke atas, bawah ke bawah (selang-seling), ujung mendatar
    thorns = set()
    drips = {}
    for x in range(BOSS_PAD_X + 16, BOSS_PAD_X + BOSS_W - 12, 24):
        for r in range(BOSS_PAD_Y):          # lebar 1,1,3,3,5 dari ujung ke pangkal
            thorns |= {(x + dx, r) for dx in range(-(r // 2), r // 2 + 1)}
        bx = x + 12
        if bx < BOSS_PAD_X + BOSS_W - 14:
            for r in range(BOSS_PAD_Y - 2):  # duri bawah lebih pendek
                thorns |= {(bx + dx, H - 1 - r) for dx in range(-(r // 2), r // 2 + 1)}
    # tetesan darah yang menggantung dari bawah bar
    rng = random.Random(7)
    for x in range(BOSS_PAD_X + 30, BOSS_PAD_X + BOSS_W - 20, 37):
        x += rng.randint(-5, 5)
        if any((x + dx, H - 1) in thorns for dx in (-2, -1, 0, 1, 2)):
            x += 5
        drips[x] = rng.randint(2, BOSS_PAD_Y)
    for side in (-1, 1):
        tip = BOSS_PAD_X - 1 if side < 0 else BOSS_PAD_X + BOSS_W
        for i in range(BOSS_PAD_X):
            x = tip + side * i
            half = 1 if i < BOSS_PAD_X - 2 else 0
            thorns |= {(x, mid + dy) for dy in range(-half, half + 1)}
    thorns -= body

    for p in dilate(thorns | body) - thorns - body:
        c.set(*p, INK)
    for (x, y) in thorns:
        lit = (x - 1, y) not in thorns or (x, y - 1) not in thorns
        c.set(x, y, "8c7d88" if lit and y < mid else "4a3d48" if y < mid else "2c232b")
    bottom = oy + BOSS_BODY_H
    for x, n in drips.items():
        for i in range(n):
            c.set(x, bottom + i, "8e1b2f" if i < n - 1 else "c4283a")
        if n >= 3:
            c.set(x - 1, bottom + n - 1, "5a0f18")
            c.set(x + 1, bottom + n - 1, "5a0f18")

    for p in body - m1:
        c.set(*p, INK)
    # bingkai besi hitam, dipotong jadi lempengan tiap 50px
    for (x, y) in m1 - m2:
        if (x - BOSS_PAD_X) % 50 == 25:
            c.set(x, y, "1c151b")
        else:
            c.set(x, y, "7d6f7a" if y < mid else "3a2f39")
    # garis darah di dalam bingkai
    for (x, y) in m2 - channel:
        c.set(x, y, "6a1220" if y < mid else "3c0912")
    top = min(y for _, y in channel)
    for (x, y) in channel:
        c.set(x, y, "080204" if y == top else pick(["170609", "12050a", "0d0306"], (y - top) / 8, x, y))
    # paku keling di tiap sambungan lempengan
    for x in range(BOSS_PAD_X + 25, BOSS_PAD_X + BOSS_W - 10, 50):
        c.set(x, oy + 1, "c9bcc6")
        c.set(x, oy + BOSS_BODY_H - 2, "6d606b")
    c.save("boss_bar_frame.png")

    # isi abu-abu bertekstur seukuran saluran (diwarnai lewat tint_progress)
    ox = min(x for x, _ in channel)
    fw = max(x for x, _ in channel) - ox + 1
    fh = max(y for _, y in channel) - top + 1
    rng = random.Random(13)
    cells = {}
    f = Canvas(fw, fh)
    for (x, y) in channel:
        fx, fy = x - ox, y - top
        if fy == 0:
            v = 1.0
        elif fy == fh - 1:
            v = 0.5
        else:
            key = (fx // 4, fy // 2)
            if key not in cells:
                cells[key] = rng.random()
            # urat-urat gelap seperti darah yang mengental
            v = 0.72 + (cells[key] - 0.5) * 0.3 + (0.1 if fy == 1 else 0.0) - (0.08 if fy >= fh - 3 else 0.0)
            v = pick([0.55, 0.66, 0.78, 0.9], (v - 0.55) / 0.35, fx, fy)
        g = int(255 * max(0.0, min(1.0, v)))
        f.set(fx, fy, (g, g, g, 255))
    f.save("boss_bar_fill.png")
    print("boss bar channel offset", (ox, top), "size", (fw, fh))


def boss_tick():
    """Penanda ambang fase 2 yang menancap melintang di bar."""
    w, h = 5, 17
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, h - 1)
            if edge and not ((x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                c.set(x, y, INK)
            elif not edge:
                c.set(x, y, "ff6a4a" if x == 2 and 5 <= y <= 11 else "8c7d88" if x == 1 else "3a2f39")
    c.save("boss_bar_tick.png")


BOSS_SKULL = [
    "....bBBBBBb....",
    "..bBBBBBBBBBb..",
    ".bBBBBBBBBBBBd.",
    ".BBBBBBBBBBBBd.",
    "bBBBBBBBBBBBBBd",
    "bBkkkkBBBkkkkbd",
    "bBkkkkBdBkkkkbd",
    "dbBkkBBdBBkkbdd",
    ".dbBBBBBBBBBdd.",
    "..dbbBkdkBbdd..",
    "...dbBBBBBbd...",
    "...dkdkdkdkd...",
    "...dbbbbbbbd...",
    "....ddddddd....",
]


def boss_crest():
    """Lambang bos: wajik besi hitam bertanduk berisi tengkorak, permata darah di bawah.
    Matanya digambar terpisah (boss_crest_eyes.png) supaya bisa berpendar di fase 2."""
    W, H, cx, cy, R = 60, 58, 30, 35, 20
    d = lambda x, y: abs(x - cx) + abs(y - cy)
    c = Canvas(W, H)

    # tanduk melengkung dari dua sisi atas wajik
    left = [(22, 28), (15, 23), (9, 17), (5, 10), (3, 3), (4, 0), (8, 6), (13, 12), (19, 17), (27, 21)]
    horns = poly_mask(W, H, left) | poly_mask(W, H, [(W - 1 - x, y) for x, y in left])
    for p in dilate(horns) - horns:
        c.set(*p, INK)
    for (x, y) in horns:
        t = 1.0 - y / 26.0
        edge = (x, y - 1) not in horns or (x - 1, y) not in horns
        ring_band = y % 5 == 4 and t < 0.8   # cincin pertumbuhan tanduk
        col = pick(["5e5246", "86796a", "b5a78f", "d9ccb2"], t, x, y)
        c.set(x, y, "efe3cc" if edge and t > 0.45 else "4a4036" if ring_band else col)

    faces = {
        1: ("a08e98", "74646f", "4e424c", "362c35"),
        2: ("6a5b66", "574a55", "40353f", "2c242b"),
        3: ("4a3e48", "3e333c", "2f272e", "221b21"),
    }
    for y in range(H):
        for x in range(W):
            k = R - d(x, y)
            if k < 0:
                continue
            if k in (0, 4):
                c.set(x, y, INK)
            elif k in faces:
                c.set(x, y, diamond_faces(x, y, cx, cy, *faces[k]))
            else:
                t = (y - (cy - R)) / (2 * R)
                c.set(x, y, pick(["3e0b13", "2c070e", "1d050a", "120306"], t, x, y))

    # tengkorak
    sx, sy = cx - 7, cy - 8
    bone = {"B": "e6dcc8", "b": "b3a790", "d": "726754", "k": "0a0204"}
    filled = set()
    for y, row in enumerate(BOSS_SKULL):
        for x, ch in enumerate(row):
            if ch != ".":
                c.set(sx + x, sy + y, bone[ch])
                filled.add((sx + x, sy + y))
    for p in dilate(filled) - filled:
        c.set(*p, INK)

    # paku keling di sudut kiri, kanan, atas
    for (x, y) in [(cx - R + 2, cy), (cx + R - 2, cy), (cx, cy - R + 2)]:
        c.set(x, y, "d8ccd4")
        c.set(x + 1, y, "362c35")
    # permata darah di sudut bawah
    gx, gy = cx, cy + R - 2
    for y in range(gy - 4, gy + 5):
        for x in range(gx - 4, gx + 5):
            k = abs(x - gx) + abs(y - gy)
            if k == 4:
                c.set(x, y, INK)
            elif k <= 3:
                c.set(x, y, "ffd2c4" if (y < gy and x <= gx and k >= 2) else "e8303a" if y <= gy else "86101e")
    c.save("boss_crest.png")

    # mata: hanya piksel rongga mata, dipakai sebagai overlay yang di-modulate
    e = Canvas(W, H)
    for y, row in enumerate(BOSS_SKULL):
        for x, ch in enumerate(row):
            if ch == "k":
                core = y == 6 and x in (3, 4, 10, 11)
                e.set(sx + x, sy + y, "ffb070" if core else "c0202a" if y in (5, 6) else "5a0810")
    e.save("boss_crest_eyes.png")


# ------------------------------------------------------------------ ikon upgrade
# Peta 16x16; garis luar gelap ditambahkan otomatis di sekeliling piksel berwarna.

PALETTE = {
    "w": "fffbea", "e": "e9dcb4", "E": "b39a72",
    "y": "ffe36e", "o": "ffb02e", "O": "c9661b",
    "r": "e5383f", "R": "8e1b2f", "p": "ff8f8a",
    "s": "dfe6f0", "S": "8b98ae", "d": "4d566c",
    "b": "9a6436", "B": "5e3a20",
    "c": "8af0ff", "C": "36a2ff", "n": "1f4f9e",
    "v": "b083ff", "V": "6640b8", "m": "35255e",
    "g": "a6ef5a", "G": "3f9d3a",
    "K": INK,
}

ICONS = {
    # Bilah Tajam: pedang miring
    "tajam": [
        "................",
        "..............w.",
        ".............wS.",
        "............wsS.",
        "...........wsS..",
        "..........wsS...",
        ".........wsS....",
        "...o....wsS.....",
        "...oo..wsS......",
        "....oowsS.......",
        ".....oOS........",
        ".....BOoo.......",
        "....bB..o.......",
        "...bB...........",
        "..yo............",
        "................",
    ],
    # Jantung Baja: hati merah dengan kilau
    "jantung": [
        "................",
        "................",
        "...rrr....rrr...",
        "..rpprr..rrrrr..",
        ".rpwprrrrrrrrrr.",
        ".rpprrrrrrrrrrR.",
        ".rprrrrrrrrrrrR.",
        ".rrrrrrrrrrrrrR.",
        "..rrrrrrrrrrrR..",
        "...rrrrrrrrrR...",
        "....rrrrrrrR....",
        ".....rrrrrR.....",
        "......rrrR......",
        ".......rR.......",
        "................",
        "................",
    ],
    # Langkah Angin: sepatu bersayap
    "angin": [
        "................",
        "..........w.....",
        ".........ws.w...",
        "........wss.s.w.",
        "...bbb.wsssss.s.",
        "...bBbwssssssS..",
        "...bbbbsssSS....",
        "...bBbbb........",
        "...bbbbb........",
        "...bbbbbb.......",
        "..bbbbbbbbbb....",
        "..bbbbbbbbbbbb..",
        "..BBBBBBBBBBBB..",
        "................",
        ".cc..ccc..cc....",
        "................",
    ],
    # Dash Kilat: petir biru (warna bar dash)
    "kilat": [
        "................",
        ".........cccc...",
        "........cccC....",
        ".......cwcC.....",
        "......cwcC......",
        ".....cwcC.......",
        "....cwcccccc....",
        "...cccccccwC....",
        "........cwC.....",
        ".......cwC......",
        "......ccC.......",
        ".....ccC........",
        "....cC..........",
        "...C............",
        "................",
        "................",
    ],
    # Sumbu Awet: lilin menyala
    "sumbu": [
        ".......y........",
        "......yoy.......",
        "......owo.......",
        ".....oywyo......",
        ".....oywyo......",
        "......oyo.......",
        ".......B........",
        "......ewE.......",
        ".....eewwE......",
        ".....eewEE......",
        ".....eewEE......",
        ".....eewEE......",
        ".....eeeEE......",
        "...ObbbbbbbO....",
        "....OOOOOOO.....",
        "................",
    ],
    # Lentera Besar: lentera dengan pendar
    "lentera": [
        "......SS........",
        ".....S..S.......",
        "....dddddd......",
        "...dSSSSSSd.....",
        "y...dyyyyd...y..",
        "....dywwyd......",
        "...ydywwyd.y....",
        "....dywwyd......",
        "....dyooyd......",
        "....dyyyyd......",
        "...dSSSSSSd.....",
        "....dddddd......",
        "y............y..",
        "................",
        "................",
        "................",
    ],
    # Tangan Cahaya: tangan bercahaya menarik butir cahaya
    "magnet": [
        "....y...........",
        "...ywy....y.....",
        "....y.........y.",
        "......o.o.o.....",
        ".....oyoyoyo....",
        ".....oyoyoyo....",
        ".....oyoyoyo.o..",
        ".....oyyyyyooyo.",
        ".....oyyyyyyyyo.",
        ".....oyyyyyyyo..",
        ".....oyyyyyyo...",
        "......oyyyyo....",
        "......OOOOOO....",
        "......OOOOOO....",
        "................",
        "................",
    ],
    # Haus Cahaya: tetes cahaya yang terbelah tebasan
    "haus": [
        "................",
        ".......y........",
        ".......y........",
        "......yyy.......",
        "......yyy.......",
        ".....yyyyy...w..",
        "....yywyyyy.w...",
        "....ywyyyyyw....",
        "...yywyyyywo....",
        "...yyyyyywyo....",
        "...yyyyywyoo....",
        "....yyywyoo.....",
        ".....owooo......",
        "....w...........",
        "...w............",
        "................",
    ],
    # Insting Pemburu: mata pemburu
    "pemburu": [
        "................",
        "................",
        "................",
        "................",
        ".....wwwwww.....",
        "...wwwggggwww...",
        "..wwwggwgggww...",
        ".wwwggGKKGggww..",
        ".wwwggGKKGggwww.",
        "..wwwggGGggwww..",
        "...wwwggggwww...",
        ".....wwwwww.....",
        "................",
        "................",
        "................",
        "................",
    ],
    # Darah Bulan: bulan sabit merah dengan tetes darah
    "darah": [
        "................",
        "......rrrr......",
        "....rrrpR.......",
        "...rrpR.........",
        "..rrpR..........",
        "..rpR......p....",
        ".rrpR.....prr...",
        ".rrpR.....prr...",
        ".rrpR....prrrR..",
        ".rrrR....rrrrR..",
        "..rrrR....rrR...",
        "..rrrrR.........",
        "...rrrrRR.......",
        ".....rrrrrr.....",
        "................",
        "................",
    ],
    # Kulit Bayangan: perisai bayangan
    "bayang": [
        "................",
        "..vvvvvvvvvvvv..",
        "..vVVVVVVVVVVv..",
        "..vVmmmmmmmmVv..",
        "..vVmvmmmmmmVv..",
        "..vVmvmmmmmmVv..",
        "..vVmvmmmmmmVv..",
        "..vVmmmmmmmmVv..",
        "..vVmmmmmmmmVv..",
        "...vVmmmmmmVv...",
        "...vVmmmmmmVv...",
        "....vVmmmmVv....",
        ".....vVmmVv.....",
        "......vVVv......",
        ".......vv.......",
        "................",
    ],
    # Pamungkas Surya: matahari bersinar
    "surya": [
        ".......o........",
        ".......y........",
        "..o.........o...",
        "...y..ooo..y....",
        ".....oyyyo......",
        "....oyywyyo.....",
        "....oywwyyo.....",
        "oy..oyyyyyo..yo.",
        "....oyyyyyo.....",
        ".....oyyyo......",
        "...y..ooo..y....",
        "..o.........o...",
        "................",
        ".......y........",
        ".......o........",
        "................",
    ],
    # Sinar Terakhir: bintang cahaya terakhir
    "sinar": [
        ".......w........",
        ".......w........",
        ".......y........",
        "......ywy.......",
        "......ywy.......",
        ".....yywyy......",
        "..o.yywwwyy.o...",
        "wwyyywwwwwyyyww.",
        "..o.yywwwyy.o...",
        ".....yywyy......",
        "......ywy.......",
        "......ywy.......",
        ".......y........",
        ".......w........",
        ".......w........",
        "................",
    ],
}


def icon(name, rows):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), name
    c = Canvas(16, 16)
    filled = set()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                c.set(x, y, PALETTE[ch])
                filled.add((x, y))
    for (x, y) in dilate(filled) - filled:
        c.set(x, y, INK)
    c.save("icons", name + ".png")


# ------------------------------------------------------------------ main

if __name__ == "__main__":
    os.makedirs(ICON_OUT, exist_ok=True)
    portrait()
    bar("hp", 168, 16, seed=3)
    bar("light", 132, 11, seed=5)
    bar("dash", 104, 6)
    bar("xp", 104, 5, border=False)
    level_chip()
    card_panel()
    card_glow()
    icon_frame()
    icon_frame(18, "slot_frame")
    pips()
    menu_panel()
    menu_buttons()
    slider_parts()
    pause_button()
    boss_bar()
    boss_tick()
    boss_crest()
    for name, rows in ICONS.items():
        icon(name, rows)
    print("ok ->", OUT)
