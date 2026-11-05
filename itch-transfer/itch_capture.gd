extends SceneTree
## Pengambil screenshot untuk halaman itch.io (HUD tetap tampil, tanpa tombol sentuh).
## Jalankan dari folder proyek Godot (bukan headless, perlu jendela):
##   godot --path . --resolution 1280x720 --audio-driver Dummy -s tools/itch_capture.gd -- <folder_output>
## Menghasilkan 6 PNG: 01_goblin, 02_wolf, 03_boss_aimed, 04_boss_trap, 05_boss_volley, 06_levelup.
var outdir := ""
var lvl: Node
var player: Node2D
var npc: Node2D

func _initialize():
	# Autoload baru _ready setelah _initialize; RunState mereset run di sana.
	await process_frame
	var a := OS.get_cmdline_user_args()
	outdir = a[0] if a.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(outdir)
	# Hanya di memori, jangan lewat setter: setter menyimpan ke file pengaturan pemain.
	var settings = root.get_node("Settings")
	settings.touch_controls = false
	settings.tips_seen = true # layar tips menjeda game dan menutupi tangkapan
	# Jendela yang tertutup jendela lain berhenti digambar, jadi shot() bisa tertahan.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	create_timer(170.0, true, false, true).timeout.connect(_on_watchdog)
	physics_frame.connect(_keep_alive)
	for sc in ["goblin", "wolf", "boss", "levelup"]:
		await call(sc)
		await _unload()
	quit()

# ------------------------------------------------------------ util
func shot(name: String) -> void:
	await process_frame
	await process_frame
	var drawn := [false]
	var on_drawn := func(): drawn[0] = true
	RenderingServer.frame_post_draw.connect(on_drawn, CONNECT_ONE_SHOT)
	for i in 180:
		await process_frame
		if drawn[0]: break
	if not drawn[0]:
		RenderingServer.frame_post_draw.disconnect(on_drawn)
		print("TIMEOUT draw ", name, " (jendela tidak digambar, gambar bisa basi)")
	var img := root.get_texture().get_image()
	img.save_png(outdir.path_join(name + ".png"))
	print("SHOT ", name, " ", img.get_size(), " state=", observe())

func _on_watchdog() -> void:
	print("TIMEOUT watchdog 170s, state=", observe())
	quit(1)

func phys(n: int) -> void:
	for i in n: await physics_frame

func _keep_alive() -> void:
	if not is_instance_valid(player): return
	var h = player.get_node_or_null("Health")
	if h: h.current_health = h.max_health
	var hb = player.get_node_or_null("HurtBox")
	if hb:
		hb.monitorable = false
		hb.monitoring = false
	var rs = root.get_node("RunState")
	rs.light = rs.max_light() * 0.8

func _strip_touch() -> void:
	for t in lvl.find_children("*", "", true, false):
		if t.get_script() and str(t.get_script().resource_path).ends_with("touch_controls.gd"):
			t.queue_free()

func _unload() -> void:
	paused = false
	if is_instance_valid(lvl):
		lvl.queue_free()
	npc = null
	player = null
	await phys(5)

func _prep_run() -> void:
	var rs = root.get_node("RunState")
	rs.reset_run()
	rs.level = 4
	rs.xp = int(rs.xp_to_next() * 0.6)
	rs.kills = 23

func wait_state(prefix: String, max_s: float, extra: Callable = Callable()) -> bool:
	for i in int(max_s * 60):
		await physics_frame
		if observe().begins_with(prefix) and (not extra.is_valid() or extra.call()):
			return true
	print("TIMEOUT waiting ", prefix, " last=", observe())
	return false

func observe() -> String:
	if not is_instance_valid(npc): return "<freed>"
	if npc.has_node("LimboHSM"):
		var st = npc.get_node("LimboHSM").get_active_state()
		if st == null: return "<none>"
		var s := String(st.name)
		if st is BTState and st.get_bt_instance() != null:
			s += "/" + _branch(st.get_bt_instance().get_root_task())
		return s
	if npc.has_node("BTPlayer"):
		var bp: BTPlayer = npc.get_node("BTPlayer")
		if bp.get_bt_instance() == null: return "<bt-none>"
		return _branch(bp.get_bt_instance().get_root_task())
	return "?"

func _branch(root_t: BTTask) -> String:
	if root_t == null: return ""
	for i in root_t.get_child_count():
		var c := root_t.get_child(i)
		if c.get_status() == BT.RUNNING:
			var nm := c.get_task_name()
			var sub := _named_running(c)
			return nm + ("/" + sub if sub != "" else "")
	return ""

func _named_running(task: BTTask) -> String:
	for i in task.get_child_count():
		var c := task.get_child(i)
		if c.get_status() == BT.RUNNING:
			if c is BTSelector or c is BTProbabilitySelector or c is BTSequence:
				for j in c.get_child_count():
					var g := c.get_child(j)
					if g.get_status() == BT.RUNNING and g.custom_name != "":
						return g.custom_name
			if c.custom_name != "": return c.custom_name
	return ""

func has_script_child(node: Node, klass: String) -> bool:
	for c in node.get_children():
		if c.get_script() and c.get_script().get_global_name() == klass: return true
	return false

# ------------------------------------------------------------ level
func load_tower(sd: int) -> void:
	_prep_run()
	lvl = load("res://Scenes/levels/tower.tscn").instantiate()
	lvl.seed_value = sd
	root.add_child(lvl)
	current_scene = lvl
	await phys(5)
	_strip_touch()
	player = lvl.get_node("Player")
	# musuh bawaan dibiarkan, kecuali yang terlalu dekat dengan titik awal
	for e in lvl.get_node("Enemies").get_children():
		if e.global_position.distance_to(player.global_position) < 260:
			e.queue_free()
	await phys(30)

func spawn(scene_path: String, pos: Vector2) -> Node2D:
	var n: Node2D = load(scene_path).instantiate()
	n.position = pos
	lvl.get_node("Enemies").add_child(n)
	npc = n
	await phys(20)
	return n

func load_zone() -> void:
	_prep_run()
	lvl = load("res://Scenes/levels/zone_two.tscn").instantiate()
	root.add_child(lvl)
	current_scene = lvl
	await phys(5)
	_strip_touch()
	player = lvl.get_node("Player")
	npc = lvl.get_node("NorchThex")

# ------------------------------------------------------------ scenario
func goblin() -> void:
	var sd := int(OS.get_environment("SEED_G")) if OS.has_environment("SEED_G") else 202
	await load_tower(sd)
	var p := player.global_position
	# Sebelah kanan titik awal seed ini tembok, jadi goblin dimunculkan di kiri.
	await spawn("res://Scenes/Enemy/goblin/goblin.tscn", p + Vector2(-60, -10))
	player.global_position = Vector2(npc.global_position.x - 24, p.y)
	await wait_state("Attack", 5.0, func(): return has_script_child(npc, "MeleeWarning"))
	await phys(8)
	await shot("01_goblin")

func wolf() -> void:
	var sd := int(OS.get_environment("SEED_W")) if OS.has_environment("SEED_W") else 101
	await load_tower(sd)
	var p := player.global_position
	await spawn("res://Scenes/Enemy/SkullWolf/skull_wolf.tscn", p + Vector2(170, -10))
	player.global_position = Vector2(npc.global_position.x - 90, p.y)
	await wait_state("Attack", 4.0, func(): return has_script_child(npc, "NorcThexArrowWarning"))
	await phys(20)
	await shot("02_wolf")

func boss() -> void:
	await load_zone()
	var hp = npc.health
	player.global_position = npc.global_position + Vector2(-190, -20)
	await wait_state("Phase1/Aimed Shot", 12.0)
	await phys(25) # garis peringatan masih tampil, panah belum lepas
	await shot("03_boss_aimed")
	# Trap butuh jarak 60-185 px; di bawah 130 px tanpa Trap bos malah teleport.
	player.global_position = npc.global_position + Vector2(-120, -10)
	await wait_state("Phase1/Trap", 12.0)
	await phys(50)
	await shot("04_boss_trap")
	hp.take_damage(hp.current_health - int(hp.max_health * 0.45))
	await wait_state("Phase2", 15.0)
	for i in 60 * 25:
		await physics_frame
		if observe().contains("Volley"):
			await phys(25)
			await shot("05_boss_volley")
			return
	await shot("05_boss_phase2")

func levelup() -> void:
	await load_tower(303)
	await phys(30)
	root.get_node("RunState").queue_pick("level")
	for i in 40: await process_frame
	await shot("06_levelup")
