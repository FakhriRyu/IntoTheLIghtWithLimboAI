class_name TowerLevel
extends Node2D
## Level menara procedural: memanjat dari saluran bawah tanah (Sewer) ke
## kastil (Castle) lewat banyak platform. Saat dimuat: generate layout, lukis
## tile (autotile), lalu tempatkan player, pintu keluar, musuh, dan dekorasi.

## 0 = acak setiap dimuat. Isi angka tetap untuk mengulang menara yang sama saat debugging.
@export var seed_value: int = 0

## Musuh yang boleh muncul (hanya Goblin dan SkullWolf)
@export var enemy_scenes: Array[PackedScene] = [
	preload("res://Scenes/Enemy/goblin/goblin.tscn"),
	preload("res://Scenes/Enemy/SkullWolf/skull_wolf.tscn"),
]
## Musuh per lantai istirahat (min, max)
@export var enemies_per_landing_min: int = 2
@export var enemies_per_landing_max: int = 4
## Peluang platform panjang (>= 5 tile) berisi satu musuh
@export_range(0.0, 1.0) var platform_enemy_chance: float = 0.2
## Jarak minimal (tile) musuh dari titik spawn, supaya player tidak langsung diserbu
@export var min_enemy_distance: int = 10

## Kepadatan dekorasi (tanpa collision)
@export_range(0.0, 1.0) var prop_chance: float = 0.12
@export_range(0.0, 1.0) var chain_chance: float = 0.05
@export_range(0.0, 1.0) var drip_chance: float = 0.06
@export_range(0.0, 1.0) var window_chance: float = 0.5

## Warna suasana: makin tinggi makin terang ("menuju cahaya")
@export var bottom_tint: Color = Color(0.11, 0.14, 0.14)
@export var top_tint: Color = Color(0.5, 0.5, 0.46)

## Peti harta yang bisa dibuka di lantai istirahat
@export var chest_scene: PackedScene = preload("res://Scenes/Items/chest.tscn")

@export var exit_scene: PackedScene = preload("res://Scenes/levels/cave_exit.tscn")
## Scene setelah menara ini. Kosong = generate menara baru.
@export_file("*.tscn") var next_scene: String = "res://Scenes/levels/zone_two.tscn"

const TILE := 32
const ONE_WAY_LAYER := 5

const SRC_CASTLE := 0
const SRC_SEWER := 1
const SRC_EXTRA := 2
const TERRAIN_CASTLE_WALL := 0
const TERRAIN_SEWER_WALL := 1

## Background polos (sumber Castle/Sewer)
const CASTLE_BG: Array[Vector2i] = [Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11), Vector2i(6, 7), Vector2i(7, 7)]
const SEWER_BG: Array[Vector2i] = [Vector2i(1, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(0, 11), Vector2i(1, 11), Vector2i(4, 11), Vector2i(5, 11)]
## Jendela/lubang dinding 4x4 (pojok kiri atas di atlas), sama untuk kedua tema
const WINDOW_ORIGIN := Vector2i(1, 7)
## Papan/jembatan baris 8: ujung kiri, dekat kiri, tengah A/B, dekat kanan, ujung kanan
const PLANK_ROW := 8
## Penyangga di bawah ujung papan yang menempel dinding (baris 9)
const BRACE_LEFT := Vector2i(6, 9)
const BRACE_RIGHT := Vector2i(11, 9)

## Dekor besar (skala tile dinding)
const CHAIN_TOP := Vector2i(12, 4)          # Castle, 4 tile ke bawah
const WEB_TOP_LEFT := Vector2i(12, 8)       # Castle, 2x2
const WEB_TOP_RIGHT := Vector2i(14, 8)      # Castle, 2x2
const SLIME_A := Vector2i(12, 6)            # Sewer, 2x2 menggantung
const SLIME_B := Vector2i(14, 6)
const PIPE_TOP := Vector2i(6, 0)            # Sewer, pipa tegak 2x8
const GRATE := Vector2i(8, 10)              # Sewer, teralis bulat 2x2
const DOOR_WOOD := Vector2i(2, 0)           # Extra, 2x2
const DOOR_GRATE := Vector2i(4, 0)          # Extra, 2x2
const ARROW_UP := Vector2i(2, 2)            # Extra, 2x2

## Properti kecil (skala asli 16px). [sumber, pojok atlas, ukuran dalam tile 16px]
const CASTLE_PROPS: Array = [
	[SRC_CASTLE, Vector2i(8, 4), Vector2i(2, 2)],     # tumpukan tong
	[SRC_CASTLE, Vector2i(8, 6), Vector2i(2, 2)],     # tong besar
	[SRC_CASTLE, Vector2i(10, 5), Vector2i(2, 1)],    # tong kecil
	[SRC_CASTLE, Vector2i(10, 7), Vector2i(2, 1)],    # guci
	[SRC_CASTLE, Vector2i(0, 12), Vector2i(2, 2)],    # peti kayu pendek
	[SRC_CASTLE, Vector2i(2, 12), Vector2i(2, 2)],    # peti kayu tinggi
	[SRC_CASTLE, Vector2i(14, 2), Vector2i(2, 2)],    # tumpukan tengkorak
	[SRC_CASTLE, Vector2i(14, 11), Vector2i(2, 1)],   # tengkorak
	[SRC_CASTLE, Vector2i(10, 2), Vector2i(2, 2)],    # pedang tertancap
	[SRC_EXTRA, Vector2i(0, 1), Vector2i(1, 1)],      # tengkorak kecil
	[SRC_EXTRA, Vector2i(1, 1), Vector2i(1, 1)],      # tulang
]
const SEWER_PROPS: Array = [
	[SRC_SEWER, Vector2i(8, 1), Vector2i(1, 1)],      # lumut
	[SRC_SEWER, Vector2i(10, 1), Vector2i(1, 1)],
	[SRC_SEWER, Vector2i(8, 3), Vector2i(1, 1)],
	[SRC_SEWER, Vector2i(10, 3), Vector2i(1, 1)],
	[SRC_SEWER, Vector2i(8, 5), Vector2i(1, 1)],
	[SRC_SEWER, Vector2i(10, 5), Vector2i(1, 1)],
	[SRC_SEWER, Vector2i(8, 7), Vector2i(1, 1)],
	[SRC_SEWER, Vector2i(10, 7), Vector2i(1, 1)],
	[SRC_EXTRA, Vector2i(0, 1), Vector2i(1, 1)],      # tengkorak kecil
	[SRC_EXTRA, Vector2i(1, 1), Vector2i(1, 1)],      # tulang
	[SRC_CASTLE, Vector2i(0, 12), Vector2i(2, 2)],    # peti kayu hanyut
]

@onready var back_layer: TileMapLayer = $tilemaps/BackTiles
@onready var decor_layer: TileMapLayer = $tilemaps/Decor
@onready var wall_layer: TileMapLayer = $tilemaps/Walls
@onready var platform_layer: TileMapLayer = $tilemaps/Platforms
@onready var prop_layer: TileMapLayer = $Props
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var enemies: Node2D = $Enemies
@onready var background: ColorRect = $Background
@onready var tint: CanvasModulate = $CanvasModulate

var generator: TowerGenerator
var result: Dictionary
var used_seed: int = 0
var _sewer_top: int = 0
## Cell yang tidak boleh diberi properti (spawn, exit)
var _keep_clear := {}


func _ready() -> void:
	used_seed = seed_value
	if used_seed == 0:
		randomize()
		used_seed = randi_range(1, 2147483646)

	var t0: int = Time.get_ticks_msec()
	generator = TowerGenerator.new()
	result = generator.generate(used_seed)
	if result.get("failed", false):
		push_warning("TowerLevel: menara seed %d tidak lolos validasi" % used_seed)
	_sewer_top = result["sewer_top_row"]

	var rng := RandomNumberGenerator.new()
	rng.seed = used_seed
	var fallback: int = _paint_walls(rng)
	_paint_platforms()
	_paint_background(rng)

	_place_player()
	_place_exit()
	var enemy_count: int = _place_enemies(rng)
	_place_decor(rng)
	_setup_view()

	print("[TowerLevel] seed %d | %d ms | %d percobaan | %d platform | %d musuh | tile tak cocok %d" % [
		used_seed, Time.get_ticks_msec() - t0, result.get("attempts", 0),
		result["features"].size(), enemy_count, fallback])


func _process(_delta: float) -> void:
	# makin tinggi makin terang
	var h: float = float(generator.height * TILE)
	var t: float = clampf(1.0 - player.global_position.y / h, 0.0, 1.0)
	tint.color = bottom_tint.lerp(top_tint, smoothstep(0.0, 1.0, t))


# ---------------------------------------------------------------- konversi

func is_sewer(y: int) -> bool:
	return y >= _sewer_top


func cell_to_floor_pos(cell: Vector2i) -> Vector2:
	"""Titik di permukaan lantai, tepat di tengah cell tempat berdiri."""
	return Vector2(cell.x * TILE + TILE * 0.5, (cell.y + 1) * TILE)


## Jarak dari titik asal node ke dasar collision badannya. Dihitung dari shape
## yang sebenarnya (termasuk rotasinya), karena tiap musuh berbeda-beda.
func _feet_offset(body: Node) -> float:
	for c in body.get_children():
		if c is CollisionShape2D and c.shape != null and not c.disabled:
			var r: Rect2 = c.shape.get_rect()
			var xf: Transform2D = c.transform
			var bottom: float = -INF
			for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				bottom = maxf(bottom, (xf * p).y)
			return bottom
	return 0.0


# ---------------------------------------------------------------- tile

## Dinding dilukis per tema; mask dihitung dari seluruh peta, jadi sambungan
## antara Sewer dan Castle tetap rapi.
func _paint_walls(rng: RandomNumberGenerator) -> int:
	var ts: TileSet = wall_layer.tile_set
	var castle := CaveTiler.new(ts, SRC_CASTLE, TERRAIN_CASTLE_WALL)
	var sewer := CaveTiler.new(ts, SRC_SEWER, TERRAIN_SEWER_WALL)
	var n: int = castle.paint(wall_layer, generator, rng, 10, -1000000, _sewer_top, true)
	n += sewer.paint(wall_layer, generator, rng, 10, _sewer_top, 1000000, false)
	return n


## Papan one-way: ujung kiri, potongan dekat ujung, tengah selang-seling, ujung kanan.
func _paint_platforms() -> void:
	platform_layer.clear()
	for r: Rect2i in result["planks"]:
		var y: int = r.position.y
		var src: int = SRC_SEWER if is_sewer(y) else SRC_CASTLE
		var n: int = r.size.x
		for i in range(n):
			var ax: int
			if i == 0:
				ax = 6
			elif i == n - 1:
				ax = 11
			elif i == 1:
				ax = 7
			elif i == n - 2:
				ax = 10
			else:
				ax = 8 + (i % 2)
			platform_layer.set_cell(Vector2i(r.position.x + i, y), src, Vector2i(ax, PLANK_ROW))


func _paint_background(rng: RandomNumberGenerator) -> void:
	back_layer.clear()
	var g := generator
	var pad: int = 6
	for y in range(-pad, g.height + pad):
		var sewer: bool = is_sewer(y)
		var pool: Array[Vector2i] = SEWER_BG if sewer else CASTLE_BG
		var src: int = SRC_SEWER if sewer else SRC_CASTLE
		for x in range(-pad, g.width + pad):
			if g.is_solid(x, y):
				continue        # tile dinding buram, background tidak terlihat
			back_layer.set_cell(Vector2i(x, y), src, pool[rng.randi_range(0, pool.size() - 1)])

	# jendela / lubang dinding: tiap ±10 baris, di area terbuka
	var y0: int = 5
	while y0 < g.height - 8:
		if rng.randf() < window_chance:
			for attempt in range(8):
				var x0: int = rng.randi_range(g.inner_left(y0), g.inner_right(y0) - 3)
				if _area_open(x0, y0, 4, 4):
					var src: int = SRC_SEWER if is_sewer(y0) else SRC_CASTLE
					_stamp(back_layer, src, WINDOW_ORIGIN, Vector2i(4, 4), Vector2i(x0, y0))
					break
		y0 += rng.randi_range(8, 13)

	# Sewer: pipa tegak dan teralis di dinding belakang
	for attempt in range(14):
		var y: int = rng.randi_range(_sewer_top, g.height - 12)
		var x: int = rng.randi_range(g.inner_left(y), g.inner_right(y) - 1)
		if rng.randf() < 0.5:
			if _area_open(x, y, 2, 8):
				_stamp(back_layer, SRC_SEWER, PIPE_TOP, Vector2i(2, 8), Vector2i(x, y))
		elif _area_open(x, y, 2, 2):
			_stamp(back_layer, SRC_SEWER, GRATE, Vector2i(2, 2), Vector2i(x, y))


## Semua cell kosong (bukan batu dan bukan papan)
func _area_open(x0: int, y0: int, w: int, h: int) -> bool:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if generator.cell_at(x, y) != CaveGenerator.EMPTY:
				return false
	return true


func _stamp(layer: TileMapLayer, src: int, atlas_origin: Vector2i, size: Vector2i, at: Vector2i) -> void:
	for y in range(size.y):
		for x in range(size.x):
			layer.set_cell(at + Vector2i(x, y), src, atlas_origin + Vector2i(x, y))


# ---------------------------------------------------------------- penempatan

func _place_player() -> void:
	var cell: Vector2i = result["spawn_cell"]
	var pos: Vector2 = cell_to_floor_pos(cell) - Vector2(0, _feet_offset(player) + 1.0)
	player.global_position = pos
	# Wajib: player menyimpan spawn_position saat _ready(), yang terjadi SEBELUM
	# menara dibangun. Tanpa ini, respawn melempar player ke posisi lama.
	if "spawn_position" in player:
		player.spawn_position = pos
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	# pintu masuk di belakang player + panah "naik"
	_stamp(decor_layer, SRC_EXTRA, DOOR_WOOD, Vector2i(2, 2), cell + Vector2i(0, -1))
	var arrow_x: int = cell.x + 3 if cell.x < generator.width / 2 else cell.x - 4
	_stamp(decor_layer, SRC_EXTRA, ARROW_UP, Vector2i(2, 2), Vector2i(arrow_x, cell.y - 2))
	for dx in range(-2, 4):
		_keep_clear[cell + Vector2i(dx, 0)] = true


func _place_exit() -> void:
	var cell: Vector2i = result["exit_cell"]
	_stamp(decor_layer, SRC_EXTRA, DOOR_GRATE, Vector2i(2, 2), cell + Vector2i(0, -1))
	var exit_node: Node2D = exit_scene.instantiate()
	exit_node.position = cell_to_floor_pos(cell) + Vector2(TILE * 0.5, 0)
	if "next_scene" in exit_node:
		exit_node.next_scene = next_scene
	add_child(exit_node)
	for dx in range(-2, 4):
		_keep_clear[cell + Vector2i(dx, 0)] = true


func _place_enemies(rng: RandomNumberGenerator) -> int:
	var spawn: Vector2i = result["spawn_cell"]
	var exit_cell: Vector2i = result["exit_cell"]
	var reach: Dictionary = result["reachable"]
	var count: int = 0

	# Kelompok kandidat: tiap lantai istirahat, lalu tiap platform panjang
	var groups: Array = []
	for r: Rect2i in result["landings"]:
		if r.position.y - 1 == exit_cell.y:
			continue        # puncak: biarkan pintu keluar aman
		groups.append([_surface_cells(r, reach, spawn), rng.randi_range(enemies_per_landing_min, enemies_per_landing_max)])
	for f: Dictionary in result["features"]:
		var r: Rect2i = f["rect"]
		if f["kind"] != TowerGenerator.KIND_LANDING and r.size.x >= 5 and rng.randf() < platform_enemy_chance:
			groups.append([_surface_cells(r, reach, spawn), 1])

	for grp in groups:
		var cells: Array = grp[0]
		var want: int = grp[1]
		for i in range(want):
			if cells.is_empty():
				break
			var idx: int = rng.randi_range(0, cells.size() - 1)
			var cell: Vector2i = cells[idx]
			# boleh bergerombol, tapi jangan tepat bertumpuk di cell yang sama
			cells = cells.filter(func(c: Vector2i) -> bool: return absi(c.x - cell.x) > 1)
			var scene: PackedScene = enemy_scenes[rng.randi_range(0, enemy_scenes.size() - 1)]
			var enemy: Node2D = scene.instantiate()
			enemy.position = cell_to_floor_pos(cell) - Vector2(0, _feet_offset(enemy) + 1.0)
			if enemy is CollisionObject2D:
				# supaya bisa berdiri di papan one-way
				enemy.set_collision_mask_value(ONE_WAY_LAYER, true)
			enemies.add_child(enemy)
			count += 1
	return count


## Cell berdiri di atas sebuah fitur: rata 3 tile, terjangkau, ada ruang kepala,
## cukup jauh dari spawn.
func _surface_cells(r: Rect2i, reach: Dictionary, spawn: Vector2i) -> Array:
	var out: Array = []
	var y: int = r.position.y - 1
	for x in range(r.position.x + 1, r.end.x - 1):
		var c := Vector2i(x, y)
		if not reach.has(c) or not reach.has(c + Vector2i(-1, 0)) or not reach.has(c + Vector2i(1, 0)):
			continue
		if Vector2(c).distance_to(Vector2(spawn)) < min_enemy_distance:
			continue
		if not generator._col_clear(x, y - 1, y):
			continue
		out.append(c)
	return out


# ---------------------------------------------------------------- dekorasi

func _place_decor(rng: RandomNumberGenerator) -> void:
	prop_layer.clear()
	var g := generator
	for y in range(3, g.height - 3):
		var sewer: bool = is_sewer(y)
		for x in range(1, g.width - 1):
			if g.cell_at(x, y) != CaveGenerator.EMPTY:
				continue
			var cell := Vector2i(x, y)
			var ceiling: bool = g.is_solid(x, y - 1)

			# --- menggantung dari batu di atas
			if ceiling and decor_layer.get_cell_source_id(cell) == -1:
				if sewer:
					if g.is_solid(x + 1, y - 1) and _area_open(x, y, 2, 2) and rng.randf() < drip_chance:
						_stamp(decor_layer, SRC_SEWER, SLIME_A if rng.randf() < 0.5 else SLIME_B, Vector2i(2, 2), cell)
						continue
				else:
					# sarang laba-laba di pojok dinding + langit-langit
					if g.is_solid(x - 1, y) and _area_open(x, y, 2, 2) and rng.randf() < 0.35:
						_stamp(decor_layer, SRC_CASTLE, WEB_TOP_LEFT, Vector2i(2, 2), cell)
						continue
					if g.is_solid(x + 1, y) and _area_open(x - 1, y, 2, 2) and rng.randf() < 0.35:
						_stamp(decor_layer, SRC_CASTLE, WEB_TOP_RIGHT, Vector2i(2, 2), cell + Vector2i(-1, 0))
						continue
					if rng.randf() < chain_chance:
						var length: int = rng.randi_range(2, 4)
						if _area_open(x, y, 1, length + 1):
							for i in range(length):
								decor_layer.set_cell(cell + Vector2i(0, i), SRC_CASTLE, CHAIN_TOP + Vector2i(0, i))
						continue

			# --- properti di atas lantai (skala asli 16px); di papan lebih jarang
			var chance: float = prop_chance if g.is_solid(x, y + 1) else prop_chance * 0.5
			if g.is_standing(x, y) and not _keep_clear.has(cell) and rng.randf() < chance:
				var pool: Array = SEWER_PROPS if sewer else CASTLE_PROPS
				_put_prop(cell, pool[rng.randi_range(0, pool.size() - 1)], rng)

	# penyangga papan yang menempel dinding
	for r: Rect2i in result["planks"]:
		var src: int = SRC_SEWER if is_sewer(r.position.y) else SRC_CASTLE
		var below := Vector2i(0, 1)
		if g.is_solid(r.position.x - 1, r.position.y) and g.cell_at(r.position.x, r.end.y) == CaveGenerator.EMPTY:
			decor_layer.set_cell(r.position + below, src, BRACE_LEFT)
		var right := Vector2i(r.end.x - 1, r.position.y)
		if g.is_solid(right.x + 1, right.y) and g.cell_at(right.x, r.end.y) == CaveGenerator.EMPTY:
			decor_layer.set_cell(right + below, src, BRACE_RIGHT)

	# peti harta di beberapa lantai istirahat
	for r: Rect2i in result["landings"]:
		if rng.randf() > 0.35:
			continue
		var y: int = r.position.y - 1
		var x: int = rng.randi_range(maxi(r.position.x, g.inner_left(y)), mini(r.end.x - 1, g.inner_right(y)))
		var cell := Vector2i(x, y)
		if g.is_standing(x, y) and not _keep_clear.has(cell) and not _has_prop(cell):
			_place_chest(cell)


func _place_chest(cell: Vector2i) -> void:
	if chest_scene == null:
		return
	var chest: Node2D = chest_scene.instantiate()
	chest.position = cell_to_floor_pos(cell)
	add_child(chest)
	_keep_clear[cell] = true


## Properti kecil di layer Props (skala 1, grid 16px), menempel ke lantai cell.
func _put_prop(cell: Vector2i, prop: Array, rng: RandomNumberGenerator) -> void:
	var src: int = prop[0]
	var origin: Vector2i = prop[1]
	var size: Vector2i = prop[2]
	var sx: int = cell.x * 2
	if size.x == 1:
		sx += rng.randi_range(0, 1)
	var sy: int = cell.y * 2 + 2 - size.y      # rata bawah dengan lantai
	_stamp(prop_layer, src, origin, size, Vector2i(sx, sy))


func _has_prop(cell: Vector2i) -> bool:
	for y in range(2):
		for x in range(2):
			if prop_layer.get_cell_source_id(Vector2i(cell.x * 2 + x, cell.y * 2 + y)) != -1:
				return true
	return false


func _setup_view() -> void:
	var w: int = generator.width * TILE
	var h: int = generator.height * TILE
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = w
	camera.limit_bottom = h
	camera.reset_smoothing()

	var pad: int = 12 * TILE
	background.position = Vector2(-pad, -pad)
	background.size = Vector2(w + pad * 2, h + pad * 2)
	_process(0.0)
