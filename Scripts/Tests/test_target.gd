extends CharacterBody2D
## Pengganti player untuk uji perilaku NPC. Posisinya diatur langsung oleh
## skenario (teleport), atau berjalan dengan kecepatan move_speed ke arah move_dir.
## Tidak punya HurtBox, jadi serangan musuh tidak melukai apa pun.

var move_dir: float = 0.0
var move_speed: float = 80.0


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


func place(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	move_dir = 0.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_dir * move_speed
	move_and_slide()
