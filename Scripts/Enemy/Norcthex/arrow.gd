class_name NorcThexArrow
extends Area2D

## Projectile panah yang ditembakkan oleh Norc'Thex

@export var speed: float = 350.0
@export var damage: int = 1
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area is GameHurtbox:
		area.take_damage(damage, global_position)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is TileMap or body is TileMapLayer or body is StaticBody2D:
		queue_free()
