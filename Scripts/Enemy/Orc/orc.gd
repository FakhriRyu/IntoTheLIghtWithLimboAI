extends CharacterBody2D

# State machine
@export var state_machine: LimboHSM

# States
@onready var idle_state = $LimboHSM/Idle
@onready var chase_state = $LimboHSM/Chase
@onready var attack_state = $LimboHSM/Attack
@onready var dead_state = $LimboHSM/Dead
@onready var patrol_state = $LimboHSM/Patrol

# Components
@onready var sprite: Sprite2D = $Sprite2D

# AI Properties
const SPEED = 80.0
const CHASE_SPEED = 120.0
const ATTACK_RANGE = 40.0
const PATROL_DISTANCE = 100.0

var player_reference: CharacterBody2D = null
var player_in_range: bool = false

func _ready() -> void:
	_initialize_state_machine()

func _initialize_state_machine() -> void:
	# Define state transitions
	state_machine.add_transition(idle_state, patrol_state, "to_patrol")
	state_machine.add_transition(idle_state, chase_state, "to_chase")
	state_machine.add_transition(patrol_state, idle_state, "to_idle")
	state_machine.add_transition(patrol_state, chase_state, "to_chase")
	state_machine.add_transition(chase_state, patrol_state, "to_patrol")
	state_machine.add_transition(chase_state, idle_state, "to_idle")
	state_machine.add_transition(chase_state, attack_state, "to_attack")
	state_machine.add_transition(attack_state, chase_state, "to_chase")
	state_machine.add_transition(attack_state, idle_state, "to_idle")
	state_machine.add_transition(state_machine.ANYSTATE, dead_state, "to_dead")
	
	# Setup state machine
	state_machine.initial_state = idle_state
	state_machine.initialize(self)
	state_machine.set_active(true)

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()

func apply_movement(direction: float, speed: float):
	velocity.x = direction * speed
	
	# Update facing direction
	if direction != 0:
		sprite.flip_h = direction < 0

func get_direction_to_player() -> float:
	if player_reference and is_instance_valid(player_reference):
		return sign(player_reference.global_position.x - global_position.x)
	return 0.0

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		state_machine.dispatch("to_chase")

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		state_machine.dispatch("to_idle")
