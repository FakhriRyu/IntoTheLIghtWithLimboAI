extends Area2D
class_name GoblinHitbox

## Hitbox untuk Goblin yang memberikan damage ke Player

@export var damage: int = 1

var active: bool = false
var already_hit: Array = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_active(false)


func set_active(is_active: bool) -> void:
	active = is_active

	if is_active:
		already_hit.clear()

	set_deferred("monitoring", is_active)

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not is_active)


func _on_area_entered(area: Area2D) -> void:
	if not active:
		return

	if area in already_hit:
		return

	if area is GameHurtbox:
		area.take_damage(damage, global_position)
		already_hit.append(area)
		if OS.is_debug_build():
			print("Goblin hit player for ", damage, " damage")
