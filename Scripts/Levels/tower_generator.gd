class_name TowerGenerator
extends CaveGenerator
## Menara platformer vertikal: spawn di lantai bawah, pintu keluar di puncak.
##
## Bedanya dengan gua: bukan ruangan + lorong, melainkan SATU ruang lebar
## yang dipanjat lewat banyak platform. Cara kerjanya:
##   1. Dinding kiri/kanan setebal 2-4 tile (berubah per segmen), lantai & langit-langit.
##   2. LANTAI ISTIRAHAT tiap ±17 baris: tonjolan batu dari satu dinding selebar
##      50-70% ruang dalam, sisinya selang-seling kiri/kanan (zig-zag besar).
##   3. Di sisi celah tiap lantai istirahat dipasang platform TARGET yang pasti
##      bisa dipakai naik ke lantai itu.
##   4. RANTAI PLATFORM dari lantai bawah sampai ke target: tiap langkah naik
##      0-2 tile dengan celah yang masih bisa dilompati, arah zig-zag.
##   5. Platform BONUS acak di sela-sela supaya ruangan padat platform.
##   6. BFS dari CaveGenerator memverifikasi pintu keluar terjangkau; kalau gagal,
##      generate() mencoba lagi dengan seed turunan.
##
## Platform kayu/jembatan (PLATFORM) itu one-way: bisa ditembus dari bawah dan
## dari samping, jadi is_solid() = false tetapi bisa dipijak (is_standing()).
##
## Aturan jarak (supaya tidak ada kepala terbentur / platform menempel):
##   - 1 baris di atas permukaan setiap fitur wajib kosong (tempat berdiri), dan
##     3 baris di atasnya (plus 2 kolom tiap sisi) tidak boleh batu. Papan one-way
##     boleh di situ: player melompat menembusnya dari bawah (papan bertumpuk).
##   - Di bawah papan 1 baris kosong, di bawah batu 2 baris kosong.
##   - Fitur tidak boleh bersentuhan (8 arah), kecuali dengan dinding dan dengan
##     platform sebelumnya di rantai yang sama.
## Semua batu minimal 2x2, jadi skema tile 9-slice tidak butuh potongan tipis.
##
## Koordinat: y=0 di ATAS. "Naik" berarti y mengecil.

const PLATFORM := 2

const KIND_BLOCK := 0
const KIND_PLANK := 1
const KIND_LANDING := 2

const RES_SOFT := 1
const RES_HARD := 2

## Tebal dinding samping (tile)
var wall_min: int = 2
var wall_max: int = 4
## Jarak rata-rata antar lantai istirahat (baris)
var landing_spacing: float = 17.0
## Lebar lantai istirahat relatif terhadap ruang dalam
var landing_ratio_min: float = 0.5
var landing_ratio_max: float = 0.68
## Peluang langkah rantai berupa papan one-way (sisanya blok batu)
var plank_chance: float = 0.55
## Jumlah platform bonus per bagian (min, max)
var bonus_min: int = 3
var bonus_max: int = 6
## Bagian bawah peta yang bertema Sewer
var sewer_fraction: float = 0.4

## Tebal dinding per baris
var _wall_l := PackedInt32Array()
var _wall_r := PackedInt32Array()
## Pemilik tiap cell (indeks fitur), -1 = dinding/kosong
var _owner := PackedInt32Array()
## Ruang di atas/bawah fitur: RES_SOFT = tidak boleh batu, RES_HARD = harus kosong
var _reserved := PackedByteArray()
## Array of {rect: Rect2i, kind: int, chain: bool}
var _features: Array[Dictionary] = []
var _landing_ids: Array[int] = []


func _init() -> void:
	width = 30
	height = 200
	max_climb = 2
	max_gap = 3


# ---------------------------------------------------------------- grid

func cell_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return SOLID
	return _grid[_idx(x, y)]


func is_platform(x: int, y: int) -> bool:
	return cell_at(x, y) == PLATFORM


## Berdiri = cell benar-benar kosong dan di bawahnya batu ATAU papan
func is_standing(x: int, y: int) -> bool:
	return cell_at(x, y) == EMPTY and cell_at(x, y + 1) != EMPTY


func _owner_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	return _owner[_idx(x, y)]


func _reserve_rows(x0: int, x1: int, y0: int, y1: int, level: int = RES_HARD) -> void:
	for y in range(maxi(y0, 0), mini(y1, height)):
		for x in range(maxi(x0, 0), mini(x1, width)):
			var i: int = _idx(x, y)
			_reserved[i] = maxi(_reserved[i], level)


## Ruang di atas permukaan: baris berdiri harus kosong, dan 3 baris (selebar
## platform + 2 kolom tiap sisi) bebas batu, supaya lompatan naik 2 tile dan
## lintasan ke platform tetangga tidak terbentur.
func _reserve_above(x0: int, x1: int, top: int) -> void:
	_reserve_rows(x0 - 2, x1 + 2, top - 4, top - 1, RES_SOFT)
	_reserve_rows(x0, x1, top - 1, top, RES_HARD)


func inner_left(y: int) -> int:
	return _wall_l[clampi(y, 0, height - 1)]


## Kolom terakhir (inklusif) yang masih ruang dalam
func inner_right(y: int) -> int:
	return width - 1 - _wall_r[clampi(y, 0, height - 1)]


# ---------------------------------------------------------------- build

func _build_once(seed_value: int) -> Dictionary:
	_rng.seed = seed_value
	_grid = PackedByteArray()
	_grid.resize(width * height)
	_grid.fill(EMPTY)
	_owner = PackedInt32Array()
	_owner.resize(width * height)
	_owner.fill(-1)
	_reserved = PackedByteArray()
	_reserved.resize(width * height)
	_reserved.fill(0)
	_protected.clear()
	_rooms.clear()
	_features.clear()
	_landing_ids.clear()

	_make_shell()
	var ok: bool = _make_landings()

	# rantai dari bawah ke atas: lantai dasar -> L1 -> L2 -> ...
	var spawn_cell := Vector2i.ZERO
	if ok:
		var ground_y: int = height - 4
		var spawn_left: bool = _rng.randf() < 0.5
		var sx: int = inner_left(ground_y) + 2 if spawn_left else inner_right(ground_y) - 2
		spawn_cell = Vector2i(sx, ground_y)
		var prev: int = -1
		for lid in _landing_ids:
			# Rantai acak bisa buntu; ulangi bagian ini dari keadaan semula.
			var done: bool = false
			for retry in range(16):
				var snap: Array = _snapshot()
				var tid: int = _place_target(lid)
				if tid >= 0 and _build_chain(prev, lid, tid, spawn_cell):
					done = true
					break
				_restore(snap)
			if not done:
				ok = false
				break
			prev = lid

	if ok:
		var prev_top: int = height - 3
		for lid in _landing_ids:
			var top: int = _features[lid]["rect"].position.y
			_add_ledges(top + 4, prev_top - 2)
			_add_bonus(top + 2, prev_top - 1)
			prev_top = top

	var exit_cell: Vector2i = _pick_tower_exit() if ok else spawn_cell
	var reach: Dictionary = compute_reachable(spawn_cell) if ok else {}

	var planks: Array[Rect2i] = []
	var landings: Array[Rect2i] = []
	for f in _features:
		if f["kind"] == KIND_PLANK:
			planks.append(f["rect"])
		elif f["kind"] == KIND_LANDING:
			landings.append(f["rect"])

	return {
		"grid": _grid,
		"width": width,
		"height": height,
		"path": [],
		"rooms": _rooms,
		"spawn_cell": spawn_cell,
		"exit_cell": exit_cell,
		"reachable": reach,
		"protected": _protected,
		"failed": not ok,
		"features": _features,
		"planks": planks,
		"landings": landings,
		"sewer_top_row": _sewer_top_row(),
	}


## Dinding samping bergerigi, langit-langit dan lantai dasar setebal 3 tile.
func _make_shell() -> void:
	_wall_l.resize(height)
	_wall_r.resize(height)
	var tl: int = _rng.randi_range(wall_min, wall_max - 1)
	var tr: int = _rng.randi_range(wall_min, wall_max - 1)
	var y: int = 0
	while y < height:
		var seg: int = _rng.randi_range(4, 7)
		tl = clampi(tl + _rng.randi_range(-1, 1), wall_min, wall_max)
		tr = clampi(tr + _rng.randi_range(-1, 1), wall_min, wall_max)
		for i in range(seg):
			if y >= height:
				break
			_wall_l[y] = tl
			_wall_r[y] = tr
			y += 1

	for yy in range(height):
		for x in range(width):
			if x < _wall_l[yy] or x >= width - _wall_r[yy] or yy < 3 or yy >= height - 3:
				_grid[_idx(x, yy)] = SOLID
	# lantai dasar: papan tidak boleh menempel langsung di atasnya
	_reserve_above(0, width, height - 3)


## Lantai istirahat dari bawah ke atas, sisi selang-seling. Yang terakhir di
## baris 8 (puncak, tempat pintu keluar).
func _make_landings() -> bool:
	var bottom: int = height - 3
	var top_row: int = 8
	var n: int = maxi(1, roundi(float(bottom - top_row) / landing_spacing))
	var spacing: float = float(bottom - top_row) / n
	var left: bool = _rng.randf() < 0.5
	for i in range(1, n + 1):
		var b: int = top_row if i == n else bottom - roundi(i * spacing) + _rng.randi_range(-2, 2)
		var lo: int = maxi(inner_left(b), inner_left(b + 1))
		var hi: int = mini(inner_right(b), inner_right(b + 1))
		var inner_w: int = hi - lo + 1
		var w: int = roundi(inner_w * _rng.randf_range(landing_ratio_min, landing_ratio_max))
		var r: Rect2i
		if left:
			r = Rect2i(0, b, lo + w, 2)
		else:
			r = Rect2i(hi - w + 1, b, width - (hi - w + 1), 2)
		var id: int = _features.size()
		_features.append({"rect": r, "kind": KIND_LANDING, "chain": true, "left": left})
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _grid[_idx(x, y)] == EMPTY:
					_owner[_idx(x, y)] = id
				_grid[_idx(x, y)] = SOLID
		_reserve_above(r.position.x, r.end.x, b)
		_reserve_rows(r.position.x, r.end.x, b + 2, b + 4)
		_landing_ids.append(id)
		left = not left
	return true


## Ujung bebas lantai istirahat (kolom terluar ke arah celah)
func _landing_tip(lid: int) -> int:
	var f: Dictionary = _features[lid]
	var r: Rect2i = f["rect"]
	return r.end.x - 1 if f["left"] else r.position.x


## Platform di sisi celah lantai istirahat yang pasti bisa dipakai naik ke sana.
func _place_target(lid: int) -> int:
	var f: Dictionary = _features[lid]
	var b: int = f["rect"].position.y
	var tip: int = _landing_tip(lid)
	var d: int = 1 if f["left"] else -1
	for attempt in range(20):
		var plank: bool = _rng.randf() < 0.75
		var length: int = _rng.randi_range(4, 5) if plank else _rng.randi_range(3, 4)
		# naik 2 dengan celah 1, atau naik 1 dengan celah 1-2
		var rise2: bool = _rng.randf() < 0.6
		var stand: int = b + 1 if rise2 else b
		var gap: int = 1 if rise2 else _rng.randi_range(1, 2)
		var near: int = tip + d * (gap + 1)
		var x0: int = near if d > 0 else near - length + 1
		var r := Rect2i(x0, stand + 1, length, 1 if plank else 2)
		var id: int = _try_place(r, KIND_PLANK if plank else KIND_BLOCK, -1)
		if id >= 0:
			_features[id]["chain"] = true
			return id
	return -1


## Rantai platform dari fitur `from_id` (-1 = lantai dasar) sampai bisa
## menjangkau target `tid` atau langsung lantai istirahat `lid`.
func _build_chain(from_id: int, lid: int, tid: int, spawn: Vector2i) -> bool:
	var cur_rect: Rect2i
	var cur: int = from_id
	var dir: int
	if from_id < 0:
		cur_rect = Rect2i(spawn.x - 1, spawn.y + 1, 3, 1)
		dir = 1 if spawn.x < width / 2 else -1
	else:
		cur_rect = _features[from_id]["rect"]
		dir = 1 if _features[from_id]["left"] else -1
	var t_rect: Rect2i = _features[tid]["rect"]
	var l_rect: Rect2i = _features[lid]["rect"]
	var t_stand: int = t_rect.position.y - 1
	var t_plank: bool = _features[tid]["kind"] == KIND_PLANK

	for step in range(60):
		if _can_reach(cur_rect, t_rect, t_plank) or _can_reach(cur_rect, l_rect, false):
			return true
		var s: int = cur_rect.position.y - 1
		var rem: int = s - t_stand
		if rem <= 9:
			var dx: float = t_rect.get_center().x - cur_rect.get_center().x
			if absf(dx) > 0.5:
				dir = 1 if dx > 0 else -1

		var placed: int = -1
		for attempt in range(36):
			var d: int = dir if attempt < 20 else -dir
			var dy: int = _pick_rise()
			dy = clampi(dy, 0, maxi(rem, 0))
			var plank: bool = _rng.randf() < plank_chance
			var length: int = _rng.randi_range(4, 6) if plank else _rng.randi_range(3, 5)
			var gap: int = _pick_gap(dy)
			var x0: int = cur_rect.end.x + gap if d > 0 else cur_rect.position.x - gap - length
			if plank and dy == 2 and _rng.randf() < 0.2:
				# papan bertumpuk: sebagian di atas platform sekarang, dilompati tembus
				x0 = cur_rect.end.x - 2 if d > 0 else cur_rect.position.x - length + 2
			var r := Rect2i(x0, s - dy + 1, length, 1 if plank else 2)
			if _under_landing(r, l_rect):
				continue
			placed = _try_place(r, KIND_PLANK if plank else KIND_BLOCK, cur)
			if placed >= 0:
				dir = d
				break
		if placed < 0:
			return false
		_features[placed]["chain"] = true
		cur = placed
		cur_rect = _features[placed]["rect"]
	return false


## Platform tepat di bawah lantai istirahat (kurang dari 6 baris) adalah jalan
## buntu: tidak bisa naik menembus batu, jadi rantai menghindarinya.
func _under_landing(r: Rect2i, l_rect: Rect2i) -> bool:
	var overlap: bool = r.position.x < l_rect.end.x and l_rect.position.x < r.end.x
	return overlap and r.position.y > l_rect.position.y and r.position.y <= l_rect.end.y + 6


func _snapshot() -> Array:
	return [_grid.duplicate(), _owner.duplicate(), _reserved.duplicate(), _features.size()]


func _restore(snap: Array) -> void:
	_grid = snap[0].duplicate()
	_owner = snap[1].duplicate()
	_reserved = snap[2].duplicate()
	_features.resize(snap[3])


func _pick_rise() -> int:
	var roll: float = _rng.randf()
	if roll < 0.6:
		return 2
	elif roll < 0.85:
		return 1
	return 0


## Celah mendatar (jumlah kolom kosong) yang aman untuk kenaikan dy
func _pick_gap(dy: int) -> int:
	match dy:
		0:
			return 3 if _rng.randf() < 0.3 else 2
		1:
			return _rng.randi_range(0, 2)
		_:
			return _rng.randi_range(0, 1)


## Apakah dari permukaan `a` bisa melompat ke permukaan `b` (sesuai BFS).
## Papan tepat di atas (bertumpuk) dijangkau dengan melompat menembusnya.
func _can_reach(a: Rect2i, b: Rect2i, b_is_plank: bool) -> bool:
	var dy: int = a.position.y - b.position.y
	if dy < 0 or dy > max_climb:
		return false
	var hgap: int = maxi(b.position.x - a.end.x, a.position.x - b.end.x)
	if hgap < 0:
		return b_is_plank and dy >= 1
	if dy == 0 and hgap < 1:
		return false
	return hgap <= max_gap - dy


## Tonjolan batu yang menempel di dinding, supaya tidak semuanya papan.
func _add_ledges(y_top: int, y_bottom: int) -> void:
	if y_bottom - y_top < 4:
		return
	var want: int = _rng.randi_range(1, 3)
	var placed: int = 0
	for attempt in range(80):
		if placed >= want:
			break
		var y: int = _rng.randi_range(y_top, y_bottom)
		var length: int = _rng.randi_range(2, 4)
		var on_left: bool = _rng.randf() < 0.5
		var lo: int = maxi(inner_left(y), inner_left(y + 1))
		var hi: int = mini(inner_right(y), inner_right(y + 1))
		var x0: int = lo if on_left else hi - length + 1
		if _try_place(Rect2i(x0, y, length, 2), KIND_BLOCK, -1) >= 0:
			placed += 1


## Platform tambahan acak di antara baris y_top..y_bottom.
func _add_bonus(y_top: int, y_bottom: int) -> void:
	if y_bottom - y_top < 4:
		return
	var want: int = _rng.randi_range(bonus_min, bonus_max)
	var placed: int = 0
	for attempt in range(60):
		if placed >= want:
			break
		var plank: bool = _rng.randf() < 0.45
		var length: int = _rng.randi_range(4, 6) if plank else _rng.randi_range(2, 4)
		var y: int = _rng.randi_range(y_top, y_bottom)
		var x0: int = _rng.randi_range(inner_left(y), inner_right(y) - length + 1)
		var r := Rect2i(x0, y, length, 1 if plank else 2)
		if _try_place(r, KIND_PLANK if plank else KIND_BLOCK, -1) >= 0:
			placed += 1


## Menaruh fitur kalau memenuhi semua aturan jarak. Mengembalikan id atau -1.
## `allow` = id fitur yang boleh disentuh (platform sebelumnya di rantai).
func _try_place(r: Rect2i, kind: int, allow: int) -> int:
	if r.position.y < 4 or r.end.y > height - 3:
		return -1
	var below: int = 1 if kind == KIND_PLANK else 2
	var max_res: int = RES_SOFT if kind == KIND_PLANK else 0
	for y in range(r.position.y, r.end.y):
		if r.position.x < inner_left(y) or r.end.x - 1 > inner_right(y):
			return -1
		for x in range(r.position.x, r.end.x):
			var i: int = _idx(x, y)
			if _grid[i] != EMPTY or _reserved[i] > max_res:
				return -1
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var o: int = _owner_at(x + ox, y + oy)
					if o >= 0 and o != allow:
						return -1
	# ruang di atas & di bawah harus sudah bebas sekarang
	for x in range(r.position.x, r.end.x):
		if cell_at(x, r.position.y - 1) != EMPTY:
			return -1
		for y in range(r.position.y - 4, r.position.y - 1):
			if cell_at(x, y) == SOLID:
				return -1
	for y in range(r.end.y, r.end.y + below):
		for x in range(r.position.x, r.end.x):
			if cell_at(x, y) != EMPTY:
				return -1

	var id: int = _features.size()
	_features.append({"rect": r, "kind": kind, "chain": false})
	var v: int = PLATFORM if kind == KIND_PLANK else SOLID
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_grid[_idx(x, y)] = v
			_owner[_idx(x, y)] = id
	_reserve_above(r.position.x, r.end.x, r.position.y)
	_reserve_rows(r.position.x, r.end.x, r.end.y, r.end.y + below)
	return id


# ---------------------------------------------------------------- hasil

func _pick_tower_exit() -> Vector2i:
	var lid: int = _landing_ids[_landing_ids.size() - 1]
	var f: Dictionary = _features[lid]
	var r: Rect2i = f["rect"]
	var y: int = r.position.y - 1
	# di dekat dinding, jauh dari ujung tempat player naik
	var x: int = inner_left(y) + 2 if f["left"] else inner_right(y) - 2
	return Vector2i(x, y)


## Baris teratas tema Sewer: puncak lantai istirahat yang paling dekat
## dengan batas sewer_fraction dari bawah.
func _sewer_top_row() -> int:
	var target: float = height * (1.0 - sewer_fraction)
	var best: int = height
	var best_d: float = INF
	for lid in _landing_ids:
		var top: int = _features[lid]["rect"].position.y
		var d: float = absf(top - target)
		if d < best_d:
			best_d = d
			best = top
	return best
