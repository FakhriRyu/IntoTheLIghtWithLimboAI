class_name CaveGenerator
extends RefCounted
## Gua "ruang + lorong" yang menanjak: spawn di bawah, pintu keluar di atas.
##
## Cara kerjanya (gaya Spelunky):
##   1. Peta dibagi jadi grid ruangan (4 kolom x 10 baris, tiap ruangan 16x14 tile).
##   2. JALUR SOLUSI dibuat duluan: mulai dari ruangan di baris paling bawah, bergeser
##      kiri/kanan beberapa ruangan, lalu naik satu baris, terus sampai baris teratas.
##   3. Ruangan di jalur diukir dan disambung. Kalau jalurnya naik, ruangan itu diberi
##      TANGGA DIAGONAL SATU ARAH yang diisi padat sampai lantai.
##   4. Ruangan di luar jalur dijadikan gua samping (opsional) atau dibiarkan batu.
##   5. BFS memverifikasi pintu keluar benar-benar terjangkau dari spawn.
##
## Kenapa tangga diagonal satu arah, bukan zig-zag bolak-balik?
## Player tingginya 1 tile dan lompatannya cuma 2,18 tile. Zig-zag butuh ledge
## sisi-sama berjarak >= 4 baris supaya ada ruang kepala, padahal lompatan cuma
## muat 2 baris. Tangga satu arah tidak pernah punya ledge di atas kepala player.
##
## Kenapa semua batu dijamin minimal setebal 2 tile?
## Tileset CaveG memakai skema 13 tile (isian + 4 tepi + 4 pojok luar + 4 pojok
## dalam). Skema ini tidak punya tile untuk pilar/tonjolan setebal 1 tile.
##
## Koordinat: y=0 di ATAS. "Naik" berarti y mengecil.

const SOLID := 1
const EMPTY := 0

const ROOM_W := 16
const ROOM_H := 14
## Baris lokal dalam ruangan
const FLOOR_ROW := 13       # lantai padat
const STAND_ROW := 12       # baris tempat berdiri di atas lantai
const DOOR_TOP := 10        # bukaan samping = baris 10..12 (setinggi 3 tile)
## Puncak tiap anak tangga (baris lokal), dari bawah ke atas. Selisih 2 = tinggi lompatan.
const STEP_TOPS: Array[int] = [11, 9, 7, 5, 3, 1]

var cols: int = 4
var rows: int = 10
var width: int = 64
var height: int = 140

## Batas kemampuan player dalam tile (jump_velocity -330 -> 69,8 px = 2,18 tile)
var max_climb: int = 2
## Lebar celah terjauh yang bisa dilompati mendatar
var max_gap: int = 3

## Peluang ruangan di luar jalur dijadikan gua samping
var side_cave_chance: float = 0.5
## Peluang ada gundukan batu di lantai ruangan mendatar
var mound_chance: float = 0.45

var _grid: PackedByteArray
var _rng := RandomNumberGenerator.new()
## Cell yang wajib tetap kosong (lubang naik dan tempat mendarat di atasnya)
var _protected := {}
## Vector2i(cx, cy) -> Dictionary info ruangan
var _rooms := {}


func _init() -> void:
	width = cols * ROOM_W
	height = rows * ROOM_H


# ---------------------------------------------------------------- grid dasar

func _idx(x: int, y: int) -> int:
	return y * width + x


func is_solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return true
	return _grid[_idx(x, y)] == SOLID


func _put(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	if v == SOLID and _protected.has(Vector2i(x, y)):
		return
	_grid[_idx(x, y)] = v


func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(x, y, EMPTY)


func _fill_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(x, y, SOLID)


# ---------------------------------------------------------------- API utama

## Mencoba beberapa layout sampai pintu keluar terjangkau.
## Percobaan berikutnya memakai seed turunan, jadi hasilnya tetap deterministik.
func generate(seed_value: int, max_attempts: int = 30) -> Dictionary:
	var s: int = seed_value
	var last: Dictionary = {}
	for i in range(max_attempts):
		last = _build_once(s)
		if not last.get("failed", false) and last["reachable"].has(last["exit_cell"]):
			last["attempts"] = i + 1
			return last
		s = int((s * 1103515245 + 12345) & 0x7FFFFFFF)
	last["attempts"] = max_attempts
	last["failed"] = true
	return last


func _build_once(seed_value: int) -> Dictionary:
	_rng.seed = seed_value
	_grid = PackedByteArray()
	_grid.resize(width * height)
	_grid.fill(SOLID)
	_protected.clear()
	_rooms.clear()

	var path: Array[Vector2i] = _make_path()
	for i in range(path.size()):
		var info := {
			"cell": path[i],
			"on_path": true,
			"prev": path[i - 1] if i > 0 else Vector2i(-99, -99),
			"next": path[i + 1] if i < path.size() - 1 else Vector2i(-99, -99),
			"hole": [],           # kolom global lubang di LANTAI ruangan ini
			"blocked": 0,         # sisi yang tidak boleh dibuka (-1 kiri, 1 kanan)
		}
		_rooms[path[i]] = info

	# ukir ruangan jalur dari bawah ke atas (lubang naik ditentukan ruangan bawahnya)
	var ok := true
	for i in range(path.size()):
		if not _build_path_room(_rooms[path[i]]):
			ok = false
			break

	if ok:
		_build_side_caves()

	var spawn_cell: Vector2i = _pick_spawn(_rooms[path[0]])
	var exit_cell: Vector2i = _pick_exit(_rooms[path[path.size() - 1]], spawn_cell)
	var reach: Dictionary = compute_reachable(spawn_cell)

	return {
		"grid": _grid,
		"width": width,
		"height": height,
		"path": path,
		"rooms": _rooms,
		"spawn_cell": spawn_cell,
		"exit_cell": exit_cell,
		"reachable": reach,
		"protected": _protected,
		"failed": not ok,
	}


# ---------------------------------------------------------------- jalur solusi

func _make_path() -> Array[Vector2i]:
	var cx: int = _rng.randi_range(0, cols - 1)
	var cy: int = rows - 1
	var path: Array[Vector2i] = [Vector2i(cx, cy)]
	while true:
		# geser mendatar 0..2 ruangan ke satu arah (tidak pernah balik, jadi tak ada ruangan dikunjungi 2x)
		var steps: int = _rng.randi_range(0, 2)
		var dir: int = -1 if _rng.randf() < 0.5 else 1
		for i in range(steps):
			var nx: int = cx + dir
			if nx < 0 or nx >= cols:
				break
			cx = nx
			path.append(Vector2i(cx, cy))
		if cy == 0:
			break
		cy -= 1
		path.append(Vector2i(cx, cy))
	return path


func _origin(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x * ROOM_W, cell.y * ROOM_H)


# ---------------------------------------------------------------- ruangan jalur

func _build_path_room(info: Dictionary) -> bool:
	var cell: Vector2i = info["cell"]
	var o: Vector2i = _origin(cell)
	var prev: Vector2i = info["prev"]
	var next: Vector2i = info["next"]
	var goes_up: bool = next == cell + Vector2i(0, -1)
	var from_below: bool = prev == cell + Vector2i(0, 1)
	var vertical: bool = goes_up or from_below

	# Ruangan yang terhubung vertikal memakai margin 0 supaya lubang naik selalu
	# punya lantai di sebelahnya untuk mendarat. Ruangan mendatar boleh variatif,
	# dan margin sampingnya otomatis menjadi lorong.
	var ml: int = 0
	var mr: int = 0
	var mt: int = 0
	if not vertical:
		ml = _rng.randi_range(0, 3)
		mr = _rng.randi_range(0, 3)
		mt = _rng.randi_range(0, 5)
	elif not goes_up:
		mt = _rng.randi_range(0, 4)

	var interior := Rect2i(o.x + 1 + ml, o.y + 1 + mt, ROOM_W - 2 - ml - mr, STAND_ROW - mt)
	info["interior"] = interior
	_carve_rect(interior)

	# sambungan mendatar dengan ruangan jalur tetangga
	for nb in [prev, next]:
		if nb == cell + Vector2i(-1, 0):
			_open_side(info, -1)
		elif nb == cell + Vector2i(1, 0):
			_open_side(info, 1)

	if goes_up:
		if not _build_ramp(info):
			return false
	elif not vertical and _rng.randf() < mound_chance:
		_add_mound(info)
	return true


## Membuka bukaan setinggi 3 tile di sisi ruangan (dir -1 kiri, 1 kanan).
## Margin antara dinding sel dan interior ikut terukir, jadi terbentuk lorong.
func _open_side(info: Dictionary, dir: int) -> void:
	var o: Vector2i = _origin(info["cell"])
	var interior: Rect2i = info["interior"]
	var y0: int = o.y + DOOR_TOP
	if dir < 0:
		_carve_rect(Rect2i(o.x, y0, interior.position.x - o.x, STAND_ROW - DOOR_TOP + 1))
	else:
		_carve_rect(Rect2i(interior.end.x, y0, o.x + ROOM_W - interior.end.x, STAND_ROW - DOOR_TOP + 1))
	info["open_" + ("L" if dir < 0 else "R")] = true


## Tangga diagonal dari lantai sampai langit-langit, menempel di dinding sisi tinggi.
## Enam anak tangga setinggi 2 tile, diisi padat sampai lantai.
func _build_ramp(info: Dictionary) -> bool:
	var cell: Vector2i = info["cell"]
	var o: Vector2i = _origin(cell)
	var interior: Rect2i = info["interior"]
	var left: int = interior.position.x
	var right: int = interior.end.x - 1
	var prev: Vector2i = info["prev"]
	var holes: Array = info["hole"]

	var d: int
	var s: int
	if prev == cell + Vector2i(-1, 0):
		d = 1
		s = left + 2          # mulai 2 kolom dari pintu masuk supaya ada ruang ancang-ancang
	elif prev == cell + Vector2i(1, 0):
		d = -1
		s = right - 2
	elif not holes.is_empty():
		# datang dari lubang di lantai: naik menjauhi lubang, ke arah dinding terjauh
		var hmin: int = holes.min()
		var hmax: int = holes.max()
		if (right - hmax) >= (hmin - left):
			d = 1
			s = hmax + 2      # sisakan 1 kolom lantai untuk mendarat
		else:
			d = -1
			s = hmin - 2
	else:
		d = 1 if _rng.randf() < 0.5 else -1
		s = left + 2 if d == 1 else right - 2

	var w: int = right if d == 1 else left
	var total: int = absi(w - s) + 1
	if total > 12:
		s = w - d * 11
		total = 12
	if total < 7:
		return false

	# lebar tiap anak tangga: anak terakhir selalu 2 (supaya tidak jadi pilar tipis),
	# sisanya 1..2, dan anak pertama menyerap sisa kolom.
	var widths: Array[int] = [0, 1, 1, 1, 1, 2]
	widths[0] = total - 6
	while widths[0] > 1:
		var k: int = _rng.randi_range(1, 4)
		if widths[k] == 1 and _rng.randf() < 0.6:
			widths[k] = 2
			widths[0] -= 1
		elif _rng.randf() < 0.3:
			break

	var x: int = s
	for k in range(6):
		var top: int = o.y + STEP_TOPS[k]
		for i in range(widths[k]):
			_fill_rect(Rect2i(x, top, 1, o.y + STAND_ROW - top + 1))
			x += d

	# Lubang naik 2 kolom: di atas kolom terakhir anak ke-5 dan kolom dalam anak ke-6.
	# Satu kolom saja tidak cukup - player yang melompat dari anak ke-5 akan terbentur
	# langit-langit sebelum sempat masuk ke lubang.
	var h1: int = w - d * 2
	var h2: int = w - d
	for hx in [h1, h2]:
		_put(hx, o.y, EMPTY)          # langit-langit ruangan ini
		_put(hx, o.y - 1, EMPTY)      # lantai ruangan di atasnya
		_protected[Vector2i(hx, o.y)] = true
		_protected[Vector2i(hx, o.y - 1)] = true
	# ruang mendarat & ruang kepala di ruangan atas
	for px in [h1 - d, h1, h2, w]:
		for py in [o.y - 2, o.y - 3]:
			_protected[Vector2i(px, py)] = true

	info["blocked"] = d     # sisi dinding tempat tangga menempel tidak boleh dibuka
	var up: Vector2i = cell + Vector2i(0, -1)
	if _rooms.has(up):
		_rooms[up]["hole"] = [h1, h2]
	return true


## Gundukan setinggi 2 tile di lantai ruangan mendatar, untuk variasi lompatan.
func _add_mound(info: Dictionary) -> void:
	var o: Vector2i = _origin(info["cell"])
	var interior: Rect2i = info["interior"]
	var mw: int = _rng.randi_range(3, 5)
	var span: int = interior.size.x - mw - 4
	if span < 1:
		return
	var mx: int = interior.position.x + 2 + _rng.randi_range(0, span)
	_fill_rect(Rect2i(mx, o.y + STAND_ROW - 1, mw, 2))


# ---------------------------------------------------------------- gua samping

func _build_side_caves() -> void:
	for cy in range(rows):
		for cx in range(cols):
			var cell := Vector2i(cx, cy)
			if _rooms.has(cell) or _rng.randf() > side_cave_chance:
				continue
			# cari tetangga jalur di kiri/kanan yang sisinya masih boleh dibuka
			for dir in [-1, 1]:
				var nb: Vector2i = cell + Vector2i(dir, 0)
				if not _rooms.has(nb) or not _rooms[nb]["on_path"]:
					continue
				var nbinfo: Dictionary = _rooms[nb]
				var side_of_nb: int = -dir
				if nbinfo["blocked"] == side_of_nb:
					continue
				if nbinfo.get("open_" + ("L" if side_of_nb < 0 else "R"), false):
					continue
				_make_side_cave(cell, dir, nbinfo, side_of_nb)
				break


func _make_side_cave(cell: Vector2i, dir_to_path: int, nbinfo: Dictionary, side_of_nb: int) -> void:
	var o: Vector2i = _origin(cell)
	var ml: int = _rng.randi_range(0, 3)
	var mr: int = _rng.randi_range(0, 3)
	var mt: int = _rng.randi_range(0, 5)
	var interior := Rect2i(o.x + 1 + ml, o.y + 1 + mt, ROOM_W - 2 - ml - mr, STAND_ROW - mt)
	var info := {
		"cell": cell, "on_path": false, "interior": interior,
		"prev": Vector2i(-99, -99), "next": Vector2i(-99, -99), "hole": [], "blocked": 0,
	}
	_rooms[cell] = info
	_carve_rect(interior)
	_open_side(info, dir_to_path)
	_open_side(nbinfo, side_of_nb)
	if _rng.randf() < mound_chance:
		_add_mound(info)


# ---------------------------------------------------------------- spawn & exit

func _floor_cells(info: Dictionary) -> Array[Vector2i]:
	var o: Vector2i = _origin(info["cell"])
	var interior: Rect2i = info["interior"]
	var out: Array[Vector2i] = []
	var y: int = o.y + STAND_ROW
	for x in range(interior.position.x, interior.end.x):
		if is_standing(x, y) and not _protected.has(Vector2i(x, y)):
			out.append(Vector2i(x, y))
	return out


func _pick_spawn(info: Dictionary) -> Vector2i:
	var cells: Array[Vector2i] = _floor_cells(info)
	if cells.is_empty():
		var o: Vector2i = _origin(info["cell"])
		return Vector2i(o.x + ROOM_W / 2, o.y + STAND_ROW)
	# kalau ada tangga, spawn di sisi pangkalnya (berlawanan dengan dinding tempat tangga menempel)
	var blocked: int = info["blocked"]
	if blocked == 1:
		return cells[0]
	elif blocked == -1:
		return cells[cells.size() - 1]
	return cells[cells.size() / 2]


func _pick_exit(info: Dictionary, spawn: Vector2i) -> Vector2i:
	var cells: Array[Vector2i] = _floor_cells(info)
	if cells.is_empty():
		var o: Vector2i = _origin(info["cell"])
		return Vector2i(o.x + ROOM_W / 2, o.y + STAND_ROW)
	# sejauh mungkin dari titik masuk ruangan
	var entry: Vector2i = cells[0]
	var holes: Array = info["hole"]
	var prev: Vector2i = info["prev"]
	var cell: Vector2i = info["cell"]
	if not holes.is_empty():
		entry = Vector2i(holes[0], cells[0].y)
	elif prev == cell + Vector2i(1, 0):
		entry = cells[cells.size() - 1]
	var best: Vector2i = cells[0]
	for c in cells:
		if absi(c.x - entry.x) > absi(best.x - entry.x):
			best = c
	return best


# ---------------------------------------------------------------- keterjangkauan

## Posisi berdiri = cell kosong yang di bawahnya padat
func is_standing(x: int, y: int) -> bool:
	return not is_solid(x, y) and is_solid(x, y + 1)


## BFS keterjangkauan. Sengaja KONSERVATIF: kalau BFS bilang bisa, player
## pasti benar-benar bisa. Lebih baik meremehkan daripada gua yang menjebak.
func compute_reachable(start: Vector2i) -> Dictionary:
	var seen := {}
	if not is_standing(start.x, start.y):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for n in _neighbors(c):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach: int = max_gap + 1

	for dx in range(-reach, reach + 1):
		if dx == 0:
			continue
		var nx: int = c.x + dx

		# naik atau mendatar
		for r in range(0, max_climb + 1):
			if absi(dx) > reach - r:
				continue
			var ny: int = c.y - r
			if not is_standing(nx, ny):
				continue
			if r == 0 and absi(dx) == 1:
				out.append(Vector2i(nx, ny))      # jalan biasa
				continue
			# Lintasan L: naik lurus di kolom sendiri sampai satu tile di atas
			# ketinggian mendarat (ruang kepala di puncak lompatan), lalu geser.
			if not _col_clear(c.x, ny - 1, c.y - 1):
				continue
			if not _row_clear(ny, c.x, nx) or not _row_clear(ny - 1, c.x, nx):
				continue
			out.append(Vector2i(nx, ny))

		# turun: melangkah keluar dari tepian, lalu jatuh
		if absi(dx) <= 2 and _row_clear(c.y, c.x, nx):
			var fy: int = c.y
			while fy < height - 1:
				if is_solid(nx, fy):
					break
				if is_standing(nx, fy):
					if fy > c.y:
						out.append(Vector2i(nx, fy))
					break
				fy += 1
	return out


func _col_clear(x: int, y_top: int, y_bot: int) -> bool:
	for y in range(mini(y_top, y_bot), maxi(y_top, y_bot) + 1):
		if is_solid(x, y):
			return false
	return true


func _row_clear(y: int, x0: int, x1: int) -> bool:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		if is_solid(x, y):
			return false
	return true


# ---------------------------------------------------------------- diagnostik

## Batu setebal 1 tile tidak punya tile di skema 13-tile CaveG.
## Dihitung dari geometri, dengan luar peta dianggap padat.
func count_thin_cells() -> int:
	var n: int = 0
	for y in range(height):
		for x in range(width):
			if not is_solid(x, y):
				continue
			var l: bool = is_solid(x - 1, y)
			var r: bool = is_solid(x + 1, y)
			var u: bool = is_solid(x, y - 1)
			var d: bool = is_solid(x, y + 1)
			if (not l and not r) or (not u and not d):
				n += 1
	return n
