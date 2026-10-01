extends Node2D
## Health bar kecil di atas musuh biasa. Hanya muncul saat musuh terkena serangan,
## lalu memudar sendiri.
##
## Health dibaca lewat polling, bukan signal, karena tiap musuh di proyek ini
## memakai script Health berbeda dengan signature signal "damaged" yang tidak sama
## (ada yang 1 argumen, ada yang 2). Polling bikin komponen ini cocok untuk semuanya.

## Kosongkan untuk mencari node Health secara otomatis di antara saudara sendiri
@export var health_path: NodePath

## Berapa lama bar tetap terlihat setelah pukulan terakhir
@export var visible_duration: float = 2.5

## Lama memudar setelah waktu tampil habis
@export var fade_duration: float = 0.4

## Sembunyikan bar setelah musuh mati
@export var hide_on_death: bool = true

@onready var bg: ColorRect = $Bg
@onready var fill: ColorRect = $Fill

var health: Node = null
var _last_hp: int = -1
var _timer: float = 0.0


func _ready() -> void:
	health = _find_health()
	modulate.a = 0.0
	if health != null and "current_health" in health:
		_last_hp = int(health.current_health)


func _find_health() -> Node:
	if not health_path.is_empty():
		var n := get_node_or_null(health_path)
		if n != null:
			return n

	var parent := get_parent()
	if parent == null:
		return null

	for c in parent.get_children():
		if "current_health" in c and "max_health" in c:
			return c
	return null


func _process(delta: float) -> void:
	if health == null:
		return

	var hp := int(health.current_health)
	var max_hp := float(health.max_health)

	# Muncul begitu HP berkurang
	if hp < _last_hp:
		_timer = visible_duration + fade_duration
	_last_hp = hp

	if hide_on_death and hp <= 0:
		modulate.a = 0.0
		return

	if _timer <= 0.0:
		modulate.a = 0.0
		return

	_timer -= delta
	modulate.a = 1.0 if _timer > fade_duration else clampf(_timer / fade_duration, 0.0, 1.0)

	if max_hp > 0.0:
		var ratio := clampf(float(hp) / max_hp, 0.0, 1.0)
		fill.size.x = maxf((bg.size.x - 2.0) * ratio, 0.0)


## Dipanggil manual kalau mau memunculkan bar tanpa menunggu damage
func show_bar() -> void:
	_timer = visible_duration + fade_duration
