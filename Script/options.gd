extends Control
## Menu Pengaturan: volume Master/Music/SFX (dgn % langsung), sensitivitas mouse,
## fullscreen, dan tombol Reset Default. Semua tersambung ke autoload Settings.

var music_slider: HSlider
var master_slider: HSlider
var sfx_slider: HSlider
var sens_slider: HSlider
var fs_check: CheckButton

var music_label: Label
var master_label: Label
var sfx_label: Label
var sens_label: Label

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	music_slider = get_node_or_null("HSlider") as HSlider
	master_slider = get_node_or_null("HSlider2") as HSlider
	sfx_slider = get_node_or_null("HSlider3") as HSlider
	sens_slider = get_node_or_null("HSlider4") as HSlider
	fs_check = get_node_or_null("FullscreenCheck") as CheckButton

	music_label = get_node_or_null("TextEdit") as Label
	master_label = get_node_or_null("TextEdit2") as Label
	sfx_label = get_node_or_null("TextEdit3") as Label
	sens_label = get_node_or_null("SensLabel") as Label

	if master_slider:
		master_slider.min_value = 0.0
		master_slider.max_value = 1.0
		master_slider.step = 0.01
		master_slider.value = Settings.master_volume
		master_slider.value_changed.connect(_on_master_changed)
	if music_slider:
		music_slider.min_value = 0.0
		music_slider.max_value = 1.0
		music_slider.step = 0.01
		music_slider.value = Settings.music_volume
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider:
		sfx_slider.min_value = 0.0
		sfx_slider.max_value = 1.0
		sfx_slider.step = 0.01
		sfx_slider.value = Settings.sfx_volume
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if sens_slider:
		sens_slider.value = Settings.mouse_sensitivity
		sens_slider.value_changed.connect(_on_sens_changed)
	if fs_check:
		fs_check.button_pressed = Settings.fullscreen
		fs_check.toggled.connect(_on_fullscreen_toggled)

	var reset := get_node_or_null("ResetButton") as Button
	if reset:
		reset.pressed.connect(_on_reset)

	_refresh_labels()

func _on_master_changed(v: float) -> void:
	Settings.set_master(v)
	_refresh_labels()

func _on_music_changed(v: float) -> void:
	Settings.set_music(v)
	_refresh_labels()

func _on_sfx_changed(v: float) -> void:
	Settings.set_sfx(v)
	_refresh_labels()

func _on_sens_changed(v: float) -> void:
	Settings.set_sensitivity(v)
	_refresh_labels()

func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.set_fullscreen(pressed)

func _on_reset() -> void:
	if master_slider:
		master_slider.value = 1.0
	if music_slider:
		music_slider.value = 0.8
	if sfx_slider:
		sfx_slider.value = 1.0
	if sens_slider:
		sens_slider.value = 0.075
	if fs_check:
		fs_check.button_pressed = false
	_refresh_labels()

func _refresh_labels() -> void:
	if master_label:
		master_label.text = "MASTER  %d%%" % int(float(Settings.master_volume) * 100.0)
	if music_label:
		music_label.text = "MUSIC  %d%%" % int(float(Settings.music_volume) * 100.0)
	if sfx_label:
		sfx_label.text = "SOUND EFFECT  %d%%" % int(float(Settings.sfx_volume) * 100.0)
	if sens_label:
		sens_label.text = "SENSITIVITAS MOUSE  %.3f" % float(Settings.mouse_sensitivity)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Menu.tscn")
