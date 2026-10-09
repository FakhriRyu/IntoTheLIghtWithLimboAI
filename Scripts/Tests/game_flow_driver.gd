extends Node
## Uji mekanik black box (Bab 4.4.1) yang dijalankan otomatis.
## Driver ini hidup di /root (bukan scene aktif), jadi tetap ada saat scene berganti.
## Ia menekan tombol menu dan mensimulasikan input aksi (Left, Right, Jump,
## Attack, Up, Pause) persis seperti pemain, lalu mencatat apa yang terjadi.
## Hasil ditulis ke user://game_flow_test/hasil_<waktu>.csv.

const MAIN_MENU := "res://Scenes/UI/main_menu.tscn"
const PROLOG := "res://Scenes/Cutscene/prolog_cutscene.tscn"
const TOWER := "res://Scenes/levels/tower.tscn"
const ZONE_TWO := "res://Scenes/levels/zone_two.tscn"
const ENDING := "res://Scenes/Cutscene/ending_cutscene.tscn"
const GOBLIN := preload("res://Scenes/Enemy/goblin/goblin.tscn")
const PICKUP := preload("res://Scenes/Items/pickup.tscn")
const CHEST := preload("res://Scenes/Items/chest.tscn")

var results: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	_write_results()
	get_tree().quit()


# ---------------------------------------------------------------- helper

func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func wait_until(cond: Callable, max_s: float) -> float:
	var t := 0.0
	while t < max_s:
		await get_tree().process_frame
		t += get_process_delta_time()
		if cond.call():
			return t
	return -1.0


func scene_path() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s else ""


func tap(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().physics_frame


func hold(action: StringName, s: float) -> void:
	Input.action_press(action)
	await wait(s)
	Input.action_release(action)


func find_by_script(root: Node, file: String) -> Node:
	if root.get_script() and root.get_script().resource_path.ends_with(file):
		return root
	for c in root.get_children():
		var f := find_by_script(c, file)
		if f:
			return f
	return null


func player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func keep_light() -> void:
	# Cahaya habis = run berakhir; isi penuh supaya uji lain tidak terganggu
	RunState.add_light(RunState.max_light())


func record(no: int, fitur: String, skenario: String, harapan: String, hasil: String, lulus: bool) -> void:
	results.append({"no": no, "fitur": fitur, "skenario": skenario, "harapan": harapan, "hasil": hasil, "lulus": lulus})
	print("[%s] #%d %s | %s" % ["LULUS" if lulus else "GAGAL", no, fitur, hasil])


# ---------------------------------------------------------------- skenario

func _run() -> void:
	# 1. Main menu → pilih kesulitan → prolog
	get_tree().change_scene_to_file(MAIN_MENU)
	await wait_until(func(): return scene_path() == MAIN_MENU and get_tree().current_scene.get("_accepting") == true, 8.0)
	var menu := get_tree().current_scene
	menu.start_button.pressed.emit()
	await wait_until(func(): return menu.difficulty_panel.visible and menu.difficulty_panel.modulate.a >= 1.0, 3.0)
	menu._difficulty_buttons[1].pressed.emit()   # Normal
	var t := await wait_until(func(): return scene_path() == PROLOG, 8.0)
	record(1, "Main menu", "Menekan tombol Mulai lalu memilih kesulitan Normal",
		"Cutscene prolog ditampilkan",
		("Scene prolog dimuat %.1f detik setelah kesulitan dipilih" % t) if t > 0 else "Scene tetap " + scene_path(), t > 0)

	# 2. Prolog diselesaikan dengan menekan tombol lanjut berulang kali
	var presses := 0
	var t2 := 0.0
	while scene_path() == PROLOG and t2 < 180.0:
		await tap(&"Attack")
		presses += 1
		await wait(0.4)
		t2 += 0.45
	await wait_until(func(): return scene_path() == TOWER, 5.0)
	record(2, "Cutscene", "Menyelesaikan cutscene prolog dengan menekan tombol lanjut",
		"Pemain masuk ke level Tower",
		"Scene sekarang %s setelah %d kali tombol lanjut (±%.0f detik)" % [scene_path().get_file(), presses, t2],
		scene_path() == TOWER)
	if scene_path() != TOWER:
		get_tree().change_scene_to_file(TOWER)
		await wait_until(func(): return scene_path() == TOWER, 5.0)

	await wait_until(func(): return player() != null, 5.0)
	await wait(1.0)
	keep_light()
	var p := player()

	# 3. Bergerak kiri dan kanan
	var x0 := p.global_position.x
	await hold(&"Right", 0.6)
	var x1 := p.global_position.x
	await wait(0.2)
	await hold(&"Left", 0.6)
	var x2 := p.global_position.x
	record(3, "Pergerakan", "Menahan tombol kanan lalu kiri selama 0,6 detik",
		"Karakter bergerak sesuai arah",
		"Kanan: x %.0f → %.0f (%+.0f px); kiri: x → %.0f (%+.0f px)" % [x0, x1, x1 - x0, x2, x2 - x1],
		x1 - x0 > 20.0 and x2 - x1 < -20.0)

	# 4. Lompat
	await wait_until(func(): return p.is_on_floor(), 2.0)
	var y0 := p.global_position.y
	var min_y := y0
	Input.action_press(&"Jump")
	for i in 12:
		await get_tree().physics_frame
		min_y = minf(min_y, p.global_position.y)
	Input.action_release(&"Jump")
	var landed := await wait_until(func():
		min_y = minf(min_y, p.global_position.y)
		return p.is_on_floor() and p.velocity.y >= 0.0, 3.0)
	record(4, "Lompat", "Menekan tombol lompat",
		"Karakter melompat dan kembali mendarat",
		"Naik %.0f px, mendarat kembali setelah %.2f detik" % [y0 - min_y, landed],
		y0 - min_y > 16.0 and landed > 0)

	# 5. Serangan pemain mengenai musuh
	keep_light()
	var facing := -1.0 if p.sprite.flip_h else 1.0
	var gob := GOBLIN.instantiate()
	gob.position = p.global_position + Vector2(facing * 26.0, -6.0)
	get_tree().current_scene.add_child(gob)
	await wait(0.15)
	var hp_before: int = gob.health.current_health
	await tap(&"Attack")
	await wait(0.6)
	var hp_after: int = gob.health.current_health if is_instance_valid(gob) else 0
	record(5, "Serangan pemain", "Menekan tombol serang saat Goblin berada di depan karakter",
		"HP musuh berkurang dan musuh berkedip",
		"HP Goblin %d → %d" % [hp_before, hp_after], hp_after < hp_before)

	# 6. Damage ke pemain: biarkan Goblin menyerang
	var php: int = p.health.current_health
	var gob_dist := -1.0
	if is_instance_valid(gob):
		gob_dist = absf(gob.global_position.x - p.global_position.x)
	var t6 := await wait_until(func(): return p.health.current_health < php, 8.0)
	if t6 < 0:
		print("diag #6: jarak goblin awal %.0f, goblin valid %s, state %s, HP goblin %s" % [gob_dist, is_instance_valid(gob),
			gob.state_machine.get_active_state().name if is_instance_valid(gob) else "-", gob.health.current_health if is_instance_valid(gob) else "-"])
	record(6, "Damage ke pemain", "Diam di dekat Goblin sampai Goblin menyerang",
		"HP pemain berkurang",
		("HP pemain %d → %d setelah %.1f detik" % [php, p.health.current_health, t6]) if t6 > 0 else "HP tidak berkurang dalam 8 detik",
		t6 > 0)
	if is_instance_valid(gob):
		gob.health.take_damage(99)
	await wait(1.5)
	keep_light()

	# 8. Naik level dan kartu upgrade
	var lv0 := RunState.level
	var up0 := RunState.upgrades.duplicate()
	RunState.add_xp(RunState.xp_to_next())
	var lus := find_by_script(get_tree().root, "level_up_screen.gd")
	var t8 := await wait_until(func(): return lus and lus.get("_showing") == true, 3.0)
	var paused_on := get_tree().paused
	await wait(1.0)   # kunci input kartu
	var cards: Array = lus.get("_buttons") if lus else []
	if cards.size() > 0:
		cards[0].pressed.emit()
	await wait(0.8)
	var gained := RunState.upgrades.size() > up0.size() or str(RunState.upgrades) != str(up0)
	record(8, "Level-up dan kartu upgrade", "XP pemain mencapai batas level, lalu memilih kartu pertama",
		"Pilihan kartu upgrade muncul dan efeknya diterapkan",
		"Level %d → %d, layar kartu muncul: %s (game dijeda: %s), %d kartu ditawarkan, upgrade bertambah: %s, game berjalan lagi: %s" % [
			lv0, RunState.level, "ya" if t8 > 0 else "tidak", "ya" if paused_on else "tidak", cards.size(), "ya" if gained else "tidak", "ya" if not get_tree().paused else "tidak"],
		t8 > 0 and cards.size() > 0 and gained and not get_tree().paused)
	keep_light()

	# 9. Pickup dan peti
	var xp0 := RunState.xp
	var pk := PICKUP.instantiate()
	pk.kind = 1   # XP
	pk.amount = 3
	pk.position = p.global_position + Vector2(20, -8)
	get_tree().current_scene.add_child(pk)
	var t9 := await wait_until(func(): return not is_instance_valid(pk), 3.0)
	var xp1 := RunState.xp
	var ch := CHEST.instantiate()
	ch.position = p.global_position
	get_tree().current_scene.add_child(ch)
	await wait(0.2)
	await tap(&"Up")
	await wait(0.5)
	var opened: bool = ch.opened
	record(9, "Pickup dan peti", "Mendekati orb XP; berdiri di depan peti lalu menekan tombol atas",
		"Item diterima sesuai jenisnya",
		"Orb XP terambil: %s (XP %d → %d); peti terbuka: %s" % ["ya" if t9 > 0 else "tidak", xp0, xp1, "ya" if opened else "tidak"],
		t9 > 0 and xp1 != xp0 and opened)
	await wait(1.0)
	# Peti bisa berisi relik: tutup layar kartu kalau muncul
	if lus and lus.get("_showing") == true:
		await wait(1.0)
		var c2: Array = lus.get("_buttons")
		if c2.size() > 0:
			c2[0].pressed.emit()
		await wait(0.8)
	keep_light()

	# 10. Pause
	var pm := find_by_script(get_tree().root, "pause_menu.gd")
	await tap(&"Pause")
	await wait(0.3)
	var paused := get_tree().paused
	var shown: bool = pm != null and pm.get("_showing") == true
	await tap(&"Pause")
	await wait(0.3)
	record(10, "Pause dan settings", "Menekan tombol pause, lalu menekan lagi",
		"Permainan berhenti dan menu pause tampil",
		"Game dijeda: %s, menu pause tampil: %s, setelah ditekan lagi game berjalan: %s" % [
			"ya" if paused else "tidak", "ya" if shown else "tidak", "ya" if not get_tree().paused else "tidak"],
		paused and shown and not get_tree().paused)

	# 11. Pintu keluar Tower → Zone Two
	keep_light()
	var exit: Node2D = null
	for n in get_tree().current_scene.get_children():
		if n is CaveExit:
			exit = n
	if exit:
		p.global_position = exit.global_position + Vector2(0, -4)
	var t11 := await wait_until(func(): return scene_path() == ZONE_TWO, 5.0)
	record(11, "Perpindahan level", "Pemain masuk ke pintu keluar Tower",
		"Pemain masuk ke Zone Two (arena bos)",
		("Zone Two dimuat %.2f detik setelah menyentuh pintu" % t11) if t11 > 0 else "Scene tetap " + scene_path().get_file(),
		t11 > 0)

	# 12. Mengalahkan Norc'Thex
	await wait_until(func(): return player() != null and get_tree().get_first_node_in_group("boss") != null, 5.0)
	await wait(1.0)
	keep_light()
	var boss := get_tree().get_first_node_in_group("boss")
	var before_scene := scene_path()
	if boss:
		boss.health.take_damage(1)
		await wait(2.5)
		boss.health.take_damage(boss.health.current_health)
	var boss_gone := await wait_until(func(): return not is_instance_valid(boss), 6.0)
	var t12 := await wait_until(func(): return scene_path() == ENDING, 6.0)
	var ending := t12 > 0
	record(12, "Kemenangan", "Mengalahkan Norc'Thex",
		"Cutscene penutup ditampilkan sebagai akhir permainan",
		"Bos mati dan dihapus: %s; %s" % [
			"ya" if boss_gone > 0 else "tidak",
			("cutscene penutup dimuat %.2f detik setelah node bos dihapus" % t12) if ending
				else "scene tetap " + scene_path().get_file() + " (cutscene penutup tidak dimuat)"],
		ending)

	# 7. Kematian pemain (terakhir, karena mengakhiri run).
	# Kemenangan sudah memindahkan game ke cutscene penutup, jadi muat ulang Zone Two.
	if scene_path() != ZONE_TWO:
		await wait(1.0)
		get_tree().change_scene_to_file(ZONE_TWO)
		await wait_until(func(): return scene_path() == ZONE_TWO and player() != null, 5.0)
		await wait(0.5)
	p = player()
	var ros := find_by_script(get_tree().root, "run_over_screen.gd")
	p.health.take_damage(p.health.current_health)
	var t7 := await wait_until(func(): return ros and ros.root.visible, 8.0)
	record(7, "Kematian pemain", "HP pemain habis",
		"Layar game over ditampilkan",
		("Layar run over tampil %.1f detik setelah HP habis (level %d, kill %d)" % [t7, RunState.level, RunState.kills]) if t7 > 0 else "Layar run over tidak tampil",
		t7 > 0)


# ---------------------------------------------------------------- output

func _write_results() -> void:
	results.sort_custom(func(a, b): return a.no < b.no)
	DirAccess.make_dir_recursive_absolute("user://game_flow_test")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://game_flow_test/hasil_%s.csv" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("no,fitur,skenario,harapan,hasil,status")
	var passed := 0
	for r in results:
		if r.lulus:
			passed += 1
		var cells := [str(r.no), r.fitur, r.skenario, r.harapan, r.hasil, "Sesuai" if r.lulus else "Tidak sesuai"]
		f.store_line(",".join(cells.map(func(c): return "\"" + String(c).replace("\"", "\"\"") + "\"")))
	f.close()
	print("Hasil: %d/%d skenario sesuai. File: %s" % [passed, results.size(), ProjectSettings.globalize_path(path)])
