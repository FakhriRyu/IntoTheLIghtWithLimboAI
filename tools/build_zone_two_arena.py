#!/usr/bin/env python3
"""Membangun ulang tilemap arena bos Zone Two (puncak tower) di
Scenes/levels/zone_two.tscn memakai CastleTiles (tower_tile_set.tres).

Tata letak (tile 16 px, grid 54 x 30, arena 864 x 480 px):
  - dinding kastil kiri/kanan (kolom 0-1 dan 52-53) + merlon
  - lantai utama rata (baris 27-29), tanpa jurang
  - dais kiri/kanan +2 tile (32 px), di bawah batas langkah blink bos (40 px)
  - papan one-way A/B +5 tile (80 px), papan C +8 tile (128 px)
    -> tiap tingkat 48 px, masih terjangkau lompatan Fiora (~57 px)
  - tembok belakang + merlon, jendela, pintu tangga, dekorasi

Jalankan dari root repo:  python3 tools/build_zone_two_arena.py
Node selain tilemap (Player, NorchThex, HUD, dst.) diambil dari scene lama
dan hanya posisinya yang disesuaikan.
"""
import base64
import re
import struct
from pathlib import Path

SCENE = Path(__file__).resolve().parent.parent / "Scenes/levels/zone_two.tscn"
T = 16
W, H = 54, 30

SOLID, ONEWAY = "#", "="


def build_grid():
    grid = [[" "] * W for _ in range(H)]

    def fill(c0, c1, r0, r1, ch):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                grid[r][c] = ch

    fill(0, 1, 8, 29, SOLID)       # dinding kiri
    fill(52, 53, 8, 29, SOLID)     # dinding kanan
    fill(2, 51, 27, 29, SOLID)     # lantai utama
    fill(2, 10, 25, 26, SOLID)     # dais kiri
    fill(43, 51, 25, 26, SOLID)    # dais kanan
    fill(12, 19, 22, 22, ONEWAY)   # papan A
    fill(34, 41, 22, 22, ONEWAY)   # papan B
    fill(22, 31, 19, 19, ONEWAY)   # papan C
    return grid


def wall_cells(grid):
    """9-slice blok batu berbingkai (atlas kolom 0-5, baris 0-5)."""
    def solid(r, c):
        return 0 <= r < H and 0 <= c < W and grid[r][c] == SOLID

    cells = {}
    for r in range(H):
        for c in range(W):
            if grid[r][c] != SOLID:
                continue
            up, dn = solid(r - 1, c), solid(r + 1, c)
            lf, rt = solid(r, c - 1), solid(r, c + 1)
            tx = 0 if not lf else (5 if not rt else (1 if c % 2 else 4))
            if not up:
                ty = 0
            elif not dn and r < H - 1:
                ty = 5
            else:
                ty = 1 if r % 2 else 4
            cells[(c, r)] = (tx, ty)
    return cells


def platform_cells(grid):
    """Papan kayu one-way (atlas baris 8, kolom 6-11)."""
    cells = {}
    for r in range(H):
        for c in range(W):
            if grid[r][c] != ONEWAY:
                continue
            lf = grid[r][c - 1] == ONEWAY
            rt = grid[r][c + 1] == ONEWAY
            cells[(c, r)] = (6 if not lf else (11 if not rt else 7 + (c % 4)), 8)
    return cells


def back_cells():
    """Tembok belakang (tanpa collision): bata gelap, merlon, jendela, pintu."""
    cells = {}
    for r in range(15, H):
        for c in range(W):
            cells[(c, r)] = (c % 6, 6 + (r % 2))
    for c in range(0, W, 3):          # merlon tembok belakang
        for r in (13, 14):
            for cc in (c, c + 1):
                if cc < W:
                    cells[(cc, r)] = (cc % 6, 6 + (r % 2))

    def frame(c0, r0):
        """Bingkai jendela 4x3 (atlas 1-4, 8-10). Bagian tengahnya kosong."""
        for dy in range(3):
            for dx in range(4):
                key = (c0 + dx, r0 + dy)
                ax, ay = 1 + dx, 8 + dy
                if ay in (8, 9) and ax in (2, 3):
                    cells.pop(key, None)    # lubang: langit / pintu gelap
                else:
                    cells[key] = (ax, ay)

    for wc in (15, 26, 37):
        frame(wc, 17)
    frame(4, 22)                      # pintu tangga (terkunci)
    return cells


def decor_cells():
    cells = {}

    def put(ax, ay, w, h, c0, r0):
        for dy in range(h):
            for dx in range(w):
                cells[(c0 + dx, r0 + dy)] = (ax + dx, ay + dy)

    for c0 in (0, 52):                # merlon di atas dinding samping
        put(6, 12, 2, 2, c0, 6)
    put(8, 4, 2, 2, 50, 23)           # tumpukan tong
    put(14, 2, 2, 2, 43, 23)          # tumpukan tengkorak
    put(0, 12, 2, 2, 2, 23)           # peti
    put(10, 1, 1, 3, 9, 22)           # papan & pedang
    put(14, 11, 2, 1, 25, 26)         # tengkorak di lantai
    for cc in (24, 29):               # rantai di bawah papan C
        put(12, 4, 1, 2, cc, 20)
    for c0, c1, r in ((12, 19, 22), (34, 41, 22), (22, 31, 19)):   # siku penyangga papan
        put(6, 9, 1, 1, c0, r + 1)
        put(11, 9, 1, 1, c1, r + 1)
    put(12, 8, 1, 2, 2, 15)           # sarang laba-laba
    put(15, 8, 1, 2, 51, 15)
    return cells


def encode(cells, source=0):
    data = bytearray(b"\x00\x00")
    for (x, y), (ax, ay) in sorted(cells.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        data += struct.pack("<hhHHHH", x, y, source, ax, ay, 0)
    return base64.b64encode(bytes(data)).decode()


def node_block(text, name):
    """Ambil satu blok [node name="name" ...] lengkap dari scene lama."""
    m = re.search(r'(\[node name="%s".*?)(?=\n\[node |\Z)' % re.escape(name), text, re.S)
    return m.group(1).rstrip() + "\n"


def main():
    old = SCENE.read_text()
    grid = build_grid()

    keep = {n: node_block(old, n) for n in (
        "PlayerHUD", "BossHealthBar", "CanvasModulate", "LevelMusic", "BossVictory")}

    out = f'''[gd_scene format=4 uid="uid://m76anex3axrv"]

[ext_resource type="TileSet" uid="uid://cw30wxhldnjkc" path="res://Scenes/levels/tower_tile_set.tres" id="tower_tiles"]
[ext_resource type="Texture2D" uid="uid://boivhrvw1kt7x" path="res://Assets/background/background_night1.png" id="sky_tex"]
[ext_resource type="PackedScene" uid="uid://6bwtmnfhpxbs" path="res://Scenes/player/player.tscn" id="3_dkyar"]
[ext_resource type="PackedScene" uid="uid://c7i4jb6ld3xn0" path="res://Scenes/Enemy/NorcThex/norch_thex.tscn" id="4_e6e8q"]
[ext_resource type="PackedScene" uid="uid://b7k3stab0ssr2" path="res://Scenes/UI/boss_health_bar.tscn" id="bossbar_1"]
[ext_resource type="Script" uid="uid://bkrwqd2obf1pw" path="res://Scripts/Levels/boss_victory.gd" id="boss_victory_1"]
[ext_resource type="PackedScene" path="res://Scenes/Items/light_brazier.tscn" id="brazier_1"]
[ext_resource type="PackedScene" uid="uid://c8h2ueapl4yr1" path="res://Scenes/UI/player_hud.tscn" id="hud_1"]
[ext_resource type="Script" uid="uid://dsh05m6pt605i" path="res://Scripts/Core/level_music.gd" id="level_music_1"]

[node name="zone_two" type="Node2D" unique_id=102063117]

[node name="Sky" type="Parallax2D" parent="." unique_id=1730550101]
z_index = -20
scroll_scale = Vector2(0.3, 1)
repeat_size = Vector2(640, 0)
repeat_times = 3

[node name="SkySprite" type="Sprite2D" parent="Sky" unique_id=1730550102]
position = Vector2(320, 240)
texture = ExtResource("sky_tex")

[node name="StairDoor" type="ColorRect" parent="." unique_id=1730550103]
z_index = -11
offset_left = {5 * T}.0
offset_top = {22 * T}.0
offset_right = {7 * T}.0
offset_bottom = {24 * T}.0
mouse_filter = 2
color = Color(0.03, 0.025, 0.04, 1)

[node name="tilemaps" type="Node2D" parent="." unique_id=405285063]

[node name="BackWall" type="TileMapLayer" parent="tilemaps" unique_id=1730550104]
modulate = Color(0.55, 0.55, 0.65, 1)
z_index = -10
tile_map_data = PackedByteArray("{encode(back_cells())}")
tile_set = ExtResource("tower_tiles")
collision_enabled = false

[node name="Decor" type="TileMapLayer" parent="tilemaps" unique_id=1730550105]
z_index = -5
tile_map_data = PackedByteArray("{encode(decor_cells())}")
tile_set = ExtResource("tower_tiles")
collision_enabled = false

[node name="Walls" type="TileMapLayer" parent="tilemaps" unique_id=1959004443]
tile_map_data = PackedByteArray("{encode(wall_cells(grid))}")
tile_set = ExtResource("tower_tiles")

[node name="Platforms" type="TileMapLayer" parent="tilemaps" unique_id=1586175817 groups=["one_way_platform"]]
tile_map_data = PackedByteArray("{encode(platform_cells(grid))}")
tile_set = ExtResource("tower_tiles")

[node name="Player" parent="." unique_id=1226008961 instance=ExtResource("3_dkyar")]
z_index = 5
position = Vector2(80, {25 * T - 16})

[node name="Camera2D" type="Camera2D" parent="Player" unique_id=1072977564]
limit_left = 0
limit_top = 0
limit_right = {W * T}
limit_bottom = {H * T}
position_smoothing_enabled = true
editor_draw_limits = true

[node name="NorchThex" parent="." unique_id=1163414465 instance=ExtResource("4_e6e8q")]
z_index = 6
position = Vector2(752, {25 * T - 41})

{keep["PlayerHUD"]}
{keep["BossHealthBar"]}
{keep["CanvasModulate"]}
[node name="LightBrazier" parent="." unique_id=937118767 instance=ExtResource("brazier_1")]
position = Vector2(128, {25 * T})

[node name="LightBrazier2" parent="." unique_id=856170534 instance=ExtResource("brazier_1")]
position = Vector2(432, {19 * T})

{keep["LevelMusic"]}
{keep["BossVictory"]}'''
    SCENE.write_text(out.rstrip() + "\n")
    print("ditulis:", SCENE)


if __name__ == "__main__":
    main()
