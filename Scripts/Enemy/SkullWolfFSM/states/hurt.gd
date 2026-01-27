extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName

func _enter() -> void:
	animation_player.play(animation)

func _update(_delta: float) -> void:
	agent.apply_knockback()
	
	if not animation_player.is_playing() or animation_player.current_animation != animation:
		agent.is_hurt = false
		if agent.player_in_range:
			dispatch("to_chase")
		else:
			dispatch("to_idle")

func _exit() -> void:
	agent.velocity.x = 0
	agent.is_hurt = false
