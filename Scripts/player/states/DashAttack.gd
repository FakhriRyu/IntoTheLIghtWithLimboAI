extends LimboState
## Tebasan meluncur: dipicu dengan menekan Attack saat sedang dash.
## Menembus musuh (tidak berhenti di musuh pertama) dan menutup jarak dengan cepat.

@export var animation_player: AnimationPlayer
@export var animation: StringName

## Seberapa cepat meluncur, sebagai pengali dari dash_speed player
@export var speed_multiplier: float = 0.8

## Lama meluncur sebelum kembali ke state biasa
@export var duration: float = 0.3

var _timer: float = 0.0
var _direction: float = 1.0


func _enter() -> void:
	animation_player.play(animation)
	_timer = duration

	# arah mengikuti dash yang sedang berjalan, jatuh balik ke arah hadap sprite
	_direction = signf(agent.dash_direction.x)
	if _direction == 0.0:
		_direction = -1.0 if agent.sprite.flip_h else 1.0

	agent.combo_index = 0
	agent.is_dash_attacking = true
	agent.start_attack()


func _exit() -> void:
	agent.is_dash_attacking = false
	agent.cancel_attack_hitbox()
	agent.velocity.x = 0.0


func _update(delta: float) -> void:
	_timer -= delta
	agent.velocity.x = _direction * agent.dash_speed * speed_multiplier
	agent.velocity.y = 0.0   # meluncur lurus, tidak terpengaruh gravitasi

	if _timer <= 0.0:
		if agent.is_on_floor():
			get_root().dispatch(agent.TRANSITION_IDLE)
		else:
			get_root().dispatch(agent.TRANSITION_FALL)
