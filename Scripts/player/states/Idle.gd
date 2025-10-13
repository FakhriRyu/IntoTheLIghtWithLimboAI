extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _update(_delta: float) -> void:
	agent.check_jump_input()
	agent.check_attack_input()
	agent.check_dash_input()
	if agent.movement_input != Vector2.ZERO:
		get_root().dispatch("to_move")
