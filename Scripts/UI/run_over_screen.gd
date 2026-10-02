extends CanvasLayer
## Layar akhir run: muncul saat player mati, menampilkan ringkasan run (level,
## musuh dikalahkan, ikon upgrade yang dikumpulkan), lalu pilih "Coba Lagi"
## (run baru dari awal) atau "Menu Utama". Gayanya sama dengan HUD dan kartu
## upgrade (Assets/ui/pixel_theme.tres).

const INPUT_LOCK := 0.8
const ICON_DIR := "res://Assets/ui/icons/"
const FRAME_TEX := preload("res://Assets/ui/slot_frame.png")
const SLOT_SIZE := Vector2(37, 37)

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var level_value: Label = $Root/Panel/Body/Stats/Level/Value
@onready var kills_value: Label = $Root/Panel/Body/Stats/Kills/Value
@onready var upgrade_grid: GridContainer = $Root/Panel/Body/Upgrades
@onready var no_upgrades: Label = $Root/Panel/Body/NoUpgrades
@onready var buttons: HBoxContainer = $Root/Buttons
@onready var retry_button: Button = $Root/Buttons/Retry
@onready var menu_button: Button = $Root/Buttons/Menu
@onready var hint: Label = $Root/Hint

var _ready_to_restart: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	RunState.run_ended.connect(_on_run_ended)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	for b in [retry_button, menu_button]:
		b.mouse_entered.connect(func() -> void: if _ready_to_restart: b.grab_focus())
		b.focus_entered.connect(func() -> void:
			if _ready_to_restart:
				Audio.play_sfx(&"card_move", -8.0, 0.03))


func _on_run_ended() -> void:
	get_tree().paused = true
	level_value.text = str(RunState.level)
	kills_value.text = str(RunState.kills)
	_build_upgrades()
	hint.text = "%s / Space  pilih     %s / %s  ganti" % [
		Settings.key_name(&"Attack"), Settings.key_name(&"Left"), Settings.key_name(&"Right")]

	root.visible = true
	buttons.visible = false
	hint.visible = false
	Audio.play_sfx(&"game_over", 0.0, 0.0)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(INPUT_LOCK, true, false, true).timeout
	buttons.visible = true
	hint.visible = true
	_ready_to_restart = true
	retry_button.grab_focus()


## Ikon tiap upgrade yang diambil dalam wajik berwarna rarity, plus jumlah tumpukan
func _build_upgrades() -> void:
	for c in upgrade_grid.get_children():
		c.queue_free()
	for u in Upgrades.ALL:
		var n := RunState.upgrade_count(u["id"])
		if n <= 0:
			continue
		var slot := Control.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.tooltip_text = u["name"]

		var frame := TextureRect.new()
		frame.texture = FRAME_TEX
		frame.self_modulate = Upgrades.RARITY_COLORS[u["rarity"]]
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(frame)

		var icon_path: String = ICON_DIR + u["id"] + ".png"
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size = Vector2(32, 32)
			icon.position = Vector2(2, 3)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)

		if n > 1:
			var count := Label.new()
			count.text = "x%d" % n
			count.position = Vector2(22, 16)
			count.add_theme_color_override("font_color", Color(0.49, 1.0, 0.42))
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(count)
		upgrade_grid.add_child(slot)
	no_upgrades.visible = RunState.upgrades.is_empty()
	upgrade_grid.visible = not no_upgrades.visible


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_restart:
		return
	# A/D dan J ikut dipakai, sama dengan menu lain di dalam game
	if event.is_action_pressed("Left") or event.is_action_pressed("Right"):
		(menu_button if retry_button.has_focus() else retry_button).grab_focus()
	elif event.is_action_pressed("Attack") or event.is_action_pressed("Jump"):
		var b := get_viewport().gui_get_focus_owner() as Button
		(b if b else retry_button).pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_retry_pressed() -> void:
	if not _ready_to_restart:
		return
	_ready_to_restart = false
	Audio.play_sfx(&"card_pick", -2.0, 0.0)
	RunState.restart_run()


func _on_menu_pressed() -> void:
	if not _ready_to_restart:
		return
	_ready_to_restart = false
	Audio.play_sfx(&"card_pick", -2.0, 0.0)
	RunState.quit_to_menu()
