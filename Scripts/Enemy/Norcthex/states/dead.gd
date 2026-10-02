extends LimboState
## Bos mati: matikan hurtbox, main animasi death, lalu hapus node.

@export var animation: StringName = &"death"


func _enter() -> void:
	agent.velocity = Vector2.ZERO
	Audio.enemy_voice(agent, &"death")

	# Bos sudah mati: jangan terima pukulan lagi selama animasi death
	agent.hurt_box.set_deferred("monitoring", false)
	agent.hurt_box.set_deferred("monitorable", false)

	agent.animation_player.play(animation)
	await agent.animation_player.animation_finished
	await agent.get_tree().create_timer(0.5).timeout

	agent.queue_free()
