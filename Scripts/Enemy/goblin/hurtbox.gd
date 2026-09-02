extends Area2D
class_name GoblinHurtbox

## Hurtbox untuk Goblin yang menerima damage dari serangan Player

@export var health: Node


func _ready() -> void:
	if not health:
		health = get_parent().get_node_or_null("GoblinHealth")


func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if health and health.has_method("take_damage"):
		health.take_damage(amount, source_position)
		if OS.is_debug_build():
			print("Goblin hurtbox took damage: ", amount)
