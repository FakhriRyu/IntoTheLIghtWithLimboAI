extends CharacterBody2D

#state machine
@export var state_machine: LimboHSM

#state
@onready var idle_state = $LimboHSM/Idle
@onready var move_state = $LimboHSM/Move
@onready var jump_state = $LimboHSM/Jump
@onready var fall_state = $LimboHSM/Fall
@onready var attack_state = $LimboHSM/Attack
@onready var dash_state = $LimboHSM/Dash
@onready var dead_state = $LimboHSM/Dead
@onready var hurt_state = $LimboHSM/Hurt

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $HurtBox
@onready var health: GameHealth = $Health


const SPEED = 120.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 2.0
const RESPAWN_DELAY = 2.0
const KNOCKBACK_FORCE = 200.0
const IMMUNITY_DURATION = 1.5  # Durasi immunity setelah terkena hit

var movement_input: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true
var spawn_position: Vector2 = Vector2.ZERO
var is_hurt: bool = false
var is_immune: bool = false
var knockback_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_initialize_state_machine()
	
	# Connect health signals
	if health:
		health.death.connect(_on_death)
		health.damaged.connect(_on_damaged)

func _initialize_state_machine() -> void:
	#define states transitions
	state_machine.add_transition(idle_state, move_state, "to_move")
	state_machine.add_transition(move_state, idle_state, "to_idle")
	state_machine.add_transition(idle_state, jump_state, "to_jump")
	state_machine.add_transition(move_state, jump_state, "to_jump")
	state_machine.add_transition(state_machine.ANYSTATE, fall_state, "to_fall")
	state_machine.add_transition(fall_state, move_state, "to_move")
	state_machine.add_transition(fall_state, idle_state, "to_idle")
	state_machine.add_transition(idle_state, attack_state, "to_attack")
	state_machine.add_transition(move_state, attack_state, "to_attack")
	state_machine.add_transition(attack_state, move_state, "to_move")
	state_machine.add_transition(attack_state, idle_state, "to_idle")
	state_machine.add_transition(state_machine.ANYSTATE, dash_state, "to_dash")
	state_machine.add_transition(dash_state, move_state, "to_move")
	state_machine.add_transition(dash_state, idle_state, "to_idle")
	state_machine.add_transition(dash_state, jump_state, "to_jump")
	state_machine.add_transition(state_machine.ANYSTATE, dead_state, "to_dead")
	state_machine.add_transition(dead_state, idle_state, "to_idle")
	state_machine.add_transition(state_machine.ANYSTATE, hurt_state, "to_hurt")
	state_machine.add_transition(hurt_state, idle_state, "to_idle")
	state_machine.add_transition(hurt_state, move_state, "to_move")
	#setup state machine
	state_machine.initial_state = idle_state
	state_machine.initialize(self)
	state_machine.set_active(true)

func apply_movement(_delta):
	velocity.x = movement_input.x * SPEED

func check_attack_input():
	if Input.is_action_just_pressed("Attack") and is_on_floor():
		state_machine.dispatch("to_attack")

func check_jump_input():
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		state_machine.dispatch("to_jump")

func check_dash_input():
	if Input.is_action_just_pressed("Dash") and can_dash and dash_cooldown_timer <= 0:
		# Set dash direction based on movement input or facing direction
		if movement_input.x != 0:
			dash_direction = Vector2(movement_input.x, 0)
		else:
			dash_direction = Vector2(1 if not sprite.flip_h else -1, 0)
		
		state_machine.dispatch("to_dash")

func update_facing():
	if movement_input.x != 0:
		sprite.flip_h = movement_input.x < 0
		# Flip hitbox saja (untuk attack direction)
		if hitbox:
			hitbox.scale.x = -1 if sprite.flip_h else 1

func start_attack():
	"""Called when attack animation begins"""
	if hitbox:
		if hitbox.has_method("set_active"):
			hitbox.set_active(true)
		else:
			# Fallback: enable monitoring with set_deferred
			hitbox.set_deferred("monitoring", true)
			hitbox.set_deferred("monitorable", true)
			# Connect signals if not already connected
			if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
				hitbox.body_entered.connect(_on_hitbox_body_entered)
			if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
				hitbox.area_entered.connect(_on_hitbox_area_entered)

func end_attack():
	"""Called when attack animation ends"""
	if hitbox:
		if hitbox.has_method("set_active"):
			hitbox.set_active(false)
		else:
			# Fallback: disable monitoring with set_deferred
			hitbox.set_deferred("monitoring", false)
			hitbox.set_deferred("monitorable", false)

func _on_hitbox_body_entered(body):
	"""Handle hitbox collision with bodies (like barrels)"""
	if body.has_method("take_damage"):
		body.take_damage()
		print("Player hit: ", body.name)

func _on_hitbox_area_entered(area):
	"""Handle hitbox collision with areas (like enemy hurtboxes)"""
	if area.has_method("take_damage"):
		area.take_damage()
		print("Player hit area: ", area.name)
	elif area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage()
		print("Player hit enemy: ", area.get_parent().name)

func _physics_process(delta: float) -> void:
	# Don't process physics if dead
	if state_machine.get_active_state() == dead_state:
		return
	
	movement_input = Input.get_vector("Left", "Right", "Up", "Down")

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Update dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		can_dash = false
	else:
		can_dash = true

	move_and_slide()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack":
		end_attack()
		state_machine.dispatch("to_idle")
	elif anim_name == "Dead":
		print("Dead animation finished, waiting ", RESPAWN_DELAY, " seconds before respawn...")
		# Wait a bit before respawning
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		print("Timer finished, calling respawn()...")
		respawn()
	elif anim_name == "Hurt":
		# Hurt animation selesai tapi knockback mungkin masih berlangsung
		# State transition dihandle di _end_hurt_state()
		pass

func _on_damaged(amount: int) -> void:
	"""Called when player takes damage"""
	if is_immune or is_hurt:
		return
	
	print("Player took ", amount, " damage!")
	is_hurt = true
	
	# Hitung arah knockback (dari enemy terdekat)
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_enemy: Node2D = null
	var closest_distance: float = INF
	
	for enemy in enemies:
		if enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_distance:
				closest_distance = dist
				closest_enemy = enemy
	
	if closest_enemy:
		knockback_direction = (global_position - closest_enemy.global_position).normalized()
	else:
		# Fallback: knockback berdasarkan arah hadap
		knockback_direction = Vector2(1 if sprite.flip_h else -1, 0)
	
	# Transition ke hurt state
	state_machine.dispatch("to_hurt")
	
	# Apply knockback
	_apply_knockback()

func _apply_knockback() -> void:
	"""Apply knockback effect"""
	for i in range(10):
		if not is_hurt:
			return
		velocity.x = knockback_direction.x * KNOCKBACK_FORCE
		velocity.y = -100  # Sedikit terangkat
		await get_tree().physics_frame
	
	_end_hurt_state()

func _end_hurt_state() -> void:
	"""End hurt state and start immunity"""
	is_hurt = false
	knockback_direction = Vector2.ZERO
	velocity = Vector2.ZERO  # Stop sliding
	
	# Start immunity period
	_start_immunity()
	
	# Return to idle or move state
	if movement_input != Vector2.ZERO:
		state_machine.dispatch("to_move")
	else:
		state_machine.dispatch("to_idle")

func _start_immunity() -> void:
	"""Start immunity period with blinking effect"""
	is_immune = true
	
	# Blink effect selama immunity
	var blink_count = int(IMMUNITY_DURATION / 0.1)
	for i in range(blink_count):
		if not is_immune:
			break
		sprite.modulate.a = 0.3 if i % 2 == 0 else 1.0
		await get_tree().create_timer(0.1).timeout
	
	# Reset sprite dan immunity
	sprite.modulate.a = 1.0
	is_immune = false

func _on_death() -> void:
	"""Called when health reaches 0"""
	print("Player died! Transitioning to dead state...")
	
	# Stop immunity jika sedang berlangsung
	is_immune = false
	is_hurt = false
	
	# Disable hurtbox so player can't take more damage while dead
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		print("Hurtbox disabled (deferred)")
	
	state_machine.dispatch("to_dead")

func respawn() -> void:
	"""Respawn player at starting position"""
	print("=== RESPAWN START ===")
	print("Current position before respawn: ", global_position)
	print("Spawn position: ", spawn_position)
	print("Current state: ", state_machine.get_active_state())
	
	# Reset position
	global_position = spawn_position
	print("Position set to: ", global_position)
	
	# Reset velocity
	velocity = Vector2.ZERO
	print("Velocity reset to zero")
	
	# Reset health
	if health:
		health.current_health = health.max_health
		print("Health reset to: ", health.max_health)
	
	# Re-enable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
		print("Hurtbox re-enabled (deferred)")
	
	# Reset dash cooldown
	dash_cooldown_timer = 0.0
	can_dash = true
	print("Dash cooldown reset")
	
	# Reset hurt/immunity state
	is_hurt = false
	is_immune = false
	knockback_direction = Vector2.ZERO
	sprite.modulate.a = 1.0
	print("Hurt/immunity state reset")
	
	# Return to idle state
	print("Attempting to dispatch to_idle...")
	var result = state_machine.dispatch("to_idle")
	print("Dispatch result: ", result)
	print("New state: ", state_machine.get_active_state())
	
	print("=== RESPAWN END ===")
	print("Player respawned at: ", spawn_position)
