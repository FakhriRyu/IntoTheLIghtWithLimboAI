extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)
	agent.velocity.y = agent.jump_velocity


func _update(delta: float) -> void:
	agent.apply_movement(delta)
	agent.update_facing()
	agent.check_dash_input()
	# Only transition to fall when velocity becomes positive (falling down)
	if agent.velocity.y > 0 and !agent.is_on_floor():
		get_root().dispatch("to_fall")
