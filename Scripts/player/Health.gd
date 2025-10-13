extends Node
class_name GameHealth

## Simple health system for the main game
signal death
signal damaged(amount: int)

@export var max_health: int = 10
var current_health: int

func _ready():
	current_health = max_health

func take_damage(amount: int = 1):
	if current_health <= 0:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	damaged.emit(amount)
	print("Took damage: ", amount, " - Health remaining: ", current_health)
	
	if current_health <= 0:
		death.emit()
		print("Died!")

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	print("Healed: ", amount, " - Health: ", current_health)

func get_current_health() -> int:
	return current_health

func is_alive() -> bool:
	return current_health > 0
