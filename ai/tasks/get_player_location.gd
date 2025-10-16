@tool
extends BTAction
## Mendapatkan player dari group "player" dan menyimpannya ke blackboard
## Returns SUCCESS jika player ditemukan
## Returns FAILURE jika player tidak ditemukan

## Blackboard variable untuk menyimpan player
@export var output_var: StringName = &"target"


func _generate_name() -> String:
	return "GetPlayer ➜%s" % [LimboUtility.decorate_var(output_var)]


func _tick(_delta: float) -> Status:
	var players = agent.get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return FAILURE
	
	blackboard.set_var(output_var, players[0])
	return SUCCESS
