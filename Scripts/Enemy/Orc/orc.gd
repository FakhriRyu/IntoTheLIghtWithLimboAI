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
@onready var hitbox: Area2D = $Hitbox
@onready var attack_area: Area2D = $AttackArea
@onready var health: Node = $Health
@onready var hurtbox: Area2D = $Hurtbox

# AI Properties
const SPEED = 80.0
const CHASE_SPEED = 120.0
const PATROL_DISTANCE = 100.0
const ATTACK_COOLDOWN = 2.0

var player_reference: CharacterBody2D = null
var player_in_range: bool = false
var player_in_attack_range: bool = false
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0

func _ready() -> void:
	_initialize_state_machine()
	# Set initial facing direction (default kanan)
	update_facing_direction(1.0)
	
	# Connect health signals
	if health and health.has_signal("death"):
		health.death.connect(_on_death)

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
	
	state_machine.initial_state = idle_state
	state_machine.initialize(self)
	state_machine.set_active(true)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true
	
	move_and_slide()

func apply_movement(direction: float, speed: float):
	velocity.x = direction * speed
	
	if direction != 0:
		sprite.flip_h = direction < 0
		# Flip attack area dan hitbox mengikuti arah
		update_facing_direction(direction)

func start_attack():
	velocity.x = 0
	can_attack = false
	attack_cooldown_timer = ATTACK_COOLDOWN
	
	# Update facing ke arah player sebelum attack
	var dir = get_direction_to_player()
	if dir != 0:
		sprite.flip_h = dir < 0
		update_facing_direction(dir)
	
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(true)

func end_attack():
	velocity.x = 0
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(false)

func update_facing_direction(direction: float):
	# Flip attack_area dan hitbox mengikuti arah hadap
	# direction > 0 = kanan, direction < 0 = kiri
	if attack_area:
		attack_area.scale.x = -1 if direction < 0 else 1
	if hitbox:
		hitbox.scale.x = -1 if direction < 0 else 1

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


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_attack_range = true
		if can_attack:
			state_machine.dispatch("to_attack")

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_attack_range = false
		state_machine.dispatch("to_chase")

func _on_death() -> void:
	# Trigger transition ke dead state
	state_machine.dispatch("to_dead")
	
	# Disable collision agar tidak mengganggu player
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Disable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
