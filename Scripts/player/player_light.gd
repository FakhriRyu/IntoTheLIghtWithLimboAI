extends PointLight2D
## Cahaya player yang terus meredup. Sisa cahaya disimpan di RunState;
## node ini menguras cahaya tiap frame dan mengecilkan radius sesuai sisanya.
## Di bawah ambang kritis lampu berkedip sebagai peringatan: cahaya 0 = mati.

## Radius & terang dasar. Level boleh menimpanya (lihat CaveLevel._setup_view).
var base_scale: float
var base_energy: float

## Radius / terang paling kecil (dikali base) saat cahaya hampir habis
@export var min_scale_ratio: float = 0.35
@export var min_energy_ratio: float = 0.55
## Di bawah rasio ini lampu mulai berkedip
@export var flicker_threshold: float = 0.25

var _player: Node = null
var _flicker: float = 1.0
var _flicker_timer: float = 0.0
## Hitung mundur bunyi "tik" peringatan
var _tick_timer: float = 0.0


func _ready() -> void:
	base_scale = texture_scale
	base_energy = energy
	_player = get_parent()


func _process(delta: float) -> void:
	if _player_alive():
		RunState.drain_light(delta)

	var ratio := RunState.light_ratio()
	_update_flicker(delta, ratio)
	_update_tick(delta, ratio)
	var radius_mult := float(RunState.stats.get("radius_mult", 1.0))
	texture_scale = base_scale * radius_mult * lerpf(min_scale_ratio, 1.0, ratio) * _flicker
	energy = base_energy * lerpf(min_energy_ratio, 1.0, ratio) * _flicker


func _player_alive() -> bool:
	if _player == null:
		return false
	var h = _player.get_node_or_null("Health")
	return h != null and h.is_alive()


## "Tik" peringatan saat cahaya kritis, makin cepat makin gelap
func _update_tick(delta: float, ratio: float) -> void:
	if ratio >= flicker_threshold or ratio <= 0.0 or not _player_alive():
		_tick_timer = 0.0
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		var danger := 1.0 - ratio / flicker_threshold
		_tick_timer = lerpf(0.9, 0.25, danger)
		Audio.play_sfx(&"light_tick", lerpf(-12.0, -4.0, danger), 0.0, lerpf(1.0, 1.3, danger))


func _update_flicker(delta: float, ratio: float) -> void:
	if ratio >= flicker_threshold or ratio <= 0.0:
		_flicker = 1.0
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		# makin gelap makin sering dan makin dalam kedipnya
		var danger := 1.0 - ratio / flicker_threshold
		_flicker_timer = randf_range(0.05, lerpf(0.4, 0.12, danger))
		_flicker = 1.0 - randf() * lerpf(0.12, 0.45, danger)
