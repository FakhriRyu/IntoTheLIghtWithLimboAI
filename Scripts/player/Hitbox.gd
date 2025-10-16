extends Area2D

@export var damage: int = 1
@export var knockback_force: float = 200.0

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
	monitoring = is_active
	monitorable = is_active
	
	# Hide/show collision shapes
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not is_active

func _on_body_entered(body):
	if not active:
		return
		
	# Check if it's a barrel
	if body.has_method("take_damage"):
		body.take_damage()
		hit_target.emit(body)
		print("Hit target: ", body.name)

func _on_area_entered(area):
	if not active:
		return
		
	# Check if it's an enemy hurtbox
	if area.has_method("take_damage"):
		area.take_damage(damage)
		hit_target.emit(area)
		print("Player hit enemy for ", damage, " damage")
	elif area.get_parent().has_method("take_damage"):
		var target = area.get_parent()
		target.take_damage(damage)
		hit_target.emit(target)
		print("Player hit target: ", target.name)
