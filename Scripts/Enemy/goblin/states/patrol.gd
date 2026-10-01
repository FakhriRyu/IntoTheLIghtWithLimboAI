extends LimboState
## Berjalan bolak-balik di sekitar titik spawn. Berbalik di tembok, tepi
## platform, atau batas jarak patroli. Setelah beberapa putaran kembali Idle.

@export var animation_player: AnimationPlayer
@export var animation: StringName
@export var min_legs: int = 1
@export var max_legs: int = 2

var _dir: float = 1.0
var _legs_left: int = 0


func _enter() -> void:
	agent.play_anim(animation)
	_legs_left = randi_range(min_legs, max_legs) * 2
	# mulai ke arah yang menjauhi batas terdekat
	_dir = -1.0 if agent.global_position.x > agent.spawn_x else 1.0
	if randf() < 0.5 and absf(agent.global_position.x - agent.spawn_x) < 8.0:
		_dir = -_dir


func _update(_delta: float) -> void:
	if agent.has_target():
		dispatch("to_chase")
		return

	var offset: float = agent.global_position.x - agent.spawn_x
	var past_limit: bool = absf(offset) >= agent.PATROL_DISTANCE and signf(offset) == _dir
	if past_limit or not agent.can_walk(_dir):
		_dir = -_dir
		_legs_left -= 1
		if _legs_left <= 0 or not agent.can_walk(_dir):
			# terjepit di dua sisi atau sudah cukup berpatroli
			dispatch("to_idle")
			return

	agent.play_anim(animation)
	agent.apply_movement(_dir, agent.SPEED)


func _exit() -> void:
	agent.stop_moving()
