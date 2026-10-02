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
const TRANSITION_DASH_ATTACK := "to_dash_attack"

# --- Coyote Time & Jump Buffer ---
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
## Tekanan tombol Attack disimpan sebentar supaya rantai combo terasa responsif
const ATTACK_BUFFER_TIME := 0.15
## Berapa lama rantai combo tetap terbuka setelah satu tebasan selesai
const COMBO_WINDOW := 0.35
## Jeda setelah pukulan pamungkas sebelum rantai baru boleh dimulai.
## Tanpa ini, mashing tombol bisa menyerang tanpa henti.
const COMBO_LOCKOUT := 0.28

# --- Papan one-way ---
## Layer fisika papan/jembatan one-way. Down+Jump di atasnya = turun menembus.
const ONE_WAY_LAYER := 5
## Lama collision papan dimatikan; cukup sampai badan lewat di bawah papan
const DROP_THROUGH_TIME := 0.35

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

# --- Efek ---
## Debu saat mendarat dari lompatan/jatuh
@export var land_dust: PackedScene = preload("res://Scenes/FX/land_dust.tscn")
## Debu saat dash
@export var dash_dust: PackedScene = preload("res://Scenes/FX/dash_dust.tscn")
## Kecepatan jatuh minimal supaya debu mendarat muncul (biar tidak spam saat jalan)
@export var land_dust_min_fall: float = 160.0

# --- State References ---
@onready var idle_state: LimboState = $LimboHSM/Idle
@onready var move_state: LimboState = $LimboHSM/Move
@onready var jump_state: LimboState = $LimboHSM/Jump
@onready var fall_state: LimboState = $LimboHSM/Fall
@onready var attack_state: LimboState = $LimboHSM/Attack
@onready var dash_state: LimboState = $LimboHSM/Dash
@onready var dash_attack_state: LimboState = $LimboHSM/DashAttack
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
var attack_buffer_timer: float = 0.0

## --- Combo ---
## 0,1,2 -> Attack1, Attack2, Attack3
var combo_index: int = 0
## Sisa waktu jendela untuk menyambung pukulan berikutnya
var combo_window: float = 0.0
## Sisa jeda setelah pamungkas
var combo_lockout: float = 0.0
## True setelah end_attack dipanggil: serangan boleh dibatalkan ke dash/lompat
var attack_recovery: bool = false
## Satu serangan udara per lompatan
var air_attack_used: bool = false
var is_dash_attacking: bool = false

var _immunity_tween: Tween = null

## Dipakai mendeteksi momen mendarat dan seberapa keras jatuhnya
var _was_on_floor: bool = true
var _fall_speed: float = 0.0

## Sisa waktu turun menembus papan one-way
var _drop_timer: float = 0.0

## Pentalan saat menyentuh duri: lompatan kecil, laju horizontal dibatasi
const HAZARD_HOP_VELOCITY := -200.0
const HAZARD_MIN_PUSH := 70.0
const HAZARD_MAX_PUSH := 260.0
## Batas lama terpental duri, jaga-jaga kalau tidak pernah mendarat
const HAZARD_MAX_TIME := 0.8
## Naik tiap knockback baru, supaya knockback lama tidak mengakhiri hurt milik yang baru
var _knockback_id: int = 0

## Nilai dasar sebelum dikali modifier upgrade dari RunState.
## Disimpan sekali supaya modifier tidak berlipat ganda tiap kali diterapkan.
var _base_speed: float
var _base_dash_cooldown: float
var _base_immunity: float
var _base_max_health: int


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_initialize_state_machine()

	# Connect health signals
	if health:
		health.death.connect(_on_death)
		health.damaged.connect(_on_damaged)

	_base_speed = speed
	_base_dash_cooldown = dash_cooldown
	_base_immunity = immunity_duration
	_base_max_health = health.max_health if health else 0
	_apply_run_stats()
	RunState.stats_changed.connect(_apply_run_stats)
	RunState.light_depleted.connect(_on_light_depleted)

	# HP dibawa dari area sebelumnya; cahaya diisi penuh di tiap area baru
	if health and RunState.hp > 0:
		health.current_health = mini(RunState.hp, health.max_health)
	RunState.begin_level()


func _exit_tree() -> void:
	# Simpan HP untuk area berikutnya. Saat mati tidak disimpan, karena
	# RunState sudah di-reset untuk run baru.
	if health and health.is_alive():
		RunState.hp = health.current_health


## Terapkan modifier upgrade ke nilai dasar player.
func _apply_run_stats() -> void:
	var st := RunState.stats
	speed = _base_speed * float(st["speed_mult"])
	dash_cooldown = _base_dash_cooldown * maxf(float(st["dash_cd_mult"]), 0.2)
	immunity_duration = _base_immunity + float(st["immunity_bonus"])
	if health:
		var new_max := _base_max_health + int(st["max_hp_bonus"])
		if new_max != health.max_health:
			health.max_health = new_max
			health.current_health = mini(health.current_health, new_max)


## Cahaya padam = mati seketika.
func _on_light_depleted() -> void:
	if health and health.is_alive():
		if OS.is_debug_build():
			print("Cahaya padam! Player mati.")
		health.kill()


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
	# serangan udara: boleh menyerang saat melompat / jatuh, dan kembali ke fall
	state_machine.add_transition(jump_state, attack_state, TRANSITION_ATTACK)
	state_machine.add_transition(fall_state, attack_state, TRANSITION_ATTACK)
	state_machine.add_transition(attack_state, fall_state, TRANSITION_FALL)
	state_machine.add_transition(attack_state, jump_state, TRANSITION_JUMP)
	# rantai combo: Attack -> Attack lagi
	state_machine.add_transition(attack_state, attack_state, TRANSITION_ATTACK)
	# dash attack
	state_machine.add_transition(dash_state, dash_attack_state, TRANSITION_DASH_ATTACK)
	state_machine.add_transition(dash_attack_state, idle_state, TRANSITION_IDLE)
	state_machine.add_transition(dash_attack_state, move_state, TRANSITION_MOVE)
	state_machine.add_transition(dash_attack_state, fall_state, TRANSITION_FALL)
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
	"""Mencatat tekanan Attack ke buffer, lalu memakainya saat state mengizinkan."""
	if Input.is_action_just_pressed("Attack"):
		attack_buffer_timer = ATTACK_BUFFER_TIME

	if attack_buffer_timer <= 0.0:
		return

	var active := state_machine.get_active_state()

	# dash + Attack = tebasan meluncur
	if active == dash_state:
		attack_buffer_timer = 0.0
		state_machine.dispatch(TRANSITION_DASH_ATTACK)
		return

	# menyambung rantai combo saat recovery
	if active == attack_state:
		if attack_recovery and combo_index < 2:
			attack_buffer_timer = 0.0
			combo_index += 1
			state_machine.dispatch(TRANSITION_ATTACK)
		else:
			# Rantai sudah mentok atau belum waktunya. Buang inputnya, jangan
			# dibiarkan meledak begitu keluar dari state Attack.
			attack_buffer_timer = 0.0
		return

	# masih dalam jeda setelah pamungkas
	if combo_lockout > 0.0:
		attack_buffer_timer = 0.0
		return

	# serangan baru dari darat atau udara
	if not is_on_floor() and air_attack_used:
		return

	attack_buffer_timer = 0.0

	# Jendela masih terbuka -> LANJUTKAN rantai, bukan mengulang pukulan yang sama.
	# Jalur ini penting karena recovery Attack2 cuma 0,03 dtk, jadi tekanan
	# tombol hampir selalu mendarat setelah state sudah kembali ke Idle.
	if combo_window > 0.0 and combo_index < 2:
		combo_index += 1
	else:
		combo_index = 0

	state_machine.dispatch(TRANSITION_ATTACK)


func current_attack_animation() -> StringName:
	"""Nama animasi untuk indeks combo saat ini."""
	return StringName("Attack%d" % (clampi(combo_index, 0, 2) + 1))


func check_jump_input() -> void:
	var wants_jump := Input.is_action_just_pressed("Jump") or jump_buffer_timer > 0
	if wants_jump and Input.is_action_pressed("Down") and _standing_on_one_way():
		_drop_through()
		return
	if wants_jump and coyote_timer > 0:
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		state_machine.dispatch(TRANSITION_JUMP)


## Berdiri di atas papan one-way (dan bukan sekaligus di atas batu)?
func _standing_on_one_way() -> bool:
	if not is_on_floor() or not get_collision_mask_value(ONE_WAY_LAYER):
		return false
	var saved := collision_mask
	var one_way_bit := 1 << (ONE_WAY_LAYER - 1)
	collision_mask = one_way_bit
	var on_one_way := test_move(global_transform, Vector2(0, 2))
	collision_mask = saved & ~one_way_bit
	var on_solid := test_move(global_transform, Vector2(0, 2))
	collision_mask = saved
	return on_one_way and not on_solid


func _drop_through() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	set_collision_mask_value(ONE_WAY_LAYER, false)
	_drop_timer = DROP_THROUGH_TIME
	position.y += 2.0
	state_machine.dispatch(TRANSITION_FALL)


func check_dash_input() -> void:
	if Input.is_action_just_pressed("Dash") and can_dash:
		# Set dash direction based on movement input or facing direction
		if movement_input.x != 0:
			dash_direction = Vector2(movement_input.x, 0)
		else:
			dash_direction = Vector2(1 if not sprite.flip_h else -1, 0)

		# debu menyembur berlawanan arah dash
		GameFx.burst(self, dash_dust, global_position + Vector2(0, 8),
			Vector2(-signf(dash_direction.x), 0))

		Audio.play_sfx(&"player_dash", -3.0, 0.05)
		state_machine.dispatch(TRANSITION_DASH)


# --- Combat ---

func start_attack() -> void:
	"""Called when attack animation begins (via AnimationPlayer method track)."""
	if hitbox:
		hitbox.set_active(true)


func cancel_attack_hitbox() -> void:
	"""Matikan hitbox saja, tanpa menyentuh pembukuan combo.
	Dipakai state saat keluar, supaya tidak membuka ulang jendela combo
	yang baru saja ditutup oleh pukulan pamungkas."""
	if hitbox:
		hitbox.set_active(false)


func end_attack() -> void:
	"""Called when attack animation ends (via AnimationPlayer method track)."""
	if hitbox:
		hitbox.set_active(false)
	# mulai dari sini serangan boleh dibatalkan dan rantai combo boleh disambung
	attack_recovery = true
	# Jendela sambung hanya dibuka kalau masih ada pukulan berikutnya.
	# Setelah pamungkas, rantai ditutup supaya tidak bisa berputar terus.
	combo_window = COMBO_WINDOW if combo_index < 2 else 0.0


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

	if attack_buffer_timer > 0.0:
		attack_buffer_timer -= delta
	if combo_lockout > 0.0:
		combo_lockout -= delta

	# Jendela hanya meluruh saat TIDAK sedang menyerang, supaya combo_index
	# tidak ter-reset di tengah animasi dan bikin urutan mundur sendiri.
	if combo_window > 0.0 and state_machine.get_active_state() != attack_state:
		combo_window -= delta
		if combo_window <= 0.0:
			combo_index = 0

	# Dipanggil terpusat, bukan per-state, supaya buffer dan rantai combo
	# tetap terbaca saat sedang menyerang maupun sedang dash.
	check_attack_input()

	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(ONE_WAY_LAYER, true)

	# Update dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		can_dash = false
	else:
		can_dash = true

	# Simpan kecepatan jatuh sebelum move_and_slide menolnya saat menyentuh tanah
	if not is_on_floor():
		_fall_speed = velocity.y

	move_and_slide()

	# Update coyote timer (after move_and_slide so is_on_floor() is current)
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	_check_landing()


func _check_landing() -> void:
	"""Memunculkan debu tepat saat menyentuh tanah, hanya kalau jatuhnya cukup keras."""
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed >= land_dust_min_fall:
		GameFx.burst(self, land_dust, global_position + Vector2(0, 16))
		Audio.play_sfx(&"player_land", -6.0 + minf((_fall_speed - land_dust_min_fall) / 400.0, 1.0) * 4.0)
	if on_floor:
		_fall_speed = 0.0
		air_attack_used = false
	_was_on_floor = on_floor


# --- Animation Callbacks ---

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("Attack"):
		end_attack()
		if combo_index >= 2:
			# Pamungkas selesai: tutup rantai dan beri jeda sebelum combo baru.
			combo_index = 0
			combo_window = 0.0
			combo_lockout = COMBO_LOCKOUT
		state_machine.dispatch(TRANSITION_IDLE)
	elif anim_name == "Dead":
		if OS.is_debug_build():
			print("Dead animation finished, waiting ", respawn_delay, " seconds before ending the run...")
		await get_tree().create_timer(respawn_delay).timeout
		# Roguelike: mati = run berakhir, level dan upgrade di-reset
		RunState.end_run()
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

	knockback_direction = (global_position - source_position).normalized()
	_enter_hurt()

	# Apply knockback
	_apply_knockback()


func _enter_hurt() -> void:
	is_hurt = true

	# Serangan yang terpotong karena kena pukul tidak pernah sampai ke
	# animation_finished, jadi reset rantainya di sini. Tanpa ini combo_index
	# bisa tertinggal di 2 setelah pamungkas yang terinterupsi.
	combo_index = 0
	combo_window = 0.0
	attack_buffer_timer = 0.0

	state_machine.dispatch(TRANSITION_HURT)


func _apply_knockback() -> void:
	"""Apply knockback as a single impulse, then wait before ending hurt state."""
	_knockback_id += 1
	var id := _knockback_id
	velocity = Vector2(knockback_direction.x * knockback_force, -100)
	await get_tree().create_timer(0.2).timeout
	if is_hurt and id == _knockback_id:
		_end_hurt_state()


## Dipanggil duri: lompatan kecil ke arah dir_x yang cukup jauh (distance px)
## untuk keluar dari deretan duri. Kontrol dikunci sampai mendarat.
## Menggantikan knockback biasa kalau duri barusan juga memberi damage.
func hazard_knockback(dir_x: float, distance: float) -> void:
	if health == null or not health.is_alive():
		return
	if not is_hurt:
		_enter_hurt()
	_knockback_id += 1
	var id := _knockback_id

	var air_time := 2.0 * -HAZARD_HOP_VELOCITY / maxf(get_gravity().y, 1.0)
	var push := clampf(distance / air_time, HAZARD_MIN_PUSH, HAZARD_MAX_PUSH)
	velocity = Vector2(signf(dir_x) * push, HAZARD_HOP_VELOCITY)

	var t := 0.0
	while t < HAZARD_MAX_TIME:
		await get_tree().physics_frame
		if id != _knockback_id or not is_hurt:
			return
		t += get_physics_process_delta_time()
		# beberapa frame awal dilewati: player masih menempel di lantai saat baru melompat
		if t > 0.1 and is_on_floor():
			break
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

	Audio.play_sfx(&"player_death", 0.0, 0.0)
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
