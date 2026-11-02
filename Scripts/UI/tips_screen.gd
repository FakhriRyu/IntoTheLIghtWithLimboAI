extends CanvasLayer
## Layar "Tips Bermain": beberapa halaman berisi ilustrasi animasi (TipsArt) di
## kiri dan penjelasan di kanan, dengan titik halaman dan panah di bawah.
## Muncul otomatis sekali setelah prolog (PlayerHUD, Settings.tips_seen) dan bisa
## dibuka lagi dari menu jeda. Game di-pause selama layar ini terbuka.
##
## Navigasi: panah kiri/kanan atau geser layar; Kiri/Kanan, Serang/Lompat/Enter =
## lanjut; Esc / Pause = lewati.

signal closed

const TipsArt := preload("res://Scripts/UI/tips_art.gd")
const THEME := preload("res://Assets/ui/pixel_theme.tres")
const PIP_ON := preload("res://Assets/ui/pip_on.png")
const PIP_OFF := preload("res://Assets/ui/pip_off.png")
const ARROW_LEFT := preload("res://Assets/button/kiri.png")
const ARROW_LEFT_P := preload("res://Assets/button/kiri-press.png")
const ARROW_RIGHT := preload("res://Assets/button/kanan.png")
const ARROW_RIGHT_P := preload("res://Assets/button/kanan-press.png")

const INPUT_LOCK := 0.35
const SWIPE_MIN := 50.0
const TITLE_COLOR := Color(1, 0.9, 0.22)
const HEADING_COLOR := Color(1.0, 0.78, 0.4)
## Warna sorotan di teks (BBCode)
const GOLD := "#ffd25a"
const CYAN := "#66f2ff"
const RED := "#ff6a55"

## Judul tiap halaman; ilustrasi dari _build_art(), teks dari _page_text()
const PAGES := [
	"BERGERAK & BERTARUNG",
	"KALAHKAN MUSUH",
	"JANGAN BIARKAN PADAM",
	"NAIK LEVEL, PILIH KEKUATAN",
	"PETI & BAHAYA",
	"ATUR SESUKAMU",
]

var _from_menu := false
var _was_paused := false
var _page := 0
var _locked := true
var _touch_start := {}

var _content: Control
var _stage: Control
var _heading: Label
var _text: RichTextLabel
var _pips: HBoxContainer
var _prev: TextureButton
var _next: TextureButton
var _start: Button
var _skip: Button


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS


## Buka di halaman pertama. from_menu: dibuka dari menu jeda (tombol "Tutup",
## game tetap ter-pause setelah ditutup)
func open(from_menu := false) -> void:
	_from_menu = from_menu
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	_show_page(0, false)
	Audio.play_sfx(&"card_pick", -6.0, 0.0)
	var root: Control = get_child(0)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.2)
	get_tree().create_timer(INPUT_LOCK, true).timeout.connect(func() -> void: _locked = false)


func close() -> void:
	if _locked:
		return
	Audio.play_sfx(&"card_pick", -6.0, 0.0)
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- UI

func _build() -> void:
	var root := Control.new()
	root.theme = THEME
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var title := Label.new()
	title.text = "TIPS BERMAIN"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 8
	title.offset_bottom = 64
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_color_override("font_outline_color", Color(0.16, 0.07, 0.02))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_font_size_override("font_size", 44)
	root.add_child(title)

	_skip = Button.new()
	_skip.text = "Tutup" if _from_menu else "Lewati"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.custom_minimum_size = Vector2(84, 26)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -96
	_skip.offset_right = -12
	_skip.offset_top = 22
	_skip.offset_bottom = 48
	_skip.pressed.connect(close)
	root.add_child(_skip)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 290)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -168
	panel.offset_bottom = 122
	root.add_child(panel)

	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	panel.add_child(_content)

	_stage = Control.new()
	_stage.custom_minimum_size = TipsArt.STAGE
	_stage.clip_contents = true
	_stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.add_child(_stage)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	_content.add_child(col)

	_heading = Label.new()
	_heading.add_theme_color_override("font_color", HEADING_COLOR)
	_heading.add_theme_font_size_override("font_size", 28)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_heading)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_constant_override("line_separation", 2)
	col.add_child(_text)

	# baris bawah: < titik halaman >  [Mulai!]
	var nav := HBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 14)
	nav.offset_left = -200
	nav.offset_right = 200
	nav.offset_top = -78
	nav.offset_bottom = -30
	root.add_child(nav)

	_prev = _arrow(ARROW_LEFT, ARROW_LEFT_P)
	_prev.pressed.connect(_go.bind(-1))
	nav.add_child(_prev)
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 8)
	_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in PAGES.size():
		var p := TextureRect.new()
		p.texture = PIP_OFF
		p.custom_minimum_size = Vector2(14, 14)
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_pips.add_child(p)
	nav.add_child(_pips)
	_next = _arrow(ARROW_RIGHT, ARROW_RIGHT_P)
	_next.pressed.connect(_go.bind(1))
	nav.add_child(_next)
	_start = Button.new()
	_start.text = "Tutup" if _from_menu else "Mulai!"
	_start.focus_mode = Control.FOCUS_NONE
	_start.custom_minimum_size = Vector2(110, 40)
	_start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_start.add_theme_color_override("font_color", TITLE_COLOR)
	_start.pressed.connect(close)
	nav.add_child(_start)


func _arrow(normal: Texture2D, pressed: Texture2D) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = normal
	b.texture_pressed = pressed
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(48, 48)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _go(step: int) -> void:
	var to := clampi(_page + step, 0, PAGES.size() - 1)
	if to == _page:
		return
	Audio.play_sfx(&"card_move", -6.0, 0.03)
	_show_page(to, true)


func _show_page(i: int, animate: bool) -> void:
	_page = i
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	_build_art(i)
	_heading.text = PAGES[i]
	_text.text = _page_text(i)
	for k in _pips.get_child_count():
		(_pips.get_child(k) as TextureRect).texture = PIP_ON if k == i else PIP_OFF
	var last := i == PAGES.size() - 1
	_prev.modulate.a = 0.25 if i == 0 else 1.0
	_prev.disabled = i == 0
	_next.visible = not last
	_start.visible = last
	if animate:
		_content.modulate.a = 0.0
		_content.create_tween().tween_property(_content, "modulate:a", 1.0, 0.15)


## Ilustrasi dibangun di wadah baru per halaman; Tween-nya terikat ke wadah itu,
## jadi ikut berhenti saat halaman diganti dan wadahnya dibuang.
func _build_art(i: int) -> void:
	var art := Control.new()
	art.size = TipsArt.STAGE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(art)
	match i:
		0: TipsArt.page_move(art, Settings.touch_controls)
		1: TipsArt.page_enemy(art)
		2: TipsArt.page_light(art)
		3: TipsArt.page_level(art)
		4: TipsArt.page_chest(art)
		_: TipsArt.page_settings(art)


func _hl(text: String, color := GOLD) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func _page_text(i: int) -> String:
	match i:
		0:
			var how: String
			if Settings.touch_controls:
				how = "Pakai tombol %s untuk bergerak, lalu %s, %s, dan %s untuk menghindar." % [
					_hl("kiri / kanan"), _hl("Lompat"), _hl("Serang"), _hl("Dash")]
			else:
				var k := func(a: StringName) -> String: return _hl(Settings.key_name(a))
				how = "Gerak %s / %s, lompat %s, serang %s, dash %s untuk menghindar." % [
					k.call(&"Left"), k.call(&"Right"), k.call(&"Jump"), k.call(&"Attack"), k.call(&"Dash")]
			return how + "\n\nPanjat menara dan cari %s untuk naik ke area berikutnya." % _hl("pilar cahaya")
		1:
			return ("Musuh yang kalah menjatuhkan %s (emas), %s (biru), dan kadang %s (merah).\n\n"
				+ "Dekati saja, semuanya akan tertarik ke Fiora.") % [
				_hl("kepingan cahaya"), _hl("orb XP", CYAN), _hl("orb HP", RED)]
		2:
			return ("Cahaya Fiora terus %s setiap detik. Kalau habis, Fiora %s dan perjalanan berakhir.\n\n"
				+ "Isi lagi dengan %s dari musuh, atau berdiri dekat %s.") % [
				_hl("meredup"), _hl("padam", RED), _hl("kepingan cahaya"), _hl("obor / anglo")]
		3:
			return ("Kumpulkan %s sampai bar penuh untuk naik level, lalu %s dari 3 kartu upgrade.\n\n"
				+ "Upgrade bertahan sampai perjalanan berakhir. Pilih yang cocok dengan gayamu!") % [
				_hl("XP", CYAN), _hl("pilih 1")]
		4:
			var open_key := "tekan Atas" if Settings.touch_controls else "tekan %s" % _hl(Settings.key_name(&"Up"))
			return ("Pukul %s atau %s di depannya. Isinya bisa cahaya, ramuan, relik, atau minyak lentera, "
				+ "tapi awas %s!\n\nHindari %s, karena melukai Fiora.") % [
				_hl("peti"), open_key, _hl("peti terkutuk", RED), _hl("duri", RED)]
		_:
			var extra := "atur %s tombol sentuh." % _hl("letak, ukuran, dan transparansi") \
				if Settings.touch_controls else "ganti tombol keyboard di menu %s." % _hl("Kontrol")
			return ("Tekan %s lalu %s untuk mengatur volume dan %s\n\n"
				+ "Tips ini bisa dibuka lagi dari menu Jeda.") % [_hl("Jeda"), _hl("Pengaturan"), extra]


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# geser kiri/kanan untuk ganti halaman
		if event.pressed:
			_touch_start[event.index] = event.position
		elif _touch_start.has(event.index):
			var d: Vector2 = event.position - _touch_start[event.index]
			_touch_start.erase(event.index)
			if not _locked and absf(d.x) > SWIPE_MIN and absf(d.x) > absf(d.y) * 1.5:
				_go(1 if d.x < 0 else -1)
		return
	if _locked or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("Pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("Right") or event.is_action_pressed("ui_right"):
		_go(1)
	elif event.is_action_pressed("Left") or event.is_action_pressed("ui_left"):
		_go(-1)
	elif event.is_action_pressed("Attack") or event.is_action_pressed("Jump") \
			or event.is_action_pressed("ui_accept"):
		if _page == PAGES.size() - 1:
			close()
		else:
			_go(1)
	else:
		return
	get_viewport().set_input_as_handled()
