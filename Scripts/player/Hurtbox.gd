extends Area2D
class_name GameHurtbox

## Area that can take damage from attacks

@export var health: Node
@export var damage_amount: int = 1

func _ready():
	# If no health component is assigned, try to find one
	if not health:
		health = get_parent().get_node_or_null("Health")

func take_damage(amount: int = 1):
	# Cek apakah player immune (untuk player hurtbox)
	var parent = get_parent()
	if "is_immune" in parent and parent.is_immune:
		return
	
	if health and health.has_method("is_alive") and health.is_alive():
		health.take_damage(amount)
	elif health and health.has_method("take_damage"):
		health.take_damage(amount)
	else:
		# If no health system, just destroy the object (like barrels)
		get_parent().queue_free()
