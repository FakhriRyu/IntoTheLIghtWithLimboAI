extends CharacterBody2D

const SPEED = 100.0

func _physics_process(delta):
	# Mendapatkan arah input (-1 untuk Left, 1 untuk Right, 0 jika tidak dipencet)
	var direction = Input.get_axis("Left", "Right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

		# Menggerakkan objek dan menangani tabrakan (collision)
	move_and_slide()
