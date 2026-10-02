extends CanvasLayer
## Layar pilih upgrade: game di-pause, tiga kartu acak muncul, player memilih satu.
## Muncul saat naik level atau saat peti berisi relik (RunState.pending_picks).
## Navigasi: kiri/kanan (A/D atau panah), pilih dengan Space/Enter/J atau klik.
## Tiap kartu: ikon upgrade dalam wajik berwarna rarity, nama, deskripsi (angka
## disorot hijau), dan penanda tumpukan. Tekstur dibuat oleh tools/build_ui_art.py.

## Input diabaikan sebentar setelah layar muncul, supaya tombol Attack/Jump yang
## sedang ditekan-tekan saat bertarung tidak langsung memilih kartu.
const INPUT_LOCK := 0.35
## Harus sama dengan CARD_W/CARD_H di tools/build_ui_art.py
const CARD_SIZE := Vector2(156, 236)
const GLOW_PAD := 6
const FOCUS_SCALE := 1.06
const ICON_DIR := "res://Assets/ui/icons/"

const NAME_COLOR := Color(1.0, 0.88, 0.3)
const NUMBER_COLOR := "#7dff6a"
const STACK_COLOR := Color(0.49, 1.0, 0.42)
const GLOW_COLOR := Color(1.0, 0.86, 0.3)
const UNFOCUSED_TINT := Color(0.7, 0.72, 0.8)

const PANEL_TEX := preload("res://Assets/ui/card_panel.png")
const GLOW_TEX := preload("res://Assets/ui/card_glow.png")
const FRAME_TEX := preload("res://Assets/ui/card_icon_frame.png")
const PIP_ON := preload("res://Assets/ui/pip_on.png")
const PIP_OFF := preload("res://Assets/ui/pip_off.png")

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var subtitle: Label = $Root/Subtitle
@onready var cards: HBoxContainer = $Root/Cards
@onready var hint: Label = $Root/Hint

var _showing: bool = false
var _locked: bool = false
var _buttons: Array[Button] = []
var _glows: Array[TextureRect] = []
var _time: float = 0.0
var _number_regex := RegEx.create_from_string("[+-]?\\d+(?:[.,]\\d+)?%?")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	RunState.pick_requested.connect(_on_pick_requested)
	# kalau ada antrian dari area sebelumnya (mis. naik level tepat di pintu keluar)
	if not RunState.pending_picks.is_empty():
		_on_pick_requested.call_deferred()


func _process(delta: float) -> void:
	if not _showing:
		return
	_time += delta
	# pendar kartu terpilih berdenyut pelan
	for g in _glows:
		if g.visible:
			g.modulate.a = 0.75 + 0.25 * sin(_time * 6.0)


func _on_pick_requested() -> void:
	if _showing or RunState.pending_picks.is_empty():
		return
	_show_next()


func _show_next() -> void:
	var source: String = RunState.pending_picks[0]
	var min_rarity := Upgrades.Rarity.RARE if source == "relic" else Upgrades.Rarity.COMMON
	var choices := RunState.roll_choices(3, min_rarity)
	if choices.is_empty():
		# semua upgrade sudah penuh: ganti dengan cahaya penuh dan sedikit HP
		RunState.pending_picks.pop_front()
		RunState.add_light(RunState.max_light())
		RunState.heal_player(1)
		if not RunState.pending_picks.is_empty():
			_show_next()
		return

	_showing = true
	get_tree().paused = true
	if source == "relic":
		title.text = "RELIK DITEMUKAN!"
		subtitle.text = "Pilih satu berkah"
	else:
		title.text = "NAIK LEVEL!"
		subtitle.text = "Lv %d  -  pilih satu upgrade" % RunState.level

	hint.text = "%s / %s  pilih     %s / Space  ambil" % [
		Settings.key_name(&"Left"), Settings.key_name(&"Right"), Settings.key_name(&"Attack")]
	_build_cards(choices)
	Audio.play_sfx(&"level_up", 0.0, 0.0)
	root.visible = true
	_animate_in()

	_set_locked(true)
	await get_tree().create_timer(INPUT_LOCK, true, false, true).timeout
	_set_locked(false)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _animate_in() -> void:
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.15)

	# judul "meletup" lalu mengecil ke ukuran normal
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(title, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# kartu muncul satu per satu
	for i in range(_buttons.size()):
		var b := _buttons[i]
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.06 * i)
		t.tween_property(b, "modulate:a", 1.0, 0.15)


func _set_locked(v: bool) -> void:
	_locked = v
	for b in _buttons:
		b.disabled = v


func _build_cards(choices: Array[Dictionary]) -> void:
	for c in cards.get_children():
		c.queue_free()
	_buttons.clear()
	_glows.clear()

	for u in choices:
		var b := _make_card(u)
		cards.add_child(b)
		_buttons.append(b)

	# fokus kiri/kanan melingkar
	for i in range(_buttons.size()):
		var b := _buttons[i]
		b.focus_neighbor_left = b.get_path_to(_buttons[(i - 1 + _buttons.size()) % _buttons.size()])
		b.focus_neighbor_right = b.get_path_to(_buttons[(i + 1) % _buttons.size()])
		b.focus_entered.connect(_on_card_focused.bind(i))
		b.mouse_entered.connect(func(): if not _locked: b.grab_focus())
	_on_card_focused(-1)


func _make_card(u: Dictionary) -> Button:
	var rarity: int = u["rarity"]
	var col: Color = Upgrades.RARITY_COLORS[rarity]

	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.pivot_offset = CARD_SIZE / 2.0
	b.focus_mode = Control.FOCUS_ALL
	var panel := StyleBoxTexture.new()
	panel.texture = PANEL_TEX
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, panel)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_on_card_pressed.bind(u["id"]))

	# pendar di sekeliling kartu, hanya tampil saat kartu terpilih
	var glow := TextureRect.new()
	glow.texture = GLOW_TEX
	glow.position = Vector2(-GLOW_PAD, -GLOW_PAD)
	glow.modulate = GLOW_COLOR
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glow)
	_glows.append(glow)

	# wajik ikon menonjol di tepi atas kartu, cincinnya berwarna rarity
	var frame := TextureRect.new()
	frame.texture = FRAME_TEX
	var frame_size := FRAME_TEX.get_size()
	frame.position = Vector2(roundf((CARD_SIZE.x - frame_size.x) / 2.0), -floorf(frame_size.y / 2.0))
	frame.self_modulate = col
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)

	var icon_path: String = ICON_DIR + u["id"] + ".png"
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(48, 48)
		icon.position = ((frame_size - icon.size) / 2.0).floor()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)

	b.add_child(_label(u["name"], NAME_COLOR, Rect2(8, 34, CARD_SIZE.x - 16, 22)))
	b.add_child(_label(Upgrades.RARITY_NAMES[rarity].to_upper(), col, Rect2(8, 54, CARD_SIZE.x - 16, 22)))

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.scroll_active = false
	desc.add_theme_constant_override("line_separation", -3)
	desc.position = Vector2(12, 88)
	desc.size = Vector2(CARD_SIZE.x - 24, CARD_SIZE.y - 88 - 46)
	desc.text = "[center]%s[/center]" % _number_regex.sub(u["desc"], "[color=%s]$0[/color]" % NUMBER_COLOR, true)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(desc)
	_fit_desc.call_deferred(desc)

	# penanda tumpukan: teks "BARU!" / "LV n" dan pip sebanyak batas tumpukan
	var stack := RunState.upgrade_count(u["id"])
	var footer := "BARU!" if stack == 0 else "LV %d" % (stack + 1)
	b.add_child(_label(footer, STACK_COLOR, Rect2(8, CARD_SIZE.y - 44, CARD_SIZE.x - 16, 22)))

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.position = Vector2(0, CARD_SIZE.y - 19)
	pips.size = Vector2(CARD_SIZE.x, 7)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(int(u["max"])):
		var pip := TextureRect.new()
		pip.texture = PIP_ON if i <= stack else PIP_OFF
		if i < stack:
			pip.modulate = STACK_COLOR.darkened(0.25)
		elif i == stack:
			pip.modulate = Color(1.0, 1.0, 0.7)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	b.add_child(pips)
	return b


## Pengaman untuk deskripsi yang terlalu panjang: rapatkan jarak baris sampai
## semua teks muat di area deskripsi, supaya tidak ada kalimat yang terpotong.
func _fit_desc(desc: RichTextLabel) -> void:
	var sep := desc.get_theme_constant("line_separation")
	while desc.get_content_height() > desc.size.y and sep > -8:
		sep -= 1
		desc.add_theme_constant_override("line_separation", sep)
	if desc.get_content_height() > desc.size.y:
		push_warning("Deskripsi upgrade terlalu panjang untuk kartu: " + desc.get_parsed_text())


func _label(text: String, color: Color, rect: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## idx -1 = belum ada yang terpilih (semua kartu tampil normal)
func _on_card_focused(idx: int) -> void:
	for i in range(_buttons.size()):
		var b := _buttons[i]
		var on := i == idx
		_glows[i].visible = on
		var target_scale := Vector2.ONE * (FOCUS_SCALE if on else 1.0)
		var target_tint := Color.WHITE if on or idx < 0 else UNFOCUSED_TINT
		var t := b.create_tween().set_parallel()
		t.tween_property(b, "scale", target_scale, 0.1)
		t.tween_property(b, "self_modulate", target_tint, 0.1)
		# self_modulate tidak menurun ke anak; redupkan isi kartu juga
		for c in b.get_children():
			if c is CanvasItem and c != _glows[i]:
				t.tween_property(c, "modulate", target_tint, 0.1)


func _unhandled_input(event: InputEvent) -> void:
	if not _showing or _locked:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var idx: int = _buttons.find(focused) if focused is Button else -1
	# tombol gerak (A/D) dan Attack juga bisa dipakai, bukan hanya ui_*
	if event.is_action_pressed("Left") or event.is_action_pressed("Right"):
		var step := -1 if event.is_action_pressed("Left") else 1
		_buttons[(maxi(idx, 0) + step + _buttons.size()) % _buttons.size()].grab_focus()
		get_viewport().set_input_as_handled()
		Audio.play_sfx(&"card_move", -6.0)
	elif event.is_action_pressed("Attack") and idx >= 0:
		_buttons[idx].pressed.emit()
		get_viewport().set_input_as_handled()


func _on_card_pressed(id: String) -> void:
	if _locked or not _showing:
		return
	_locked = true
	Audio.play_sfx(&"card_pick", -2.0, 0.0)
	RunState.apply_upgrade(id)
	RunState.pending_picks.pop_front()
	root.visible = false
	_showing = false
	if RunState.pending_picks.is_empty():
		get_tree().paused = false
	else:
		_show_next()
