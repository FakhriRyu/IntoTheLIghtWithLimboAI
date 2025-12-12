extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName = &"Hurt"

func _enter() -> void:
	animation_player.play(animation)
	# Play hurt sound
	var hurt_sound = agent.get_node_or_null("SFX/HurtSound")
	if hurt_sound:
		hurt_sound.play()

func _update(_delta: float) -> void:
	# Knockback dihandle di player.gd
	pass

func _exit() -> void:
	pass

