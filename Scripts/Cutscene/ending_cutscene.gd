extends "res://Scripts/Cutscene/prolog_cutscene.gd"
## Cutscene 2 — Ending "Ke Dalam Cahaya". Diputar setelah Norc'Thex dikalahkan
## di Zone Two (lihat BossVictory), lalu kembali ke main menu.
##
## Memakai gaya dan sistem yang sama dengan prolog (panel komik, kotak dialog,
## teks efek suara, judul emas). Bagian kastil memakai gambar dari
## Assets/cutscene/prolog/ dengan kamera dan efek baru (tengkorak Norc'Thex
## retak lalu luruh, kabut mundur, cahaya menara melebar). Selama di kastil
## Elian hanya berupa suara tanpa wajah. Jati dirinya baru terungkap saat
## Fiora bangun sendirian di rumah sakit dan melihat foto masa kecilnya
## bersama ayahnya yang sudah lama meninggal: Elian adalah ayahnya
## (gambar baru di Assets/cutscene/ending/).
##
## Kontrol sama dengan prolog. Jalankan dengan "-- --auto" untuk dialog otomatis.

const MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const END_DIR := "res://Assets/cutscene/ending/"
## Gambar rumah sakit (dibuat khusus untuk ending), sisanya dari folder prolog
const HOSPITAL_IMAGES := ["h01_room", "h02_wake", "h03_photo", "h04_hold", "por_elian_rs"]
const END_IMAGES := ["p07", "p09", "p12", "p13_plate", "p14", "por_fiora", "por_elian",
		"h01_room", "h02_wake", "h03_photo", "h04_hold", "por_elian_rs"]

const END_SCN := {
	&"end_skull": {"img": "p09", "cam_a": Vector3(0.54, 0.36, 1.18), "cam_b": Vector3(0.5, 0.45, 1.0), "dur": 6.0},
	&"end_fog": {"img": "p13_plate", "cam_a": Vector3(0.42, 0.55, 1.5), "cam_b": Vector3(0.45, 0.5, 1.15), "dur": 7.0},
	&"end_tower": {"img": "p07", "cam_a": Vector3(0.5, 0.62, 1.75), "cam_b": Vector3(0.5, 0.1, 1.75), "dur": 6.0},
	&"alone": {"img": "p13_plate", "cam_a": Vector3(0.6, 0.5, 1.3), "cam_b": Vector3(0.66, 0.5, 1.12), "dur": 10.0},
	&"end_hands": {"img": "p12", "cam_a": Vector3(0.5, 0.6, 1.02), "cam_b": Vector3(0.5, 0.58, 1.2), "dur": 6.0},
	&"end_light": {"img": "p14", "cam_a": Vector3(0.5, 0.5, 1.0), "cam_b": Vector3(0.5, 0.62, 1.35), "dur": 9.0},
	&"room": {"img": "h01_room", "cam_a": Vector3(0.5, 0.5, 1.0), "cam_b": Vector3(0.42, 0.55, 1.15), "dur": 8.0},
	&"wake": {"img": "h02_wake", "cam_a": Vector3(0.5, 0.45, 1.25), "cam_b": Vector3(0.5, 0.5, 1.05), "dur": 6.0},
	&"photo": {"img": "h03_photo", "cam_a": Vector3(0.5, 0.45, 1.2), "cam_b": Vector3(0.5, 0.4, 1.05), "dur": 9.0},
	&"hold": {"img": "h04_hold", "cam_a": Vector3(0.5, 0.5, 1.02), "cam_b": Vector3(0.5, 0.55, 1.18), "dur": 8.0},
}

const END_SPEAKERS := {
	"Fiora": {"name": "FIORA", "por": "por_fiora", "col": Color(1.0, 0.79, 0.29), "side": 0, "blip": "blip_fiora"},
	# di kastil Elian hanya suara: potretnya siluet dengan tanda tanya
	"Elian (suara)": {"name": "ELIAN?", "por": "por_elian", "col": Color(0.6, 0.63, 0.75), "side": 1, "blip": "blip_elian", "sil": true},
	# terakhir kali terdengar, kini dengan wajah dari foto
	"Ayah": {"name": "ELIAN", "por": "por_elian_rs", "col": Color(1.0, 0.62, 0.24), "side": 1, "blip": "blip_elian", "fade": true},
}

var _card_ready: bool = false


func _image_names() -> Array:
	return END_IMAGES


func _image_path(n: String) -> String:
	return (END_DIR + n + ".jpg") if n in HOSPITAL_IMAGES else super(n)


func _scene_def(id: StringName) -> Dictionary:
	return END_SCN[id]


func _speaker(who: String) -> Dictionary:
	return END_SPEAKERS[who]


func _unhandled_input(event: InputEvent) -> void:
	if not _card_ready:
		super(event)
		return
	if _done:
		return
	var adv := event.is_action_pressed("ui_accept") or event.is_action_pressed("Attack") \
			or event.is_action_pressed("Jump")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		adv = true
	if event is InputEventScreenTouch and event.pressed:
		adv = true
	if adv:
		get_viewport().set_input_as_handled()
		_finish(1.4)


## Run selesai: reset RunState lalu kembali ke main menu
func _go_next() -> void:
	_restore_window()
	var rs := get_node_or_null("/root/RunState")
	if rs and rs.has_method("quit_to_menu"):
		rs.quit_to_menu()
	else:
		get_tree().change_scene_to_file(MENU_SCENE)


# ================================================================ naskah

func _run() -> void:
	await get_tree().process_frame
	# --- tengkorak Norc'Thex retak dan luruh
	_amb.mode = &"smoke"
	_loop_to(_drone, 0.5, 0.6)
	if await _wait(0.6): return
	_p["A"] = _panel(&"end_skull", Rect2(190, 40, 900, 490))
	_play("rumble", -2.0)
	if await _wait(0.5): return
	_play("crack")
	_sfx("KRRAAK!", Vector2(60, 60), {"size": 120.0, "color": Color(0.71, 0.49, 1.0), "shadow": Color(0.23, 0.08, 0.37), "rot": -8.0, "dur": 1.6})
	_shake(_p["A"], 0.8, 14.0)
	if await _wait(1.4): return
	_play("crack", -3.0)
	_shake(_p["A"], 0.5, 8.0)
	if await _wait(0.9): return
	_play("whoosh")
	_loop_to(_drone, 0.0, 3.0)
	_sfx("sssshhh...", Vector2(780, 400), {"size": 74.0, "color": Color(0.71, 0.49, 1.0), "shadow": Color(0.23, 0.08, 0.37), "rot": 4.0, "dur": 2.6, "taper": 0.06, "wobble": true})
	if await _wait(3.0): return
	if await _say("Fiora", "Sudah... berakhir?"): return

	# --- kegelapan mundur
	_dlg.hide_box()
	_exit_panel("A", "down")
	_amb.mode = &"dust"
	if await _wait(0.2): return
	_p["B"] = _panel(&"end_fog", Rect2(40, 26, 1200, 510))
	if await _wait(2.2): return
	if await _say("Fiora", "Kabutnya pergi. Lenteranya... makin terang."): return

	# --- cahaya di puncak menara
	_dlg.hide_box()
	_exit_panel("B", "up")
	_amb.mode = &"light"
	if await _wait(0.2): return
	_p["C"] = _panel(&"end_tower", Rect2(465, 14, 350, 522), "down")
	var shimmer := create_tween()
	shimmer.tween_interval(4.6)
	shimmer.tween_callback(func() -> void:
		if not _done and _p.has("C"):
			_play("shimmer")
			_sfx("SHIIING", Vector2(830, 40), {"size": 70.0, "color": Color(1.0, 0.96, 0.8), "shadow": Color(0.72, 0.54, 0.16), "rot": -10.0, "dur": 1.8, "taper": 0.06}))
	if await _wait(2.4): return
	if await _say("Elian (suara)", "Kau berhasil, Fiora. Kau tidak menoleh ke bawah."): return

	# --- Fiora sendirian, hanya suara Elian
	_dlg.hide_box()
	_exit_panel("C", "up")
	if await _wait(0.2): return
	_p["D"] = _panel(&"alone", Rect2(40, 26, 1200, 510), "right")
	if await _wait(1.0): return
	if await _say("Fiora", "Elian? Aku masih bisa mendengarmu... tapi di mana kau?"): return
	if await _say("Elian (suara)", "Di tempat yang sama seperti dulu. Di dalam cahaya yang kau bawa."): return
	if await _say("Fiora", "Siapa kau sebenarnya, Elian? Kenapa kau tahu namaku?"): return
	if await _say("Elian (suara)", "Kau akan tahu saat kau membuka mata. Waktunya kau pulang."): return

	# --- ingatan: lentera yang dulu diserahkan Elian kini menyala penuh
	_dlg.hide_box()
	_exit_panel("D", "left")
	if await _wait(0.2): return
	_p["E"] = _panel(&"end_hands", Rect2(280, 60, 720, 404))
	if await _wait(1.0): return
	_play("clink")
	_sfx("KLINK", Vector2(900, 40), {"size": 84.0, "color": Color(1.0, 0.83, 0.3), "shadow": Color(0.7, 0.31, 0.05), "rot": 8.0, "dur": 1.5})
	if await _wait(1.0): return
	_play("whoosh")
	_flash(Color(1.0, 0.85, 0.54), 0.6)
	_sfx("FWOOSH", Vector2(820, 300), {"size": 100.0, "color": Color(1.0, 0.89, 0.66), "shadow": Color(0.63, 0.35, 0.1), "rot": -6.0, "dur": 2.4, "taper": 0.05, "stagger": 0.07})
	if await _wait(1.8): return

	# --- melangkah ke dalam cahaya
	_exit_panel("E", "up")
	_loop_to(_rain, 0.12, 2.0)
	if await _wait(0.2): return
	_p["F"] = _panel(&"end_light", Rect2(40, 26, 1200, 510))
	if await _wait(1.6): return
	if await _say("Fiora", "Terima kasih, Elian. Untuk tidak membiarkanku sendirian."): return
	if await _say("Elian (suara)", "Pergilah. Ke dalam cahaya."): return
	_dlg.hide_box()
	if await _wait(1.2): return
	_exit_panel("F", "up")
	_flash(LIGHT_WHITE, 2.4)
	_play("sting", -4.0)
	_loop_to(_rain, 0.0, 1.5)
	if await _wait(2.2): return

	# --- rumah sakit: monitor jantung, Fiora terbaring sendirian
	_ecg.start()
	if await _wait(2.6): return
	_ecg.stop()
	_amb.mode = &"dust"
	if await _wait(0.9): return
	_p["G"] = _panel(&"room", Rect2(40, 26, 1200, 510))
	if await _wait(3.0): return

	# --- mata terbuka, pandangan masih buram
	_exit_panel("G", "up")
	if await _wait(0.2): return
	_p["H"] = _panel(&"wake", Rect2(190, 60, 900, 440))
	if await _wait(3.6): return
	if await _say("Fiora", "...Elian?"): return
	if await _say("Fiora", "(tidak ada siapa-siapa di kamar itu)"): return

	# --- foto di meja samping ranjang: Fiora kecil bersama ayahnya
	_dlg.hide_box()
	_exit_panel("H", "up")
	_amb.mode = &"light"
	if await _wait(0.2): return
	_p["I"] = _panel(&"photo", Rect2(40, 26, 1200, 510))
	if await _wait(1.6): return
	_play("shimmer")
	var card := _name_card(Vector2(760, 250), "ELIAN", "AYAH FIORA")
	if await _wait(1.8): return
	if await _say("Fiora", "Ayah..."): return
	_hide_node(card)
	if await _say("Fiora", "Jadi selama ini suara itu suaramu. Kau sudah lama pergi... tapi kau tetap datang menjemputku."): return

	# --- Fiora memeluk foto
	_dlg.hide_box()
	_exit_panel("I", "left")
	if await _wait(0.2): return
	_p["J"] = _panel(&"hold", Rect2(40, 26, 1200, 510))
	if await _wait(1.6): return
	if await _say("Ayah", "Sekarang kau sudah bangun. Hiduplah, Fiora."): return
	if await _say("Fiora", "Terima kasih, Ayah. ...Aku pulang."): return
	_exit_panel("J", "up")

	# --- judul dan ringkasan run
	_dlg.hide_box()
	if await _wait(0.3): return
	_play("sting")
	_show_title()
	if await _wait(2.2): return
	_show_end_card()
	if await _wait(1.6): return
	_card_ready = true
	if auto_advance:
		if await _wait(3.0): return
		_finish(1.4)


## "TAMAT" + statistik run di bawah judul
func _show_end_card() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(340, 250)
	box.size = Vector2(600, 400)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(box)

	box.add_child(_card_label("TAMAT", FONT_FX, 64, Color(1.0, 0.83, 0.3)))
	var rs := get_node_or_null("/root/RunState")
	if rs:
		var t := int(rs.run_time)
		var lines := [
			"Waktu bermain   %02d:%02d" % [t / 60, t % 60],
			"Level   %d" % rs.level,
			"Musuh dikalahkan   %d" % rs.kills,
		]
		if rs.has_method("difficulty_name"):
			lines.append("Kesulitan   %s" % rs.difficulty_name())
		for l in lines:
			box.add_child(_card_label(l, FONT_BOLD, 28, PAPER))
	var hint := _card_label("Tekan J / Space / klik untuk kembali ke menu", FONT_BODY, 22, Color(0.75, 0.78, 0.9))
	box.add_child(hint)

	var i := 0
	for c in box.get_children():
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.25 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.6)
		i += 1
	var pulse := hint.create_tween().set_loops()
	pulse.tween_interval(0.25 * i + 0.6)
	pulse.tween_property(hint, "modulate:a", 0.4, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(hint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_skip_label.hide()


func _card_label(text: String, font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = 6
	ls.outline_color = Color(0.04, 0.03, 0.06)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
