extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	if animation_player:
		animation_player.play(animation)
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)


func _update(_delta: float) -> void:
	agent.apply_knockback()


func _exit() -> void:
	agent.velocity.x = 0
	agent.is_hurt = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == animation:
		agent.is_hurt = false
		if agent.player_in_attack_range and agent.can_attack:
			dispatch("to_attack")
		elif agent.player_in_range:
			dispatch("to_chase")
		else:
			dispatch("to_idle")
