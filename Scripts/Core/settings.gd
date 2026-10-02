extends Node
## Pengaturan pemain yang disimpan di user://settings.cfg: volume (master, musik,
## efek suara), layar penuh, tombol keyboard tiap aksi, dan kesulitan terakhir.
## Didaftarkan sebagai autoload "Settings" setelah Audio, supaya volume musik
## diteruskan lewat Audio (yang juga meredam musik saat game di-pause).

signal changed

const PATH := "user://settings.cfg"
## Aksi yang tombolnya bisa diganti, urut seperti di menu Kontrol
const REBINDABLE: Array[Dictionary] = [
	{"action": &"Left", "label": "Kiri"},
	{"action": &"Right", "label": "Kanan"},
	{"action": &"Up", "label": "Atas / buka peti"},
	{"action": &"Down", "label": "Bawah"},
	{"action": &"Jump", "label": "Lompat"},
	{"action": &"Attack", "label": "Serang"},
	{"action": &"Dash", "label": "Dash"},
]
const VOLUME_BUSES := {"master": &"Master", "music": &"Music", "sfx": &"SFX"}

## 0..1 per bus
var volumes := {"master": 1.0, "music": 1.0, "sfx": 1.0}
var fullscreen := false
## RunState.Difficulty terakhir yang dipilih di main menu
var difficulty: int = RunState.Difficulty.NORMAL

## Volume bawaan bus dari default_bus_layout.tres; slider 100% = nilai ini
var _base_db := {}
## Tombol bawaan dari project.godot, untuk "Kembalikan default"
var _default_keys := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in VOLUME_BUSES:
		var idx := AudioServer.get_bus_index(VOLUME_BUSES[key])
		_base_db[key] = AudioServer.get_bus_volume_db(idx) if idx != -1 else 0.0
	for a in REBINDABLE:
		_default_keys[a["action"]] = _key_of(a["action"])
	_load()
	RunState.difficulty = difficulty as RunState.Difficulty
	for key in VOLUME_BUSES:
		_apply_volume(key)
	_apply_fullscreen()


# ---------------------------------------------------------------- suara & layar

func set_volume(key: String, value: float) -> void:
	volumes[key] = clampf(value, 0.0, 1.0)
	_apply_volume(key)
	save()
	changed.emit()


func _apply_volume(key: String) -> void:
	var idx := AudioServer.get_bus_index(VOLUME_BUSES[key])
	if idx == -1:
		return
	var v: float = volumes[key]
	AudioServer.set_bus_mute(idx, v <= 0.001)
	var db: float = _base_db[key] + linear_to_db(maxf(v, 0.001))
	if key == "music":
		Audio.set_music_volume_db(db)
	else:
		AudioServer.set_bus_volume_db(idx, db)


## Layar penuh hanya masuk akal di desktop
func can_fullscreen() -> bool:
	return OS.has_feature("pc")


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	save()
	changed.emit()


func _apply_fullscreen() -> void:
	if not can_fullscreen():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


# ---------------------------------------------------------------- kesulitan

func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, RunState.DIFFICULTY_NAMES.size() - 1)
	RunState.difficulty = difficulty as RunState.Difficulty
	save()
	changed.emit()


# ---------------------------------------------------------------- tombol

## Nama tombol keyboard sebuah aksi, mis. "A", "Space", "Shift"
func key_name(action: StringName) -> String:
	var code := _key_of(action)
	if code == KEY_NONE:
		return "-"
	var key := DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(key if key != KEY_NONE else code)


## Ganti tombol sebuah aksi. Aksi lain yang sudah memakai tombol itu ditukar
## ke tombol lama, supaya tidak ada dua aksi yang berbagi tombol.
func rebind(action: StringName, code: Key) -> void:
	var old := _key_of(action)
	for a in REBINDABLE:
		if a["action"] != action and _key_of(a["action"]) == code:
			_set_key(a["action"], old)
	_set_key(action, code)
	save()
	changed.emit()


func reset_keys() -> void:
	for action in _default_keys:
		_set_key(action, _default_keys[action])
	save()
	changed.emit()


func _key_of(action: StringName) -> Key:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	return KEY_NONE


func _set_key(action: StringName, code: Key) -> void:
	if code == KEY_NONE or not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- simpan

func save() -> void:
	var cfg := ConfigFile.new()
	for key in volumes:
		cfg.set_value("audio", key, volumes[key])
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "difficulty", difficulty)
	for a in REBINDABLE:
		cfg.set_value("keys", String(a["action"]), int(_key_of(a["action"])))
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in volumes:
		volumes[key] = clampf(float(cfg.get_value("audio", key, volumes[key])), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	difficulty = clampi(int(cfg.get_value("game", "difficulty", difficulty)), 0, RunState.DIFFICULTY_NAMES.size() - 1)
	for a in REBINDABLE:
		var code := int(cfg.get_value("keys", String(a["action"]), KEY_NONE))
		if code != KEY_NONE:
			_set_key(a["action"], code as Key)
