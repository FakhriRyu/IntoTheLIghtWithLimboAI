extends CanvasLayer
## Health bar bos di bagian bawah layar: lambang tengkorak bertanduk, nama + gelar,
## bar besi berduri berisi darah, dan penanda ambang fase 2.
## Muncul saat player masuk area deteksi bos (isi bar "terisi" dramatis),
## bergetar dan meninggalkan jejak saat bos terluka, berubah mengamuk di fase 2,
## lalu hilang setelah bos mati. Tekstur dibuat oleh tools/build_ui_art.py.

## Nama yang ditampilkan di atas bar
@export var boss_name: String = "Norc'Thex"
## Gelar kecil di sisi kanan atas bar (kosongkan untuk menyembunyikan)
@export var boss_title: String = "Sang Pemburu Kegelapan"

## Group tempat boss mendaftarkan diri
@export var boss_group: StringName = &"boss"

## Nama node Area2D milik boss yang dipakai sebagai pemicu munculnya bar
@export var detection_area_name: String = "DetectionAreaBoss"

## Kalau true, bar langsung tampil tanpa menunggu player masuk area deteksi
@export var always_visible: bool = false

@export var fade_duration: float = 0.5
## Lama isi bar terisi dari kosong saat bos pertama kali muncul
@export var intro_duration: float = 1.1

@export_group("Warna")
@export var fill_color: Color = Color(0.78, 0.1, 0.14)
## Warna isi bar di fase 2 (berdenyut antara fill_color dan warna ini)
@export var enraged_color: Color = Color(0.5, 0.02, 0.08)
## Warna kedip isi bar saat bos terkena pukulan
@export var hit_flash_color: Color = Color(1.0, 0.9, 0.85)
@export var name_color: Color = Color(0.93, 0.86, 0.76)
@export var enraged_name_color: Color = Color(1.0, 0.38, 0.32)

@export_group("Efek")
## Jeda sebelum jejak (bagian terang) mulai menyusul HP sebenarnya
@export var trail_delay: float = 0.4
## Kecepatan jejak menyusul, rasio per detik
@export var trail_speed: float = 0.5
## Besar getaran bar saat terkena pukulan (piksel)
@export var shake_strength: float = 2.5
## Di bawah rasio ini isi bar berdenyut seperti detak jantung
@export var low_hp_threshold: float = 0.25

@onready var root: Control = $Root
@onready var bar: Control = $Root/Bar
@onready var name_label: Label = $Root/Bar/NameLabel
@onready var title_label: Label = $Root/Bar/TitleLabel
@onready var fill: TextureProgressBar = $Root/Bar/Frame/Fill
@onready var trail: TextureProgressBar = $Root/Bar/Frame/Trail
@onready var tick: TextureRect = $Root/Bar/Frame/Tick
@onready var crest: TextureRect = $Root/Bar/Crest
@onready var eyes: TextureRect = $Root/Bar/Crest/Eyes

var boss: Node = null
var health: Node = null
var engaged: bool = false

var _bar_origin: Vector2
var _intro_t: float = 0.0
var _last_ratio: float = 1.0
var _trail_wait: float = 0.0
var _shake: float = 0.0
var _flash: float = 0.0
var _enraged: bool = false
var _time: float = 0.0


func _ready() -> void:
	name_label.text = boss_name
	title_label.text = boss_title
	title_label.visible = not boss_title.is_empty()
	root.modulate.a = 0.0
	_bar_origin = bar.position
	eyes.modulate = Color(0.55, 0.55, 0.55)
	_find_boss()


func _find_boss() -> void:
	boss = get_tree().get_first_node_in_group(boss_group)
	health = null
	if is_instance_valid(boss):
		health = boss.get_node_or_null("Health")
		_place_tick()


func _place_tick() -> void:
	"""Tempatkan penanda fase 2 sesuai ambang HP milik bos (default 50%)."""
	var threshold := 0.5
	if "phase_two_threshold" in boss:
		threshold = float(boss.phase_two_threshold)
	tick.position.x = fill.position.x + fill.size.x * threshold - tick.size.x * 0.5
	tick.visible = threshold > 0.0 and threshold < 1.0


func _process(delta: float) -> void:
	_time += delta

	if not is_instance_valid(boss):
		_find_boss()
		if not is_instance_valid(boss):
			_fade(delta, false)
			return

	if not engaged:
		engaged = always_visible or _player_in_range()
		if engaged:
			_start_intro()

	var alive := health != null and "current_health" in health and int(health.current_health) > 0
	_fade(delta, engaged and alive)

	if not engaged or health == null or not ("max_health" in health):
		return

	var max_hp := float(health.max_health)
	if max_hp <= 0.0:
		return
	var ratio := clampf(float(health.current_health) / max_hp, 0.0, 1.0)

	_update_fill(delta, ratio)
	_update_enrage(delta)
	_update_shake(delta)


func _start_intro() -> void:
	_intro_t = 0.0
	_last_ratio = 1.0
	fill.value = 0.0
	trail.value = 0.0
	name_label.visible_ratio = 0.0
	title_label.modulate.a = 0.0


func _update_fill(delta: float, ratio: float) -> void:
	# Intro: bar terisi dari kosong, nama muncul huruf demi huruf
	if _intro_t < intro_duration:
		_intro_t += delta
		var t := clampf(_intro_t / intro_duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		fill.value = ratio * eased
		trail.value = fill.value
		name_label.visible_ratio = clampf(t * 1.6, 0.0, 1.0)
		title_label.modulate.a = clampf(t * 2.0 - 1.0, 0.0, 1.0)
		_last_ratio = ratio
		return

	if ratio < _last_ratio - 0.0001:
		_on_hit()
	_last_ratio = ratio

	fill.value = ratio
	# Jejak terang tertinggal sebentar lalu menyusul; langsung ikut kalau HP naik
	if ratio >= trail.value:
		trail.value = ratio
	elif _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		trail.value = move_toward(trail.value, ratio, trail_speed * delta)

	var color := fill_color
	if _enraged:
		color = fill_color.lerp(enraged_color, 0.5 + 0.5 * sin(_time * 5.0))
	if ratio <= low_hp_threshold:
		# detak jantung: dua denyut cepat lalu jeda
		var beat := fposmod(_time, 0.9)
		var pulse := maxf(1.0 - absf(beat - 0.08) / 0.08, 1.0 - absf(beat - 0.3) / 0.08)
		color = color.lerp(Color(1.0, 0.35, 0.3), clampf(pulse, 0.0, 1.0) * 0.6)
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	fill.tint_progress = color.lerp(hit_flash_color, _flash)


func _on_hit() -> void:
	_trail_wait = trail_delay
	_shake = 1.0
	_flash = 1.0


func _update_enrage(delta: float) -> void:
	var enraged_now: bool = "phase" in boss and int(boss.phase) >= 2
	if enraged_now and not _enraged:
		_enraged = true
		_shake = 2.0
		name_label.add_theme_color_override(&"font_color", enraged_name_color)
		# Penanda fase pecah: membesar lalu lenyap
		var tween := create_tween().set_parallel()
		tween.tween_property(tick, "scale", Vector2(2.2, 1.4), 0.35)
		tween.tween_property(tick, "modulate:a", 0.0, 0.35)
		# Lambang menghentak
		crest.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(crest, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Mata tengkorak redup di fase 1, menyala berdenyut saat mengamuk
	var glow := 0.55
	if _enraged:
		glow = 1.3 + 0.5 * sin(_time * 6.0)
	eyes.modulate = eyes.modulate.lerp(Color(glow, glow, glow), clampf(delta * 8.0, 0.0, 1.0))


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		# Simpan posisi diam terbaru (bisa berubah kalau ukuran jendela berubah)
		_bar_origin = bar.position
		return
	_shake = move_toward(_shake, 0.0, delta * 5.0)
	if _shake <= 0.0:
		bar.position = _bar_origin
		return
	var amount := shake_strength * minf(_shake, 1.0) * (2.0 if _shake > 1.0 else 1.0)
	bar.position = _bar_origin + Vector2(randf_range(-amount, amount), randf_range(-amount, amount) * 0.5).round()


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
