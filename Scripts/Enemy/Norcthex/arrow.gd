class_name NorcThexArrow
extends Area2D

## Projectile panah yang ditembakkan oleh Norc'Thex

@export var speed: float = 350.0
@export var damage: int = 1
@export var lifetime: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_apply_orientation()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _apply_orientation() -> void:
	"""Menghadapkan panah ke arah terbangnya.
	Art panah digambar menghadap KIRI (mata panah ada di sisi kiri texture).
	Untuk arah ke kanan sprite-nya dibalik pakai flip_h, bukan diputar 180 derajat,
	supaya bulu panah tidak ikut terbalik ke bawah."""
	var facing_right := direction.x > 0.0
	sprite.flip_h = facing_right

	# Rotasi hanya untuk kemiringan (kalau nanti ada tembakan menyerong)
	if facing_right:
		rotation = direction.angle()
	else:
		rotation = direction.angle() - PI


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area is GameHurtbox:
		area.take_damage(damage, global_position)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is TileMap or body is TileMapLayer or body is StaticBody2D:
		queue_free()
