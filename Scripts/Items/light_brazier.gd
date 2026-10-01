class_name LightBrazier
extends Area2D
## Anglo cahaya. Selama player berdiri di dekatnya, cahaya player terisi ulang.
## Dipakai di area tanpa Goblin/SkullWolf (mis. arena boss), karena cahaya 0 = mati.
## Risikonya: diam di dekat anglo berarti jadi sasaran empuk.

## Cahaya yang dipulihkan per detik
@export var refill_rate: float = 12.0
## Turunkan otomatis ke lantai terdekat di bawahnya saat level dimulai,
## jadi penempatan di editor tidak perlu presisi.
@export var snap_to_floor: bool = true
@export var snap_distance: float = 400.0

@onready var light: PointLight2D = $Light

var _player: Node2D = null
var _base_energy: float
var _t: float = 0.0


func _ready() -> void:
	_base_energy = light.energy
	body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_player = b)
	body_exited.connect(func(b: Node2D) -> void:
		if b == _player:
			_player = null)


func _physics_process(_delta: float) -> void:
	if not snap_to_floor:
		set_physics_process(false)
		return
	snap_to_floor = false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position,
		global_position + Vector2(0, snap_distance), 1 | (1 << 4))
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit["position"]


func _process(delta: float) -> void:
	# nyala api yang bernapas
	_t += delta
	light.energy = _base_energy * (0.9 + 0.1 * sin(_t * 7.0) + randf() * 0.05)

	if _player == null:
		return
	var h = _player.get_node_or_null("Health")
	if h and h.is_alive():
		RunState.add_light(refill_rate * delta)
