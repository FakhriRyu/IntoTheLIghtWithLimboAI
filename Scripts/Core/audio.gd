extends Node
## Pemutar audio global (autoload "Audio"): musik latar dengan crossfade dan
## efek suara satu-kali dari pool pemutar. Semua aset berlisensi CC0,
## lihat Assets/audio/CREDITS.md.
##
## Pemakaian:
##   Audio.play_music(&"castle")
##   Audio.play_sfx(&"sword_hit")

const CASTLE_TRACK := "res://Assets/audio/music/within_the_abandoned_castle.mp3"
const CAVE_TRACK := "res://Assets/audio/music/dark_cavern_ambient.ogg"
const BOSS_TRACK := "res://Assets/audio/music/heavy_dungeon.ogg"

## Nama -> daftar putar. Lagu diputar bergantian (acak, tanpa mengulang lagu
## yang baru saja main) dan disambung crossfade, jadi loop pendek satu lagu
## tidak terasa. Lagu pertama adalah ciri khas levelnya.
const MUSIC := {
	&"castle": [CASTLE_TRACK, CAVE_TRACK],
	&"cave": [CAVE_TRACK, CASTLE_TRACK],
	&"boss": [BOSS_TRACK, CAVE_TRACK],
}

## Suara khas tiap musuh, dipilih dari nama scene (lihat enemy_voice)
const ENEMY_VOICES := {
	&"orc": {&"attack": &"orc_attack", &"hurt": &"orc_hurt", &"death": &"orc_death"},
	&"goblin": {&"attack": &"goblin_attack", &"hurt": &"goblin_hurt", &"death": &"goblin_death"},
	&"skull_wolf": {&"attack": &"wolf_growl", &"hurt": &"wolf_hurt", &"death": &"wolf_death"},
	&"skull_wolf_fsm": {&"attack": &"wolf_growl", &"hurt": &"wolf_hurt", &"death": &"wolf_death"},
	&"frogo": {&"attack": &"frog_croak", &"hurt": &"frog_hurt", &"death": &"frog_death"},
	&"norch_thex": {&"attack": &"boss_scream", &"hurt": &"boss_hurt", &"death": &"boss_death"},
}

## Sampel rekaman CC0 yang sudah diolah (lihat tools/build_sfx.py)
const REAL := "res://Assets/audio/sfx/real/"

## Nama -> daftar file. Kalau lebih dari satu, dipilih acak supaya tidak monoton.
const SFX := {
	# --- player
	&"sword_swing": [REAL + "sword_swing_0.wav", REAL + "sword_swing_1.wav", REAL + "sword_swing_2.wav"],
	&"sword_swing_heavy": [REAL + "sword_swing_heavy_0.wav", REAL + "sword_swing_heavy_1.wav"],
	&"sword_hit": [REAL + "sword_hit_0.wav", REAL + "sword_hit_1.wav", REAL + "sword_hit_2.wav"],
	&"sword_hit_heavy": [REAL + "sword_hit_heavy_0.wav", REAL + "sword_hit_heavy_1.wav"],
	&"player_land": [REAL + "land.wav"],
	&"player_dash": [REAL + "dash.wav"],
	&"player_death": [REAL + "player_death.wav"],
	# --- musuh
	&"orc_attack": [REAL + "orc_attack_0.wav", REAL + "orc_attack_1.wav", REAL + "orc_attack_2.wav"],
	&"orc_hurt": [REAL + "orc_hurt_0.wav", REAL + "orc_hurt_1.wav"],
	&"orc_death": [REAL + "orc_death_0.wav", REAL + "orc_death_1.wav"],
	&"goblin_attack": [REAL + "goblin_attack_0.wav", REAL + "goblin_attack_1.wav", REAL + "goblin_attack_2.wav"],
	&"goblin_hurt": [REAL + "goblin_hurt_0.wav", REAL + "goblin_hurt_1.wav", REAL + "goblin_hurt_2.wav"],
	&"goblin_death": [REAL + "goblin_death_0.wav", REAL + "goblin_death_1.wav"],
	&"wolf_growl": [REAL + "wolf_growl_0.wav", REAL + "wolf_growl_1.wav"],
	&"wolf_hurt": [REAL + "wolf_hurt_0.wav", REAL + "wolf_hurt_1.wav"],
	&"wolf_death": [REAL + "wolf_death_0.wav", REAL + "wolf_death_1.wav"],
	&"wolf_lunge": [REAL + "wolf_lunge_0.wav", REAL + "wolf_lunge_1.wav"],
	&"frog_croak": [REAL + "frog_croak.wav"],
	&"frog_hurt": [REAL + "frog_hurt.wav"],
	&"frog_death": [REAL + "frog_death.wav"],
	&"boss_scream": [REAL + "boss_scream.wav"],
	&"boss_crossbow": [REAL + "boss_crossbow.wav"],
	&"boss_crossbow_load": [REAL + "boss_crossbow_load.wav"],
	&"boss_vanish": [REAL + "boss_vanish.wav"],
	&"boss_appear": [REAL + "boss_appear.wav"],
	&"boss_hurt": [REAL + "boss_hurt_0.wav", REAL + "boss_hurt_1.wav"],
	&"boss_death": [REAL + "boss_death.wav"],
	&"trap_snap": [REAL + "trap_snap.wav"],
	&"pickup_light": [
		"res://Assets/audio/sfx/kenney/glass_001.ogg",
		"res://Assets/audio/sfx/kenney/glass_002.ogg",
	],
	&"pickup_xp": [
		"res://Assets/audio/sfx/kenney/pluck_001.ogg",
		"res://Assets/audio/sfx/kenney/pluck_002.ogg",
	],
	&"pickup_heal": ["res://Assets/audio/sfx/kenney/confirmation_001.ogg"],
	&"chest_open": ["res://Assets/audio/sfx/kenney/metalLatch.ogg"],
	&"chest_loot": ["res://Assets/audio/sfx/kenney/handleCoins.ogg"],
	&"mimic": ["res://Assets/audio/sfx/orcGrunt.mp3"],
	&"card_move": ["res://Assets/audio/sfx/kenney/select_002.ogg"],
	&"card_pick": ["res://Assets/audio/sfx/kenney/confirmation_002.ogg"],
	&"level_up": ["res://Assets/audio/sfx/kenney/jingle_level_up.ogg"],
	&"game_over": ["res://Assets/audio/sfx/kenney/jingle_game_over.ogg"],
	&"light_tick": ["res://Assets/audio/sfx/kenney/tick_002.ogg"],
}

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
## Jumlah efek suara yang bisa berbunyi bersamaan
const SFX_VOICES := 10
## Musik diredam sebanyak ini saat game di-pause (layar kartu / akhir run)
const PAUSE_DUCK_DB := -8.0
## Volume musik "diam" saat crossfade
const SILENT_DB := -40.0
## Lama crossfade antar lagu dalam satu daftar putar
const PLAYLIST_FADE := 4.0
## Suara musuh yang lebih jauh dari ini (px dari tengah kamera) tidak dimainkan
const HEAR_RANGE := 900.0
const HEAR_FULL := 260.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
## Pemutar musik yang sedang aktif (a atau b)
var _music_current: AudioStreamPlayer
var _music_track: StringName = &""
## Urutan lagu yang tersisa untuk track aktif, dan lagu yang sedang main
var _queue: Array[String] = []
var _now_playing: String = ""
var _music_tween: Tween

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}
var _ducked: bool = false
## Volume bus Music dari default_bus_layout.tres, acuan saat meredam
var _music_bus_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player(MUSIC_BUS)
	_music_b = _make_player(MUSIC_BUS)
	_music_current = _music_a
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx != -1:
		_music_bus_db = AudioServer.get_bus_volume_db(idx)
	for i in range(SFX_VOICES):
		_voices.append(_make_player(SFX_BUS))


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	add_child(p)
	return p


func _process(_delta: float) -> void:
	_check_playlist()
	# redam musik saat pause, kembalikan saat lanjut
	var paused := get_tree().paused
	if paused != _ducked:
		_ducked = paused
		var idx := AudioServer.get_bus_index(MUSIC_BUS)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, _music_bus_db + (PAUSE_DUCK_DB if paused else 0.0))


## Volume dasar bus Music (dipanggil Settings). Peredaman saat pause tetap
## dihitung dari nilai ini.
func set_music_volume_db(db: float) -> void:
	_music_bus_db = db
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _music_bus_db + (PAUSE_DUCK_DB if _ducked else 0.0))


## Hentikan dan lepas stream saat game ditutup, supaya playback Ogg tidak
## tertinggal di memori ketika engine membersihkan resource.
func _exit_tree() -> void:
	for p in [_music_a, _music_b] + _voices:
		p.stop()
		p.stream = null
	_cache.clear()


# ---------------------------------------------------------------- musik

## Ganti musik dengan crossfade. Track yang sama tidak diulang dari awal,
## jadi musik tetap mengalir saat menara/gua di-generate ulang.
func play_music(track: StringName, fade: float = 1.0) -> void:
	if track == _music_track and _music_current.playing:
		return
	if not MUSIC.has(track):
		push_warning("Audio: musik '%s' tidak ditemukan" % track)
		return
	_music_track = track
	_queue.clear()
	_start_song(_next_song(), fade)


func stop_music(fade: float = 1.0) -> void:
	_music_track = &""
	var p := _music_current
	var t := create_tween()
	t.tween_property(p, "volume_db", SILENT_DB, fade)
	t.tween_callback(p.stop)


## Lagu berikutnya dari daftar putar: antrean diacak ulang kalau habis, dan
## lagu yang baru saja main tidak diulang berturut-turut.
func _next_song() -> String:
	if _queue.is_empty():
		var tracks: Array = MUSIC[_music_track]
		_queue.assign(tracks)
		# lagu pembuka level selalu duluan saat track baru dimulai
		var first: String = _queue.pop_front()
		_queue.shuffle()
		if _now_playing != "" and _queue.size() > 0 and _queue[0] == _now_playing:
			_queue.push_back(_queue.pop_front())
		_queue.push_front(first)
	return _queue.pop_front()


func _start_song(path: String, fade: float) -> void:
	var stream := _load_music(path)
	if stream == null:
		push_warning("Audio: file musik '%s' gagal dimuat" % path)
		return
	_now_playing = path

	var old := _music_current
	var incoming := _music_b if old == _music_a else _music_a
	_music_current = incoming
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, fade)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, fade)
		_music_tween.chain().tween_callback(old.stop)


## Menjelang akhir lagu, sambung ke lagu berikutnya dengan crossfade panjang.
## Lagu tidak di-loop mentah, jadi tidak ada lompatan ke awal yang terdengar.
func _check_playlist() -> void:
	if _music_track == &"" or not _music_current.playing or _music_current.stream == null:
		return
	var length := _music_current.stream.get_length()
	if length <= 0.0:
		return
	var fade := minf(PLAYLIST_FADE, length * 0.25)
	if length - _music_current.get_playback_position() <= fade:
		_start_song(_next_song(), fade)


func _load_music(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	# tanpa daftar putar pun lagu tetap tidak berhenti kalau cuma ada satu
	if stream and "loop" in stream:
		stream.loop = false
	return stream


# ---------------------------------------------------------------- efek suara

## Mainkan efek suara. pitch_jitter mengacak nada sedikit supaya pukulan
## beruntun tidak terdengar identik.
func play_sfx(sfx_name: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.08,
		pitch: float = 1.0) -> void:
	var stream := _sfx_stream(sfx_name)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch + randf_range(-pitch_jitter, pitch_jitter), 0.05)
	p.play()


func _sfx_stream(sfx_name: StringName) -> AudioStream:
	if not SFX.has(sfx_name):
		push_warning("Audio: sfx '%s' tidak terdaftar" % sfx_name)
		return null
	var paths: Array = SFX[sfx_name]
	var path: String = paths[randi() % paths.size()]
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Seperti play_sfx, tapi dari titik di dunia: makin jauh dari kamera makin
## pelan, dan di luar jangkauan tidak dimainkan sama sekali.
func play_sfx_at(sfx_name: StringName, world_pos: Vector2, volume_db: float = 0.0,
		pitch_jitter: float = 0.08, pitch: float = 1.0) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var dist := world_pos.distance_to(cam.get_screen_center_position())
		if dist > HEAR_RANGE:
			return
		volume_db -= 20.0 * clampf((dist - HEAR_FULL) / (HEAR_RANGE - HEAR_FULL), 0.0, 1.0)
	play_sfx(sfx_name, volume_db, pitch_jitter, pitch)


## Suara khas sebuah musuh. event: &"attack", &"hurt", atau &"death".
## Jenis musuh dibaca dari nama file scene-nya (mis. orc.tscn -> "orc"),
## atau dari meta "voice" kalau scene perlu menimpanya.
func enemy_voice(enemy: Node, event: StringName, volume_db: float = 0.0) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var kind: StringName = enemy.get_meta(&"voice", &"")
	if kind == &"":
		kind = StringName(enemy.scene_file_path.get_file().get_basename())
	if not ENEMY_VOICES.has(kind):
		return
	var sfx_name: StringName = ENEMY_VOICES[kind].get(event, &"")
	if sfx_name == &"":
		return
	# bos selalu terdengar penuh, sejauh apa pun dari kamera
	if enemy is Node2D and not enemy.is_in_group(&"boss"):
		play_sfx_at(sfx_name, (enemy as Node2D).global_position, volume_db, 0.06)
	else:
		play_sfx(sfx_name, volume_db, 0.06)
