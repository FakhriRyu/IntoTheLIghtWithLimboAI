extends Node2D
## Uji perilaku NPC otomatis (observasi perilaku Bab 4.4.2).
## Setiap skenario membangun arena baru, memunculkan satu NPC dan target pengganti
## player, mengatur kondisi, lalu mencatat state FSM / cabang BT yang aktif setiap
## physics frame. Hasil ditulis ke user://npc_behavior_test/hasil_<waktu>.csv.
##
## Jalankan: godot --headless --path . res://Scenes/Tests/npc_behavior_test.tscn

const GOBLIN := preload("res://Scenes/Enemy/goblin/goblin.tscn")
const WOLF := preload("res://Scenes/Enemy/SkullWolf/skull_wolf.tscn")
const BOSS := preload("res://Scenes/Enemy/NorcThex/norch_thex.tscn")
const TARGET := preload("res://Scripts/Tests/test_target.gd")

const ARENA_WIDTH := 1600.0

var results: Array[Dictionary] = []
var target: CharacterBody2D
var npc: Node2D
var _arena: Array[Node] = []
## Jejak state/cabang per frame selama skenario berjalan
var trace: PackedStringArray = []


func _ready() -> void:
	await _run_all()
	_write_results()
	get_tree().quit()


func _run_all() -> void:
	await _goblin_tests()
	await _wolf_tests()
	await _boss_tests()


# ---------------------------------------------------------------- arena

## opts: gap (Vector2 x0,x1), platform (Rect2), wall (Rect2)
func _reset(opts: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_arena.clear()
	trace.clear()

	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	if opts.has("gap"):
		var g: Vector2 = opts.gap
		_box(ground, Rect2(-40.0, 0.0, g.x + 40.0, 40.0))
		_box(ground, Rect2(g.y, 0.0, ARENA_WIDTH + 40.0 - g.y, 40.0))
	else:
		_box(ground, Rect2(-40.0, 0.0, ARENA_WIDTH + 80.0, 40.0))
	_box(ground, Rect2(-40.0, -600.0, 40.0, 600.0))
	_box(ground, Rect2(ARENA_WIDTH, -600.0, 40.0, 600.0))
	if opts.has("platform"):
		_box(ground, opts.platform)
	if opts.has("wall"):
		_box(ground, opts.wall)

	target = TARGET.new()
	target.name = "TestTarget"
	add_child(target)
	target.place(Vector2(ARENA_WIDTH - 60.0, -20.0))


func _box(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)


func _spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var n := scene.instantiate() as Node2D
	n.position = pos
	add_child(n)
	npc = n
	await frames(10)   # biarkan jatuh ke lantai
	return n


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		_sample()


func seconds(s: float) -> void:
	await frames(int(round(s * 60.0)))


## Tunggu sampai cond() benar, paling lama max_s detik. Mengembalikan detik yang dibutuhkan, atau -1.
func wait_until(cond: Callable, max_s: float) -> float:
	var n := int(max_s * 60.0)
	for i in n:
		await get_tree().physics_frame
		_sample()
		if cond.call():
			return (i + 1) / 60.0
	return -1.0


# ---------------------------------------------------------------- observasi

func _sample() -> void:
	trace.append(observe())


func observe() -> String:
	if not is_instance_valid(npc) or npc.is_queued_for_deletion():
		return "<freed>"
	if npc.has_node("LimboHSM"):
		var hsm: LimboHSM = npc.get_node("LimboHSM")
		var st := hsm.get_active_state()
		if st == null:
			return "<none>"
		var s := String(st.name)
		if st is BTState and st.get_bt_instance() != null:
			var b := _branch(st.get_bt_instance().get_root_task())
			if b != "":
				s += "/" + b
		return s
	if npc.has_node("BTPlayer"):
		var bp: BTPlayer = npc.get_node("BTPlayer")
		if not bp.active:
			return "<bt-off>"
		if bp.get_bt_instance() == null:
			return "<bt-none>"
		return _branch(bp.get_bt_instance().get_root_task())
	return "?"


## Cabang (anak langsung root) yang sedang RUNNING; untuk cabang komposit
## yang juga punya anak bernama (mis. Attack fase 2) ditambah sub-cabangnya.
func _branch(root: BTTask) -> String:
	if root == null:
		return ""
	for i in root.get_child_count():
		var c := root.get_child(i)
		if c.get_status() == BT.RUNNING:
			var name := c.get_task_name()
			var sub := _named_running(c)
			return name + ("/" + sub if sub != "" else "")
	return ""


func _named_running(task: BTTask) -> String:
	for i in task.get_child_count():
		var c := task.get_child(i)
		if c.get_status() == BT.RUNNING:
			if c is BTComposite and c.get_child_count() > 0 and c.custom_name != "":
				var deeper := _named_running(c)
				if deeper != "" and _is_branch_name(deeper):
					return deeper
			if c is BTSelector or c is BTProbabilitySelector:
				for j in c.get_child_count():
					var g := c.get_child(j)
					if g.get_status() == BT.RUNNING and g.custom_name != "":
						return g.custom_name
	return ""


func _is_branch_name(s: String) -> bool:
	return s in ["Volley", "Aimed Shot", "Trap", "Reload"]


## Urutan state/cabang unik berurutan (tanpa pengulangan berturut-turut)
func sequence(from: int = 0) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(from, trace.size()):
		var s := trace[i]
		if s == "":
			continue
		if out.is_empty() or out[out.size() - 1] != s:
			out.append(s)
	return out


func seen(prefix: String, from: int = 0) -> bool:
	for i in range(from, trace.size()):
		if trace[i].begins_with(prefix):
			return true
	return false


func count_nodes(klass: String) -> int:
	var n := 0
	for c in get_children():
		if c.get_class() == klass or (c.get_script() and c.get_script().get_global_name() == klass):
			n += 1
	return n


func has_child_script(node: Node, klass: String) -> bool:
	for c in node.get_children():
		if c.get_script() and c.get_script().get_global_name() == klass:
			return true
	return false


func record(npc_name: String, no: int, kondisi: String, harapan: String, observasi: String, lulus: bool) -> void:
	results.append({"npc": npc_name, "no": no, "kondisi": kondisi, "harapan": harapan, "observasi": observasi, "lulus": lulus})
	print("[%s] %s #%d %s | %s" % ["LULUS" if lulus else "GAGAL", npc_name, no, kondisi, observasi])


func short(seq: PackedStringArray, max_items: int = 8) -> String:
	var s := seq.slice(0, max_items)
	var txt := " → ".join(s)
	if seq.size() > max_items:
		txt += " → …"
	return txt


# ---------------------------------------------------------------- Goblin (FSM)

func _goblin_tests() -> void:
	var G := "Goblin"
	var floor_y := 0.0

	# 1. Pemain di luar area deteksi: Idle lalu Patrol
	await _reset()
	await _spawn(GOBLIN, Vector2(400, -30))
	target.place(Vector2(1300, -20))
	await seconds(6.0)
	var seq := sequence()
	record(G, 1, "Pemain di luar area deteksi", "Idle → Patrol",
		"Urutan state: %s" % short(seq), seen("Idle") and seen("Patrol") and not seen("Chase"))

	# 2. Patroli dekat tepi platform: berbalik, tidak jatuh
	await _reset({"gap": Vector2(460, 700)})
	await _spawn(GOBLIN, Vector2(420, -30))
	target.place(Vector2(1300, -20))
	var max_y := -INF
	var min_x := INF
	var max_x := -INF
	for i in 12 * 60:
		await frames(1)
		max_y = maxf(max_y, npc.global_position.y)
		min_x = minf(min_x, npc.global_position.x)
		max_x = maxf(max_x, npc.global_position.x)
	record(G, 2, "Goblin berpatroli dekat tepi platform (tepi di x=460)", "Berbalik arah, tidak jatuh",
		"Rentang x patroli %.0f–%.0f, y terendah %.1f (lantai y=0), patroli terlihat: %s" % [min_x, max_x, max_y, seen("Patrol")],
		seen("Patrol") and max_y < 5.0 and max_x < 460.0 + 16.0)

	# 3. Pemain masuk area deteksi: Chase
	await _reset()
	await _spawn(GOBLIN, Vector2(400, -30))
	target.place(Vector2(1300, -20))
	await seconds(1.0)
	target.place(Vector2(470, -20))
	var t := await wait_until(func(): return trace[trace.size() - 1].begins_with("Chase"), 2.0)
	record(G, 3, "Pemain memasuki area deteksi (70 px)", "Mengejar pemain (→ Chase)",
		("Masuk Chase setelah %.2f detik" % t) if t >= 0 else "Tidak masuk Chase dalam 2 detik", t >= 0)

	# 4. Pemain di lantai lain (platform 50 px lebih tinggi)
	await _reset({"platform": Rect2(560, -50, 200, 50)})
	await _spawn(GOBLIN, Vector2(420, -30))
	target.place(Vector2(1300, -20))
	await seconds(0.5)
	target.place(Vector2(600, -70))
	await seconds(4.0)
	var gx := npc.global_position.x
	var gy := npc.global_position.y
	await seconds(1.0)
	var moved := absf(npc.global_position.x - gx)
	var last := trace[trace.size() - 1]
	record(G, 4, "Pemain berdiri di platform 50 px lebih tinggi", "Berhenti di bawah pemain, tidak mengejar buta",
		"State akhir %s, posisi x=%.0f y=%.0f, bergerak %.1f px dalam 1 detik terakhir" % [last, npc.global_position.x, gy, moved],
		last.begins_with("Chase") and moved < 2.0 and gy > -5.0)

	# 5. Pemain di jangkauan serang: zona merah lalu ayunan
	await _reset()
	await _spawn(GOBLIN, Vector2(400, -30))
	target.place(Vector2(1300, -20))
	await seconds(0.5)
	target.place(Vector2(425, -20))
	var warned := false
	var hit_on := false
	var t_attack := -1.0
	var t_swing := -1.0
	for i in 3 * 60:
		await frames(1)
		if t_attack < 0 and trace[trace.size() - 1] == "Attack":
			t_attack = i / 60.0
		if has_child_script(npc, "MeleeWarning"):
			warned = true
		if npc.hitbox.monitoring and t_swing < 0:
			hit_on = true
			t_swing = i / 60.0
	record(G, 5, "Pemain masuk jangkauan serang (25 px)", "Zona merah muncul, lalu mengayun senjata (Chase → Attack)",
		"Attack pada %.2f dtk, zona peringatan: %s, hitbox aktif pada %.2f dtk (jeda peringatan %.2f dtk)" % [t_attack, "ya" if warned else "tidak", t_swing, t_swing - t_attack],
		t_attack >= 0 and warned and hit_on and t_swing > t_attack)

	# 6. Pemain keluar area deteksi > 1,5 detik
	await _reset()
	await _spawn(GOBLIN, Vector2(400, -30))
	target.place(Vector2(480, -20))
	await wait_until(func(): return trace[trace.size() - 1].begins_with("Chase"), 2.0)
	target.place(Vector2(1300, -20))
	var t_lost := await wait_until(func(): return trace[trace.size() - 1] in ["Idle", "Patrol"], 5.0)
	record(G, 6, "Pemain keluar area deteksi saat dikejar", "Berhenti mengejar setelah ±1,5 detik (Chase → Idle)",
		("Kembali ke Idle setelah %.2f detik" % t_lost) if t_lost >= 0 else "Tetap mengejar lebih dari 5 detik",
		t_lost >= 1.4 and t_lost <= 1.8)

	# 7. Goblin dipukul pemain (dari belakang)
	await _reset()
	await _spawn(GOBLIN, Vector2(400, -30))
	target.place(Vector2(1300, -20))
	await seconds(0.5)
	target.place(Vector2(380, -20))   # di belakang? arah hadap awal kanan, jadi kiri = belakang
	var x0 := npc.global_position.x
	var from := trace.size()
	npc.health.take_damage(1, target.global_position)
	await seconds(2.5)
	seq = sequence(from)
	record(G, 7, "Goblin dipukul pemain dari belakang", "Terdorong mundur, lalu menyerang balik/mengejar (Hurt → Attack/Chase)",
		"Urutan state: %s; HP %d/5" % [short(seq), npc.health.current_health],
		seq.size() >= 2 and seq[0] == "Hurt" and (seq[1] == "Attack" or seq[1] == "Chase"))

	# 8. HP Goblin habis
	await _reset()
	await _spawn(GOBLIN, Vector2(400, -30))
	target.place(Vector2(440, -20))
	await seconds(0.5)
	var g := npc
	g.health.take_damage(5, target.global_position)
	await frames(3)
	var dead_state := trace[trace.size() - 1]
	var hb_off: bool = not g.hitbox.monitoring
	var t_free := await wait_until(func(): return not is_instance_valid(g), 5.0)
	record(G, 8, "HP Goblin habis", "Animasi mati, tidak lagi melukai (→ Dead)",
		"State %s, hitbox mati: %s, node dihapus setelah %.2f dtk" % [dead_state, "ya" if hb_off else "tidak", t_free],
		dead_state == "Dead" and hb_off and t_free > 0)


# ---------------------------------------------------------------- Skull Wolf (BT)

func _wolf_tests() -> void:
	var W := "Skull Wolf"

	# 1. Pemain di luar area deteksi
	await _reset()
	await _spawn(WOLF, Vector2(400, -30))
	target.place(Vector2(1300, -20))
	await seconds(3.0)
	var seq := sequence()
	record(W, 1, "Pemain di luar area deteksi", "Diam (Chill)", "Cabang: %s" % short(seq),
		seq.size() > 0 and Array(seq).all(func(s): return s == "Chill"))

	# 2. Pemain di area deteksi, jarak > 100 px
	await _reset()
	await _spawn(WOLF, Vector2(400, -30))
	target.place(Vector2(515, -20))
	var x0 := npc.global_position.x
	var t := await wait_until(func(): return trace[trace.size() - 1] == "Chase", 1.0)
	await seconds(0.5)
	record(W, 2, "Pemain di area deteksi, jarak 115 px", "Mengejar pemain (Chase)",
		("Chase setelah %.2f dtk, bergerak %.1f px ke arah pemain" % [t, npc.global_position.x - x0]) if t >= 0 else "Cabang: %s" % short(sequence()),
		t >= 0 and npc.global_position.x > x0)

	# 3. Pemain ≤ 100 px, cooldown selesai: peringatan lalu terkaman
	await _reset()
	await _spawn(WOLF, Vector2(400, -30))
	target.place(Vector2(480, -20))
	var t_atk := await wait_until(func(): return trace[trace.size() - 1] == "Attack", 1.0)
	var warned := false
	var max_v := 0.0
	var t_hit := -1.0
	for i in 2 * 60:
		await frames(1)
		if has_child_script(npc, "NorcThexArrowWarning"):
			warned = true
		max_v = maxf(max_v, absf(npc.velocity.x))
		if t_hit < 0 and npc.hitbox.active:
			t_hit = i / 60.0
	record(W, 3, "Pemain di area deteksi, jarak 80 px, cooldown selesai", "Garis peringatan muncul, lalu menerkam (Attack)",
		"Attack pada %.2f dtk, garis peringatan: %s, hitbox aktif %.2f dtk setelahnya, kecepatan terkaman maks %.0f px/dtk" % [t_atk, "ya" if warned else "tidak", t_hit, max_v],
		t_atk >= 0 and warned and t_hit >= 0.7 and max_v >= 300.0)

	# 4. Pemain dekat, terkaman masih cooldown: Hold
	await seconds(1.0)   # recover selesai
	target.place(Vector2(npc.global_position.x + 40.0, -20))
	var from := trace.size()
	await seconds(1.0)
	seq = sequence(from)
	record(W, 4, "Pemain dekat (40 px), terkaman masih cooldown", "Diam menghadap pemain (Hold)",
		"Cabang setelah terkaman: %s" % short(seq), seen("Hold", from))

	# 5. Pemain menghindar saat Charge: arah terkaman terkunci
	await _reset()
	await _spawn(WOLF, Vector2(400, -30))
	target.place(Vector2(480, -20))
	await wait_until(func(): return trace[trace.size() - 1] == "Attack", 1.0)
	target.place(Vector2(330, -20))   # pindah ke sisi kiri selama charge
	var lunge_dir := 0.0
	for i in 90:
		await frames(1)
		if lunge_dir == 0.0 and absf(npc.velocity.x) > 200.0:
			lunge_dir = signf(npc.velocity.x)
	record(W, 5, "Pemain pindah ke sisi lain saat Charge", "Terkaman tetap lurus searah garis, tidak berbelok",
		"Arah terkaman %s (pemain kini di kiri)" % ("kanan" if lunge_dir > 0 else ("kiri" if lunge_dir < 0 else "tidak terkam")),
		lunge_dir > 0)

	# 6. Terkaman mengarah ke tepi platform
	await _reset({"gap": Vector2(500, 800)})
	await _spawn(WOLF, Vector2(420, -30))
	target.place(Vector2(1300, -20))
	await seconds(0.3)
	target.place(Vector2(505, -20))   # di tepi, wolf akan menerkam ke arah jurang
	await wait_until(func(): return trace[trace.size() - 1] == "Attack", 1.0)
	target.place(Vector2(1300, -20))
	var max_y := -INF
	var max_x := -INF
	for i in 2 * 60:
		await frames(1)
		max_y = maxf(max_y, npc.global_position.y)
		max_x = maxf(max_x, npc.global_position.x)
	record(W, 6, "Terkaman mengarah ke tepi platform (tepi di x=500)", "Berhenti di tepi, tidak jatuh",
		"x terjauh %.0f, y terendah %.1f (lantai y=0)" % [max_x, max_y], max_y < 5.0 and max_x <= 505.0)

	# 7. Dipukul saat Charge
	await _reset()
	await _spawn(WOLF, Vector2(400, -30))
	target.place(Vector2(480, -20))
	await wait_until(func(): return trace[trace.size() - 1] == "Attack", 1.0)
	await frames(10)
	npc.health.take_damage(1)
	await frames(2)
	var warn_gone := not has_child_script(npc, "NorcThexArrowWarning")
	var bt_off := trace[trace.size() - 1] == "<bt-off>"
	var hb_off: bool = not npc.hitbox.active
	from = trace.size()
	var t_back := await wait_until(func(): return not trace[trace.size() - 1].begins_with("<"), 3.0)
	record(W, 7, "Skull Wolf dipukul saat Charge", "Terkaman batal, knockback, BT dijalankan ulang",
		"Garis peringatan hilang: %s, hitbox mati: %s, BTPlayer berhenti: %s, BT aktif lagi setelah %.2f dtk (%s)" % [
			"ya" if warn_gone else "tidak", "ya" if hb_off else "tidak", "ya" if bt_off else "tidak", t_back, trace[trace.size() - 1]],
		warn_gone and hb_off and bt_off and t_back > 0)

	# 8. HP ≤ 30%: kabur
	await _reset()
	await _spawn(WOLF, Vector2(600, -30))
	target.place(Vector2(1300, -20))
	await seconds(0.3)
	npc.health.take_damage(4)   # HP 1/5 = 20%
	await wait_until(func(): return not trace[trace.size() - 1].begins_with("<"), 3.0)
	target.place(Vector2(npc.global_position.x + 70.0, -20))
	x0 = npc.global_position.x
	from = trace.size()
	var t_flee := await wait_until(func(): return trace[trace.size() - 1] == "Flee", 1.0)
	var flee_start := trace.size()
	await wait_until(func(): return trace[trace.size() - 1] != "Flee", 3.0)
	var flee_frames := trace.size() - flee_start
	record(W, 8, "HP Skull Wolf 1/5 (20%) dan pemain mendekat", "Kabur menjauhi pemain selama 2 detik (Flee)",
		"Flee setelah %.2f dtk, berlangsung %.2f dtk, berpindah %.0f px menjauhi pemain" % [t_flee, flee_frames / 60.0, x0 - npc.global_position.x],
		t_flee >= 0 and absf(flee_frames / 60.0 - 2.0) < 0.2 and npc.global_position.x < x0)

	# 9. HP masih rendah, cooldown kabur 5 detik belum selesai
	target.place(Vector2(npc.global_position.x + 80.0, -20))
	from = trace.size()
	await seconds(2.0)
	seq = sequence(from)
	record(W, 9, "HP masih rendah, cooldown kabur (5 dtk) belum selesai", "Kembali menyerang/mengejar, tidak kabur",
		"Cabang 2 detik berikutnya: %s" % short(seq),
		not seen("Flee", from) and (seen("Attack", from) or seen("Chase", from)))

	# 10. HP habis
	var w := npc
	w.health.take_damage(5)
	await frames(2)
	var off := trace[trace.size() - 1] == "<bt-off>"
	var t_free := await wait_until(func(): return not is_instance_valid(w), 5.0)
	record(W, 10, "HP Skull Wolf habis", "Animasi mati, BT berhenti",
		"BTPlayer berhenti: %s, node dihapus setelah %.2f dtk" % ["ya" if off else "tidak", t_free], off and t_free > 0)


# ---------------------------------------------------------------- Norc'Thex (hibrida)

func _arrows() -> int:
	var n := 0
	for c in get_children():
		if c is NorcThexArrow:
			n += 1
	return n


func _traps() -> int:
	var n := 0
	for c in get_children():
		if c is NorcThexTrap:
			n += 1
	return n


func _boss_tests() -> void:
	var B := "Norc'Thex"

	# 1. Pemain belum masuk arena
	await _reset()
	await _spawn(BOSS, Vector2(800, -40))
	target.place(Vector2(1580, -20))
	# Arena bos 1150 px, jadi letakkan di luar dengan menggeser bos
	npc.global_position = Vector2(200, -40)
	await seconds(3.0)
	var seq := sequence()
	record(B, 1, "Pemain belum masuk arena", "Bos diam (Dormant)", "State: %s" % short(seq),
		Array(seq).all(func(s): return s == "Dormant"))

	# 2. Pemain masuk arena: meraung lalu Phase1
	target.place(Vector2(600, -20))
	var t := await wait_until(func(): return trace[trace.size() - 1].begins_with("Phase1"), 5.0)
	record(B, 2, "Pemain masuk arena (400 px dari bos)", "Bos meraung lalu mulai bertarung (Dormant → Phase1)",
		("Masuk Phase1 setelah %.2f dtk (raungan)" % t) if t >= 0 else "Tetap di %s" % trace[trace.size() - 1], t >= 0)

	# 3. Pemain jauh, jalur tembak bersih: Aimed Shot
	await _reset()
	await _spawn(BOSS, Vector2(400, -40))
	target.place(Vector2(700, -20))
	npc.health.take_damage(1)   # bangunkan
	var from := trace.size()
	var t_shot := await wait_until(func(): return _arrows() > 0, 6.0)
	record(B, 3, "Pemain berjarak 300 px, jalur tembak bersih", "Garis peringatan lalu panah (Phase1/Aimed Shot)",
		"Cabang: %s; panah muncul setelah %.2f dtk" % [short(sequence(from)), t_shot], seen("Phase1/Aimed Shot", from) and t_shot > 0)

	# 4. Pemain pada jarak menengah: Trap
	await _reset()
	await _spawn(BOSS, Vector2(400, -40))
	target.place(Vector2(520, -20))
	npc.health.take_damage(1)
	from = trace.size()
	var t_trap := await wait_until(func(): return _traps() > 0, 4.0)
	await frames(2)
	record(B, 4, "Pemain berjarak 120 px", "Perangkap muncul di bawah pemain (Phase1/Trap)",
		"Cabang: %s; %d perangkap muncul setelah %.2f dtk" % [short(sequence(from)), _traps(), t_trap],
		seen("Phase1/Trap", from) and _traps() == 3)

	# 5. Jalur tembak terhalang dinding
	await _reset({"wall": Rect2(560, -200, 20, 200)})
	await _spawn(BOSS, Vector2(400, -40))
	target.place(Vector2(800, -20))
	npc.health.take_damage(1)
	from = trace.size()
	var shots_before_move := -1
	var bx := npc.global_position.x
	await seconds(4.0)
	seq = sequence(from)
	var hit_wall_arrows := _arrows()
	record(B, 5, "Dinding di antara bos dan pemain (pemain 400 px)", "Tidak menembak dinding; berpindah posisi atau memasang perangkap",
		"Cabang: %s; posisi bos x %.0f → %.0f" % [short(seq), bx, npc.global_position.x],
		(seen("Phase1/Reposition", from) or seen("Phase1/Trap (No Line)", from)) and not seen("Phase1/Aimed Shot", from))

	# 6. Pemain mendekat ≤ 130 px (dan < 60 px agar Trap tidak berlaku)
	await _reset()
	await _spawn(BOSS, Vector2(800, -40))
	target.place(Vector2(845, -20))
	npc.health.take_damage(1)
	await wait_until(func(): return trace[trace.size() - 1].begins_with("Phase1"), 4.0)
	from = trace.size()
	bx = npc.global_position.x
	var t_blink := await wait_until(func(): return seen("Phase1/Keep Distance", from), 3.0)
	await wait_until(func(): return not trace[trace.size() - 1].begins_with("Phase1/Keep Distance"), 3.0)
	var d_after := absf(npc.global_position.x - target.global_position.x)
	record(B, 6, "Pemain mendekat 45 px", "Bos berteleportasi menjauh (Phase1/Keep Distance)",
		"Keep Distance setelah %.2f dtk, jarak ke pemain 45 → %.0f px" % [t_blink, d_after],
		t_blink >= 0 and d_after > 130.0)

	# 7. Dipukul 3 kali beruntun: Stagger lalu Panic Blink
	await _reset()
	await _spawn(BOSS, Vector2(800, -40))
	target.place(Vector2(1300, -20))
	npc.health.take_damage(1)
	await wait_until(func(): return trace[trace.size() - 1].begins_with("Phase1") and not npc.is_uninterruptible, 4.0)
	from = trace.size()
	for k in 3:
		npc.health.take_damage(1)
		await frames(12)
	await seconds(3.0)
	seq = sequence(from)
	var stag_idx := Array(seq).find("Stagger")
	var panic_after := stag_idx >= 0 and stag_idx + 1 < seq.size() and seq[stag_idx + 1].begins_with("Phase1/Panic Blink")
	record(B, 7, "Bos dipukul 3 kali dalam 0,4 detik", "Tersentak lalu langsung teleport (Stagger → Phase1/Panic Blink)",
		"Urutan: %s" % short(seq), stag_idx >= 0 and panic_after)

	# 8. Dipukul saat teleport
	await _reset()
	await _spawn(BOSS, Vector2(800, -40))
	target.place(Vector2(845, -20))
	npc.health.take_damage(1)
	var t_un := await wait_until(func(): return npc.is_uninterruptible, 5.0)
	var hp0: int = npc.health.current_health
	var st0 := trace[trace.size() - 1]
	from = trace.size()
	for k in 3:
		npc.health.take_damage(1)
		await frames(3)
	var hp1: int = npc.health.current_health
	await frames(3)
	record(B, 8, "Bos dipukul 3 kali saat sedang teleport", "HP berkurang tetapi teleport tidak terhenti",
		"Cabang saat dipukul %s, HP %d → %d, Stagger terjadi: %s" % [st0, hp0, hp1, "ya" if seen("Stagger", from) else "tidak"],
		t_un >= 0 and hp1 == hp0 - 3 and not seen("Stagger", from))

	# 9. HP ≤ 50%: PhaseShift → Phase2, 5 perangkap
	await _reset()
	await _spawn(BOSS, Vector2(800, -40))
	target.place(Vector2(1300, -20))
	npc.health.take_damage(1)
	await wait_until(func(): return trace[trace.size() - 1].begins_with("Phase1") and not npc.is_uninterruptible, 4.0)
	from = trace.size()
	var traps0 := _traps()
	npc.health.take_damage(npc.health.current_health - 27)   # 27/56 < 50%
	var t_p2 := await wait_until(func(): return trace[trace.size() - 1].begins_with("Phase2"), 6.0)
	seq = sequence(from)
	var tint: Color = npc.base_modulate
	record(B, 9, "HP bos turun ke 27/56 (48%)", "Meraung, berubah warna, memasang 5 perangkap (Phase1 → PhaseShift → Phase2)",
		"Urutan: %s; perangkap dipasang: %d; warna dasar %s; Phase2 setelah %.2f dtk" % [short(seq, 3), _traps() - traps0, tint, t_p2],
		seen("PhaseShift", from) and t_p2 > 0 and (_traps() - traps0) == 5 and tint != Color.WHITE)

	# 10 & 11. Fase 2: amati 40 detik
	target.move_speed = 60.0
	from = trace.size()
	var counts := {}
	var ambush_ok := 0
	var ambush_n := 0
	var prev := ""
	for i in 40 * 60:
		# pemain mondar-mandir di tengah arena
		if target.global_position.x > 1100.0:
			target.move_dir = -1.0
		elif target.global_position.x < 500.0 or target.move_dir == 0.0:
			target.move_dir = 1.0
		await frames(1)
		var cur := trace[trace.size() - 1]
		if cur != prev:
			counts[cur] = counts.get(cur, 0) + 1
			if prev.begins_with("Phase2/Blink Ambush") and not cur.begins_with("Phase2/Blink Ambush"):
				pass
			prev = cur
		if not is_instance_valid(npc):
			break
	var ambush := 0
	var attack_sub := {"Volley": 0, "Aimed Shot": 0, "Trap": 0}
	for k in counts.keys():
		if String(k).begins_with("Phase2/Blink Ambush"):
			ambush += counts[k]
		for s in attack_sub.keys():
			if String(k) == "Phase2/Attack/" + s:
				attack_sub[s] += counts[k]
	record(B, 10, "Fase 2, cooldown ambush selesai (diamati 40 dtk)", "Teleport ke dekat/belakang pemain lalu langsung menembak (Phase2/Blink Ambush)",
		"Blink Ambush terjadi %d kali" % ambush, ambush > 0)
	record(B, 11, "Fase 2, pemain di arena (diamati 40 dtk)", "Jurus dipilih acak antara Volley, Aimed Shot, Trap (Phase2/Attack)",
		"Volley %d kali, Aimed Shot %d kali, Trap %d kali" % [attack_sub["Volley"], attack_sub["Aimed Shot"], attack_sub["Trap"]],
		attack_sub.values().filter(func(v): return v > 0).size() >= 2)
	print("Fase 2 cabang: ", counts)

	# 12. HP habis
	var b := npc
	b.health.take_damage(b.health.current_health)
	await frames(2)
	var st := trace[trace.size() - 1]
	var hurt_off: bool = not b.hurt_box.monitoring
	var t_free := await wait_until(func(): return not is_instance_valid(b), 6.0)
	record(B, 12, "HP bos habis", "Animasi mati, bos tidak bisa dipukul lagi (→ Dead)",
		"State %s, hurtbox mati: %s, node dihapus setelah %.2f dtk" % [st, "ya" if hurt_off else "tidak", t_free],
		st == "Dead" and hurt_off and t_free > 0)


# ---------------------------------------------------------------- output

func _write_results() -> void:
	DirAccess.make_dir_recursive_absolute("user://npc_behavior_test")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://npc_behavior_test/hasil_%s.csv" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("npc,no,kondisi,harapan,observasi,status")
	var passed := 0
	for r in results:
		if r.lulus:
			passed += 1
		var cells := [r.npc, str(r.no), r.kondisi, r.harapan, r.observasi, "Sesuai" if r.lulus else "Tidak sesuai"]
		f.store_line(",".join(cells.map(func(c): return "\"" + String(c).replace("\"", "\"\"") + "\"")))
	f.close()
	print("Hasil: %d/%d skenario sesuai. File: %s" % [passed, results.size(), ProjectSettings.globalize_path(path)])
