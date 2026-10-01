extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName

## Detik ke berapa start_attack() dipanggil pada animasi attack (method track)
@export var swing_time: float = 0.6
## Kecepatan animasi serangan. Di bawah 1 = pengayunan lebih lambat, jadi
## jendela peringatan lebih panjang dan player lebih sempat bereaksi.
@export var windup_speed: float = 0.8

var attack_finished: bool = false


func _enter() -> void:
	attack_finished = false
	agent.velocity.x = 0
	agent.can_attack = false
	agent.attack_cooldown_timer = agent.ATTACK_COOLDOWN

	var dir = agent.get_direction_to_player()
	if dir != 0:
		agent.update_facing(dir)

	# Peringatan tampil selama animasi mengangkat senjata, sampai ayunan dimulai
	agent.show_attack_warning(swing_time / windup_speed)

	if animation_player:
		animation_player.play(animation, -1, windup_speed)

	if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _exit() -> void:
	# Safety cleanup: pastikan hitbox selalu nonaktif saat keluar dari attack state
	agent.end_attack()
	agent.clear_attack_warning()


func _update(_delta: float) -> void:
	agent.velocity.x = 0
	if attack_finished:
		if agent.ready_to_attack():
			dispatch("to_attack")
		elif agent.has_target():
			dispatch("to_chase")
		else:
			dispatch("to_idle")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == animation:
		attack_finished = true
