class_name NorcThexTrap
extends Area2D

## Perangkap duri Norc'Thex.
## Begitu muncul, animasinya langsung jalan sampai selesai (tidak menunggu diinjak).
## Durinya menancap di pertengahan animasi — di situlah damage diberikan,
## sehingga player punya jeda untuk menyingkir sebelum duri naik.

@export var damage: int = 1

## Detik ke berapa (sejak animasi mulai) duri menancap dan melukai
@export var strike_time: float = 0.95

## Nama animasi duri
@export var trigger_animation: StringName = &"trigger"

## Dipakai hanya kalau animasi trigger tidak ada
@export var fallback_duration: float = 1.8

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var elapsed: float = 0.0
var has_struck: bool = false


func _ready() -> void:
	if animation_player and animation_player.has_animation(trigger_animation):
		animation_player.play(trigger_animation)
		animation_player.animation_finished.connect(_on_animation_finished)
	else:
		# Tidak ada animasi: tetap hilang sendiri supaya tidak menumpuk di level
		get_tree().create_timer(fallback_duration).timeout.connect(queue_free)


func _process(delta: float) -> void:
	if has_struck:
		return

	elapsed += delta

	if elapsed >= strike_time:
		has_struck = true
		_strike()


func _strike() -> void:
	"""Duri menancap: lukai semua hurtbox yang sedang berada di atas perangkap."""
	for area in get_overlapping_areas():
		if area is GameHurtbox:
			area.take_damage(damage, global_position)


func _on_animation_finished(_anim_name: StringName) -> void:
	queue_free()
