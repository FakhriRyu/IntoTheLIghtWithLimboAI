class_name LootDropper
extends Node
## Komponen drop untuk musuh. Pasang sebagai anak musuh; saat sinyal `death`
## dari komponen health-nya berbunyi, XP, kepingan cahaya, dan (kadang) orb heal
## dimunculkan di posisi musuh.

## Komponen health musuh. Kosong = cari sibling "Health" / "GoblinHealth".
@export var health: Node
@export var pickup_scene: PackedScene = preload("res://Scenes/Items/pickup.tscn")

@export var xp: int = 3
@export_range(0.0, 1.0) var light_chance: float = 0.75
@export var light_amount: float = 20.0
@export_range(0.0, 1.0) var heal_chance: float = 0.1
@export var heal_amount: int = 1
## Titik munculnya drop relatif terhadap titik asal musuh
@export var drop_offset: Vector2 = Vector2(0, -8)

var _dropped: bool = false


func _ready() -> void:
	if health == null:
		for n in ["Health", "GoblinHealth"]:
			health = get_parent().get_node_or_null(n)
			if health:
				break
	if health and health.has_signal("death"):
		health.death.connect(_on_death)
	else:
		push_warning("LootDropper: health dengan sinyal 'death' tidak ditemukan di %s" % get_parent().name)


func _on_death() -> void:
	if _dropped:
		return
	_dropped = true
	var parent := get_parent() as Node2D
	if parent == null:
		return
	# Ditunda: sinyal death sering berbunyi di tengah callback fisika
	_drop.call_deferred(parent.global_position + drop_offset)
	RunState.on_enemy_killed()
	Audio.enemy_voice(parent, &"death")


## Memakai RunState (autoload, selalu ada di tree) sebagai jangkar, karena
## musuhnya bisa saja sudah keluar dari tree saat panggilan tertunda ini jalan.
func _drop(at: Vector2) -> void:
	Pickup.spawn_xp(RunState, pickup_scene, at, xp)
	if randf() < light_chance:
		Pickup.spawn(RunState, pickup_scene, at, Pickup.Kind.LIGHT, light_amount)
	if randf() < heal_chance:
		Pickup.spawn(RunState, pickup_scene, at, Pickup.Kind.HEAL, heal_amount)
