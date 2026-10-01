extends CanvasLayer
## Health bar besar untuk boss di bagian bawah layar, lengkap dengan nama bosnya.
## Muncul saat player masuk area deteksi boss, lalu hilang setelah boss mati.

## Nama yang ditampilkan di atas bar
@export var boss_name: String = "NORC'THEX"

## Group tempat boss mendaftarkan diri
@export var boss_group: StringName = &"boss"

## Nama node Area2D milik boss yang dipakai sebagai pemicu munculnya bar
@export var detection_area_name: String = "DetectionAreaBoss"

## Kalau true, bar langsung tampil tanpa menunggu player masuk area deteksi
@export var always_visible: bool = false

@export var fade_duration: float = 0.5

@onready var root: Control = $Root
@onready var name_label: Label = $Root/Bar/NameLabel
@onready var fill: ColorRect = $Root/Bar/BarBg/BarFill
@onready var bar_bg: ColorRect = $Root/Bar/BarBg

var boss: Node = null
var health: Node = null
var engaged: bool = false


func _ready() -> void:
	name_label.text = boss_name
	root.modulate.a = 0.0
	_find_boss()


func _find_boss() -> void:
	boss = get_tree().get_first_node_in_group(boss_group)
	health = null
	if is_instance_valid(boss):
		health = boss.get_node_or_null("Health")


func _process(delta: float) -> void:
	if not is_instance_valid(boss):
		_find_boss()
		if not is_instance_valid(boss):
			_fade(delta, false)
			return

	if not engaged:
		engaged = always_visible or _player_in_range()

	var alive := health != null and "current_health" in health and int(health.current_health) > 0
	_fade(delta, engaged and alive)

	if health != null and "max_health" in health:
		var max_hp := float(health.max_health)
		if max_hp > 0.0:
			var ratio := clampf(float(health.current_health) / max_hp, 0.0, 1.0)
			fill.size.x = maxf((bar_bg.size.x - 4.0) * ratio, 0.0)


func _player_in_range() -> bool:
	var area := boss.get_node_or_null(detection_area_name) as Area2D
	if area == null:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return false
	if area.has_method("overlaps_body") and player is PhysicsBody2D:
		return area.overlaps_body(player)
	return false


func _fade(delta: float, target_visible: bool) -> void:
	var step := delta / maxf(fade_duration, 0.001)
	var target := 1.0 if target_visible else 0.0
	root.modulate.a = move_toward(root.modulate.a, target, step)
