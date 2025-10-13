extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)

func _exit() -> void:
	pass

func _ready() -> void:
	pass

func _update(_delta: float) -> void:
	agent.velocity.x = 0
