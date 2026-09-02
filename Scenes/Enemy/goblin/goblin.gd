extends CharacterBody2D

@export var state_machine: LimboHSM

# --- States ---
@onready var idle_state: LimboState = $LimboHSM/Idle
@onready var chase_state: LimboState = $LimboHSM/Chase
@onready var dead_state: LimboState = $LimboHSM/Dead
@onready var hurt_state: LimboState = $LimboHSM/Hurt
@onready var attack_state: LimboState = $LimboHSM/Attack
@onready var patrol_state: LimboState = $LimboHSM/Patrol

# --- Components ---
@onready var health = $GoblinHealth
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurtbox: Area2D = $GoblinHurtBox
@onready var hitbox: Area2D = $GoblinHitBox
@onready var attack_area: Area2D = $GoblinAttackArea
@onready var detection_area: Area2D = $GoblinDetection

# --- AI Properties ---
const SPEED = 80.0
const CHASE_SPEED = 120.0
const PATROL_DISTANCE = 100.0
const ATTACK_COOLDOWN = 2.0
const KNOCKBACK_FORCE = 100.0

# --- Runtime State ---
var player_reference: CharacterBody2D = null
var player_in_range: bool = false
var player_in_attack_range: bool = false
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemy")
	_initialize_state_machine()
	
	if health:
		if health.has_signal("death"):
			health.death.connect(_on_death)
		if health.has_signal("damaged"):
			health.damaged.connect(_on_damaged)


func _initialize_state_machine() -> void:
	# Define state transitions
	state_machine.add_transition(idle_state, chase_state, "to_chase")
	state_machine.add_transition(chase_state, idle_state, "to_idle")
	state_machine.add_transition(chase_state, attack_state, "to_attack")
	state_machine.add_transition(attack_state, chase_state, "to_chase")
	state_machine.add_transition(attack_state, idle_state, "to_idle")
	state_machine.add_transition(chase_state, hurt_state, "to_hurt")
	state_machine.add_transition(idle_state, hurt_state, "to_hurt")
	state_machine.add_transition(attack_state, hurt_state, "to_hurt")
	state_machine.add_transition(hurt_state, idle_state, "to_idle")
	state_machine.add_transition(hurt_state, chase_state, "to_chase")
	state_machine.add_transition(state_machine.ANYSTATE, dead_state, "to_dead")

	state_machine.initial_state = idle_state
	state_machine.initialize(self)
	state_machine.set_active(true)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Hitung mundur cooldown attack
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true

	move_and_slide()


func apply_movement(direction: float, move_speed: float) -> void:
	velocity.x = direction * move_speed

	if direction != 0:
		update_facing(direction)


func get_direction_to_player() -> float:
	if player_reference and is_instance_valid(player_reference):
		return sign(player_reference.global_position.x - global_position.x)
	return 0.0


func update_facing(direction: float) -> void:
	if direction == 0:
		return

	# Flip sprite dan area sesuai arah gerak/player
	if sprite:
		sprite.flip_h = direction < 0

	if hitbox:
		hitbox.scale.x = -1 if direction < 0 else 1

	if attack_area:
		attack_area.scale.x = -1 if direction < 0 else 1


func start_attack() -> void:
	"""Dipanggil dari AnimationPlayer Method Track saat frame ayunan senjata dimulai."""
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(true)


func end_attack() -> void:
	"""Dipanggil dari AnimationPlayer Method Track saat frame ayunan senjata selesai."""
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(false)


func apply_knockback() -> void:
	velocity.x = knockback_direction.x * KNOCKBACK_FORCE


func _on_damaged(_amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_hurt or is_dead:
		return

	is_hurt = true

	if source_position != Vector2.ZERO:
		knockback_direction = (global_position - source_position).normalized()
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			knockback_direction = (global_position - player.global_position).normalized()
		else:
			knockback_direction = Vector2(-1 if sprite.flip_h else 1, 0)

	state_machine.dispatch("to_hurt")


func _on_death() -> void:
	is_dead = true
	state_machine.dispatch("to_dead")

	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Disable hitbox
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(false)
	elif hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	# Disable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)


# --- Detection Signal Callbacks ---

func _on_goblin_detection_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		state_machine.dispatch("to_chase")


func _on_goblin_detection_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		state_machine.dispatch("to_idle")


func _on_goblin_attack_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_attack_range = true
		if can_attack:
			state_machine.dispatch("to_attack")


func _on_goblin_attack_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_attack_range = false
		state_machine.dispatch("to_chase")
