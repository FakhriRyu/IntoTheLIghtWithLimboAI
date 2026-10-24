class_name GameFx
extends RefCounted

## Kumpulan efek "game feel": freeze frame (hit stop) dan partikel sekali pakai.
## Semua fungsinya static, jadi cukup dipanggil GameFx.hit_stop(self) dari mana saja
## tanpa perlu autoload.

## Penjaga supaya beberapa pukulan beruntun tidak saling menimpa
## dan meninggalkan time_scale dalam keadaan salah.
static var _stopping: bool = false


## Membekukan game sesaat saat pukulan mendarat.
## Timernya memakai ignore_time_scale, jadi tetap jalan walau waktu game dibekukan.
static func hit_stop(node: Node, duration: float = 0.07, scale: float = 0.0) -> void:
	if _stopping:
		return
	if node == null or not node.is_inside_tree():
		return

	var tree := node.get_tree()
	if tree == null:
		return

	_stopping = true
	Engine.time_scale = scale
	# argumen ke-4 = ignore_time_scale
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


## Tween goyangan yang sedang berjalan dan kekuatannya, supaya goyangan baru
## yang lebih lemah tidak memotong goyangan yang lebih kuat.
static var _shake_tween: Tween = null
static var _shake_camera: Camera2D = null
static var _shake_strength: float = 0.0


## Menggoyang kamera aktif sesaat. strength dalam piksel dunia, meluruh ke nol
## selama duration. Memakai offset kamera, jadi tidak bentrok dengan smoothing
## maupun limit kamera. Tetap jalan saat hit_stop membekukan waktu game.
static func shake(node: Node, strength: float = 3.0, duration: float = 0.2) -> void:
	if node == null or not node.is_inside_tree():
		return
	var cam := node.get_viewport().get_camera_2d()
	if cam == null:
		return

	if _shake_tween and _shake_tween.is_valid() and _shake_camera == cam:
		if _shake_strength > strength:
			return
		_shake_tween.kill()
	if is_instance_valid(_shake_camera):
		_shake_camera.offset = Vector2.ZERO

	_shake_camera = cam
	_shake_strength = strength
	_shake_tween = cam.create_tween().set_ignore_time_scale(true)
	_shake_tween.tween_method(func(t: float):
		_shake_strength = strength * t
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * t,
		1.0, 0.0, duration)
	_shake_tween.tween_callback(func():
		cam.offset = Vector2.ZERO
		_shake_strength = 0.0)


## Memunculkan satu scene partikel di posisi global tertentu.
## Partikelnya menghapus diri sendiri setelah selesai.
static func burst(node: Node, scene: PackedScene, global_pos: Vector2,
		direction: Vector2 = Vector2.ZERO) -> Node:
	if scene == null or node == null or not node.is_inside_tree():
		return null

	var host := _fx_host(node)
	if not is_instance_valid(host):
		return null

	var fx := scene.instantiate()
	host.add_child(fx)
	if fx is Node2D:
		fx.global_position = global_pos
		# hadapkan partikel ke arah pantulan, kalau arahnya diberikan
		if direction != Vector2.ZERO and "direction" in fx:
			fx.direction = direction
		elif direction.x != 0.0:
			fx.scale.x = signf(direction.x)
	return fx


## Mencari induk yang stabil untuk partikel.
## Penting: partikel TIDAK boleh menempel pada entitas yang memanggilnya,
## karena musuh yang mati langsung di-queue_free dan ledakannya ikut hilang
## sebelum sempat terlihat.
static func _fx_host(node: Node) -> Node:
	var tree := node.get_tree()
	if tree == null:
		return null

	if is_instance_valid(tree.current_scene):
		return tree.current_scene

	# Tidak ada current_scene (mis. saat dites): pakai leluhur teratas
	# yang masih berada di bawah root viewport.
	var n := node
	while n.get_parent() != null and n.get_parent() != tree.root:
		n = n.get_parent()
	return n


## Kedip sesaat pada sebuah sprite sebagai tanda pukulan mendarat.
## Digeneralisasi dari _flash() milik Norc'Thex supaya semua musuh memakai yang sama.
static func flash(sprite: CanvasItem, color: Color = Color(2.2, 2.2, 2.2),
		duration: float = 0.09) -> void:
	if not is_instance_valid(sprite) or not sprite.is_inside_tree():
		return

	sprite.modulate = color
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, duration)
