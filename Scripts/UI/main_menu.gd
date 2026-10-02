extends Node2D
## Main menu: hutan malam yang gelap, ksatria menatap cahaya di cakrawala.
## "Mulai" membuka pilihan kesulitan; setelah dipilih ksatria berlari ke arah
## cahaya sementara layar memutih, lalu run baru dimulai dari RunState.run_start_scene.
##
## Navigasi: W/S atau panah untuk memilih, J / Space / Enter untuk memilih,
## Esc untuk kembali dari panel kontrol / kesulitan. Mouse dan sentuhan juga bisa.

## Warna layar saat "masuk ke cahaya", juga warna awal transisi ke level
const LIGHT_WHITE := Color(1.0, 0.96, 0.86)
const INTRO_TIME := 1.4
const START_RUN_TIME := 1.7
## Jarak penanda (nyala kecil) di kiri tombol yang terpilih
const MARKER_GAP := 14.0
## Penjelasan tiap kesulitan, urut sesuai RunState.Difficulty
const DIFFICULTY_DESC := [
	"Cahaya bertahan 40 detik.\nObor di menara mengisi cahayamu.",
	"Cahaya mulai 40 detik, makin singkat\nsampai 25 detik. Obor lebih jarang.",
	"Cahaya hanya bertahan 25 detik.\nTanpa obor.",
]

@onready var warrior: AnimatedSprite2D = $Warrior
@onready var lantern: PointLight2D = $Warrior/Lantern
@onready var horizon_light: PointLight2D = $HorizonLight
@onready var horizon_glow: Sprite2D = $HorizonGlow
@onready var rays: TextureRect = $FX/Rays

@onready var ui: Control = $UI/Root
@onready var title: Label = $UI/Root/Title
@onready var subtitle: Label = $UI/Root/Subtitle
@onready var menu: VBoxContainer = $UI/Root/Menu
@onready var marker: Control = $UI/Root/Marker
@onready var hint: Label = $UI/Root/Hint
@onready var controls_panel: Control = $UI/Root/ControlsPanel
@onready var fade: ColorRect = $UI/Fade
@onready var key_grid: GridContainer = $UI/Root/ControlsPanel/Box/VBox/Grid
@onready var difficulty_panel: Control = $UI/Root/DifficultyPanel
@onready var difficulty_options: VBoxContainer = $UI/Root/DifficultyPanel/Box/VBox/Options
@onready var difficulty_desc: Label = $UI/Root/DifficultyPanel/Box/VBox/Desc

@onready var start_button: Button = $UI/Root/Menu/Start
@onready var controls_button: Button = $UI/Root/Menu/Controls
@onready var quit_button: Button = $UI/Root/Menu/Quit

var _buttons: Array[Button] = []
var _difficulty_buttons: Array[Button] = []
## Run sudah dimulai (animasi menuju cahaya): semua input menu diabaikan
var _starting: bool = false
## Input menu dikunci selama intro dan setelah sebuah pilihan dijalankan
var _accepting: bool = false
var _time: float = 0.0
var _base_lantern: float
var _base_horizon: float
var _base_glow_alpha: float
var _base_rays_alpha: float
var _marker_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	_base_lantern = lantern.energy
	_base_horizon = horizon_light.energy
	_base_glow_alpha = horizon_glow.modulate.a
	_base_rays_alpha = rays.modulate.a

	# Keluar tidak ada artinya di web
	quit_button.visible = not OS.has_feature("web")
	for b: Button in menu.get_children():
		if b.visible:
			_buttons.append(b)
			b.focus_entered.connect(_on_button_focused.bind(b))
			b.mouse_entered.connect(_on_button_hovered.bind(b))
	start_button.pressed.connect(_on_start_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	marker.draw.connect(_draw_marker)
	controls_panel.visible = false
	controls_panel.gui_input.connect(_on_controls_panel_input)
	difficulty_panel.visible = false
	for i in range(difficulty_options.get_child_count()):
		var b := difficulty_options.get_child(i) as Button
		_difficulty_buttons.append(b)
		b.pressed.connect(_on_difficulty_chosen.bind(i))
		b.focus_entered.connect(_on_difficulty_focused.bind(i))
		b.mouse_entered.connect(func() -> void:
			if difficulty_panel.visible and not b.has_focus():
				b.grab_focus())
	_refresh_key_labels()

	warrior.play(&"idle")
	Audio.play_music(&"cave", 2.0)
	_play_intro()


func _process(delta: float) -> void:
	_time += delta
	# lentera berkedip halus, cahaya cakrawala bernapas pelan
	var flicker := 0.92 + 0.05 * sin(_time * 9.0) + 0.03 * sin(_time * 23.0 + 1.3)
	lantern.energy = _base_lantern * flicker
	var breath := 0.5 + 0.5 * sin(_time * 0.9)
	horizon_light.energy = _base_horizon * lerpf(0.9, 1.08, breath)
	horizon_glow.modulate.a = _base_glow_alpha * lerpf(0.85, 1.0, breath)
	rays.modulate.a = _base_rays_alpha * lerpf(0.75, 1.0, 0.5 + 0.5 * sin(_time * 0.6 + 2.0))
	if marker.visible:
		marker.queue_redraw()


# ---------------------------------------------------------------- intro

func _play_intro() -> void:
	fade.color = Color.BLACK
	fade.modulate.a = 1.0
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	hint.modulate.a = 0.0
	marker.visible = false
	for b in _buttons:
		b.modulate.a = 0.0

	var t := create_tween()
	t.tween_property(fade, "modulate:a", 0.0, INTRO_TIME).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(title, "modulate:a", 1.0, 1.2).set_delay(0.5)
	t.parallel().tween_property(title, "position:y", title.position.y, 1.2) \
			.from(title.position.y - 10.0).set_delay(0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(subtitle, "modulate:a", 1.0, 0.8).set_delay(1.1)
	for i in range(_buttons.size()):
		t.parallel().tween_property(_buttons[i], "modulate:a", 1.0, 0.4).set_delay(1.3 + i * 0.12)
	t.parallel().tween_property(hint, "modulate:a", 1.0, 0.6).set_delay(1.8)
	t.tween_callback(_on_intro_done)


func _on_intro_done() -> void:
	_accepting = true
	marker.visible = true
	start_button.grab_focus()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if difficulty_panel.visible:
		_difficulty_input(event)
		return
	if controls_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("Attack") \
				or event.is_action_pressed("Jump") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_close_controls()
		return
	if not _accepting:
		return
	# W/S dan J ikut menggerakkan menu, sama dengan tombol di dalam game
	if event.is_action_pressed("Up"):
		_move_focus(-1)
	elif event.is_action_pressed("Down"):
		_move_focus(1)
	elif event.is_action_pressed("Attack"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused:
			focused.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_focus(step: int) -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	var i := _buttons.find(focused)
	i = 0 if i == -1 else wrapi(i + step, 0, _buttons.size())
	_buttons[i].grab_focus()


func _on_button_hovered(b: Button) -> void:
	if _accepting and not b.has_focus():
		b.grab_focus()


func _on_button_focused(b: Button) -> void:
	if not _accepting:
		return
	Audio.play_sfx(&"card_move", -6.0, 0.03)
	# penanda meluncur ke tombol yang dipilih
	var target_y := menu.position.y + b.position.y + b.size.y * 0.5
	if _marker_tween and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = create_tween()
	_marker_tween.tween_property(marker, "position:y", target_y, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Nyala kecil berbentuk belah ketupat piksel, berdenyut seperti api lilin
func _draw_marker() -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 6.0)
	var core := Color(1.0, 0.93, 0.7, pulse)
	var halo := Color(1.0, 0.7, 0.35, 0.35 * pulse)
	var x := -MARKER_GAP
	for r in [Rect2(x - 3, -6, 6, 12), Rect2(x - 6, -3, 12, 6)]:
		marker.draw_rect(r, halo)
	for r in [Rect2(x - 1, -4, 2, 8), Rect2(x - 3, -2, 6, 4), Rect2(x - 2, -3, 4, 6)]:
		marker.draw_rect(r, core)


# ---------------------------------------------------------------- pilihan

func _on_start_pressed() -> void:
	if not _accepting:
		return
	_accepting = false
	Audio.play_sfx(&"card_pick", -4.0, 0.0)
	marker.visible = false
	difficulty_panel.visible = true
	difficulty_panel.modulate.a = 0.0
	_difficulty_buttons[Settings.difficulty].grab_focus()
	create_tween().tween_property(difficulty_panel, "modulate:a", 1.0, 0.2)


func _difficulty_input(event: InputEvent) -> void:
	if _starting:
		return
	if difficulty_panel.modulate.a < 1.0 and not event.is_action_pressed("ui_cancel"):
		return
	if event.is_action_pressed("ui_cancel"):
		_close_difficulty()
	elif event.is_action_pressed("Up") or event.is_action_pressed("Down"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		var i := _difficulty_buttons.find(focused)
		var step := -1 if event.is_action_pressed("Up") else 1
		i = 1 if i == -1 else wrapi(i + step, 0, _difficulty_buttons.size())
		_difficulty_buttons[i].grab_focus()
	elif event.is_action_pressed("Attack"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused:
			focused.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_difficulty_focused(i: int) -> void:
	difficulty_desc.text = DIFFICULTY_DESC[i]
	if difficulty_panel.visible:
		Audio.play_sfx(&"card_move", -6.0, 0.03)


func _close_difficulty() -> void:
	Audio.play_sfx(&"card_move", -6.0, 0.03)
	var t := create_tween()
	t.tween_property(difficulty_panel, "modulate:a", 0.0, 0.15)
	t.tween_callback(func() -> void:
		difficulty_panel.visible = false
		_accepting = true
		marker.visible = true
		start_button.grab_focus())


func _on_difficulty_chosen(i: int) -> void:
	if _starting or not difficulty_panel.visible or difficulty_panel.modulate.a < 1.0:
		return
	_starting = true
	Settings.set_difficulty(i)
	for b in _difficulty_buttons:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_run_sequence()


func _start_run_sequence() -> void:
	Audio.play_sfx(&"card_pick", 0.0, 0.0)

	# ksatria berlari menuju cahaya, dunia memutih
	warrior.play(&"run")
	var t := create_tween().set_parallel(true)
	t.tween_property(ui, "modulate:a", 0.0, 0.4)
	t.tween_property(warrior, "position:x", warrior.position.x + 260.0, START_RUN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(horizon_light, "texture_scale", horizon_light.texture_scale * 2.2, START_RUN_TIME)
	t.tween_property(self, "_base_horizon", _base_horizon * 2.5, START_RUN_TIME)
	t.tween_property(self, "_base_rays_alpha", minf(_base_rays_alpha * 2.0, 1.0), START_RUN_TIME)
	fade.color = LIGHT_WHITE
	fade.modulate.a = 0.0
	t.tween_property(fade, "modulate:a", 1.0, START_RUN_TIME * 0.7) \
			.set_delay(START_RUN_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(_begin_run)


func _begin_run() -> void:
	RunState.reset_run()
	# Lapisan putih ditaruh di root supaya tetap ada setelah scene berganti,
	# lalu memudar dan membuka level pertama.
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = LIGHT_WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var t := layer.create_tween()
	t.tween_interval(0.15)
	t.tween_property(rect, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(layer.queue_free)
	get_tree().change_scene_to_file(RunState.run_start_scene)


func _on_controls_pressed() -> void:
	if not _accepting:
		return
	_accepting = false
	Audio.play_sfx(&"card_pick", -4.0, 0.0)
	controls_panel.visible = true
	controls_panel.modulate.a = 0.0
	controls_panel.grab_focus()
	create_tween().tween_property(controls_panel, "modulate:a", 1.0, 0.2)


## Tombol di panel kontrol mengikuti pengaturan (bisa diganti dari menu jeda)
func _refresh_key_labels() -> void:
	var k := func(action: StringName) -> String: return Settings.key_name(action)
	key_grid.get_node("K1").text = "%s / %s" % [k.call(&"Left"), k.call(&"Right")]
	key_grid.get_node("K2").text = k.call(&"Jump")
	key_grid.get_node("K3").text = "%s + %s" % [k.call(&"Down"), k.call(&"Jump")]
	key_grid.get_node("K4").text = k.call(&"Attack")
	key_grid.get_node("K5").text = k.call(&"Dash")
	key_grid.get_node("K6").text = k.call(&"Up")
	hint.text = "%s/%s  pilih     %s / Space  konfirmasi" % [k.call(&"Up"), k.call(&"Down"), k.call(&"Attack")]


func _on_controls_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_controls()


func _close_controls() -> void:
	Audio.play_sfx(&"card_move", -6.0, 0.03)
	var t := create_tween()
	t.tween_property(controls_panel, "modulate:a", 0.0, 0.15)
	t.tween_callback(func() -> void:
		controls_panel.visible = false
		_accepting = true
		controls_button.grab_focus())


func _on_quit_pressed() -> void:
	if not _accepting:
		return
	_accepting = false
	Audio.stop_music(0.6)
	fade.color = Color.BLACK
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.6)
	t.tween_callback(get_tree().quit)
