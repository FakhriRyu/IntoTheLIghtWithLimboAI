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
@export var approach_distance: float = 20.0

## Jarak maksimal untuk mengejar - jika player lebih jauh, kembali ke idle
@export var max_chase_distance: float = 300.0

## Tidak memainkan animasi di dalam task ini. Animasi diatur di Sequence.
## Area untuk memicu serangan; jika target di dalam area ini, hentikan chase (FAILURE)
@export var attack_area_path: NodePath = ^"hitbox"
## Area untuk deteksi; jika target keluar dari area ini, hentikan chase (FAILURE)
@export var detection_area_path: NodePath = ^"DetectionArea"
var attack_area: Area2D
var detection_area: Area2D


func _generate_name() -> String:
	return "Pursue %s" % [LimboUtility.decorate_var(target_var)]



func _setup() -> void:
	if attack_area_path:
		attack_area = agent.get_node_or_null(attack_area_path)
	if detection_area_path:
		detection_area = agent.get_node_or_null(detection_area_path)


func _enter() -> void:
	pass

func _tick(_delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)
	
	if not is_instance_valid(target):
		return FAILURE
	
	# Cek apakah target masih dalam detection area
	if detection_area != null:
		var still_in_area := false
		if detection_area.has_method("overlaps_body"):
			still_in_area = detection_area.overlaps_body(target)
		elif detection_area.has_method("get_overlapping_bodies"):
			for b in detection_area.get_overlapping_bodies():
				if b == target:
					still_in_area = true
					break
		
		if not still_in_area:
			return FAILURE
	
	var distance = agent.global_position.distance_to(target.global_position)
	
	# Cek apakah player terlalu jauh - kembali ke idle
	if distance > max_chase_distance:
		return FAILURE
	
	# Cek apakah sudah sangat dekat dengan target (hanya jika approach_distance > 0)
	if approach_distance > 0.0 and distance <= approach_distance:
		return SUCCESS
	
	# Bergerak menuju target secara agresif (langsung ke target)
	var direction = agent.global_position.direction_to(target.global_position)
	var velocity = direction * speed
	
	# Update posisi agent
	if agent is CharacterBody2D:
		agent.velocity.x = velocity.x
		agent.move_and_slide()
		
		# Flip sprite berdasarkan arah gerak
		if agent.has_method("update_facing"):
			agent.update_facing(velocity.x)
		else:
			# Fallback untuk agent yang tidak punya method update_facing
			var sprite = agent.get_node_or_null("Sprite2D")
			if sprite and sprite is Sprite2D:
				sprite.flip_h = velocity.x < 0
	
	return RUNNING


func _exit() -> void:
	# Stop movement
	if agent is CharacterBody2D:
		agent.velocity.x = 0
