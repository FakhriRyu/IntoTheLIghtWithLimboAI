extends CharacterBody2D
## Goblin dengan LimboHSM. Goblin hanya "melihat" (flag + referensi player);
## keputusan pindah state diambil oleh state masing-masing di _update(),
## bukan dari callback sinyal area, supaya transisi tidak berkedip.

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
## Tetap mengejar sebentar setelah player keluar area deteksi
const LOSE_SIGHT_TIME = 1.5
## Player lebih tinggi/rendah dari ini dianggap di lantai lain: jangan dikejar buta
const MAX_CHASE_HEIGHT = 48.0
## Jarak probe lantai di depan kaki, dan seberapa dalam dicek ke bawah
const LEDGE_PROBE_X = 14.0
const LEDGE_PROBE_DEPTH = 40.0
## world + papan one-way
const FLOOR_MASK = 1 | (1 << 4)
## Zona peringatan sebelum mengayun, dan warna tubuh yang berdenyut
const MELEE_WARNING := preload("res://Scenes/FX/melee_warning.tscn")
const TELL_COLOR := Color(1.7, 0.45, 0.45)

# --- Runtime State ---
var player_reference: CharacterBody2D = null
var player_in_range: bool = false
var player_in_attack_range: bool = false
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO
## Arah hadap saat ini (1 kanan, -1 kiri)
var facing: float = 1.0
## Titik pusat patroli
var spawn_x: float = 0.0

## Variasi per individu supaya gerombolan tidak menumpuk di satu titik
var stop_distance: float = 22.0
var speed_jitter: float = 1.0

var _lose_sight_timer: float = 0.0
var _warning: Node = null
var _tell_tween: Tween = null


func _ready() -> void:
	add_to_group("enemy")
	spawn_x = global_position.x
	stop_distance = randf_range(16.0, 30.0)
	speed_jitter = randf_range(0.9, 1.1)
	_initialize_state_machine()

	if health:
		if health.has_signal("death"):
			health.death.connect(_on_death)
		if health.has_signal("damaged"):
			health.damaged.connect(_on_damaged)


func _initialize_state_machine() -> void:
	state_machine.add_transition(idle_state, chase_state, "to_chase")
	state_machine.add_transition(idle_state, patrol_state, "to_patrol")
	state_machine.add_transition(patrol_state, idle_state, "to_idle")
	state_machine.add_transition(patrol_state, chase_state, "to_chase")
	state_machine.add_transition(chase_state, idle_state, "to_idle")
	state_machine.add_transition(chase_state, attack_state, "to_attack")
	state_machine.add_transition(attack_state, chase_state, "to_chase")
	state_machine.add_transition(attack_state, idle_state, "to_idle")
	state_machine.add_transition(attack_state, attack_state, "to_attack")
	state_machine.add_transition(idle_state, hurt_state, "to_hurt")
	state_machine.add_transition(patrol_state, hurt_state, "to_hurt")
	state_machine.add_transition(chase_state, hurt_state, "to_hurt")
	state_machine.add_transition(attack_state, hurt_state, "to_hurt")
	state_machine.add_transition(hurt_state, idle_state, "to_idle")
	state_machine.add_transition(hurt_state, chase_state, "to_chase")
	state_machine.add_transition(hurt_state, attack_state, "to_attack")
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

	# Lepas jejak player setelah beberapa saat di luar area deteksi
	if not player_in_range and player_reference != null:
		_lose_sight_timer -= delta
		if _lose_sight_timer <= 0.0:
			player_reference = null

	move_and_slide()


# --- Persepsi (dipakai oleh state) ---

## Masih punya target yang hidup untuk dikejar?
func has_target() -> bool:
	if player_reference == null or not is_instance_valid(player_reference):
		return false
	var h = player_reference.get_node_or_null("Health")
	return h == null or h.is_alive()


func get_direction_to_player() -> float:
	if has_target():
		return sign(player_reference.global_position.x - global_position.x)
	return 0.0


## Selisih posisi ke player (x, y). Nol kalau tidak ada target.
func offset_to_player() -> Vector2:
	if has_target():
		return player_reference.global_position - global_position
	return Vector2.ZERO


## Siap mengayun: player di jangkauan serang dan cooldown sudah selesai
func ready_to_attack() -> bool:
	return has_target() and player_in_attack_range and can_attack


## Ada lantai di depan kaki? Mencegah goblin berlari menembus tepi platform.
func has_floor_ahead(dir: float) -> bool:
	if dir == 0.0:
		return true
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * LEDGE_PROBE_X, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LEDGE_PROBE_DEPTH), FLOOR_MASK)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


## Tertahan tembok di arah gerak?
func blocked_ahead(dir: float) -> bool:
	if dir == 0.0 or not is_on_wall():
		return false
	return signf(get_wall_normal().x) == -signf(dir)


## Bisa melangkah ke arah ini tanpa jatuh atau menabrak tembok?
func can_walk(dir: float) -> bool:
	if not is_on_floor():
		return true
	return has_floor_ahead(dir) and not blocked_ahead(dir)


## Mainkan animasi tanpa me-restart animasi yang sedang berjalan
func play_anim(anim: StringName) -> void:
	if animation_player and animation_player.current_animation != anim:
		animation_player.play(anim)


# --- Gerak ---

func apply_movement(direction: float, move_speed: float) -> void:
	velocity.x = direction * move_speed * speed_jitter
	if direction != 0:
		update_facing(direction)


func stop_moving() -> void:
	velocity.x = 0.0


func update_facing(direction: float) -> void:
	if direction == 0:
		return
	facing = signf(direction)

	# Flip sprite dan area sesuai arah gerak/player
	if sprite:
		sprite.flip_h = direction < 0

	if hitbox:
		hitbox.scale.x = -1 if direction < 0 else 1

	if attack_area:
		attack_area.scale.x = -1 if direction < 0 else 1


func start_attack() -> void:
	"""Dipanggil dari AnimationPlayer Method Track saat frame ayunan senjata dimulai."""
	Audio.enemy_voice(self, &"attack")
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(true)


func end_attack() -> void:
	"""Dipanggil dari AnimationPlayer Method Track saat frame ayunan senjata selesai."""
	if hitbox and hitbox.has_method("set_active"):
		hitbox.set_active(false)


## Tampilkan zona merah seukuran hitbox + tubuh berdenyut sebelum mengayun,
## supaya player tahu kapan harus mundur atau menghindar.
func show_attack_warning(lead_time: float) -> void:
	clear_attack_warning()
	var warning := MELEE_WARNING.instantiate() as MeleeWarning
	warning.duration = lead_time
	warning.rect = _hitbox_rect()
	add_child(warning)
	_warning = warning

	# self_modulate, supaya tidak bentrok dengan kedip putih saat kena pukul
	_tell_tween = create_tween().set_loops()
	_tell_tween.tween_property(sprite, "self_modulate", TELL_COLOR, 0.1)
	_tell_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.1)


func clear_attack_warning() -> void:
	if _tell_tween and _tell_tween.is_valid():
		_tell_tween.kill()
	_tell_tween = null
	if sprite:
		sprite.self_modulate = Color.WHITE
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null


## Area yang benar-benar dilukai hitbox serangan, dalam koordinat goblin.
func _hitbox_rect() -> Rect2:
	for c in hitbox.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var size: Vector2 = c.shape.size
			var center: Vector2 = hitbox.transform * c.position
			return Rect2(center - size * 0.5, size)
	return Rect2(-40.0, -6.0, 80.0, 24.0)


func apply_knockback() -> void:
	velocity.x = knockback_direction.x * KNOCKBACK_FORCE


func _on_damaged(_amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_hurt or is_dead:
		return

	is_hurt = true

	# Dipukul = langsung tahu posisi player, walau sedang membelakangi
	var player = get_tree().get_first_node_in_group("player")
	if player is CharacterBody2D:
		player_reference = player
		_lose_sight_timer = LOSE_SIGHT_TIME

	if source_position != Vector2.ZERO:
		knockback_direction = (global_position - source_position).normalized()
	elif player:
		knockback_direction = (global_position - player.global_position).normalized()
	else:
		knockback_direction = Vector2(-1 if sprite.flip_h else 1, 0)

	state_machine.dispatch("to_hurt")


func _on_death() -> void:
	is_dead = true
	clear_attack_warning()
	state_machine.dispatch("to_dead")

	# Disable collision
	set_collision_layer_value(3, false)

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
# Hanya mencatat apa yang dilihat; tidak ada dispatch di sini.

func _on_goblin_detection_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = true
		player_reference = body


func _on_goblin_detection_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = false
		_lose_sight_timer = LOSE_SIGHT_TIME


func _on_goblin_attack_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_attack_range = true


func _on_goblin_attack_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_attack_range = false
