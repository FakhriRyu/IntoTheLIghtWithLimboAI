@tool
extends BTCondition
## Cek apakah target (player) berada di dalam Area2D (DetectionArea)
## Returns SUCCESS jika target berada dalam area
## Returns FAILURE jika target tidak valid atau berada di luar area

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## NodePath ke Area2D detection milik agent (mis. "DetectionArea")
@export var detection_area_path: NodePath = ^"DetectionArea"

var detection_area: Area2D


func _generate_name() -> String:
	return "CheckTargetInArea %s" % [LimboUtility.decorate_var(target_var)]


func _setup() -> void:
	if detection_area_path:
		detection_area = agent.get_node_or_null(detection_area_path)


func _tick(_delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)
	if not is_instance_valid(target):
		return FAILURE
	if detection_area == null:
		return FAILURE
	
	# Jika Area2D punya direct helper methods (Godot 4): overlaps_body/overlaps_area
	if detection_area.has_method("overlaps_body"):
		if detection_area.overlaps_body(target):
			return SUCCESS
		return FAILURE
	
	# Fallback: manual cek dari bodies/areas yang overlap jika method tidak tersedia
	var inside := false
	if detection_area.has_method("get_overlapping_bodies"):
		for b in detection_area.get_overlapping_bodies():
			if b == target:
				inside = true
				break
	if not inside and detection_area.has_method("get_overlapping_areas") and target is Area2D:
		for a in detection_area.get_overlapping_areas():
			if a == target:
				inside = true
				break
	
	return SUCCESS if inside else FAILURE
