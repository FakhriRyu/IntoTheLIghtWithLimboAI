extends Node
## Titik masuk uji mekanik: memasang driver di /root, lalu driver memuat main menu.
## Jalankan: godot --headless --path . res://Scenes/Tests/game_flow_test.tscn


func _ready() -> void:
	var driver := preload("res://Scripts/Tests/game_flow_driver.gd").new()
	driver.name = "GameFlowDriver"
	get_tree().root.add_child.call_deferred(driver)
