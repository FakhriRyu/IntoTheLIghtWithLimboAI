extends LimboState

@export var animation_player: AnimationPlayer
@export var animation: StringName


func _enter() -> void:
	if animation_player:
		animation_player.play(animation)
		# Hubungkan signal untuk menghapus orc setelah animasi selesai
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	else:
		# Jika tidak ada animation player, langsung hapus setelah delay
		await agent.get_tree().create_timer(1.0).timeout
		agent.queue_free()

func _ready() -> void:
	pass

func _update(_delta: float) -> void:
	# Set velocity ke 0 agar orc tidak bergerak saat mati
	agent.velocity = Vector2.ZERO

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == animation:
		# Hapus orc dari scene setelah animasi death selesai
		agent.queue_free()
