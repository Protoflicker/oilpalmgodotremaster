extends RigidBody3D
class_name Fruit

var has_touched_surface = false
var is_falling = false
var fruit_type: String = "Masak"
var can_be_collected: bool = false
var has_been_collected: bool = false
var has_given_points: bool = false

var lod_self_update_timer: float = 0.0
var culling_self_update_timer: float = 0.0
var current_lod_level: String = "high"
var player_node: Node3D = null
var camera_node: Camera3D = null

var is_culled: bool = false
var was_frozen: bool = true
var current_update_interval: float = 0.3

@export var linear_damping = 0.5
@export var angular_damping = 2.0
@export var fruit_mass = 1.0

var ripe_model_high = preload("res://3D Asset/Buah_Sawit_Masak.gltf")
var unripe_model_high = preload("res://3D Asset/Buah_Sawit_Mentah.gltf")
var ripe_model_low = preload("res://3D Asset/Buah_Sawit_Masak_LowMesh.gltf")
var unripe_model_low = preload("res://3D Asset/Buah_Sawit_Mentah_LowMesh.gltf")

const LOD_HIGH_DISTANCE = 20
const LOD_LOW_DISTANCE = 25
const CULLING_DISTANCE: float = 50.0
const MIN_CULLING_DISTANCE: float = 10
const BACKFACE_THRESHOLD: float = 0.3
const NEAR_UPDATE_INTERVAL: float = 0.05
const FAR_UPDATE_INTERVAL: float = 0.3

const AREA_OFFSET = Vector3(0, -0.8, 0)
const COLLISION_RADIUS = 0.8

var is_initialized: bool = false
var use_tree_culling: bool = true
var parent_tree_ref: WeakRef = null

func _ready():
	add_to_group("buah")
	freeze = true
	was_frozen = true
	linear_damp = linear_damping
	angular_damp = angular_damping
	mass = fruit_mass
	setup_area_detector()
	call_deferred("initialize_fruit")

func set_parent_tree(tree: Node3D):
	parent_tree_ref = weakref(tree)
	var parent_tree = get_parent_tree()
	if parent_tree and parent_tree.player_node:
		player_node = parent_tree.player_node
		camera_node = parent_tree.camera_node

func get_parent_tree():
	if parent_tree_ref:
		return parent_tree_ref.get_ref()
	return null

func initialize_fruit():
	var parent_tree = get_parent_tree()
	if parent_tree and parent_tree.player_node:
		player_node = parent_tree.player_node
		camera_node = parent_tree.camera_node
	else:
		find_player_and_camera()
	
	if player_node and camera_node:
		is_initialized = true
		set_process(true)

func _process(delta):
	if not is_initialized:
		return
	
	var parent_tree = get_parent_tree()
	
	if use_tree_culling and parent_tree and parent_tree.is_tree_culled:
		if not is_culled:
			set_culled(true)
		return
	elif use_tree_culling and parent_tree and not parent_tree.is_tree_culled:
		if is_culled:
			set_culled(false)
	
	culling_self_update_timer += delta
	
	if culling_self_update_timer >= current_update_interval:
		culling_self_update_timer = 0.0
		if not use_tree_culling or not parent_tree:
			update_culling()
	
	if not is_culled:
		lod_self_update_timer += delta
		if lod_self_update_timer >= 0.3:
			lod_self_update_timer = 0.0
			update_lod()

func find_player_and_camera():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		camera_node = _find_camera_recursive(player_node)
	else:
		await get_tree().process_frame
		find_player_and_camera()

func _find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = _find_camera_recursive(child)
		if found:
			return found
	return null

func set_fruit_type(type: String):
	fruit_type = type
	setup_fruit_model()

func setup_fruit_model():
	var nodes_to_remove = []
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D and not child is Area3D and child.name != "ModelContainer":
			nodes_to_remove.append(child)
	
	for node in nodes_to_remove:
		node.queue_free()
	
	var model_container = get_node_or_null("ModelContainer")
	if not model_container:
		model_container = Node3D.new()
		model_container.name = "ModelContainer"
		add_child(model_container)
	
	for child in model_container.get_children():
		child.queue_free()
	
	var selected_model = get_current_model()
	if selected_model:
		var model_instance = selected_model.instantiate()
		model_container.add_child(model_instance)

func get_current_model():
	if current_lod_level == "high":
		return ripe_model_high if fruit_type == "Masak" else unripe_model_high
	else:
		return ripe_model_low if fruit_type == "Masak" else unripe_model_low

func update_lod():
	if not player_node or is_culled:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	var new_lod_level = "high" if distance_to_player <= LOD_HIGH_DISTANCE else "low"
	
	if new_lod_level != current_lod_level:
		current_lod_level = new_lod_level
		setup_fruit_model()

func update_culling():
	if not player_node or not camera_node:
		return
	
	if global_position.y < -500:
		if not is_culled:
			set_culled(true)
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= MIN_CULLING_DISTANCE:
		if is_culled:
			set_culled(false)
		return
	
	var should_be_active = (
		distance_to_player <= CULLING_DISTANCE and
		is_in_camera_frustum() and
		is_in_front_of_player()
	)
	
	if should_be_active and is_culled:
		set_culled(false)
	elif not should_be_active and not is_culled:
		set_culled(true)

func is_in_camera_frustum() -> bool:
	if not camera_node:
		return true
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	if distance_to_player <= MIN_CULLING_DISTANCE:
		return true
	
	var fruit_screen_pos = camera_node.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 100
	
	return (
		fruit_screen_pos.x >= -margin and
		fruit_screen_pos.x <= viewport_size.x + margin and
		fruit_screen_pos.y >= -margin and
		fruit_screen_pos.y <= viewport_size.y + margin
	)

func is_in_front_of_player() -> bool:
	if not player_node or not camera_node:
		return true
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	if distance_to_player <= MIN_CULLING_DISTANCE:
		return true
	
	var player_forward = -camera_node.global_transform.basis.z
	var direction_to_fruit = (global_position - player_node.global_position).normalized()
	
	return player_forward.dot(direction_to_fruit) > BACKFACE_THRESHOLD

func set_culled(culled: bool):
	if is_culled == culled:
		return
	
	is_culled = culled
	
	if culled:
		visible = false
		was_frozen = freeze
		freeze = true
		process_mode = PROCESS_MODE_DISABLED
	else:
		process_mode = PROCESS_MODE_INHERIT
		freeze = was_frozen
		visible = true
		update_lod()

func setup_area_detector():
	var area_detector = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = SphereShape3D.new()
	collision_shape.shape.radius = COLLISION_RADIUS
	
	area_detector.add_child(collision_shape)
	add_child(area_detector)
	
	area_detector.position = AREA_OFFSET
	area_detector.collision_mask = 0xFFFFFFFF
	area_detector.collision_layer = 0
	area_detector.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if has_touched_surface or is_culled or has_been_collected:
		return
	
	if (body is StaticBody3D or body is RigidBody3D or 
		body is CharacterBody3D or body is Node3D):
		if not body.is_in_group("player") and not body.is_in_group("buah"):
			has_touched_surface = true
			can_be_collected = true
			# GDD: buah sawit jatuh ke tanah menimbulkan suara di titik jatuhnya.
			if is_falling:
				NoiseManager.emit_noise(global_position, NoiseManager.LOUDNESS_FRUIT_LAND)

func fall_from_tree(target_position: Vector3 = Vector3.ZERO):
	if is_falling or is_culled or has_been_collected:
		return
	
	use_tree_culling = false
	remove_from_group("buah")
	add_to_group("buah_jatuh")
	freeze = false
	is_falling = true
	set_process(true)
	
	if fruit_type == "Mentah" and not has_given_points:
		give_unripe_fruit_points()
	
	var force_direction = Vector3(
		randf_range(-2.0, 2.0),
		randf_range(1.0, 3.0),
		randf_range(-2.0, 2.0)
	)
	
	if target_position != Vector3.ZERO:
		var direction_to_player = (target_position - global_position).normalized()
		force_direction = Vector3(
			direction_to_player.x * randf_range(1.5, 3.0),
			randf_range(1.0, 3.0),
			direction_to_player.z * randf_range(1.5, 3.0)
		)
	
	apply_impulse(force_direction)

func give_unripe_fruit_points():
	if has_given_points:
		return
	
	has_given_points = true
	
	var inventory_system = _find_inventory_system()
	if inventory_system and inventory_system.has_method("add_unripe_fruit_kg"):
		var weight_kg = randi_range(25, 30)
		inventory_system.add_unripe_fruit_kg(weight_kg)

func _find_inventory_system():
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0:
			inventory_system = nodes[0]
	return inventory_system

func _exit_tree():
	parent_tree_ref = null
	player_node = null
	camera_node = null

func get_fruit_type() -> String:
	return fruit_type

func set_harvesting_mode_active(active: bool):
	if active:
		if is_culled:
			set_culled(false)
		process_mode = PROCESS_MODE_INHERIT
		visible = true
