extends Area2D
class_name SkullWolfHurtbox

## Hurtbox untuk SkullWolf yang bisa menerima damage dari player

@export var health: Node

func _ready():
	# Cari health component jika tidak diassign
	if not health:
		health = get_parent().get_node_or_null("Health")

func take_damage(amount: int = 1):
	if health and health.has_method("take_damage"):
		health.take_damage(amount)
		print("SkullWolf took damage: ", amount)


