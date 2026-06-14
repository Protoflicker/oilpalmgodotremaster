extends Node3D
class_name GameModeManager
## Mengatur satu ronde level: memuat konfigurasi dari GameState (kuota, waktu,
## jumlah musuh & satwa), menjalankan timer, dan menentukan menang/kalah.
## MENANG : kuota terpenuhi & player berada di zona ekstraksi (sopir masih ada) sebelum waktu habis.
## KALAH  : tertangkap penghuni kebun / diserang satwa liar / waktu habis.

@export var level_number: int = 1

# Skala dunia: memperbesar peta agar terasa luas, sunyi, & mencekam.
@export var world_scale: float = 2.0

# Fallback config (dipakai bila GameState tidak tersedia / dijalankan langsung dari editor).
@export var round_duration: float = 210.0
@export var player_speed_reduction_per_kg: float = 0.03
@export var ripe_fruit_price: int = 2000
@export var time_bonus_per_second: int = 50

# Konfigurasi Genangan (water pools) - dipertahankan dari versi lama.
@export var water_pool_count: int = 0
@export var water_pool_scene: PackedScene = null
@export var spawn_area_size: Vector3 = Vector3(50, 0, 50)
@export var min_spawn_distance_from_player: float = 10.0
@export var min_distance_between_pools: float = 5.0
@export var spawn_height_above_ground: float = 0.1
@export var raycast_start_height: float = 10.0
@export var max_spawn_attempts_per_pool: int = 30

# Semak persembunyian yang disebar otomatis (GDD: Hiding & Stealth).
@export var hiding_bush_count: int = 16
@export var hiding_bush_area: Vector3 = Vector3(110, 0, 110)
var hiding_bush_scene: PackedScene = preload("res://Scene/HidingBush.tscn")
var pondok_scene: PackedScene = preload("res://Scene/Pondok.tscn")

# Isi peta besar dengan pohon sawit tambahan agar terasa perkebunan yang luas & lebat.
@export var extra_tree_count: int = 35
var tree_scene: PackedScene = preload("res://Scene/Tree.tscn")

# Konfigurasi level aktif (diambil dari GameState).
var quota_kg: int = 0
var is_tutorial: bool = false
var _cfg: Dictionary = {}

var remaining_time: float = 0.0
var is_round_active: bool = false
var has_ended: bool = false
var quota_met: bool = false
var last_delivered: int = -1

var inventory_system: InventorySystem
var npc_manager: NPCManager
var ui_manager: UIManager
var player: Node = null

var water_pool_container: Node3D
var current_water_pools: Array = []

signal game_time_updated(remaining_time)
signal round_ended_with_score(final_score, score_details)   # MENANG
signal game_over_triggered(reason)                          # KALAH
signal round_started()
signal quota_updated(current_kg, target_kg)

func _ready():
	add_to_group("game_mode_manager")
	GameState.set_current_level(level_number)
	call_deferred("initialize_systems")

func initialize_systems():
	find_systems()
	await get_tree().process_frame
	_load_level_config()
	_scale_world()
	apply_config_to_systems()
	_apply_atmosphere()
	_spawn_madman_house()
	_spawn_horror_overlay()
	initialize_water_pool_system()
	_scatter_hiding_bushes()
	_fill_plantation()
	start_round()

func _load_level_config():
	_cfg = GameState.get_config(level_number)
	quota_kg = int(_cfg.get("quota_kg", 0))
	is_tutorial = bool(_cfg.get("is_tutorial", quota_kg <= 0))
	round_duration = float(_cfg.get("round_duration", round_duration))

func find_systems():
	var attempts = 0
	while attempts < 5 and (not inventory_system or not npc_manager):
		inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		if not inventory_system:
			var inventory_nodes = get_tree().get_nodes_in_group("inventory_system")
			if inventory_nodes.size() > 0:
				inventory_system = inventory_nodes[0]

		npc_manager = get_node_or_null("/root/Node3D/NPCManager")
		if not npc_manager:
			var npc_managers = get_tree().get_nodes_in_group("npc_manager")
			if npc_managers.size() > 0:
				npc_manager = npc_managers[0]

		attempts += 1
		if not inventory_system or not npc_manager:
			await get_tree().create_timer(0.1).timeout

	ui_manager = get_node_or_null("/root/Node3D/UIManager")
	if not ui_manager:
		var ui_managers = get_tree().get_nodes_in_group("ui_manager")
		if ui_managers.size() > 0:
			ui_manager = ui_managers[0]

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func apply_config_to_systems():
	if player and player.has_method("set_speed_reduction_factor"):
		player.set_speed_reduction_factor(player_speed_reduction_per_kg)

	var enemy_count := int(_cfg.get("enemy_count", 0))
	var boar_count := int(_cfg.get("boar_count", 0))
	var enemy_has_flashlight := bool(_cfg.get("enemy_has_flashlight", false))
	var tiger_enabled := bool(_cfg.get("tiger_enabled", false))

	if npc_manager:
		if npc_manager.has_method("set_max_npcs"):
			npc_manager.set_max_npcs(enemy_count)
		if npc_manager.has_method("set_max_wildboars"):
			npc_manager.set_max_wildboars(boar_count)
		if npc_manager.has_method("set_enemy_config"):
			npc_manager.set_enemy_config({
				"has_flashlight": enemy_has_flashlight,
				"chase_speed": 12.0,
				"patrol_speed": 3.0,
				"sight_range": 18.0,
				"fov_degrees": 100.0,
			})
		if npc_manager.has_method("set_boar_config"):
			if tiger_enabled:
				npc_manager.set_boar_config({
					"is_tiger": true,
					"move_speed": 13.0,
					"detection_range": 26.0,
					"attack_range": 3.0,
				})
			else:
				npc_manager.set_boar_config({"is_tiger": false})

	print("GameModeManager: Level ", level_number, " | Kuota ", quota_kg,
		" kg | Musuh ", enemy_count, " | Babi ", boar_count, " | Durasi ", round_duration)

func _scale_world():
	if is_equal_approx(world_scale, 1.0):
		return
	var f := world_scale
	var root := get_tree().current_scene
	if root == null:
		return

	# Tanah + tembok batas (StaticBody3D berisi Map & collision) → diperbesar.
	var env := root.get_node_or_null("StaticBody3D")
	if env and env is Node3D:
		(env as Node3D).scale *= f

	# Pohon: renggangkan jarak antar pohon, ukuran pohon tetap.
	var trees := root.get_node_or_null("Trees")
	if trees and trees is Node3D:
		(trees as Node3D).position *= f
		for c in trees.get_children():
			if c is Node3D:
				(c as Node3D).position *= f

	# Zona ekstraksi (mobil pickup) → relokasi sesuai skala.
	var dz := root.get_node_or_null("DeliveryZones")
	if dz and dz is Node3D:
		(dz as Node3D).position *= f
		for c in dz.get_children():
			if c is Node3D:
				(c as Node3D).position *= f

	# Titik spawn musuh tersebar lebih jauh.
	if npc_manager:
		for m in npc_manager.manual_spawn_points:
			if is_instance_valid(m):
				m.position *= f

	# Reposisi player + perbarui titik respawn-nya.
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			var np := p as Node3D
			np.global_position = Vector3(np.global_position.x * f, 6.0, np.global_position.z * f)
			np.set("respawn_position", np.global_position)

	# Sebaran semak ikut melebar.
	hiding_bush_area *= f
	print("GameModeManager: dunia diperbesar x", f)

func _spawn_madman_house():
	if not pondok_scene:
		return
	var center := _madman_house_center()
	var pos := _ground_at(center)
	var house = pondok_scene.instantiate()
	get_tree().current_scene.add_child(house)
	house.global_position = pos
	print("GameModeManager: Pondok penghuni kebun ditempatkan di ", pos)

func _madman_house_center() -> Vector3:
	var pts: Array[Vector3] = []
	if npc_manager and npc_manager.manual_spawn_points:
		for m in npc_manager.manual_spawn_points:
			if is_instance_valid(m):
				pts.append(m.global_position)
	if pts.is_empty():
		for m in get_tree().get_nodes_in_group("npc_spawn"):
			if is_instance_valid(m) and m is Node3D:
				pts.append((m as Node3D).global_position)
	if pts.is_empty():
		return global_position
	var sum := Vector3.ZERO
	for p in pts:
		sum += p
	return sum / float(pts.size())

func _ground_at(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var start := Vector3(p.x, p.y + 30.0, p.z)
	var endp := Vector3(p.x, p.y - 100.0, p.z)
	var q := PhysicsRayQueryParameters3D.create(start, endp)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if hit:
		var gp: Vector3 = hit.position
		return gp
	return Vector3(p.x, 0.0, p.z)

func _spawn_horror_overlay():
	var ov = load("res://Script/HorrorOverlay.gd").new()
	get_tree().current_scene.add_child(ov)

func start_round():
	remaining_time = round_duration
	is_round_active = true
	has_ended = false
	quota_met = (quota_kg <= 0)

	cleanup_existing_water_pools()
	spawn_all_water_pools_at_start()

	round_started.emit()
	game_time_updated.emit(remaining_time)
	quota_updated.emit(0, quota_kg)

func _process(delta):
	if not is_round_active or has_ended:
		return
	if get_tree().paused:
		return

	remaining_time -= delta

	if int(remaining_time) != int(remaining_time + delta):
		game_time_updated.emit(remaining_time)

	_update_quota()
	_check_win()

	if remaining_time <= 0:
		remaining_time = 0
		_lose("Waktu habis! Sopir pergi tanpamu.")

func _update_quota():
	if not inventory_system:
		return
	var delivered: int = inventory_system.get_delivered_ripe_kg()
	if delivered != last_delivered:
		last_delivered = delivered
		quota_updated.emit(delivered, quota_kg)

	if not quota_met and quota_kg > 0 and delivered >= quota_kg:
		quota_met = true
		if ui_manager and ui_manager.has_method("show_notification"):
			ui_manager.show_notification("Kuota terpenuhi! Kembali ke mobil pickup untuk kabur.")

func _check_win():
	if not quota_met:
		return
	# Cegah menang instan bila player kebetulan spawn di dalam zona ekstraksi.
	if round_duration - remaining_time < 2.0:
		return
	if not player or not player.get("in_delivery_zone"):
		return

	var driver_ok := true
	var zone = player.get("current_delivery_zone")
	if zone and zone.has_method("is_driver_present"):
		driver_ok = zone.is_driver_present()

	if driver_ok:
		_win()

func _win():
	if has_ended:
		return
	has_ended = true
	is_round_active = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var result := _calculate_score()
	GameState.add_money(int(result["final_score"]))
	round_ended_with_score.emit(int(result["final_score"]), result["details"])

func _lose(reason: String):
	if has_ended:
		return
	has_ended = true
	is_round_active = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_over_triggered.emit(reason)

func _calculate_score() -> Dictionary:
	var delivered: int = 0
	if inventory_system and inventory_system.has_method("get_delivered_ripe_kg"):
		delivered = inventory_system.get_delivered_ripe_kg()

	var ripe_income: int = delivered * ripe_fruit_price
	var time_bonus: int = int(remaining_time) * time_bonus_per_second
	var final_score: int = ripe_income + time_bonus

	var details := {
		"delivered_ripe_kg": delivered,
		"ripe_income": ripe_income,
		"time_bonus": time_bonus,
		"remaining_time": int(remaining_time),
		"quota_kg": quota_kg,
		"ripe_fruit_price": ripe_fruit_price,
	}
	return {"final_score": final_score, "details": details}

func get_remaining_time() -> float:
	return remaining_time

func is_round_running() -> bool:
	return is_round_active and remaining_time > 0

# ===================== WATER POOL SYSTEM (dipertahankan) =====================
func initialize_water_pool_system():
	if not has_node("WaterPoolsContainer"):
		water_pool_container = Node3D.new()
		water_pool_container.name = "WaterPoolsContainer"
		add_child(water_pool_container)
	else:
		water_pool_container = get_node("WaterPoolsContainer")
	current_water_pools.clear()

func spawn_all_water_pools_at_start():
	if not water_pool_scene:
		return
	for i in range(water_pool_count):
		try_spawn_single_water_pool()

func try_spawn_single_water_pool() -> bool:
	var spawn_position = find_valid_spawn_position_for_pool()
	if spawn_position == Vector3.ZERO:
		return false
	var new_water_pool_instance = water_pool_scene.instantiate()
	water_pool_container.add_child(new_water_pool_instance)
	new_water_pool_instance.global_position = spawn_position
	current_water_pools.append(new_water_pool_instance)
	return true

func find_valid_spawn_position_for_pool() -> Vector3:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return Vector3.ZERO
	var player_ref = players[0]
	var player_position = player_ref.global_position
	var attempts = 0

	while attempts < max_spawn_attempts_per_pool:
		var random_offset = Vector3(
			randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2),
			0,
			randf_range(-spawn_area_size.z / 2, spawn_area_size.z / 2)
		)
		var final_position = global_position + random_offset

		var distance_to_player = final_position.distance_to(player_position)
		if distance_to_player < min_spawn_distance_from_player:
			attempts += 1
			continue

		var too_close = false
		for existing_pool in current_water_pools:
			if is_instance_valid(existing_pool):
				if final_position.distance_to(existing_pool.global_position) < min_distance_between_pools:
					too_close = true
					break
		if too_close:
			attempts += 1
			continue

		var space_state = get_world_3d().direct_space_state
		var ray_start = final_position + Vector3(0, raycast_start_height, 0)
		var ray_end = final_position - Vector3(0, 100, 0)
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = 1
		query.exclude = [player_ref]
		var result = space_state.intersect_ray(query)
		if result:
			return result.position + Vector3(0, spawn_height_above_ground, 0)
		attempts += 1

	return Vector3.ZERO

func cleanup_existing_water_pools():
	for water_pool in current_water_pools:
		if is_instance_valid(water_pool):
			water_pool.queue_free()
	current_water_pools.clear()

# ===================== ATMOSFER HORROR (per waktu hari) =====================
func _apply_atmosphere():
	var preset: Dictionary = GameState.get_time_preset(level_number)
	var root := get_tree().current_scene

	var env_node := _find_node_of_type(root, "WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.fog_enabled = true
		env.fog_light_color = preset["fog_color"]
		env.fog_density = preset["fog_density"]
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = preset["ambient_color"]
		env.ambient_light_energy = preset["ambient_energy"]
		# Redupkan langit panorama agar terasa malam.
		var sky := env.sky
		if sky and sky.sky_material and sky.sky_material is ShaderMaterial:
			(sky.sky_material as ShaderMaterial).set_shader_parameter("exposure", preset["sky_exposure"])

	var sun := _find_node_of_type(root, "DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_energy = preset["sun_energy"]
		sun.light_color = preset["sun_color"]

func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node == null:
		return null
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_node_of_type(child, type_name)
		if found:
			return found
	return null

# ===================== SEBAR SEMAK PERSEMBUNYIAN =====================
func _scatter_hiding_bushes():
	if not hiding_bush_scene:
		return
	var placed := 0
	var attempts := 0
	while placed < hiding_bush_count and attempts < hiding_bush_count * 8:
		attempts += 1
		var pos := _random_ground_position(hiding_bush_area)
		if pos == Vector3.ZERO:
			continue
		var bush := hiding_bush_scene.instantiate()
		get_tree().current_scene.add_child(bush)
		bush.global_position = pos
		placed += 1

func _fill_plantation():
	if not tree_scene or extra_tree_count <= 0:
		return

	var player_pos := Vector3(99999, 0, 99999)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node3D:
		player_pos = (players[0] as Node3D).global_position

	var house_pos := Vector3(99999, 0, 99999)
	var homes := get_tree().get_nodes_in_group("madman_home")
	if homes.size() > 0 and homes[0] is Node3D:
		house_pos = (homes[0] as Node3D).global_position

	var ext_pos := Vector3(99999, 0, 99999)
	var zones := get_tree().get_nodes_in_group("delivery_zone")
	if zones.size() > 0 and zones[0] is Node3D:
		ext_pos = (zones[0] as Node3D).global_position

	var placed_positions: Array[Vector3] = []
	var placed := 0
	var attempts := 0
	while placed < extra_tree_count and attempts < extra_tree_count * 10:
		attempts += 1
		var pos := _random_ground_position(hiding_bush_area)
		if pos == Vector3.ZERO:
			continue
		if pos.distance_to(player_pos) < 12.0:
			continue
		if pos.distance_to(house_pos) < 11.0:
			continue
		if pos.distance_to(ext_pos) < 12.0:
			continue
		var too_close := false
		for q in placed_positions:
			if pos.distance_to(q) < 7.0:
				too_close = true
				break
		if too_close:
			continue
		var t := tree_scene.instantiate()
		get_tree().current_scene.add_child(t)
		(t as Node3D).global_position = pos
		placed_positions.append(pos)
		placed += 1
	print("GameModeManager: ", placed, " pohon tambahan disebar")

func _random_ground_position(area: Vector3) -> Vector3:
	var origin := global_position + Vector3(
		randf_range(-area.x / 2.0, area.x / 2.0),
		0.0,
		randf_range(-area.z / 2.0, area.z / 2.0)
	)
	var space_state := get_world_3d().direct_space_state
	var ray_start := origin + Vector3(0, raycast_start_height + 20.0, 0)
	var ray_end := origin - Vector3(0, 100, 0)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	var result := space_state.intersect_ray(query)
	if result:
		return result.position
	return Vector3.ZERO
