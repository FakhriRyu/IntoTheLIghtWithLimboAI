class_name CaveExit
extends Area2D
## Pintu keluar gua: berupa pilar cahaya. Begitu player masuk, pindah ke
## next_scene kalau diisi; kalau kosong, gua di-generate ulang (gua baru).

signal reached

## Scene tujuan berikutnya. Kosong = muat ulang scene ini (gua baru).
@export_file("*.tscn") var next_scene: String = ""

var _used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	reached.emit()
	if next_scene != "":
		get_tree().call_deferred("change_scene_to_file", next_scene)
	else:
		get_tree().call_deferred("reload_current_scene")
