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
		"is_tutorial": false,
	},
}

# Preset atmosfer per waktu hari (dipakai AtmosphereController).
const TIME_PRESETS := {
	"evening": {
		"sun_energy": 0.9,
		"sun_color": Color(1.0, 0.72, 0.45),
		"ambient_energy": 0.45,
		"ambient_color": Color(0.45, 0.38, 0.42),
		"sky_exposure": 6.0,
		"fog_density": 0.012,
		"fog_color": Color(0.55, 0.42, 0.38),
	},
	"night": {
		"sun_energy": 0.18,
		"sun_color": Color(0.55, 0.62, 0.85),
		"ambient_energy": 0.12,
		"ambient_color": Color(0.10, 0.13, 0.22),
		"sky_exposure": 1.4,
		"fog_density": 0.03,
		"fog_color": Color(0.07, 0.09, 0.16),
	},
	"midnight": {
		"sun_energy": 0.08,
		"sun_color": Color(0.45, 0.52, 0.78),
		"ambient_energy": 0.06,
		"ambient_color": Color(0.05, 0.07, 0.14),
		"sky_exposure": 0.8,
		"fog_density": 0.045,
		"fog_color": Color(0.03, 0.05, 0.10),
	},
	"dawn": {
		"sun_energy": 0.35,
		"sun_color": Color(0.6, 0.6, 0.85),
		"ambient_energy": 0.18,
		"ambient_color": Color(0.18, 0.20, 0.30),
		"sky_exposure": 2.4,
		"fog_density": 0.028,
		"fog_color": Color(0.18, 0.20, 0.32),
	},
}

var current_level: int = 1
var total_money: int = 0
var last_round_score: int = 0

func _ready() -> void:
	# Autoload harus tetap berjalan walau game di-pause (untuk transisi).
	process_mode = Node.PROCESS_MODE_ALWAYS

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
