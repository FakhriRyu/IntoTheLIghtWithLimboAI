class_name Chest
extends Area2D
## Peti harta. Dibuka dengan memukulnya (lewat jalur take_damage di Hitbox player)
## atau menekan Up saat berdiri di depannya. Tidak menghalangi jalan.
##
## Isi peti:
##   Selalu   : kepingan cahaya besar + beberapa orb XP
##   Lalu satu roll:
##     Ramuan          -> orb heal
##     Relik           -> pilih 1 dari 3 upgrade gratis (minimal Langka)
##     Minyak Lentera  -> +max cahaya permanen untuk run ini, cahaya penuh
##     Peti Terkutuk   -> menggigit dan memanggil musuh, tapi isinya bernilai ganda

enum Loot { RANDOM, POTION, RELIC, OIL, MIMIC }

## Paksa satu jenis isi, untuk menguji (RANDOM = normal)
@export var force_loot: Loot = Loot.RANDOM

@export var pickup_scene: PackedScene = preload("res://Scenes/Items/pickup.tscn")
@export var open_fx: PackedScene = preload("res://Scenes/FX/death_burst.tscn")
## Musuh yang dipanggil peti terkutuk
@export var mimic_enemies: Array[PackedScene] = [
	preload("res://Scenes/Enemy/goblin/goblin.tscn"),
	preload("res://Scenes/Enemy/SkullWolf/skull_wolf.tscn"),
]

@export var base_light: float = 40.0
@export var base_xp: int = 6
@export var potion_heal: int = 3
@export var oil_max_light: float = 10.0

## Peluang tiap isi (dinormalisasi)
@export var potion_weight: float = 45.0
@export var relic_weight: float = 30.0
@export var oil_weight: float = 15.0
@export var mimic_weight: float = 10.0

## Region sprite di ExtraTiles1.png: tertutup dan sudah terbuka
const CLOSED_REGION := Rect2(160, 32, 32, 32)
const OPEN_REGION := Rect2(192, 32, 32, 32)
const ONE_WAY_LAYER := 5

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: PointLight2D = $Glow

var opened: bool = false
var _player_near: Node2D = null


func _ready() -> void:
	add_to_group("chest")
	sprite.region_rect = CLOSED_REGION
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not opened and _player_near and Input.is_action_just_pressed("Up"):
		open()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player_near:
		_player_near = null


## Dipanggil Hitbox player saat peti dipukul
func take_damage(_amount: int = 1, _source_position: Vector2 = Vector2.ZERO) -> void:
	open()


func open() -> void:
	if opened:
		return
	opened = true
	sprite.region_rect = OPEN_REGION
	glow.energy = 0.0

	# kocok sebentar
	var base_x := sprite.position.x
	var t := create_tween()
	for i in range(4):
		t.tween_property(sprite, "position:x", base_x + (2.0 if i % 2 == 0 else -2.0), 0.03)
	t.tween_property(sprite, "position:x", base_x, 0.03)

	GameFx.burst(self, open_fx, global_position + Vector2(0, -10))
	Audio.play_sfx(&"chest_open")
	Audio.play_sfx(&"chest_loot", -4.0)
	_spill_loot.call_deferred(_roll())


func _roll() -> Loot:
	if force_loot != Loot.RANDOM:
		return force_loot
	var total := potion_weight + relic_weight + oil_weight + mimic_weight
	var r := randf() * total
	if r < potion_weight:
		return Loot.POTION
	r -= potion_weight
	if r < relic_weight:
		return Loot.RELIC
	r -= relic_weight
	if r < oil_weight:
		return Loot.OIL
	return Loot.MIMIC


func _spill_loot(loot: Loot) -> void:
	var at := global_position + Vector2(0, -12)
	var mult := 2 if loot == Loot.MIMIC else 1

	Pickup.spawn(self, pickup_scene, at, Pickup.Kind.LIGHT, base_light * mult)
	Pickup.spawn_xp(self, pickup_scene, at, base_xp * mult)

	match loot:
		Loot.POTION:
			Pickup.spawn(self, pickup_scene, at, Pickup.Kind.HEAL, potion_heal)
		Loot.RELIC:
			RunState.queue_pick("relic")
		Loot.OIL:
			RunState.add_stat("max_light_bonus", oil_max_light)
			RunState.add_light(RunState.max_light())
			GameFx.flash(sprite, Color(2.5, 2.2, 1.2), 0.3)
		Loot.MIMIC:
			_mimic()


## Peti terkutuk: menggigit player yang dekat lalu memanggil dua musuh.
func _mimic() -> void:
	GameFx.flash(sprite, Color(2.5, 0.6, 0.6), 0.35)
	Audio.play_sfx(&"mimic", 0.0, 0.05, 0.7)
	if _player_near:
		var hurtbox = _player_near.get_node_or_null("HurtBox")
		if hurtbox and hurtbox.has_method("take_damage"):
			hurtbox.take_damage(1, global_position)

	var host := get_tree().current_scene
	if host == null or mimic_enemies.is_empty():
		return
	for side in [-1, 1]:
		var scene: PackedScene = mimic_enemies[randi() % mimic_enemies.size()]
		var enemy := scene.instantiate() as Node2D
		# dijatuhkan sedikit di atas lantai di kiri/kanan peti
		enemy.position = (host as Node2D).to_local(global_position + Vector2(side * 28, -24)) \
			if host is Node2D else global_position
		if enemy is CollisionObject2D:
			enemy.set_collision_mask_value(ONE_WAY_LAYER, true)
		host.add_child(enemy)
