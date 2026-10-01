extends Area2D
## Hitbox serangan player. Kekuatan pukulan menyesuaikan indeks combo:
## pukulan ke-3 lebih sakit, lebih mendorong, dan freeze frame-nya lebih lama.

@export var damage: int = 1
@export var knockback_force: float = 200.0

## Per indeks combo (0,1,2). Pukulan ke-3 adalah pamungkas.
@export var combo_damage: Array[int] = [1, 1, 2]
@export var combo_knockback: Array[float] = [100.0, 120.0, 260.0]
@export var combo_hit_stop: Array[float] = [0.05, 0.05, 0.12]

## Efek saat pukulan mendarat
@export var hit_spark: PackedScene = preload("res://Scenes/FX/hit_spark.tscn")
## Dipakai kalau indeks combo tidak diketahui
@export var hit_stop_duration: float = 0.06

signal hit_target(target)

var active: bool = false

## Supaya satu musuh hanya kena sekali per ayunan, penting untuk dash attack
## yang hitbox-nya menembus beberapa musuh sekaligus.
var _already_hit: Array = []


func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_active(false)


func set_active(is_active: bool):
	active = is_active
	if is_active:
		_already_hit.clear()

	set_deferred("monitoring", is_active)
	set_deferred("monitorable", is_active)

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not is_active)


func _combo_index() -> int:
	var owner_node := get_parent()
	if owner_node and "combo_index" in owner_node:
		return clampi(int(owner_node.combo_index), 0, 2)
	return 0


func _pick(arr: Array, idx: int, fallback):
	return arr[idx] if idx < arr.size() else fallback


func _on_body_entered(body):
	if not active or body in _already_hit:
		return
	_already_hit.append(body)

	# Benda yang bisa dihancurkan, mis. barrel
	if body.has_method("take_damage"):
		body.take_damage()
		hit_target.emit(body)
		_impact(body.global_position if body is Node2D else global_position)


func _on_area_entered(area):
	if not active or area in _already_hit:
		return

	var idx := _combo_index()
	var dmg: int = _pick(combo_damage, idx, damage)
	var force: float = _pick(combo_knockback, idx, knockback_force)

	# bonus dari upgrade roguelike
	var st := RunState.stats
	dmg += int(st["damage_bonus"])
	var is_finisher := idx == 2 and not _is_dash_attacking()
	if is_finisher:
		dmg += int(st["finisher_bonus"])

	var target = null
	if area.has_method("take_damage"):
		target = area
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		target = area.get_parent()
	if target == null:
		return

	_already_hit.append(area)
	_deal(target, dmg)
	_push(target, force)
	if _is_enemy(area):
		var gain := float(st["light_on_hit"])
		if is_finisher:
			gain += float(st["finisher_light"])
		RunState.add_light(gain)
	hit_target.emit(target)
	_impact(_contact_point(area))
	if _is_enemy(area):
		Audio.enemy_voice(area.get_parent(), &"hurt", -2.0)


func _deal(target, dmg: int) -> void:
	"""Hurtbox musuh di proyek ini punya signature berbeda-beda: ada yang
	take_damage(amount), ada yang take_damage(amount, source_position).
	Jumlah argumennya dicek dulu supaya tidak error."""
	var arg_count := -1
	for m in target.get_method_list():
		if m.name == "take_damage":
			arg_count = m.args.size()
			break

	if arg_count >= 2:
		target.take_damage(dmg, global_position)
	else:
		target.take_damage(dmg)


func _push(target, force: float) -> void:
	"""Dorong musuh sesuai arah hadap player, bukan tebakan musuh sendiri."""
	var body = target if target is CharacterBody2D else target.get_parent()
	if body == null or not (body is CharacterBody2D):
		return

	var dir := signf(global_position.x - _player_x())
	if dir == 0.0:
		dir = 1.0

	if body.has_method("apply_hit_knockback"):
		body.apply_hit_knockback(Vector2(dir, 0), force)
	elif "velocity" in body:
		body.velocity.x = dir * force


func _is_enemy(area: Area2D) -> bool:
	var p := area.get_parent()
	return p != null and p.is_in_group("enemy")


func _is_dash_attacking() -> bool:
	var p := get_parent()
	return p != null and "is_dash_attacking" in p and p.is_dash_attacking


func _player_x() -> float:
	var p := get_parent()
	return p.global_position.x if p is Node2D else global_position.x


func _contact_point(area: Area2D) -> Vector2:
	"""Titik benturan kira-kira: di tengah antara hitbox dan target."""
	return global_position.lerp(area.global_position, 0.6)


func _impact(at: Vector2) -> void:
	"""Percikan + freeze frame. Pamungkas membeku lebih lama."""
	var idx := _combo_index()
	var dir := Vector2(signf(global_position.x - _player_x()), -0.35)
	if dir.x == 0.0:
		dir.x = 1.0

	GameFx.burst(self, hit_spark, at, dir)
	GameFx.hit_stop(self, _pick(combo_hit_stop, idx, hit_stop_duration))
	# pamungkas terdengar lebih berat (nada lebih rendah)
	if idx == 2 and not _is_dash_attacking():
		Audio.play_sfx(&"sword_hit_heavy", 0.0, 0.05)
	else:
		Audio.play_sfx(&"sword_hit", -1.0, 0.08, 1.0 + 0.04 * idx)
