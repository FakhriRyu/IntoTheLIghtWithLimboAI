extends CanvasLayer
## Layar pilih upgrade: game di-pause, tiga kartu acak muncul, player memilih satu.
## Muncul saat naik level atau saat peti berisi relik (RunState.pending_picks).
## Navigasi: kiri/kanan (A/D atau panah), pilih dengan Space/Enter/J atau klik.

## Input diabaikan sebentar setelah layar muncul, supaya tombol Attack/Jump yang
## sedang ditekan-tekan saat bertarung tidak langsung memilih kartu.
const INPUT_LOCK := 0.35
const CARD_SIZE := Vector2(172, 176)

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var subtitle: Label = $Root/Subtitle
@onready var cards: HBoxContainer = $Root/Cards

var _showing: bool = false
var _locked: bool = false
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	RunState.pick_requested.connect(_on_pick_requested)
	# kalau ada antrian dari area sebelumnya (mis. naik level tepat di pintu keluar)
	if not RunState.pending_picks.is_empty():
		_on_pick_requested.call_deferred()


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
		title.text = "RELIK DITEMUKAN"
		subtitle.text = "Pilih satu berkah"
	else:
		title.text = "NAIK LEVEL!  Lv %d" % RunState.level
		subtitle.text = "Pilih satu upgrade"

	_build_cards(choices)
	Audio.play_sfx(&"level_up", 0.0, 0.0)
	root.visible = true
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.15)

	_set_locked(true)
	await get_tree().create_timer(INPUT_LOCK, true, false, true).timeout
	_set_locked(false)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _set_locked(v: bool) -> void:
	_locked = v
	for b in _buttons:
		b.disabled = v


func _build_cards(choices: Array[Dictionary]) -> void:
	for c in cards.get_children():
		c.queue_free()
	_buttons.clear()

	for u in choices:
		var b := _make_card(u)
		cards.add_child(b)
		_buttons.append(b)

	# fokus kiri/kanan melingkar
	for i in range(_buttons.size()):
		var b := _buttons[i]
		b.focus_neighbor_left = b.get_path_to(_buttons[(i - 1 + _buttons.size()) % _buttons.size()])
		b.focus_neighbor_right = b.get_path_to(_buttons[(i + 1) % _buttons.size()])


func _make_card(u: Dictionary) -> Button:
	var rarity: int = u["rarity"]
	var col: Color = Upgrades.RARITY_COLORS[rarity]

	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _card_style(col, 0.35, 1))
	b.add_theme_stylebox_override("hover", _card_style(col, 0.7, 2))
	b.add_theme_stylebox_override("focus", _card_style(col, 1.0, 3))
	b.add_theme_stylebox_override("pressed", _card_style(col, 1.0, 3))
	b.add_theme_stylebox_override("disabled", _card_style(col, 0.25, 1))
	b.pressed.connect(_on_card_pressed.bind(u["id"]))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)

	var stack := RunState.upgrade_count(u["id"])
	box.add_child(_label(Upgrades.RARITY_NAMES[rarity].to_upper(), 10, col))
	box.add_child(_label(u["name"], 15, Color.WHITE))
	var desc := _label(u["desc"], 11, Color(0.85, 0.86, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	box.add_child(_label("%d / %d" % [stack + 1, u["max"]], 10, Color(0.6, 0.62, 0.7)))
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _card_style(col: Color, border_alpha: float, border: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	s.border_color = Color(col, border_alpha)
	s.set_border_width_all(border)
	s.set_corner_radius_all(4)
	return s


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
