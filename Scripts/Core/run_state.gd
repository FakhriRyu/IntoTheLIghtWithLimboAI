extends Node
## State satu "run" roguelike: level, XP, cahaya, HP, dan upgrade yang dipilih.
## Didaftarkan sebagai autoload "RunState" supaya tetap hidup saat pindah scene
## (pintu keluar gua memakai change_scene_to_file / reload_current_scene).
## Mati = run berakhir dan semuanya di-reset.

signal xp_changed
signal light_changed
signal stats_changed
## Ada kartu upgrade yang menunggu dipilih (antrian di pending_picks)
signal pick_requested
signal light_depleted
signal run_ended

## Scene awal run baru setelah mati
@export_file("*.tscn") var run_start_scene: String = "res://Scenes/levels/tower.tscn"
## Lama bermain (detik) sampai cahaya di Normal menyusut dari 40 ke 25 detik
@export var normal_ramp_time: float = 480.0

const MAIN_MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const BASE_MAX_LIGHT := 100.0

enum Difficulty { EASY, NORMAL, HARD }
## Lama cahaya penuh sampai padam (detik) per kesulitan: [awal run, setelah normal_ramp_time].
## Upgrade decay_mult / max_light_bonus tetap berlaku di atasnya.
const LIGHT_SECONDS := {
	Difficulty.EASY: [40.0, 40.0],
	Difficulty.NORMAL: [40.0, 25.0],
	Difficulty.HARD: [25.0, 25.0],
}
const DIFFICULTY_NAMES := ["Mudah", "Normal", "Sulit"]
## Waktu tenang di awal tiap area sebelum cahaya mulai meredup
const LEVEL_GRACE := 3.0
## Cahaya yang tersisa saat diselamatkan "Sinar Terakhir"
const LAST_LIGHT_RESTORE := 30.0

const DEFAULT_STATS := {
	"damage_bonus": 0,
	"finisher_bonus": 0,
	"finisher_light": 0.0,
	"max_hp_bonus": 0,
	"speed_mult": 1.0,
	"dash_cd_mult": 1.0,
	"decay_mult": 1.0,
	"max_light_bonus": 0.0,
	"radius_mult": 1.0,
	"magnet_mult": 1.0,
	"light_on_hit": 0.0,
	"xp_mult": 1.0,
	"kill_heal_chance": 0.0,
	"immunity_bonus": 0.0,
	"last_light": 0,
}

## Dipilih di main menu; tidak di-reset antar run (lihat Settings)
var difficulty: Difficulty = Difficulty.NORMAL
## Lama bermain di run ini. Hanya bertambah saat player hidup dan game tidak di-pause.
var run_time: float = 0.0
var level: int = 1
var xp: int = 0
var light: float = BASE_MAX_LIGHT
var kills: int = 0
## HP dibawa antar-area. -1 = belum ada (pakai HP penuh).
var hp: int = -1
## id upgrade -> jumlah tumpukan
var upgrades: Dictionary = {}
var stats: Dictionary = {}
## Antrian sumber kartu yang belum dipilih: "level" atau "relic"
var pending_picks: Array[String] = []
## Sisa waktu tenang di awal area
var grace_timer: float = 0.0
## Sisa pemakaian "Sinar Terakhir" di area ini
var last_light_charges: int = 0

var _depleted: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset_run()


func reset_run() -> void:
	level = 1
	xp = 0
	kills = 0
	run_time = 0.0
	hp = -1
	upgrades.clear()
	stats = DEFAULT_STATS.duplicate()
	pending_picks.clear()
	light = max_light()
	_depleted = false
	stats_changed.emit()
	xp_changed.emit()
	light_changed.emit()


# ---------------------------------------------------------------- XP & level

## Kebutuhan XP tumbuh lebih cepat dari linear: 8, 24, 46, 73, 105, ...
func xp_to_next() -> int:
	return int(round(8.0 * pow(level, 1.6)))


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += maxi(int(round(amount * float(stats["xp_mult"]))), 1)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		queue_pick("level")
	xp_changed.emit()


## Meminta layar kartu upgrade. Dipakai saat naik level dan saat chest berisi relik.
func queue_pick(source: String) -> void:
	pending_picks.append(source)
	pick_requested.emit()


## Hingga `count` upgrade acak tanpa duplikat, dengan bobot rarity.
## Upgrade yang tumpukannya sudah penuh tidak ditawarkan lagi.
func roll_choices(count: int = 3, min_rarity: int = Upgrades.Rarity.COMMON) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for u in Upgrades.ALL:
		if u["rarity"] >= min_rarity and int(upgrades.get(u["id"], 0)) < int(u["max"]):
			pool.append(u)

	var out: Array[Dictionary] = []
	while out.size() < count and not pool.is_empty():
		# pilih rarity dulu (hanya yang masih punya kandidat), lalu upgrade-nya
		var total := 0.0
		for r in range(Upgrades.RARITY_WEIGHTS.size()):
			if _pool_has(pool, r):
				total += Upgrades.RARITY_WEIGHTS[r]
		var roll := _rng.randf() * total
		var tier := 0
		for r in range(Upgrades.RARITY_WEIGHTS.size()):
			if not _pool_has(pool, r):
				continue
			tier = r
			roll -= Upgrades.RARITY_WEIGHTS[r]
			if roll <= 0.0:
				break
		var tier_pool := pool.filter(func(u: Dictionary) -> bool: return u["rarity"] == tier)
		var pick: Dictionary = tier_pool[_rng.randi_range(0, tier_pool.size() - 1)]
		out.append(pick)
		pool.erase(pick)
	return out


func _pool_has(pool: Array[Dictionary], rarity: int) -> bool:
	for u in pool:
		if u["rarity"] == rarity:
			return true
	return false


func apply_upgrade(id: String) -> void:
	var u := Upgrades.get_by_id(id)
	if u.is_empty():
		return
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	for e in u["effects"]:
		add_stat(e[0], e[1])
	if id == "sinar":
		last_light_charges = maxi(last_light_charges, 1)
	if u.has("heal"):
		heal_player(int(u["heal"]))
	if u.has("light"):
		add_light(float(u["light"]))


func add_stat(stat: String, value) -> void:
	stats[stat] = stats.get(stat, 0) + value
	stats_changed.emit()
	light_changed.emit()


func upgrade_count(id: String) -> int:
	return int(upgrades.get(id, 0))


# ---------------------------------------------------------------- kesulitan

func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]


## Obor pengisi cahaya hanya muncul di Mudah dan Normal
func torches_enabled() -> bool:
	return difficulty != Difficulty.HARD


## Lama cahaya penuh sampai padam (tanpa upgrade) pada titik run sekarang
func light_duration() -> float:
	var range_s: Array = LIGHT_SECONDS[difficulty]
	var t := clampf(run_time / maxf(normal_ramp_time, 1.0), 0.0, 1.0)
	return lerpf(range_s[0], range_s[1], t)


# ---------------------------------------------------------------- cahaya

func max_light() -> float:
	return BASE_MAX_LIGHT + float(stats.get("max_light_bonus", 0.0))


func light_ratio() -> float:
	return clampf(light / max_light(), 0.0, 1.0)


func add_light(amount: float) -> void:
	if amount <= 0.0:
		return
	light = minf(light + amount, max_light())
	_depleted = false
	light_changed.emit()


func drain_light(delta: float) -> void:
	if _depleted:
		return
	run_time += delta
	if grace_timer > 0.0:
		grace_timer -= delta
		return
	light -= BASE_MAX_LIGHT / light_duration() * maxf(float(stats["decay_mult"]), 0.1) * delta
	if light <= 0.0:
		light = 0.0
		if last_light_charges > 0:
			# Sinar Terakhir: bertahan sekali per area
			last_light_charges -= 1
			light = LAST_LIGHT_RESTORE
		else:
			_depleted = true
			light_depleted.emit()
	light_changed.emit()


## Dipanggil player saat masuk area baru: cahaya penuh dan ada jeda tenang.
func begin_level() -> void:
	light = max_light()
	_depleted = false
	grace_timer = LEVEL_GRACE
	last_light_charges = int(stats["last_light"])
	light_changed.emit()


# ---------------------------------------------------------------- HP & kill

func heal_player(amount: int) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var h = p.get_node_or_null("Health")
	if h and h.has_method("heal") and h.is_alive():
		h.heal(amount)


func on_enemy_killed() -> void:
	kills += 1
	if _rng.randf() < float(stats["kill_heal_chance"]):
		heal_player(1)


# ---------------------------------------------------------------- akhir run

## Player mati. Kalau ada layar akhir run yang mendengarkan, biarkan dia yang
## memanggil restart_run(); kalau tidak ada, langsung mulai ulang.
func end_run() -> void:
	if run_ended.get_connections().is_empty():
		restart_run()
	else:
		run_ended.emit()


## Tinggalkan run dan kembali ke main menu (dari menu jeda / layar akhir run)
func quit_to_menu() -> void:
	reset_run()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)


func restart_run() -> void:
	reset_run()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", run_start_scene)
