extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName

var attack_finished: bool = false


func _enter() -> void:
	attack_finished = false
	agent.velocity.x = 0
	agent.can_attack = false
	agent.attack_cooldown_timer = agent.ATTACK_COOLDOWN

	var dir = agent.get_direction_to_player()
	if dir != 0:
		agent.update_facing(dir)

	if animation_player:
		animation_player.play(animation)

	if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _exit() -> void:
	# Safety cleanup: pastikan hitbox selalu nonaktif saat keluar dari attack state
	agent.end_attack()


func _update(_delta: float) -> void:
	agent.velocity.x = 0
	if attack_finished:
		if agent.player_in_attack_range and agent.can_attack:
			dispatch("to_attack")
		elif agent.player_in_range:
			dispatch("to_chase")
		else:
			dispatch("to_idle")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == animation:
		attack_finished = true
