extends LimboState
## Serangan darat maupun udara, dengan rantai combo 3 pukulan.
## Nama animasi dipilih dari combo_index milik player: Attack1 / Attack2 / Attack3.

@export var animation_player: AnimationPlayer
@export var animation: StringName

## Dorongan maju saat menebas, per indeks combo
@export var lunge_speeds: Array[float] = [150.0, 170.0, 260.0]

## Kecepatan putar animasi per indeks combo. Di bawah 1 = tebasan lebih lambat
## dan terasa lebih berbobot (hitbox ikut mundur karena memakai method track).
@export var animation_speeds: Array[float] = [0.6, 0.55, 0.9]

## Pengali gravitasi saat menyerang di udara (bikin terasa menggantung sesaat)
@export var air_hover: float = 0.35

var _started_in_air: bool = false


func _enter() -> void:
	_started_in_air = not agent.is_on_floor()
	if _started_in_air:
		agent.air_attack_used = true

	agent.attack_recovery = false
	var idx: int = clampi(agent.combo_index, 0, lunge_speeds.size() - 1)
	var anim_speed: float = animation_speeds[idx] if idx < animation_speeds.size() else 1.0
	animation_player.play(agent.current_attack_animation(), -1, anim_speed)
	agent.attack_cooldown = agent.ATTACK_INTERVALS[clampi(idx, 0, agent.ATTACK_INTERVALS.size() - 1)]

	# dorongan maju sesuai arah hadap
	var facing := -1.0 if agent.sprite.flip_h else 1.0
	agent.velocity.x = facing * lunge_speeds[idx]

	# pamungkas: lapisi tebasan biasa dengan ayunan berat
	if idx >= 2:
		Audio.play_sfx(&"sword_swing_heavy", -2.0, 0.05)


func _exit() -> void:
	agent.cancel_attack_hitbox()
	agent.attack_recovery = false


func _update(delta: float) -> void:
	# dorongan meluruh, bukan berhenti mendadak
	agent.velocity.x = move_toward(agent.velocity.x, 0.0, agent.friction * delta)

	if _started_in_air:
		# Lawan sebagian gravitasi supaya serangan udara terasa menggantung sesaat.
		# Sisa gravitasi efektif = air_hover (default 35%).
		agent.velocity.y -= agent.get_gravity().y * delta * (1.0 - air_hover)

	# selama recovery, serangan boleh dibatalkan ke dash atau lompat
	if agent.attack_recovery:
		agent.check_dash_input()
		agent.check_jump_input()
