class_name NorchThex
extends CharacterBody2D

@export var arrow_scene: PackedScene = preload("res://Scenes/Enemy/NorcThex/arrow.tscn")
@export var trap_scene: PackedScene = preload("res://Scenes/Enemy/NorcThex/trap.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var marker_2d: Marker2D = $Marker2D
@onready var detection_area_boss: Area2D = $DetectionAreaBoss


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()


func shoot_arrow() -> void:
	"""Menembakkan proyektil panah ke arah hadap Norc'Thex."""
	if not arrow_scene:
		return

	var arrow = arrow_scene.instantiate()
	arrow.global_position = marker_2d.global_position

	# Arah tembakan mengikuti flip_h sprite
	var dir_x = -1.0 if sprite.flip_h else 1.0
	arrow.direction = Vector2(dir_x, 0).normalized()

	get_parent().add_child(arrow)


func spawn_trap() -> void:
	"""Memasang perangkap di tanah dekat kaki Norc'Thex."""
	if not trap_scene:
		return

	var trap = trap_scene.instantiate()
	# Posisi spawn sedikit di depan kaki bos
	var spawn_offset = Vector2(-40 if sprite.flip_h else 40, 16)
	trap.global_position = global_position + spawn_offset

	get_parent().add_child(trap)


func update_facing(direction: float) -> void:
	"""Membalik sprite dan posisi titik panah (Marker2D) sesuai arah hadap/kecepatan."""
	if direction == 0:
		return

	sprite.flip_h = direction < 0
	marker_2d.position.x = abs(marker_2d.position.x) * (-1 if direction < 0 else 1)
