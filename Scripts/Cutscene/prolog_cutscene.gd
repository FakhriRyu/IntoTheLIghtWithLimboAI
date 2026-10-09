extends Control
## Cutscene 1 — Prolog "Bangun". Diputar sekali saat run baru dimulai dari main
## menu, lalu pindah ke RunState.run_start_scene (menara).
##
## Gaya komik: panel bergambar muncul satu per satu di atas latar hitam, kamera
## di tiap panel bergerak pelan, teks efek suara besar, kotak dialog di bawah.
## Semua panel dan efek dibuat dari kode (lihat ComicPanel), gambar ada di
## Assets/cutscene/prolog/.
##
## Kontrol: J / Space / Enter / klik = lanjut dialog, tahan Esc = lewati.
## Jalankan dengan argumen "-- --auto" untuk memutar dialog otomatis.

const DESIGN := Vector2(1280, 720)
const IMG_DIR := "res://Assets/cutscene/prolog/"
const SFX_DIR := "res://Assets/audio/sfx/cutscene/"
const NEXT_FALLBACK := "res://Scenes/levels/tower.tscn"
const IMAGES := ["p01a", "p01b", "p02", "p03", "p04", "p05", "p06", "p07", "p08", "p09",
		"p10", "p11", "p12", "p13", "p13_plate", "p14", "por_fiora", "por_elian"]
const SOUNDS := ["beep", "drip", "thump", "clink", "whoosh", "rumble", "crack", "shimmer",
		"sting", "blip_fiora", "blip_elian", "blip_unknown"]
## Gambar yang datanya (Image) disimpan untuk efek "luruh" per sel di ComicPanel
const DATA_IMAGES := ["p13", "p09"]
const LIGHT_WHITE := Color(1.0, 0.96, 0.86)
const PAPER := Color(0.957, 0.937, 0.894)
## Lama menahan Esc untuk melewati cutscene
const SKIP_HOLD := 1.0

const FONT_FX := preload("res://Assets/fonts/Bangers-Regular.ttf")
const FONT_BODY := preload("res://Assets/fonts/Baloo2-SemiBold.ttf")
const FONT_BOLD := preload("res://Assets/fonts/Baloo2-ExtraBold.ttf")
const FONT_TITLE := preload("res://Assets/fonts/Cinzel-Black.ttf")

## Panel per adegan: gambar, kamera awal/akhir (x, y relatif 0..1, zoom), lama gerak (detik)
const SCN := {
	&"eyes": {},
	&"lying": {"img": "p02", "cam_a": Vector3(0.42, 0.5, 1.12), "cam_b": Vector3(0.56, 0.5, 1.04), "dur": 7.0},
	&"sit": {"img": "p03", "cam_a": Vector3(0.5, 0.52, 1.08), "cam_b": Vector3(0.48, 0.48, 1.0), "dur": 6.0},
	&"elian": {"img": "p04", "cam_a": Vector3(0.36, 0.5, 1.12), "cam_b": Vector3(0.42, 0.5, 1.0), "dur": 8.0},
	&"fiora_sad": {"img": "p05", "cam_a": Vector3(0.45, 0.42, 1.12), "cam_b": Vector3(0.48, 0.46, 1.02), "dur": 7.0},
	&"elian_point": {"img": "p06", "cam_a": Vector3(0.5, 0.6, 1.12), "cam_b": Vector3(0.45, 0.42, 1.04), "dur": 6.0},
	&"tower": {"img": "p07", "cam_a": Vector3(0.5, 0.86, 1.75), "cam_b": Vector3(0.5, 0.16, 1.75), "dur": 5.2},
	&"dark": {"img": "p08", "cam_a": Vector3(0.55, 0.5, 1.08), "cam_b": Vector3(0.6, 0.52, 1.16), "dur": 7.0},
	&"norch": {"img": "p09", "cam_a": Vector3(0.5, 0.45, 1.0), "cam_b": Vector3(0.54, 0.36, 1.18), "dur": 4.5},
	&"two_f": {"img": "p10", "cam_a": Vector3(0.37, 0.42, 1.36), "cam_b": Vector3(0.35, 0.42, 1.42), "dur": 12.0},
	&"two_e": {"img": "p11", "cam_a": Vector3(0.5, 0.45, 1.12), "cam_b": Vector3(0.53, 0.43, 1.2), "dur": 12.0},
	&"hands": {"img": "p12", "cam_a": Vector3(0.5, 0.55, 1.14), "cam_b": Vector3(0.5, 0.6, 1.02), "dur": 4.2},
	&"fade": {"img": "p13", "cam_a": Vector3(0.52, 0.5, 1.04), "cam_b": Vector3(0.27, 0.52, 1.9), "dur": 3.9, "delay": 1.1},
	&"finale": {"img": "p14", "cam_a": Vector3(0.5, 0.66, 1.22), "cam_b": Vector3(0.5, 0.5, 1.0), "dur": 7.0},
}

const SPEAKERS := {
	"???": {"name": "???", "por": "por_elian", "col": Color(0.6, 0.63, 0.75), "side": 1, "blip": "blip_unknown", "sil": true},
	"Fiora": {"name": "FIORA", "por": "por_fiora", "col": Color(1.0, 0.79, 0.29), "side": 0, "blip": "blip_fiora"},
	"Elian": {"name": "ELIAN", "por": "por_elian", "col": Color(1.0, 0.62, 0.24), "side": 1, "blip": "blip_elian"},
	"Elian (memudar)": {"name": "ELIAN (MEMUDAR)", "por": "por_elian", "col": Color(0.78, 0.63, 0.49), "side": 1, "blip": "blip_elian", "fade": true},
}

const TITLE_SHADER := """
shader_type canvas_item;
uniform float x0 = 0.0;
uniform float x1 = 1.0;
uniform float letter_w = 60.0;
uniform float shine = -0.5;
varying float lx;
void vertex() { lx = VERTEX.x; }
void fragment() {
	float g = mix(x0, x1, clamp(lx / letter_w, 0.0, 1.0));
	vec3 col = mix(vec3(0.72, 0.45, 0.11), vec3(1.0, 0.88, 0.54), smoothstep(0.0, 0.35, g));
	col = mix(col, vec3(0.79, 0.52, 0.16), smoothstep(0.62, 1.0, g));
	col = mix(col, vec3(1.0, 0.98, 0.94), exp(-pow((g - shine) * 6.0, 2.0)));
	COLOR = vec4(col, COLOR.a);
}
"""

const BLUR_SHADER := """
shader_type canvas_item;
uniform float lod = 0.0;
uniform float brightness = 1.0;
void fragment() {
	COLOR = vec4(textureLod(TEXTURE, UV, lod).rgb * brightness, 1.0);
}
"""

signal _advanced

@export var auto_advance: bool = false

var _res := {}
var _stage: Control
var _amb: Ambient
var _panels: Control
var _ecg: Ecg
var _fx: Control
var _title: Control
var _dlg: DialogBox
var _skip_label: Label
var _skip_bar: ColorRect
var _p := {}
var _done: bool = false
var _skip_time: float = 0.0
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _rain: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _sounds := {}
var _old_scale := {}


# ================================================================ setup

func _ready() -> void:
	if "--auto" in OS.get_cmdline_user_args():
		auto_advance = true
	get_tree().paused = false
	# Cutscene digambar di resolusi layar asli (bukan 640x480 piksel game)
	var win := get_window()
	_old_scale = {"mode": win.content_scale_mode, "size": win.content_scale_size, "aspect": win.content_scale_aspect}
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_size = Vector2i(DESIGN)
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_load_resources()
	_build_stage()
	_build_audio()
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("stop_music"):
		audio.stop_music(1.2)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_run()


func _exit_tree() -> void:
	_restore_window()


func _restore_window() -> void:
	if _old_scale.is_empty():
		return
	var win := get_window()
	win.content_scale_mode = _old_scale.mode
	win.content_scale_size = _old_scale.size
	win.content_scale_aspect = _old_scale.aspect
	_old_scale = {}


func _load_resources() -> void:
	var tex := {}
	var data := {}
	for n in _image_names():
		var t := load(IMG_DIR + n + ".jpg") as Texture2D
		if t == null:
			push_warning("Prolog: gambar %s tidak ada" % n)
			continue
		var img := t.get_image()
		if img == null:
			tex[n] = t
			continue
		if img.is_compressed():
			img.decompress()
		if n in DATA_IMAGES:
			data[n] = img.duplicate()
		# mipmap supaya gambar besar tetap halus saat diperkecil
		img.generate_mipmaps()
		tex[n] = ImageTexture.create_from_image(img)

	var glow := GradientTexture2D.new()
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	glow.gradient = g

	var vig := GradientTexture2D.new()
	vig.width = 256
	vig.height = 256
	vig.fill = GradientTexture2D.FILL_RADIAL
	vig.fill_from = Vector2(0.5, 0.5)
	vig.fill_to = Vector2(1.0, 1.0)
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	vg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)])
	vig.gradient = vg

	var blur := Shader.new()
	blur.code = BLUR_SHADER
	var title := Shader.new()
	title.code = TITLE_SHADER
	_res = {"tex": tex, "img_data": data, "glow": glow, "vignette": vig, "blur_shader": blur, "title_shader": title}


func _build_stage() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.024, 0.027, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_stage = Control.new()
	_stage.size = DESIGN
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_amb = Ambient.new()
	_amb.glow = _res.glow
	_amb.size = DESIGN
	_stage.add_child(_amb)

	_panels = _layer_control()
	_ecg = Ecg.new()
	_ecg.position = Vector2(0, 240)
	_ecg.size = Vector2(1280, 240)
	_ecg.beat.connect(_on_ecg_beat)
	_stage.add_child(_ecg)
	_fx = _layer_control()
	_title = _layer_control()

	_dlg = DialogBox.new()
	_dlg.position = Vector2(40, 556)
	_dlg.size = Vector2(1200, 150)
	_dlg.cutscene = self
	_stage.add_child(_dlg)
	_dlg.build(_res, FONT_FX, FONT_BODY)
	_dlg.line_done.connect(func() -> void: _advanced.emit())

	_skip_label = Label.new()
	_skip_label.text = "Tahan ESC untuk lewati"
	var ls := LabelSettings.new()
	ls.font = FONT_BOLD
	ls.font_size = 18
	ls.font_color = Color(0.75, 0.78, 0.9, 0.7)
	ls.outline_size = 4
	ls.outline_color = Color.BLACK
	_skip_label.label_settings = ls
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.position = Vector2(1000, 4)
	_skip_label.size = Vector2(270, 26)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_skip_label)
	_skip_bar = ColorRect.new()
	_skip_bar.color = Color(1.0, 0.79, 0.29)
	_skip_bar.position = Vector2(1270, 30)
	_skip_bar.size = Vector2(0, 3)
	_skip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_skip_bar)


func _layer_control() -> Control:
	var c := Control.new()
	c.size = DESIGN
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(c)
	return c


func _layout() -> void:
	var vp := get_viewport_rect().size
	var k := minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	_stage.scale = Vector2(k, k)
	_stage.position = ((vp - DESIGN * k) * 0.5).round()


func _build_audio() -> void:
	var bus := &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_voices.append(p)
	for n in SOUNDS:
		var s := load(SFX_DIR + n + ".wav") as AudioStream
		if s:
			_sounds[n] = s
	_rain = _loop_player("rain_loop", bus)
	_drone = _loop_player("drone_loop", bus)


func _loop_player(n: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -60.0
	var s := load(SFX_DIR + n + ".wav") as AudioStreamWAV
	if s:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
	add_child(p)
	return p


func _play(n: String, db: float = 0.0) -> void:
	if not _sounds.has(n):
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _sounds[n]
	p.volume_db = db
	p.pitch_scale = 1.0
	p.play()


## Volume loop (0..1) dengan fade
func _loop_to(p: AudioStreamPlayer, v: float, fade: float) -> void:
	if p.stream == null:
		return
	if v > 0.0 and not p.playing:
		p.play()
	var db := linear_to_db(maxf(v, 0.0001))
	create_tween().tween_property(p, "volume_db", db, fade)


# ================================================================ data adegan
# Cutscene lain (mis. ending_cutscene.gd) mewarisi script ini dan menimpa
# fungsi-fungsi berikut untuk memakai gambar, panel, dan pembicara sendiri.

func _image_names() -> Array:
	return IMAGES


func _scene_def(id: StringName) -> Dictionary:
	return SCN[id]


func _speaker(who: String) -> Dictionary:
	return SPEAKERS[who]


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var adv := event.is_action_pressed("ui_accept") or event.is_action_pressed("Attack") \
			or event.is_action_pressed("Jump")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		adv = true
	if event is InputEventScreenTouch and event.pressed:
		adv = true
	if adv:
		_dlg.advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _done:
		return
	var holding := Input.is_action_pressed("ui_cancel") or (InputMap.has_action("Pause") and Input.is_action_pressed("Pause"))
	_skip_time = clampf(_skip_time + (delta if holding else -delta * 2.0), 0.0, SKIP_HOLD)
	_skip_bar.size.x = 260.0 * _skip_time / SKIP_HOLD
	_skip_bar.position.x = 1270.0 - _skip_bar.size.x
	if _skip_time >= SKIP_HOLD:
		_finish(0.5)


# ================================================================ helper urutan

## Tunggu beberapa detik. true = cutscene sudah selesai/dilewati, hentikan urutan.
func _wait(sec: float) -> bool:
	if _done:
		return true
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(sec, 0.01)
	add_child(t)
	t.start()
	await t.timeout
	t.queue_free()
	return _done


func _say(who: String, text: String) -> bool:
	if _done:
		return true
	_dlg.show_line(_speaker(who), text, auto_advance)
	await _advanced
	return _done


func _panel(id: StringName, rect: Rect2, enter: String = "pop", z: int = 0, opts: Dictionary = {}) -> ComicPanel:
	var p := ComicPanel.new()
	var o: Dictionary = _scene_def(id).duplicate()
	o.merge(opts, true)
	_panels.add_child(p)
	p.setup(id, rect, o, _res)
	p.z_index = z
	var base := p.position
	var tw := p.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# masuk dari gelap: bingkai putih tidak tembus saat panel masih transparan
	p.modulate = Color(0, 0, 0, 0)
	if enter == "pop":
		p.scale = Vector2(0.6, 0.6)
		p.rotation_degrees = -2.0
		tw.tween_property(p, "scale", Vector2.ONE, 0.52)
		tw.tween_property(p, "rotation_degrees", 0.0, 0.52)
	else:
		var off: Vector2 = {"left": Vector2(-160, 0), "right": Vector2(160, 0), "up": Vector2(0, -120), "down": Vector2(0, 140)}[enter]
		p.position = base + off
		p.rotation_degrees = signf(off.x + off.y) * 3.0
		tw.tween_property(p, "position", base, 0.52)
		tw.tween_property(p, "rotation_degrees", 0.0, 0.52)
	tw.tween_property(p, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)
	_play("thump", -4.0)
	return p


func _exit_panel(key: String, dir: String = "up") -> void:
	var p: ComicPanel = _p.get(key, null)
	_p.erase(key)
	if p == null or not is_instance_valid(p):
		return
	var off: Vector2 = {"left": Vector2(-96, 0), "right": Vector2(96, 0), "up": Vector2(0, -72), "down": Vector2(0, 84)}.get(dir, Vector2.ZERO)
	var tw := p.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "position", p.position + off, 0.38)
	tw.tween_property(p, "modulate", Color(0, 0, 0, 0), 0.38)
	tw.tween_property(p, "scale", Vector2(0.96, 0.96), 0.38)
	tw.chain().tween_callback(p.queue_free)


func _shake(p: ComicPanel, dur: float, amp: float) -> void:
	if p == null:
		return
	var base := p.position
	var tw := p.create_tween()
	var steps := 12
	for i in range(steps):
		var off := Vector2(ComicPanel.hash2(i, 1, dur) - 0.5, ComicPanel.hash2(i, 2, dur) - 0.5) * amp
		tw.tween_property(p, "position", base + off, dur / (steps + 1))
	tw.tween_property(p, "position", base, dur / (steps + 1))


## Teks efek suara komik: huruf muncul satu-satu dengan pantulan
func _sfx(text: String, pos: Vector2, o: Dictionary = {}) -> void:
	var size: float = o.get("size", 90.0)
	var taper: float = o.get("taper", 0.0)
	var stagger: float = o.get("stagger", 0.045)
	var box := Control.new()
	box.position = pos
	box.rotation_degrees = o.get("rot", 0.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(box)
	var x := 0.0
	for i in range(text.length()):
		var ch := text[i]
		var fs := int(size * maxf(0.45, 1.0 - i * taper))
		var ls := LabelSettings.new()
		ls.font = FONT_FX
		ls.font_size = fs
		ls.font_color = o.get("color", Color(1.0, 0.83, 0.3))
		ls.outline_size = int(o.get("sw", 8))
		ls.outline_color = Color(0.043, 0.035, 0.063)
		ls.shadow_color = o.get("shadow", Color(0.043, 0.035, 0.063))
		ls.shadow_offset = Vector2(0, o.get("ex", 7))
		ls.shadow_size = int(o.get("sw", 8))
		var l := Label.new()
		l.text = ch
		l.label_settings = ls
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		var w := FONT_FX.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		l.size = l.get_minimum_size()
		l.position = Vector2(x, (size - fs) * 0.82)
		l.pivot_offset = l.size * 0.5
		x += w + size * 0.02
		l.scale = Vector2(0.2, 0.2)
		l.modulate.a = 0.0
		var tw := l.create_tween()
		tw.tween_interval(i * stagger)
		tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "modulate:a", 1.0, 0.15)
		tw.tween_property(l, "scale", Vector2.ONE, 0.14)
		if o.get("wobble", false):
			var y0 := l.position.y
			var wt := l.create_tween().set_loops()
			wt.tween_interval(0.4 + i * 0.03)
			wt.tween_property(l, "position:y", y0 + (5.0 if i % 2 else -5.0), 0.21).set_trans(Tween.TRANS_SINE)
			wt.tween_property(l, "position:y", y0, 0.21).set_trans(Tween.TRANS_SINE)
	var out := box.create_tween()
	out.tween_interval(o.get("dur", 2.2))
	out.tween_property(box, "modulate:a", 0.0, 0.3)
	out.parallel().tween_property(box, "position:y", pos.y - 14.0, 0.3)
	out.tween_callback(box.queue_free)


func _flash(col: Color, dur: float) -> void:
	var r := ColorRect.new()
	r.color = col
	r.size = DESIGN
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(r)
	r.modulate.a = 0.85
	var tw := r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, dur)
	tw.tween_callback(r.queue_free)


func _name_card(pos: Vector2, title: String, sub: String) -> Control:
	var box := Control.new()
	box.position = pos
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(box)
	var nm := Label.new()
	nm.text = title
	var ls := LabelSettings.new()
	ls.font = FONT_FX
	ls.font_size = 150
	ls.font_color = Color(1.0, 0.7, 0.28)
	ls.outline_size = 12
	ls.outline_color = Color(0.07, 0.04, 0.02)
	ls.shadow_color = Color(0.48, 0.18, 0.03)
	ls.shadow_offset = Vector2(0, 10)
	ls.shadow_size = 12
	nm.label_settings = ls
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nm.size = Vector2(460, 150)
	nm.pivot_offset = Vector2(460, 150)
	nm.rotation_degrees = -4.0
	box.add_child(nm)
	var rib := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.02)
	sb.set_border_width_all(3)
	sb.border_color = PAPER
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	rib.add_theme_stylebox_override("panel", sb)
	var sl := Label.new()
	sl.text = sub
	var ss := LabelSettings.new()
	ss.font = FONT_BOLD
	ss.font_size = 22
	ss.font_color = PAPER
	sl.label_settings = ss
	rib.add_child(sl)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rib)
	rib.position = Vector2(460 - rib.get_combined_minimum_size().x, 158)
	rib.pivot_offset = rib.get_combined_minimum_size()
	rib.rotation_degrees = -2.0
	box.modulate.a = 0.0
	var start := pos + Vector2(260, 0)
	box.position = start
	var tw := box.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "position", pos, 0.56)
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	return box


func _hide_node(n: Control, dx: float = 80.0) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 0.0, 0.26)
	tw.tween_property(n, "position:x", n.position.x + dx, 0.26)
	tw.chain().tween_callback(n.queue_free)


func _on_ecg_beat(i: int) -> void:
	_play("beep", -6.0)
	_sfx("tit...", Vector2(640 + (170 if i % 2 else -300), 250),
			{"size": 58.0, "color": Color(0.24, 0.9, 0.82), "shadow": Color(0.04, 0.35, 0.33), "sw": 6, "ex": 5, "dur": 1.1, "stagger": 0.06})


# ================================================================ judul akhir

func _show_title() -> void:
	_flash(Color(1.0, 0.96, 0.86), 0.9)
	var text := "INTO THE LIGHT"
	var fs := 96
	var spacing := fs * 0.12
	var widths: Array[float] = []
	var total := 0.0
	for ch in text:
		var w := FONT_TITLE.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w + spacing
	total -= spacing
	var k := minf(1.0, 1060.0 / total)
	fs = int(fs * k)
	spacing *= k
	total *= k

	var glow := TextureRect.new()
	glow.texture = _res.glow
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(1400, 420)
	glow.position = Vector2(640 - 700, 128 - 210)
	glow.modulate = Color(1.0, 0.8, 0.45, 0.0)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(glow)
	glow.create_tween().tween_property(glow, "modulate:a", 0.55, 1.6).set_delay(0.3)

	var row := Control.new()
	row.position = Vector2(640 - total * 0.5, 76)
	row.size = Vector2(total, fs * 1.3)
	row.pivot_offset = row.size * 0.5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(row)
	row.scale = Vector2(1.08, 1.08)
	row.create_tween().tween_property(row, "scale", Vector2.ONE, 5.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var x := 0.0
	var mats: Array[ShaderMaterial] = []
	for i in range(text.length()):
		var w: float = widths[i] * k
		var letter := Control.new()
		letter.position = Vector2(x, 0)
		letter.size = Vector2(w, fs * 1.3)
		letter.pivot_offset = letter.size * 0.5
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(letter)
		var back := Label.new()
		back.text = text[i]
		var bs := LabelSettings.new()
		bs.font = FONT_TITLE
		bs.font_size = fs
		bs.font_color = Color(0.16, 0.08, 0.02)
		bs.outline_size = 10
		bs.outline_color = Color(0.1, 0.05, 0.015)
		bs.shadow_color = Color(0.16, 0.08, 0.02)
		bs.shadow_offset = Vector2(0, 5)
		bs.shadow_size = 10
		back.label_settings = bs
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		letter.add_child(back)
		var front := Label.new()
		front.text = text[i]
		var fls := LabelSettings.new()
		fls.font = FONT_TITLE
		fls.font_size = fs
		fls.font_color = Color.WHITE
		front.label_settings = fls
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = _res.title_shader
		m.set_shader_parameter("x0", x / total)
		m.set_shader_parameter("x1", (x + w) / total)
		m.set_shader_parameter("letter_w", maxf(w, 1.0))
		m.set_shader_parameter("shine", -0.4)
		front.material = m
		mats.append(m)
		letter.add_child(front)
		letter.modulate.a = 0.0
		letter.scale = Vector2(1.25, 1.25)
		var tw := letter.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(letter, "modulate:a", 1.0, 1.1).set_delay(0.2 + i * 0.09)
		tw.tween_property(letter, "scale", Vector2.ONE, 1.1).set_delay(0.2 + i * 0.09)
		x += w + spacing

	var shine := create_tween()
	shine.tween_interval(0.9)
	shine.tween_method(func(v: float) -> void:
		for m in mats:
			m.set_shader_parameter("shine", v), -0.4, 1.4, 3.2).set_trans(Tween.TRANS_SINE)

	var rule := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.width = 256
	gt.height = 4
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gg.colors = PackedColorArray([Color(1, 0.88, 0.54, 0), Color(1, 0.88, 0.54, 1), Color(1, 0.88, 0.54, 0)])
	gt.gradient = gg
	rule.texture = gt
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.position = Vector2(640, 76 + fs * 1.3 + 6)
	rule.size = Vector2(0, 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(rule)
	var rt := rule.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(rule, "size:x", 760.0, 1.6).set_delay(1.2)
	rt.tween_property(rule, "position:x", 640.0 - 380.0, 1.6).set_delay(1.2)


# ================================================================ selesai

## Layar memutih lalu masuk ke level pertama (sama seperti transisi main menu)
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
	rect.color = LIGHT_WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0.0
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var t := layer.create_tween()
	t.tween_property(rect, "modulate:a", 1.0, fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_go_next)
	t.tween_interval(0.15)
	t.tween_property(rect, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(layer.queue_free)


func _go_next() -> void:
	_restore_window()
	var next := NEXT_FALLBACK
	var rs := get_node_or_null("/root/RunState")
	if rs and "run_start_scene" in rs and rs.run_start_scene != "":
		next = rs.run_start_scene
	get_tree().change_scene_to_file(next)


# ================================================================ naskah

func _run() -> void:
	await get_tree().process_frame
	# --- layar hitam: monitor jantung
	_amb.mode = &"rain"
	_loop_to(_rain, 0.35, 1.2)
	_ecg.start()
	if await _wait(2.9): return
	if await _say("???", "Fiora... bangun."): return
	_ecg.stop()
	_loop_to(_rain, 0.15, 2.0)

	# --- mata terbuka
	_p["A"] = _panel(&"eyes", Rect2(190, 100, 900, 390))
	if await _wait(0.7): return
	_play("drip")
	_sfx("drip", Vector2(1010, 70), {"size": 52.0, "color": Color(0.75, 0.9, 1.0), "shadow": Color(0.16, 0.35, 0.48), "sw": 6, "ex": 5, "rot": 6.0, "dur": 1.2})
	if await _wait(1.9): return
	if await _say("???", "Kau tidak boleh tidur di sini. Tidak lagi."): return

	# --- terbaring, lalu duduk
	_dlg.hide_box()
	_exit_panel("A", "up")
	_amb.mode = &"dust"
	_loop_to(_drone, 0.3, 2.0)
	_p["B"] = _panel(&"lying", Rect2(36, 40, 800, 450), "left")
	if await _wait(0.9): return
	_play("drip")
	_sfx("drip...", Vector2(420, 20), {"size": 46.0, "color": Color(0.75, 0.9, 1.0), "shadow": Color(0.16, 0.35, 0.48), "sw": 6, "ex": 5, "dur": 1.3})
	if await _wait(1.5): return
	_p["C"] = _panel(&"sit", Rect2(864, 58, 380, 472), "right", 2)
	if await _wait(0.5): return
	_sfx("ngh...", Vector2(900, 20), {"size": 62.0, "color": Color(1.0, 0.79, 0.29), "shadow": Color(0.54, 0.29, 0.06), "rot": -6.0, "dur": 1.5})
	if await _wait(0.9): return
	if await _say("Fiora", "Siapa... kau? Di mana ini?"): return

	# --- Elian muncul
	_dlg.hide_box()
	_exit_panel("B", "left")
	_exit_panel("C", "right")
	if await _wait(0.25): return
	_p["D"] = _panel(&"elian", Rect2(40, 26, 1200, 510))
	_flash(Color(1.0, 0.85, 0.54), 0.42)
	_play("clink")
	_sfx("KLANK!", Vector2(150, 60), {"size": 120.0, "color": Color(1.0, 0.83, 0.3), "shadow": Color(0.7, 0.31, 0.05), "rot": -8.0, "dur": 1.6})
	if await _wait(0.5): return
	var card := _name_card(Vector2(760, 250), "ELIAN", "PENJAGA LENTERA · DASAR KASTIL")
	if await _wait(1.7): return
	if await _say("Elian", "Namaku Elian. Dan ini... dasar dari segalanya."): return
	_hide_node(card)
	if await _say("Elian", "Tempat orang-orang yang tertidur terlalu lama."): return

	# --- ingatan tertinggal di atas
	_exit_panel("D", "up")
	_dlg.hide_box()
	_p["E"] = _panel(&"fiora_sad", Rect2(40, 40, 600, 484), "left")
	if await _wait(0.6): return
	if await _say("Fiora", "Aku tidak ingat apa-apa. Bahkan bagaimana aku sampai di sini."): return
	_p["F"] = _panel(&"elian_point", Rect2(640, 40, 600, 484), "right")
	if await _wait(0.4): return
	if await _say("Elian", "Itu wajar. Ingatanmu tertinggal di atas sana. (menunjuk ke atas)"): return

	# --- menara
	_dlg.hide_box()
	_exit_panel("E", "left")
	_exit_panel("F", "right")
	if await _wait(0.2): return
	_p["G"] = _panel(&"tower", Rect2(465, 14, 350, 522), "down")
	var shimmer := create_tween()
	shimmer.tween_interval(4.4)
	shimmer.tween_callback(func() -> void:
		if not _done and _p.has("G"):
			_play("shimmer")
			_sfx("SHIIING", Vector2(830, 40), {"size": 70.0, "color": Color(1.0, 0.96, 0.8), "shadow": Color(0.72, 0.54, 0.16), "rot": -10.0, "dur": 1.8, "taper": 0.06}))
	if await _wait(2.3): return
	if await _say("Elian", "Lihat cahaya itu? Kau harus mencapainya, Fiora."): return
	if await _say("Elian", "Sebelum kegelapan di sini menelanmu."): return

	# --- kegelapan merayap, Norchthex mengintai
	_dlg.hide_box()
	_exit_panel("G", "up")
	_amb.mode = &"smoke"
	_p["H"] = _panel(&"dark", Rect2(40, 26, 1200, 510))
	_play("rumble", -2.0)
	_loop_to(_drone, 0.55, 1.0)
	if await _wait(0.9): return
	_sfx("SSSHHHHHH", Vector2(50, 380), {"size": 130.0, "color": Color(0.71, 0.49, 1.0), "shadow": Color(0.23, 0.08, 0.37), "rot": -5.0, "dur": 3.4, "taper": 0.07, "wobble": true})
	_shake(_p["H"], 0.9, 12.0)
	if await _wait(1.5): return
	_p["H2"] = _panel(&"norch", Rect2(880, 16, 372, 250), "pop", 3)
	_play("crack")
	_sfx("KRRK", Vector2(820, 220), {"size": 70.0, "color": Color(0.24, 0.9, 0.82), "shadow": Color(0.04, 0.35, 0.33), "rot": 12.0, "dur": 1.4})
	if await _wait(1.9): return
	if await _say("Fiora", "Kau tahu namaku..."): return

	# --- percakapan dua panel miring
	_exit_panel("H", "down")
	_exit_panel("H2", "up")
	_amb.mode = &"dust"
	_loop_to(_drone, 0.3, 2.0)
	if await _wait(0.15): return
	_p["I1"] = _panel(&"two_f", Rect2(40, 26, 660, 510), "left", 0,
			{"shape": PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.9, 1), Vector2(0, 1)])})
	_p["I2"] = _panel(&"two_e", Rect2(580, 26, 660, 510), "right", 0,
			{"shape": PackedVector2Array([Vector2(0.1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])})
	if await _wait(0.5): return
	if await _say("Elian", "(jeda) Aku sudah lama menunggumu bangun."): return
	if await _say("Fiora", "Kalau begitu ikut aku."): return
	if await _say("Elian", "Tempatku bukan di sini. Aku hanya bisa memanggilmu."): return
	if await _say("Elian", "Tapi selama kau mendengar suaraku, kau tidak sendirian."): return

	# --- lentera berpindah tangan, Elian memudar
	_dlg.hide_box()
	_exit_panel("I1", "left")
	_exit_panel("I2", "right")
	if await _wait(0.2): return
	_p["J"] = _panel(&"hands", Rect2(280, 60, 720, 404))
	if await _wait(1.3): return
	_play("clink")
	_sfx("KLINK", Vector2(900, 40), {"size": 84.0, "color": Color(1.0, 0.83, 0.3), "shadow": Color(0.7, 0.31, 0.05), "rot": 8.0, "dur": 1.5})
	if await _wait(1.6): return
	_exit_panel("J", "up")
	_p["K"] = _panel(&"fade", Rect2(40, 26, 1200, 510))
	if await _wait(0.7): return
	_play("whoosh")
	_sfx("FWOOSH", Vector2(820, 40), {"size": 100.0, "color": Color(1.0, 0.89, 0.66), "shadow": Color(0.63, 0.35, 0.1), "rot": -6.0, "dur": 2.6, "taper": 0.05, "stagger": 0.07})
	if await _wait(1.3): return
	if await _say("Elian (memudar)", "Naiklah. Jangan menoleh ke bawah."): return

	# --- judul
	_dlg.hide_box()
	_exit_panel("K", "up")
	_amb.mode = &"light"
	_loop_to(_drone, 0.0, 3.0)
	_loop_to(_rain, 0.1, 2.0)
	if await _wait(0.2): return
	_p["L"] = _panel(&"finale", Rect2(40, 26, 1200, 510), "pop", 0)
	if await _wait(1.3): return
	_play("sting")
	_show_title()
	if await _wait(5.6): return
	_finish(1.4)


# ================================================================ kelas bantu

## Partikel yang melayang di sela-sela panel (hujan, bara, asap, cahaya)
class Ambient extends Control:
	var glow: Texture2D
	var mode: StringName = &"dust"
	var _parts: Array = []
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in range(110):
			_parts.append([rng.randf() * 1280.0, rng.randf() * 720.0, rng.randf(), i])

	func _process(delta: float) -> void:
		_t += delta
		var k := delta * 60.0
		for p in _parts:
			var s: float = p[2]
			match mode:
				&"rain":
					p[1] += (11.0 + s * 7.0) * k
					p[0] += 2.4 * k
					if p[1] > 720.0:
						p[1] = -20.0
						p[0] = randf() * 1280.0
				&"dust":
					p[1] -= (0.2 + s * 0.35) * k
					p[0] += sin(_t * 0.5 + p[3]) * 0.3 * k
				&"smoke":
					p[1] -= (0.8 + s * 1.4) * k
					p[0] += sin(_t + p[3]) * 1.2 * k
				_:
					p[1] -= (0.9 + s * 1.6) * k
					p[0] += sin(_t * 0.8 + p[3]) * 0.6 * k
			if p[1] < -20.0:
				p[1] = 740.0
				p[0] = randf() * 1280.0
		queue_redraw()

	func _draw() -> void:
		for p in _parts:
			var s: float = p[2]
			var pos := Vector2(p[0], p[1])
			if mode == &"rain":
				draw_line(pos, pos + Vector2(-4, 16), Color(0.67, 0.78, 0.94, 0.1 + s * 0.22), 1.5, true)
				continue
			var col: Color
			var r: float
			match mode:
				&"dust":
					col = Color(1.0, 0.75, 0.43, (0.2 + s * 0.5) * (0.6 + 0.4 * sin(_t * 2.0 + p[3])))
					r = 1.0 + s * 2.2
				&"smoke":
					col = Color(0.59, 0.35, 0.9, 0.12 + s * 0.15) if s > 0.8 else Color(0.27, 0.12, 0.43, 0.12 + s * 0.15)
					r = 3.0 + s * 9.0
				_:
					col = Color(1.0, 0.89, 0.63, 0.35 + s * 0.55)
					r = 1.0 + s * 2.6
			draw_texture_rect(glow, Rect2(pos - Vector2(r, r) * 2.5, Vector2(r, r) * 5.0), false, col)


## Garis monitor jantung di layar hitam pembuka
class Ecg extends Control:
	signal beat(index: int)
	const PERIOD := 1.25
	var _on: bool = false
	var _t: float = 0.0
	var _last: int = -1
	var _pts: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func start() -> void:
		_on = true
		_t = 0.0
		_last = -1
		_pts.clear()
		modulate.a = 1.0
		visible = true

	func stop() -> void:
		_on = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.9)
		tw.tween_callback(hide)

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		if _on:
			var ph := fmod(_t, PERIOD) / PERIOD
			var b := int(_t / PERIOD)
			if b != _last and ph > 0.45:
				_last = b
				beat.emit(b)
			var y := 120.0
			if ph > 0.45 and ph < 0.5:
				y = 120.0 - (ph - 0.45) / 0.05 * 80.0
			elif ph >= 0.5 and ph < 0.55:
				y = 40.0 + (ph - 0.5) / 0.05 * 130.0
			elif ph >= 0.55 and ph < 0.6:
				y = 170.0 - (ph - 0.55) / 0.05 * 50.0
			_pts.append([fmod(_t * 280.0, 1280.0), y, _t])
		while not _pts.is_empty() and _t - _pts[0][2] > 2.2:
			_pts.pop_front()
		queue_redraw()

	func _draw() -> void:
		for i in range(1, _pts.size()):
			var a: Array = _pts[i - 1]
			var b: Array = _pts[i]
			if b[0] < a[0]:
				continue
			var al: float = 1.0 - (_t - b[2]) / 2.2
			draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), Color(0.24, 0.9, 0.82, al * 0.25), 12.0, true)
			draw_line(Vector2(a[0], a[1]), Vector2(b[0], b[1]), Color(0.24, 0.9, 0.82, al), 4.0, true)
		if _on and not _pts.is_empty():
			var last: Array = _pts[-1]
			draw_circle(Vector2(last[0], last[1]), 12.0, Color(0.24, 0.9, 0.82, 0.25))
			draw_circle(Vector2(last[0], last[1]), 6.0, Color(0.9, 1.0, 0.98))


## Kotak dialog bawah: portrait, nama, teks mengetik, segitiga "lanjut"
class DialogBox extends Control:
	signal line_done
	const NAVY_TOP := Color(0.078, 0.11, 0.25)
	const NAVY := Color(0.05, 0.078, 0.19)
	const PAPER := Color(0.957, 0.937, 0.894)
	const DIM := "#9aa0bf"
	const POR := 114.0

	var cutscene
	var _por: TextureRect
	var _por_frame: Control
	var _q: Label
	var _name: Label
	var _text: RichTextLabel
	var _spk: Dictionary = {}
	var _shown: bool = false
	var _typing: bool = false
	var _vis: float = 0.0
	var _pause: float = 0.0
	var _total: int = 0
	var _auto: bool = false
	var _auto_t: float = 0.0
	var _t: float = 0.0
	var _res: Dictionary
	var _por_col := Color.WHITE

	func build(res: Dictionary, font_fx: Font, font_body: Font) -> void:
		_res = res
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0
		_por_frame = Control.new()
		_por_frame.size = Vector2(POR, POR)
		_por_frame.draw.connect(func() -> void:
			_por_frame.draw_rect(Rect2(-7, -7, POR + 14, POR + 14), Color.BLACK)
			_por_frame.draw_rect(Rect2(-4, -4, POR + 8, POR + 8), _por_col))
		add_child(_por_frame)
		_por = TextureRect.new()
		_por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_por.size = Vector2(POR, POR)
		_por.clip_contents = true
		_por_frame.add_child(_por)
		_q = Label.new()
		_q.text = "?"
		var qs := LabelSettings.new()
		qs.font = font_fx
		qs.font_size = 72
		qs.font_color = Color(0.35, 0.38, 0.5)
		_q.label_settings = qs
		_q.size = Vector2(POR, POR)
		_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_por_frame.add_child(_q)

		_name = Label.new()
		var ns := LabelSettings.new()
		ns.font = font_fx
		ns.font_size = 32
		ns.outline_size = 6
		ns.outline_color = Color.BLACK
		_name.label_settings = ns
		_name.size = Vector2(1000, 36)
		add_child(_name)

		_text = RichTextLabel.new()
		_text.bbcode_enabled = true
		_text.scroll_active = false
		_text.size = Vector2(1000, 96)
		_text.add_theme_font_override("normal_font", font_body)
		var it := FontVariation.new()
		it.base_font = font_body
		it.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		_text.add_theme_font_override("italics_font", it)
		_text.add_theme_font_size_override("normal_font_size", 28)
		_text.add_theme_font_size_override("italics_font_size", 28)
		_text.add_theme_color_override("default_color", PAPER)
		_text.add_theme_constant_override("line_separation", -2)
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_text)

	func show_line(spk: Dictionary, text: String, auto: bool) -> void:
		_spk = spk
		_auto = auto
		var right: bool = spk.side == 1
		_por_col = spk.col
		_por.texture = _res.tex.get(spk.por, null)
		_por.modulate = Color.BLACK if spk.get("sil", false) else Color.WHITE
		_q.visible = spk.get("sil", false)
		_name.text = spk.name
		_name.label_settings.font_color = spk.col
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		var pad := 12.0 + 7.0
		_por_frame.position = Vector2(size.x - pad - POR, (size.y - POR) * 0.5) if right else Vector2(pad, (size.y - POR) * 0.5)
		var tx := 24.0 if right else pad + POR + 22.0
		var tw := size.x - POR - pad - 22.0 - 24.0
		_name.position = Vector2(tx, 10)
		_name.size.x = tw
		_text.position = Vector2(tx, 46)
		_text.size.x = tw
		# arahan panggung "(...)" ditulis miring dan redup
		var bb := ""
		var rx := RegEx.new()
		rx.compile("\\(([^)]*)\\)")
		var last := 0
		for m in rx.search_all(text):
			bb += text.substr(last, m.get_start() - last)
			bb += "[i][color=%s](%s)[/color][/i]" % [DIM, m.get_string(1)]
			last = m.get_end()
		bb += text.substr(last)
		_text.text = ("[right]%s[/right]" % bb) if right else bb
		_text.visible_characters = 0
		_total = _text.get_total_character_count()
		_vis = 0.0
		_pause = 0.0
		_typing = true
		_auto_t = 0.0
		_por_frame.queue_redraw()
		if not _shown:
			_shown = true
			var t := create_tween().set_parallel(true)
			position.y = 572
			t.tween_property(self, "modulate:a", 1.0, 0.18)
			t.tween_property(self, "position:y", 556.0, 0.18)

	func hide_box() -> void:
		if not _shown:
			return
		_shown = false
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.18)
		t.tween_property(self, "position:y", 572.0, 0.18)

	func advance() -> void:
		if not _shown or _spk.is_empty():
			return
		if _typing:
			_finish_typing()
		else:
			_spk = {}
			line_done.emit()

	func _finish_typing() -> void:
		_typing = false
		_text.visible_characters = -1
		_auto_t = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _spk.is_empty():
			return
		if _spk.get("fade", false):
			_por.modulate.a = 0.55 + 0.25 * sin(_t * 4.0)
		if _typing:
			if _pause > 0.0:
				_pause -= delta
			else:
				var before := int(_vis)
				_vis += delta / 0.03
				var now := mini(int(_vis), _total)
				var parsed := _text.get_parsed_text()
				for i in range(before, now):
					if i % 2 == 1 and i < parsed.length() and parsed[i] != " ":
						cutscene._play(_spk.blip, -14.0)
					if i < parsed.length() and parsed[i] in ".?!,":
						_pause = 0.14 if parsed[i] == "," else 0.26
						now = i + 1
						_vis = now
						break
				_text.visible_characters = now
				if now >= _total:
					_finish_typing()
		elif _auto:
			_auto_t += delta
			if _auto_t > 1.3 + _total * 0.032:
				advance()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(-9, -9), size + Vector2(18, 18)), Color.BLACK)
		draw_rect(Rect2(Vector2(-6, -6), size + Vector2(12, 12)), PAPER)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
				PackedColorArray([NAVY_TOP, NAVY_TOP, NAVY, NAVY]))
		if not _typing and not _spk.is_empty():
			var right: bool = _spk.side == 1
			var x := 32.0 if right else size.x - 32.0
			var y := size.y - 22.0 + 3.0 * sin(_t * 9.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 9, y - 6), Vector2(x + 9, y - 6), Vector2(x, y + 6)]), Color(1.0, 0.79, 0.29))
