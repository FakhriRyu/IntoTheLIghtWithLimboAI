@tool
extends BTCondition
## Cek sebuah flag bool milik agent, lalu langsung mematikannya (sekali pakai)
## Dipakai agar kejadian di luar tree (mis. state HSM Stagger) bisa memicu
## satu branch tepat satu kali, tanpa bergantung pada scope blackboard
## Returns SUCCESS jika flag bernilai true (flag lalu diset false)
## Returns FAILURE jika flag false atau tidak ada

## Nama properti bool pada agent
@export var flag: StringName = &""


func _generate_name() -> String:
	return "ConsumeAgentFlag \"%s\"" % flag


func _tick(_delta: float) -> Status:
	if flag.is_empty() or not agent.get(flag):
		return FAILURE

	agent.set(flag, false)
	return SUCCESS
