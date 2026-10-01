class_name NorchThex
extends CharacterBody2D

const KNOCKBACK_FORCE = 100.0  # Kekuatan knockback

## Flag blackboard yang memberi tahu behavior tree bahwa bos baru saja dipukul,
## supaya branch "Panic Blink" langsung menendang dan bos kabur.
const HIT_FLAG := &"was_hit"

## Warna kedip saat kena pukul (umpan balik walau bos sedang tidak bisa dihentikan)
@export var flash_color: Color = Color(1.6, 0.6, 0.6)

@export var arrow_scene: PackedScene = preload("res://Scenes/Enemy/NorcThex/arrow.tscn")
@export var trap_scene: PackedScene = preload("res://Scenes/Enemy/NorcThex/trap.tscn")
@export var arrow_warning_scene: PackedScene = preload("res://Scenes/Enemy/NorcThex/arrow_warning.tscn")

## Berapa perangkap yang dipasang sekaligus di bawah player
@export var trap_count: int = 3
## Jarak antar perangkap
@export var trap_spacing: float = 44.0
## Sejauh apa mencari lantai ke bawah dari posisi player
@export var trap_ground_probe: float = 260.0
## Jarak titik asal perangkap ke lantai (setengah tinggi sprite 64px)
@export var trap_ground_offset: float = 32.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var marker_2d: Marker2D = $Marker2D
@onready var detection_area_boss: Area2D = $DetectionAreaBoss
@onready var health = $Health
@onready var bt_player = $BTPlayer
@onready var hurt_box: Area2D = $HurtBox

var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO

## Saat true, bos tetap menerima damage tapi tidak bisa dihentikan.
## Diset oleh task blink_away.gd selama teleport berlangsung.
var is_uninterruptible: bool = false

var flash_tween: Tween


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")   # dipakai oleh Scenes/UI/boss_health_bar.tscn
	health.death.connect(_on_death)
	health.damaged.connect(_on_damaged)

	# Flag harus sudah ada sejak awal, kalau tidak BTCheckVar akan error tiap tick
	bt_player.blackboard.set_var(HIT_FLAG, false)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()


func facing_vector() -> Vector2:
	"""Arah hadap Norc'Thex sebagai vektor.
	Sprite default (belum di-flip) menghadap KIRI, jadi flip_h berarti menghadap kanan."""
	return Vector2(1.0 if sprite.flip_h else -1.0, 0.0)


func show_arrow_warning(lead_time: float = 0.8) -> void:
	"""Menampilkan garis merah peringatan sejalur arah tembakan,
	supaya player bisa mengantisipasi panah yang akan datang."""
	if not arrow_warning_scene:
		return

	var warning = arrow_warning_scene.instantiate()
	warning.direction = facing_vector()
	warning.duration = lead_time
	warning.global_position = marker_2d.global_position

	# Jangan sampai garisnya terpotong oleh bos sendiri atau player
	var ignored: Array[RID] = [get_rid()]
	var player = get_tree().get_first_node_in_group("player")
	if player is CollisionObject2D:
		ignored.append(player.get_rid())
	warning.exclude = ignored

	get_parent().add_child(warning)


func shoot_arrow() -> void:
	"""Menembakkan proyektil panah ke arah hadap Norc'Thex."""
	if not arrow_scene:
		return

	var arrow = arrow_scene.instantiate()
	arrow.global_position = marker_2d.global_position
	arrow.direction = facing_vector()
	Audio.play_sfx_at(&"arrow_shot", marker_2d.global_position, -2.0)

	get_parent().add_child(arrow)


func spawn_trap() -> void:
	"""Memasang beberapa perangkap berjajar tepat di bawah player.
	Tiap perangkap ditempelkan ke lantai lewat raycast supaya tidak melayang di udara."""
	if not trap_scene:
		return

	Audio.enemy_voice(self, &"attack")
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var center: float = (trap_count - 1) * 0.5

	for i in trap_count:
		var origin := Vector2(
			player.global_position.x + (i - center) * trap_spacing,
			player.global_position.y)

		var ground := _find_ground(origin, player)
		if is_inf(ground):
			continue

		var trap = trap_scene.instantiate()
		trap.global_position = Vector2(origin.x, ground - trap_ground_offset)
		get_parent().add_child(trap)


func _find_ground(from: Vector2, player: Node2D) -> float:
	"""Mencari permukaan lantai di bawah sebuah titik.
	Mengembalikan koordinat y lantai, atau INF jika tidak ada lantai di bawahnya."""
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, trap_ground_probe))
	query.collide_with_areas = false
	# hanya lantai (world + papan one-way), bukan body musuh/player
	query.collision_mask = 1 | (1 << 4)

	# Abaikan bos dan player supaya yang terdeteksi hanya lantai
	var ignored: Array[RID] = [get_rid()]
	if player is CollisionObject2D:
		ignored.append(player.get_rid())
	query.exclude = ignored

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return INF

	return hit.position.y


func update_facing(direction: float) -> void:
	"""Membalik sprite dan posisi titik panah (Marker2D) sesuai arah hadap/kecepatan."""
	if direction == 0:
		return

	# Sprite default menghadap kiri, jadi flip_h hanya saat menghadap kanan
	sprite.flip_h = direction > 0
	marker_2d.position.x = abs(marker_2d.position.x) * (-1 if direction < 0 else 1)


func set_uninterruptible(value: bool) -> void:
	"""Dipanggil oleh task BT yang sedang menjalankan gerakan yang tidak boleh dibatalkan."""
	is_uninterruptible = value


func _flash() -> void:
	"""Kedip merah sebagai tanda pukulan masuk."""
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	sprite.modulate = flash_color
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _on_damaged(_amount: int) -> void:
	if is_dead:
		return

	# Pukulan selalu terasa, walau bos sedang tidak bisa dihentikan
	_flash()

	# Sedang teleport: HP tetap berkurang, tapi gerakannya tidak boleh dibatalkan.
	# Inilah yang mencegah player mengunci bos dengan serangan beruntun.
	if is_uninterruptible or is_hurt:
		return

	is_hurt = true

	# Pause AI saat hurt
	bt_player.set_active(false)

	# Hitung arah knockback (dari player)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		knockback_direction = (global_position - player.global_position).normalized()
	else:
		# Terdorong ke belakang relatif arah hadap sekarang
		knockback_direction = Vector2(-1 if sprite.flip_h else 1, 0)

	# Apply knockback
	_apply_knockback()

	# Play hurt animation dan tunggu selesai
	animation_player.play("hurt")
	await animation_player.animation_finished

	# End hurt state setelah animasi selesai
	_end_hurt_state()


func _apply_knockback() -> void:
	# Knockback selama beberapa physics frame
	for i in range(10):
		if is_dead:
			return
		velocity.x = knockback_direction.x * KNOCKBACK_FORCE
		await get_tree().physics_frame


func _end_hurt_state() -> void:
	if is_dead:
		return

	# Reset state
	is_hurt = false
	knockback_direction = Vector2.ZERO
	velocity.x = 0

	# Restart AI jika masih hidup, lalu suruh langsung kabur.
	# Flag diset SESUDAH restart supaya tidak ikut terhapus kalau restart
	# membersihkan state tree.
	if health.current_health > 0:
		bt_player.restart()
		bt_player.blackboard.set_var(HIT_FLAG, true)


func _on_death() -> void:
	if is_dead:
		return

	is_dead = true
	is_hurt = false
	is_uninterruptible = false
	Audio.enemy_voice(self, &"death")

	# Stop AI behavior
	bt_player.set_active(false)

	# Bos sudah mati: jangan terima pukulan lagi selama animasi death
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

	# Play death animation
	animation_player.play("death")
	await animation_player.animation_finished
	await get_tree().create_timer(0.5).timeout

	# Cleanup
	queue_free()
