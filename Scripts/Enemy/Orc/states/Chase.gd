extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)
	print("Chase state entered")

func _ready() -> void:
	pass

func _update(_delta: float) -> void:
	agent.apply_movement(agent.get_direction_to_player(), agent.CHASE_SPEED)
