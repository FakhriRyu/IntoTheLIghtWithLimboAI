extends CanvasLayer
## HUD player di pojok kanan atas: potret, nama + level, health bar, sisa cahaya,
## cooldown dash, dan XP.
## Dipasang sebagai anak dari scene level; player dicari otomatis lewat group "player".

## Nama yang ditampilkan di atas health bar
@export var character_name: String = "WARRIOR"

## Warna bar dash saat sudah siap dipakai / sedang mengisi ulang
@export var dash_ready_color: Color = Color(0.35, 0.85, 1.0)
@export var dash_charging_color: Color = Color(0.45, 0.45, 0.55)

## Warna health bar saat HP penuh dan saat HP kritis (di bawah low_hp_threshold)
@export var health_color: Color = Color(0.85, 0.22, 0.25)
@export var health_low_color: Color = Color(1.0, 0.65, 0.15)
@export var low_hp_threshold: float = 0.3

## Warna bar cahaya; di bawah low_light_threshold berdenyut ke warna bahaya
@export var light_color: Color = Color(1.0, 0.82, 0.4)
@export var light_danger_color: Color = Color(1.0, 0.25, 0.2)
@export var low_light_threshold: float = 0.25

@onready var name_label: Label = $Root/Panel/NameLabel
@onready var portrait: TextureRect = $Root/Panel/Portrait
@onready var health_fill: ColorRect = $Root/Panel/HealthBg/HealthFill
@onready var dash_fill: ColorRect = $Root/Panel/DashBg/DashFill
@onready var light_fill: ColorRect = $Root/Panel/LightBg/LightFill
@onready var xp_fill: ColorRect = $Root/Panel/XpBg/XpFill

var player: Node = null
var health: Node = null
var _pulse: float = 0.0


func _ready() -> void:
	name_label.text = character_name
	_find_player()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	health = null
	if is_instance_valid(player):
		health = player.get_node_or_null("Health")


func _process(delta: float) -> void:
	_update_light(delta)
	_update_xp()
	if not is_instance_valid(player):
		_find_player()
		if not is_instance_valid(player):
			return
	_update_health()
	_update_dash()


func _set_fill(fill: ColorRect, ratio: float) -> void:
	var slot := fill.get_parent() as Control
	fill.size.x = maxf((slot.size.x - 2.0) * clampf(ratio, 0.0, 1.0), 0.0)


func _update_light(delta: float) -> void:
	var ratio := RunState.light_ratio()
	_set_fill(light_fill, ratio)
	if ratio <= low_light_threshold:
		# makin gelap makin cepat berdenyut
		_pulse += delta * lerpf(14.0, 5.0, ratio / low_light_threshold)
		light_fill.color = light_color.lerp(light_danger_color, 0.5 + 0.5 * sin(_pulse))
	else:
		light_fill.color = light_color


func _update_xp() -> void:
	_set_fill(xp_fill, float(RunState.xp) / float(RunState.xp_to_next()))
	name_label.text = "%s  Lv %d" % [character_name, RunState.level]


func _update_health() -> void:
	if health == null or not ("max_health" in health and "current_health" in health):
		return

	var max_hp := float(health.max_health)
	if max_hp <= 0.0:
		return

	var ratio := clampf(float(health.current_health) / max_hp, 0.0, 1.0)
	var slot := health_fill.get_parent() as Control
	health_fill.size.x = maxf((slot.size.x - 2.0) * ratio, 0.0)
	health_fill.color = health_low_color if ratio <= low_hp_threshold else health_color


func _update_dash() -> void:
	if not ("dash_cooldown" in player and "dash_cooldown_timer" in player):
		return

	var cooldown := float(player.dash_cooldown)
	var remaining := float(player.dash_cooldown_timer)
	var ratio := 1.0 if cooldown <= 0.0 else clampf(1.0 - remaining / cooldown, 0.0, 1.0)

	var slot := dash_fill.get_parent() as Control
	dash_fill.size.x = maxf((slot.size.x - 2.0) * ratio, 0.0)

	var is_ready: bool = player.can_dash if "can_dash" in player else ratio >= 1.0
	dash_fill.color = dash_ready_color if is_ready else dash_charging_color
