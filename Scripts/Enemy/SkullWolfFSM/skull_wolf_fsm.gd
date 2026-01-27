extends CharacterBody2D

@export var state_machine : LimboHSM

@onready var idle_state = $LimboHSM/Idle
@onready var chase_state = $LimboHSM/Chase
@onready var dead_state = $LimboHSM/Dead
@onready var hurt_state = $LimboHSM/Hurt

@onready var health = $Health
@onready var sprite : Sprite2D = $Sprite2D
@onready var animation_player = $AnimationPlayer
@onready var hurtbox: Area2D = $Hurtbox

const SPEED = 80
const KNOCKBACK_FORCE = 100.0

var player_reference: CharacterBody2D = null
var player_in_range: bool = false
var player_in_attack_range: bool = false
var can_attack: bool = true
var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	health.death.connect(_on_death)
	health.damaged.connect(_on_damaged)
	_initialize_state_machine()

func _initialize_state_machine() -> void:
	state_machine.add_transition(idle_state, chase_state, "to_chase")
	state_machine.add_transition(chase_state, idle_state, "to_idle")
	state_machine.add_transition(chase_state, hurt_state, "to_hurt")
	state_machine.add_transition(idle_state, hurt_state, "to_hurt")
	state_machine.add_transition(hurt_state, idle_state, "to_idle")
	state_machine.add_transition(hurt_state, chase_state, "to_chase")
	state_machine.add_transition(state_machine.ANYSTATE, dead_state, "to_dead")
	
	state_machine.initial_state = idle_state
	state_machine.initialize(self)
	state_machine.set_active(true)

func _process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()
	
func apply_movement(direction: float, speed: float):
	velocity.x = direction * speed
	
	if direction != 0:
		update_facing(direction)

func get_direction_to_player() -> float:
	if player_reference and is_instance_valid(player_reference):
		return sign(player_reference.global_position.x - global_position.x)
	return 0.0

func _on_detection_area_body_entered(body:Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		state_machine.dispatch("to_chase")

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		state_machine.dispatch("to_idle")

func _on_damaged(_amount: int):
	if is_hurt or is_dead:
		return
	
	is_hurt = true
	
	# Hitung arah knockback (dari player)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		knockback_direction = (global_position - player.global_position).normalized()
	else:
		knockback_direction = Vector2(-sign(sprite.scale.x), 0)
	
	state_machine.dispatch("to_hurt")

func apply_knockback():
	velocity.x = knockback_direction.x * KNOCKBACK_FORCE

func _on_death() -> void:
	# Trigger transition ke dead state
	state_machine.dispatch("to_dead")
	
	# Disable hitbox agar tidak menyakiti pemain saat mati
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	
	# Disable hurtbox agar tidak bisa dipukul lagi
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

func update_facing(direction: float) -> void:
	## Update arah hadap sprite dan hitbox menggunakan scale.x
	if direction == 0:
		return
	
	if sprite:
		sprite.scale.x = abs(sprite.scale.x) * -sign(direction)
	
	# Flip hitbox juga
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.scale.x = abs(hitbox.scale.x) * -sign(direction)