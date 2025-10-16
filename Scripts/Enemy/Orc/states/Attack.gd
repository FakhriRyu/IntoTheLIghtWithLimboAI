extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName

var attack_finished: bool = false


func _enter() -> void:
	attack_finished = false
	animation_player.play(animation)
	print("Attack state entered")
	
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func _exit() -> void:
	agent.end_attack()

func _ready() -> void:
	pass

func _update(_delta: float) -> void:
	agent.velocity.x = 0
	if attack_finished:
		if agent.player_in_attack_range:
			dispatch("to_chase")
		elif agent.player_in_range:
			dispatch("to_chase")
		else:
			dispatch("to_idle")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == animation:
		attack_finished = true
