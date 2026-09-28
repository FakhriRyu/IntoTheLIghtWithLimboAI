@tool
extends BTAction
## Menghadapkan agent ke arah target tanpa bergerak
## Dipakai musuh yang menyerang dari tempat (mis. boss ranged)
## Returns SUCCESS jika target valid dan arah hadap sudah diupdate
## Returns FAILURE jika target tidak valid

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "FaceTarget %s" % [LimboUtility.decorate_var(target_var)]


func _tick(_delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)

	if not is_instance_valid(target):
		return FAILURE

	var direction: float = signf(target.global_position.x - agent.global_position.x)

	# Sudah sejajar persis, biarkan arah hadap yang sekarang
	if direction == 0.0:
		return SUCCESS

	if agent.has_method("update_facing"):
		agent.update_facing(direction)
	else:
		# Fallback untuk agent yang tidak punya method update_facing
		var sprite = agent.get_node_or_null("Sprite2D")
		if sprite and sprite is Sprite2D:
			sprite.flip_h = direction < 0

	return SUCCESS
