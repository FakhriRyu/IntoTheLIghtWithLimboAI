class_name ComicPanel
extends Control
## Satu panel komik untuk cutscene: gambar dengan kamera pelan (geser + zoom),
## bingkai putih tebal ala komik, dan efek yang digambar di atas gambar
## (cahaya lentera, debu, hujan, asap, kedipan mata, Elian memudar).
## Dibuat dan diatur oleh prolog_cutscene.gd lewat setup().

const PAPER := Color(0.957, 0.937, 0.894)
const BORDER := 6.0
const WARM := Color(1.0, 0.67, 0.31)
const WARM_CORE := Color(1.0, 0.88, 0.63)
const TEAL := Color(0.24, 0.9, 0.82)

enum { L_IMAGE, L_ADD, L_MIX }


## Lapisan gambar di dalam panel. Isinya digambar oleh ComicPanel._draw_layer.
class Layer extends Control:
	var panel: ComicPanel
	var kind: int = 0

	func _draw() -> void:
		panel._draw_layer(self, kind)


## Topeng berbentuk panel: anak-anaknya hanya terlihat di dalam bentuk ini.
class Mask extends Control:
	var points := PackedVector2Array()

	func _draw() -> void:
		draw_colored_polygon(points, Color.WHITE)


var scene_id: StringName
var time: float = 0.0
## Tekstur dan data bersama dari cutscene (gambar, glow, vignette)
var res: Dictionary

var _tex: Texture2D
var _cam_a := Vector3(0.5, 0.5, 1.0)
var _cam_b := Vector3(0.5, 0.5, 1.0)
var _cam_dur: float = 6.0
var _cam_delay: float = 0.0
var _shape := PackedVector2Array()
var _inner := Vector2.ZERO
var _layers: Array[Layer] = []
var _image_layer: Layer
## Kamera saat ini: skala gambar->layar dan potongan sumber
var _s: float = 1.0
var _src := Rect2()
var _cur: Texture2D
## Data efek Elian memudar (sel-sel gambar yang lepas satu per satu)
var _cells: Array = []
const CELL := 16.0
const FADE_ELLIPSE := Rect2(1105, 370, 262, 430)  # pusat x,y dan jari-jari x,y
const FADE_START := 0.6
const FADE_LEN := 3.4


## opts: img, cam_a, cam_b, dur, delay, shape (titik 0..1)
func setup(id: StringName, rect: Rect2, opts: Dictionary, shared: Dictionary) -> void:
	scene_id = id
	res = shared
	position = rect.position
	size = rect.size
	pivot_offset = rect.size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = res.tex.get(opts.get("img", ""), null)
	_cam_a = opts.get("cam_a", _cam_a)
	_cam_b = opts.get("cam_b", _cam_a)
	_cam_dur = opts.get("dur", 6.0)
	_cam_delay = opts.get("delay", 0.0)
	var shape_n: PackedVector2Array = opts.get("shape",
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	_shape = PackedVector2Array()
	for p in shape_n:
		_shape.append(p * size)

	_inner = size - Vector2(BORDER, BORDER) * 2.0
	var mask := Mask.new()
	mask.position = Vector2(BORDER, BORDER)
	mask.size = _inner
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var mpts := PackedVector2Array()
	for p in shape_n:
		mpts.append(p * _inner)
	mask.points = mpts
	add_child(mask)

	for kind in [L_IMAGE, L_ADD, L_MIX]:
		var l := Layer.new()
		l.panel = self
		l.kind = kind
		l.size = _inner
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == L_ADD:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			l.material = m
		mask.add_child(l)
		_layers.append(l)
	_image_layer = _layers[0]

	if scene_id == &"eyes":
		var m := ShaderMaterial.new()
		m.shader = res.blur_shader
		_image_layer.material = m
	if scene_id == &"fade":
		_prep_fade()
	_update_cam()


func _process(delta: float) -> void:
	time += delta
	_update_cam()
	for l in _layers:
		l.queue_redraw()


func _draw() -> void:
	var shadow := PackedVector2Array()
	for p in _shape:
		shadow.append(p + Vector2(0, 16))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
	var outline := _shape.duplicate()
	outline.append(_shape[0])
	draw_polyline(outline, Color.BLACK, 6.0, true)
	draw_colored_polygon(_shape, PAPER)


# ---------------------------------------------------------------- kamera

static func ease_io(p: float) -> float:
	return 2.0 * p * p if p < 0.5 else 1.0 - pow(-2.0 * p + 2.0, 2.0) / 2.0


func _view(tex: Texture2D, a: Vector3, b: Vector3, p: float) -> void:
	_cur = tex
	if tex == null:
		return
	var c := a.lerp(b, ease_io(clampf(p, 0.0, 1.0)))
	var ts := tex.get_size()
	_s = maxf(_inner.x / ts.x, _inner.y / ts.y) * c.z
	var vw := _inner.x / _s
	var vh := _inner.y / _s
	_src = Rect2(clampf(c.x * ts.x - vw * 0.5, 0.0, ts.x - vw),
			clampf(c.y * ts.y - vh * 0.5, 0.0, ts.y - vh), vw, vh)


func _update_cam() -> void:
	if scene_id == &"eyes":
		# mata tertutup dulu, lalu berkedip ke gambar mata terbuka
		if time < EYES_SWAP:
			_view(res.tex.p01a, Vector3(0.5, 0.5, 1.0), Vector3(0.5, 0.5, 1.08), time / 6.0)
		else:
			_view(res.tex.p01b, Vector3(0.5, 0.41, 1.02), Vector3(0.5, 0.41, 1.1), (time - EYES_SWAP) / 6.0)
		var m := _image_layer.material as ShaderMaterial
		var w := clampf(time / 2.0, 0.0, 1.0)
		m.set_shader_parameter("lod", lerpf(3.2, 0.0, w))
		m.set_shader_parameter("brightness", lerpf(0.45, 1.0, w))
		return
	_view(_tex, _cam_a, _cam_b, (time - _cam_delay) / _cam_dur)


## Titik di gambar sumber -> titik di layar panel
func map(p: Vector2) -> Vector2:
	return (p - _src.position) * _s


# ---------------------------------------------------------------- noise & helper

static func hash2(x: float, y: float, s: float = 0.0) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453, 1.0)


static func vnoise(x: float, y: float, s: float = 0.0) -> float:
	var xi := floorf(x)
	var yi := floorf(y)
	var xf := x - xi
	var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := hash2(xi, yi, s)
	var b := hash2(xi + 1.0, yi, s)
	var c := hash2(xi, yi + 1.0, s)
	var d := hash2(xi + 1.0, yi + 1.0, s)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


static func flick(t: float, s: float = 0.0) -> float:
	return 0.86 + 0.14 * vnoise(t * 8.0, s, 3.0) + 0.05 * sin(t * 21.0 + s)


func _glow(c: CanvasItem, pos: Vector2, r: float, col: Color, a: float) -> void:
	if a <= 0.0 or r <= 0.0:
		return
	c.draw_texture_rect(res.glow, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(col.r, col.g, col.b, a))


func _lantern(c: CanvasItem, ip: Vector2, k: float = 1.0, seed: float = 0.0, t: float = -1.0) -> void:
	var f := flick(time if t < 0.0 else t, seed)
	var p := map(ip)
	_glow(c, p, 260.0 * _s * k, WARM, 0.28 * f)
	_glow(c, p, 70.0 * _s * k, WARM_CORE, 0.35 * f)


func _motes(c: CanvasItem, ic: Vector2, rx: float, ry: float, n: int, seed: float,
		col: Color = Color(1.0, 0.82, 0.55), sz: float = 2.4) -> void:
	for i in range(n):
		var sp := 0.25 + hash2(i, 3, seed) * 0.5
		var life := fposmod(time * sp * 0.35 + hash2(i, 4, seed), 1.0)
		var px := ic.x + (hash2(i, 1, seed) - 0.5) * 2.0 * rx + sin(time * sp * 2.0 + i) * rx * 0.08
		var py := ic.y + (hash2(i, 2, seed) - 0.5) * 2.0 * ry - life * ry * 0.9
		var a := sin(life * PI) * 0.85
		var r := (sz * 0.6 + hash2(i, 5, seed) * sz) * maxf(0.6, _s * 1.4) * 3.0
		_glow(c, map(Vector2(px, py)), r, col, a)


func _rain(c: CanvasItem, a: float, seed: float = 1.0) -> void:
	var W := _inner.x
	var H := _inner.y
	var col := Color(0.75, 0.84, 1.0, a)
	for i in range(90):
		var sp := 0.8 + hash2(i, 1, seed) * 0.6
		var x := fposmod(hash2(i, 2, seed) * W * 1.2 + time * 90.0 * sp, W * 1.2) - W * 0.1
		var y := fposmod(hash2(i, 3, seed) * H + time * 900.0 * sp, H + 60.0) - 30.0
		c.draw_line(Vector2(x, y), Vector2(x - 7, y + 26), col, 1.4, true)


func _smoke(c: CanvasItem, p: float, seed: float = 1.0, col: Color = Color(0.086, 0.031, 0.157)) -> void:
	var W := _inner.x
	var H := _inner.y
	for i in range(34):
		var a := hash2(i, 1, seed) * TAU + time * 0.12 * (hash2(i, 2, seed) - 0.5)
		var edge := 1.08 - p * 0.3 + sin(time * 0.9 + i) * 0.04
		var pos := Vector2(W * 0.5 + cos(a) * W * 0.55 * edge, H * 0.5 + sin(a) * H * 0.6 * edge)
		var r := (0.12 + hash2(i, 3, seed) * 0.13) * W
		_glow(c, pos, r, col, 0.75 * p)


func _vignette(c: CanvasItem, a: float) -> void:
	c.draw_texture_rect(res.vignette, Rect2(Vector2.ZERO, _inner), false, Color(1, 1, 1, a))


## Kelopak mata hitam dari atas dan bawah (0 = terbuka, 1 = tertutup)
func _lids(c: CanvasItem, l: float) -> void:
	if l <= 0.001:
		return
	var W := _inner.x
	var H := _inner.y
	var h := H * 0.5 * l
	var top := PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, h)])
	var bot := PackedVector2Array([Vector2(0, H), Vector2(W, H), Vector2(W, H - h)])
	for i in range(1, 16):
		var u := 1.0 - i / 16.0
		var x := W * u
		var bulge := 4.0 * u * (1.0 - u)
		top.append(Vector2(x, h + H * 0.11 * l * bulge))
		bot.append(Vector2(x, H - h - H * 0.08 * l * bulge))
	top.append(Vector2(0, h))
	bot.append(Vector2(0, H - h))
	c.draw_colored_polygon(top, Color.BLACK)
	c.draw_colored_polygon(bot, Color.BLACK)


# ---------------------------------------------------------------- isi panel

const EYES_SWAP := 2.1


func _draw_layer(c: CanvasItem, kind: int) -> void:
	if _cur == null:
		return
	match kind:
		L_IMAGE:
			c.draw_texture_rect_region(_cur, Rect2(Vector2.ZERO, _inner), _src)
			if scene_id == &"fade":
				_draw_fade_plate(c)
		L_ADD:
			_draw_add(c)
		L_MIX:
			_draw_mix(c)


func _draw_add(c: CanvasItem) -> void:
	match scene_id:
		&"eyes":
			if time >= EYES_SWAP:
				var pu := 0.8 + 0.2 * sin(time * 3.0)
				_glow(c, Vector2(_inner.x * 0.32, _inner.y * 0.55), _inner.x * 0.12, Color(0.47, 0.78, 1.0), 0.10 * pu)
				_glow(c, Vector2(_inner.x * 0.68, _inner.y * 0.55), _inner.x * 0.12, Color(0.47, 0.78, 1.0), 0.10 * pu)
		&"lying":
			_lantern(c, Vector2(1305, 345))
			_motes(c, Vector2(830, 300), 60, 300, 26, 3.0, Color(0.78, 0.9, 1.0), 2.0)
		&"sit":
			_lantern(c, Vector2(905, 340), 1.1)
		&"elian":
			_lantern(c, Vector2(412, 330), 1.5, 2.0)
			_motes(c, Vector2(420, 330), 170, 220, 40, 7.0)
		&"fiora_sad":
			_lantern(c, Vector2(1135, 290), 1.2, 1.0)
		&"elian_point":
			_lantern(c, Vector2(652, 790), 1.0, 4.0)
			_motes(c, Vector2(260, 240), 180, 240, 30, 5.0, Color(0.75, 0.92, 1.0), 2.0)
		&"tower":
			var o := map(Vector2(450, 70))
			var pu := 0.85 + 0.15 * sin(time * 2.4)
			_glow(c, o, 300.0 * _s, Color(1.0, 0.94, 0.78), 0.5 * pu)
			_glow(c, o, 90.0 * _s, Color(1.0, 1.0, 0.94), 0.6 * pu)
			_lantern(c, Vector2(480, 1225), 0.6, 3.0)
			_motes(c, Vector2(450, 500), 160, 420, 40, 9.0, Color(1.0, 0.94, 0.78), 2.4)
			_rain(c, 0.12)
		&"dark":
			var p := clampf(time / 3.4, 0.0, 1.0) * 0.55
			var dip := 0.55 if (p > 0.5 and vnoise(time * 12.0, 1.0, 4.0) > 0.75) else 1.0
			_lantern(c, Vector2(990, 285), 1.3 * dip, 5.0, time * 1.5)
			var pu := 0.7 + 0.3 * sin(time * 4.0)
			_glow(c, map(Vector2(493, 98)), 90.0 * _s, TEAL, 0.6 * pu)
		&"norch":
			var e := map(Vector2(688, 245))
			var pu := 0.7 + 0.3 * sin(time * 5.0)
			_glow(c, e, 240.0 * _s, TEAL, 0.45 * pu)
			_glow(c, e, 60.0 * _s, Color(0.86, 1.0, 0.98), 0.5 * pu)
		&"two_f":
			_glow(c, map(Vector2(840, 600)), 300.0 * _s, WARM, 0.18 * flick(time))
		&"two_e":
			_lantern(c, Vector2(240, 870), 1.2, 6.0)
		&"hands":
			_lantern(c, Vector2(690, 470), 1.4, 7.0)
			_motes(c, Vector2(690, 470), 520, 300, 46, 11.0)
		&"fade":
			var dp := clampf((time - FADE_START) / FADE_LEN, 0.0, 1.0)
			_glow(c, map(Vector2(1105, 330)), 380.0 * _s, Color(1.0, 0.78, 0.5), 0.32 * sin(dp * PI))
			_draw_fade_sparks(c)
			_lantern(c, Vector2(762, 482), 1.3, 8.0)
		&"finale":
			var pu := 0.85 + 0.15 * sin(time * 1.6)
			_glow(c, map(Vector2(800, 0)), 700.0 * _s, Color(1.0, 0.96, 0.84), 0.3 * pu)
			_lantern(c, Vector2(806, 545), 0.7, 9.0)
			_motes(c, Vector2(800, 360), 260, 360, 60, 13.0, Color(1.0, 0.94, 0.78), 2.6)
			_rain(c, 0.16, 3.0)


func _draw_mix(c: CanvasItem) -> void:
	match scene_id:
		&"eyes":
			var T := EYES_SWAP
			_vignette(c, 0.6 if time < T else 0.45)
			var l := 0.0
			if time > T - 0.25 and time < T:
				l = (time - (T - 0.25)) / 0.25
			elif time >= T and time < T + 0.55:
				l = 1.0 - ease_io((time - T) / 0.55)
			elif time >= T + 0.9 and time < T + 1.15:
				l = 0.55 * sin((time - T - 0.9) / 0.25 * PI)
			_lids(c, l)
		&"lying":
			# tetesan air jatuh ke genangan
			var ph := fposmod(time * 0.5, 1.0)
			var d := map(Vector2(700, ph * 600.0))
			c.draw_circle(d, maxf(2.0, 5.0 * _s), Color(0.75, 0.9, 1.0, 0.9))
			if ph > 0.9:
				var pp := map(Vector2(700, 612))
				var r := (ph - 0.9) * 10.0 * 50.0 * _s
				c.draw_arc(pp, r, 0.0, TAU, 32, Color(0.75, 0.9, 1.0, 1.0 - (ph - 0.9) * 10.0), 2.0, true)
		&"sit":
			_smoke(c, 0.25, 4.0)
		&"elian":
			_vignette(c, 0.35)
		&"dark":
			var p := clampf(time / 3.4, 0.0, 1.0) * 0.55
			_smoke(c, p, 2.0)
			_vignette(c, 0.35 + p * 0.2)
		&"norch":
			_smoke(c, 0.55, 8.0, Color(0.07, 0.024, 0.118))
		&"fade":
			_draw_fade_bits(c)


# ---------------------------------------------------------------- Elian memudar

func _prep_fade() -> void:
	var img: Image = res.img_data.get("p13", null)
	var e := FADE_ELLIPSE
	var ih := float(img.get_height()) if img else 672.0
	var y := maxf(0.0, e.position.y - e.size.y)
	while y < minf(ih, e.position.y + e.size.y):
		var x := e.position.x - e.size.x
		while x < e.position.x + e.size.x:
			var nx := (x + CELL * 0.5 - e.position.x) / e.size.x
			var ny := (y + CELL * 0.5 - e.position.y) / e.size.y
			if Vector2(nx, ny).length() <= 0.98:
				var th := 0.62 * vnoise(x * 0.02, y * 0.02, 5.0) + 0.38 * (y / ih) + 0.06 * hash2(x, y, 2.0)
				var col := Color(0.27, 0.2, 0.35)
				if img:
					col = img.get_pixel(clampi(int(x + CELL * 0.5), 0, img.get_width() - 1),
							clampi(int(y + CELL * 0.5), 0, img.get_height() - 1))
				_cells.append([x, y, th, col, hash2(x, y, 9.0)])
			x += CELL
		y += CELL


func _fade_p() -> float:
	return clampf((time - FADE_START) / FADE_LEN, 0.0, 1.0) * 1.12


## Sel yang sudah lepas digantikan latar buram (tempat Elian berdiri tadi)
func _draw_fade_plate(c: CanvasItem) -> void:
	var p := _fade_p()
	if p <= 0.0:
		return
	var plate: Texture2D = res.tex.p13_plate
	for cell in _cells:
		if cell[2] < p:
			var src := Rect2(cell[0] - 1.0, cell[1] - 1.0, CELL + 2.0, CELL + 2.0)
			c.draw_texture_rect_region(plate, Rect2(map(src.position), src.size * _s), src)


func _cell_motion(cell: Array, age: float) -> Vector2:
	return Vector2(cell[0] + CELL * 0.5 + sin(age * 5.0 + cell[4] * 9.0) * 40.0 * age,
			cell[1] + CELL * 0.5 - age * 260.0 * (0.6 + cell[4] * 0.6))


## Potongan tubuh Elian yang terangkat dan berubah jadi bara
func _draw_fade_bits(c: CanvasItem) -> void:
	var p := _fade_p()
	if p <= 0.0:
		return
	for cell in _cells:
		var age: float = (p - cell[2]) / 0.32
		if age <= 0.0 or age >= 1.0:
			continue
		var pos := map(_cell_motion(cell, age))
		var r := CELL * _s * (1.05 - age * 0.75)
		var m := minf(1.0, age * 1.6)
		var base: Color = cell[3]
		var col := base.lerp(Color(1.0, 0.77, 0.47), m)
		col.a = (1.0 - age) * 0.85
		c.draw_circle(pos, r, col)


func _draw_fade_sparks(c: CanvasItem) -> void:
	var p := _fade_p()
	if p <= 0.0:
		return
	for cell in _cells:
		if cell[4] <= 0.55:
			continue
		var age: float = (p - cell[2]) / 0.32
		if age <= 0.0 or age >= 1.0:
			continue
		var pos := map(_cell_motion(cell, age))
		_glow(c, pos, CELL * _s * 1.2, Color(1.0, 0.75, 0.43), (1.0 - age) * 0.8)
