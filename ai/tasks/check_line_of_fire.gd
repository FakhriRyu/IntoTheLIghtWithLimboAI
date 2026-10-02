@tool
extends BTCondition
## Cek apakah agent punya jalur tembak bersih ke target
## Memanggil method agent (default: has_line_of_fire) yang melakukan raycast
## dan cek sudut bidikan, supaya musuh ranged tidak menembaki dinding
## Returns SUCCESS jika jalur tembak bersih
## Returns FAILURE jika terhalang tembok, sudutnya terlalu curam, atau method tidak ada

## Nama method pada agent yang mengembalikan bool
@export var check_method: StringName = &"has_line_of_fire"


func _generate_name() -> String:
	return "CheckLineOfFire ➜%s()" % check_method


func _tick(_delta: float) -> Status:
	if not agent.has_method(check_method):
		return FAILURE

	return SUCCESS if agent.call(check_method) else FAILURE
