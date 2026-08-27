extends Area2D

## Hitbox untuk SkullWolf - contact damage (selalu aktif)

@export var damage: int = 2
@export var damage_interval: float = 1.0  # Interval antara damage

var damage_timer: float = 0.0


func _ready():
	# Selalu aktif untuk contact damage
	monitoring = true
	monitorable = true


func _physics_process(delta: float) -> void:
	if not monitoring:
		return

	# Countdown timer
	if damage_timer > 0:
		damage_timer -= delta
		return

	# Cek overlap dengan player hurtbox
	for area in get_overlapping_areas():
		if area is GameHurtbox:
			area.take_damage(damage, global_position)
			if OS.is_debug_build():
				print("SkullWolf hit player for ", damage, " damage")
			damage_timer = damage_interval
			break  # Hanya hit sekali per interval
