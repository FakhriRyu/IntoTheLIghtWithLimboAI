extends CanvasLayer
## Tombol sentuh di layar untuk Android: kiri/kanan dan atas/bawah di pojok kiri
## bawah, serang/lompat/dash di pojok kanan bawah. Tiap tombol adalah
## TouchScreenButton yang menekan aksi input yang sudah ada (Left, Right, Up,
## Down, Attack, Jump, Dash), jadi kode player tidak perlu tahu sumber inputnya.
## Jeda memakai tombol jeda HUD yang sudah ada.
##
## Dipasang oleh PlayerHUD hanya kalau Settings.touch_controls true.
## Disembunyikan saat game di-pause (menu jeda, pilih upgrade, akhir run);
## tombol yang sedang ditahan otomatis dilepas oleh TouchScreenButton saat pause.

const DIR := "res://Assets/button/"
## Tekstur 32x32 digambar 2x supaya cukup besar untuk jari
const BUTTON_SCALE := 2.0
## Tombol atas/bawah lebih kecil, jarang dipakai
const SMALL_SCALE := 1.5
const TEX_SIZE := 32.0
## Jarak dari tepi layar dan antar tombol, dalam piksel viewport
const MARGIN := 14.0
const GAP := 8.0
const OPACITY := 0.6

var _buttons := {}


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add(&"Left", "kiri", "kiri-press", BUTTON_SCALE, true)
	_add(&"Right", "kanan", "kanan-press", BUTTON_SCALE, true)
	_add(&"Up", "atas", "atas-press", SMALL_SCALE)
	_add(&"Down", "bawah", "bawah-press", SMALL_SCALE)
	_add(&"Attack", "Sword", "SwordPressed", BUTTON_SCALE)
	_add(&"Jump", "Jump", "JumpPressed", BUTTON_SCALE)
	_add(&"Dash", "Dash", "DashPressed", BUTTON_SCALE)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	visible = not get_tree().paused


## passby: tombol ikut tertekan saat jari digeser masuk dari tombol lain
## (geser dari kiri ke kanan tanpa mengangkat jari)
func _add(action: StringName, normal: String, pressed: String, s: float, passby := false) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = load(DIR + normal + ".png")
	b.texture_pressed = load(DIR + pressed + ".png")
	b.action = action
	b.passby_press = passby
	b.scale = Vector2(s, s)
	b.modulate.a = OPACITY
	# di-pause bersama game supaya tombol yang ditahan dilepas saat menu muncul
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(b)
	_buttons[action] = b


## Susun ulang tombol mengikuti ukuran viewport (rasio layar HP berbeda-beda)
## dan area aman (poni/kamera di layar).
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var inset := _safe_insets(view)
	var big := TEX_SIZE * BUTTON_SCALE
	var small := TEX_SIZE * SMALL_SCALE
	var left := MARGIN + inset.x
	var right := view.x - MARGIN - inset.z
	var bottom := view.y - MARGIN - inset.w

	# kiri: [kiri][kanan], di atasnya [atas][bawah] di tengah
	_place(&"Left", Vector2(left, bottom - big))
	_place(&"Right", Vector2(left + big + GAP, bottom - big))
	var pad_center := left + big + GAP / 2.0
	_place(&"Up", Vector2(pad_center - GAP / 2.0 - small, bottom - big - GAP - small))
	_place(&"Down", Vector2(pad_center + GAP / 2.0, bottom - big - GAP - small))

	# kanan: [serang][lompat], dash di atas lompat
	_place(&"Jump", Vector2(right - big, bottom - big))
	_place(&"Attack", Vector2(right - big * 2.0 - GAP, bottom - big))
	_place(&"Dash", Vector2(right - big, bottom - big * 2.0 - GAP))


func _place(action: StringName, pos: Vector2) -> void:
	_buttons[action].position = pos.round()


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
