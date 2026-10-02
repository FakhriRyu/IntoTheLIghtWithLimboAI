extends LimboState
## Bos tersentak setelah poise-nya habis: terdorong mundur, main animasi hurt,
## lalu kembali ke fase yang sedang berjalan sambil langsung kabur (Panic Blink).

@export var animation: StringName = &"hurt"
## Berapa physics frame knockback diterapkan
@export var knockback_frames: int = 10

var _frames_left: int = 0


func _enter() -> void:
	agent.is_hurt = true
	_frames_left = knockback_frames

	# Hitung arah knockback (dari player)
	var player: Node2D = agent.get_tree().get_first_node_in_group("player")
	if player:
		agent.knockback_direction = (agent.global_position - player.global_position).normalized()
	else:
		# Terdorong ke belakang relatif arah hadap sekarang
		agent.knockback_direction = -agent.facing_vector()

	agent.animation_player.play(animation)


func _update(_delta: float) -> void:
	if _frames_left > 0:
		_frames_left -= 1
		agent.velocity.x = agent.knockback_direction.x * agent.KNOCKBACK_FORCE
	else:
		agent.velocity.x = 0

	if agent.animation_player.is_playing() and agent.animation_player.current_animation == animation:
		return

	# Selesai tersentak: suruh behavior tree langsung kabur
	agent.panic_requested = true
	dispatch(&"recover_p2" if agent.phase == 2 else &"recover_p1")


func _exit() -> void:
	agent.is_hurt = false
	agent.knockback_direction = Vector2.ZERO
	agent.velocity.x = 0
