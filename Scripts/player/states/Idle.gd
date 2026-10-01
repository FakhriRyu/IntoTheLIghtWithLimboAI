extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)


func _update(delta: float) -> void:
	agent.apply_movement(delta)
	agent.update_facing()
	agent.check_jump_input()
	agent.check_dash_input()
	# sudah pindah state (mis. turun menembus papan -> Fall)
	if not is_active():
		return
	if agent.movement_input != Vector2.ZERO:
		get_root().dispatch("to_move")
