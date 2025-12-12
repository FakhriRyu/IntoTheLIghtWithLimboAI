@tool
extends BTCondition
## Cek apakah HP agent di bawah threshold tertentu (default 30%)
## Juga cek apakah flee cooldown sudah selesai
## Returns SUCCESS jika HP di bawah threshold DAN tidak dalam cooldown
## Returns FAILURE jika HP cukup tinggi, dalam cooldown, atau health tidak ditemukan

## Threshold HP dalam persen (0.0 - 1.0)
## Default: 0.3 = 30%
@export var hp_threshold: float = 0.3

## Path ke Health node pada agent
@export var health_node_path: NodePath = ^"Health"

## Blackboard variable untuk cek cooldown (dari flee_from_target)
@export var cooldown_var: StringName = &"flee_cooldown_end"

var health_node: Node


func _generate_name() -> String:
	return "CheckLowHP (< %d%%)" % int(hp_threshold * 100)


func _setup() -> void:
	if health_node_path:
		health_node = agent.get_node_or_null(health_node_path)


func _tick(_delta: float) -> Status:
	# Cek apakah masih dalam cooldown (hanya jika variable ada di blackboard)
	if blackboard.has_var(cooldown_var):
		var cooldown_end: float = blackboard.get_var(cooldown_var, 0.0)
		var current_time: float = Time.get_ticks_msec() / 1000.0
		
		if current_time < cooldown_end:
			# Masih dalam cooldown, jangan flee dulu
			return FAILURE
	
	if health_node == null:
		return FAILURE
	
	var current_hp: int = 0
	var max_hp: int = 1
	
	# Ambil current_health dan max_health dari health node
	if "current_health" in health_node:
		current_hp = health_node.current_health
	elif health_node.has_method("get_current_health"):
		current_hp = health_node.get_current_health()
	else:
		return FAILURE
	
	if "max_health" in health_node:
		max_hp = health_node.max_health
	else:
		return FAILURE
	
	# Hitung persentase HP
	var hp_percent: float = float(current_hp) / float(max_hp)
	
	# Return SUCCESS jika HP di bawah threshold
	if hp_percent <= hp_threshold:
		return SUCCESS
	
	return FAILURE
