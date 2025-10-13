extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)
	print("Patrol state entered")

func _update(_delta: float) -> void:
	pass
