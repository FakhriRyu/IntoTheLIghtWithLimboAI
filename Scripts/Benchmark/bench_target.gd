extends CharacterBody2D
## Pengganti player untuk pengujian kinerja AI.
## Berjalan bolak-balik di arena supaya musuh terus mendeteksi, mengejar,
## dan menyerang. Tidak punya HurtBox (layer 4), jadi serangan musuh tidak
## pernah mengenai apa pun dan jumlah musuh tetap sama selama pengukuran.

## Lebih lambat dari musuh tercepat supaya target bisa tersusul dan diserang
@export var speed: float = 60.0
@export var min_x: float = 500.0
@export var max_x: float = 1100.0
## Lompat sesekali supaya musuh juga diuji saat target di udara
@export var jump_interval: float = 3.0
@export var jump_velocity: float = -320.0

var _dir: float = 1.0
var _jump_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2       # layer "player": dipakai area deteksi musuh
	collision_mask = 1        # hanya lantai/dinding
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.0
	capsule.height = 28.0
	shape.shape = capsule
	shape.position = Vector2(0.0, -14.0)
	add_child(shape)
	_jump_timer = jump_interval


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if global_position.x >= max_x:
		_dir = -1.0
	elif global_position.x <= min_x:
		_dir = 1.0
	velocity.x = _dir * speed

	_jump_timer -= delta
	if _jump_timer <= 0.0 and is_on_floor():
		_jump_timer = jump_interval
		velocity.y = jump_velocity

	move_and_slide()


func _draw() -> void:
	draw_rect(Rect2(-7.0, -28.0, 14.0, 28.0), Color(0.4, 0.8, 1.0))
