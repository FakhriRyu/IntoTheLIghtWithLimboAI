extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const KNOCKBACK_FORCE = 150.0  # Kekuatan knockback

@onready var health = $Health
@onready var animation_player = $AnimationPlayer
@onready var bt_player = $BTPlayer

var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO

func _ready():
	health.death.connect(_on_death)
	health.damaged.connect(_on_damaged)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()

func _on_damaged(_amount: int):
	if is_hurt or is_dead:
		return
	
	is_hurt = true
	
	# Pause AI saat hurt
	bt_player.set_active(false)
	
	# Hitung arah knockback (dari player)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		knockback_direction = (global_position - player.global_position).normalized()
	else:
		knockback_direction = Vector2(-sign($Sprite2D.scale.x), 0)
	
	# Apply knockback
	_apply_knockback()
	
	# Play hurt animation dan tunggu selesai
	animation_player.play("hurt")
	await animation_player.animation_finished
	
	# End hurt state setelah animasi selesai
	_end_hurt_state()

func _apply_knockback():
	# Knockback selama beberapa physics frame
	for i in range(10):
		if is_dead:
			return
		velocity.x = knockback_direction.x * KNOCKBACK_FORCE
		await get_tree().physics_frame

func _end_hurt_state():
	if is_dead:
		return
	
	# Reset state
	is_hurt = false
	knockback_direction = Vector2.ZERO
	velocity.x = 0
	
	# Restart AI jika masih hidup
	if health.current_health > 0:
		bt_player.restart()

func _on_death():
	if is_dead:
		return
	
	is_dead = true
	is_hurt = false
	
	# Stop AI behavior
	bt_player.set_active(false)
	
	# Play death animation
	animation_player.play("death")
	await animation_player.animation_finished
	await get_tree().create_timer(0.5).timeout
	
	# Cleanup
	queue_free()

func update_facing(direction: float) -> void:
	## Update arah hadap sprite menggunakan scale.x
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D:
		if direction != 0:
			sprite.scale.x = abs(sprite.scale.x) * -sign(direction)
