extends LimboState
## Transisi ke fase 2: bos meraung (tidak bisa disela), memasang perangkap,
## berubah warna, lalu masuk behavior tree fase 2.

@export var animation: StringName = &"trapscream"
## Detik ke berapa perangkap dipasang selama raungan
@export var trap_time: float = 0.6

var _elapsed: float = 0.0
var _trapped: bool = false


func _enter() -> void:
	_elapsed = 0.0
	_trapped = false
	agent.set_uninterruptible(true)
	agent.velocity.x = 0
	agent.panic_requested = false
	agent.enter_phase_two()

	var player: Node2D = agent.get_tree().get_first_node_in_group("player")
	if player:
		agent.update_facing(signf(player.global_position.x - agent.global_position.x))

	agent.animation_player.play(animation)
	Audio.play_sfx(&"boss_scream", 2.0, 0.0, 0.85)

	# Tint fase 2 dipudarkan masuk supaya perubahannya terasa
	var tween: Tween = agent.create_tween()
	tween.tween_property(agent.sprite, "modulate", agent.base_modulate, 0.4)


func _update(delta: float) -> void:
	_elapsed += delta

	if not _trapped and _elapsed >= trap_time:
		_trapped = true
		agent.spawn_trap()

	if agent.animation_player.is_playing() and agent.animation_player.current_animation == animation:
		return

	dispatch(&"phase_done")


func _exit() -> void:
	agent.set_uninterruptible(false)
