extends Node3D
class_name PalmTree

@export var fruit_scene: PackedScene
@export var auto_ripe_chance: bool = true
@export var min_ripe_chance: float = 0.3
@export var max_ripe_chance: float = 0.8
@export var tree_model_low: PackedScene

var current_tree_lod: String = "high"
var player_node: Node3D = null
var camera_node: Camera3D = null
var has_tree_lod: bool = false
var original_mesh: MeshInstance3D = null
var is_tree_culled: bool = false

var ripe_chance: float = 0.5
var all_fruits: Array = []
var has_spawned_fruits: bool = false

var tree_culling_update_timer: float = 0.0
var tree_current_update_interval: float = 0.3
var lod_update_timer: float = 0.0

var is_initializing: bool = true
var spawn_retry_count: int = 0

const LOD_UPDATE_INTERVAL: float = 0.2
const TREE_LOD_HIGH_DISTANCE = 20
const TREE_LOD_LOW_DISTANCE = 25.0
const TREE_CULLING_DISTANCE: float = 300
const TREE_MIN_CULLING_DISTANCE: float = 25
const TREE_BACKFACE_THRESHOLD: float = 0.2
const TREE_NEAR_UPDATE_INTERVAL: float = 0.05
const TREE_FAR_UPDATE_INTERVAL: float = 0.3
const MAX_SPAWN_RETRIES: int = 3

func _ready():
	add_to_group("tree")
	
	if auto_ripe_chance:
		ripe_chance = randf_range(min_ripe_chance, max_ripe_chance)
	
	call_deferred("initialize_tree")

func initialize_tree():
	var player_found = await wait_for_player_quick()
	if not player_found:
		is_initializing = false
		spawn_initial_fruits()
		return
	
	setup_all_systems()
	visible = true
	await get_tree().process_frame
	spawn_initial_fruits()
	
func wait_for_player_quick():
	var max_attempts = 15
	var attempt = 0
	
	while attempt < max_attempts:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			if is_player_ready_quick(player):
				player_node = player
				if setup_camera_from_player(player):
					return true
		attempt += 1
		await get_tree().create_timer(0.1).timeout
	
	return false
	
func is_player_ready_quick(player: Node) -> bool:
	if player == null:
		return false
	
	if player.is_inside_tree():
		return true
	if player.has_method("get_carried_ripe_fruits"):
		return true
	
	return true

func _exit_tree():
	all_fruits.clear()
	player_node = null
	camera_node = null
	original_mesh = null

func setup_camera_from_player(player: Node) -> bool:
	if player == null:
		return false
	
	var camera_paths = [
		"PlayerController/Camera3D",
		"Camera3D",
		"Head/Camera3D"
	]
	
	for path in camera_paths:
		if player.has_node(path):
			camera_node = player.get_node(path)
			if camera_node and camera_node is Camera3D:
				return true
	
	camera_node = find_camera_recursive(player)
	return camera_node != null

func find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = find_camera_recursive(child)
		if found:
			return found
	return null

func setup_all_systems():
	setup_tree_lod_system()
	setup_tree_culling_system()

func _process(delta):
	if not is_initializing and player_node and camera_node:
		lod_update_timer += delta
		if lod_update_timer >= LOD_UPDATE_INTERVAL:
			lod_update_timer = 0.0
			update_all_fruits_lod()
			if has_tree_lod:
				update_tree_lod()
		
		tree_culling_update_timer += delta
		
		if tree_culling_update_timer >= tree_current_update_interval:
			tree_culling_update_timer = 0.0
			update_tree_culling()
			update_tree_culling_priority()

func update_tree_culling_priority():
	if not player_node:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= 12.0:
		tree_current_update_interval = 0.03
	elif distance_to_player <= 25.0 and (is_tree_in_front_of_player() or is_tree_in_camera_frustum()):
		tree_current_update_interval = TREE_NEAR_UPDATE_INTERVAL
	elif distance_to_player <= 50.0:
		tree_current_update_interval = 0.2
	else:
		tree_current_update_interval = TREE_FAR_UPDATE_INTERVAL

func setup_tree_lod_system():
	if not tree_model_low:
		return
	_find_original_mesh()

func setup_tree_culling_system():
	if not original_mesh:
		return
	has_tree_lod = true

func _find_original_mesh():
	for child in get_children():
		if child is MeshInstance3D:
			original_mesh = child
			return
	
	var found_mesh = _find_mesh_recursive(self)
	if found_mesh:
		original_mesh = found_mesh

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_mesh_recursive(child)
		if found:
			return found
	return null

func update_tree_lod():
	if not player_node or not has_tree_lod:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	var new_lod_level = "high" if distance_to_player <= TREE_LOD_HIGH_DISTANCE else "low"
	
	if new_lod_level != current_tree_lod:
		current_tree_lod = new_lod_level
		apply_tree_lod()

func update_tree_culling():
	if not player_node or not camera_node:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= TREE_MIN_CULLING_DISTANCE:
		if is_tree_culled:
			set_tree_culled(false)
		return
	
	var should_be_active = (
		distance_to_player <= TREE_CULLING_DISTANCE and
		is_tree_in_camera_frustum() and
		is_tree_in_front_of_player()
	)
	
	if should_be_active and is_tree_culled:
		set_tree_culled(false)
	elif not should_be_active and not is_tree_culled:
		set_tree_culled(true)

func is_tree_in_camera_frustum() -> bool:
	if not camera_node:
		return true
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	if distance_to_player <= TREE_MIN_CULLING_DISTANCE:
		return true
	
	var tree_screen_pos = camera_node.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 150
	
	return (
		tree_screen_pos.x >= -margin and
		tree_screen_pos.x <= viewport_size.x + margin and
		tree_screen_pos.y >= -margin and
		tree_screen_pos.y <= viewport_size.y + margin
	)

func is_tree_in_front_of_player() -> bool:
	if not player_node or not camera_node:
		return true
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	if distance_to_player <= TREE_MIN_CULLING_DISTANCE:
		return true
	
	var player_forward = -camera_node.global_transform.basis.z
	var direction_to_tree = (global_position - player_node.global_position).normalized()
	
	return player_forward.dot(direction_to_tree) > TREE_BACKFACE_THRESHOLD

func set_tree_culled(culled: bool):
	if is_tree_culled == culled:
		return
	
	if is_initializing and culled:
		return
	
	is_tree_culled = culled
	
	if culled:
		visible = false
		for fruit in all_fruits:
			if is_instance_valid(fruit):
				fruit.visible = false
				fruit.process_mode = PROCESS_MODE_DISABLED
	else:
		visible = true
		for fruit in all_fruits:
			if is_instance_valid(fruit):
				fruit.process_mode = PROCESS_MODE_INHERIT
				fruit.visible = true
		
		if has_tree_lod:
			update_tree_lod()

func apply_tree_lod():
	if not original_mesh:
		return
	
	if current_tree_lod == "high":
		original_mesh.visible = true
		var low_model = find_child("TreeLowLOD", true, false)
		if low_model:
			low_model.queue_free()
	else:
		original_mesh.visible = false
		var low_model = find_child("TreeLowLOD", true, false)
		if not low_model and tree_model_low:
			var low_instance = tree_model_low.instantiate()
			if low_instance:
				low_instance.name = "TreeLowLOD"
				add_child(low_instance)
				low_instance.global_position = global_position
				low_instance.global_rotation = global_rotation

func update_all_fruits_lod():
	for fruit in all_fruits:
		if is_instance_valid(fruit) and fruit.has_method("update_lod"):
			fruit.update_lod()

func spawn_initial_fruits():
	if has_spawned_fruits:
		return
	
	var spawn_points_node = $SpawnPoints
	if not spawn_points_node:
		if spawn_retry_count < MAX_SPAWN_RETRIES:
			spawn_retry_count += 1
			await get_tree().process_frame
			call_deferred("spawn_initial_fruits")
			return
		else:
			is_initializing = false
			return
	
	var markers = []
	for child in spawn_points_node.get_children():
		if child is Marker3D:
			markers.append(child)
	
	var total_markers = markers.size()
	if total_markers == 0:
		has_spawned_fruits = true
		is_initializing = false
		return
	
	var ripe_count = int(total_markers * ripe_chance)
	ripe_count = clamp(ripe_count, 1, total_markers)
	
	var fruit_types = []
	for i in range(total_markers):
		if i < ripe_count:
			fruit_types.append("Masak")
		else:
			fruit_types.append("Mentah")
	
	shuffle_array(fruit_types)
	all_fruits.clear()
	
	for i in range(markers.size()):
		spawn_fruit_with_type(markers[i], fruit_types[i])
	
	has_spawned_fruits = true
	is_initializing = false

func shuffle_array(arr: Array):
	for i in range(arr.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func spawn_fruit_with_type(marker: Marker3D, fruit_type: String) -> RigidBody3D:
	if not fruit_scene:
		return null
	
	var fruit_instance = fruit_scene.instantiate()
	if not fruit_instance:
		return null
	
	add_child(fruit_instance)
	all_fruits.append(fruit_instance)
	
	fruit_instance.global_position = marker.global_position
	fruit_instance.global_rotation = marker.global_rotation
	
	if fruit_instance.has_method("set_parent_tree"):
		fruit_instance.set_parent_tree(self)
	
	if fruit_instance.has_method("set_fruit_type"):
		fruit_instance.set_fruit_type(fruit_type)
	else:
		fruit_instance.fruit_type = fruit_type
		if fruit_instance.has_method("setup_fruit_model"):
			fruit_instance.setup_fruit_model()
	
	fruit_instance.visible = true
	fruit_instance.process_mode = PROCESS_MODE_INHERIT
	
	return fruit_instance
	
func remove_fruit(fruit: RigidBody3D):
	if fruit in all_fruits:
		all_fruits.erase(fruit)
		if is_instance_valid(fruit):
			fruit.queue_free()
	
func get_all_fruits() -> Array:
	return all_fruits.duplicate()

func get_ripe_count() -> int:
	if not has_spawned_fruits or all_fruits.is_empty():
		return 0
	
	var ripe_count = 0
	for fruit in all_fruits:
		if is_instance_valid(fruit) and fruit.has_method("get_fruit_type"):
			var fruit_type = fruit.get_fruit_type()
			if fruit_type == "Masak":
				ripe_count += 1
		elif is_instance_valid(fruit) and "fruit_type" in fruit:
			if fruit.fruit_type == "Masak":
				ripe_count += 1
	
	return ripe_count

func harvest_physical(harvester_position: Vector3 = Vector3.ZERO) -> int:
	if not has_spawned_fruits or all_fruits.is_empty():
		return 0
	
	var harvested_count = 0
	var fruits_to_remove = []
	
	for fruit in all_fruits:
		if not is_instance_valid(fruit):
			continue
		
		var is_ripe = false
		if fruit.has_method("get_fruit_type"):
			is_ripe = fruit.get_fruit_type() == "Masak"
		elif "fruit_type" in fruit:
			is_ripe = fruit.fruit_type == "Masak"
		
		if is_ripe:
			if fruit.has_method("fall_from_tree"):
				fruit.fall_from_tree(harvester_position)
				harvested_count += 1
				fruits_to_remove.append(fruit)
	
	for fruit in fruits_to_remove:
		all_fruits.erase(fruit)
	
	return harvested_count

func harvest_simulated() -> int:
	if not has_spawned_fruits or all_fruits.is_empty():
		return 0
	
	var harvested_count = 0
	var fruits_to_remove = []
	
	for fruit in all_fruits:
		if not is_instance_valid(fruit):
			continue
		
		var is_ripe = false
		if fruit.has_method("get_fruit_type"):
			is_ripe = fruit.get_fruit_type() == "Masak"
		elif "fruit_type" in fruit:
			is_ripe = fruit.fruit_type == "Masak"
		
		if is_ripe:
			harvested_count += 1
			fruits_to_remove.append(fruit)
	
	for fruit in fruits_to_remove:
		if is_instance_valid(fruit):
			all_fruits.erase(fruit)
			fruit.queue_free()
	
	return harvested_count

func has_ripe_fruits() -> bool:
	return get_ripe_count() > 0

func get_tree_position() -> Vector3:
	return global_position

func set_harvesting_mode_active(active: bool):
	if active:
		if is_tree_culled:
			set_tree_culled(false)
		tree_current_update_interval = 0.05
	else:
		update_tree_culling_priority()
