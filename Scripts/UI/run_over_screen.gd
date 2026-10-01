extends CanvasLayer
## Layar akhir run: muncul saat player mati, menampilkan ringkasan run,
## lalu Attack/Jump memulai run baru dari awal.

const INPUT_LOCK := 0.8

@onready var root: Control = $Root
@onready var title: Label = $Root/Title
@onready var summary: Label = $Root/Summary
@onready var hint: Label = $Root/Hint

var _ready_to_restart: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	RunState.run_ended.connect(_on_run_ended)


func _on_run_ended() -> void:
	get_tree().paused = true
	var picked: Array[String] = []
	for id in RunState.upgrades.keys():
		var u := Upgrades.get_by_id(id)
		if not u.is_empty():
			var n: int = RunState.upgrades[id]
			picked.append(u["name"] + ("" if n <= 1 else " x%d" % n))
	summary.text = "Level tercapai: %d\nMusuh dikalahkan: %d\n\n%s" % [
		RunState.level, RunState.kills,
		"Upgrade: " + ", ".join(picked) if not picked.is_empty() else "Tanpa upgrade"]

	root.visible = true
	hint.visible = false
	Audio.play_sfx(&"game_over", 0.0, 0.0)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(INPUT_LOCK, true, false, true).timeout
	hint.visible = true
	_ready_to_restart = true


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_restart:
		return
	if event.is_action_pressed("Attack") or event.is_action_pressed("Jump") \
			or event.is_action_pressed("ui_accept"):
		_ready_to_restart = false
		get_viewport().set_input_as_handled()
		RunState.restart_run()
