extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName

func _enter() -> void:
	# Pastikan nama animasi di AnimationPlayer SAMA PERSIS dengan string 'animation'
	animation_player.play(animation)

func _update(_delta: float) -> void:
	agent.apply_knockback()
	
	# Tambahkan check agar tidak langsung keluar di frame pertama
	if animation_player.is_playing() and animation_player.current_animation == animation:
		pass # Tunggu animasi selesai
	else:
		# Logika keluar state
		agent.is_hurt = false
		if agent.player_in_range:
			dispatch("to_chase")
		else:
			dispatch("to_idle")

func _exit() -> void:
	agent.velocity.x = 0
	agent.is_hurt = false
