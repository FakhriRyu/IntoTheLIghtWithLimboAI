extends CanvasLayer
## HUD player di pojok kiri atas, bergaya kartu karakter: potret dalam bingkai
## wajik, nama, health bar (dengan angka HP), sisa cahaya, cooldown dash, serta
## chip level + garis XP. Tombol jeda di pojok kanan atas membuka PauseMenu.
## Tekstur dibuat oleh tools/build_ui_art.py.
## Dipasang sebagai anak dari scene level; player dicari otomatis lewat group "player".

## Nama yang ditampilkan di atas health bar
@export var character_name: String = "FIORA"

## Warna bar dash saat sudah siap dipakai / sedang mengisi ulang
@export var dash_ready_color: Color = Color(0.35, 0.85, 1.0)
@export var dash_charging_color: Color = Color(0.45, 0.45, 0.55)

## Warna health bar saat HP penuh dan saat HP kritis (di bawah low_hp_threshold)
@export var health_color: Color = Color(0.85, 0.22, 0.25)
@export var health_low_color: Color = Color(1.0, 0.65, 0.15)
@export var low_hp_threshold: float = 0.3
## Kecepatan bar "jejak" HP (terang) menyusul HP sebenarnya, rasio per detik
@export var hp_trail_speed: float = 0.6

## Warna bar cahaya; di bawah low_light_threshold berdenyut ke warna bahaya
@export var light_color: Color = Color(1.0, 0.82, 0.4)
@export var light_danger_color: Color = Color(1.0, 0.25, 0.2)
@export var low_light_threshold: float = 0.25

@onready var name_label: Label = $Root/Panel/NameLabel
@onready var level_label: Label = $Root/Panel/LevelChip/LevelLabel
@onready var hp_fill: TextureProgressBar = $Root/Panel/HpFrame/HpFill
@onready var hp_trail: TextureProgressBar = $Root/Panel/HpFrame/HpTrail
@onready var hp_text: Label = $Root/Panel/HpFrame/HpText
@onready var dash_fill: TextureProgressBar = $Root/Panel/DashFrame/DashFill
@onready var light_fill: TextureProgressBar = $Root/Panel/LightFrame/LightFill
@onready var xp_fill: TextureProgressBar = $Root/Panel/XpFrame/XpFill
@onready var pause_button: TextureButton = $Root/PauseButton
@onready var pause_menu: CanvasLayer = $PauseMenu

var player: Node = null
var health: Node = null
var _pulse: float = 0.0


func _ready() -> void:
	name_label.text = character_name
	pause_button.pressed.connect(pause_menu.open)
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
	_update_health(delta)
	_update_dash()


func _update_light(delta: float) -> void:
	var ratio := RunState.light_ratio()
	light_fill.value = ratio
	if ratio <= low_light_threshold:
		# makin gelap makin cepat berdenyut
		_pulse += delta * lerpf(14.0, 5.0, ratio / low_light_threshold)
		light_fill.tint_progress = light_color.lerp(light_danger_color, 0.5 + 0.5 * sin(_pulse))
	else:
		light_fill.tint_progress = light_color


func _update_xp() -> void:
	xp_fill.value = float(RunState.xp) / float(RunState.xp_to_next())
	level_label.text = "Lv %d" % RunState.level


func _update_health(delta: float) -> void:
	if health == null or not ("max_health" in health and "current_health" in health):
		return

	var max_hp := float(health.max_health)
	if max_hp <= 0.0:
		return

	var ratio := clampf(float(health.current_health) / max_hp, 0.0, 1.0)
	hp_fill.value = ratio
	hp_fill.tint_progress = health_low_color if ratio <= low_hp_threshold else health_color
	# jejak terang tertinggal sebentar saat terkena damage, langsung ikut saat heal
	hp_trail.value = ratio if ratio > hp_trail.value else move_toward(hp_trail.value, ratio, hp_trail_speed * delta)
	hp_text.text = "%d/%d" % [maxi(int(health.current_health), 0), int(max_hp)]


func _update_dash() -> void:
	if not ("dash_cooldown" in player and "dash_cooldown_timer" in player):
		return

	var cooldown := float(player.dash_cooldown)
	var remaining := float(player.dash_cooldown_timer)
	var ratio := 1.0 if cooldown <= 0.0 else clampf(1.0 - remaining / cooldown, 0.0, 1.0)
	dash_fill.value = ratio

	var is_ready: bool = player.can_dash if "can_dash" in player else ratio >= 1.0
	dash_fill.tint_progress = dash_ready_color if is_ready else dash_charging_color
