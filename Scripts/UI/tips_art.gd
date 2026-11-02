extends RefCounted
## Ilustrasi animasi untuk layar Tips Bermain (TipsScreen), dibangun dari sprite
## game sendiri: Fiora, Goblin, kepingan cahaya, bar HUD, kartu upgrade, peti, duri.
## Tiap fungsi page_*() mengisi `stage` (Control berukuran STAGE) dan memasang
## Tween berulang. Semua node mewarisi PROCESS_MODE_ALWAYS dari TipsScreen, jadi
## animasinya tetap jalan walau game di-pause.

const STAGE := Vector2(250, 220)
## Skala sprite karakter di ilustrasi (sprite game aslinya 1x)
const CHAR_SCALE := 2.0
const FLOOR_Y := 150.0

## Sama dengan Pickup.COLORS (Scripts/Items/pickup.gd)
const LIGHT_COLOR := Color(1.0, 0.85, 0.45)
const XP_COLOR := Color(0.4, 0.95, 1.0)
const HEAL_COLOR := Color(1.0, 0.35, 0.4)
## Sama dengan PlayerHUD.light_color / light_danger_color
const BAR_LIGHT := Color(1.0, 0.82, 0.4)
const BAR_DANGER := Color(1.0, 0.25, 0.2)
const XP_BAR := Color(0.4, 0.95, 1.0)

const DOT := preload("res://Assets/FX/particle_dot.png")
const CASTLE := preload("res://Assets/Tiles/CastleTiles.png")
const EXTRA := preload("res://Assets/Tiles/ExtraTiles1.png")
## Sama dengan Chest.CLOSED_REGION; region "terbuka" di game hanya pecahan tutup,
## jadi di ilustrasi peti cukup berkilat & melonjak saat dibuka
const CHEST_CLOSED := Rect2(160, 32, 32, 32)
const SPIKE_REGIONS: Array[Rect2] = [Rect2(192, 56, 16, 8), Rect2(208, 56, 16, 8)]
const BTN_DIR := "res://Assets/button/"
const UI_DIR := "res://Assets/ui/"


# ================================================================ bahan

## SpriteFrames Fiora dari folder Assets/Warrior/<folder>/Warrior_<nama>_<n>.png
static func warrior_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim in [["idle", "idle", "Idle", 8.0, true], ["run", "Run", "Run", 12.0, true],
			["attack", "Attack", "Attack", 18.0, false]]:
		sf.add_animation(anim[0])
		sf.set_animation_speed(anim[0], anim[3])
		sf.set_animation_loop(anim[0], anim[4])
		var i := 1
		while true:
			var path := "res://Assets/Warrior/%s/Warrior_%s_%d.png" % [anim[1], anim[2], i]
			if not ResourceLoader.exists(path):
				break
			sf.add_frame(anim[0], load(path))
			i += 1
	return sf


static func fiora(stage: Control, pos: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = warrior_frames()
	s.scale = Vector2.ONE * CHAR_SCALE
	# titik asal = kaki
	s.offset = Vector2(0, -22)
	s.position = pos
	s.play(&"idle")
	stage.add_child(s)
	return s


## Goblin dari sheet persegi 150x150 (Idle/Take Hit/Death 4 frame)
static func goblin(stage: Control, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://Assets/Goblin/Idle.png")
	s.hframes = 4
	s.flip_h = true
	s.scale = Vector2.ONE * CHAR_SCALE
	s.offset = Vector2(0, -18)
	s.position = pos
	stage.add_child(s)
	return s


static func set_goblin_anim(g: Sprite2D, sheet: String) -> void:
	g.texture = load("res://Assets/Goblin/%s.png" % sheet)
	g.hframes = int(g.texture.get_width() / g.texture.get_height())
	g.frame = 0


## Lantai batu menara (potongan tepi atas CastleTiles), selebar panggung
static func floor_strip(stage: Control, y: float) -> void:
	var x := 0.0
	var i := 0
	while x < STAGE.x:
		var s := Sprite2D.new()
		s.texture = CASTLE
		s.region_enabled = true
		s.region_rect = Rect2(16 if i % 2 else 64, 0, 16, 16)
		s.centered = false
		s.scale = Vector2(2, 2)
		s.position = Vector2(x, y)
		s.modulate = Color(0.75, 0.75, 0.85)
		stage.add_child(s)
		x += 32.0
		i += 1


static func _glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Cahaya lembut (pengganti PointLight2D, karena layer UI tidak diterangi lampu level)
static func glow(color: Color, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _glow_texture()
	s.modulate = color
	s.scale = Vector2.ONE * size / 64.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	return s


## Kepingan / orb seperti Pickup di game
static func orb(stage: Control, color: Color) -> Node2D:
	var n := Node2D.new()
	var g := glow(Color(color, 0.7), 34.0)
	n.add_child(g)
	var s := Sprite2D.new()
	s.texture = DOT
	s.scale = Vector2.ONE * 6.0
	s.modulate = color
	n.add_child(s)
	n.visible = false
	stage.add_child(n)
	return n


static func tex_rect(path: String, pos: Vector2, scale := 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.position = pos
	t.scale = Vector2.ONE * scale
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Bar ala HUD: bingkai + isi; mengembalikan TextureProgressBar isinya
static func hud_bar(stage: Control, frame: String, fill: String, inset: Vector2,
		pos: Vector2, scale: float, tint: Color) -> TextureProgressBar:
	var holder := Control.new()
	holder.position = pos
	holder.scale = Vector2.ONE * scale
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(holder)
	holder.add_child(tex_rect(UI_DIR + frame, Vector2.ZERO))
	var bar := TextureProgressBar.new()
	bar.texture_progress = load(UI_DIR + fill)
	bar.position = inset
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = 1.0
	bar.tint_progress = tint
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	return bar


static func label(stage: Control, text: String, pos: Vector2, color: Color, size := 19) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(l)
	return l


## Lompatan kecil keluar lalu jatuh ke lantai, seperti drop musuh
static func tween_pop(t: Tween, n: Node2D, from: Vector2, to: Vector2, dur := 0.45) -> void:
	t.tween_callback(func() -> void:
		n.position = from
		n.scale = Vector2.ONE
		n.visible = true)
	t.tween_method(func(k: float) -> void:
		n.position = from.lerp(to, k) + Vector2(0, -36.0 * sin(k * PI)), 0.0, 1.0, dur)


# ================================================================ halaman

## 1. Bergerak & bertarung: Fiora lari bolak-balik lalu menebas.
## Di bawah lantai: legenda tombol sentuh, atau nama tombol keyboard.
static func page_move(stage: Control, touch: bool) -> void:
	floor_strip(stage, FLOOR_Y)
	var legend := [["kiri", &"Left", "Kiri"], ["kanan", &"Right", "Kanan"],
		["Jump", &"Jump", "Lompat"], ["Sword", &"Attack", "Serang"], ["Dash", &"Dash", "Dash"]]
	for i in legend.size():
		var x := 9.0 + i * 48.0
		if touch:
			var r := tex_rect(BTN_DIR + legend[i][0] + ".png", Vector2(x, FLOOR_Y + 14), 1.0)
			r.modulate.a = 0.85
			stage.add_child(r)
		else:
			var key := label(stage, Settings.key_name(legend[i][1]), Vector2(x - 8, FLOOR_Y + 18),
				Color(1.0, 0.78, 0.4), 19)
			key.size.x = 48
			key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cap := label(stage, legend[i][2], Vector2(x - 8, FLOOR_Y + 44), Color(0.82, 0.84, 0.9), 15)
		cap.size.x = 48
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var light := glow(Color(1.0, 0.8, 0.45, 0.35), 150.0)
	stage.add_child(light)
	var f := fiora(stage, Vector2(50, FLOOR_Y))
	light.position = f.position + Vector2(0, -24)
	var t := stage.create_tween().set_loops()
	for dir in [1, -1]:
		var target := 200.0 if dir == 1 else 50.0
		t.tween_callback(func() -> void:
			f.flip_h = dir == -1
			f.play(&"run"))
		t.tween_method(func(x: float) -> void:
			f.position.x = x
			light.position.x = x, 50.0 if dir == 1 else 200.0, target, 1.4)
		t.tween_callback(f.play.bind(&"attack"))
		t.tween_interval(0.7)
		t.tween_callback(f.play.bind(&"idle"))
		t.tween_interval(0.5)


## 2. Kalahkan musuh: tebas Goblin, dia menjatuhkan cahaya/XP/HP yang tertarik ke Fiora
static func page_enemy(stage: Control) -> void:
	floor_strip(stage, FLOOR_Y)
	var f := fiora(stage, Vector2(70, FLOOR_Y))
	var g := goblin(stage, Vector2(168, FLOOR_Y))
	var orbs: Array[Node2D] = []
	var colors := [LIGHT_COLOR, LIGHT_COLOR, LIGHT_COLOR, XP_COLOR, XP_COLOR, HEAL_COLOR]
	for c in colors:
		orbs.append(orb(stage, c))
	var t := stage.create_tween().set_loops()
	t.tween_callback(func() -> void:
		set_goblin_anim(g, "Idle")
		g.modulate = Color.WHITE)
	t.tween_property(g, "frame", 3, 0.6).from(0)
	# dua tebasan: kena, lalu tumbang
	for hit in 2:
		t.tween_callback(f.play.bind(&"attack"))
		t.tween_interval(0.3)
		t.tween_callback(func() -> void:
			set_goblin_anim(g, "Take Hit" if hit == 0 else "Death")
			g.modulate = Color(3, 3, 3))
		t.tween_property(g, "modulate", Color.WHITE, 0.15)
		t.tween_property(g, "frame", 3, 0.35).from(0)
		t.tween_callback(f.play.bind(&"idle"))
		t.tween_interval(0.15)
	t.tween_property(g, "modulate:a", 0.0, 0.25)
	# drop melompat keluar dari tempat Goblin tumbang (semua bersamaan)
	var from := Vector2(168, FLOOR_Y - 30)
	for i in orbs.size():
		var o := orbs[i]
		var to := Vector2(132 + i * 12, FLOOR_Y - 8)
		if i > 0:
			t.parallel()
		t.tween_callback(func() -> void:
			o.position = from
			o.visible = true)
		t.parallel().tween_method(func(k: float) -> void:
			o.position = from.lerp(to, k) + Vector2(0, -36.0 * sin(k * PI)), 0.0, 1.0, 0.45)
	t.tween_interval(0.35)
	# lalu tertarik ke Fiora
	for i in orbs.size():
		if i > 0:
			t.parallel()
		t.tween_property(orbs[i], "position", f.position + Vector2(0, -22), 0.35 + i * 0.05) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		for o in orbs:
			o.visible = false
		f.modulate = Color(1.6, 1.4, 1.0))
	t.tween_property(f, "modulate", Color.WHITE, 0.3)
	t.tween_interval(0.6)
	t.tween_callback(func() -> void: set_goblin_anim(g, "Idle"))
	t.tween_property(g, "modulate:a", 1.0, 0.3)


## 3. Jaga cahaya: bar cahaya menyusut, diisi kepingan; kalau habis Fiora padam
static func page_light(stage: Control) -> void:
	var aura := glow(Color(1.0, 0.8, 0.45, 0.55), 170.0)
	aura.position = Vector2(125, 92)
	stage.add_child(aura)
	var f := fiora(stage, Vector2(125, 120))
	var lantern := tex_rect(UI_DIR + "icons/lentera.png", Vector2(8, 158), 2.0)
	stage.add_child(lantern)
	var bar := hud_bar(stage, "hud_bar_light.png", "hud_bar_light_fill.png", Vector2(3, 2),
		Vector2(44, 162), 1.5, BAR_LIGHT)
	var warn := label(stage, "", Vector2(0, 186), BAR_DANGER, 22)
	warn.size.x = STAGE.x
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var o := orb(stage, LIGHT_COLOR)

	var set_light := func(v: float) -> void:
		bar.value = v
		var low := v < 0.25
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		bar.tint_progress = BAR_LIGHT.lerp(BAR_DANGER, pulse) if low else BAR_LIGHT
		aura.modulate.a = 0.15 + 0.45 * v
		aura.scale = Vector2.ONE * (90.0 + 90.0 * v) / 64.0
		f.modulate = Color.WHITE.lerp(Color(0.25, 0.25, 0.35), clampf(1.0 - v * 3.0, 0.0, 1.0))

	var t := stage.create_tween().set_loops()
	t.tween_callback(func() -> void:
		warn.text = ""
		f.play(&"idle"))
	# meredup, lalu diselamatkan kepingan cahaya
	t.tween_method(set_light, 1.0, 0.12, 2.6)
	t.tween_callback(func() -> void: warn.text = "Cahaya hampir padam!")
	tween_pop(t, o, Vector2(230, 40), Vector2(150, 100), 0.5)
	t.tween_property(o, "position", Vector2(125, 96), 0.25)
	t.tween_callback(func() -> void:
		o.visible = false
		warn.text = "")
	t.tween_method(set_light, 0.12, 1.0, 0.4)
	t.tween_interval(0.5)
	# kali ini tidak ada cahaya: padam
	t.tween_method(set_light, 1.0, 0.0, 2.6)
	t.tween_callback(func() -> void: warn.text = "PADAM")
	t.tween_property(f, "modulate:a", 0.0, 0.6)
	t.tween_interval(0.8)
	t.tween_callback(func() -> void: f.modulate.a = 1.0)
	t.tween_method(set_light, 0.0, 1.0, 0.5)
	t.tween_interval(0.3)


## 4. Naik level: bar XP penuh, Lv naik, tiga kartu muncul, satu dipilih
static func page_level(stage: Control) -> void:
	var chip := tex_rect(UI_DIR + "hud_level_chip.png", Vector2(14, 14), 2.0)
	stage.add_child(chip)
	var lv := label(chip, "Lv 1", Vector2(2, -3), Color(0.82, 0.92, 1.0), 15)
	lv.size = Vector2(28, 15)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_theme_constant_override("outline_size", 2)
	var bar := hud_bar(stage, "hud_bar_xp.png", "hud_bar_xp_fill.png", Vector2(1, 1),
		Vector2(90, 24), 1.5, XP_BAR)
	var title := label(stage, "NAIK LEVEL!", Vector2(0, 46), Color(1.0, 0.9, 0.22), 26)
	title.size.x = STAGE.x
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var icons := ["tajam", "lentera", "angin"]
	var cards: Array[Control] = []
	var glow_rect: TextureRect = null
	for i in 3:
		var card := Control.new()
		card.size = Vector2(156, 236)
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2.ONE * 0.36
		card.position = Vector2(125 + (i - 1) * 70, 146) - card.size / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 1:
			glow_rect = tex_rect(UI_DIR + "card_glow.png", Vector2(-6, -6))
			glow_rect.modulate = Color(1.0, 0.86, 0.3, 0.0)
			card.add_child(glow_rect)
		card.add_child(tex_rect(UI_DIR + "card_panel.png", Vector2.ZERO))
		card.add_child(tex_rect(UI_DIR + "card_icon_frame.png", Vector2(46, 30)))
		card.add_child(tex_rect(UI_DIR + "icons/%s.png" % icons[i], Vector2(54, 38), 3.0))
		stage.add_child(card)
		cards.append(card)

	var t := stage.create_tween().set_loops()
	t.tween_callback(func() -> void:
		bar.value = 0.0
		lv.text = "Lv 1"
		title.modulate.a = 0.0
		for c in cards:
			c.modulate.a = 0.0
			c.scale = Vector2.ONE * 0.36
		glow_rect.modulate.a = 0.0)
	t.tween_property(bar, "value", 1.0, 1.3)
	t.tween_callback(func() -> void:
		lv.text = "Lv 2"
		bar.value = 0.0
		chip.scale = Vector2.ONE * 2.6)
	t.tween_property(chip, "scale", Vector2.ONE * 2.0, 0.2)
	t.parallel().tween_property(title, "modulate:a", 1.0, 0.2)
	for i in 3:
		var c := cards[i]
		t.tween_property(c, "modulate:a", 1.0, 0.18)
	t.tween_interval(0.4)
	t.tween_property(cards[1], "scale", Vector2.ONE * 0.42, 0.18)
	t.parallel().tween_property(glow_rect, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(cards[0], "modulate:a", 0.4, 0.18)
	t.parallel().tween_property(cards[2], "modulate:a", 0.4, 0.18)
	t.tween_interval(1.4)


## 5. Peti & bahaya: peti bergoyang lalu terbuka; duri melukai
static func page_chest(stage: Control) -> void:
	floor_strip(stage, FLOOR_Y)
	var chest := Sprite2D.new()
	chest.texture = EXTRA
	chest.region_enabled = true
	chest.region_rect = CHEST_CLOSED
	chest.scale = Vector2(2.5, 2.5)
	chest.offset = Vector2(0, -16)
	chest.position = Vector2(66, FLOOR_Y)
	stage.add_child(chest)
	var orbs: Array[Node2D] = []
	for c in [LIGHT_COLOR, LIGHT_COLOR, HEAL_COLOR, XP_COLOR]:
		orbs.append(orb(stage, c))

	var spikes: Array[Sprite2D] = []
	for i in 3:
		var s := Sprite2D.new()
		s.texture = CASTLE
		s.region_enabled = true
		s.region_rect = SPIKE_REGIONS[i % 2]
		s.centered = false
		s.scale = Vector2(2.5, 2.5)
		s.position = Vector2(150 + i * 32, FLOOR_Y - 20)
		stage.add_child(s)
		spikes.append(s)
	var dmg := label(stage, "-2", Vector2(178, 70), BAR_DANGER, 26)
	dmg.modulate.a = 0.0
	label(stage, "Peti", Vector2(44, FLOOR_Y + 30), Color(0.82, 0.84, 0.9))
	label(stage, "Duri", Vector2(178, FLOOR_Y + 30), Color(0.82, 0.84, 0.9))

	var t := stage.create_tween().set_loops()
	t.tween_callback(func() -> void: chest.modulate = Color.WHITE)
	for i in 2:
		t.tween_property(chest, "rotation", 0.12, 0.08)
		t.tween_property(chest, "rotation", -0.12, 0.12)
		t.tween_property(chest, "rotation", 0.0, 0.08)
		t.tween_interval(0.3)
	t.tween_callback(func() -> void:
		chest.modulate = Color(2.2, 1.9, 1.2)
		chest.scale = Vector2(2.9, 2.2))
	t.tween_property(chest, "scale", Vector2(2.5, 2.5), 0.25).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(chest, "modulate", Color(0.7, 0.7, 0.8), 0.4)
	for i in orbs.size():
		var o := orbs[i]
		var to := Vector2(34 + i * 20, FLOOR_Y - 8)
		var from := Vector2(66, FLOOR_Y - 34)
		t.parallel().tween_callback(func() -> void:
			o.position = from
			o.visible = true)
		t.parallel().tween_method(func(k: float) -> void:
			o.position = from.lerp(to, k) + Vector2(0, -40.0 * sin(k * PI)), 0.0, 1.0, 0.5)
	# duri berkilat merah, angka damage melayang
	t.tween_callback(func() -> void:
		for s in spikes:
			s.modulate = Color(2.5, 0.6, 0.5)
		dmg.position.y = 80
		dmg.modulate.a = 1.0)
	t.tween_property(dmg, "position:y", 52.0, 0.6)
	t.parallel().tween_property(dmg, "modulate:a", 0.0, 0.6).set_delay(0.2)
	for s in spikes:
		t.parallel().tween_property(s, "modulate", Color.WHITE, 0.5)
	t.tween_interval(0.8)
	t.tween_callback(func() -> void:
		for o in orbs:
			o.visible = false)
	t.tween_interval(0.2)


## Riak lingkaran untuk menandai ketukan jari
class Ripple extends Control:
	var radius := 0.0
	var color := Color(1.0, 0.9, 0.55)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_radius(r: float) -> void:
		radius = r
		modulate.a = clampf(1.0 - r / 22.0, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		if radius > 0.0:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.0)
			draw_circle(Vector2.ZERO, 4.0, Color(color, 0.8))


## 6. Atur sesukamu: ketuk tombol jeda, lalu tombol sentuh digeser & diperbesar
static func page_settings(stage: Control) -> void:
	# "layar HP" mini
	var screen := Panel.new()
	screen.position = Vector2(10, 22)
	screen.size = Vector2(230, 150)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(screen)
	var pause := tex_rect(UI_DIR + "btn_pause.png", Vector2(204, 30), 1.0)
	stage.add_child(pause)
	var buttons := {}
	for b in [["kiri", Vector2(22, 136)], ["kanan", Vector2(52, 136)],
			["Sword", Vector2(170, 136)], ["Jump", Vector2(202, 136)], ["Dash", Vector2(202, 104)]]:
		var r := tex_rect(BTN_DIR + b[0] + ".png", b[1], 0.9)
		r.modulate.a = 0.75
		r.pivot_offset = Vector2(16, 16)
		stage.add_child(r)
		buttons[b[0]] = r
	var jump: TextureRect = buttons["Jump"]
	var home := jump.position
	var tap := Ripple.new()
	stage.add_child(tap)
	var caption := label(stage, "", Vector2(0, 182), Color(1.0, 0.9, 0.55), 20)
	caption.size.x = STAGE.x
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t := stage.create_tween().set_loops()
	t.tween_callback(func() -> void:
		caption.text = "Jeda  >  Pengaturan"
		jump.position = home
		jump.scale = Vector2.ONE * 0.9
		tap.position = pause.position + Vector2(11, 11))
	t.tween_interval(0.4)
	t.tween_method(tap.set_radius, 0.0, 22.0, 0.45)
	t.tween_callback(func() -> void:
		pause.modulate = Color(1.6, 1.5, 1.0))
	t.tween_property(pause, "modulate", Color.WHITE, 0.3)
	t.tween_callback(func() -> void:
		caption.text = "Geser & ubah ukuran tombol"
		tap.position = home + Vector2(14, 14))
	t.tween_method(tap.set_radius, 0.0, 10.0, 0.2)
	# jari menyeret Lompat ke atas-kiri lalu membesarkannya
	t.tween_method(func(k: float) -> void:
		jump.position = home.lerp(home + Vector2(-46, -44), k)
		tap.position = jump.position + Vector2(14, 14)
		tap.set_radius(8.0), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_callback(tap.set_radius.bind(0.0))
	t.tween_property(jump, "scale", Vector2.ONE * 1.4, 0.4).set_trans(Tween.TRANS_BACK)
	t.tween_interval(1.2)
	t.tween_property(jump, "modulate:a", 0.0, 0.2)
	t.tween_callback(func() -> void:
		jump.position = home
		jump.scale = Vector2.ONE * 0.9)
	t.tween_property(jump, "modulate:a", 0.75, 0.2)
