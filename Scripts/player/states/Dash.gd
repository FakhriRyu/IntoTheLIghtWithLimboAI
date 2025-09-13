extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName

func _enter() -> void:
	animation_player.play(animation)
	# Set dash velocity only once
	agent.velocity.x = agent.dash_direction.x * agent.DASH_SPEED
	agent.velocity.y = 0  # Stop vertical movement during dash
	agent.dash_timer = agent.DASH_DURATION
	agent.can_dash = false  # Prevent multiple dashes
	agent.dash_cooldown_timer = agent.DASH_COOLDOWN  # Start cooldown

func _update(_delta: float) -> void:
	# Countdown dash timer
	agent.dash_timer -= _delta
	# End dash when timer runs out
	if agent.dash_timer <= 0:
		# Stop horizontal movement when dash ends
		agent.velocity.x = 0
		get_root().dispatch("to_idle")
