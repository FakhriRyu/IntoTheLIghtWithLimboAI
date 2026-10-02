extends LimboState
## Bos diam menunggu sampai player masuk arena, lalu meraung dan mulai bertarung.
## Kalau bos dipukul duluan, norch_thex.gd langsung men-dispatch "engage".

@export var idle_animation: StringName = &"idle"
@export var roar_animation: StringName = &"trapscream"

var _roaring: bool = false


func _enter() -> void:
	_roaring = false
	agent.velocity.x = 0
	agent.animation_player.play(idle_animation)


func _update(_delta: float) -> void:
	if _roaring:
		# Raungan selesai: masuk fase 1
		if not agent.animation_player.is_playing() \
				or agent.animation_player.current_animation != roar_animation:
			dispatch(&"engage")
		return

	var player: Node2D = agent.get_tree().get_first_node_in_group("player")
	if player == null or not agent.detection_area_boss.overlaps_body(player):
		return

	_roaring = true
	agent.update_facing(signf(player.global_position.x - agent.global_position.x))
	agent.animation_player.play(roar_animation)
	Audio.play_sfx(&"boss_scream", 0.0, 0.04)
