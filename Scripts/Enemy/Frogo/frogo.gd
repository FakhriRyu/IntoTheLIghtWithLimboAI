extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()

func update_facing(direction: float) -> void:
	## Update arah hadap sprite menggunakan flip_h
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D:
		if direction != 0:
			sprite.flip_h = direction < 0
