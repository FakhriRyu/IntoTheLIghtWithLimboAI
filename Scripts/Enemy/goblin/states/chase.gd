extends LimboState
## Mengejar player. Berhenti (dengan animasi idle, bukan berlari di tempat) saat:
## sudah cukup dekat, ada tembok/tepi platform di depan, atau player berada di
## lantai lain. Masuk Attack begitu player di jangkauan dan cooldown selesai.

@export var animation_player: AnimationPlayer
@export var animation: StringName
## Animasi saat menunggu/tertahan
@export var hold_animation: StringName = &"idle"


func _enter() -> void:
	agent.play_anim(animation)


func _update(_delta: float) -> void:
	if not agent.has_target():
		dispatch("to_idle")
		return

	var dir: float = agent.get_direction_to_player()
	if dir != 0.0:
		agent.update_facing(dir)

	if agent.ready_to_attack():
		dispatch("to_attack")
		return

	var off: Vector2 = agent.offset_to_player()
	var close_enough: bool = absf(off.x) <= agent.stop_distance
	var other_floor: bool = absf(off.y) > agent.MAX_CHASE_HEIGHT
	if close_enough or dir == 0.0 or not agent.can_walk(dir) or (other_floor and absf(off.x) < 24.0):
		agent.stop_moving()
		agent.play_anim(hold_animation)
		return

	agent.play_anim(animation)
	agent.apply_movement(dir, agent.CHASE_SPEED)


func _exit() -> void:
	agent.stop_moving()
