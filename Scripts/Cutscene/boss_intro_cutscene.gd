extends "res://Scripts/Cutscene/prolog_pixel_cutscene.gd"
## Cutscene 2 — Boss Intro "Bisikan di Puncak", versi pixel art. Diputar saat
## player menyentuh pilar cahaya di puncak Tower, lalu masuk ke Zone Two.
##
## Mengikuti naskah revisi (B-01 s.d. B-16): cahaya di puncak berubah ungu,
## Norc'Thex muncul dan menghasut Fiora (iri, derita, takut, putus asa).
## Lentera yang hampir padam menyala lagi bersama bunyi samar monitor jantung,
## Fiora berdiri dan pertarungan dimulai. Lelaki tua tidak muncul di sini.
##
## Gambar 640x360 dan video Theora 640x360 (tanpa suara) dari Google Flow ada di
## Assets/cutscene/boss_pixel/. Gambar memakai PixelShot dari prolog pixel art,
## video diputar di kotak yang sama dan dipotong ke area layar lebar. Kata
## bisikan, nama bos, dan semua suara ditambahkan di sini.
##
## Kontrol sama dengan prolog. Jalankan dengan "-- --auto" untuk dialog otomatis.

const BI_DIR := "res://Assets/cutscene/boss_pixel/"
const BI_IMAGES := ["b03", "b04", "b06", "b08", "b09", "b12", "b13", "b14", "b15",
		"por_fiora", "por_norc"]
const BOSS_SCENE := "res://Scenes/levels/zone_two.tscn"
const WHISPER := Color(0.78, 0.6, 1.0)

const BI_SPEAKERS := {
	"Fiora": {"name": "FIORA", "por": "por_fiora", "col": Color(1.0, 0.79, 0.29), "side": 0, "blip": "blip_fiora"},
	"Norc'Thex": {"name": "NORC'THEX", "por": "por_norc", "col": Color(0.4, 0.9, 0.86), "side": 1, "blip": "blip_unknown"},
}

var _vid: Control


func _image_names() -> Array:
	return BI_IMAGES


func _image_path(n: String) -> String:
	return (PX_DIR if n == "por_fiora" else BI_DIR) + n + ".png"


func _speaker(who: String) -> Dictionary:
	return BI_SPEAKERS[who]


## Gambar diam (PixelShot); video sebelumnya ikut memudar
func _img(img: String, a: Vector3, b: Vector3, dur: float, o: Dictionary = {}) -> PixelShot:
	_drop_video()
	return _shot(img, a, b, dur, o)


## Klip video dari Flow di area layar lebar. y = bagian gambar 16:9 yang
## dipertahankan saat dipotong (0 = atas, 1 = bawah).
func _video(n: String, y: float = 0.5) -> VideoStreamPlayer:
	var box := Control.new()
	box.size = SHOT_SIZE
	box.clip_contents = true
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VideoStreamPlayer.new()
	v.stream = load(BI_DIR + n + ".ogv")
	v.expand = true
	v.size = Vector2(SHOT_SIZE.x, SHOT_SIZE.x * 9.0 / 16.0)
	v.position.y = -(v.size.y - SHOT_SIZE.y) * y
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(v)
	_panels.add_child(box)
	box.modulate = Color.BLACK
	box.create_tween().tween_property(box, "modulate", Color.WHITE, 0.5)
	if _cur != null and is_instance_valid(_cur):
		_fade_out(_cur)
	_cur = null
	_drop_video()
	_vid = box
	v.play()
	return v


func _drop_video() -> void:
	if _vid != null and is_instance_valid(_vid):
		_fade_out(_vid)
	_vid = null


func _fade_out(n: Control) -> void:
	n.z_index = -1
	var t := n.create_tween()
	t.tween_property(n, "modulate", Color.BLACK, 0.5)
	t.tween_callback(n.queue_free)


## Layar bergetar (gemuruh, raungan)
func _quake(n: Control, dur: float, amp: float) -> void:
	var t := n.create_tween()
	var steps := int(dur / 0.05)
	for i in range(steps):
		var k := amp * (1.0 - float(i) / steps)
		t.tween_property(n, "position", Vector2(randf_range(-k, k), randf_range(-k, k)).round(), 0.05)
	t.tween_property(n, "position", Vector2.ZERO, 0.05)


## Kata bisikan Norc'Thex ("iri…", "derita…") yang muncul lalu memudar
func _word(text: String, pos: Vector2, size: int = 72, hold: float = 3.0) -> void:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = FONT_PIXEL
	ls.font_size = size
	ls.font_color = WHISPER
	ls.outline_size = 8
	ls.outline_color = Color(0.08, 0.02, 0.14)
	ls.shadow_color = Color(0.45, 0.15, 0.8, 0.6)
	ls.shadow_size = 14
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	l.modulate.a = 0.0
	_fx.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "modulate:a", 0.9, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "position:y", pos.y - 24.0, hold + 1.6).set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(hold - 0.8)
	t.chain().tween_callback(l.queue_free)


## Nama bos di atas freeze frame terakhir
func _boss_card() -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(0, 360)
	box.size = Vector2(1280, 170)
	_title.add_child(box)
	var band := ColorRect.new()
	band.color = Color(0.03, 0.01, 0.06, 0.78)
	band.size = box.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(band)
	var nm := _card_text("NORC'THEX", 104, Color(0.45, 0.95, 0.9), Color(0.05, 0.12, 0.14))
	nm.position = Vector2(0, 4)
	box.add_child(nm)
	var sub := _card_text("Penjaga Limbo", 40, Color(0.85, 0.72, 1.0), Color(0.12, 0.03, 0.18))
	sub.position = Vector2(0, 112)
	box.add_child(sub)
	box.modulate.a = 0.0
	box.scale = Vector2(1.0, 0.0)
	box.pivot_offset = box.size * 0.5
	var t := box.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(box, "modulate:a", 1.0, 0.3)
	t.tween_property(box, "scale", Vector2.ONE, 0.45)


func _card_text(text: String, size: int, col: Color, outline: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = FONT_PIXEL
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = 10
	ls.outline_color = outline
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1280, size * 1.1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Potong ke hitam (bukan putih seperti prolog), lalu masuk arena bos
func _finish(fade: float = 1.2) -> void:
	if _done:
		return
	_done = true
	_advanced.emit()
	_loop_to(_rain, 0.0, fade)
	_loop_to(_drone, 0.0, fade)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0.0
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var t := layer.create_tween()
	t.tween_property(rect, "modulate:a", 1.0, fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_go_next)
	t.tween_interval(0.3)
	t.tween_property(rect, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_callback(layer.queue_free)


func _go_next() -> void:
	_restore_window()
	get_tree().change_scene_to_file(BOSS_SCENE)


# ================================================================ naskah

func _run() -> void:
	await get_tree().process_frame
	_loop_to(_rain, 0.12, 1.5)

	# B-01 — Fiora berjalan ke pilar cahaya dan mengulurkan tangan
	_video("b01", 0.75)
	if await _wait(1.8): return
	if await _say("Fiora", "Akhirnya... cahaya itu."): return
	_dlg.hide_box()
	if await _wait(1.2): return

	# B-02 — kilat putih
	_play("shimmer")
	_flash(LIGHT_WHITE, 1.2)
	if await _wait(0.6): return

	# B-03 — cahaya berubah ungu, asap merayap
	var s := _img("b03", Vector3(0.55, 0.5, 1.12), Vector3(0.5, 0.5, 1.0), 6.0, {"embers": true})
	_play("rumble")
	_play("crack", -4.0)
	_quake(s, 1.2, 10.0)
	_loop_to(_drone, 0.45, 2.0)
	if await _wait(1.2): return
	if await _say("Fiora", "Apa--?! Cahayanya..."): return

	# B-04 — Norc'Thex muncul dari asap
	_dlg.hide_box()
	s = _img("b04", Vector3(0.45, 0.55, 1.0), Vector3(0.62, 0.45, 1.25), 7.0, {"dust": true})
	_play("crack")
	_play("rumble", -6.0)
	_quake(s, 0.8, 6.0)
	if await _wait(1.6): return
	if await _say("Norc'Thex", "Begitu terburu-buru, gadis kecil."): return

	# B-05 — close-up mata Norc'Thex
	_dlg.hide_box()
	_video("b05", 0.5)
	if await _wait(1.0): return
	if await _say("Norc'Thex", "Kau pikir jawaban yang kau cari ada di dalam cahaya itu?"): return

	# B-06 — iri: Fiora berlutut, bayangan orang tertawa di kejauhan
	_dlg.hide_box()
	_img("b06", Vector3(0.4, 0.55, 1.1), Vector3(0.6, 0.45, 1.1), 10.0, {"dust": true})
	if await _wait(0.6): return
	_play("whoosh", -10.0)
	_word("iri...", Vector2(800, 120))
	if await _wait(1.0): return
	if await _say("Norc'Thex", "Lihat mereka di luar sana. Hidup utuh, tertawa tanpa beban. Kenapa dunia memberi mereka segalanya... dan kau hanya luka?"): return

	# B-07 — derita: serpihan ingatan pecah
	_dlg.hide_box()
	_video("b07", 0.5)
	if await _wait(0.6): return
	_play("whoosh", -10.0)
	_word("derita...", Vector2(120, 380))
	if await _wait(1.0): return
	if await _say("Norc'Thex", "Ingatanmu tidak hilang. Kau sendiri yang membuangnya, karena terlalu menyakitkan untuk diingat."): return

	# B-08 — takut: wajah Fiora, detak jantung pelan
	_dlg.hide_box()
	_img("b08", Vector3(0.5, 0.42, 1.0), Vector3(0.5, 0.4, 1.12), 8.0, {"sway": true})
	var hb := create_tween().set_loops(6)
	hb.tween_callback(func() -> void:
		if not _done:
			_play("thump", -8.0))
	hb.tween_interval(1.1)
	if await _wait(0.6): return
	_word("takut...", Vector2(900, 60))
	if await _wait(0.8): return
	if await _say("Norc'Thex", "Kembalilah ke atas, dan semua rasa sakit itu akan kembali kepadamu. Sekaligus."): return
	hb.kill()

	# B-09 — putus asa: asap menyelimuti, mata hampir terpejam
	_dlg.hide_box()
	s = _img("b09", Vector3(0.4, 0.55, 1.0), Vector3(0.33, 0.58, 1.3), 12.0,
			{"lamp": Vector2(0.465, 0.9), "lamp_r": 50.0, "dust": true})
	s.lamp_k = 0.35
	if await _wait(0.6): return
	_word("putus asa...", Vector2(740, 70))
	if await _wait(1.0): return
	if await _say("Norc'Thex", "Di sini sunyi. Tak ada yang menuntut, tak ada yang hilang. Tinggallah... dan tidurlah selamanya."): return
	_dlg.hide_box()
	_word("tidurlah...", Vector2(470, 240), 84, 2.4)
	s.create_tween().tween_property(s, "dark", 0.45, 2.5)
	if await _wait(1.6): return

	# B-10 — hampir terpejam
	_loop_to(_drone, 0.15, 2.5)
	if await _say("Fiora", "Aku... lelah sekali..."): return
	_dlg.hide_box()
	s.create_tween().tween_property(s, "dark", 1.0, 1.4)
	_loop_to(_drone, 0.0, 1.4)
	_loop_to(_rain, 0.0, 1.4)
	if await _wait(1.6): return

	# B-11 — hening, bip monitor jantung samar, lentera menyala lagi
	_play("beep", -16.0)
	if await _wait(1.0): return
	_video("b11", 0.6)
	_play("beep", -13.0)
	if await _wait(1.0): return
	_play("beep", -10.0)
	if await _wait(0.6): return
	_play("whoosh")
	_play("shimmer", -6.0)
	if await _wait(2.6): return

	# B-12 — Fiora berdiri, lentera mendorong asap
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("play_music"):
		audio.play_music(&"boss", 5.0)
	_img("b12", Vector3(0.5, 0.6, 1.15), Vector3(0.5, 0.5, 1.0), 7.0,
			{"lamp": Vector2(0.603, 0.38), "lamp_r": 190.0, "embers": true})
	if await _wait(1.2): return
	if await _say("Fiora", "Mungkin kau benar. Mungkin di atas sana memang sakit."): return

	# B-13 — menatap Norc'Thex lurus
	_img("b13", Vector3(0.5, 0.45, 1.12), Vector3(0.5, 0.4, 1.0), 8.0, {"dust": true})
	if await _wait(0.6): return
	if await _say("Fiora", "Tapi aku tidak mau terus tertidur di tempat yang bahkan tidak kuingat."): return

	# B-14 — menghunus pedang
	_dlg.hide_box()
	_img("b14", Vector3(0.38, 0.55, 1.2), Vector3(0.4, 0.55, 1.05), 6.0,
			{"lamp": Vector2(0.43, 0.68), "lamp_r": 90.0, "dust": true})
	if await _wait(0.5): return
	_play("whoosh", -2.0)
	_play("clink", -2.0)
	if await _wait(0.6): return
	if await _say("Fiora", "Aku akan naik. Dan kau tidak akan menghentikanku."): return

	# B-15 — Norc'Thex membentangkan sayap
	_dlg.hide_box()
	s = _img("b15", Vector3(0.5, 0.5, 1.2), Vector3(0.5, 0.42, 1.0), 4.0,
			{"lamp": Vector2(0.32, 0.9), "lamp_r": 80.0, "embers": true})
	_play("rumble")
	_play("crack", -2.0)
	_quake(s, 1.4, 12.0)
	if await _wait(1.0): return
	if await _say("Norc'Thex", "Kalau begitu, akan kuseret kau kembali ke dasar!"): return

	# B-16 — freeze frame, nama bos
	_dlg.hide_box()
	_play("sting")
	_flash(Color(0.6, 0.3, 1.0), 0.5)
	_boss_card()
	if await _wait(3.6): return
	_finish(0.8)
