class_name NorcThexArrowWarning
extends Node2D

## Garis merah peringatan sebelum Norc'Thex menembakkan panah.
## Muncul sejalur dengan arah tembakan supaya player sempat menghindar.
## Menghilang sendiri tepat saat panah dilepaskan.

## Panjang maksimal garis peringatan (dipendekkan otomatis jika terhalang tembok)
@export var length: float = 720.0

## Tebal garis inti
@export var thickness: float = 3.0

## Berapa lama garis ditampilkan (idealnya = jeda sampai panah ditembakkan)
@export var duration: float = 0.8

## Berapa kali garis berkedip selama durasi
@export var blink_count: float = 5.0

## Warna peringatan
@export var color: Color = Color(1.0, 0.16, 0.16)

## Arah tembakan, diisi oleh yang men-spawn (sudah dinormalisasi)
var direction: Vector2 = Vector2.RIGHT

## RID yang diabaikan saat mencari tembok (mis. bos dan player)
var exclude: Array[RID] = []

var elapsed: float = 0.0


func _ready() -> void:
	z_index = 10
	# Garis digambar sepanjang sumbu X lokal, jadi node-nya yang diputar
	rotation = direction.angle()
	_clip_to_wall()
	queue_redraw()


func _clip_to_wall() -> void:
	"""Memendekkan garis sampai tembok terdekat supaya indikatornya jujur:
	garis berhenti persis di tempat panah nanti akan menancap."""
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + direction * length)
	query.collide_with_areas = false
	query.exclude = exclude

	var hit := space.intersect_ray(query)
	if hit:
		length = global_position.distance_to(hit.position)


func _process(delta: float) -> void:
	elapsed += delta

	if elapsed >= duration:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)

	# Kedip makin terang mendekati saat tembakan
	var pulse: float = 0.4 + 0.6 * absf(sin(progress * blink_count * PI))
	var tip := Vector2(length, 0.0)

	# Pita lebar sebagai penanda area bahaya
	draw_line(Vector2.ZERO, tip, Color(color.r, color.g, color.b, 0.16 * pulse), thickness * 4.0)
	# Garis inti
	draw_line(Vector2.ZERO, tip, Color(color.r, color.g, color.b, 0.85 * pulse), thickness)

	# Mata panah kecil di ujung garis biar arahnya jelas
	var head := PackedVector2Array([
		tip,
		tip + Vector2(-10.0, -6.0),
		tip + Vector2(-10.0, 6.0),
	])
	draw_colored_polygon(head, Color(color.r, color.g, color.b, 0.85 * pulse))
