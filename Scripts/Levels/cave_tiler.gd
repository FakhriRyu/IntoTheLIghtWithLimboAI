class_name CaveTiler
extends RefCounted
## Melukis grid gua ke TileMapLayer memakai skema 13-tile milik CaveG.png
## (1 isian + 4 tepi + 4 pojok luar + 4 pojok dalam).
##
## Mask dihitung sendiri lalu dicocokkan ke data peering di TileSet, bukan lewat
## set_cells_terrain_connect(): lebih cepat untuk ribuan cell, deterministik per
## seed, dan bisa melaporkan cell yang tidak punya tile yang cocok.

const _BITS := [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
]

## mask -> Array of [atlas_coords, bobot]
var _lookup := {}
var _source_id: int = 0


## terrain: terrain di terrain set 0 yang dipakai (gua = 0; tower punya beberapa)
func _init(tile_set: TileSet, source_id: int = 0, terrain: int = 0) -> void:
	_source_id = source_id
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	for i in src.get_tiles_count():
		var ac: Vector2i = src.get_tile_id(i)
		var td: TileData = src.get_tile_data(ac, 0)
		if td.terrain_set != 0 or td.terrain != terrain:
			continue
		var m: int = 0
		for b in 8:
			if td.get_terrain_peering_bit(_BITS[b]) == terrain:
				m |= 1 << b
		if not _lookup.has(m):
			_lookup[m] = []
		_lookup[m].append([ac, maxf(td.probability, 0.001)])


## Melukis semua cell padat, ditambah bantalan di luar peta supaya tepi peta
## tidak tampil sebagai dinding tipis. Mengembalikan jumlah cell yang terpaksa
## memakai tile terdekat karena polanya tidak ada (idealnya 0).
## row_from/row_to membatasi baris yang dilukis (untuk peta dengan beberapa tema);
## mask tetap dihitung dari seluruh peta, jadi sambungan antar tema tidak putus.
func paint(layer: TileMapLayer, gen: CaveGenerator, rng: RandomNumberGenerator, padding: int = 10,
		row_from: int = -1000000, row_to: int = 1000000, clear: bool = true) -> int:
	if clear:
		layer.clear()
	var fallback: int = 0
	for y in range(maxi(-padding, row_from), mini(gen.height + padding, row_to)):
		for x in range(-padding, gen.width + padding):
			if not gen.is_solid(x, y):
				continue
			var m: int = mask_at(gen, x, y)
			var choices: Array = _lookup.get(m, [])
			if choices.is_empty():
				fallback += 1
				choices = _lookup[_nearest_mask(m)]
			layer.set_cell(Vector2i(x, y), _source_id, _pick(choices, rng))
	return fallback


## Mask 8-tetangga. Bit pojok hanya dihitung kalau kedua sisi yang mengapitnya
## juga padat - aturan mode MATCH_CORNERS_AND_SIDES di Godot.
static func mask_at(gen: CaveGenerator, x: int, y: int) -> int:
	var r: bool = gen.is_solid(x + 1, y)
	var b: bool = gen.is_solid(x, y + 1)
	var l: bool = gen.is_solid(x - 1, y)
	var t: bool = gen.is_solid(x, y - 1)
	var m: int = 0
	if r: m |= 1
	if r and b and gen.is_solid(x + 1, y + 1): m |= 2
	if b: m |= 4
	if b and l and gen.is_solid(x - 1, y + 1): m |= 8
	if l: m |= 16
	if l and t and gen.is_solid(x - 1, y - 1): m |= 32
	if t: m |= 64
	if t and r and gen.is_solid(x + 1, y - 1): m |= 128
	return m


func _nearest_mask(m: int) -> int:
	var best: int = 255
	var best_d: int = 99
	for k in _lookup.keys():
		var x: int = m ^ int(k)
		var d: int = 0
		while x:
			d += x & 1
			x >>= 1
		if d < best_d:
			best_d = d
			best = k
	return best


func _pick(choices: Array, rng: RandomNumberGenerator) -> Vector2i:
	var total: float = 0.0
	for c in choices:
		total += c[1]
	var roll: float = rng.randf() * total
	for c in choices:
		roll -= c[1]
		if roll <= 0.0:
			return c[0]
	return choices[choices.size() - 1][0]
