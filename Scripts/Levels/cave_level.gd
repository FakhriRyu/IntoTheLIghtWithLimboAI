class_name CaveLevel
extends Node2D
## Level gua procedural. Saat dimuat: generate layout, lukis tile, lalu
## tempatkan player, pintu keluar, musuh, dan dekorasi.

## 0 = acak setiap dimuat. Isi angka tetap untuk mengulang gua yang sama saat debugging.
@export var seed_value: int = 0

## Musuh yang boleh muncul (hanya Goblin dan SkullWolf)
@export var enemy_scenes: Array[PackedScene] = [
	preload("res://Scenes/Enemy/goblin/goblin.tscn"),
	preload("res://Scenes/Enemy/SkullWolf/skull_wolf.tscn"),
]
## Peluang satu ruangan berisi musuh
@export_range(0.0, 1.0) var enemy_chance_per_room: float = 0.55
## Bobot ukuran gerombolan per ruangan: [1 musuh, 2 musuh, 3 musuh]
@export var group_size_weights: Array[float] = [0.5, 0.35, 0.15]
## Jarak minimal (tile) musuh dari titik spawn, supaya player tidak langsung diserbu
@export var min_enemy_distance: int = 14

## Kepadatan dekorasi (tanpa collision, digambar di belakang player)
@export_range(0.0, 1.0) var stalactite_chance: float = 0.08
@export_range(0.0, 1.0) var stalagmite_chance: float = 0.05
@export_range(0.0, 1.0) var rubble_chance: float = 0.06

## Cahaya player khusus di gua (tidak mengubah player.tscn, jadi level lain aman).
## Ruang gua lebar 16 tile; dengan radius bawaan, dinding seberang tidak terbaca.
@export var player_light_scale: float = 2.4
@export var player_light_energy: float = 1.7

## Peti harta di gua samping (ruang di luar jalur utama): hadiah untuk menjelajah
@export var chest_scene: PackedScene = preload("res://Scenes/Items/chest.tscn")
@export_range(0.0, 1.0) var chest_chance_per_side_room: float = 0.6

## Duri di lantai rata (semua kesulitan)
@export var spike_scene: PackedScene = preload("res://Scenes/Items/spikes.tscn")
@export_range(0.0, 1.0) var spike_chance_per_room: float = 0.3

@export var exit_scene: PackedScene = preload("res://Scenes/levels/cave_exit.tscn")
## Scene setelah gua ini. Kosong = generate gua baru.
@export_file("*.tscn") var next_scene: String = ""

const TILE := 32
const STALACTITE_TOP := Vector2i(23, 13)
const STALACTITE_BOTTOM := Vector2i(23, 14)
const RUBBLE: Array[Vector2i] = [Vector2i(0, 4), Vector2i(2, 4), Vector2i(0, 10), Vector2i(2, 10)]

@onready var rock_layer: TileMapLayer = $tilemaps/Rock
@onready var decor_layer: TileMapLayer = $tilemaps/Decor
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var enemies: Node2D = $Enemies
@onready var background: ColorRect = $Background

var generator: CaveGenerator
var result: Dictionary
var used_seed: int = 0
## Cell berduri (dan tetangganya): musuh dan peti tidak ditaruh di sini
var _hazard := {}


func _ready() -> void:
	used_seed = seed_value
	if used_seed == 0:
		randomize()
		used_seed = randi_range(1, 2147483646)

	var t0: int = Time.get_ticks_msec()
	generator = CaveGenerator.new()
	result = generator.generate(used_seed)
	if result.get("failed", false):
		push_warning("CaveLevel: gua seed %d tidak lolos validasi" % used_seed)

	var rng := RandomNumberGenerator.new()
	rng.seed = used_seed
	var tiler := CaveTiler.new(rock_layer.tile_set)
	var fallback: int = tiler.paint(rock_layer, generator, rng)

	_place_player()
	_place_exit()
	var spike_count: int = _place_spikes(rng)
	var enemy_count: int = _place_enemies(rng)
	var chest_count: int = _place_chests(rng)
	_place_decor(rng)
	_setup_view()

	print("[CaveLevel] seed %d | %d ms | %d ruang di jalur | %d musuh | %d peti | %d duri | tile tak cocok %d" % [
		used_seed, Time.get_ticks_msec() - t0, result["path"].size(), enemy_count, chest_count, spike_count, fallback])


# ---------------------------------------------------------------- konversi

func cell_to_floor_pos(cell: Vector2i) -> Vector2:
	"""Titik di permukaan lantai, tepat di tengah cell tempat berdiri."""
	return Vector2(cell.x * TILE + TILE * 0.5, (cell.y + 1) * TILE)


## Jarak dari titik asal node ke dasar collision badannya. Dihitung dari shape
## yang sebenarnya (termasuk rotasinya), karena tiap musuh berbeda-beda.
## Bisa negatif: collision SkullWolf berada DI ATAS titik asalnya.
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


# ---------------------------------------------------------------- penempatan

func _place_player() -> void:
	var pos: Vector2 = cell_to_floor_pos(result["spawn_cell"]) - Vector2(0, _feet_offset(player) + 1.0)
	player.global_position = pos
	# Wajib: player menyimpan spawn_position saat _ready(), yang terjadi SEBELUM
	# gua dibangun. Tanpa ini, respawn melempar player ke posisi lama di dalam batu.
	if "spawn_position" in player:
		player.spawn_position = pos
	if "velocity" in player:
		player.velocity = Vector2.ZERO


func _place_exit() -> void:
	var exit_node: Node2D = exit_scene.instantiate()
	exit_node.position = cell_to_floor_pos(result["exit_cell"])
	if "next_scene" in exit_node:
		exit_node.next_scene = next_scene
	add_child(exit_node)


func _place_enemies(rng: RandomNumberGenerator) -> int:
	var spawn: Vector2i = result["spawn_cell"]
	var protected: Dictionary = result["protected"]
	var reach: Dictionary = result["reachable"]

	# kandidat: lantai rata 3 tile, terjangkau, cukup jauh dari spawn
	var by_room := {}
	for c in reach.keys():
		var cell: Vector2i = c
		if protected.has(cell) or _hazard.has(cell):
			continue
		if Vector2(cell).distance_to(Vector2(spawn)) < min_enemy_distance:
			continue
		if not (reach.has(cell + Vector2i(-1, 0)) and reach.has(cell + Vector2i(1, 0))):
			continue
		if not generator._col_clear(cell.x, cell.y - 2, cell.y):
			continue
		var room := Vector2i(cell.x / CaveGenerator.ROOM_W, cell.y / CaveGenerator.ROOM_H)
		if not by_room.has(room):
			by_room[room] = []
		by_room[room].append(cell)

	var count: int = 0
	var rooms: Array = by_room.keys()
	rooms.sort()       # urutan stabil supaya hasil per seed deterministik
	for room in rooms:
		if rng.randf() > enemy_chance_per_room:
			continue
		var cells: Array = by_room[room]
		cells.sort()
		for i in range(_roll_group_size(rng)):
			if cells.is_empty():
				break
			var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			# gerombolan: berdekatan, tapi tidak di cell yang sama
			cells = cells.filter(func(c: Vector2i) -> bool: return c.y != cell.y or absi(c.x - cell.x) > 1)
			var scene: PackedScene = enemy_scenes[rng.randi_range(0, enemy_scenes.size() - 1)]
			var enemy: Node2D = scene.instantiate()
			enemy.position = cell_to_floor_pos(cell) - Vector2(0, _feet_offset(enemy) + 1.0)
			enemies.add_child(enemy)
			count += 1
	return count


## Duri 1-2 tile di lantai rata, dengan >= 2 tile aman di kedua sisi dan ruang
## kepala cukup untuk melompatinya. Tidak di cell tangga (protected).
func _place_spikes(rng: RandomNumberGenerator) -> int:
	if spike_scene == null:
		return 0
	var g := generator
	var spawn: Vector2i = result["spawn_cell"]
	var exit_cell: Vector2i = result["exit_cell"]
	var protected: Dictionary = result["protected"]
	var reach: Dictionary = result["reachable"]

	var by_room := {}
	for c in reach.keys():
		var cell: Vector2i = c
		var room := Vector2i(cell.x / CaveGenerator.ROOM_W, cell.y / CaveGenerator.ROOM_H)
		if not by_room.has(room):
			by_room[room] = []
		by_room[room].append(cell)

	var count: int = 0
	var rooms: Array = by_room.keys()
	rooms.sort()       # urutan stabil supaya hasil per seed deterministik
	for room in rooms:
		if rng.randf() > spike_chance_per_room:
			continue
		var cells: Array = by_room[room]
		cells.sort()
		var n: int = rng.randi_range(1, 2)
		var options: Array = cells.filter(func(c: Vector2i) -> bool:
			return _spike_fits(c, n, spawn, exit_cell, protected, reach))
		if options.is_empty():
			continue
		var cell: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		var spike := spike_scene.instantiate() as Spikes
		spike.width_tiles = n
		spike.position = Vector2((cell.x + n * 0.5) * TILE, (cell.y + 1) * TILE)
		add_child(spike)
		for x in range(cell.x - 1, cell.x + n + 1):
			_hazard[Vector2i(x, cell.y)] = true
		count += 1
	return count


func _spike_fits(c: Vector2i, n: int, spawn: Vector2i, exit_cell: Vector2i,
		protected: Dictionary, reach: Dictionary) -> bool:
	if Vector2(c).distance_to(Vector2(spawn)) < 8.0 or Vector2(c).distance_to(Vector2(exit_cell)) < 6.0:
		return false
	for x in range(c.x - 2, c.x + n + 2):
		var o := Vector2i(x, c.y)
		if not reach.has(o) or protected.has(o) or not generator.is_standing(x, c.y):
			return false
		if not generator._col_clear(x, c.y - 3, c.y):
			return false
	return true


func _roll_group_size(rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for w in group_size_weights:
		total += w
	var roll: float = rng.randf() * total
	for i in range(group_size_weights.size()):
		roll -= group_size_weights[i]
		if roll <= 0.0:
			return i + 1
	return 1


## Satu peti per gua samping (peluang chest_chance_per_side_room), di lantai
## yang terjangkau dan punya ruang kepala.
func _place_chests(rng: RandomNumberGenerator) -> int:
	if chest_scene == null:
		return 0
	var reach: Dictionary = result["reachable"]
	var protected: Dictionary = result["protected"]
	var rooms: Dictionary = result["rooms"]
	var keys: Array = rooms.keys()
	keys.sort()       # urutan stabil supaya hasil per seed deterministik
	var count: int = 0
	for key in keys:
		var info: Dictionary = rooms[key]
		if info.get("on_path", true) or rng.randf() > chest_chance_per_side_room:
			continue
		var r: Rect2i = info["interior"]
		var cells: Array = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if reach.has(c) and not protected.has(c) and not _hazard.has(c) and generator.is_standing(x, y) \
						and generator._col_clear(x, y - 1, y):
					cells.append(c)
		if cells.is_empty():
			continue
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var chest: Node2D = chest_scene.instantiate()
		chest.position = cell_to_floor_pos(cell)
		add_child(chest)
		count += 1
	return count


func _place_decor(rng: RandomNumberGenerator) -> void:
	decor_layer.clear()
	var protected: Dictionary = result["protected"]
	var g := generator
	for y in range(1, g.height - 4):
		for x in range(1, g.width - 1):
			if g.is_solid(x, y) or protected.has(Vector2i(x, y)) or _hazard.has(Vector2i(x, y)):
				continue
			# stalaktit: menggantung dari langit-langit, dengan ruang kosong di bawahnya
			if g.is_solid(x, y - 1) and g._col_clear(x, y, y + 3) and rng.randf() < stalactite_chance:
				decor_layer.set_cell(Vector2i(x, y), 0, STALACTITE_TOP)
				decor_layer.set_cell(Vector2i(x, y + 1), 0, STALACTITE_BOTTOM)
				continue
			# di atas lantai
			if g.is_standing(x, y) and g._col_clear(x, y - 3, y):
				var roll: float = rng.randf()
				if roll < stalagmite_chance:
					# versi terbalik (alternatif 1 = flip vertikal)
					decor_layer.set_cell(Vector2i(x, y), 0, STALACTITE_TOP, 1)
					decor_layer.set_cell(Vector2i(x, y - 1), 0, STALACTITE_BOTTOM, 1)
				elif roll < stalagmite_chance + rubble_chance:
					decor_layer.set_cell(Vector2i(x, y), 0, RUBBLE[rng.randi_range(0, RUBBLE.size() - 1)])


func _setup_view() -> void:
	# Isi nilai DASAR cahaya, bukan nilai langsung: script cahaya player
	# mengecilkan radius dari dasar ini sesuai sisa cahaya.
	var light := player.get_node_or_null("Light") as PointLight2D
	if light != null:
		if "base_scale" in light:
			light.base_scale = player_light_scale
			light.base_energy = player_light_energy
		else:
			light.texture_scale = player_light_scale
			light.energy = player_light_energy

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
