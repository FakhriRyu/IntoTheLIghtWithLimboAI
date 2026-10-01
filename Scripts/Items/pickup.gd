class_name Pickup
extends Node2D
## Item yang bisa diambil: kepingan cahaya, orb XP, atau orb heal.
## Muncul dengan lompatan kecil, melayang di tempat, lalu tertarik ke player
## begitu masuk radius magnet. Tanpa fisika, karena selalu muncul di atas lantai.

enum Kind { LIGHT, XP, HEAL }

@export var kind: Kind = Kind.LIGHT
## Besar nilainya: cahaya, XP, atau HP
@export var amount: float = 20.0
## Radius tarik dasar (dikali magnet_mult dari upgrade)
@export var magnet_radius: float = 56.0
@export var collect_radius: float = 10.0
@export var max_speed: float = 360.0
@export var accel: float = 900.0

## Percikan saat diambil
@export var collect_fx: PackedScene = preload("res://Scenes/FX/hit_spark.tscn")

const COLORS := {
	Kind.LIGHT: Color(1.0, 0.85, 0.45),
	Kind.XP: Color(0.4, 0.95, 1.0),
	Kind.HEAL: Color(1.0, 0.35, 0.4),
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: PointLight2D = $Glow

var _player: Node2D = null
var _velocity: Vector2 = Vector2.ZERO
var _homing: bool = false
## Jeda sebelum boleh tertarik, supaya lompatan munculnya sempat terlihat
var _settle: float = 0.35
var _bob_time: float = 0.0
var _rest_y: float = 0.0


func _ready() -> void:
	var c: Color = COLORS[kind]
	sprite.modulate = c
	glow.color = c
	match kind:
		Kind.LIGHT:
			# kepingan cahaya harus terlihat jelas di kegelapan
			sprite.scale = Vector2.ONE * (2.5 + clampf(amount / 20.0, 0.0, 2.0))
			glow.texture_scale = 0.35 + clampf(amount / 100.0, 0.0, 0.4)
			glow.energy = 1.1
		Kind.XP:
			sprite.scale = Vector2.ONE * 2.0
			glow.texture_scale = 0.15
			glow.energy = 0.6
		Kind.HEAL:
			sprite.scale = Vector2.ONE * 3.0
			glow.texture_scale = 0.25
			glow.energy = 0.8
	_bob_time = randf() * TAU
	_pop()


## Lompatan kecil ke arah acak saat muncul
func _pop() -> void:
	var target := position + Vector2(randf_range(-22.0, 22.0), randf_range(-14.0, -6.0))
	_rest_y = target.y
	var t := create_tween()
	t.tween_property(self, "position:x", target.x, 0.35).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "position:y", target.y - 14.0, 0.17) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(self, "position:y", target.y, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	_settle -= delta
	# titik tengah badan player, bukan kakinya
	var target := _player.global_position + Vector2(0, -4)
	var dist := global_position.distance_to(target)

	if _settle <= 0.0 and not _homing and _player_alive():
		var radius := magnet_radius * float(RunState.stats.get("magnet_mult", 1.0))
		if dist <= radius:
			_homing = true

	if _homing:
		var dir := (target - global_position).normalized()
		_velocity = _velocity.move_toward(dir * max_speed, accel * delta)
		global_position += _velocity * delta
		if global_position.distance_to(target) <= collect_radius:
			_collect()
	elif _settle <= 0.0:
		_bob_time += delta * 3.0
		position.y = _rest_y + sin(_bob_time) * 2.0


func _player_alive() -> bool:
	var h = _player.get_node_or_null("Health")
	return h == null or h.is_alive()


func _collect() -> void:
	match kind:
		Kind.LIGHT:
			RunState.add_light(amount)
			Audio.play_sfx(&"pickup_light", -4.0)
		Kind.XP:
			RunState.add_xp(int(amount))
			# makin dekat ke naik level, makin tinggi nadanya
			var progress := float(RunState.xp) / float(RunState.xp_to_next())
			Audio.play_sfx(&"pickup_xp", -10.0, 0.03, 1.0 + progress * 0.5)
		Kind.HEAL:
			RunState.heal_player(int(amount))
			Audio.play_sfx(&"pickup_heal", -4.0)
	GameFx.burst(self, collect_fx, global_position)
	queue_free()


## Memunculkan pickup di posisi global. Induknya scene aktif (bukan musuh yang
## memanggil), supaya tidak ikut terhapus saat musuh di-queue_free.
static func spawn(from: Node, scene: PackedScene, at: Vector2, kind_: Kind, amount_: float) -> Pickup:
	if scene == null or from == null or not from.is_inside_tree():
		return null
	var host := from.get_tree().current_scene
	if host == null:
		return null
	var p := scene.instantiate() as Pickup
	p.kind = kind_
	p.amount = amount_
	# posisi diisi SEBELUM add_child, karena _ready() memakai posisi untuk lompatan muncul
	p.position = (host as Node2D).to_local(at) if host is Node2D else at
	host.add_child(p)
	return p


## Membagi XP menjadi beberapa orb kecil supaya terasa lebih "juicy".
static func spawn_xp(from: Node, scene: PackedScene, at: Vector2, total: int) -> void:
	var left := total
	while left > 0:
		var n := mini(left, 2 if left > 3 else 1)
		spawn(from, scene, at, Kind.XP, n)
		left -= n
