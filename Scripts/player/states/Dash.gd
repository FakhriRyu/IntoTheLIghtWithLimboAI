extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName
@export var dash_iframe_window: float = 0.12


func _enter() -> void:
	animation_player.play(animation)
	# Set dash velocity only once
	agent.velocity.x = agent.dash_direction.x * agent.dash_speed
	agent.velocity.y = 0  # Stop vertical movement during dash
	agent.dash_timer = agent.dash_duration
	agent.can_dash = false  # Prevent multiple dashes
	agent.dash_cooldown_timer = agent.dash_cooldown  # Start cooldown
	# Temporary i-frames: disable hurtbox briefly
	var hb = agent.get_node_or_null("HurtBox")
	if hb:
		hb.set_deferred("monitoring", false)
		hb.set_deferred("monitorable", false)
		_restore_hurtbox_after_iframes(hb)


func _update(delta: float) -> void:
	# Countdown dash timer
	agent.dash_timer -= delta
	# End dash when timer runs out
	if agent.dash_timer <= 0:
		# Stop horizontal movement when dash ends
		agent.velocity.x = 0
		get_root().dispatch("to_idle")


func _restore_hurtbox_after_iframes(hb: Node) -> void:
	await get_tree().create_timer(dash_iframe_window).timeout
	if is_instance_valid(hb):
		hb.set_deferred("monitoring", true)
		hb.set_deferred("monitorable", true)
