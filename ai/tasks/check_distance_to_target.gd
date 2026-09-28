@tool
extends BTCondition
## Cek apakah jarak agent ke target berada dalam rentang tertentu
## Dipakai untuk memisahkan jurus berdasarkan pita jarak (mis. trap dekat, panah jauh)
## Returns SUCCESS jika jarak berada di antara min_distance dan max_distance
## Returns FAILURE jika target tidak valid atau jarak di luar rentang

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## Jarak minimal (inklusif). 0 berarti tanpa batas bawah
@export var min_distance: float = 0.0

## Jarak maksimal (inklusif). 0 berarti tanpa batas atas
@export var max_distance: float = 0.0


func _generate_name() -> String:
	var upper := "∞" if max_distance <= 0.0 else "%.0f" % max_distance
	return "CheckDistance %s (%.0f..%s)" % [LimboUtility.decorate_var(target_var), min_distance, upper]


func _tick(_delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)

	if not is_instance_valid(target):
		return FAILURE

	var distance: float = agent.global_position.distance_to(target.global_position)

	if distance < min_distance:
		return FAILURE

	if max_distance > 0.0 and distance > max_distance:
		return FAILURE

	return SUCCESS
