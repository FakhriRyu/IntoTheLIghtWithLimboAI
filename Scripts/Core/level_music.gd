extends Node
## Menentukan musik latar sebuah level. Taruh sebagai anak scene level dan
## pilih track-nya (lihat Audio.MUSIC).

@export_enum("castle", "cave", "boss") var track: String = "castle"
@export var fade: float = 1.5


func _ready() -> void:
	Audio.play_music(StringName(track), fade)
