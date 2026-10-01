extends Area2D
class_name GameHurtbox

## Area that can take damage from attacks

@export var health: Node
@export var damage_amount: int = 1

## Efek saat PLAYER yang kena pukul
@export var hit_spark: PackedScene = preload("res://Scenes/FX/hit_spark.tscn")
## Freeze frame saat player kena, sengaja lebih lama biar terasa menyakitkan
@export var hit_stop_duration: float = 0.11


func _ready():
	# If no health component is assigned, try to find one
	if not health:
		health = get_parent().get_node_or_null("Health")


func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO):
	# Check if parent (player) is immune
	var parent = get_parent()
	if "is_immune" in parent and parent.is_immune:
		return

	# arah percikan memantul menjauhi sumber serangan
	var dir := Vector2.UP
	if source_position != Vector2.ZERO:
		dir = (global_position - source_position).normalized()
	GameFx.burst(self, hit_spark, global_position, dir)
	GameFx.hit_stop(self, hit_stop_duration)

	if health and health.has_method("is_alive") and health.is_alive():
		health.take_damage(amount, source_position)
	elif health and health.has_method("take_damage"):
		health.take_damage(amount, source_position)
	else:
		# If no health system, just destroy the object (like barrels)
		get_parent().queue_free()
