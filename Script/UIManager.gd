extends Control
class_name UIManager
## HUD stealth-horror: Noise Meter, Detection/Visibility Indicator, status waspada,
## kuota buah, vignette saat bahaya, layar menang (skor) & layar GAME OVER.

# Label inventaris / info
@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var notification_label: Label = $NotificationLabel
@onready var npc_harvest_label: Label = $NpcHarvestLabel

@onready var timer_label: Label
@onready var crosshair: Control = $Crosshair

# Elemen stealth/horror (dicari saat _ready, ditambahkan ke scene)
var noise_meter: ProgressBar = null
var detection_meter: ProgressBar = null
var alert_label: Label = null
var quota_label: Label = null
var vignette: TextureRect = null
var blackout: ColorRect = null
var capture_label: Label = null
var capture_count_ui: int = 0
var stamina_bar: ProgressBar = null
var battery_bar: ProgressBar = null
var red_flash: ColorRect = null
var extraction_hint: Label = null
var quota_met_ui: bool = false
var _last_quota_cur: int = 0
var _last_quota_tgt: int = 0

# Pause menu
@onready var pause_menu: Control = $PauseMenu
var resume_button: Button
var restart_button: Button
var quit_button: Button

# Layar akhir ronde (MENANG)
@onready var round_end_panel: Control = $RoundEndPanel
var final_score_label: Label
var details_label: Label
var restart_button_end: Button
var quit_button_end: Button
var next_button_end: Button

# Layar GAME OVER (KALAH)
var game_over_panel: Control = null
var game_over_reason_label: Label = null
var game_over_retry_button: Button = null
var game_over_menu_button: Button = null

# Panel Pengaturan dalam Pause Menu
var options_panel: Control = null
var opt_master: HSlider = null
var opt_music: HSlider = null
var opt_sfx: HSlider = null
var opt_sens: HSlider = null
var opt_fs: CheckButton = null
var opt_master_label: Label = null
var opt_music_label: Label = null
var opt_sfx_label: Label = null

var notification_timer: Timer
var is_paused: bool = false

func _ready():
	visible = true

	timer_label = find_child("TimerLabel", true, false)
	set_process_input(true)
	set_process_unhandled_input(true)

	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)
	add_child(notification_timer)

	interaction_label.visible = false
	notification_label.visible = false

	# Grab elemen stealth HUD (opsional bila ada di scene)
	noise_meter = find_child("NoiseMeter", true, false)
	detection_meter = find_child("DetectionMeter", true, false)
	alert_label = find_child("AlertLabel", true, false)
	quota_label = find_child("QuotaLabel", true, false)
	vignette = find_child("Vignette", true, false)
	blackout = find_child("Blackout", true, false)
	capture_label = find_child("CaptureLabel", true, false)
	stamina_bar = find_child("StaminaBar", true, false)
	battery_bar = find_child("BatteryBar", true, false)
	red_flash = find_child("RedFlash", true, false)
	extraction_hint = find_child("ExtractionHint", true, false)
	if alert_label:
		alert_label.visible = false
	if extraction_hint:
		extraction_hint.visible = false
	if capture_label:
		capture_label.text = Loc.t("capture_count") % 0

	# "Buah yang dicuri" tidak relevan lagi di mode stealth.
	if npc_harvest_label:
		npc_harvest_label.visible = false

	call_deferred("setup_pause_menu")
	call_deferred("setup_options_panel")
	call_deferred("setup_round_end_ui")
	call_deferred("setup_game_over_ui")
	call_deferred("show_inventory_labels")
	call_deferred("connect_to_game_systems")
	call_deferred("_apply_localization")

	if not Loc.language_changed.is_connected(_apply_localization):
		Loc.language_changed.connect(_apply_localization)

func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta):
	if not should_show_ui_labels():
		update_sensitive_labels_visibility()
	update_crosshair_based_on_tool()
	_update_stealth_hud()
	_update_resource_bars()
	_update_extraction_hint()

func _update_resource_bars():
	var player := _get_player() as Node3D
	if not player:
		return
	var pc := player.get_node_or_null("PlayerController")
	if not pc:
		return
	if stamina_bar and pc.has_method("get_stamina_ratio"):
		stamina_bar.value = float(pc.get_stamina_ratio()) * 100.0
		if pc.has_method("is_stamina_exhausted") and pc.is_stamina_exhausted():
			stamina_bar.modulate = Color(1, 0.35, 0.2)
		else:
			stamina_bar.modulate = Color(0.4, 0.8, 1)
	if battery_bar and pc.has_method("get_battery_ratio"):
		var b := float(pc.get_battery_ratio())
		battery_bar.value = b * 100.0
		battery_bar.modulate = Color(1, 0.3, 0.2) if b < 0.2 else Color(1, 0.85, 0.3)

func _update_extraction_hint():
	if not extraction_hint:
		return
	if not quota_met_ui:
		extraction_hint.visible = false
		return
	var zones := get_tree().get_nodes_in_group("delivery_zone")
	var player := _get_player() as Node3D
	if zones.is_empty() or player == null:
		extraction_hint.visible = false
		return
	var zone := zones[0] as Node3D
	if zone == null:
		extraction_hint.visible = false
		return
	var ppos := player.global_position
	var zpos := zone.global_position
	var dist := ppos.distance_to(zpos)

	var arrow: String = Loc.t("dir_ahead")
	var cam := player.get_node_or_null("PlayerController/Camera3D") as Camera3D
	if cam:
		var to := zpos - ppos
		to.y = 0.0
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		var right := cam.global_transform.basis.x
		right.y = 0.0
		if to.length() > 0.1 and fwd.length() > 0.1:
			to = to.normalized()
			fwd = fwd.normalized()
			if to.dot(fwd) > 0.7:
				arrow = Loc.t("dir_ahead")
			elif to.dot(right.normalized()) > 0.0:
				arrow = Loc.t("dir_right")
			else:
				arrow = Loc.t("dir_left")
	extraction_hint.visible = true
	extraction_hint.text = Loc.t("extraction_hint") % [int(dist), arrow]

# ===================== STEALTH HUD =====================
func _update_stealth_hud():
	if noise_meter:
		noise_meter.value = NoiseManager.get_noise_level() * 100.0

	var max_det := 0.0
	var alert := "calm"
	for e in get_tree().get_nodes_in_group("harvester_npc"):
		if is_instance_valid(e) and e.has_method("get_detection_level"):
			var d = e.get_detection_level()
			if d > max_det:
				max_det = d
			if e.has_method("get_alert_state"):
				var a = e.get_alert_state()
				if a == "alerted":
					alert = "alerted"
				elif a == "suspicious" and alert != "alerted":
					alert = "suspicious"

	if detection_meter:
		detection_meter.value = max_det * 100.0
		if alert == "alerted":
			detection_meter.modulate = Color(1, 0.1, 0.1)
		elif alert == "suspicious":
			detection_meter.modulate = Color(1, 0.75, 0.1)
		else:
			detection_meter.modulate = Color(0.6, 0.9, 0.6)

	_update_alert_label(alert)
	_update_vignette(alert, max_det)

func _update_alert_label(alert: String):
	if not alert_label:
		return
	if alert == "alerted":
		alert_label.visible = true
		alert_label.text = Loc.t("alert_seen")
		alert_label.modulate = Color(1, 0.1, 0.1)
	elif alert == "suspicious":
		alert_label.visible = true
		alert_label.text = "?"
		alert_label.modulate = Color(1, 0.8, 0.2)
	else:
		alert_label.visible = false

func _update_vignette(alert: String, det: float):
	if not vignette:
		return
	var target_a := 0.0
	if alert == "alerted":
		target_a = 0.6
	elif alert == "suspicious":
		target_a = 0.25 * det
	var col := vignette.modulate
	col.a = lerpf(col.a, target_a, 0.08)
	vignette.modulate = col

func update_quota_display(current_kg: int, target_kg: int):
	quota_met_ui = (target_kg <= 0) or (current_kg >= target_kg)
	if not quota_label:
		return
	_last_quota_cur = current_kg
	_last_quota_tgt = target_kg
	if target_kg <= 0:
		quota_label.text = Loc.t("quota_training")
		quota_label.modulate = Color.WHITE
	else:
		quota_label.text = Loc.t("quota_progress") % [current_kg, target_kg]
		quota_label.modulate = Color.GREEN if current_kg >= target_kg else Color.WHITE

# ===================== PAUSE MENU =====================
func setup_pause_menu():
	if pause_menu:
		pause_menu.visible = false
		resume_button = pause_menu.find_child("ResumeButton", true, false)
		restart_button = pause_menu.find_child("RestartButton", true, false)
		quit_button = pause_menu.find_child("QuitButton", true, false)

		if resume_button and not resume_button.is_connected("pressed", _on_resume_pressed):
			resume_button.pressed.connect(_on_resume_pressed)
		if restart_button and not restart_button.is_connected("pressed", _on_restart_pressed):
			restart_button.pressed.connect(_on_restart_pressed)
		if quit_button and not quit_button.is_connected("pressed", _on_quit_pressed):
			quit_button.pressed.connect(_on_quit_pressed)

		var options_button := pause_menu.find_child("OptionsButton", true, false) as Button
		if options_button and not options_button.is_connected("pressed", _on_pause_options_pressed):
			options_button.process_mode = Node.PROCESS_MODE_ALWAYS
			options_button.pressed.connect(_on_pause_options_pressed)

# ===================== OPTIONS DALAM PAUSE =====================
func setup_options_panel():
	options_panel = find_child("OptionsPanel", true, false)
	if not options_panel:
		return
	options_panel.visible = false
	options_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	opt_master = options_panel.find_child("MasterSlider", true, false) as HSlider
	opt_music = options_panel.find_child("MusicSlider", true, false) as HSlider
	opt_sfx = options_panel.find_child("SfxSlider", true, false) as HSlider
	opt_sens = options_panel.find_child("SensSlider", true, false) as HSlider
	opt_fs = options_panel.find_child("FsCheck", true, false) as CheckButton
	opt_master_label = options_panel.find_child("MasterLabel", true, false) as Label
	opt_music_label = options_panel.find_child("MusicLabel", true, false) as Label
	opt_sfx_label = options_panel.find_child("SfxLabel", true, false) as Label

	if opt_master:
		opt_master.value = Settings.master_volume
		opt_master.value_changed.connect(_on_opt_master)
	if opt_music:
		opt_music.value = Settings.music_volume
		opt_music.value_changed.connect(_on_opt_music)
	if opt_sfx:
		opt_sfx.value = Settings.sfx_volume
		opt_sfx.value_changed.connect(_on_opt_sfx)
	if opt_sens:
		opt_sens.value = Settings.mouse_sensitivity
		opt_sens.value_changed.connect(_on_opt_sens)
	if opt_fs:
		opt_fs.button_pressed = Settings.fullscreen
		opt_fs.toggled.connect(_on_opt_fs)
	var back := options_panel.find_child("BackButton", true, false) as Button
	if back:
		back.pressed.connect(_on_options_back)
	var lid := options_panel.find_child("LangID", true, false) as Button
	if lid:
		lid.pressed.connect(_on_lang_id)
	var len_btn := options_panel.find_child("LangEN", true, false) as Button
	if len_btn:
		len_btn.pressed.connect(_on_lang_en)
	_refresh_opt_labels()

func _on_lang_id():
	Loc.set_language("id")

func _on_lang_en():
	Loc.set_language("en")

# ===================== LOKALISASI =====================
func _set_text(node_name: String, key: String, base: Node = null) -> void:
	var root_node: Node = base if base else self
	var node := root_node.find_child(node_name, true, false)
	if node:
		node.set("text", Loc.t(key))

func _apply_localization(_lang: String = "") -> void:
	# Tag HUD statis
	_set_text("NoiseTag", "noise_tag")
	_set_text("DetectionTag", "detection_tag")
	_set_text("StaminaTag", "stamina_tag")
	_set_text("BatteryTag", "battery_tag")
	# Tombol layar game over
	if game_over_panel:
		_set_text("RetryButton", "retry", game_over_panel)
		_set_text("MenuButton", "menu_main", game_over_panel)
	# Panel options (dalam pause)
	if options_panel:
		_set_text("Title", "options_title", options_panel)
		_set_text("SensLabel", "sensitivity", options_panel)
		_set_text("FsCheck", "fullscreen", options_panel)
		_set_text("BackButton", "back", options_panel)
		_set_text("LangLabel", "language", options_panel)
	_refresh_opt_labels()
	# Terapkan ulang teks dinamis dengan nilai terakhir
	update_quota_display(_last_quota_cur, _last_quota_tgt)
	if capture_label:
		capture_label.text = Loc.t("capture_count") % capture_count_ui
	update_ui_from_player()

func _on_pause_options_pressed():
	if pause_menu:
		pause_menu.visible = false
	if options_panel:
		options_panel.visible = true

func _on_options_back():
	if options_panel:
		options_panel.visible = false
	if pause_menu:
		pause_menu.visible = true

func _on_opt_master(v: float):
	Settings.set_master(v)
	_refresh_opt_labels()

func _on_opt_music(v: float):
	Settings.set_music(v)
	_refresh_opt_labels()

func _on_opt_sfx(v: float):
	Settings.set_sfx(v)
	_refresh_opt_labels()

func _on_opt_sens(v: float):
	Settings.set_sensitivity(v)

func _on_opt_fs(pressed: bool):
	Settings.set_fullscreen(pressed)

func _refresh_opt_labels():
	if opt_master_label:
		opt_master_label.text = "%s  %d%%" % [Loc.t("master"), int(float(Settings.master_volume) * 100.0)]
	if opt_music_label:
		opt_music_label.text = "%s  %d%%" % [Loc.t("music"), int(float(Settings.music_volume) * 100.0)]
	if opt_sfx_label:
		opt_sfx_label.text = "%s  %d%%" % [Loc.t("sfx"), int(float(Settings.sfx_volume) * 100.0)]

func setup_timer_display():
	if timer_label:
		timer_label.visible = true

func update_timer_display(remaining_time: float):
	if timer_label:
		var minutes = int(remaining_time) / 60
		var seconds = int(remaining_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		if remaining_time <= 30.0:
			timer_label.modulate = Color.RED
		else:
			timer_label.modulate = Color.WHITE

func show_inventory_labels():
	if ripe_label: ripe_label.visible = true
	if unripe_label: unripe_label.visible = true
	update_ui_from_player()

func connect_to_game_systems():
	await get_tree().process_frame

	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0: inventory_system = nodes[0]

	var player = get_node_or_null("/root/Node3D/Player")
	if not player:
		var nodes = get_tree().get_nodes_in_group("player")
		if nodes.size() > 0: player = nodes[0]

	if inventory_system and inventory_system.has_signal("permanent_inventory_updated"):
		inventory_system.permanent_inventory_updated.connect(update_permanent_display)

	if player:
		if player.has_signal("carried_fruits_updated"):
			player.carried_fruits_updated.connect(update_carried_fruits)
		if player.has_signal("player_fully_ready"):
			player.player_fully_ready.connect(_on_player_ready)
		if player.has_signal("player_caught") and not player.player_caught.is_connected(_on_caught_respawn):
			player.player_caught.connect(_on_caught_respawn)

	update_ui_from_player()

	var game_mode_manager = get_node_or_null("/root/Node3D/GameModeManager")
	if not game_mode_manager:
		var managers = get_tree().get_nodes_in_group("game_mode_manager")
		if managers.size() > 0: game_mode_manager = managers[0]

	if game_mode_manager:
		if game_mode_manager.has_signal("game_time_updated") and not game_mode_manager.game_time_updated.is_connected(update_timer_display):
			game_mode_manager.game_time_updated.connect(update_timer_display)
		if game_mode_manager.has_signal("round_ended_with_score") and not game_mode_manager.round_ended_with_score.is_connected(show_round_end_notification):
			game_mode_manager.round_ended_with_score.connect(show_round_end_notification)
		if game_mode_manager.has_signal("game_over_triggered") and not game_mode_manager.game_over_triggered.is_connected(show_game_over):
			game_mode_manager.game_over_triggered.connect(show_game_over)
		if game_mode_manager.has_signal("quota_updated") and not game_mode_manager.quota_updated.is_connected(update_quota_display):
			game_mode_manager.quota_updated.connect(update_quota_display)

	setup_round_end_ui()
	setup_timer_display()

func _unhandled_input(event):
	if game_over_panel and game_over_panel.visible:
		return
	if round_end_panel and round_end_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	if round_end_panel and round_end_panel.visible:
		return
	if game_over_panel and game_over_panel.visible:
		return
	# Jika panel Options terbuka, Esc kembali ke pause menu (bukan unpause).
	if options_panel and options_panel.visible:
		_on_options_back()
		return
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if is_paused: return
	is_paused = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if options_panel: options_panel.visible = false
	if pause_menu:
		pause_menu.visible = true
		if resume_button: resume_button.grab_focus()
	on_ui_state_changed()

func resume_game():
	if not is_paused: return
	is_paused = false
	if pause_menu: pause_menu.visible = false
	if options_panel: options_panel.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	on_ui_state_changed()

func _on_resume_pressed():
	resume_game()

func _on_restart_round_pressed():
	if round_end_panel: round_end_panel.visible = false
	GameState.restart_level()

func _on_restart_pressed():
	GameState.restart_level()

func _on_quit_pressed():
	GameState.go_to_menu()

func _on_next_level_pressed():
	if GameState.has_next_level():
		GameState.go_to_next_level()
	else:
		GameState.go_to_menu()

func is_game_paused() -> bool:
	return is_paused

func _on_player_ready():
	await get_tree().process_frame
	update_ui_from_player()

func update_ui_from_player():
	var player = _get_player()
	var inventory_system = _get_inventory()

	var carried_ripe = 0
	var delivered_ripe_kg = 0
	var collected_unripe_kg = 0

	if player and player.has_method("get_carried_ripe_fruits"):
		carried_ripe = player.get_carried_ripe_fruits()
	if inventory_system:
		if inventory_system.has_method("get_delivered_ripe_kg"):
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		if inventory_system.has_method("get_collected_unripe_kg"):
			collected_unripe_kg = inventory_system.get_collected_unripe_kg()

	if ripe_label:
		ripe_label.visible = true
		ripe_label.text = Loc.t("ripe_carry") % [carried_ripe, delivered_ripe_kg]
	if unripe_label:
		unripe_label.visible = true
		unripe_label.text = Loc.t("unripe_wasted") % collected_unripe_kg

func show_interaction_label(text: String):
	if not should_show_ui_labels():
		if interaction_label and interaction_label.visible:
			interaction_label.visible = false
		return
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	if interaction_label: interaction_label.visible = false

func clear_target():
	hide_interaction_label()

func show_delivery_notification(total_kg: int):
	show_notification(Loc.t("delivered") % total_kg)

## Notifikasi umum (dipakai GameModeManager & DeliveryZone).
func show_notification(text: String):
	if not should_show_ui_labels():
		return
	if notification_label:
		notification_label.text = text
		notification_label.visible = true
		notification_timer.start(3.5)

func _on_notification_timeout():
	if notification_label: notification_label.visible = false

func update_permanent_display(delivered_ripe_kg: int, collected_unripe_kg: int):
	if ripe_label:
		var player = _get_player()
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		ripe_label.text = Loc.t("ripe_carry") % [carried_ripe, delivered_ripe_kg]
	if unripe_label:
		unripe_label.text = "Buah mentah terbuang: %d kg" % collected_unripe_kg

func update_carried_fruits(carried_ripe: int, _carried_kg: int):
	if ripe_label:
		var inventory_system = _get_inventory()
		var delivered_ripe_kg = 0
		if inventory_system:
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		ripe_label.text = Loc.t("ripe_carry") % [carried_ripe, delivered_ripe_kg]

# ===================== LAYAR MENANG (SKOR) =====================
func setup_round_end_ui():
	if not round_end_panel:
		return
	round_end_panel.visible = false
	round_end_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	final_score_label = round_end_panel.find_child("FinalScoreLabel", true, false)
	details_label = round_end_panel.find_child("DetailsLabel", true, false)
	restart_button_end = round_end_panel.find_child("RestartButton", true, false)
	quit_button_end = round_end_panel.find_child("QuitButton", true, false)
	next_button_end = round_end_panel.find_child("RestartButton3", true, false)

	if restart_button_end:
		restart_button_end.process_mode = Node.PROCESS_MODE_ALWAYS
		if not restart_button_end.is_connected("pressed", _on_restart_round_pressed):
			restart_button_end.pressed.connect(_on_restart_round_pressed)
	if quit_button_end:
		quit_button_end.process_mode = Node.PROCESS_MODE_ALWAYS
		if not quit_button_end.is_connected("pressed", _on_quit_pressed):
			quit_button_end.pressed.connect(_on_quit_pressed)
	if next_button_end:
		next_button_end.process_mode = Node.PROCESS_MODE_ALWAYS
		if not next_button_end.is_connected("pressed", _on_next_level_pressed):
			next_button_end.pressed.connect(_on_next_level_pressed)
		next_button_end.visible = GameState.has_next_level()

func show_round_end_notification(final_score: int, score_details: Dictionary):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not round_end_panel:
		return
	round_end_panel.visible = true

	if final_score_label:
		final_score_label.text = Loc.t("win_title") % _format_currency(final_score)
		final_score_label.modulate = Color.GREEN

	if details_label:
		var ripe_kg = score_details.get("delivered_ripe_kg", 0)
		var ripe_income = score_details.get("ripe_income", 0)
		var time_bonus = score_details.get("time_bonus", 0)
		var rem = score_details.get("remaining_time", 0)
		var text = Loc.t("details_header") + "\n"
		text += Loc.t("detail_fruit") % [ripe_kg, _format_currency(ripe_income)] + "\n"
		text += Loc.t("detail_time") % [rem, _format_currency(time_bonus)] + "\n"
		text += Loc.t("detail_total") % _format_currency(GameState.total_money)
		details_label.text = text

	if next_button_end:
		next_button_end.visible = GameState.has_next_level()
		if next_button_end.visible:
			next_button_end.grab_focus()
		elif restart_button_end:
			restart_button_end.grab_focus()

	on_ui_state_changed()

# ===================== LAYAR GAME OVER (KALAH) =====================
func setup_game_over_ui():
	game_over_panel = find_child("GameOverPanel", true, false)
	if not game_over_panel:
		return
	game_over_panel.visible = false
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	game_over_reason_label = game_over_panel.find_child("ReasonLabel", true, false)
	game_over_retry_button = game_over_panel.find_child("RetryButton", true, false)
	game_over_menu_button = game_over_panel.find_child("MenuButton", true, false)

	if game_over_retry_button:
		game_over_retry_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if not game_over_retry_button.is_connected("pressed", _on_restart_pressed):
			game_over_retry_button.pressed.connect(_on_restart_pressed)
	if game_over_menu_button:
		game_over_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if not game_over_menu_button.is_connected("pressed", _on_quit_pressed):
			game_over_menu_button.pressed.connect(_on_quit_pressed)

# ===================== RESPAWN (tertangkap, bukan game over) =====================
func _on_caught_respawn(reason: String):
	capture_count_ui += 1
	if capture_label:
		capture_label.text = Loc.t("capture_count") % capture_count_ui
	show_notification(Loc.t("caught_prefix") + reason)
	# Jumpscare: kilatan merah singkat.
	if red_flash:
		var rc := red_flash.modulate
		rc.a = 0.0
		red_flash.modulate = rc
		var rt := create_tween()
		rt.tween_property(red_flash, "modulate:a", 0.6, 0.08)
		rt.tween_property(red_flash, "modulate:a", 0.0, 0.5)
	if blackout:
		var col := blackout.modulate
		col.a = 0.0
		blackout.modulate = col
		var tw := create_tween()
		tw.tween_property(blackout, "modulate:a", 1.0, 0.3)
		tw.tween_interval(0.5)
		tw.tween_property(blackout, "modulate:a", 0.0, 0.6)

func show_game_over(reason: String):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if vignette:
		var col := vignette.modulate
		col.a = 0.85
		vignette.modulate = col
	if not game_over_panel:
		return
	game_over_panel.visible = true
	if game_over_reason_label:
		game_over_reason_label.text = reason
	if game_over_retry_button:
		game_over_retry_button.grab_focus()
	on_ui_state_changed()

# ===================== CROSSHAIR =====================
func update_crosshair_based_on_tool() -> void:
	var player_controller = get_node_or_null("/root/Node3D/Player/PlayerController")
	if not player_controller:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_controller = players[0].get_node_or_null("PlayerController")
	if player_controller and player_controller.has_method("is_ketapel_active"):
		update_crosshair_visibility(player_controller.is_ketapel_active())

func update_crosshair_visibility(should_show: bool) -> void:
	if crosshair:
		crosshair.visible = should_show

# ===================== HELPERS =====================
func _format_currency(amount: int) -> String:
	var is_negative = amount < 0
	var abs_amount = abs(amount)
	var formatted = ""
	var str_amount = str(abs_amount)
	var length = str_amount.length()
	for i in range(length):
		if i > 0 and i % 3 == 0: formatted = "." + formatted
		formatted = str_amount[length - i - 1] + formatted
	if is_negative: formatted = "-" + formatted
	return formatted

func should_show_ui_labels() -> bool:
	return not (is_paused or (round_end_panel and round_end_panel.visible) or (game_over_panel and game_over_panel.visible))

func update_sensitive_labels_visibility():
	var should_show = should_show_ui_labels()
	if interaction_label and not should_show and interaction_label.visible:
		interaction_label.visible = false
	if notification_label and not should_show and notification_label.visible:
		notification_label.visible = false
		if notification_timer and notification_timer.time_left > 0:
			notification_timer.stop()

func on_ui_state_changed():
	update_sensitive_labels_visibility()

# Lookup tahan-banting (node player di scene bernama "CharacterBody3D", bukan "Player").
func _get_player() -> Node:
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		return nodes[0]
	return null

func _get_inventory() -> Node:
	var nodes = get_tree().get_nodes_in_group("inventory_system")
	if nodes.size() > 0:
		return nodes[0]
	return null
