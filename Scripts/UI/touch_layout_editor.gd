extends CanvasLayer
## Editor tombol sentuh: dibuka dari Jeda > Pengaturan > Atur tombol sentuh.
## Game tetap ter-pause di belakang; tombol sentuh (TouchControls) ditampilkan
## dalam mode edit.
##   - seret tombol untuk memindah, ketuk untuk memilih
##   - slider Ukuran: ukuran tombol terpilih; slider Transparansi: semua tombol
##   - Samakan ukuran / Reset / Batal / Simpan
## Perubahan baru disimpan ke Settings saat Simpan (atau Esc / tombol Pause).

signal closed

const THEME := preload("res://Assets/ui/pixel_theme.tres")
const LABELS := {&"Left": "Kiri", &"Right": "Kanan", &"Attack": "Serang", &"Jump": "Lompat", &"Dash": "Dash"}
const SELECT_COLOR := Color(1.0, 0.85, 0.3)
const OUTLINE_COLOR := Color(0.8, 0.85, 1.0, 0.45)
const LABEL_COLOR := Color(0.82, 0.84, 0.9)
const VALUE_COLOR := Color(1.0, 0.78, 0.4)
## Tombol sedikit lebih mudah diambil daripada kotaknya
const GRAB_PAD := 8.0
const SNAP := 2.0

var _tc: Node = null
var _layout := {}
var _opacity := 0.6
var _selected: StringName = &""
## Jari yang sedang menyeret (-1 = tidak ada) dan selisih ke tengah tombol
var _drag_index := -1
var _drag_offset := Vector2.ZERO

var _bar: PanelContainer
var _overlay: Control
var _size_label: Label
var _size_slider: HSlider
var _size_value: Label
var _opacity_slider: HSlider
var _opacity_value: Label


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS


## Mulai mengatur TouchControls `tc`
func open(tc: Node) -> void:
	_tc = tc
	_tc.editing = true
	_layout = _tc.get_layout()
	_opacity = Settings.touch_opacity
	_build()
	_select(&"Jump")
	_preview()


func _finish(save: bool) -> void:
	_tc.editing = false
	if save:
		Settings.set_touch_layout(_layout)
		Settings.set_touch_opacity(_opacity)
		Audio.play_sfx(&"card_pick", -6.0, 0.0)
	_tc.reload()
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- UI

func _build() -> void:
	# redup di bawah tombol sentuh (layer 15) supaya game di belakang tidak mengganggu
	var dim_layer := CanvasLayer.new()
	dim_layer.layer = 14
	add_child(dim_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_layer.add_child(dim)

	var root := Control.new()
	root.theme = THEME
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	root.add_child(_overlay)

	var hint := Label.new()
	hint.text = "Seret tombol untuk memindah, ketuk untuk memilih"
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_left = 0
	hint.offset_right = 0
	hint.offset_top = 96
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	_bar = PanelContainer.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 8
	_bar.offset_right = -8
	_bar.offset_top = 6
	root.add_child(_bar)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_bar.add_child(rows)

	var sliders := HBoxContainer.new()
	sliders.add_theme_constant_override("separation", 8)
	rows.add_child(sliders)
	_size_label = _label("Ukuran", 96)
	sliders.add_child(_size_label)
	_size_slider = _slider(Settings.TOUCH_SCALE_MIN * 100.0, Settings.TOUCH_SCALE_MAX * 100.0)
	sliders.add_child(_size_slider)
	_size_value = _label("", 44, VALUE_COLOR)
	sliders.add_child(_size_value)
	sliders.add_child(_label("Transparansi", 0))
	_opacity_slider = _slider(Settings.TOUCH_OPACITY_MIN * 100.0, Settings.TOUCH_OPACITY_MAX * 100.0)
	sliders.add_child(_opacity_slider)
	_opacity_value = _label("", 44, VALUE_COLOR)
	sliders.add_child(_opacity_value)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(buttons)
	buttons.add_child(_button("Samakan ukuran", _on_same_size))
	buttons.add_child(_button("Reset", _on_reset))
	buttons.add_child(_button("Batal", _finish.bind(false)))
	buttons.add_child(_button("Simpan", _finish.bind(true)))

	_size_slider.value_changed.connect(_on_size_changed)
	_opacity_slider.value_changed.connect(_on_opacity_changed)
	_opacity_slider.set_value_no_signal(roundf(_opacity * 100.0))
	_opacity_value.text = "%d%%" % int(_opacity_slider.value)


func _label(text: String, min_w: float, color := LABEL_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = min_w
	l.add_theme_color_override("font_color", color)
	return l


func _slider(lo: float, hi: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 5.0
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(90, 12)
	s.focus_mode = Control.FOCUS_NONE
	return s


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Audio.play_sfx(&"card_pick", -8.0, 0.0)
		on_press.call())
	return b


func _draw_overlay() -> void:
	for action in _tc.actions():
		var r: Rect2 = _tc.button_rect(action)
		if action == _selected:
			_overlay.draw_rect(r.grow(3), SELECT_COLOR, false, 2.0)
		else:
			_overlay.draw_rect(r.grow(1), OUTLINE_COLOR, false, 1.0)


# ---------------------------------------------------------------- aksi

func _select(action: StringName) -> void:
	_selected = action
	var s: float = _layout[action]["scale"]
	_size_label.text = "Ukuran " + LABELS.get(action, String(action))
	_size_slider.set_value_no_signal(roundf(s * 100.0))
	_size_value.text = "%d%%" % int(_size_slider.value)
	_overlay.queue_redraw()


func _preview() -> void:
	_tc.preview(_layout, _opacity)
	_overlay.queue_redraw()


func _on_size_changed(v: float) -> void:
	_size_value.text = "%d%%" % int(v)
	_set_scale(_selected, v / 100.0)
	_preview()


## Ubah ukuran dengan titik tengah tetap, lalu jaga tombol tetap di dalam layar
func _set_scale(action: StringName, s: float) -> void:
	var center: Vector2 = _tc.center_of(_layout[action])
	center = _tc.clamp_center(center, s, _bar_bottom())
	_layout[action] = _tc.entry_from_center(center, s)


func _on_opacity_changed(v: float) -> void:
	_opacity_value.text = "%d%%" % int(v)
	_opacity = v / 100.0
	_preview()


func _on_same_size() -> void:
	var s: float = _layout[_selected]["scale"]
	for action in _layout:
		_set_scale(action, s)
	_preview()


func _on_reset() -> void:
	_layout = _tc.default_layout()
	_opacity = 0.6
	_opacity_slider.set_value_no_signal(60.0)
	_opacity_value.text = "60%"
	_select(_selected)
	_preview()


func _bar_bottom() -> float:
	return _bar.get_global_rect().end.y + 4.0


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _drag_index != -1 or _bar.get_global_rect().has_point(event.position):
				return
			var hit := _hit(event.position)
			if hit == &"":
				return
			_select(hit)
			_drag_index = event.index
			_drag_offset = _tc.center_of(_layout[hit]) - event.position
			get_viewport().set_input_as_handled()
		elif event.index == _drag_index:
			_drag_index = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _drag_index:
		var s: float = _layout[_selected]["scale"]
		var center: Vector2 = ((event.position + _drag_offset) / SNAP).round() * SNAP
		center = _tc.clamp_center(center, s, _bar_bottom())
		_layout[_selected] = _tc.entry_from_center(center, s)
		_preview()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(true)


## Tombol teratas di titik itu (yang terakhir digambar menang)
func _hit(pos: Vector2) -> StringName:
	var actions: Array = _tc.actions()
	for i in range(actions.size() - 1, -1, -1):
		if _tc.button_rect(actions[i]).grow(GRAB_PAD).has_point(pos):
			return actions[i]
	return &""
