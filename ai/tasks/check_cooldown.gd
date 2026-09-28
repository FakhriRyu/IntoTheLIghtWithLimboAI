@tool
extends BTCondition
## Cek apakah cooldown sebuah jurus sudah selesai
## Cooldown disimpan di blackboard sebagai timestamp absolut (detik)
## Returns SUCCESS jika variable belum pernah diset atau waktunya sudah lewat
## Returns FAILURE jika masih dalam masa cooldown

## Blackboard variable yang menyimpan waktu cooldown berakhir
@export var cooldown_var: StringName = &"cooldown_end"


func _generate_name() -> String:
	return "CheckCooldown %s" % [LimboUtility.decorate_var(cooldown_var)]


func _tick(_delta: float) -> Status:
	# Belum pernah dipakai sama sekali, jadi tidak ada cooldown
	if not blackboard.has_var(cooldown_var):
		return SUCCESS

	var cooldown_end: float = blackboard.get_var(cooldown_var, 0.0)
	var current_time: float = Time.get_ticks_msec() / 1000.0

	if current_time < cooldown_end:
		return FAILURE

	return SUCCESS
