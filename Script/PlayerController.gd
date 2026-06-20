extends Node3D
class_name PlayerController

@export var player_body: CharacterBody3D
@export var camera_node: Camera3D
@export var egrek_node: Node3D
@export var tojok_node: Node3D

enum Tool { EGREK, TOJOK, KETAPEL }
var current_tool: Tool = Tool.EGREK

@export var ketapel_node: Node3D

# Tambah variabel untuk animasi ketapel
var ketapel_animation_player: AnimationPlayer = null
const KETAPEL_SHOOT_ANIM_NAME: String = "Shoot"  # Nama animasi shoot

# ===== STEALTH MOVEMENT (GDD: berjalan / lari / jongkok) =====
enum MoveState { WALK, SPRINT, CROUCH }
var move_state: MoveState = MoveState.WALK

var current_speed = 5.5                      # kecepatan jalan dasar (diatur Player.gd dari berat)
const SPRINT_MULTIPLIER: float = 1.7
const CROUCH_MULTIPLIER: float = 0.5
const JUMP_VELOCITY = 7.0
const GRAVITY = 25.0

# Tinggi kamera berdiri vs jongkok (untuk efek crouch).
const STAND_CAM_HEIGHT: float = 1.5
const CROUCH_CAM_HEIGHT: float = 0.8
const CAM_HEIGHT_LERP: float = 10.0

const MOUSE_SENSITIVITY = 0.075
const VERTICAL_CLAMP = Vector2(-70.0, 80.0)

const EGREK_UP_POSITION = Vector3(0.45, -0.25, -1.4)
const EGREK_UP_ROTATION = Vector3(-45.5, -70, 80)
const EGREK_DOWN_POSITION = Vector3(0.2, -0.4, 1.1)
const EGREK_DOWN_ROTATION = Vector3(-45.5, -90.0, 80)

const TOJOK_DEFAULT_POSITION = Vector3(0.215, -0.15, -0.735)
const TOJOK_DEFAULT_ROTATION = Vector3(51.5, 90.0, 82.0)
const TOJOK_SHOOT_POSITION = Vector3(0.18, -0.15, -0.9)
const TOJOK_SHOOT_ROTATION = Vector3(51.5, 90.0, 82.0)

const TRANSITION_THRESHOLD = 35.0
const ANIMATION_DISABLE_THRESHOLD = 10.0
const DECELERATION = 75
const MIN_VELOCITY_THRESHOLD = 0.01

var raycast_node: RayCast3D = null
var is_shooting: bool = false
const SHOOT_COOLDOWN: float = 1.0
var shoot_timer: float = 0.0

var egrek_tween: Tween
var tojok_tween: Tween
var tojok_shoot_tween: Tween

# ===== SENSES (Noise & Visibility) =====
var flashlight: SpotLight3D = null
var flashlight_on: bool = false
var in_bush: bool = false
var is_moving: bool = false

var step_timer: float = 0.0
var footstep_player: AudioStreamPlayer3D = null
var footstep_sound: AudioStream = null

# ===== STAMINA (lari menguras tenaga — survival horror) =====
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN: float = 26.0      # per detik saat lari
const STAMINA_REGEN: float = 16.0      # per detik saat tidak lari
const STAMINA_RECOVER_THRESHOLD: float = 30.0
var stamina: float = STAMINA_MAX
var stamina_exhausted: bool = false

# ===== BATERAI SENTER (kelola cahaya — risiko gelap) =====
const BATTERY_MAX: float = 100.0
const BATTERY_DRAIN: float = 4.0       # per detik saat menyala
const BATTERY_REGEN: float = 1.2       # per detik saat mati (recharge lambat)
var battery: float = BATTERY_MAX

# Dekoy batu (GDD: Q lempar batu)
var stone_scene: PackedScene = preload("res://Scene/Stone.tscn")
const STONE_THROW_COOLDOWN: float = 0.8
var stone_timer: float = 0.0
const STONE_THROW_FORCE: float = 16.0

var input_locked: bool = false   # dikunci saat tertangkap / game over

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	switch_tool(Tool.EGREK)
	update_tool_position()

	if player_body and player_body.has_method("get_base_speed"):
		current_speed = player_body.get_base_speed()

	# Setup animasi ketapel setelah semua node siap
	await get_tree().process_frame
	setup_ketapel_animation()
	setup_raycast()
	setup_flashlight()
	setup_footstep_audio()

func setup_footstep_audio():
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.bus = "SFX"
	footstep_player.max_distance = 12.0
	add_child(footstep_player)
	if ResourceLoader.exists("res://soundeffect/walk.mp3"):
		footstep_sound = load("res://soundeffect/walk.mp3")


func setup_flashlight():
	# Senter: SpotLight3D di kamera, mati di awal (GDD: Flashlight System).
	if not camera_node:
		return
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_energy = 6.0
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 30.0
	flashlight.spot_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera_node.add_child(flashlight)
	flashlight.position = Vector3(0.0, -0.1, 0.0)
	flashlight.rotation = Vector3.ZERO   # SpotLight3D menyorot ke -Z, sama dengan kamera


func setup_ketapel_animation():
	if ketapel_node:
		ketapel_animation_player = find_animation_player_in_node(ketapel_node)

		if ketapel_animation_player:
			if not ketapel_animation_player.has_animation(KETAPEL_SHOOT_ANIM_NAME):
				print("Peringatan: Animasi 'Shoot' tidak ditemukan untuk Ketapel")

func find_animation_player_in_node(node: Node3D) -> AnimationPlayer:
	var animation_player = node.find_child("AnimationPlayer", true, false)

	if not animation_player:
		for child in node.get_children():
			if child is AnimationPlayer:
				return child
			var found = find_animation_player_recursive(child)
			if found:
				return found

	return animation_player

func find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var found = find_animation_player_recursive(child)
		if found:
			return found

	return null

func set_current_speed(new_speed: float):
	current_speed = new_speed

func switch_tool(new_tool: Tool):
	if current_tool == new_tool:
		return

	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = false
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = false
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.visible = false

	current_tool = new_tool

	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = true
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = true
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.visible = true
				if not ketapel_animation_player:
					setup_ketapel_animation()

	update_tool_position()

func update_tool_position():
	if !camera_node:
		return

	var camera_x_rotation = camera_node.rotation_degrees.x
	var t = clamp(camera_x_rotation / TRANSITION_THRESHOLD, 0.0, 1.0)

	match current_tool:
		Tool.EGREK:
			if egrek_node:
				var target_position = EGREK_UP_POSITION.lerp(EGREK_DOWN_POSITION, 1.0 - t)
				var target_rotation = EGREK_UP_ROTATION.lerp(EGREK_DOWN_ROTATION, 1.0 - t)

				if egrek_tween and egrek_tween.is_valid():
					egrek_tween.kill()

				egrek_tween = create_tween()
				egrek_tween.set_parallel(true)
				egrek_tween.tween_property(egrek_node, "position", target_position, 0.2)
				egrek_tween.tween_property(egrek_node, "rotation_degrees", target_rotation, 0.2)

		Tool.TOJOK:
			if tojok_node:
				if tojok_tween and tojok_tween.is_valid():
					tojok_tween.kill()

				tojok_tween = create_tween()
				tojok_tween.set_parallel(true)
				tojok_tween.tween_property(tojok_node, "position", TOJOK_DEFAULT_POSITION, 0.2)
				tojok_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_DEFAULT_ROTATION, 0.2)

		Tool.KETAPEL:
			pass

	update_tool_animation_status()

func update_tool_animation_status():
	if !camera_node:
		return

	var animation_enabled = camera_node.rotation_degrees.x > ANIMATION_DISABLE_THRESHOLD
	set_tool_animation_enabled(animation_enabled)

func set_tool_animation_enabled(enabled: bool):
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.set_meta("animation_enabled", enabled)
		Tool.TOJOK:
			if tojok_node:
				tojok_node.set_meta("animation_enabled", true)
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.set_meta("animation_enabled", false)

func _input(event):
	if get_tree().paused or input_locked:
		return

	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event.is_action_pressed("ui_cancel"):
		toggle_mouse_mode()
	elif event.is_action_pressed("tool_1"):
		switch_tool(Tool.EGREK)
	elif event.is_action_pressed("tool_2"):
		switch_tool(Tool.TOJOK)
	elif event.is_action_pressed("tool_3"):
		switch_tool(Tool.KETAPEL)
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("throw_stone"):
		throw_stone()

func handle_mouse_motion(event):
	if !player_body or !camera_node:
		return

	var sens: float = Settings.mouse_sensitivity if Settings else MOUSE_SENSITIVITY

	player_body.rotation_degrees.y -= event.relative.x * sens

	camera_node.rotation_degrees.x -= event.relative.y * sens
	camera_node.rotation_degrees.x = clampf(camera_node.rotation_degrees.x, VERTICAL_CLAMP.x, VERTICAL_CLAMP.y)

	update_tool_position()
	update_tool_animation_status()

func toggle_mouse_mode():
	var current_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if current_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

func toggle_flashlight():
	if not flashlight:
		return
	if not flashlight_on and battery <= 0.0:
		return  # baterai habis, tak bisa dinyalakan
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on

func _update_flashlight_battery(delta: float):
	if not flashlight:
		return
	if flashlight_on:
		battery -= BATTERY_DRAIN * delta
		if battery <= 0.0:
			battery = 0.0
			flashlight_on = false
			flashlight.visible = false
	else:
		battery = minf(battery + BATTERY_REGEN * delta, BATTERY_MAX)

func setup_raycast():
	raycast_node = RayCast3D.new()
	raycast_node.enabled = false
	raycast_node.collision_mask = 0b111111
	raycast_node.collide_with_areas = true
	raycast_node.collide_with_bodies = true
	raycast_node.exclude_parent = true

	if camera_node:
		camera_node.add_child(raycast_node)
		raycast_node.target_position = Vector3(0, 0, -50)

func _physics_process(delta):
	if get_tree().paused or input_locked:
		return

	if !player_body:
		return

	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = player_body.transform.basis * Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	is_moving = input_direction_2D.length() > 0.0

	# --- State gerak (jongkok > lari bila stamina cukup > jalan) ---
	var crouch_held := Input.is_action_pressed("crouch")
	var sprint_held := Input.is_action_pressed("sprint")
	var can_sprint := sprint_held and is_moving and not crouch_held and not stamina_exhausted and stamina > 0.0
	if crouch_held:
		move_state = MoveState.CROUCH
	elif can_sprint:
		move_state = MoveState.SPRINT
	else:
		move_state = MoveState.WALK

	# Stamina: terkuras saat lari, pulih saat tidak.
	if move_state == MoveState.SPRINT:
		stamina -= STAMINA_DRAIN * delta
		if stamina <= 0.0:
			stamina = 0.0
			stamina_exhausted = true
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if stamina_exhausted and stamina >= STAMINA_RECOVER_THRESHOLD:
			stamina_exhausted = false

	var effective_speed: float = current_speed * _speed_multiplier()

	if is_moving:
		player_body.velocity.x = direction.x * effective_speed
		player_body.velocity.z = direction.z * effective_speed
	else:
		var horizontal_velocity = Vector2(player_body.velocity.x, player_body.velocity.z)
		if horizontal_velocity.length() > MIN_VELOCITY_THRESHOLD:
			var deceleration_amount = DECELERATION * delta
			horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, deceleration_amount)
			player_body.velocity.x = horizontal_velocity.x
			player_body.velocity.z = horizontal_velocity.y
		else:
			player_body.velocity.x = 0.0
			player_body.velocity.z = 0.0

	player_body.velocity.y -= GRAVITY * delta

	# Tidak bisa lompat sambil jongkok
	if Input.is_action_just_pressed("jump") and player_body.is_on_floor() and move_state != MoveState.CROUCH:
		player_body.velocity.y = JUMP_VELOCITY

	player_body.move_and_slide()

	_update_crouch_camera(delta)
	_update_footstep_noise(delta, effective_speed)
	_update_flashlight_battery(delta)

	# Cooldowns
	if shoot_timer > 0:
		shoot_timer -= delta
	if stone_timer > 0:
		stone_timer -= delta

	if Input.is_action_just_pressed("shoot") and is_ketapel_active() and shoot_timer <= 0:
		shoot_ketapel()

func _speed_multiplier() -> float:
	match move_state:
		MoveState.SPRINT:
			return SPRINT_MULTIPLIER
		MoveState.CROUCH:
			return CROUCH_MULTIPLIER
		_:
			return 1.0

func _update_crouch_camera(delta: float):
	if not camera_node:
		return
	var target_h := CROUCH_CAM_HEIGHT if move_state == MoveState.CROUCH else STAND_CAM_HEIGHT
	camera_node.position.y = lerpf(camera_node.position.y, target_h, CAM_HEIGHT_LERP * delta)

func _update_footstep_noise(delta: float, _effective_speed: float):
	if not is_moving or not player_body.is_on_floor():
		step_timer = 0.0
		return
	step_timer += delta
	if step_timer >= _step_interval_for_state():
		step_timer = 0.0
		var loud := _footstep_loudness_for_state()
		if loud > 0.0:
			NoiseManager.emit_noise(player_body.global_position, loud)
		_play_footstep_sound()

func _play_footstep_sound():
	# Jongkok = senyap (tanpa suara langkah). Jalan/lari berbunyi.
	if move_state == MoveState.CROUCH:
		return
	if footstep_player and footstep_sound:
		footstep_player.stream = footstep_sound
		footstep_player.volume_db = -2.0 if move_state == MoveState.SPRINT else -8.0
		footstep_player.pitch_scale = 1.25 if move_state == MoveState.SPRINT else 1.0
		footstep_player.play()

func _step_interval_for_state() -> float:
	match move_state:
		MoveState.SPRINT:
			return 0.32
		MoveState.CROUCH:
			return 0.7
		_:
			return 0.5

func _footstep_loudness_for_state() -> float:
	match move_state:
		MoveState.SPRINT:
			return float(NoiseManager.LOUDNESS_RUN_STEP)
		MoveState.CROUCH:
			return float(NoiseManager.LOUDNESS_CROUCH_STEP)
		_:
			return float(NoiseManager.LOUDNESS_WALK_STEP)

# ===== DEKOY BATU (GDD: Q lempar batu untuk mengalihkan perhatian) =====
func throw_stone():
	if stone_timer > 0.0 or not stone_scene or not camera_node:
		return
	stone_timer = STONE_THROW_COOLDOWN

	var stone = stone_scene.instantiate()
	get_tree().current_scene.add_child(stone)

	var cam_xform := camera_node.global_transform
	stone.global_position = cam_xform.origin - cam_xform.basis.z * 0.8

	if stone is RigidBody3D:
		var throw_dir := (-cam_xform.basis.z + Vector3.UP * 0.35).normalized()
		stone.linear_velocity = throw_dir * STONE_THROW_FORCE

# ===== SENSES API (dibaca musuh & HUD) =====
func is_crouching() -> bool:
	return move_state == MoveState.CROUCH

func is_sprinting() -> bool:
	return move_state == MoveState.SPRINT and is_moving

func is_flashlight_on() -> bool:
	return flashlight_on

func set_in_bush(value: bool):
	in_bush = value

func is_hidden() -> bool:
	# Tersembunyi penuh: jongkok di dalam semak dan senter mati.
	return in_bush and is_crouching() and not flashlight_on

## Seberapa mudah player terlihat musuh (0 = tak terlihat, 1 = sangat mencolok).
func get_visibility() -> float:
	if is_hidden():
		return 0.04

	var vis := 0.5
	match move_state:
		MoveState.CROUCH:
			vis = 0.22
		MoveState.SPRINT:
			vis = 0.78
		_:
			vis = 0.5

	if not is_moving:
		vis *= 0.8
	if in_bush:
		vis *= 0.5
	if flashlight_on:
		vis = maxf(vis, 0.95)   # senter membuat sangat terlihat

	return clampf(vis, 0.0, 1.0)

func lock_input(locked: bool):
	input_locked = locked
	if locked:
		if player_body:
			player_body.velocity = Vector3.ZERO

# HUD ratios
func get_stamina_ratio() -> float:
	return stamina / STAMINA_MAX

func is_stamina_exhausted() -> bool:
	return stamina_exhausted

func get_battery_ratio() -> float:
	return battery / BATTERY_MAX

## Jumpscare: paksa player menatap si penangkap saat tertangkap.
func snap_look_at(target_pos: Vector3):
	if not player_body or not camera_node:
		return
	var flat_target := Vector3(target_pos.x, player_body.global_position.y, target_pos.z)
	if flat_target.distance_to(player_body.global_position) < 0.1:
		return
	player_body.look_at(flat_target, Vector3.UP)
	# Dongak sedikit ke "wajah" si penangkap.
	camera_node.rotation_degrees.x = 8.0

# ===== KETAPEL (opsional, dipertahankan dari versi lama) =====
func play_tool_animation():
	match current_tool:
		Tool.EGREK:
			play_egrek_animation()
		Tool.TOJOK:
			play_tojok_animation()
		Tool.KETAPEL:
			play_ketapel_animation()

func play_ketapel_animation():
	if not ketapel_node or not is_instance_valid(ketapel_node):
		return
	if not is_ketapel_active():
		return
	if not ketapel_animation_player:
		setup_ketapel_animation()
	if ketapel_animation_player and ketapel_animation_player.has_animation(KETAPEL_SHOOT_ANIM_NAME):
		ketapel_animation_player.play(KETAPEL_SHOOT_ANIM_NAME)
	else:
		play_ketapel_fallback_animation()

func play_ketapel_fallback_animation():
	if ketapel_node:
		var tween = create_tween()
		tween.set_parallel(true)
		var original_position = ketapel_node.position
		var recoil_position = original_position + Vector3(0, 0, -0.1)
		tween.tween_property(ketapel_node, "position", recoil_position, 0.1)
		tween.tween_property(ketapel_node, "position", original_position, 0.2).set_delay(0.1)

func play_egrek_animation():
	if !egrek_node:
		return
	var animation_enabled = egrek_node.get_meta("animation_enabled", true)
	if !animation_enabled:
		return
	var fiber_mesh = egrek_node.get_node_or_null("Fiber")
	if fiber_mesh and fiber_mesh is MeshInstance3D:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(fiber_mesh, "position:z", -0.3, 0.1)
		tween.tween_property(fiber_mesh, "position:z", 0.0, 0.2).set_delay(0.1)

func play_tojok_animation():
	if !tojok_node:
		return
	if tojok_shoot_tween and tojok_shoot_tween.is_valid():
		tojok_shoot_tween.kill()
	tojok_shoot_tween = create_tween()
	tojok_shoot_tween.set_parallel(true)
	tojok_shoot_tween.tween_property(tojok_node, "position", TOJOK_SHOOT_POSITION, 0.1)
	tojok_shoot_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_SHOOT_ROTATION, 0.1)
	tojok_shoot_tween.tween_property(tojok_node, "position", TOJOK_DEFAULT_POSITION, 0.2).set_delay(0.1)
	tojok_shoot_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_DEFAULT_ROTATION, 0.2).set_delay(0.1)

const KETAPEL_RANGE: float = 60.0

func shoot_ketapel():
	if not is_ketapel_active() or shoot_timer > 0 or not camera_node:
		return
	shoot_timer = SHOOT_COOLDOWN
	play_ketapel_animation()

	# Raycast konsisten dari tengah kamera ke arah pandang (hitscan), bukan RayCast3D anak
	# yang state-nya bisa basi. Lebih akurat & stabil.
	var space := get_world_3d().direct_space_state
	var origin := camera_node.global_position
	var dir := -camera_node.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * KETAPEL_RANGE)
	query.collision_mask = 0b111111
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if player_body:
		query.exclude = [player_body.get_rid()]
	var hit := space.intersect_ray(query)
	if hit:
		handle_ketapel_collision(hit.collider)

func handle_ketapel_collision(collider: Object):
	if not collider:
		return
	var ancestor = collider
	while ancestor and ancestor != get_tree().root:
		if ancestor.is_in_group("harvester_npc"):
			if ancestor.has_method("stun_enemy"):
				ancestor.stun_enemy(2.0)
			return
		elif ancestor.is_in_group("wild_boar"):
			if ancestor.has_method("stun_boar"):
				ancestor.stun_boar(1.5)
			return
		ancestor = ancestor.get_parent()

func is_egrek_active() -> bool:
	return current_tool == Tool.EGREK

func is_tojok_active() -> bool:
	return current_tool == Tool.TOJOK

func is_ketapel_active() -> bool:
	return current_tool == Tool.KETAPEL

func get_current_tool() -> Tool:
	return current_tool
