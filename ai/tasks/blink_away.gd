@tool
extends BTAction
## Menghilang lalu muncul kembali di titik acak yang aman di arena (blink/teleport)
## Dipakai musuh tanpa animasi jalan yang tetap perlu berpindah posisi
## Urutan: animasi menghilang ➜ pindah posisi ➜ animasi muncul ➜ set cooldown
## Titik tujuan dipilih ACAK dari semua titik aman di arena yang jaraknya ke target
## berada di antara min_distance dan max_distance, jadi bisa mundur, maju melewati
## target, pindah jauh ke sisi lain arena, atau naik/turun ke lantai yang sedikit
## lebih tinggi/rendah (max_step_up / max_step_down). Titik yang ada jalur tembak bersih
## ke target dan belum lama dipakai lebih sering terpilih.
## Returns RUNNING selama proses blink berlangsung
## Returns SUCCESS setelah animasi muncul selesai (dan set cooldown)
## Returns FAILURE jika target tidak valid atau animasi tidak ditemukan

enum Phase { OUT, IN }

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## Path ke AnimationPlayer milik agent
@export var animation_player_path: NodePath = ^"AnimationPlayer"

## Animasi saat menghilang
@export var out_animation: StringName = &"fadeaway"

## Animasi saat muncul kembali
@export var in_animation: StringName = &"fadein"

## Jarak horizontal minimal titik tujuan dari target
@export var min_distance: float = 160.0

## Jarak horizontal maksimal titik tujuan dari target
@export var max_distance: float = 480.0

## Jarak minimal titik tujuan dari posisi agent sekarang, supaya blink benar-benar pindah
@export var min_travel: float = 96.0

## Kalau true, agent hanya muncul di SISI SEBERANG target (menyergap dari belakang)
@export var land_behind_target: bool = false

## Durasi cooldown setelah blink (detik)
@export var cooldown_duration: float = 5.0

## Blackboard variable untuk menyimpan waktu cooldown berakhir
@export var cooldown_var: StringName = &"blink_cooldown_end"

@export_group("Arena")
## Area2D milik agent yang menandai lebar arena. Batasnya direkam sekali saat setup
## (posisi awal agent), jadi arena tidak ikut bergeser saat agent berpindah.
## Kalau tidak ada, arena = target ± max_distance.
@export var arena_area_path: NodePath = ^"DetectionAreaBoss"

## Jarak antar titik yang dicoba saat memindai arena (piksel)
@export var scan_step: float = 8.0

@export_group("Bobot pilihan")
## Pengali peluang untuk titik yang punya jalur tembak bersih ke target. 1 = netral
@export var clear_shot_weight: float = 4.0

## Kalau true, hanya titik dengan jalur tembak bersih ke target yang boleh dipilih
## (dipakai blink yang tujuannya menembak: sergap & reposisi). Kalau tidak ada
## satu pun, syarat ini dilonggarkan supaya agent tetap berpindah.
@export var require_clear_shot: bool = false

## Berapa titik blink terakhir yang diingat supaya agent tidak bolak-balik ke tempat sama
@export var recent_count: int = 3

## Radius di sekitar titik yang baru dipakai yang peluangnya dikurangi
@export var recent_radius: float = 64.0

## Pengali peluang untuk titik di dekat titik yang baru dipakai
@export var recent_weight: float = 0.15

@export_group("Keamanan pijakan")
## Seberapa tinggi lantai tujuan boleh berada DI ATAS pijakan sekarang. Dibatasi
## supaya agent tidak kabur ke ledge yang tidak bisa dicapai player
@export var max_step_up: float = 40.0

## Seberapa rendah lantai tujuan boleh berada DI BAWAH pijakan sekarang.
## Dibatasi supaya agent tidak muncul di dasar jurang
@export var max_step_down: float = 40.0

## Setengah lebar pijakan yang wajib ada lantainya (dicek di kiri, tengah, kanan),
## supaya agent tidak mendarat di bibir platform lalu tergelincir jatuh
@export var foothold_half_width: float = 12.0

## Ruang kosong yang wajib ada di atas badan agent, supaya tidak muncul
## di ceruk sempit dengan langit-langit rendah
@export var headroom: float = 24.0

## Ruang kosong yang wajib ada di KIRI dan KANAN badan agent, supaya agent tidak
## muncul terjepit di ceruk sempit atau menempel tembok lalu tidak bisa ke mana-mana
@export var elbow_room: float = 32.0

## Badan diangkat sedikit saat dicek supaya lantai yang menempel di kaki
## tidak dihitung sebagai tabrakan
const LIFT := 2.0

## Meta pada agent untuk riwayat titik blink (dibagi antar semua task blink agent itu)
const HISTORY_META := &"blink_history"

var animation_player: AnimationPlayer
## Collision shape badan agent, dipakai untuk cek apakah agent muat di titik tujuan
var body_shape: CollisionShape2D
## Batas arena (x global); INF berarti tidak ada
var arena_min_x: float = INF
var arena_max_x: float = INF

## Fase yang sedang berjalan
var phase: int = Phase.OUT
## Timer internal untuk fase yang sedang berjalan
var elapsed: float = 0.0


func _generate_name() -> String:
	var mode := "BlinkBehind" if land_behind_target else "BlinkRandom"
	return "%s %s (%.0f..%.0fpx, cd:%.1fs)" % [mode, LimboUtility.decorate_var(target_var), min_distance, max_distance, cooldown_duration]


func _setup() -> void:
	if animation_player_path:
		animation_player = agent.get_node_or_null(animation_player_path)

	for child in agent.get_children():
		if child is CollisionShape2D and child.shape != null and not child.disabled:
			body_shape = child
			break

	_record_arena_bounds()


func _record_arena_bounds() -> void:
	var area: Area2D = null
	if arena_area_path:
		area = agent.get_node_or_null(arena_area_path) as Area2D
	if area == null:
		return
	for child in area.get_children():
		if child is CollisionShape2D and child.shape != null:
			var rect: Rect2 = child.shape.get_rect()
			var xform: Transform2D = child.global_transform
			arena_min_x = (xform * rect.position).x
			arena_max_x = (xform * rect.end).x
			if arena_min_x > arena_max_x:
				var tmp := arena_min_x
				arena_min_x = arena_max_x
				arena_max_x = tmp
			return


func _enter() -> void:
	phase = Phase.OUT
	elapsed = 0.0

	# Selama blink berlangsung agent tidak boleh dihentikan oleh serangan,
	# supaya player tidak bisa mengunci agent dengan pukulan beruntun.
	if agent.has_method("set_uninterruptible"):
		agent.set_uninterruptible(true)

	if agent is CharacterBody2D:
		agent.velocity.x = 0

	if animation_player != null and animation_player.has_animation(out_animation):
		animation_player.play(out_animation)
	# hook opsional untuk efek suara/visual milik agent
	if agent.has_method(&"on_blink_out"):
		agent.on_blink_out()


func _tick(delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)

	if not is_instance_valid(target):
		return FAILURE

	if animation_player == null:
		return FAILURE

	if not animation_player.has_animation(out_animation) or not animation_player.has_animation(in_animation):
		return FAILURE

	elapsed += delta

	if phase == Phase.OUT:
		if elapsed < animation_player.get_animation(out_animation).length:
			return RUNNING

		_teleport(target)

		phase = Phase.IN
		elapsed = 0.0
		animation_player.play(in_animation)
		if agent.has_method(&"on_blink_in"):
			agent.on_blink_in()
		return RUNNING

	# Phase.IN
	if elapsed < animation_player.get_animation(in_animation).length:
		return RUNNING

	var cooldown_end_time: float = Time.get_ticks_msec() / 1000.0 + cooldown_duration
	blackboard.set_var(cooldown_var, cooldown_end_time)

	return SUCCESS


func _teleport(target: Node2D) -> void:
	var destination: Vector2 = pick_destination(target)
	if not destination.is_finite():
		# Tidak ada tempat berpijak yang aman: tetap di tempat, jangan jatuh ke jurang
		return

	agent.global_position = destination
	if agent is CharacterBody2D:
		agent.velocity = Vector2.ZERO
	_remember(destination.x)

	# Muncul kembali sambil menghadap target
	var facing: float = signf(target.global_position.x - destination.x)
	if facing != 0.0 and agent.has_method("update_facing"):
		agent.update_facing(facing)


func pick_destination(target: Node2D) -> Vector2:
	"""Pindai arena, kumpulkan semua titik aman yang memenuhi syarat jarak,
	lalu pilih satu secara acak berbobot. Vector2.INF kalau tidak ada satu pun.
	Kalau tidak ada titik yang memenuhi syarat, syarat dilonggarkan bertahap:
	sisi mana pun (untuk mode sergap), lalu tanpa syarat jalur tembak."""
	for behind: bool in ([true, false] if land_behind_target else [false]):
		var destination: Vector2 = _pick(target, behind, require_clear_shot)
		if destination.is_finite():
			return destination
	if require_clear_shot:
		return _pick(target, false, false)
	return Vector2.INF


func _pick(target: Node2D, behind_only: bool, need_clear_shot: bool) -> Vector2:
	var target_x: float = target.global_position.x
	var here: float = agent.global_position.x

	var lo: float = target_x - max_distance
	var hi: float = target_x + max_distance
	if not is_inf(arena_min_x):
		lo = maxf(lo, arena_min_x)
		hi = minf(hi, arena_max_x)

	# Sisi tempat agent berada relatif terhadap target (untuk mode sergap)
	var agent_side: float = signf(here - target_x)
	if agent_side == 0.0:
		agent_side = 1.0

	var history: Array = agent.get_meta(HISTORY_META, [])
	var candidates: PackedVector2Array = []
	var weights: PackedFloat32Array = []
	var total: float = 0.0

	var x: float = lo
	while x <= hi:
		var dist: float = absf(x - target_x)
		var ok: bool = dist >= min_distance and dist <= max_distance \
				and absf(x - here) >= min_travel
		if ok and behind_only:
			ok = signf(x - target_x) == -agent_side
		var spot := Vector2.INF
		if ok:
			spot = find_landing(x)
		if spot.is_finite():
			var clear: bool = _has_clear_shot(spot, target)
			if clear or not need_clear_shot:
				var weight: float = clear_shot_weight if clear else 1.0
				for past in history:
					if absf(x - float(past)) < recent_radius:
						weight *= recent_weight
						break
				candidates.append(spot)
				weights.append(weight)
				total += weight
		x += scan_step

	if candidates.is_empty():
		return Vector2.INF

	var roll: float = randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


func _remember(x: float) -> void:
	var history: Array = agent.get_meta(HISTORY_META, [])
	history.push_front(x)
	while history.size() > maxi(recent_count, 0):
		history.pop_back()
	agent.set_meta(HISTORY_META, history)


func _has_clear_shot(spot: Vector2, target: Node2D) -> bool:
	"""Apakah dari titik ini agent bisa menembak target.
	Pakai method agent kalau ada (sudah termasuk batas sudut bidikan),
	selain itu raycast sederhana dari tengah badan."""
	if agent.has_method(&"has_line_of_fire_from"):
		return agent.has_line_of_fire_from(spot)

	var ray := PhysicsRayQueryParameters2D.create(spot, target.global_position)
	ray.collide_with_areas = false
	ray.collision_mask = 1
	var ignored: Array[RID] = [agent.get_rid()]
	if target is CollisionObject2D:
		ignored.append(target.get_rid())
	ray.exclude = ignored
	return agent.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _feet_offset() -> float:
	"""Jarak dari titik asal agent ke telapak kakinya (dasar collision shape)."""
	return body_shape.position.y + body_shape.shape.get_rect().end.y


func find_landing(at_x: float) -> Vector2:
	"""Cari lantai di kolom at_x dalam rentang max_step_up..max_step_down dari
	pijakan sekarang, lalu pastikan aman. Hasilnya posisi agent (titik asal),
	atau Vector2.INF kalau tidak ada lantai yang aman di kolom ini."""
	if body_shape == null:
		return Vector2.INF

	var feet_offset: float = _feet_offset()
	var feet_y: float = agent.global_position.y + feet_offset
	var from := Vector2(at_x, feet_y - max_step_up)
	var ray := PhysicsRayQueryParameters2D.create(from, Vector2(at_x, feet_y + max_step_down))
	ray.collide_with_areas = false
	# Mask-nya sama dengan agent: lapisan yang tidak ditabrak agent (mis. papan
	# one-way) bukan lantai baginya, walau terlihat seperti lantai.
	ray.collision_mask = agent.collision_mask
	var ignored: Array[RID] = [agent.get_rid()]
	ray.exclude = ignored

	var hit: Dictionary = agent.get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return Vector2.INF

	var spot := Vector2(at_x, hit.position.y - feet_offset)
	return spot if _is_safe_landing(spot) else Vector2.INF


func _is_safe_landing(spot: Vector2) -> bool:
	"""Titik mendarat aman jika badan agent muat di sana (tidak masuk ke dalam
	tembok/ledge, yang bisa membuat agent terdorong keluar lalu jatuh ke void),
	ada ruang kosong di atas kepala serta di kiri-kanannya (bukan ceruk sempit),
	dan ada lantai yang cukup lebar tepat di bawah kakinya."""
	var space: PhysicsDirectSpaceState2D = agent.get_world_2d().direct_space_state
	var ignored: Array[RID] = [agent.get_rid()]

	# Transform collision shape seandainya agent sudah berada di titik tujuan
	var xform: Transform2D = body_shape.global_transform
	xform.origin += spot - agent.global_position + Vector2(0.0, -LIFT)

	# 1) Badan harus muat, termasuk ruang di atas kepala dan di kiri-kanan
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = body_shape.shape
	shape_query.collision_mask = agent.collision_mask
	shape_query.exclude = ignored
	for offset: Vector2 in [Vector2.ZERO, Vector2(0.0, -headroom),
			Vector2(-elbow_room, 0.0), Vector2(elbow_room, 0.0)]:
		shape_query.transform = xform.translated(offset)
		if not space.intersect_shape(shape_query, 1).is_empty():
			return false

	# 2) Lantai selebar pijakan tepat di bawah kaki (kiri, tengah, kanan),
	# supaya tidak mendarat di bibir platform lalu tergelincir
	var feet_y: float = spot.y + _feet_offset()
	for dx: float in [0.0, -foothold_half_width, foothold_half_width]:
		var from := Vector2(spot.x + dx, feet_y - LIFT * 2.0)
		var ray := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LIFT * 4.0 + 4.0))
		ray.collide_with_areas = false
		ray.collision_mask = agent.collision_mask
		ray.exclude = ignored
		# Ujung pijakan yang sudah menempel di tanah (anak tangga) tetap dihitung lantai
		ray.hit_from_inside = true
		if space.intersect_ray(ray).is_empty():
			return false

	return true


func _exit() -> void:
	if agent.has_method("set_uninterruptible"):
		agent.set_uninterruptible(false)

	if agent is CharacterBody2D:
		agent.velocity.x = 0
	elapsed = 0.0
	phase = Phase.OUT
