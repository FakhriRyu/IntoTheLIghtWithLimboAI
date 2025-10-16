extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)
	print("Chase state entered")

func _ready() -> void:
	pass

func _update(_delta: float) -> void:
	# Cek apakah player sudah masuk ke attack range dan cooldown selesai
	if agent.player_in_attack_range and agent.can_attack:
		dispatch("to_attack")
		return
	
	agent.apply_movement(agent.get_direction_to_player(), agent.CHASE_SPEED)
