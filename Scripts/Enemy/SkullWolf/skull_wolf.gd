extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const KNOCKBACK_FORCE = 100.0  # Kekuatan knockback

## Garis peringatan merah yang sama dengan panah Norc'Thex
const CHARGE_WARNING := preload("res://Scenes/Enemy/NorcThex/arrow_warning.tscn")
## Warna tubuh yang berdenyut selama serigala mengumpulkan tenaga
const TELL_COLOR := Color(1.7, 0.45, 0.45)
## world + papan one-way
const FLOOR_MASK := 1 | (1 << 4)

@onready var health = $Health
@onready var animation_player = $AnimationPlayer
@onready var bt_player = $BTPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

var _warning: Node = null
var _tell_tween: Tween = null
var _shake_tween: Tween = null

var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("enemy")
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
	# Dipukul saat mengumpulkan tenaga/menerkam = serangannya batal
	cancel_attack()
	
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
	cancel_attack()
	
	# Stop AI behavior
	bt_player.set_active(false)
	velocity = Vector2.ZERO

	# Contact damage dan hurtbox dimatikan, supaya serigala yang sedang
	# memainkan animasi mati tidak lagi memukul atau dipukul
	var hitbox := get_node_or_null("Hitbox") as Area2D
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_physics_process(false)
	var hurtbox := get_node_or_null("HurtBox") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	# Play death animation
	animation_player.play("death")
	await animation_player.animation_finished
	await get_tree().create_timer(0.5).timeout
	
	# Cleanup
	queue_free()

func update_facing(direction: float) -> void:
	## Update arah hadap sprite dan hitbox menggunakan scale.x
	if direction == 0:
		return
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D:
		sprite.scale.x = abs(sprite.scale.x) * -sign(direction)
	
	# Flip hitbox juga
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.scale.x = abs(hitbox.scale.x) * -sign(direction)


# --- Terkaman: charge (peringatan) -> lunge (hitbox aktif) -> recover ---
# Dipanggil oleh ai/tasks/wolf_charge_attack.gd

## Arah hadap saat ini (1 kanan, -1 kiri). Sprite aslinya menghadap kiri.
func facing_dir() -> float:
	return -signf(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0


## Mulai mengumpulkan tenaga: menunduk, tubuh berdenyut merah, dan garis
## peringatan sepanjang jalur terkaman supaya player sempat menghindar.
func begin_charge(dir: float, lead_time: float, length: float) -> void:
	update_facing(dir)
	if animation_player.has_animation(&"charge"):
		animation_player.play(&"charge")
	_show_warning(dir, lead_time, length)
	_start_tell()
	Audio.enemy_voice(self, &"attack")


## Melesat: hitbox baru menyala di sini, dan hanya selama terkaman.
func begin_lunge() -> void:
	_stop_tell()
	if animation_player.has_animation(&"lunge"):
		animation_player.play(&"lunge")
	hitbox.set_active(true)
	Audio.play_sfx_at(&"wolf_lunge", global_position, -2.0, 0.06)


## Terkaman selesai: hitbox mati, serigala terengah-engah dan terbuka dipukul.
func begin_recover() -> void:
	hitbox.set_active(false)
	if animation_player.has_animation(&"idle"):
		animation_player.play(&"idle")


## Batalkan semuanya (dipukul, mati, atau task dihentikan)
func cancel_attack() -> void:
	hitbox.set_active(false)
	_stop_tell()
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null


## Ada lantai di depan? Supaya terkaman tidak membuat serigala terjun dari tepi.
func has_floor_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 28.0, -16.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 56.0), FLOOR_MASK)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _show_warning(dir: float, lead_time: float, length: float) -> void:
	if is_instance_valid(_warning):
		_warning.queue_free()
	var warning := CHARGE_WARNING.instantiate() as NorcThexArrowWarning
	warning.direction = Vector2(dir, 0.0)
	warning.length = length
	warning.duration = lead_time
	warning.blink_count = 6.0
	warning.exclude = [get_rid()]
	# keluar dari moncong, dan ikut serigala kalau terdorong
	warning.position = Vector2(dir * 16.0, -16.0)
	add_child(warning)
	_warning = warning


## Tubuh berdenyut merah dan bergetar. Memakai self_modulate supaya tidak
## bentrok dengan kedip putih saat kena pukul (yang memakai modulate).
func _start_tell() -> void:
	_stop_tell()
	_tell_tween = create_tween().set_loops()
	_tell_tween.tween_property(sprite, "self_modulate", TELL_COLOR, 0.1)
	_tell_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.1)
	var shake := create_tween().set_loops()
	shake.tween_property(sprite, "offset:x", 1.5, 0.03)
	shake.tween_property(sprite, "offset:x", -1.5, 0.03)
	_shake_tween = shake


func _stop_tell() -> void:
	if _tell_tween and _tell_tween.is_valid():
		_tell_tween.kill()
	_tell_tween = null
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	sprite.self_modulate = Color.WHITE
	sprite.offset.x = 0.0
