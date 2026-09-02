extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)
	print("Idle state entered")


func _update(_delta: float) -> void:
	agent.velocity.x = 0
	if agent.player_in_range:
		get_root().dispatch("to_chase")
