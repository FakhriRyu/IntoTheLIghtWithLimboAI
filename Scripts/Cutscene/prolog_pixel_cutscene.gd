extends "res://Scripts/Cutscene/prolog_cutscene.gd"
## Cutscene 1 — Prolog "Dasar Kastil", versi pixel art. Menggantikan prolog
## gaya komik di Scenes/Cutscene/prolog_cutscene.tscn.
##
## Versi singkat (±30 detik) dari naskah revisi P-01 s.d. P-15: Fiora bangun
## tanpa ingatan di dasar kastil, lelaki tua tanpa nama memberinya lentera dan menyuruhnya naik ke
## cahaya di puncak menara. Aturan misteri: tidak ada petunjuk bahwa lelaki tua
## adalah ayah Fiora, dan ia baru menyebut nama Fiora setelah Fiora sendiri
## menyebutnya.
##
## Tiap adegan satu gambar layar lebar (PixelShot) dengan kamera pelan, cahaya
## lentera berkedip, debu, dan efek kecil (kelopak mata, gelap, hujan).
## Gambar 640x360 ada di Assets/cutscene/prolog_pixel/ dan digambar tanpa
## filter supaya pikselnya tetap tajam. Sistem dialog, audio, lewati (tahan Esc),
## dan judul akhir memakai prolog_cutscene.gd.
##
## Kontrol: J / Space / Enter / klik = lanjut dialog, tahan Esc = lewati.
## Jalankan dengan argumen "-- --auto" untuk memutar dialog otomatis.

const PX_DIR := "res://Assets/cutscene/prolog_pixel/"
## Gambar yang dipakai versi singkat. p04, p07, p09, p10, dan p14 tetap ada
## di folder untuk versi panjang.
const PX_IMAGES := ["p03", "p05", "p06", "p08", "p11", "p13", "p15", "por_fiora", "por_tua"]
## Area gambar layar lebar; kotak dialog ada di bawahnya
const SHOT_SIZE := Vector2(1280, 540)
const FONT_PIXEL := preload("res://Assets/fonts/Jersey10-Regular.ttf")

const PX_SPEAKERS := {
	"???": {"name": "???", "por": "por_tua", "col": Color(0.6, 0.63, 0.75), "side": 1, "blip": "blip_unknown", "sil": true},
	"Fiora": {"name": "FIORA", "por": "por_fiora", "col": Color(1.0, 0.79, 0.29), "side": 0, "blip": "blip_fiora"},
	"Lelaki Tua": {"name": "LELAKI TUA", "por": "por_tua", "col": Color(1.0, 0.62, 0.24), "side": 1, "blip": "blip_elian"},
	"Lelaki Tua (suara)": {"name": "LELAKI TUA", "por": "por_tua", "col": Color(0.85, 0.66, 0.45), "side": 1, "blip": "blip_elian"},
	"Lelaki Tua (memudar)": {"name": "LELAKI TUA", "por": "por_tua", "col": Color(0.78, 0.63, 0.49), "side": 1, "blip": "blip_elian", "fade": true},
}

var _cur: PixelShot


func _image_names() -> Array:
	return PX_IMAGES


func _image_path(n: String) -> String:
	return PX_DIR + n + ".png"


func _speaker(who: String) -> Dictionary:
	return PX_SPEAKERS[who]


## Kotak dialog dan label memakai font pixel, potret tanpa filter
func _build_stage() -> void:
	super()
	_amb.visible = false
	_dlg._name.label_settings.font = FONT_PIXEL
	_dlg._name.label_settings.font_size = 40
	_dlg._text.add_theme_font_override("normal_font", FONT_PIXEL)
	_dlg._text.add_theme_font_override("italics_font", FONT_PIXEL)
	_dlg._text.add_theme_font_size_override("normal_font_size", 34)
	_dlg._text.add_theme_font_size_override("italics_font_size", 34)
	_dlg._por.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skip_label.label_settings.font = FONT_PIXEL
	_skip_label.label_settings.font_size = 24
	_auto_btn.add_theme_font_override("font", FONT_PIXEL)
	_auto_btn.add_theme_font_size_override("font_size", 28)


## Monitor jantung di layar hitam: cukup bunyi, tanpa teks efek komik
func _on_ecg_beat(_i: int) -> void:
	_play("beep", -6.0)


## Ganti adegan: gambar baru muncul dari gelap, gambar lama memudar.
## a/b = kamera awal/akhir (x, y relatif 0..1, zoom), dur = lama gerak kamera.
func _shot(img: String, a: Vector3, b: Vector3, dur: float, o: Dictionary = {}) -> PixelShot:
	var s := PixelShot.new()
	s.size = SHOT_SIZE
	s.setup(_res.tex.get(img, null), _res.glow, o)
	s.cam = a
	_panels.add_child(s)
	s.create_tween().tween_property(s, "cam", b, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	s.modulate = Color.BLACK
	s.create_tween().tween_property(s, "modulate", Color.WHITE, 0.5)
	if _cur != null and is_instance_valid(_cur):
		var old := _cur
		old.z_index = -1
		var t := old.create_tween()
		t.tween_property(old, "modulate", Color.BLACK, 0.5)
		t.tween_callback(old.queue_free)
	_cur = s
	return s


func _steps(n: int, gap: float, db: float) -> void:
	var t := create_tween()
	for i in range(n):
		t.tween_callback(func() -> void:
			if not _done:
				_play("thump", db - i * 1.5))
		t.tween_interval(gap)


# ================================================================ naskah

## Versi singkat (±30 detik): bangun, lelaki tua datang, Fiora menyebut
## namanya, cahaya di puncak menara, lentera berpindah tangan, judul.
func _run() -> void:
	await get_tree().process_frame
	# P-01 — layar hitam, monitor jantung, satu tetes air
	_loop_to(_rain, 0.3, 0.8)
	_ecg.start()
	if await _wait(2.0): return
	_ecg.stop()
	_loop_to(_rain, 0.0, 1.2)
	_play("drip")
	if await _wait(0.4): return

	# P-03 — mata Fiora terbuka
	var s := _shot("p03", Vector3(0.6, 0.5, 1.0), Vector3(0.6, 0.5, 1.1), 4.0)
	s.lids = 1.0
	s.dark = 0.5
	var lt := s.create_tween()
	lt.tween_property(s, "lids", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	lt.tween_property(s, "lids", 0.6, 0.25)
	lt.tween_property(s, "lids", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	s.create_tween().tween_property(s, "dark", 0.0, 2.0)
	_loop_to(_drone, 0.3, 2.0)
	if await _wait(2.4): return

	# P-05 — duduk, bingung
	_shot("p05", Vector3(0.5, 0.55, 1.0), Vector3(0.47, 0.48, 1.1), 5.0, {"dust": true, "sway": true})
	if await _wait(0.4): return
	if await _say("Fiora", "Di mana aku...? Aku tidak ingat apa pun."): return

	# P-06 — langkah kaki, lalu cahaya lentera dari pintu lengkung
	_dlg.hide_box()
	s = _shot("p06", Vector3(0.54, 0.55, 1.14), Vector3(0.54, 0.55, 1.0), 5.0,
			{"lamp": Vector2(0.541, 0.585), "lamp_r": 150.0, "dust": true})
	s.dark = 0.85
	s.lamp_k = 0.0
	_steps(3, 0.4, -6.0)
	if await _wait(1.0): return
	_play("clink", -4.0)
	var lw := s.create_tween().set_parallel(true)
	lw.tween_property(s, "dark", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	lw.tween_property(s, "lamp_k", 1.0, 0.7)
	if await _wait(0.5): return
	if await _say("???", "Jadi, kau sudah bangun."): return

	# P-08 — close-up Fiora menyebut namanya
	_shot("p08", Vector3(0.5, 0.42, 1.0), Vector3(0.5, 0.4, 1.08), 5.0,
			{"lamp": Vector2(0.94, 0.95), "lamp_r": 120.0, "dust": true})
	if await _wait(0.3): return
	if await _say("Fiora", "Aku hanya ingat namaku... Fiora."): return

	# P-11 — kamera naik menyusuri menara sampai cahaya di puncak
	_dlg.hide_box()
	_shot("p11", Vector3(0.5, 0.95, 1.0), Vector3(0.5, 0.06, 1.0), 5.5,
			{"lamp": Vector2(0.5, 0.11), "lamp_r": 260.0, "dust": true})
	var sh := create_tween()
	sh.tween_interval(4.6)
	sh.tween_callback(func() -> void:
		if not _done:
			_play("shimmer", -4.0))
	if await _wait(0.6): return
	if await _say("Lelaki Tua (suara)", "Naiklah ke cahaya di puncak menara. Di sana ada jawabanmu."): return

	# P-13 — lentera berpindah tangan
	_dlg.hide_box()
	_shot("p13", Vector3(0.5, 0.55, 1.12), Vector3(0.5, 0.58, 1.0), 4.0,
			{"lamp": Vector2(0.505, 0.62), "lamp_r": 170.0, "embers": true})
	if await _wait(0.5): return
	_play("clink")
	if await _say("Lelaki Tua", "Bawa lentera ini."): return

	# P-15 — Fiora mengangkat lentera ke arah cahaya, judul
	_dlg.hide_box()
	_loop_to(_drone, 0.0, 2.0)
	_loop_to(_rain, 0.25, 1.5)
	_shot("p15", Vector3(0.42, 0.75, 1.15), Vector3(0.5, 0.42, 1.0), 5.0,
			{"lamp": Vector2(0.375, 0.45), "lamp_r": 130.0, "rain": true})
	if await _wait(1.0): return
	_play("sting")
	_show_title()
	if await _wait(3.2): return
	_finish(1.2)


# ================================================================ kelas bantu

## Satu adegan layar lebar dari gambar pixel art: kamera geser/zoom, cahaya
## lentera berkedip (additive), debu/bara/hujan, gelap, kelopak mata, dan
## sisi kanan yang ditelan gelap.
class PixelShot extends Control:
	## x, y pusat kamera (0..1 dari gambar) dan zoom (1 = selebar mungkin)
	var cam := Vector3(0.5, 0.5, 1.0)
	var dark: float = 0.0
	var lids: float = 0.0
	var fade_right: float = 0.0
	var lamp_k: float = 1.0
	var tex: Texture2D
	var _o: Dictionary
	var _lamp: Control
	var _glow: Texture2D
	var _parts: Array = []
	var _t: float = 0.0
	var _src := Rect2()

	func setup(t: Texture2D, glow: Texture2D, o: Dictionary) -> void:
		tex = t
		_glow = glow
		_o = o
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		_lamp = Control.new()
		_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lamp.material = m
		_lamp.size = size
		_lamp.draw.connect(_draw_light)
		add_child(_lamp)
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in range(70):
			_parts.append([rng.randf() * size.x, rng.randf() * size.y, rng.randf(), i])

	func _process(delta: float) -> void:
		_t += delta
		var k := delta * 60.0
		for p in _parts:
			var s: float = p[2]
			if _o.get("rain", false):
				p[1] += (12.0 + s * 6.0) * k
				p[0] += 2.0 * k
				if p[1] > size.y:
					p[1] = -16.0
					p[0] = randf() * size.x
			else:
				p[1] -= (0.25 + s * 0.4) * k * (2.5 if _o.get("embers", false) else 1.0)
				p[0] += sin(_t * 0.6 + p[3]) * 0.3 * k
				if p[1] < -8.0:
					p[1] = size.y + 8.0
					p[0] = randf() * size.x
		queue_redraw()
		_lamp.queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var ts := tex.get_size()
		var aspect := size.x / size.y
		var w := minf(ts.x, ts.y * aspect) / maxf(cam.z, 1.0)
		var src := Vector2(w, w / aspect)
		var sway := Vector2.ZERO
		if _o.get("sway", false):
			sway = Vector2(sin(_t * 1.3) * 3.0, sin(_t * 0.9 + 1.0) * 2.0)
		var pos := (Vector2(cam.x, cam.y) * ts - src * 0.5 + sway).clamp(Vector2.ZERO, ts - src)
		_src = Rect2(pos.round(), src)
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), _src)

		# debu / bara / hujan dalam kotak piksel
		var px := size.x / src.x
		if _o.get("rain", false):
			for p in _parts:
				var s: float = p[2]
				var c := Color(0.7, 0.8, 0.95, 0.12 + s * 0.2)
				for j in range(3):
					draw_rect(Rect2(Vector2(p[0] - j * px * 0.5, p[1] - j * px * 2.0).snapped(Vector2(px, px)), Vector2(px, px * 2.0)), c)
		elif _o.get("dust", false) or _o.get("embers", false):
			var warm: bool = _o.get("embers", false)
			for p in _parts:
				var s: float = p[2]
				var a := (0.15 + s * 0.45) * (0.5 + 0.5 * sin(_t * 2.2 + p[3]))
				var c := Color(1.0, 0.7, 0.35, a) if warm else Color(0.75, 0.82, 1.0, a * 0.7)
				draw_rect(Rect2(Vector2(p[0], p[1]).snapped(Vector2(px, px)), Vector2(px, px)), c)

		if fade_right > 0.0:
			var x0 := size.x * (1.0 - 0.75 * fade_right)
			draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(size.x, 0), size, Vector2(x0, size.y)]),
					PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, fade_right), Color(0, 0, 0, fade_right), Color(0, 0, 0, 0)]))
		if dark > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dark))
		if lids > 0.0:
			var h := size.y * 0.5 * lids
			draw_rect(Rect2(0, 0, size.x, h), Color.BLACK)
			draw_rect(Rect2(0, size.y - h, size.x, h), Color.BLACK)

	func _draw_light() -> void:
		if not _o.has("lamp") or lamp_k <= 0.0 or _src.size.x <= 0.0:
			return
		var ts := tex.get_size()
		var uv: Vector2 = _o.lamp
		var at := (uv * ts - _src.position) / _src.size * size
		var fl := 0.82 + 0.1 * sin(_t * 17.0) * sin(_t * 5.3) + 0.08 * sin(_t * 31.0)
		var r: float = _o.get("lamp_r", 140.0) * (0.95 + 0.05 * fl) * cam.z
		var k := lamp_k * fl * (1.0 - dark)
		_lamp.draw_texture_rect(_glow, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.6, 0.25, 0.35 * k))
		_lamp.draw_texture_rect(_glow, Rect2(at - Vector2(r, r) * 0.35, Vector2(r, r) * 0.7), false, Color(1.0, 0.8, 0.45, 0.4 * k))
