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

## Sejauh apa mencari lantai di titik tujuan. Kalau tidak ada lantai,
## jarak blink diperpendek atau dibalik arah supaya agent tidak jatuh ke jurang.
@export var ground_probe: float = 320.0

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

	# Selama blink berlangsung agent tidak boleh dihentikan oleh serangan,
	# supaya player tidak bisa mengunci agent dengan pukulan beruntun.
	if agent.has_method("set_uninterruptible"):
		agent.set_uninterruptible(true)

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

	var destination: float = _pick_destination(target, away)
	if is_inf(destination):
		# Tidak ada tempat berpijak ke mana pun: tetap di tempat, jangan jatuh ke jurang
		return

	# Ketinggian dipertahankan supaya agent tetap berpijak di lantai yang sama
	agent.global_position.x = destination

	# Muncul kembali sambil menghadap target
	if agent.has_method("update_facing"):
		agent.update_facing(-away)


func _pick_destination(target: Node2D, away: float) -> float:
	"""Memilih titik mendarat yang ada lantainya.
	Coba jarak penuh dulu, lalu diperpendek, lalu sisi seberang."""
	for dir: float in [away, -away]:
		for factor: float in [1.0, 0.75, 0.5]:
			var candidate: float = target.global_position.x + dir * blink_distance * factor
			if _has_ground(candidate):
				return candidate
	return INF


func _has_ground(at_x: float) -> bool:
	"""Cek apakah ada lantai di bawah sebuah koordinat x."""
	var space: PhysicsDirectSpaceState2D = agent.get_world_2d().direct_space_state
	var from := Vector2(at_x, agent.global_position.y)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, ground_probe))
	query.collide_with_areas = false

	var ignored: Array[RID] = [agent.get_rid()]
	query.exclude = ignored

	return not space.intersect_ray(query).is_empty()


func _exit() -> void:
	if agent.has_method("set_uninterruptible"):
		agent.set_uninterruptible(false)

	if agent is CharacterBody2D:
		agent.velocity.x = 0
	elapsed = 0.0
	phase = Phase.OUT
