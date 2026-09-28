@tool
extends BTAction
## Menghilang lalu muncul kembali di jarak aman dari target (blink/teleport)
## Dipakai musuh tanpa animasi jalan yang tetap perlu menjaga jarak
## Urutan: animasi menghilang ➜ pindah posisi ➜ animasi muncul ➜ set cooldown
## Returns RUNNING selama proses blink berlangsung
## Returns SUCCESS setelah animasi muncul selesai (dan set cooldown)
## Returns FAILURE jika target tidak valid atau animasi tidak ditemukan

enum Phase { OUT, IN }

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## Path ke AnimationPlayer milik agent
@export var animation_player_path: NodePath = ^"AnimationPlayer"

## Animasi saat menghilang
@export var out_animation: StringName = &"fadeaway"

## Animasi saat muncul kembali
@export var in_animation: StringName = &"fadein"

## Jarak dari target tempat agent muncul kembali
@export var blink_distance: float = 260.0

## Durasi cooldown setelah blink (detik)
@export var cooldown_duration: float = 5.0

## Blackboard variable untuk menyimpan waktu cooldown berakhir
@export var cooldown_var: StringName = &"blink_cooldown_end"

var animation_player: AnimationPlayer

## Fase yang sedang berjalan
var phase: int = Phase.OUT
## Timer internal untuk fase yang sedang berjalan
var elapsed: float = 0.0


func _generate_name() -> String:
	return "BlinkAway from %s (%.0fpx, cd:%.1fs)" % [LimboUtility.decorate_var(target_var), blink_distance, cooldown_duration]


func _setup() -> void:
	if animation_player_path:
		animation_player = agent.get_node_or_null(animation_player_path)


func _enter() -> void:
	phase = Phase.OUT
	elapsed = 0.0

	if agent is CharacterBody2D:
		agent.velocity.x = 0

	if animation_player != null and animation_player.has_animation(out_animation):
		animation_player.play(out_animation)


func _tick(delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)

	if not is_instance_valid(target):
		return FAILURE

	if animation_player == null:
		return FAILURE

	if not animation_player.has_animation(out_animation) or not animation_player.has_animation(in_animation):
		return FAILURE

	elapsed += delta

	if phase == Phase.OUT:
		if elapsed < animation_player.get_animation(out_animation).length:
			return RUNNING

		_teleport_away(target)

		phase = Phase.IN
		elapsed = 0.0
		animation_player.play(in_animation)
		return RUNNING

	# Phase.IN
	if elapsed < animation_player.get_animation(in_animation).length:
		return RUNNING

	var cooldown_end_time: float = Time.get_ticks_msec() / 1000.0 + cooldown_duration
	blackboard.set_var(cooldown_var, cooldown_end_time)

	return SUCCESS


func _teleport_away(target: Node2D) -> void:
	# Arah menjauhi target secara horizontal; kalau sejajar persis, pakai arah hadap sekarang
	var away: float = signf(agent.global_position.x - target.global_position.x)
	if away == 0.0:
		away = -1.0

	# Ketinggian dipertahankan supaya agent tetap berpijak di lantai yang sama
	agent.global_position.x = target.global_position.x + away * blink_distance

	# Muncul kembali sambil menghadap target
	if agent.has_method("update_facing"):
		agent.update_facing(-away)


func _exit() -> void:
	if agent is CharacterBody2D:
		agent.velocity.x = 0
	elapsed = 0.0
	phase = Phase.OUT
