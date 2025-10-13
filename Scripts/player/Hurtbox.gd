extends Area2D
class_name GameHurtbox

## Area that can take damage from player attacks

@export var health: Node
@export var damage_amount: int = 1

func _ready():
	# If no health component is assigned, try to find one
	if not health:
		health = get_parent().get_node_or_null("Health")
	
	# Connect to area and body entered signals to handle attacks
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func take_damage(amount: int = 1):
	if health and health.is_alive():
		health.take_damage(amount)
	else:
		# If no health system, just destroy the object (like barrels)
		get_parent().queue_free()

func _on_area_entered(area):
	# Check if it's a player hitbox
	if area.has_method("get_parent") and area.get_parent().name == "Player":
		take_damage(damage_amount)

func _on_body_entered(body):
	# Check if it's a player or player attack
	if body.name == "Player":
		# Don't damage the player for now
		pass
