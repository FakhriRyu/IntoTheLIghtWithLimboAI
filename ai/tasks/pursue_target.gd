@tool
extends BTAction
## Mengejar target hingga sangat dekat (aggressive chase)
## Returns RUNNING saat sedang bergerak menuju target
## Returns SUCCESS saat sudah sangat dekat dengan target
## Returns FAILURE jika target tidak valid atau terlalu jauh (melewati max_chase_distance)

## Seberapa dekat agent harus ke posisi yang diinginkan untuk return SUCCESS
const TOLERANCE := 15.0

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## Kecepatan gerak (lebih cepat untuk mengejar)
@export var speed: float = 30

## Jarak yang diinginkan dari target (sangat dekat untuk aggressive chase)
@export var approach_distance: float = 0.0

## Jarak maksimal untuk mengejar - jika player lebih jauh, kembali ke idle
@export var max_chase_distance: float = 100.0

## Tidak memainkan animasi di dalam task ini. Animasi diatur di Sequence.
## Area untuk memicu serangan; jika target di dalam area ini, hentikan chase (FAILURE)
@export var attack_area_path: NodePath = ^"hitbox"
var attack_area: Area2D


func _generate_name() -> String:
	return "Pursue %s" % [LimboUtility.decorate_var(target_var)]



func _setup() -> void:
	if attack_area_path:
		attack_area = agent.get_node_or_null(attack_area_path)


func _enter() -> void:
	pass

func _tick(_delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)
	
	if not is_instance_valid(target):
		return FAILURE

	# Jika target sudah berada di dalam hitbox serangan, hentikan chase agar tree bisa berpindah ke Attack
	if attack_area != null:
		if attack_area.has_method("overlaps_body"):
			if attack_area.overlaps_body(target):
				return FAILURE
		else:
			if attack_area.has_method("get_overlapping_bodies"):
				for b in attack_area.get_overlapping_bodies():
					if b == target:
						return FAILURE
	
	var distance = agent.global_position.distance_to(target.global_position)
	
	# Cek apakah player terlalu jauh - kembali ke idle
	if distance > max_chase_distance:
		return FAILURE
	
	# Cek apakah sudah sangat dekat dengan target
	if distance <= approach_distance:
		return SUCCESS
	
	# Bergerak menuju target secara agresif (langsung ke target)
	var direction = agent.global_position.direction_to(target.global_position)
	var velocity = direction * speed
	
	# Update posisi agent
	if agent is CharacterBody2D:
		agent.velocity.x = velocity.x
		agent.move_and_slide()
		
		# Flip sprite berdasarkan arah gerak
		var sprite = agent.get_node_or_null("Sprite2D")
		if sprite and sprite is Sprite2D:
			sprite.flip_h = velocity.x < 0
	
	return RUNNING


func _exit() -> void:
	# Stop movement
	if agent is CharacterBody2D:
		agent.velocity.x = 0
