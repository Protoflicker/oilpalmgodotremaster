extends Node
## Settings (Autoload) — pengaturan global yang berfungsi & tersimpan:
## volume Master/Music/SFX, sensitivitas mouse, dan fullscreen.
## Disimpan ke user://settings.cfg, diterapkan ke AudioServer & DisplayServer.

const CONFIG_PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var mouse_sensitivity: float = 0.075
var fullscreen: bool = false

# Aksi yang bisa di-rebind di Options (urutan tampil).
const REBINDABLE := [
	"move_forward", "move_back", "move_left", "move_right",
	"sprint", "crouch", "jump", "harvest", "throw_stone", "flashlight",
]
# action -> physical_keycode (hanya yang diubah player; sisanya pakai default project.godot)
var keybinds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply_all()
	apply_keybinds()

# ===================== KEYBINDS =====================
func apply_keybinds() -> void:
	for action in keybinds:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = int(keybinds[action]) as Key
		InputMap.action_add_event(action, ev)

func get_keycode_for(action: String) -> int:
	if keybinds.has(action):
		return int(keybinds[action])
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return 0

func key_name_for(action: String) -> String:
	var kc := get_keycode_for(action)
	if kc == 0:
		return "-"
	return OS.get_keycode_string(kc)

func set_keybind(action: String, keycode: int) -> void:
	keybinds[action] = keycode
	apply_keybinds()
	save_settings()

func _ensure_buses() -> void:
	# Buat bus "Music" & "SFX" (kirim ke Master) bila belum ada.
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	apply_fullscreen()

func _apply_bus(bus_name: String, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if vol <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(vol, 0.001, 1.0)))

func set_master(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	save_settings()

func set_music(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	save_settings()

func set_sfx(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	save_settings()

func set_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, 0.01, 0.5)
	save_settings()

func set_fullscreen(b: bool) -> void:
	fullscreen = b
	apply_fullscreen()
	save_settings()

func apply_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("controls", "sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fullscreen", fullscreen)
	for action in keybinds:
		cfg.set_value("keybinds", action, int(keybinds[action]))
	cfg.save(CONFIG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	mouse_sensitivity = float(cfg.get_value("controls", "sensitivity", mouse_sensitivity))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	if cfg.has_section("keybinds"):
		for action in cfg.get_section_keys("keybinds"):
			keybinds[action] = int(cfg.get_value("keybinds", action))
