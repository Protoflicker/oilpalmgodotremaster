extends Node
## Loc (Autoload) — lokalisasi sederhana Bahasa Indonesia / English.
## Teks UI yang diset lewat kode memakai Loc.t("key"); format string memakai t(key) % [..].
## Bahasa tersimpan permanen (user://locale.cfg) & bisa diganti di Options.

signal language_changed(lang: String)

const CONFIG_PATH := "user://locale.cfg"

var lang: String = "en"

const STRINGS := {
	"id": {
		# HUD
		"noise_tag": "Kebisingan",
		"detection_tag": "Terdeteksi",
		"stamina_tag": "Tenaga",
		"battery_tag": "Baterai Senter",
		"capture_count": "Tertangkap: %d kali",
		"quota_training": "Mode Latihan (tanpa kuota)",
		"quota_progress": "Kuota: %d / %d kg",
		"ripe_carry": "Buah matang: %d dibawa, %d kg disetor",
		"unripe_wasted": "Buah mentah terbuang: %d kg",
		"alert_seen": "!  TERLIHAT  !",
		"extraction_hint": "Mobil pickup: %d m   (%s)",
		"extraction_simple": "Kabur ke mobil pickup!",
		"dir_ahead": "▲ lurus",
		"dir_right": "► kanan",
		"dir_left": "◄ kiri",
		# Notifikasi & sebab
		"caught_prefix": "Tertangkap! ",
		"caught_madman": "Tertangkap penghuni kebun!",
		"killed_boar": "Diterkam babi hutan liar!",
		"killed_tiger": "Diterkam harimau!",
		"snake_bite": "Digigit ular di semak-semak!",
		"snake_warn": "Ssshh... ADA ULAR di semak! Cepat keluar!",
		"quota_met": "Kuota terpenuhi! Kembali ke mobil pickup untuk kabur.",
		"driver_fled": "Sopir kabur! Penghuni kebun terlalu dekat mobil pickup!",
		"driver_gone": "Sopir sudah kabur, tak bisa setor buah lagi!",
		"delivered": "%d kg buah matang berhasil disetor!",
		"time_up": "Waktu habis! Sopir pergi tanpamu.",
		# Layar menang / kalah
		"win_title": "BERHASIL KABUR!  +Rp %s",
		"details_header": "RINCIAN:",
		"detail_fruit": "+ Buah disetor : %d kg = Rp %s",
		"detail_time": "+ Bonus waktu  : %d dtk = Rp %s",
		"detail_total": "Total uang     : Rp %s",
		"retry": "Coba Lagi",
		"menu_main": "Menu Utama",
		# Options
		"options_title": "PENGATURAN",
		"master": "MASTER",
		"music": "MUSIC",
		"sfx": "EFEK SUARA",
		"sensitivity": "SENSITIVITAS MOUSE",
		"fullscreen": "Layar Penuh (Fullscreen)",
		"back": "Kembali",
		"reset": "Reset Default",
		"controls_title": "KONTROL",
		"language": "Bahasa / Language",
		"press_key": "Tekan tombol...",
		"locked": "TERKUNCI",
		"next": "NEXT",
		"enter": "MASUK",
		# Aksi kontrol
		"act_move_forward": "Maju",
		"act_move_back": "Mundur",
		"act_move_left": "Kiri",
		"act_move_right": "Kanan",
		"act_sprint": "Lari",
		"act_crouch": "Jongkok",
		"act_jump": "Lompat",
		"act_harvest": "Panen",
		"act_throw_stone": "Lempar Batu",
		"act_flashlight": "Senter",
	},
	"en": {
		"noise_tag": "Noise",
		"detection_tag": "Detected",
		"stamina_tag": "Stamina",
		"battery_tag": "Flashlight Battery",
		"capture_count": "Caught: %d times",
		"quota_training": "Practice Mode (no quota)",
		"quota_progress": "Quota: %d / %d kg",
		"ripe_carry": "Ripe fruit: %d carried, %d kg delivered",
		"unripe_wasted": "Unripe wasted: %d kg",
		"alert_seen": "!  SPOTTED  !",
		"extraction_hint": "Pickup truck: %d m   (%s)",
		"extraction_simple": "Escape to the pickup truck!",
		"dir_ahead": "▲ ahead",
		"dir_right": "► right",
		"dir_left": "◄ left",
		"caught_prefix": "Caught! ",
		"caught_madman": "Caught by the plantation dweller!",
		"killed_boar": "Mauled by a wild boar!",
		"killed_tiger": "Mauled by a tiger!",
		"snake_bite": "Bitten by a snake in the bushes!",
		"snake_warn": "Ssshh... a SNAKE in the bush! Get out fast!",
		"quota_met": "Quota met! Return to the pickup truck to escape.",
		"driver_fled": "Driver fled! The dweller got too close to the truck!",
		"driver_gone": "The driver already fled — can't deliver fruit anymore!",
		"delivered": "%d kg of ripe fruit delivered!",
		"time_up": "Time's up! The driver left without you.",
		"win_title": "ESCAPED!  +Rp %s",
		"details_header": "DETAILS:",
		"detail_fruit": "+ Fruit delivered : %d kg = Rp %s",
		"detail_time": "+ Time bonus      : %d s = Rp %s",
		"detail_total": "Total money       : Rp %s",
		"retry": "Retry",
		"menu_main": "Main Menu",
		"options_title": "SETTINGS",
		"master": "MASTER",
		"music": "MUSIC",
		"sfx": "SOUND EFFECT",
		"sensitivity": "MOUSE SENSITIVITY",
		"fullscreen": "Fullscreen",
		"back": "Back",
		"reset": "Reset to Default",
		"controls_title": "CONTROLS",
		"language": "Language / Bahasa",
		"press_key": "Press a key...",
		"locked": "LOCKED",
		"next": "NEXT",
		"enter": "ENTER",
		"act_move_forward": "Forward",
		"act_move_back": "Backward",
		"act_move_left": "Left",
		"act_move_right": "Right",
		"act_sprint": "Sprint",
		"act_crouch": "Crouch",
		"act_jump": "Jump",
		"act_harvest": "Harvest",
		"act_throw_stone": "Throw Stone",
		"act_flashlight": "Flashlight",
	},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()

func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS["id"])
	if table.has(key):
		return str(table[key])
	return str(STRINGS["id"].get(key, key))

func set_language(l: String) -> void:
	if l != "id" and l != "en":
		return
	if l == lang:
		return
	lang = l
	_save()
	language_changed.emit(lang)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		var saved := str(cfg.get_value("locale", "language", "en"))
		if saved == "id" or saved == "en":
			lang = saved

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "language", lang)
	cfg.save(CONFIG_PATH)
