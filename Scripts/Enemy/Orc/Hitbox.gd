extends Area2D

## Hitbox untuk enemy yang bisa memberikan damage ke player

@export var damage: int = 1

var active: bool = false
var already_hit: Array = []  # Track yang sudah kena hit

func _ready():
	# Connect signal
	area_entered.connect(_on_area_entered)
	
	# Start disabled
	set_active(false)

func set_active(is_active: bool):
	active = is_active
	
	# Reset hit tracking saat diaktifkan
	if is_active:
		already_hit.clear()
	
	# Gunakan set_deferred untuk menghindari error saat physics processing
	set_deferred("monitoring", is_active)
	
	# Hide/show collision shapes dengan deferred
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not is_active)

func _on_area_entered(area):
	if not active:
		return
	
	# Cek apakah sudah pernah hit area ini
	if area in already_hit:
		return
	
	# Cek apakah ini player hurtbox
	if area is GameHurtbox:
		area.take_damage(damage)
		already_hit.append(area)
		print("Orc hit player for ", damage, " damage")