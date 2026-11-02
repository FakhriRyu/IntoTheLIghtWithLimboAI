extends CanvasLayer
## Tombol sentuh di layar untuk Android: kiri/kanan di pojok kiri bawah,
## serang/lompat/dash di pojok kanan bawah. Tiap tombol adalah
## TouchScreenButton yang menekan aksi input yang sudah ada (Left, Right, Attack,
## Jump, Dash), jadi kode player tidak perlu tahu sumber inputnya.
## Jeda memakai tombol jeda HUD yang sudah ada.
##
## Letak, ukuran tiap tombol dan transparansi bisa diatur pemain lewat
## Jeda > Pengaturan > Atur tombol sentuh (TouchLayoutEditor), disimpan di
## Settings.touch_layout / touch_opacity. Aksi yang belum diatur memakai letak bawaan.
##
## Dipasang oleh PlayerHUD hanya kalau Settings.touch_controls true.
## Disembunyikan saat game di-pause (menu jeda, pilih upgrade, akhir run), kecuali
## sedang diatur; tombol yang sedang ditahan otomatis dilepas saat pause.

const DIR := "res://Assets/button/"
## [tekstur normal, tekstur ditekan, passby]
## passby: tombol ikut tertekan saat jari digeser masuk dari tombol lain
## (geser dari kiri ke kanan tanpa mengangkat jari)
const BUTTONS := {
	&"Left": ["kiri", "kiri-press", true],
	&"Right": ["kanan", "kanan-press", true],
	&"Attack": ["Sword", "SwordPressed", false],
	&"Jump": ["Jump", "JumpPressed", false],
	&"Dash": ["Dash", "DashPressed", false],
}
## Tekstur 32x32 digambar 2.5x (80 px) supaya cukup besar untuk jari;
## "scale" di layout dikalikan dengan nilai ini
const BUTTON_SCALE := 2.5
const TEX_SIZE := 32.0
## Jarak bawaan dari tepi layar dan antar tombol, dalam piksel viewport.
## Dibuat lega supaya tombol tidak mepet pojok layar HP (sudut membulat,
## gesture bar) dan mudah dijangkau jempol.
const MARGIN_X := 40.0
const MARGIN_BOTTOM := 28.0
const GAP := 10.0

## true selama TouchLayoutEditor terbuka: tombol tetap tampil walau game di-pause
var editing := false

var _buttons := {}
## Layout yang sedang dipakai (dari Settings, atau pratinjau editor)
var _layout := {}
var _opacity := 0.6


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_controls")
	for action in BUTTONS:
		var t: Array = BUTTONS[action]
		_add(action, t[0], t[1], t[2])
	get_viewport().size_changed.connect(_apply)
	Settings.changed.connect(reload)
	reload()


func _process(_delta: float) -> void:
	visible = editing or not get_tree().paused


func _add(action: StringName, normal: String, pressed: String, passby: bool) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = load(DIR + normal + ".png")
	b.texture_pressed = load(DIR + pressed + ".png")
	b.action = action
	b.passby_press = passby
	# di-pause bersama game supaya tombol yang ditahan dilepas saat menu muncul
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(b)
	_buttons[action] = b


# ---------------------------------------------------------------- layout

## Ambil ulang layout & transparansi dari Settings
func reload() -> void:
	if editing:
		return
	_layout = Settings.touch_layout.duplicate(true)
	_opacity = Settings.touch_opacity
	_apply()


## Terapkan layout sementara (dipakai editor), tanpa menyimpan
func preview(layout: Dictionary, opacity: float) -> void:
	_layout = layout.duplicate(true)
	_opacity = opacity
	_apply()


func actions() -> Array:
	return BUTTONS.keys()


## Layout efektif semua tombol (bawaan untuk yang belum diatur)
func get_layout() -> Dictionary:
	var out := default_layout()
	for action in _layout:
		out[action] = _layout[action].duplicate()
	return out


## Letak bawaan: kiri [kiri][kanan]; kanan [serang][lompat], dash di atas lompat.
## Jarak diukur dari tepi area aman ke tengah tombol.
func default_layout() -> Dictionary:
	var big := TEX_SIZE * BUTTON_SCALE
	var c1 := MARGIN_X + big / 2.0
	var c2 := c1 + big + GAP
	var low := MARGIN_BOTTOM + big / 2.0
	return {
		&"Left": {"side": 0, "x": c1, "y": low, "scale": 1.0},
		&"Right": {"side": 0, "x": c2, "y": low, "scale": 1.0},
		&"Jump": {"side": 1, "x": c1, "y": low, "scale": 1.0},
		&"Attack": {"side": 1, "x": c2, "y": low, "scale": 1.0},
		&"Dash": {"side": 1, "x": c1, "y": low + big + GAP, "scale": 1.0},
	}


## Ukuran tombol dalam piksel viewport untuk skala layout tertentu
func size_for(scale: float) -> float:
	return TEX_SIZE * BUTTON_SCALE * scale


## Kotak tombol di layar (piksel viewport)
func button_rect(action: StringName) -> Rect2:
	var b: TouchScreenButton = _buttons[action]
	return Rect2(b.position, Vector2.ONE * TEX_SIZE * b.scale.x)


## Area aman layar (di luar poni/kamera/gesture bar) dalam piksel viewport
func bounds() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var inset := _safe_insets(view)
	return Rect2(inset.x, inset.y, view.x - inset.x - inset.z, view.y - inset.y - inset.w)


## Titik tengah tombol di layar dari satu entri layout
func center_of(entry: Dictionary) -> Vector2:
	var b := bounds()
	var x: float = b.position.x + entry["x"] if int(entry["side"]) == 0 else b.end.x - entry["x"]
	return Vector2(x, b.end.y - entry["y"])


## Entri layout dari titik tengah di layar; sisi dipilih dari separuh layar
## tempat tombol berada, supaya tetap menempel di sisi itu di layar yang lebih lebar
func entry_from_center(center: Vector2, scale: float) -> Dictionary:
	var b := bounds()
	var side := 0 if center.x < b.get_center().x else 1
	var x := center.x - b.position.x if side == 0 else b.end.x - center.x
	return {"side": side, "x": x, "y": b.end.y - center.y, "scale": scale}


## Geser titik tengah supaya tombol seukuran itu tidak keluar dari area aman
func clamp_center(center: Vector2, scale: float, top_limit := 0.0) -> Vector2:
	var b := bounds()
	var half := size_for(scale) / 2.0
	var top := maxf(b.position.y, top_limit) + half
	return Vector2(
		clampf(center.x, b.position.x + half, maxf(b.end.x - half, b.position.x + half)),
		clampf(center.y, top, maxf(b.end.y - half, top)))


func _apply() -> void:
	var defaults := default_layout()
	for action in _buttons:
		var e: Dictionary = _layout.get(action, defaults[action])
		var s: float = e.get("scale", 1.0)
		var b: TouchScreenButton = _buttons[action]
		b.scale = Vector2.ONE * BUTTON_SCALE * s
		var center := clamp_center(center_of(e), s)
		b.position = (center - Vector2.ONE * size_for(s) / 2.0).round()
		b.modulate.a = _opacity


## Jarak area aman dari tiap tepi (kiri, atas, kanan, bawah) dalam piksel viewport
func _safe_insets(view: Vector2) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var k := view.x / win.x
	return Vector4(
		maxf(safe.position.x, 0.0) * k,
		maxf(safe.position.y, 0.0) * k,
		maxf(win.x - safe.end.x, 0.0) * k,
		maxf(win.y - safe.end.y, 0.0) * k)
