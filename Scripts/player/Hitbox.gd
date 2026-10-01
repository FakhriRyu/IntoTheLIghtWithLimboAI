extends Area2D

@export var damage: int = 1
@export var knockback_force: float = 200.0

## Efek saat pukulan mendarat
@export var hit_spark: PackedScene = preload("res://Scenes/FX/hit_spark.tscn")
## Lama freeze frame saat pukulan kita mendarat (detik)
@export var hit_stop_duration: float = 0.06

signal hit_target(target)

var active: bool = false


func _ready():
	# Connect the area entered signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Start disabled
	set_active(false)


func set_active(is_active: bool):
	active = is_active
	set_deferred("monitoring", is_active)
	set_deferred("monitorable", is_active)

	# Hide/show collision shapes with deferred
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not is_active)


func _on_body_entered(body):
	if not active:
		return

	# Check if it's a destructible (like barrels)
	if body.has_method("take_damage"):
		body.take_damage()
		hit_target.emit(body)
		_impact(body.global_position if body is Node2D else global_position)
		if OS.is_debug_build():
			print("Hit target: ", body.name)


func _on_area_entered(area):
	if not active:
		return

	# Check if it's an enemy hurtbox
	if area.has_method("take_damage"):
		area.take_damage(damage)
		hit_target.emit(area)
		_impact(_contact_point(area))
		if OS.is_debug_build():
			print("Player hit enemy for ", damage, " damage")
	elif area.get_parent().has_method("take_damage"):
		var target = area.get_parent()
		target.take_damage(damage)
		hit_target.emit(target)
		_impact(_contact_point(area))
		if OS.is_debug_build():
			print("Player hit target: ", target.name)


func _contact_point(area: Area2D) -> Vector2:
	"""Titik benturan kira-kira: di tengah antara hitbox dan target."""
	return global_position.lerp(area.global_position, 0.6)


func _impact(at: Vector2) -> void:
	"""Percikan + freeze frame singkat supaya pukulan terasa 'nyangkut'."""
	var dir := Vector2(signf(global_scale.x), -0.35)
	GameFx.burst(self, hit_spark, at, dir)
	GameFx.hit_stop(self, hit_stop_duration)
