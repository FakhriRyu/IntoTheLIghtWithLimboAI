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
	# Only transition when actually on floor and not moving vertically
	if agent.is_on_floor() and agent.velocity.y >= 0:
		if agent.movement_input != Vector2.ZERO:
			get_root().dispatch("to_move")
		else:
			get_root().dispatch("to_idle")
