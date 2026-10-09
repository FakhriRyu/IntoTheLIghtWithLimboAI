extends Node2D
## Pengujian kinerja AI musuh: Behavior Tree vs Finite State Machine vs hibrida.
##
## Untuk tiap varian musuh dan tiap jumlah musuh (N), scene ini:
##   1. memunculkan N musuh dan satu target pengganti player di arena datar,
##   2. menjalankan pemanasan (warmup) lalu mengukur selama `duration` detik,
##   3. mencatat waktu CPU tiap pembaruan AI, waktu frame, FPS, dan memori,
##   4. menulis hasilnya ke CSV di user://ai_benchmark/.
##
## Waktu AI diukur dengan mengubah BTPlayer / LimboHSM ke update_mode MANUAL,
## lalu memanggil update(delta) sendiri dari sini, diapit Time.get_ticks_usec().
## Yang terukur adalah seluruh kerja AI per tick: evaluasi pohon/state beserta
## aksi di dalam task/state (mis. mengatur velocity). Fisika (move_and_slide)
## dan animasi tidak termasuk, karena berjalan di luar AI pada kedua metode.
##
## Jalankan dari editor (F6 pada scene ini) atau tanpa jendela:
##   godot --headless res://Scenes/Benchmark/ai_benchmark.tscn -- \
##       --variants=goblin_fsm,wolf_bt --counts=1,10,50,100 --duration=10 --reps=3
## Lihat docs/pengujian-kinerja-ai.md untuk semua opsi.

const VARIANTS := {
	"wolf_bt": {
		"label": "Skull Wolf",
		"method": "BT",
		"scene": "res://Scenes/Enemy/SkullWolf/skull_wolf.tscn",
	},
	"wolf_fsm": {
		"label": "Skull Wolf",
		"method": "FSM",
		"scene": "res://Scenes/Enemy/SkullWolf/skull_wolf_fsm.tscn",
	},
	"goblin_fsm": {
		"label": "Goblin",
		"method": "FSM",
		"scene": "res://Scenes/Enemy/goblin/goblin.tscn",
	},
	"norcthex_p1": {
		"label": "Norc'Thex fase 1",
		"method": "FSM+BT",
		"scene": "res://Scenes/Enemy/NorcThex/norch_thex.tscn",
	},
	"norcthex_p2": {
		"label": "Norc'Thex fase 2",
		"method": "FSM+BT",
		"scene": "res://Scenes/Enemy/NorcThex/norch_thex.tscn",
	},
}

const ARENA_WIDTH := 1600.0
## Musuh dimunculkan merata selebar ini di tengah arena, dan target berpatroli
## di rentang yang sama, supaya hampir semua musuh terus terlibat (deteksi,
## kejar, serang) dan bukan diam menunggu.
const ENGAGE_WIDTH := 600.0
const OUT_DIR := "user://ai_benchmark"

## NPC yang dibahas skripsi. wolf_fsm tetap tersedia lewat --variants=wolf_fsm.
@export var variants: PackedStringArray = ["goblin_fsm", "wolf_bt", "norcthex_p1", "norcthex_p2"]
@export var counts: PackedInt32Array = [1, 10, 50, 100]
## Bos tidak masuk akal dimunculkan puluhan; jumlahnya dibatasi ini
@export var boss_max_count: int = 1
@export var warmup_sec: float = 2.0
@export var duration_sec: float = 10.0
@export var repetitions: int = 3
@export var rng_seed: int = 12345
## Simpan juga data mentah per frame (satu CSV per run)
@export var write_raw: bool = false
## Keluar otomatis setelah semua run selesai (selalu true saat --headless)
@export var quit_when_done: bool = false

var _agents: Array[Node] = []      # node musuh
var _drivers: Array[Node] = []     # BTPlayer / LimboHSM milik musuh tsb.
var _measuring: bool = false
var _phase_text: String = ""

# Sampel selama satu run
var _ai_samples_us: PackedFloat32Array = []       # per musuh per tick
var _ai_frame_us: PackedFloat32Array = []         # total semua musuh per tick
var _frame_ms: PackedFloat32Array = []            # delta _process
# Monitor bawaan Performance hanya diperbarui sekitar sekali per detik, jadi
# nilainya hanya dicatat saat berubah (bukan tiap frame) dan dilaporkan rata-ratanya
var _process_ms: PackedFloat32Array = []          # Performance.TIME_PROCESS
var _physics_ms: PackedFloat32Array = []          # Performance.TIME_PHYSICS_PROCESS
var _last_process_raw: float = 0.0
var _last_physics_raw: float = 0.0
## Rata-rata |velocity.x| musuh: bukti AI benar-benar aktif selama diukur
var _speed_sum: float = 0.0
var _speed_samples: int = 0

var _timer_overhead_us: float = 0.0
var _summary_rows: Array[String] = []
var _hud: Label
var _target: Node2D
## Anak scene milik arena; sisanya (musuh, panah, perangkap) dibuang tiap run
var _arena_nodes: Array[Node] = []


func _ready() -> void:
	_parse_cmdline()
	if DisplayServer.get_name() == "headless":
		quit_when_done = true

	# Jangan dibatasi vsync/max_fps supaya waktu frame mencerminkan beban
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_build_arena()
	_build_hud()
	_arena_nodes.assign(get_children())
	_timer_overhead_us = _measure_timer_overhead()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_run_all.call_deferred()


func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else "true"
		match key:
			"variants": variants = PackedStringArray(value.split(",", false))
			"counts": counts = PackedInt32Array(Array(value.split(",", false)).map(func(s): return int(s)))
			"boss-max": boss_max_count = int(value)
			"warmup": warmup_sec = float(value)
			"duration": duration_sec = float(value)
			"reps": repetitions = int(value)
			"seed": rng_seed = int(value)
			"raw": write_raw = value != "false"
			"quit": quit_when_done = value != "false"
			_: push_warning("ai_benchmark: opsi tidak dikenal '%s'" % arg)


# --- Arena ---

func _build_arena() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	_add_box(ground, Rect2(-40.0, 0.0, ARENA_WIDTH + 80.0, 40.0))       # lantai
	_add_box(ground, Rect2(-40.0, -400.0, 40.0, 400.0))                  # dinding kiri
	_add_box(ground, Rect2(ARENA_WIDTH, -400.0, 40.0, 400.0))            # dinding kanan

	_target = preload("res://Scripts/Benchmark/bench_target.gd").new()
	_target.name = "BenchTarget"
	_target.position = Vector2(ARENA_WIDTH * 0.5, -20.0)
	_target.min_x = (ARENA_WIDTH - ENGAGE_WIDTH) * 0.5
	_target.max_x = (ARENA_WIDTH + ENGAGE_WIDTH) * 0.5
	add_child(_target)

	var cam := Camera2D.new()
	cam.position = Vector2(ARENA_WIDTH * 0.5, -120.0)
	cam.zoom = Vector2(0.4, 0.4)
	add_child(cam)


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.25, 0.25, 0.3)
	body.add_child(vis)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	_hud.add_theme_font_size_override("font_size", 12)
	layer.add_child(_hud)


# --- Alur pengujian ---

func _run_all() -> void:
	var started := Time.get_datetime_string_from_system().replace(":", "-")
	print("== Pengujian kinerja AI | Godot %s | %s ==" % [Engine.get_version_info().string, OS.get_processor_name()])
	print("Overhead pengukur waktu: %.3f us per pasangan panggilan" % _timer_overhead_us)

	for variant in variants:
		if not VARIANTS.has(variant):
			push_error("ai_benchmark: varian '%s' tidak ada. Pilihan: %s" % [variant, ", ".join(VARIANTS.keys())])
			continue
		var info: Dictionary = VARIANTS[variant]
		var scene: PackedScene = load(info.scene)
		var is_boss: bool = info.method == "FSM+BT"
		var run_counts: Array[int] = []
		for c in counts:
			var n := mini(c, boss_max_count) if is_boss else c
			if n > 0 and not run_counts.has(n):
				run_counts.append(n)

		for n in run_counts:
			for rep in range(1, repetitions + 1):
				await _run_one(variant, info, scene, n, rep, started)

	_write_summary(started)
	_phase_text = "Selesai. Hasil: %s" % ProjectSettings.globalize_path(OUT_DIR)
	_update_hud()
	print(_phase_text)
	if quit_when_done:
		get_tree().quit()


func _run_one(variant: String, info: Dictionary, scene: PackedScene, n: int, rep: int, started: String) -> void:
	seed(rng_seed + rep)
	_target.position = Vector2(ARENA_WIDTH * 0.5, -20.0)
	_target.velocity = Vector2.ZERO

	# Garis dasar memori/objek sebelum musuh dimunculkan
	await _wait_physics_frames(10)
	var mem_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var obj_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	_spawn(scene, n)
	match variant:
		"norcthex_p1": await _setup_norcthex_p1()
		"norcthex_p2": await _setup_norcthex_p2()

	var mem_spawned := Performance.get_monitor(Performance.MEMORY_STATIC)
	var nodes_spawned := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var obj_spawned := Performance.get_monitor(Performance.OBJECT_COUNT)

	_phase_text = "%s (%s) N=%d ulangan %d: pemanasan" % [info.label, info.method, n, rep]
	await get_tree().create_timer(warmup_sec, true, true).timeout

	_clear_samples()
	_measuring = true
	_phase_text = "%s (%s) N=%d ulangan %d: mengukur" % [info.label, info.method, n, rep]
	await get_tree().create_timer(duration_sec, true, true).timeout
	_measuring = false

	var mem_peak := Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	var alive := _prune_agents()
	_despawn()

	var ai := _stats(_ai_samples_us)
	var ai_frame := _stats(_ai_frame_us)
	var frame := _stats(_frame_ms)
	var proc := _stats(_process_ms)
	var phys := _stats(_physics_ms)
	var row := {
		"variant": variant,
		"musuh": info.label,
		"metode": info.method,
		"n": n,
		"ulangan": rep,
		"tick_ai": _ai_frame_us.size(),
		"musuh_hidup_akhir": alive,
		"gerak_px_per_s_mean": _speed_sum / maxi(_speed_samples, 1),
		"ai_us_per_musuh_mean": ai.mean,
		"ai_us_per_musuh_median": ai.median,
		"ai_us_per_musuh_p95": ai.p95,
		"ai_us_per_musuh_p99": ai.p99,
		"ai_us_per_musuh_max": ai.max,
		"ai_ms_per_tick_total_mean": ai_frame.mean / 1000.0,
		"ai_ms_per_tick_total_p95": ai_frame.p95 / 1000.0,
		"frame_ms_mean": frame.mean,
		"frame_ms_p95": frame.p95,
		"frame_ms_max": frame.max,
		"process_ms_mean": proc.mean,
		"physics_ms_mean": phys.mean,
		"fps_mean": 1000.0 / frame.mean if frame.mean > 0.0 else 0.0,
		"fps_1pct_low": 1000.0 / frame.p99 if frame.p99 > 0.0 else 0.0,
		"memori_kb_per_musuh": (mem_spawned - mem_before) / 1024.0 / n,
		"memori_puncak_mb": mem_peak / 1048576.0,
		"node_per_musuh": (nodes_spawned - nodes_before) / n,
		"objek_per_musuh": (obj_spawned - obj_before) / n,
	}
	_summary_rows.append(_csv_line(row.values()))
	if _summary_rows.size() == 1:
		_summary_rows.push_front(_csv_line(row.keys()))

	print("%-18s %-6s N=%-4d #%d  AI %7.2f us/musuh (p95 %7.2f) | AI total %6.3f ms/tick | frame %6.2f ms | fisika %6.2f ms | %5.0f fps | %6.1f KB/musuh | gerak %5.1f px/s" % [
		info.label, info.method, n, rep, ai.mean, ai.p95, ai_frame.mean / 1000.0,
		frame.mean, phys.mean, row.fps_mean, row.memori_kb_per_musuh, row.gerak_px_per_s_mean])

	if write_raw:
		_write_raw(started, variant, n, rep)


func _spawn(scene: PackedScene, n: int) -> void:
	for i in n:
		var agent := scene.instantiate()
		var x := (ARENA_WIDTH - ENGAGE_WIDTH) * 0.5 + ENGAGE_WIDTH * (float(i) + 0.5) / n
		agent.position = Vector2(x, -40.0)
		var driver := _find_ai_driver(agent)
		if driver == null:
			push_error("ai_benchmark: %s tidak punya BTPlayer/LimboHSM" % scene.resource_path)
			agent.free()
			continue
		# Diatur sebelum masuk tree, jadi BTPlayer/LimboHSM tidak pernah
		# memperbarui dirinya sendiri; hanya _physics_process di bawah ini.
		driver.set("update_mode", 2)  # UpdateMode.MANUAL di BTPlayer & LimboHSM
		add_child(agent)
		_agents.append(agent)
		_drivers.append(driver)


func _find_ai_driver(agent: Node) -> Node:
	# Ambil yang paling luar: LimboHSM Norc'Thex sudah menjalankan BTState di dalamnya
	for child in agent.get_children():
		if child is BTPlayer or child is LimboHSM:
			return child
	return null


func _despawn() -> void:
	for agent in _agents:
		if is_instance_valid(agent):
			agent.queue_free()
	_agents.clear()
	_drivers.clear()
	# Sisa panah, perangkap, dan garis peringatan bos ikut dibersihkan
	for child in get_children():
		if not _arena_nodes.has(child):
			child.queue_free()


func _prune_agents() -> int:
	var count := 0
	for agent in _agents:
		if is_instance_valid(agent) and not agent.is_queued_for_deletion():
			count += 1
	return count


# --- Setup khusus varian ---

func _setup_norcthex_p1() -> void:
	# Pukulan pertama membangunkan bos dari Dormant langsung ke Phase1
	for agent in _agents:
		agent.health.take_damage(1)
	await _wait_physics_frames(2)


func _setup_norcthex_p2() -> void:
	await _setup_norcthex_p1()
	# Turunkan HP sampai lewat ambang fase 2 lewat jalur damage yang sama
	# dengan permainan, lalu tunggu animasi PhaseShift selesai
	for agent in _agents:
		var h = agent.health
		var target_hp := int(floor(h.max_health * agent.phase_two_threshold)) - 1
		agent.health.take_damage(h.current_health - target_hp)
	for i in 600:
		await get_tree().physics_frame
		var all_p2 := true
		for agent in _agents:
			if agent.hsm.get_active_state() != agent.phase2_state:
				all_p2 = false
		if all_p2:
			return
	push_warning("ai_benchmark: Norc'Thex belum masuk Phase2 setelah 10 detik")


# --- Pengukuran per frame ---

func _physics_process(delta: float) -> void:
	_tick_ai(delta)


func _tick_ai(delta: float) -> void:
	if _drivers.is_empty():
		return
	var total := 0.0
	for i in _drivers.size():
		var driver := _drivers[i]
		if not is_instance_valid(driver) or not driver.is_inside_tree():
			continue
		var t0 := Time.get_ticks_usec()
		driver.update(delta)
		var dt := maxf(float(Time.get_ticks_usec() - t0) - _timer_overhead_us, 0.0)
		total += dt
		if _measuring:
			_ai_samples_us.append(dt)
			var agent := _agents[i]
			if is_instance_valid(agent) and agent is CharacterBody2D:
				_speed_sum += absf(agent.velocity.x)
				_speed_samples += 1
	if _measuring:
		_ai_frame_us.append(total)
		var phys_raw := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		if phys_raw != _last_physics_raw:
			_last_physics_raw = phys_raw
			_physics_ms.append(phys_raw * 1000.0)


func _process(delta: float) -> void:
	if _measuring:
		_frame_ms.append(delta * 1000.0)
		var proc_raw := Performance.get_monitor(Performance.TIME_PROCESS)
		if proc_raw != _last_process_raw:
			_last_process_raw = proc_raw
			_process_ms.append(proc_raw * 1000.0)
	if Engine.get_process_frames() % 15 == 0:
		_update_hud()


func _update_hud() -> void:
	if _hud == null:
		return
	var text := _phase_text
	if _measuring and not _ai_frame_us.is_empty():
		var last := _ai_frame_us.size() - 1
		text += "\nAI: %.3f ms/tick untuk %d musuh | FPS %d" % [
			_ai_frame_us[last] / 1000.0, _drivers.size(), Engine.get_frames_per_second()]
	_hud.text = text


func _clear_samples() -> void:
	_ai_samples_us.clear()
	_ai_frame_us.clear()
	_frame_ms.clear()
	_process_ms.clear()
	_physics_ms.clear()
	# Nilai monitor yang sedang tampil masih milik detik sebelum pengukuran
	# (pemanasan/spawn); hanya pembaruan setelah ini yang dihitung
	_last_process_raw = Performance.get_monitor(Performance.TIME_PROCESS)
	_last_physics_raw = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_speed_sum = 0.0
	_speed_samples = 0


func _wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _measure_timer_overhead() -> float:
	var loops := 20000
	var t0 := Time.get_ticks_usec()
	for i in loops:
		var a := Time.get_ticks_usec()
		var b := Time.get_ticks_usec()
	return float(Time.get_ticks_usec() - t0) / loops


# --- Statistik & keluaran ---

func _stats(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "min": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in sorted:
		sum += v
	return {
		"mean": sum / sorted.size(),
		"median": _percentile(sorted, 0.5),
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[sorted.size() - 1],
		"min": sorted[0],
	}


func _percentile(sorted: PackedFloat32Array, q: float) -> float:
	var idx := clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[idx]


func _csv_line(values: Array) -> String:
	var cells: PackedStringArray = []
	for v in values:
		if v is float:
			cells.append("%.4f" % v)
		else:
			var s := str(v)
			if s.contains(",") or s.contains("\""):
				s = "\"%s\"" % s.replace("\"", "\"\"")
			cells.append(s)
	return ",".join(cells)


func _write_summary(started: String) -> void:
	if _summary_rows.is_empty():
		return
	var path := "%s/ringkasan_%s.csv" % [OUT_DIR, started]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ai_benchmark: gagal menulis %s" % path)
		return
	f.store_line("# Godot %s | CPU %s | OS %s | build %s | overhead timer %.3f us" % [
		Engine.get_version_info().string, OS.get_processor_name(), OS.get_name(),
		"debug" if OS.is_debug_build() else "release", _timer_overhead_us])
	for line in _summary_rows:
		f.store_line(line)
	f.close()
	print("Ringkasan ditulis ke ", ProjectSettings.globalize_path(path))


func _write_raw(started: String, variant: String, n: int, rep: int) -> void:
	var path := "%s/mentah_%s_%s_n%d_r%d.csv" % [OUT_DIR, started, variant, n, rep]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("tick,ai_total_us")
	for i in _ai_frame_us.size():
		f.store_line("%d,%.1f" % [i, _ai_frame_us[i]])
	f.close()
