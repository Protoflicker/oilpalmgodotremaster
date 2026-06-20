extends Node
## GameState (Autoload)
## Menyimpan progres campaign 4-level, uang terkumpul, dan konfigurasi tiap level
## (waktu hari, kuota buah, jumlah musuh, peluang satwa liar, atmosfer).
## Juga mengatur alur menang/kalah & transisi antar level sesuai flowchart GDD.

signal money_changed(total_money: int)

const TOTAL_LEVELS: int = 4

# Path scene tiap level (index 1..4).
const LEVEL_SCENES := {
	1: "res://Scene/Level.tscn",
	2: "res://Scene/Level2.tscn",
	3: "res://Scene/Level3.tscn",
	4: "res://Scene/Level4.tscn",
}

const MENU_SCENE := "res://Scene/Menu.tscn"

# Konfigurasi tiap level. Tingkat kesulitan, kuota, dan satwa liar meningkat (GDD §8).
# Waktu: Level1 Sore, Level2 Malam, Level3 Tengah Malam, Level4 Dini Hari.
const LEVEL_CONFIG := {
	1: {
		"name": "Level 1 - Sore Hari",
		"time_of_day": "evening",
		"quota_kg": 0,                 # tutorial, bebas eksplorasi tanpa kuota
		"round_duration": 300.0,
		"enemy_count": 0,              # tanpa penghuni kebun
		"enemy_has_flashlight": false,
		"boar_count": 0,
		"snake_enabled": false,
		"tiger_enabled": false,
		"is_tutorial": true,
	},
	2: {
		"name": "Level 2 - Malam Hari",
		"time_of_day": "night",
		"quota_kg": 120,
		"round_duration": 280.0,
		"enemy_count": 1,
		"enemy_has_flashlight": true,
		"boar_count": 1,
		"snake_chance": 0.12,
		"tiger_enabled": false,
		"is_tutorial": false,
	},
	3: {
		"name": "Level 3 - Tengah Malam",
		"time_of_day": "midnight",
		"quota_kg": 200,
		"round_duration": 280.0,
		"enemy_count": 2,
		"enemy_has_flashlight": true,
		"boar_count": 2,
		"snake_chance": 0.2,
		"tiger_enabled": false,
		"has_river": true,
		"is_tutorial": false,
	},
	4: {
		"name": "Level 4 - Dini Hari",
		"time_of_day": "dawn",
		"quota_kg": 300,
		"round_duration": 320.0,
		"enemy_count": 3,
		"enemy_has_flashlight": true,
		"boar_count": 3,
		"snake_chance": 0.3,
		"tiger_enabled": true,
		"has_river": true,
		"is_tutorial": false,
	},
}

# Preset atmosfer per waktu hari (dipakai AtmosphereController).
const TIME_PRESETS := {
	"evening": {
		"sun_energy": 1.1,
		"sun_color": Color(1.0, 0.74, 0.48),
		"ambient_energy": 0.7,
		"ambient_color": Color(0.5, 0.42, 0.45),
		"sky_exposure": 7.0,
		"fog_density": 0.008,
		"fog_color": Color(0.6, 0.46, 0.4),
	},
	"night": {
		"sun_energy": 0.5,
		"sun_color": Color(0.62, 0.7, 0.95),
		"ambient_energy": 0.55,
		"ambient_color": Color(0.22, 0.28, 0.42),
		"sky_exposure": 3.6,
		"fog_density": 0.014,
		"fog_color": Color(0.16, 0.2, 0.3),
	},
	"midnight": {
		"sun_energy": 0.36,
		"sun_color": Color(0.55, 0.62, 0.9),
		"ambient_energy": 0.4,
		"ambient_color": Color(0.15, 0.19, 0.32),
		"sky_exposure": 2.6,
		"fog_density": 0.02,
		"fog_color": Color(0.1, 0.13, 0.22),
	},
	"dawn": {
		"sun_energy": 0.6,
		"sun_color": Color(0.7, 0.7, 0.92),
		"ambient_energy": 0.5,
		"ambient_color": Color(0.28, 0.3, 0.42),
		"sky_exposure": 4.0,
		"fog_density": 0.013,
		"fog_color": Color(0.3, 0.32, 0.44),
	},
}

var current_level: int = 1
var total_money: int = 0
var last_round_score: int = 0

# Progres: level tertinggi yang sudah terbuka (level berikutnya terkunci sampai
# level sebelumnya diselesaikan). Disimpan permanen ke disk.
var unlocked_level: int = 1
const PROGRESS_PATH := "user://progress.cfg"

func _ready() -> void:
	# Autoload harus tetap berjalan walau game di-pause (untuk transisi).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_progress()

func is_unlocked(level: int) -> bool:
	return level <= unlocked_level

func unlock_level(level: int) -> void:
	var lv := clampi(level, 1, TOTAL_LEVELS)
	if lv > unlocked_level:
		unlocked_level = lv
		_save_progress()

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.save(PROGRESS_PATH)

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) == OK:
		unlocked_level = int(cfg.get_value("progress", "unlocked_level", 1))

func set_current_level(level: int) -> void:
	current_level = clampi(level, 1, TOTAL_LEVELS)

func get_config(level: int = -1) -> Dictionary:
	var lv := current_level if level < 0 else level
	return LEVEL_CONFIG.get(lv, LEVEL_CONFIG[1])

func get_time_preset(level: int = -1) -> Dictionary:
	var cfg := get_config(level)
	return TIME_PRESETS.get(cfg.get("time_of_day", "night"), TIME_PRESETS["night"])

func get_quota(level: int = -1) -> int:
	return int(get_config(level).get("quota_kg", 0))

func add_money(amount: int) -> void:
	total_money += amount
	last_round_score = amount
	money_changed.emit(total_money)

func has_next_level() -> bool:
	return current_level < TOTAL_LEVELS

## Lanjut ke level berikutnya (dipanggil setelah layar skor "Next").
func go_to_next_level() -> void:
	if has_next_level():
		current_level += 1
		_change_scene(LEVEL_SCENES.get(current_level, MENU_SCENE))

## Ulang level saat ini (dipakai saat kalah → Retry).
func restart_level() -> void:
	_change_scene(LEVEL_SCENES.get(current_level, MENU_SCENE))

func go_to_menu() -> void:
	_change_scene(MENU_SCENE)

## Reset campaign baru dari menu utama.
func start_new_campaign() -> void:
	current_level = 1
	total_money = 0
	last_round_score = 0
	money_changed.emit(total_money)

func _change_scene(path: String) -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(path)
