extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName = "Dead"


func _enter() -> void:
	# Disable player input by setting velocity to zero
	agent.velocity = Vector2.ZERO
	
	# Play death animation
	if animation_player:
		animation_player.play(animation)
		print("Entering Dead state, playing animation: ", animation)
	else:
		print("ERROR: AnimationPlayer not found!")

func _update(_delta: float) -> void:
	# Keep player stationary during death animation
	agent.velocity.x = 0
	agent.velocity.y = 0
