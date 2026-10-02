class_name NorchThex
extends CharacterBody2D

## Arsitektur AI: LimboHSM mengatur "mode" bos (Dormant, Phase1, PhaseShift,
## Phase2, Stagger, Dead), sedangkan pemilihan jurus di tiap fase dijalankan
## oleh behavior tree lewat node BTState (Phase1 & Phase2).

const KNOCKBACK_FORCE = 100.0  # Kekuatan knockback

## Warna kedip saat kena pukul (umpan balik walau bos sedang tidak bisa dihentikan)
@export var flash_color: Color = Color(1.6, 0.6, 0.6)
## Tint permanen selama fase 2, tanda visual bahwa bos sedang mengamuk
@export var phase_two_tint: Color = Color(1.25, 0.8, 0.8)

## Persentase HP (0..1) saat bos berpindah ke fase 2
@export_range(0.0, 1.0) var phase_two_threshold: float = 0.5
## Jumlah perangkap yang dipasang selama fase 2
@export var phase_two_trap_count: int = 5

## Poise: bos baru tersentak setelah sekian pukulan beruntun, bukan tiap pukulan
@export var stagger_hits: int = 3
## Hitungan pukulan direset kalau bos tidak dipukul selama sekian detik
@export var poise_reset_time: float = 2.5

## Batas kemiringan bidikan panah terhadap horizontal (derajat)
@export var max_aim_angle_deg: float = 30.0
## Sudut sebar antar panah saat volley (derajat)
@export var volley_spread_deg: float = 14.0
## Titik bidik relatif terhadap posisi player (badan, bukan kaki)
@export var aim_offset: Vector2 = Vector2(0.0, -8.0)

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

## Jaring pengaman: kalau bos terjatuh lebih dari sekian piksel di bawah pijakan
## aman terakhirnya (mis. terdorong keluar platform), dia muncul kembali di sana
@export var fall_recover_distance: float = 160.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var marker_2d: Marker2D = $Marker2D
@onready var detection_area_boss: Area2D = $DetectionAreaBoss
@onready var health = $Health
@onready var hurt_box: Area2D = $HurtBox

@onready var hsm: LimboHSM = $LimboHSM
@onready var dormant_state: LimboState = $LimboHSM/Dormant
@onready var phase1_state: LimboState = $LimboHSM/Phase1
@onready var phase_shift_state: LimboState = $LimboHSM/PhaseShift
@onready var phase2_state: LimboState = $LimboHSM/Phase2
@onready var stagger_state: LimboState = $LimboHSM/Stagger
@onready var dead_state: LimboState = $LimboHSM/Dead

var is_hurt: bool = false
var is_dead: bool = false
var knockback_direction: Vector2 = Vector2.ZERO

## Saat true, bos tetap menerima damage tapi tidak bisa dihentikan.
## Diset oleh task blink_away.gd selama teleport berlangsung.
var is_uninterruptible: bool = false

## Fase pertarungan saat ini (1 atau 2)
var phase: int = 1
## Dibaca task consume_agent_flag.gd: true = branch "Panic Blink" langsung jalan
var panic_requested: bool = false
## Warna dasar sprite; kedip kena pukul selalu kembali ke warna ini
var base_modulate: Color = Color.WHITE

var flash_tween: Tween

var _poise_hits: int = 0
var _last_hit_time: float = -INF
## Ambang fase 2 tercapai saat bos sedang blink; dijalankan begitu blink selesai
var _phase_shift_pending: bool = false
## Arah bidikan yang dikunci saat garis peringatan muncul
var _aim_dir: Vector2 = Vector2.ZERO
## Posisi terakhir saat bos berdiri di lantai
var _safe_position: Vector2


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")   # dipakai oleh Scenes/UI/boss_health_bar.tscn
	health.death.connect(_on_death)
	health.damaged.connect(_on_damaged)
	_safe_position = global_position
	_initialize_state_machine()


func _initialize_state_machine() -> void:
	hsm.add_transition(dormant_state, phase1_state, &"engage")

	hsm.add_transition(phase1_state, stagger_state, &"stagger")
	hsm.add_transition(phase2_state, stagger_state, &"stagger")
	hsm.add_transition(stagger_state, phase1_state, &"recover_p1")
	hsm.add_transition(stagger_state, phase2_state, &"recover_p2")

	hsm.add_transition(phase1_state, phase_shift_state, &"phase_shift")
	hsm.add_transition(stagger_state, phase_shift_state, &"phase_shift")
	hsm.add_transition(phase_shift_state, phase2_state, &"phase_done")

	hsm.add_transition(hsm.ANYSTATE, dead_state, &"die")

	hsm.initial_state = dormant_state
	hsm.initialize(self)
	hsm.set_active(true)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	_track_safe_ground()


func _track_safe_ground() -> void:
	if is_on_floor():
		_safe_position = global_position
		return

	if global_position.y - _safe_position.y > fall_recover_distance:
		_recover_from_fall()


func _recover_from_fall() -> void:
	"""Bos jatuh ke void: munculkan lagi di pijakan aman terakhir, seolah-olah blink."""
	global_position = _safe_position
	velocity = Vector2.ZERO
	on_blink_in()

	sprite.self_modulate.a = 0.0
	create_tween().tween_property(sprite, "self_modulate:a", 1.0, 0.35)


func facing_vector() -> Vector2:
	"""Arah hadap Norc'Thex sebagai vektor.
	Sprite default (belum di-flip) menghadap KIRI, jadi flip_h berarti menghadap kanan."""
	return Vector2(1.0 if sprite.flip_h else -1.0, 0.0)


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func compute_aim_dir() -> Vector2:
	"""Arah dari titik tembak ke badan player, kemiringannya dibatasi max_aim_angle_deg."""
	var player := _get_player()
	if player == null:
		return facing_vector()

	var to_player: Vector2 = player.global_position + aim_offset - marker_2d.global_position
	var side: float = signf(to_player.x)
	if side == 0.0:
		side = facing_vector().x

	var max_angle: float = deg_to_rad(max_aim_angle_deg)
	var tilt: float = clampf(atan2(to_player.y, absf(to_player.x)), -max_angle, max_angle)
	return Vector2(cos(tilt) * side, sin(tilt))


func has_line_of_fire() -> bool:
	"""True jika panah bisa mengenai player dari posisi sekarang.
	Dipakai task check_line_of_fire.gd supaya bos tidak menembaki dinding."""
	return has_line_of_fire_from(global_position)


func has_line_of_fire_from(body_position: Vector2) -> bool:
	"""True jika dari posisi badan body_position panah bisa mengenai player:
	sudutnya masih dalam batas bidikan dan tidak ada tembok di antara titik tembak
	dan player. Dipakai juga oleh blink_away.gd untuk memilih titik teleport."""
	var player := _get_player()
	if player == null:
		return false

	var target: Vector2 = player.global_position + aim_offset
	var side: float = 1.0 if target.x > body_position.x else -1.0
	var muzzle: Vector2 = body_position + Vector2(absf(marker_2d.position.x) * side, marker_2d.position.y)
	var to_player: Vector2 = target - muzzle

	# Terlalu curam (player jauh di atas/bawah): panah tidak akan sampai
	if absf(atan2(to_player.y, absf(to_player.x))) > deg_to_rad(max_aim_angle_deg):
		return false

	var query := PhysicsRayQueryParameters2D.create(muzzle, target)
	query.collide_with_areas = false
	# hanya tembok (layer world), sama dengan yang menghentikan panah
	query.collision_mask = 1
	var ignored: Array[RID] = [get_rid()]
	if player is CollisionObject2D:
		ignored.append(player.get_rid())
	query.exclude = ignored

	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func show_arrow_warning(lead_time: float = 0.8) -> void:
	"""Menampilkan garis merah peringatan sejalur arah tembakan,
	supaya player bisa mengantisipasi panah yang akan datang.
	Arah bidikan dikunci di sini, jadi panah nanti terbang persis di garis ini."""
	_aim_dir = compute_aim_dir()
	# crossbow dikokang selama garis peringatan tampil
	Audio.play_sfx(&"boss_crossbow_load", -4.0, 0.05)
	_spawn_warning(_aim_dir, lead_time)


func show_volley_warning(lead_time: float = 0.8) -> void:
	"""Tiga garis peringatan berbentuk kipas untuk jurus volley."""
	_aim_dir = compute_aim_dir()
	Audio.play_sfx(&"boss_crossbow_load", -4.0, 0.05)
	for dir in _volley_dirs():
		_spawn_warning(dir, lead_time)


func _spawn_warning(direction: Vector2, lead_time: float) -> void:
	if not arrow_warning_scene:
		return

	var warning = arrow_warning_scene.instantiate()
	warning.direction = direction
	warning.duration = lead_time
	warning.global_position = marker_2d.global_position

	# Jangan sampai garisnya terpotong oleh bos sendiri atau player
	var ignored: Array[RID] = [get_rid()]
	var player := _get_player()
	if player is CollisionObject2D:
		ignored.append(player.get_rid())
	warning.exclude = ignored

	get_parent().add_child(warning)


func _take_aim() -> Vector2:
	"""Arah yang sudah dikunci oleh garis peringatan, lalu dilepas (sekali pakai)."""
	var dir: Vector2 = _aim_dir if _aim_dir != Vector2.ZERO else facing_vector()
	_aim_dir = Vector2.ZERO
	return dir


func _volley_dirs() -> Array[Vector2]:
	var spread: float = deg_to_rad(volley_spread_deg)
	var center: Vector2 = _aim_dir if _aim_dir != Vector2.ZERO else facing_vector()
	return [center.rotated(-spread), center, center.rotated(spread)]


func shoot_arrow() -> void:
	"""Menembakkan proyektil panah ke arah yang sudah dibidik."""
	_spawn_arrow(_take_aim())
	Audio.play_sfx(&"boss_crossbow", 0.0, 0.06)


func shoot_volley() -> void:
	"""Menembakkan tiga panah sekaligus berbentuk kipas."""
	for dir in _volley_dirs():
		_spawn_arrow(dir)
	_aim_dir = Vector2.ZERO
	Audio.play_sfx(&"boss_crossbow", 1.5, 0.06)


func _spawn_arrow(direction: Vector2) -> void:
	if not arrow_scene:
		return

	var arrow = arrow_scene.instantiate()
	arrow.global_position = marker_2d.global_position
	arrow.direction = direction
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


## Dipanggil task blink_away.gd saat mulai menghilang dan saat muncul kembali
func on_blink_out() -> void:
	Audio.play_sfx(&"boss_vanish", -3.0, 0.04)


func on_blink_in() -> void:
	Audio.play_sfx(&"boss_appear", -3.0, 0.04)


func set_uninterruptible(value: bool) -> void:
	"""Dipanggil oleh task BT / state yang sedang menjalankan gerakan yang tidak boleh dibatalkan."""
	is_uninterruptible = value

	# Ambang fase 2 tercapai di tengah blink: jalankan sekarang setelah blink selesai.
	# Deferred karena setter ini bisa dipanggil dari _exit sebuah task di tengah
	# transisi state lain.
	if not value and _phase_shift_pending:
		_start_phase_shift.call_deferred()


func hp_ratio() -> float:
	return float(health.current_health) / float(health.max_health)


func enter_phase_two() -> void:
	"""Dipanggil state PhaseShift: naikkan tekanan bos untuk sisa pertarungan."""
	phase = 2
	trap_count = phase_two_trap_count
	base_modulate = phase_two_tint
	_poise_hits = 0


func _start_phase_shift() -> void:
	_phase_shift_pending = false
	if is_dead or phase != 1:
		return

	var state := hsm.get_active_state()
	if state == phase1_state or state == stagger_state:
		hsm.dispatch(&"phase_shift")


func _flash() -> void:
	"""Kedip merah sebagai tanda pukulan masuk."""
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	sprite.modulate = flash_color
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", base_modulate, 0.15)


func _on_damaged(_amount: int) -> void:
	if is_dead:
		return

	# Pukulan selalu terasa, walau bos sedang tidak bisa dihentikan
	_flash()

	# Pukulan mematikan: biarkan sinyal death yang mengambil alih
	if health.current_health <= 0:
		return

	var state := hsm.get_active_state()

	# Dipukul sebelum sempat sadar: langsung bertarung
	if state == dormant_state:
		hsm.dispatch(&"engage")
		return

	if phase == 1 and hp_ratio() <= phase_two_threshold:
		if is_uninterruptible:
			# Sedang teleport: tunggu blink selesai (lihat set_uninterruptible)
			_phase_shift_pending = true
		else:
			_start_phase_shift()
		return

	# Sedang teleport/ganti fase/tersentak: HP tetap berkurang, tapi tidak dibatalkan.
	# Inilah yang mencegah player mengunci bos dengan serangan beruntun.
	if is_uninterruptible or state == stagger_state or state == phase_shift_state:
		return

	_register_poise_hit()


func _register_poise_hit() -> void:
	"""Poise: bos hanya tersentak setelah stagger_hits pukulan beruntun."""
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time > poise_reset_time:
		_poise_hits = 0
	_last_hit_time = now
	_poise_hits += 1

	if _poise_hits >= stagger_hits:
		_poise_hits = 0
		hsm.dispatch(&"stagger")


func _on_death() -> void:
	if is_dead:
		return

	is_dead = true
	is_hurt = false
	is_uninterruptible = false
	_phase_shift_pending = false
	hsm.dispatch(&"die")
