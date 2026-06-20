extends Control
## Menu Pengaturan: volume (Master/Music/SFX %), sensitivitas, fullscreen, RESET,
## rebinding kontrol (klik tombol lalu tekan tombol baru), dan pilihan Bahasa (ID/EN).

var music_slider: HSlider
var master_slider: HSlider
var sfx_slider: HSlider
var sens_slider: HSlider
var fs_check: CheckButton
var music_label: Label
var master_label: Label
var sfx_label: Label

var listening_action: String = ""
var rebind_buttons: Dictionary = {}
var rebind_labels: Dictionary = {}
var _font: Font = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_font = load("res://Script/FONT/Colorfiction - Simple.otf")

	music_slider = get_node_or_null("HSlider") as HSlider
	master_slider = get_node_or_null("HSlider2") as HSlider
	sfx_slider = get_node_or_null("HSlider3") as HSlider
	sens_slider = get_node_or_null("HSlider4") as HSlider
	fs_check = get_node_or_null("FullscreenCheck") as CheckButton
	music_label = get_node_or_null("TextEdit") as Label
	master_label = get_node_or_null("TextEdit2") as Label
	sfx_label = get_node_or_null("TextEdit3") as Label

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

	var lid := get_node_or_null("LangID") as Button
	if lid:
		lid.pressed.connect(_on_lang_id)
	var len_btn := get_node_or_null("LangEN") as Button
	if len_btn:
		len_btn.pressed.connect(_on_lang_en)

	_build_rebind_list()

	if not Loc.language_changed.is_connected(_apply_localization):
		Loc.language_changed.connect(_apply_localization)
	_apply_localization()

# ===================== REBIND KONTROL =====================
func _build_rebind_list() -> void:
	var list := get_node_or_null("ControlsList") as ScrollContainer
	if not list:
		return
	for c in list.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 0)
	list.add_child(vbox)
	for action in Settings.REBINDABLE:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 40)
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(280, 0)
		lbl.text = Loc.t("act_" + action)
		if _font:
			lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 26)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 0)
		btn.text = Settings.key_name_for(action)
		if _font:
			btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_on_rebind_pressed.bind(action))
		row.add_child(btn)
		vbox.add_child(row)
		rebind_buttons[action] = btn
		rebind_labels[action] = lbl

func _on_rebind_pressed(action: String) -> void:
	listening_action = action
	if rebind_buttons.has(action):
		(rebind_buttons[action] as Button).text = Loc.t("press_key")

func _input(event: InputEvent) -> void:
	if listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		var act := listening_action
		listening_action = ""
		if k.keycode != KEY_ESCAPE:
			var kc: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			Settings.set_keybind(act, kc)
		if rebind_buttons.has(act):
			(rebind_buttons[act] as Button).text = Settings.key_name_for(act)
		get_viewport().set_input_as_handled()

# ===================== AUDIO / SENS / FS =====================
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

func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.set_fullscreen(pressed)

func _on_reset() -> void:
	if master_slider: master_slider.value = 1.0
	if music_slider: music_slider.value = 0.8
	if sfx_slider: sfx_slider.value = 1.0
	if sens_slider: sens_slider.value = 0.075
	if fs_check: fs_check.button_pressed = false
	_refresh_labels()

# ===================== BAHASA =====================
func _on_lang_id() -> void:
	Loc.set_language("id")

func _on_lang_en() -> void:
	Loc.set_language("en")

# ===================== LOKALISASI LABEL =====================
func _apply_localization(_lang: String = "") -> void:
	_set_text("ControlsTitle", Loc.t("controls_title"))
	_set_text("LangLabel", Loc.t("language"))
	_set_text("SensLabel", Loc.t("sensitivity"))
	_set_text("FullscreenCheck", Loc.t("fullscreen"))
	_set_text("ResetButton", Loc.t("reset"))
	for action in rebind_labels:
		(rebind_labels[action] as Label).text = Loc.t("act_" + action)
	_refresh_labels()

func _set_text(node_name: String, txt: String) -> void:
	var n := get_node_or_null(node_name)
	if n:
		n.set("text", txt)

func _refresh_labels() -> void:
	if master_label:
		master_label.text = "%s  %d%%" % [Loc.t("master"), int(float(Settings.master_volume) * 100.0)]
	if music_label:
		music_label.text = "%s  %d%%" % [Loc.t("music"), int(float(Settings.music_volume) * 100.0)]
	if sfx_label:
		sfx_label.text = "%s  %d%%" % [Loc.t("sfx"), int(float(Settings.sfx_volume) * 100.0)]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Menu.tscn")
