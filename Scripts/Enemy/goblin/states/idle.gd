extends LimboState
## Diam di tempat. Ada player -> Chase. Kalau lama tidak ada apa-apa -> Patrol.

@export var animation_player: AnimationPlayer
@export var animation: StringName
## Lama diam (acak) sebelum mulai berpatroli
@export var min_wait: float = 1.5
@export var max_wait: float = 3.0

var _wait: float = 0.0


func _enter() -> void:
	agent.play_anim(animation)
	agent.stop_moving()
	_wait = randf_range(min_wait, max_wait)


func _update(delta: float) -> void:
	agent.stop_moving()
	if agent.has_target():
		dispatch("to_chase")
		return
	_wait -= delta
	if _wait <= 0.0:
		dispatch("to_patrol")
