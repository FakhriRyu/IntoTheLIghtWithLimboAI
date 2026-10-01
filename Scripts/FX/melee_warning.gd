class_name MeleeWarning
extends Node2D
## Zona merah peringatan sebelum serangan jarak dekat (mis. ayunan Goblin).
## Gayanya sama dengan garis peringatan panah Norc'Thex: merah, berkedip makin
## terang mendekati saat serangan. Zonanya persis seukuran hitbox serangan,
## jadi yang terlihat merah memang area yang akan terkena.
## Menghilang sendiri tepat saat serangan dilepaskan.

## Area bahaya dalam koordinat lokal parent (biasanya diambil dari hitbox)
@export var rect: Rect2 = Rect2(-40.0, -6.0, 80.0, 24.0)

## Berapa lama zona ditampilkan (idealnya = jeda sampai serangan dilepas)
@export var duration: float = 0.6

## Berapa kali zona berkedip selama durasi
@export var blink_count: float = 4.0

## Warna peringatan
@export var color: Color = Color(1.0, 0.16, 0.16)

## Tanda seru di atas kepala penyerang, relatif terhadap tengah atas zona
@export var mark_offset: Vector2 = Vector2(0.0, -26.0)

var elapsed: float = 0.0


func _ready() -> void:
	z_index = 10
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var pulse: float = 0.4 + 0.6 * absf(sin(progress * blink_count * PI))

	# Isi zona makin pekat seiring waktu, plus garis tepi yang berkedip
	draw_rect(rect, Color(color.r, color.g, color.b, 0.10 * pulse + 0.18 * progress))
	draw_rect(rect, Color(color.r, color.g, color.b, 0.85 * pulse), false, 1.5)

	# Tanda seru kecil yang berdenyut di atas kepala
	var top := Vector2(rect.get_center().x, rect.position.y) + mark_offset
	var mark := Color(color.r, color.g, color.b, 0.95)
	var bob: float = sin(progress * blink_count * TAU) * 1.5
	draw_rect(Rect2(top.x - 1.5, top.y - 9.0 + bob, 3.0, 8.0), mark)
	draw_rect(Rect2(top.x - 1.5, top.y + 1.0 + bob, 3.0, 3.0), mark)
