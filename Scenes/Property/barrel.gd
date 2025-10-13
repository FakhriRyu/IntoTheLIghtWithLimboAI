extends StaticBody2D

## Simple destructible barrel that can be attacked by the player

func take_damage(_amount: int = 1):
	print("Barrel destroyed!")
	# Add some visual effects here if desired
	queue_free()

func _ready():
	# Make sure this barrel can be detected by player attacks
	add_to_group("destructible")
