extends Area2D
class_name SkullWolfHurtbox

## Hurtbox untuk SkullWolf yang bisa menerima damage dari player

@export var health: Node
## Ledakan partikel saat musuh ini mati
@export var death_burst: PackedScene = preload("res://Scenes/FX/death_burst.tscn")

var _death_fx_done: bool = false


func _ready():
	# Cari health component jika tidak diassign
	if not health:
		health = get_parent().get_node_or_null("Health")

func take_damage(amount: int = 1):
	if health and health.has_method("take_damage"):
		health.take_damage(amount)
		print("SkullWolf took damage: ", amount)
		_check_death_fx()


func _check_death_fx() -> void:
	"""Memunculkan ledakan partikel tepat saat HP menyentuh nol."""
	if _death_fx_done:
		return
	if health == null or not ("current_health" in health):
		return
	if int(health.current_health) > 0:
		return
	_death_fx_done = true
	GameFx.burst(self, death_burst, global_position)
