class_name Player
extends CharacterBody2D

## Player controller with LimboHSM state machine.
## Handles movement, combat, and health systems.

# --- Transition Event Constants ---
const TRANSITION_MOVE := "to_move"
const TRANSITION_IDLE := "to_idle"
const TRANSITION_JUMP := "to_jump"
const TRANSITION_FALL := "to_fall"
const TRANSITION_ATTACK := "to_attack"
const TRANSITION_DASH := "to_dash"
const TRANSITION_DEAD := "to_dead"
const TRANSITION_HURT := "to_hurt"

# --- Coyote Time & Jump Buffer ---
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

# --- State Machine ---
@export var state_machine: LimboHSM

# --- Movement Tuning ---
@export var speed: float = 120.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# --- Dash Tuning ---
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.25
@export var dash_cooldown: float = 2.0

# --- Combat Tuning ---
@export var knockback_force: float = 200.0
@export var immunity_duration: float = 1.5
@export var respawn_delay: float = 2.0

# --- State References ---
@onready var idle_state: LimboState = $LimboHSM/Idle
@onready var move_state: LimboState = $LimboHSM/Move
@onready var jump_state: LimboState = $LimboHSM/Jump
@onready var fall_state: LimboState = $LimboHSM/Fall
@onready var attack_state: LimboState = $LimboHSM/Attack
@onready var dash_state: LimboState = $LimboHSM/Dash
@onready var dead_state: LimboState = $LimboHSM/Dead
@onready var hurt_state: LimboState = $LimboHSM/Hurt

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $HurtBox
@onready var health: GameHealth = $Health

# --- Runtime State ---
var movement_input: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true
var spawn_position: Vector2 = Vector2.ZERO
var is_hurt: bool = false
var is_immune: bool = false
var knockback_direction: Vector2 = Vector2.ZERO
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var _immunity_tween: Tween = null


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_initialize_state_machine()

	# Connect health signals
	if health:
		health.death.connect(_on_death)
		health.damaged.connect(_on_damaged)


func _initialize_state_machine() -> void:
	# Define state transitions
	state_machine.add_transition(idle_state, move_state, TRANSITION_MOVE)
	state_machine.add_transition(move_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(idle_state, jump_state, TRANSITION_JUMP)
	state_machine.add_transition(move_state, jump_state, TRANSITION_JUMP)
	state_machine.add_transition(state_machine.ANYSTATE, fall_state, TRANSITION_FALL)
	state_machine.add_transition(fall_state, move_state, TRANSITION_MOVE)
	state_machine.add_transition(fall_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(fall_state, jump_state, TRANSITION_JUMP)
	state_machine.add_transition(idle_state, attack_state, TRANSITION_ATTACK)
	state_machine.add_transition(move_state, attack_state, TRANSITION_ATTACK)
	state_machine.add_transition(attack_state, move_state, TRANSITION_MOVE)
	state_machine.add_transition(attack_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(state_machine.ANYSTATE, dash_state, TRANSITION_DASH)
	state_machine.add_transition(dash_state, move_state, TRANSITION_MOVE)
	state_machine.add_transition(dash_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(dash_state, jump_state, TRANSITION_JUMP)
	state_machine.add_transition(state_machine.ANYSTATE, dead_state, TRANSITION_DEAD)
	state_machine.add_transition(dead_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(state_machine.ANYSTATE, hurt_state, TRANSITION_HURT)
	state_machine.add_transition(hurt_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(hurt_state, move_state, TRANSITION_MOVE)

	# Setup state machine
	state_machine.initial_state = idle_state
	state_machine.initialize(self)
	state_machine.set_active(true)


# --- Movement ---

func apply_movement(delta: float) -> void:
	var target_speed := movement_input.x * speed
	var accel := acceleration if is_on_floor() else acceleration * 0.5

	if movement_input.x != 0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)


func update_facing() -> void:
	if movement_input.x != 0:
		sprite.flip_h = movement_input.x < 0
		# Flip hitbox for attack direction
		if hitbox:
			hitbox.scale.x = -1 if sprite.flip_h else 1


# --- Input Checks ---

func check_attack_input() -> void:
	if Input.is_action_just_pressed("Attack") and is_on_floor():
		state_machine.dispatch(TRANSITION_ATTACK)


func check_jump_input() -> void:
	var wants_jump := Input.is_action_just_pressed("Jump") or jump_buffer_timer > 0
	if wants_jump and coyote_timer > 0:
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		state_machine.dispatch(TRANSITION_JUMP)


func check_dash_input() -> void:
	if Input.is_action_just_pressed("Dash") and can_dash:
		# Set dash direction based on movement input or facing direction
		if movement_input.x != 0:
			dash_direction = Vector2(movement_input.x, 0)
		else:
			dash_direction = Vector2(1 if not sprite.flip_h else -1, 0)

		state_machine.dispatch(TRANSITION_DASH)


# --- Combat ---

func start_attack() -> void:
	"""Called when attack animation begins (via AnimationPlayer method track)."""
	if hitbox:
		hitbox.set_active(true)


func end_attack() -> void:
	"""Called when attack animation ends (via AnimationPlayer method track)."""
	if hitbox:
		hitbox.set_active(false)


# --- Physics ---

func _physics_process(delta: float) -> void:
	# Don't process physics if dead
	if state_machine.get_active_state() == dead_state:
		return

	movement_input = Input.get_vector("Left", "Right", "Up", "Down")

	# Record jump buffer input
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	elif jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Update dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		can_dash = false
	else:
		can_dash = true

	move_and_slide()

	# Update coyote timer (after move_and_slide so is_on_floor() is current)
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)


# --- Animation Callbacks ---

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack":
		end_attack()
		state_machine.dispatch(TRANSITION_IDLE)
	elif anim_name == "Dead":
		if OS.is_debug_build():
			print("Dead animation finished, waiting ", respawn_delay, " seconds before respawn...")
		await get_tree().create_timer(respawn_delay).timeout
		if OS.is_debug_build():
			print("Timer finished, calling respawn()...")
		respawn()
	elif anim_name == "Hurt":
		# Hurt animation finished; knockback may still be in progress.
		# State transition is handled in _end_hurt_state().
		pass


# --- Damage & Knockback ---

func _on_damaged(amount: int, source_position: Vector2) -> void:
	"""Called when player takes damage."""
	if is_immune or is_hurt:
		return

	if OS.is_debug_build():
		print("Player took ", amount, " damage!")

	is_hurt = true
	knockback_direction = (global_position - source_position).normalized()

	# Transition to hurt state
	state_machine.dispatch(TRANSITION_HURT)

	# Apply knockback
	_apply_knockback()


func _apply_knockback() -> void:
	"""Apply knockback as a single impulse, then wait before ending hurt state."""
	velocity = Vector2(knockback_direction.x * knockback_force, -100)
	await get_tree().create_timer(0.2).timeout
	if is_hurt:
		_end_hurt_state()


func _end_hurt_state() -> void:
	"""End hurt state and start immunity."""
	is_hurt = false
	knockback_direction = Vector2.ZERO
	velocity = Vector2.ZERO  # Stop sliding

	# Start immunity period
	_start_immunity()

	# Return to idle or move state
	if movement_input != Vector2.ZERO:
		state_machine.dispatch(TRANSITION_MOVE)
	else:
		state_machine.dispatch(TRANSITION_IDLE)


func _start_immunity() -> void:
	"""Start immunity period with blinking effect using Tween."""
	is_immune = true

	# Kill any existing immunity tween
	if _immunity_tween and _immunity_tween.is_valid():
		_immunity_tween.kill()

	_immunity_tween = create_tween()
	var loop_count := int(immunity_duration / 0.2)
	_immunity_tween.set_loops(loop_count)
	_immunity_tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
	_immunity_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	_immunity_tween.finished.connect(_on_immunity_finished)


func _on_immunity_finished() -> void:
	sprite.modulate.a = 1.0
	is_immune = false


# --- Death & Respawn ---

func _on_death() -> void:
	"""Called when health reaches 0."""
	if OS.is_debug_build():
		print("Player died! Transitioning to dead state...")

	# Stop immunity if in progress
	is_immune = false
	is_hurt = false
	if _immunity_tween and _immunity_tween.is_valid():
		_immunity_tween.kill()
	sprite.modulate.a = 1.0

	# Disable hurtbox so player can't take more damage while dead
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	state_machine.dispatch(TRANSITION_DEAD)


func respawn() -> void:
	"""Respawn player at starting position."""
	if OS.is_debug_build():
		print("Respawning player at: ", spawn_position)

	# Reset position & velocity
	global_position = spawn_position
	velocity = Vector2.ZERO

	# Reset health
	if health:
		health.current_health = health.max_health

	# Re-enable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)

	# Reset dash cooldown
	dash_cooldown_timer = 0.0
	can_dash = true

	# Reset hurt/immunity state
	is_hurt = false
	is_immune = false
	knockback_direction = Vector2.ZERO
	sprite.modulate.a = 1.0

	# Reset timers
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

	# Return to idle state
	state_machine.dispatch(TRANSITION_IDLE)
