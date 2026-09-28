class_name NorcThexTrap
extends Area2D

## Perangkap lantai yang dipasang oleh Norc'Thex

@export var damage: int = 1
@export var trap_duration: float = 12.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_triggered: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(trap_duration).timeout.connect(_on_timeout)


func _on_area_entered(area: Area2D) -> void:
	if is_triggered:
		return

	if area is GameHurtbox:
		is_triggered = true
		area.take_damage(damage, global_position)

		if animation_player and animation_player.has_animation("trigger"):
			animation_player.play("trigger")
			await animation_player.animation_finished
		else:
			await get_tree().create_timer(0.4).timeout

		queue_free()


func _on_timeout() -> void:
	if not is_triggered:
		queue_free()
