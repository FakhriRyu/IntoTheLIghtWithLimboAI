extends CanvasLayer
## Menu jeda: dibuka dengan tombol Pause (Esc / P) atau tombol jeda di HUD.
## Halaman: utama (lanjut, pengaturan, kontrol, menu utama), pengaturan (volume
## master/musik/efek suara, layar penuh) dan kontrol (ganti tombol keyboard).
## Isi tiap halaman dibangun dari kode; semua nilai disimpan lewat autoload Settings.
##
## Navigasi: W/S atau panah memilih, A/D menggeser slider, J / Enter memilih,
## Esc kembali satu halaman (di halaman utama: lanjut bermain).

const LABEL_COLOR := Color(0.82, 0.84, 0.9)
const LABEL_FOCUS_COLOR := Color(1.0, 0.9, 0.55)
const KEY_COLOR := Color(1.0, 0.78, 0.4)
const WARN_COLOR := Color(1.0, 0.45, 0.35)
const ROW_SIZE := Vector2(280, 24)
const VOLUME_STEP := 10.0

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var body: VBoxContainer = $Root/Panel/Body
@onready var hint: Label = $Root/Hint

var _showing: bool = false
## Halaman yang sedang tampil: "main", "settings", "controls"
var _page: String = ""
## Aksi yang sedang menunggu tombol baru (halaman kontrol)
var _waiting_action: StringName = &""
var _confirm_quit: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false


## Buka menu jeda. Diabaikan kalau game sedang di-pause oleh layar lain
## (pilih upgrade, akhir run).
func open() -> void:
	if _showing or get_tree().paused:
		return
	_showing = true
	get_tree().paused = true
	Audio.play_sfx(&"card_pick", -6.0, 0.0)
	root.visible = true
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.12)
	_show_main()


func close() -> void:
	if not _showing:
		return
	_showing = false
	_waiting_action = &""
	root.visible = false
	get_tree().paused = false


# ---------------------------------------------------------------- halaman

func _clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func _show_main(focus_index: int = 0) -> void:
	_clear()
	_page = "main"
	_confirm_quit = false
	title.text = "JEDA"
	var buttons: Array[Button] = [
		_button("Lanjutkan", close),
		_button("Pengaturan", _show_settings),
		_button("Kontrol", _show_controls),
		_button("Menu Utama", _on_quit_pressed),
	]
	for b in buttons:
		body.add_child(b)
	# konfirmasi keluar batal kalau pilihan pindah
	buttons[3].focus_exited.connect(func() -> void:
		_confirm_quit = false
		buttons[3].text = "Menu Utama"
		buttons[3].remove_theme_color_override("font_focus_color"))
	_set_hint("%s/%s  pilih     %s / Enter  ok     Esc  lanjut" % [
		Settings.key_name(&"Up"), Settings.key_name(&"Down"), Settings.key_name(&"Attack")])
	buttons[clampi(focus_index, 0, buttons.size() - 1)].grab_focus.call_deferred()


func _show_settings() -> void:
	_clear()
	_page = "settings"
	title.text = "PENGATURAN"
	body.add_child(_section("SUARA"))
	var first := _volume_row("Master", "master")
	_volume_row("Musik", "music")
	_volume_row("Efek suara", "sfx")
	if Settings.can_fullscreen():
		body.add_child(_section("LAYAR"))
		var fs := _button(_fullscreen_text(), func() -> void: pass)
		fs.pressed.connect(func() -> void:
			Settings.set_fullscreen(not Settings.fullscreen)
			fs.text = _fullscreen_text())
		body.add_child(fs)
	body.add_child(_spacer())
	body.add_child(_button("Kembali", _show_main.bind(1)))
	_set_hint("%s/%s  ubah volume     Esc  kembali" % [
		Settings.key_name(&"Left"), Settings.key_name(&"Right")])
	first.grab_focus.call_deferred()


func _show_controls() -> void:
	_clear()
	_page = "controls"
	title.text = "KONTROL"
	var first: Button = null
	for a in Settings.REBINDABLE:
		var b := _key_row(a["action"], a["label"])
		body.add_child(b)
		if first == null:
			first = b
	body.add_child(_spacer())
	body.add_child(_button("Kembalikan default", func() -> void:
		Settings.reset_keys()
		Audio.play_sfx(&"card_pick", -6.0, 0.0)
		_show_controls()))
	body.add_child(_button("Kembali", _show_main.bind(2)))
	_set_hint("Pilih aksi, lalu tekan tombol baru     Esc  kembali")
	first.grab_focus.call_deferred()


func _set_hint(text: String) -> void:
	hint.text = text


func _fullscreen_text() -> String:
	return "Layar penuh:  %s" % ("AKTIF" if Settings.fullscreen else "MATI")


# ---------------------------------------------------------------- komponen

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = ROW_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.play_sfx(&"card_pick", -8.0, 0.0)
		on_press.call())
	b.focus_entered.connect(_on_focus_moved)
	b.mouse_entered.connect(b.grab_focus)
	return b


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.78))
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 4)
	return c


## Baris "Nama  [====o---]  80%"; mengembalikan slider-nya
func _volume_row(text: String, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.custom_minimum_size = ROW_SIZE
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size.x = 84
	name_label.add_theme_color_override("font_color", LABEL_COLOR)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = VOLUME_STEP
	slider.value = roundf(Settings.volumes[key] * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 12
	slider.focus_mode = Control.FOCUS_ALL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 44
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % int(slider.value)
	value_label.add_theme_color_override("font_color", KEY_COLOR)
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v)
		Settings.set_volume(key, v / 100.0)
		# bunyi kecil supaya volume efek suara langsung terdengar
		Audio.play_sfx(&"card_move", -4.0, 0.0))
	slider.focus_entered.connect(func() -> void:
		name_label.add_theme_color_override("font_color", LABEL_FOCUS_COLOR)
		_on_focus_moved())
	slider.focus_exited.connect(func() -> void:
		name_label.add_theme_color_override("font_color", LABEL_COLOR))
	slider.mouse_entered.connect(slider.grab_focus)
	body.add_child(row)
	return slider


## Tombol berisi nama aksi di kiri dan tombol keyboard-nya di kanan
func _key_row(action: StringName, text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = ROW_SIZE
	b.focus_mode = Control.FOCUS_ALL

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_bottom = -2
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", LABEL_COLOR)
	row.add_child(name_label)

	var key_label := Label.new()
	key_label.text = Settings.key_name(action)
	key_label.add_theme_color_override("font_color", KEY_COLOR)
	row.add_child(key_label)

	b.pressed.connect(func() -> void:
		if _waiting_action != &"":
			return
		Audio.play_sfx(&"card_pick", -8.0, 0.0)
		_waiting_action = action
		key_label.text = "tekan tombol..."
		key_label.add_theme_color_override("font_color", WARN_COLOR))
	b.focus_entered.connect(func() -> void:
		name_label.add_theme_color_override("font_color", LABEL_FOCUS_COLOR)
		_on_focus_moved())
	b.focus_exited.connect(func() -> void:
		name_label.add_theme_color_override("font_color", LABEL_COLOR))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _on_focus_moved() -> void:
	if _showing and root.modulate.a > 0.5:
		Audio.play_sfx(&"card_move", -8.0, 0.03)


func _on_quit_pressed() -> void:
	var b := get_viewport().gui_get_focus_owner() as Button
	if not _confirm_quit:
		# tekan sekali lagi untuk benar-benar keluar
		_confirm_quit = true
		if b:
			b.text = "Yakin? Run akan hilang"
			b.add_theme_color_override("font_focus_color", WARN_COLOR)
		return
	_showing = false
	RunState.quit_to_menu()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# tangkap tombol baru sebelum diproses sebagai aksi apa pun
	if _waiting_action == &"" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var focus_index := _focus_index()
	if code != KEY_ESCAPE:
		Settings.rebind(_waiting_action, code)
		Audio.play_sfx(&"card_pick", -6.0, 0.0)
	_waiting_action = &""
	_show_controls()
	var items := _focusables()
	if focus_index >= 0 and focus_index < items.size():
		items[focus_index].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _showing:
		if event.is_action_pressed("Pause"):
			get_viewport().set_input_as_handled()
			open()
		return

	if event.is_action_pressed("Pause") or event.is_action_pressed("ui_cancel"):
		if _page == "main":
			close()
		else:
			_show_main(1 if _page == "settings" else 2)
	elif event.is_action_pressed("Up") or event.is_action_pressed("Down"):
		var items := _focusables()
		var step := -1 if event.is_action_pressed("Up") else 1
		items[wrapi(_focus_index() + step, 0, items.size())].grab_focus()
	elif event.is_action_pressed("Left") or event.is_action_pressed("Right"):
		var slider := get_viewport().gui_get_focus_owner() as HSlider
		if slider == null:
			return
		slider.value += VOLUME_STEP * (-1 if event.is_action_pressed("Left") else 1)
	elif event.is_action_pressed("Attack"):
		var b := get_viewport().gui_get_focus_owner() as Button
		if b == null:
			return
		b.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


## Kontrol yang bisa dipilih di halaman ini, urut dari atas
func _focusables() -> Array[Control]:
	var out: Array[Control] = []
	for c in body.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button:
			out.append(c)
		elif c is HBoxContainer:
			for s in c.get_children():
				if s is HSlider:
					out.append(s)
	return out


func _focus_index() -> int:
	var focused := get_viewport().gui_get_focus_owner()
	return _focusables().find(focused)
