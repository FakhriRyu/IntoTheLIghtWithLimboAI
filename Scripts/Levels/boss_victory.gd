class_name BossVictory
extends Node
## Taruh di scene arena bos. Saat bos (group "boss") mati: waktu melambat
## sebentar, player dibuat kebal dan cahayanya berhenti meredup, lalu setelah
## animasi death bos selesai (node bos dihapus) layar memutih dan pindah ke
## cutscene ending.
##
## Tidak mengubah AI bos: hanya mendengarkan sinyal Health.death dan
## tree_exited milik node bos.

@export_file("*.tscn") var ending_scene: String = "res://Scenes/Cutscene/ending_cutscene.tscn"
@export var boss_group: StringName = &"boss"
## Kecepatan waktu sesaat setelah pukulan terakhir
@export var slowmo_scale: float = 0.3
## Lama efek lambat (detik nyata)
@export var slowmo_time: float = 0.8
## Jeda setelah node bos hilang sebelum layar mulai memutih
@export var linger_time: float = 0.8
@export var fade_time: float = 1.2
## Batas tunggu animasi death, jaga-jaga kalau node bos tidak pernah dihapus
@export var max_wait: float = 6.0

const LIGHT_WHITE := Color(1.0, 0.96, 0.86)

var _boss: Node = null
var _triggered: bool = false


func _ready() -> void:
	# Bos di-instance bersama level; tunggu satu frame supaya sudah masuk group
	await get_tree().process_frame
	_boss = get_tree().get_first_node_in_group(boss_group)
	if _boss == null:
		push_warning("BossVictory: tidak ada node di group %s" % boss_group)
		return
	var health: Node = _boss.get_node_or_null("Health")
	if health and health.has_signal("death"):
		health.death.connect(_on_boss_death)


func _on_boss_death() -> void:
	if _triggered:
		return
	var player := get_tree().get_first_node_in_group("player")
	var ph: Node = player.get_node_or_null("Health") if player else null
	if ph and ph.has_method("is_alive") and not ph.is_alive():
		return  # player mati duluan: biarkan layar akhir run yang mengurus
	_triggered = true

	# Run dianggap menang: player tidak bisa terluka atau kehabisan cahaya lagi
	if player and "is_immune" in player:
		player.is_immune = true
	RunState.grace_timer = INF
	if Audio.has_method("stop_music"):
		Audio.stop_music(2.5)

	Engine.time_scale = slowmo_scale
	await get_tree().create_timer(slowmo_time, true, false, true).timeout
	Engine.time_scale = 1.0

	if is_instance_valid(_boss) and _boss.is_inside_tree():
		var waited := 0.0
		while is_instance_valid(_boss) and _boss.is_inside_tree() and waited < max_wait:
			await get_tree().process_frame
			waited += get_process_delta_time()
	await get_tree().create_timer(linger_time, true).timeout
	_fade_to_ending()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Layar memutih (sama seperti transisi main menu -> prolog), pindah scene,
## lalu putihnya memudar di atas cutscene ending.
func _fade_to_ending() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = LIGHT_WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0.0
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var t := layer.create_tween()
	t.tween_property(rect, "modulate:a", 1.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(ending_scene))
	t.tween_interval(0.3)
	t.tween_property(rect, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_callback(layer.queue_free)
