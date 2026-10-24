extends "res://Scripts/Cutscene/boss_intro_cutscene.gd"
## Cutscene 3 — Ending "Ke Dalam Cahaya", versi pixel art pendek (± 30 detik).
## Diputar setelah Norc'Thex dikalahkan di Zone Two (lihat BossVictory), lalu
## kembali ke main menu.
##
## Ringkasan naskah revisi E-01 s.d. E-25: tengkorak Norc'Thex hancur, lelaki tua
## muncul tanpa tudung dan bangga pada Fiora, Fiora melayang dan tangan lelaki
## tua pecah jadi cahaya saat hendak dipegang. Fiora terbangun dari koma di rumah
## sakit, kursi di samping ranjang kosong, lalu foto di meja mengungkap bahwa
## lelaki tua itu ayahnya. Kata "Ayah" tetap tidak diucapkan; fotonya yang bicara.
##
## Gambar 640x360 dan video Theora 640x360 (tanpa suara) dari Google Flow ada di
## Assets/cutscene/ending_pixel/. Potret lelaki tua tanpa tudung diambil dari
## character sheet prolog. Sistem gambar, video, dan efek memakai boss intro.
##
## Kontrol sama dengan prolog. Jalankan dengan "-- --auto" untuk dialog otomatis.

const MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const END_DIR := "res://Assets/cutscene/ending_pixel/"
const END_IMAGES := ["e1", "e2", "e4", "e5", "e6", "por_fiora", "por_tua_open"]

const END_SPEAKERS := {
	"Fiora": {"name": "FIORA", "por": "por_fiora", "col": Color(1.0, 0.79, 0.29), "side": 0, "blip": "blip_fiora"},
	"Lelaki Tua": {"name": "LELAKI TUA", "por": "por_tua_open", "col": Color(1.0, 0.62, 0.24), "side": 1, "blip": "blip_elian"},
}

var _card_ready: bool = false


func _image_names() -> Array:
	return END_IMAGES


func _image_path(n: String) -> String:
	return (PX_DIR if n == "por_fiora" else END_DIR) + n + ".png"


func _video_path(n: String) -> String:
	return END_DIR + n + ".ogv"


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

	# 1 — tengkorak Norc'Thex hancur, cahaya pagi menembus awan
	var s := _img("e1", Vector3(0.6, 0.6, 1.25), Vector3(0.5, 0.45, 1.0), 4.0, {"embers": true})
	_loop_to(_drone, 0.35, 0.4)
	_play("crack")
	_play("rumble", -4.0)
	_quake(s, 1.0, 10.0)
	if await _wait(1.6): return
	_play("whoosh", -4.0)
	_loop_to(_drone, 0.0, 2.0)
	if await _wait(1.6): return

	# 2 — lelaki tua tanpa tudung, berhadapan dengan Fiora
	_img("e2", Vector3(0.52, 0.5, 1.15), Vector3(0.55, 0.52, 1.3), 7.0,
			{"lamp": Vector2(0.637, 0.63), "lamp_r": 60.0, "dust": true})
	if await _wait(1.0): return
	if await _say("Lelaki Tua", "Kau berhasil, Fiora. Aku bangga padamu."): return

	# 3 — Fiora melayang, tangan lelaki tua pecah jadi cahaya, lalu putih
	_dlg.hide_box()
	_video("e3", 0.5)
	_play("shimmer", -6.0)
	if await _wait(1.6): return
	if await _say("Lelaki Tua", "Jalanku berakhir di sini. Pulanglah."): return
	_dlg.hide_box()
	if await _wait(2.4): return
	_play("sting", -4.0)
	_flash(LIGHT_WHITE, 2.4)
	_drop_video()
	if await _wait(2.0): return

	# monitor jantung di layar hitam
	_ecg.start()
	_loop_to(_rain, 0.12, 2.0)
	if await _wait(2.4): return
	_ecg.stop()

	# 4 — bangun di rumah sakit, kursi di samping ranjang kosong
	s = _img("e4", Vector3(0.6, 0.45, 1.2), Vector3(0.52, 0.5, 1.05), 6.0,
			{"lamp": Vector2(0.32, 0.6), "lamp_r": 70.0, "dust": true})
	s.lids = 1.0
	var lt := s.create_tween()
	lt.tween_property(s, "lids", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	if await _wait(1.6): return
	if await _say("Fiora", "...Di mana dia?"): return

	# 5 — foto di meja dan lentera yang sama
	_dlg.hide_box()
	_loop_to(_rain, 0.0, 3.0)
	_img("e5", Vector3(0.45, 0.5, 1.0), Vector3(0.4, 0.42, 1.35), 5.0,
			{"lamp": Vector2(0.88, 0.6), "lamp_r": 160.0, "dust": true})
	_play("shimmer", -10.0)
	if await _wait(4.0): return

	# 6 — Fiora memeluk foto, cahaya pagi
	_img("e6", Vector3(0.55, 0.45, 1.25), Vector3(0.52, 0.45, 1.1), 6.0,
			{"lamp": Vector2(0.323, 0.59), "lamp_r": 70.0, "dust": true})
	if await _wait(1.2): return
	if await _say("Fiora", "...Terima kasih."): return

	# judul dan ringkasan run
	_dlg.hide_box()
	_drop_video()
	if _cur != null and is_instance_valid(_cur):
		_fade_out(_cur)
		_cur = null
	if await _wait(0.6): return
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

	box.add_child(_card_label("TAMAT", FONT_PIXEL, 72, Color(1.0, 0.83, 0.3)))
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
			box.add_child(_card_label(l, FONT_PIXEL, 34, PAPER))
	var hint_text := "Ketuk layar untuk kembali ke menu" if Settings.touch_controls \
			else "Tekan J / Space / klik untuk kembali ke menu"
	var hint := _card_label(hint_text, FONT_PIXEL, 26, Color(0.75, 0.78, 0.9))
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
