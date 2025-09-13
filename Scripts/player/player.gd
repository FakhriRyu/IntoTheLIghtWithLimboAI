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

@onready var sprite: Sprite2D = $Sprite2D


const SPEED = 200.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 2.0

var movement_input: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true

func _ready() -> void:
	_initialize_state_machine()

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

func _physics_process(delta: float) -> void:
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
		state_machine.dispatch("to_idle")
