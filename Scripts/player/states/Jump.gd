extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	animation_player.play(animation)
	agent.velocity.y = agent.JUMP_VELOCITY

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _update(_delta: float) -> void:
	agent.apply_movement(_delta)
	agent.update_facing()
	agent.check_dash_input()
	# Only transition to fall when velocity becomes positive (falling down)
	if agent.velocity.y > 0 and !agent.is_on_floor():
		get_root().dispatch("to_fall")
	
