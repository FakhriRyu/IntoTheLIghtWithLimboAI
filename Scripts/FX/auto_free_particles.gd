extends CPUParticles2D
## Partikel sekali pakai: menyala saat muncul, lalu menghapus diri sendiri.

func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
	# jaring pengaman kalau signal "finished" tidak pernah terpanggil
	get_tree().create_timer(lifetime * 2.0 + 0.5).timeout.connect(
		func(): if is_instance_valid(self): queue_free())
