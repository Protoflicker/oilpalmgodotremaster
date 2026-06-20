extends CharacterBody3D
class_name Player

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek
@onready var tojok = $PlayerController/Camera3D/Tojok

# --- RAIN PARTICLE SYSTEM ---
@export var rain_particle_node: GPUParticles3D
# ----------------------------------

signal carried_fruits_updated(ripe_count, total_kg)
signal player_fully_ready

# HEALTH SYSTEM SIGNALS - DITAMBAHKAN DARI BRANCH ANSELMARIO
signal health_changed(current_health: int, max_health: int)
signal player_died

# STEALTH/HORROR: instant death sesuai GDD (tertangkap / satwa liar = game over)
signal player_caught(reason: String)

# Ubah sistem bawa buah
var carried_ripe_fruits: int = 0
var carried_ripe_kg: int = 0
var in_delivery_zone: bool = false
var current_delivery_zone: DeliveryZone = null
var inventory_system: Node
var ui_manager: UIManager

const BASE_SPEED = 18
var speed_reduction_factor: float = 0.03

var is_fully_initialized: bool = false

# VARIABEL UNTUK AIR
var water_slow_factor: float = 0
var is_in_water: bool = false
var original_speed: float = BASE_SPEED

# HEALTH SYSTEM VARIABLES - DITAMBAHKAN DARI BRANCH ANSELMARIO
const MAX_HEALTH: int = 100
var current_health: int = MAX_HEALTH
var is_dead: bool = false

# RESPAWN SYSTEM (konsep Hello Neighbor: tertangkap = balik ke spawn, bukan mati)
var respawn_position: Vector3 = Vector3.ZERO
var capture_count: int = 0
var is_respawning: bool = false
const RESPAWN_BLACKOUT_TIME: float = 1.4

# Setter untuk speed reduction factor
func set_speed_reduction_factor(new_factor: float):
	speed_reduction_factor = new_factor
	print("Player speed reduction factor diatur ke: ", speed_reduction_factor)
	update_speed()

func _ready():
	add_to_group("player")
	respawn_position = global_position
	setup_components()
	
	if player_controller:
		player_controller.set_current_speed(BASE_SPEED)
	
	find_inventory_system()
	find_ui_manager()
	
	# --- RAIN VISIBILITY FIX ---
	if rain_particle_node:
		rain_particle_node.visibility_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	# ----------------------------------
	
	await get_tree().process_frame
	is_fully_initialized = true
	player_fully_ready.emit()

# --- UPDATE RAIN POSITION EVERY FRAME ---
func _process(delta):
	move_rain_to_player()
# ----------------------------------------

# --- RAIN LOGIC FUNCTIONS ---
func move_rain_to_player():
	if rain_particle_node:
		var target_pos = global_position
		
		# Offset berdasarkan velocity untuk mencegah outrunning
		var velocity_offset = Vector3(velocity.x, 0, velocity.z) * 0.5
		target_pos += velocity_offset
		
		target_pos.y += 10.0
		rain_particle_node.global_position = target_pos
# ----------------------------------------

func get_base_speed() -> float:
	return BASE_SPEED

func setup_components():
	if player_controller:
		player_controller.player_body = self
		player_controller.camera_node = camera
		player_controller.egrek_node = egrek
		player_controller.tojok_node = tojok
		
		# Cari node Ketapel di scene
		var ketapel = camera.get_node_or_null("Ketapel")
		if ketapel:
			player_controller.ketapel_node = ketapel
		else:
			print("Warning: Ketapel node not found under camera")
	
	if interaction_system:
		interaction_system.camera = camera
		interaction_system.player_controller = player_controller

func find_inventory_system():
	var paths_to_try = [
		"/root/Node3D/InventorySystem",
		"/root/Level/InventorySystem",
		"../InventorySystem",
		"../../InventorySystem"
	]
	
	for path in paths_to_try:
		var node = get_node_or_null(path)
		if node and node.has_method("add_unripe_fruit_kg"):
			inventory_system = node
			return
	
	var nodes = get_tree().get_nodes_in_group("inventory_system")
	if nodes.size() > 0:
		inventory_system = nodes[0]

func find_ui_manager():
	var paths_to_try = [
		"/root/Node3D/UIManager",
		"../UIManager",
		"../../UIManager"
	]
	
	for path in paths_to_try:
		ui_manager = get_node_or_null(path)
		if ui_manager:
			break
	
	if ui_manager == null:
		var ui_managers = get_tree().get_nodes_in_group("ui_manager")
		if ui_managers.size() > 0:
			ui_manager = ui_managers[0]

func set_in_delivery_zone(is_in_zone: bool, zone: DeliveryZone):
	in_delivery_zone = is_in_zone
	current_delivery_zone = zone

func add_to_inventory(fruit_type: String):
	var weight_kg: int = 0
	
	if fruit_type == "Masak":
		weight_kg = randi_range(30, 40)
		carried_ripe_fruits += 1
		carried_ripe_kg += weight_kg
		carried_fruits_updated.emit(carried_ripe_fruits, carried_ripe_kg)
		update_speed()
	elif fruit_type == "Mentah":
		weight_kg = randi_range(25, 30)
		if inventory_system:
			inventory_system.add_unripe_fruit_kg(weight_kg)

func deliver_fruits():
	if not in_delivery_zone or not current_delivery_zone:
		return false

	# GDD: kalau sopir sudah kabur, buah tak bisa disetor lagi.
	if current_delivery_zone.has_method("is_driver_present") and not current_delivery_zone.is_driver_present():
		if ui_manager:
			ui_manager.show_interaction_label(Loc.t("driver_gone"))
		return false

	if carried_ripe_fruits > 0:
		if inventory_system:
			inventory_system.add_delivered_ripe_kg(carried_ripe_kg)
		
		if ui_manager:
			ui_manager.show_delivery_notification(carried_ripe_kg)
		
		carried_ripe_fruits = 0
		carried_ripe_kg = 0
		carried_fruits_updated.emit(0, 0)
		update_speed_with_water()
		return true
	
	return false

func update_speed():
	update_speed_with_water()

func apply_water_slowdown(factor: float):
	if not is_in_water:
		is_in_water = true
		water_slow_factor = factor
		print("Player terkena efek air: ", factor * 100, "% slowdown")
		update_speed_with_water()
	else:
		water_slow_factor = max(water_slow_factor, factor)
		update_speed_with_water()

func remove_water_slowdown():
	if is_in_water:
		is_in_water = false
		water_slow_factor = 0.0
		print("Player keluar dari air")
		update_speed_with_water()

func update_speed_with_water():
	var total_kg = carried_ripe_kg
	var weight_reduction = total_kg * speed_reduction_factor
	
	var water_reduction = 0.0
	if is_in_water and water_slow_factor > 0:
		water_reduction = BASE_SPEED * water_slow_factor
	
	var new_speed = max(1.0, BASE_SPEED - weight_reduction - water_reduction)
	
	if player_controller:
		player_controller.set_current_speed(new_speed)
	
	print("===== SPEED CALCULATION =====")
	print("Base Speed: ", BASE_SPEED)
	print("Carried KG: ", total_kg, " | Weight Reduction: ", weight_reduction)
	print("In Water: ", is_in_water, " | Water Slow Factor: ", water_slow_factor)
	print("Water Reduction: ", water_reduction)
	print("New Speed: ", new_speed)
	print("=============================")

func get_initialization_status() -> bool:
	return is_fully_initialized

func is_player_ready() -> bool:
	return is_fully_initialized

func get_carried_ripe_fruits() -> int:
	return carried_ripe_fruits

func get_carried_ripe_kg() -> int:
	return carried_ripe_kg

# ===== CAUGHT = RESPAWN SYSTEM (konsep Hello Neighbor) =====
## Dipanggil musuh/satwa saat menangkap player. Player TIDAK mati — ia dibawa
## kembali ke titik spawn, kehilangan buah yang sedang dibawa, layar gelap sesaat.
func catch(reason: String = "Tertangkap penghuni kebun") -> void:
	if is_respawning or is_dead:
		return
	_respawn(reason)

## Kompatibilitas: serangan apa pun memicu penangkapan/respawn (bukan kematian).
func take_damage(_damage: int, reason: String = "Diserang satwa liar") -> void:
	catch(reason)

func _respawn(reason: String) -> void:
	is_respawning = true
	capture_count += 1
	print("TERTANGKAP (", capture_count, "): ", reason, " — kembali ke titik aman")

	# Buah yang sedang dibawa tercecer saat tertangkap.
	if carried_ripe_fruits > 0:
		carried_ripe_fruits = 0
		carried_ripe_kg = 0
		carried_fruits_updated.emit(0, 0)
		update_speed()

	# UI: teriakan/jumpscare + layar gelap.
	player_caught.emit(reason)

	# Kunci & hentikan player.
	if player_controller and player_controller.has_method("lock_input"):
		player_controller.lock_input(true)
	velocity = Vector3.ZERO

	# Musuh "kehilangan" player.
	_make_enemies_give_up()

	await get_tree().create_timer(RESPAWN_BLACKOUT_TIME).timeout
	if not is_instance_valid(self):
		return

	# Pindahkan kembali ke spawn.
	global_position = respawn_position
	velocity = Vector3.ZERO
	if player_controller and player_controller.has_method("lock_input"):
		player_controller.lock_input(false)
	is_respawning = false

func _make_enemies_give_up() -> void:
	for e in get_tree().get_nodes_in_group("harvester_npc"):
		if is_instance_valid(e) and e.has_method("give_up_chase"):
			e.give_up_chase()

func get_capture_count() -> int:
	return capture_count

func is_player_dead() -> bool:
	# Tidak ada kematian permanen di mode respawn.
	return false

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return MAX_HEALTH

# ===== STEALTH SENSES (delegasi ke PlayerController, dibaca musuh & HUD) =====
func is_crouching() -> bool:
	return player_controller.is_crouching() if player_controller else false

func is_sprinting() -> bool:
	return player_controller.is_sprinting() if player_controller else false

func is_flashlight_on() -> bool:
	return player_controller.is_flashlight_on() if player_controller else false

func get_visibility() -> float:
	return player_controller.get_visibility() if player_controller else 0.5

func is_hidden() -> bool:
	return player_controller.is_hidden() if player_controller else false

func set_in_bush(value: bool) -> void:
	if player_controller and player_controller.has_method("set_in_bush"):
		player_controller.set_in_bush(value)

## Jumpscare: arahkan pandangan player ke sumber ancaman (dipanggil saat tertangkap).
func face_threat(pos: Vector3) -> void:
	if player_controller and player_controller.has_method("snap_look_at"):
		player_controller.snap_look_at(pos)
