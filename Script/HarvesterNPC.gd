extends CharacterBody3D
class_name HarvesterNPC
## PENGHUNI KEBUN (musuh utama, GDD §5e-i).
## Pria gila yang berpatroli, menyelidiki sumber suara terakhir (Noise System),
## dan mengejar player saat terlihat (Visibility System). Menangkap player = GAME OVER.
## Catatan: nama class & group "harvester_npc" dipertahankan demi kompatibilitas scene.

enum NPCState { PATROL, INVESTIGATE, CHASE, CAUGHT, IDLE }

@export var animation_player: AnimationPlayer

# --- Statistik (boleh dioverride NPCManager / GameModeManager) ---
var patrol_speed: float = 3.0
var investigate_speed: float = 4.5
var chase_speed: float = 12.0

var sight_range: float = 18.0          # jangkauan lihat dasar (diskalakan visibility player)
var fov_degrees: float = 100.0         # sudut pandang
var catch_range: float = 1.8           # jarak tangkap = game over
var hearing_multiplier: float = 1.0    # sensitivitas pendengaran
var detection_fill_time: float = 0.9   # detik melihat (visibility penuh) untuk mulai mengejar
var has_flashlight: bool = false

# --- State ---
var current_state: NPCState = NPCState.PATROL
var player_node: Node3D = null

var detection_level: float = 0.0       # 0..1 meter terdeteksi
var lost_sight_timer: float = 0.0
const LOST_SIGHT_GRACE: float = 3.0    # detik kehilangan pandangan sebelum berhenti mengejar

var investigate_target: Vector3 = Vector3.ZERO
var investigate_timer: float = 0.0
const INVESTIGATE_LOOK_TIME: float = 4.0

var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer: float = 0.0
var patrol_points: Array[Vector3] = []
var home_position: Vector3 = Vector3.ZERO
const PATROL_WANDER_RADIUS: float = 18.0

var stuck_timer: float = 0.0
var stuck_check_position: Vector3 = Vector3.ZERO
const STUCK_THRESHOLD: float = 2.0
const MIN_MOVEMENT_DISTANCE: float = 0.4

var is_stunned: bool = false

# Audio
var audio_player: AudioStreamPlayer3D
var scream_sound: AudioStream
var footstep_player: AudioStreamPlayer3D
var walk_sound: AudioStream
var foot_timer: float = 0.0
var flashlight: SpotLight3D = null

const GRAVITY: float = 25.0

func _ready() -> void:
	add_to_group("harvester_npc")
	add_to_group("enemy")
	setup_collision_config()

	if not animation_player:
		find_animation_player_auto()

	setup_audio_player()
	home_position = global_position
	stuck_check_position = global_position

	# Dengarkan kebisingan dunia (player melangkah/panen/lempar batu).
	if NoiseManager and not NoiseManager.noise_emitted.is_connected(_on_noise_emitted):
		NoiseManager.noise_emitted.connect(_on_noise_emitted)

	if has_flashlight:
		_setup_flashlight()

	call_deferred("_late_init")

func _late_init() -> void:
	await get_tree().process_frame
	# Tempel ke tanah
	global_position = Vector3(global_position.x, global_position.y, global_position.z)
	find_player()
	_set_home_to_madman_house()
	gather_patrol_points()
	pick_new_patrol_target()
	transition_to_state(NPCState.PATROL)

func _set_home_to_madman_house() -> void:
	# Penghuni kebun "menjaga" rumahnya: jadikan pondok sebagai pusat patroli.
	var homes := get_tree().get_nodes_in_group("madman_home")
	if homes.size() > 0 and is_instance_valid(homes[0]):
		var house := homes[0] as Node3D
		if house:
			home_position = house.global_position

## Player lolos / respawn → musuh berhenti mengejar dan kembali berpatroli.
func give_up_chase() -> void:
	detection_level = 0.0
	lost_sight_timer = 0.0
	if current_state != NPCState.PATROL:
		pick_new_patrol_target()
		transition_to_state(NPCState.PATROL)

func setup_collision_config() -> void:
	collision_layer = 0
	set_collision_layer_value(4, true)   # layer musuh
	collision_mask = 1                    # hanya tabrakan dengan tanah/obstacle

func setup_audio_player() -> void:
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.bus = "SFX"
	audio_player.max_distance = 30.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if ResourceLoader.exists("res://soundeffect/screamman.mp3"):
		scream_sound = load("res://soundeffect/screamman.mp3")

	# Suara langkah si penghuni kebun — terdengar dari jauh (mencekam).
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.bus = "SFX"
	footstep_player.max_distance = 28.0
	footstep_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(footstep_player)
	if ResourceLoader.exists("res://soundeffect/walk.mp3"):
		walk_sound = load("res://soundeffect/walk.mp3")

func _setup_flashlight() -> void:
	flashlight = SpotLight3D.new()
	flashlight.light_energy = 5.0
	flashlight.light_color = Color(1.0, 0.93, 0.78)
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 28.0
	flashlight.spot_attenuation = 1.5
	flashlight.shadow_enabled = true
	add_child(flashlight)
	flashlight.position = Vector3(0.0, 1.6, -0.3)
	flashlight.rotation = Vector3.ZERO   # menyorot -Z (arah hadap)

func play_scream_sound() -> void:
	if audio_player and scream_sound:
		audio_player.stream = scream_sound
		audio_player.play()

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		var anim = animation_player.get_animation(anim_name)
		if anim and anim_name == "Jalan":
			anim.loop_mode = Animation.LOOP_LINEAR
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

func find_animation_player_auto() -> void:
	animation_player = find_child("AnimationPlayer", true, false)
	if not animation_player:
		var maling_node = find_child("Maling", true, false)
		if maling_node:
			animation_player = maling_node.find_child("AnimationPlayer", true, false)

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]

func gather_patrol_points() -> void:
	patrol_points.clear()
	for node in get_tree().get_nodes_in_group("patrol_point"):
		if is_instance_valid(node) and node is Node3D:
			patrol_points.append(node.global_position)

# ========================= MAIN LOOP =========================
func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if is_stunned:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not player_node or not is_instance_valid(player_node):
		find_player()

	update_detection(delta)
	state_process(delta)
	move_and_slide()
	_update_footsteps(delta)

func _update_footsteps(delta: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	if horiz < 0.4:
		foot_timer = 0.0
		return
	foot_timer += delta
	var interval := 0.34 if current_state == NPCState.CHASE else 0.5
	if foot_timer >= interval:
		foot_timer = 0.0
		if footstep_player and walk_sound and not footstep_player.playing:
			footstep_player.stream = walk_sound
			footstep_player.play()

func update_detection(delta: float) -> void:
	if not player_node or not is_instance_valid(player_node):
		return
	if player_node.has_method("is_player_dead") and player_node.is_player_dead():
		return

	var sees := can_see_player()

	if sees:
		lost_sight_timer = 0.0
		var vis := 0.5
		if player_node.has_method("get_visibility"):
			vis = float(player_node.get_visibility())
		# Mengisi lebih cepat bila player lebih terlihat & lebih dekat.
		var dist := global_position.distance_to(player_node.global_position)
		var closeness := clampf(1.0 - dist / maxf(sight_range, 1.0), 0.2, 1.0)
		detection_level += delta * (vis * closeness) / detection_fill_time
		if current_state != NPCState.CHASE and detection_level >= 1.0:
			transition_to_state(NPCState.CHASE)
	else:
		lost_sight_timer += delta
		detection_level -= delta * 0.5

	detection_level = clampf(detection_level, 0.0, 1.0)

func can_see_player() -> bool:
	if not player_node or not is_instance_valid(player_node):
		return false
	if player_node.has_method("is_hidden") and player_node.is_hidden():
		return false

	var eye := global_position + Vector3.UP * 1.5
	var ppos := player_node.global_position + Vector3.UP * 1.0
	var to_p := ppos - eye
	var dist := to_p.length()

	var vis := 0.5
	if player_node.has_method("get_visibility"):
		vis = float(player_node.get_visibility())

	var eff_range := sight_range * (0.35 + 0.65 * vis)
	if dist > eff_range:
		return false

	# Sudut pandang (lebih lebar saat sangat dekat = persepsi periferal)
	var forward := -global_transform.basis.z
	var dir_p := to_p.normalized()
	var ang := rad_to_deg(acos(clampf(forward.dot(dir_p), -1.0, 1.0)))
	var half_fov := fov_degrees * 0.5
	if dist < 3.0:
		half_fov = 130.0
	if ang > half_fov:
		return false

	# Garis pandang (terhalang obstacle?)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, ppos)
	query.exclude = [self, player_node]
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit:
		return false

	return true

func state_process(delta: float) -> void:
	match current_state:
		NPCState.PATROL:
			_process_patrol(delta)
		NPCState.INVESTIGATE:
			_process_investigate(delta)
		NPCState.CHASE:
			_process_chase(delta)
		NPCState.CAUGHT:
			velocity.x = 0.0
			velocity.z = 0.0
		NPCState.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0

func _process_patrol(delta: float) -> void:
	var dist := global_position.distance_to(patrol_target)
	if dist <= 1.5:
		# Berhenti sejenak & melihat sekeliling
		velocity.x = 0.0
		velocity.z = 0.0
		patrol_wait_timer += delta
		_look_around(delta)
		if patrol_wait_timer >= 2.5:
			patrol_wait_timer = 0.0
			pick_new_patrol_target()
	else:
		move_towards(patrol_target, patrol_speed)
		check_if_stuck(delta, func(): pick_new_patrol_target())

func _process_investigate(delta: float) -> void:
	var dist := global_position.distance_to(investigate_target)
	if dist <= 1.6:
		velocity.x = 0.0
		velocity.z = 0.0
		investigate_timer += delta
		_look_around(delta)
		if investigate_timer >= INVESTIGATE_LOOK_TIME:
			# Tidak menemukan apa-apa → patroli adaptif di sekitar suara terakhir.
			home_position = investigate_target
			pick_new_patrol_target()
			transition_to_state(NPCState.PATROL)
	else:
		move_towards(investigate_target, investigate_speed)
		check_if_stuck(delta, func(): transition_to_state(NPCState.PATROL))

func _process_chase(_delta: float) -> void:
	if not player_node or not is_instance_valid(player_node):
		transition_to_state(NPCState.PATROL)
		return
	if player_node.has_method("is_player_dead") and player_node.is_player_dead():
		transition_to_state(NPCState.IDLE)
		return

	var dist := global_position.distance_to(player_node.global_position)

	# Tangkap player!
	if dist <= catch_range:
		_catch_player()
		return

	move_towards(player_node.global_position, chase_speed)

	# Kehilangan pandangan terlalu lama → selidiki posisi terakhir.
	if not can_see_player():
		if lost_sight_timer >= LOST_SIGHT_GRACE:
			investigate_target = player_node.global_position
			transition_to_state(NPCState.INVESTIGATE)
	else:
		investigate_target = player_node.global_position

func _catch_player() -> void:
	if current_state == NPCState.CAUGHT:
		return
	transition_to_state(NPCState.CAUGHT)
	# Hadap player & teriak
	var dir := (player_node.global_position - global_position).normalized()
	dir.y = 0.0
	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)
	play_scream_sound()
	if player_node.has_method("face_threat"):
		player_node.face_threat(global_position + Vector3.UP * 1.6)
	if player_node.has_method("catch"):
		player_node.catch("Tertangkap penghuni kebun!")

func _look_around(delta: float) -> void:
	# Putar perlahan untuk memindai area.
	rotate_y(delta * 1.2)
	play_animation("Jalan")

func move_towards(target_position: Vector3, speed: float) -> void:
	var target_flat := Vector3(target_position.x, global_position.y, target_position.z)
	var direction := (target_flat - global_position)
	direction.y = 0.0
	var d := direction.length()
	if d > 0.3:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		look_at(global_position + direction, Vector3.UP)
		play_animation("Jalan")
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func check_if_stuck(delta: float, on_stuck: Callable) -> void:
	var moved := global_position.distance_to(stuck_check_position)
	if moved < MIN_MOVEMENT_DISTANCE and Vector2(velocity.x, velocity.z).length() < 0.2:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		stuck_check_position = global_position
	if stuck_timer >= STUCK_THRESHOLD:
		stuck_timer = 0.0
		stuck_check_position = global_position
		on_stuck.call()

func pick_new_patrol_target() -> void:
	if patrol_points.size() > 0:
		patrol_target = patrol_points[randi() % patrol_points.size()]
		return
	# Wander acak di sekitar home.
	var angle := randf() * TAU
	var radius := randf_range(4.0, PATROL_WANDER_RADIUS)
	patrol_target = home_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

# ========================= TRANSITIONS =========================
func transition_to_state(new_state: NPCState) -> void:
	if current_state == new_state:
		return
	var prev := current_state
	current_state = new_state

	match new_state:
		NPCState.PATROL:
			patrol_wait_timer = 0.0
		NPCState.INVESTIGATE:
			investigate_timer = 0.0
		NPCState.CHASE:
			if prev != NPCState.CHASE:
				play_scream_sound()
		NPCState.CAUGHT:
			velocity = Vector3.ZERO
		NPCState.IDLE:
			velocity = Vector3.ZERO

	stuck_timer = 0.0
	stuck_check_position = global_position

# ========================= HEARING =========================
func _on_noise_emitted(noise_pos: Vector3, loudness: float) -> void:
	if current_state == NPCState.CHASE or current_state == NPCState.CAUGHT:
		return
	if is_stunned:
		return
	var dist := global_position.distance_to(noise_pos)
	# Terdengar jika dalam radius (loudness) dikali sensitivitas.
	if dist <= loudness * hearing_multiplier:
		investigate_target = noise_pos
		# Naikkan sedikit kecurigaan.
		detection_level = max(detection_level, 0.25)
		transition_to_state(NPCState.INVESTIGATE)

# ========================= PUBLIC API (HUD / ketapel) =========================
func get_detection_level() -> float:
	return detection_level

func get_alert_state() -> String:
	match current_state:
		NPCState.CHASE, NPCState.CAUGHT:
			return "alerted"
		NPCState.INVESTIGATE:
			return "suspicious"
		_:
			return "calm" if detection_level < 0.3 else "suspicious"

func is_chasing() -> bool:
	return current_state == NPCState.CHASE

func stun_enemy(duration: float = 2.0) -> void:
	if is_stunned:
		return
	is_stunned = true
	detection_level = 0.0
	velocity = Vector3.ZERO
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	if is_instance_valid(self) and current_state != NPCState.CAUGHT:
		transition_to_state(NPCState.PATROL)

# Kompatibilitas dengan NPCManager lama (tidak ada efek di mode stealth).
func set_carry_capacity(_capacity: int) -> void:
	pass

func configure(cfg: Dictionary) -> void:
	patrol_speed = cfg.get("patrol_speed", patrol_speed)
	chase_speed = cfg.get("chase_speed", chase_speed)
	sight_range = cfg.get("sight_range", sight_range)
	fov_degrees = cfg.get("fov_degrees", fov_degrees)
	has_flashlight = cfg.get("has_flashlight", has_flashlight)
	if has_flashlight and not flashlight:
		_setup_flashlight()
