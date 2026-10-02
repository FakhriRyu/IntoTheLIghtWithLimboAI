class_name Spikes
extends Area2D
## Deretan duri di lantai. Player yang menyentuhnya kena damage lalu dipental kecil
## keluar dari deretan duri (player.hazard_knockback). Selagi player immune tidak ada
## damage, tapi tetap dipental supaya duri tidak bisa dilewati begitu saja.
##
## Titik asal node = permukaan lantai, di tengah deretan. Sprite dan collision
## dibangun dari width_tiles, jadi level procedural cukup mengisi lebarnya.

const TILE := 32.0
const TEXTURE := preload("res://Assets/Tiles/CastleTiles.png")
## Dua potong duri pendek di CastleTiles (16x8 px, digambar 2x)
const REGIONS: Array[Rect2] = [Rect2(192, 56, 16, 8), Rect2(208, 56, 16, 8)]

## Jarak ekstra melewati tepi deretan saat dipental (setengah badan + sedikit)
const CLEARANCE := 16.0

@export var damage: int = 2
## Lebar deretan duri dalam tile 32px
@export_range(1, 6) var width_tiles: int = 1


func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 0
	# layer 4: player_hurtbox
	collision_mask = 1 << 3
	monitorable = false

	for i in range(width_tiles):
		var s := Sprite2D.new()
		s.texture = TEXTURE
		s.region_enabled = true
		s.region_rect = REGIONS[i % REGIONS.size()]
		s.scale = Vector2(2, 2)
		s.position = Vector2((i - (width_tiles - 1) * 0.5) * TILE, -8.0)
		add_child(s)

	# sedikit lebih sempit dari gambarnya, supaya ujung yang hanya menyerempet tidak dihitung
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * TILE - 8.0, 10.0)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -5.0)
	add_child(col)


func _physics_process(_delta: float) -> void:
	# Dicek tiap frame, bukan area_entered: player yang mendarat lagi di atas duri
	# (atau hurtbox-nya baru aktif lagi setelah i-frame dash) tetap kena.
	for area in get_overlapping_areas():
		if area is GameHurtbox:
			_hit(area)


func _hit(area: Area2D) -> void:
	var player := area.get_parent()
	if not player.has_method("hazard_knockback") or player.is_hurt:
		return
	var h = player.get_node_or_null("Health")
	if h == null or not h.is_alive():
		return

	# Arah dibaca sebelum damage, karena damage ikut mengubah velocity.
	# Datang dari samping (jalan/dash) = dipental balik ke arah datangnya;
	# jatuh dari atas = ke tepi deretan yang terdekat.
	var dx: float = player.global_position.x - global_position.x
	var dir: float = -signf(player.velocity.x) if absf(player.velocity.x) > 30.0 else signf(dx)
	if dir == 0.0:
		dir = 1.0
	var edge_x: float = global_position.x + dir * width_tiles * TILE * 0.5
	var distance: float = absf(edge_x - player.global_position.x) + CLEARANCE

	Audio.play_sfx_at(&"trap_snap", global_position, -6.0)
	if not player.is_immune:
		area.take_damage(damage, global_position + Vector2(0, 8))
	if h.is_alive():
		player.hazard_knockback(dir, distance)
