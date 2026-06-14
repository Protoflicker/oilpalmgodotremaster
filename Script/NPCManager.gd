extends Node
class_name NPCManager

@export var harvester_npc_scene: PackedScene
@export var wild_boar_scene: PackedScene  # DITAMBAHKAN: Scene untuk WildBoar

# Konfigurasi Harvester NPC
var max_npcs: int = 1
var spawn_interval: float = 10.0
var npc_carry_capacity: int = 2
var npc_first_spawn_time: float = 5.0  # DITAMBAHKAN: Waktu spawn pertama NPC

# Konfigurasi WildBoar - DITAMBAHKAN
var max_wildboars: int = 1
var boar_spawn_interval: float = 15.0
var boar_first_spawn_time: float = 30.0

@export var manual_spawn_points: Array[Marker3D] = []
@export var use_manual_spawn_points: bool = true

var spawn_points: Array[Marker3D] = []
var active_npcs: Array[HarvesterNPC] = []
var active_wildboars: Array[WildBoar] = []  # DITAMBAHKAN: Array untuk WildBoar aktif
var spawned_npcs_count: int = 0
var spawned_wildboars_count: int = 0  # DITAMBAHKAN: Counter WildBoar
var spawn_timer: float = 0.0
var boar_spawn_timer: float = 0.0  # DITAMBAHKAN: Timer terpisah untuk WildBoar
var total_npc_harvest: int = 0

var is_spawning: bool = false  # DITAMBAHKAN: Flag untuk mencegah spawn bersamaan
var spawn_queue: Array = []  # DITAMBAHKAN: Queue untuk spawn bergantian

@export var ground_collision_mask: int = 1
@export var spawn_height_offset: float = 1.0

signal npc_total_harvest_updated(total_kg)

# Konfigurasi penghuni kebun (senter, kecepatan, jangkauan lihat) — diisi GameModeManager.
var enemy_config: Dictionary = {}
# Konfigurasi satwa liar / harimau (level 4).
var boar_config: Dictionary = {}

func set_enemy_config(cfg: Dictionary) -> void:
	enemy_config = cfg
	for npc in active_npcs:
		if is_instance_valid(npc) and npc.has_method("configure"):
			npc.configure(enemy_config)

func set_boar_config(cfg: Dictionary) -> void:
	boar_config = cfg
	for boar in active_wildboars:
		if is_instance_valid(boar) and boar.has_method("configure_boar"):
			boar.configure_boar(boar_config)

# Setters untuk Harvester NPC
func set_max_npcs(new_max: int):
	max_npcs = new_max
	print("NPCManager: max_npcs diatur ke ", max_npcs)

func set_spawn_interval(new_interval: float):
	spawn_interval = new_interval
	print("NPCManager: spawn_interval diatur ke ", spawn_interval)

func set_npc_carry_capacity(new_capacity: int):
	npc_carry_capacity = new_capacity
	print("NPCManager: npc_carry_capacity diatur ke ", npc_carry_capacity)
	
	for npc in active_npcs:
		if is_instance_valid(npc) and npc.has_method("set_carry_capacity"):
			npc.set_carry_capacity(npc_carry_capacity)

func set_npc_first_spawn_time(new_time: float):
	npc_first_spawn_time = new_time
	print("NPCManager: npc_first_spawn_time diatur ke ", new_time)

# DITAMBAHKAN: Setters untuk WildBoar
func set_max_wildboars(new_max: int):
	max_wildboars = new_max
	print("NPCManager: max_wildboars diatur ke ", max_wildboars)

func set_boar_spawn_interval(new_interval: float):
	boar_spawn_interval = new_interval
	print("NPCManager: boar_spawn_interval diatur ke ", new_interval)

func set_boar_first_spawn_time(new_time: float):
	boar_first_spawn_time = new_time
	print("NPCManager: boar_first_spawn_time diatur ke ", new_time)

func _ready():
	add_to_group("npc_manager")
	call_deferred("initialize_spawn_system")

func initialize_spawn_system():
	find_spawn_points()
	
	# Inisialisasi timer untuk spawn pertama.
	# _process memicu spawn saat timer >= interval, jadi timer awal = interval - first_spawn
	# agar spawn pertama tepat terjadi setelah `first_spawn_time` detik.
	spawn_timer = spawn_interval - npc_first_spawn_time
	boar_spawn_timer = boar_spawn_interval - boar_first_spawn_time
	
	print("NPCManager: Sistem spawn diinisialisasi")
	print("  - Harvester NPC: Max ", max_npcs, ", Interval ", spawn_interval, ", First spawn in ", npc_first_spawn_time)
	print("  - WildBoar: Max ", max_wildboars, ", Interval ", boar_spawn_interval, ", First spawn in ", boar_first_spawn_time)

func _process(delta):
	if spawned_npcs_count < max_npcs:  # spawned_npcs_count adalah total yang PERNAH di-spawn
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			if not is_spawning:
				spawn_timer = 0.0
				if spawn_points.size() > 0:
					spawn_queue.append({"type": "npc"})
					process_spawn_queue()
	
	# DITAMBAHKAN: Handle WildBoar spawning
	if spawned_wildboars_count < max_wildboars:
		boar_spawn_timer += delta
		if boar_spawn_timer >= boar_spawn_interval:
			if not is_spawning:
				boar_spawn_timer = 0.0
				if spawn_points.size() > 0:
					# Tambahkan ke queue
					spawn_queue.append({"type": "boar"})
					process_spawn_queue()
	
	# Proses queue jika ada item dan tidak sedang spawn
	if spawn_queue.size() > 0 and not is_spawning:
		process_spawn_queue()

# DITAMBAHKAN: Fungsi untuk memproses spawn queue
func process_spawn_queue():
	if is_spawning or spawn_queue.size() == 0:
		return
	
	is_spawning = true
	var spawn_data = spawn_queue.pop_front()
	
	if spawn_data["type"] == "npc":
		spawn_harvester_npc()
	elif spawn_data["type"] == "boar":
		spawn_wild_boar()
	
	# Delay sebelum spawn berikutnya
	await get_tree().create_timer(0.1).timeout
	is_spawning = false

func find_spawn_points():
	spawn_points.clear()
	
	if use_manual_spawn_points:
		for marker in manual_spawn_points:
			if is_instance_valid(marker) and marker is Marker3D:
				spawn_points.append(marker)
				if not marker.is_in_group("npc_spawn"):
					marker.add_to_group("npc_spawn")
	else:
		var root = get_tree().root
		find_markers_recursive(root)

func find_markers_recursive(node: Node):
	for child in node.get_children():
		if child is Marker3D:
			if should_use_as_spawn_point(child):
				spawn_points.append(child)
				if not child.is_in_group("npc_spawn"):
					child.add_to_group("npc_spawn")
		find_markers_recursive(child)

func should_use_as_spawn_point(marker: Marker3D) -> bool:
	var marker_name = marker.name.to_lower()
	
	if ("spawn" in marker_name or "npc" in marker_name or "harvester" in marker_name or "boar" in marker_name or "enemy" in marker_name):
		return true
	
	if marker.is_in_group("npc_spawn"):
		return true
	
	return false

func spawn_harvester_npc():
	if not harvester_npc_scene:
		return
	
	if spawn_points.size() == 0:
		return
	
	if spawned_npcs_count >= max_npcs:
		return
	
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var safe_spawn_position = get_safe_spawn_position(spawn_point.global_position)
	
	var npc_instance = harvester_npc_scene.instantiate()
	if not npc_instance:
		return
	
	if npc_instance.has_method("set_carry_capacity"):
		npc_instance.set_carry_capacity(npc_carry_capacity)
	
	call_deferred("add_npc_to_scene", npc_instance, safe_spawn_position)
	
	spawned_npcs_count += 1
	print("NPCManager: Spawned HarvesterNPC #", spawned_npcs_count, "/", max_npcs)

# DITAMBAHKAN: Fungsi untuk spawn WildBoar
func spawn_wild_boar():
	if not wild_boar_scene:
		print("NPCManager: wild_boar_scene tidak diatur!")
		return
	
	if spawn_points.size() == 0:
		return
	
	if spawned_wildboars_count >= max_wildboars:
		return
	
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var safe_spawn_position = get_safe_spawn_position(spawn_point.global_position)
	
	var boar_instance = wild_boar_scene.instantiate()
	if not boar_instance:
		return
	
	call_deferred("add_wildboar_to_scene", boar_instance, safe_spawn_position)
	
	spawned_wildboars_count += 1
	print("NPCManager: Spawned WildBoar #", spawned_wildboars_count, "/", max_wildboars)

func get_safe_spawn_position(original_position: Vector3) -> Vector3:
	var viewport = get_tree().root
	var space_state = viewport.get_world_3d().direct_space_state
	
	var ray_origin = original_position + Vector3.UP * 10.0
	var ray_end = original_position + Vector3.DOWN * 50.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = ground_collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position + Vector3.UP * spawn_height_offset
	else:
		return Vector3(original_position.x, spawn_height_offset, original_position.z)

func add_npc_to_scene(npc_instance: HarvesterNPC, spawn_position: Vector3):
	if not is_instance_valid(npc_instance):
		return
	
	get_parent().add_child(npc_instance)
	npc_instance.global_position = spawn_position
	
	if npc_instance.has_signal("npc_harvested_fruits"):
		npc_instance.npc_harvested_fruits.connect(_on_npc_harvested_fruits)
	
	if npc_instance.has_signal("npc_returned_to_spawn"):
		npc_instance.npc_returned_to_spawn.connect(_on_npc_returned_to_spawn)
	
	if npc_instance.has_method("configure"):
		npc_instance.configure(enemy_config)

	active_npcs.append(npc_instance)

# DITAMBAHKAN: Fungsi untuk menambahkan WildBoar ke scene
func add_wildboar_to_scene(boar_instance: WildBoar, spawn_position: Vector3):
	if not is_instance_valid(boar_instance):
		return
	
	get_parent().add_child(boar_instance)
	boar_instance.global_position = spawn_position

	active_wildboars.append(boar_instance)

	if boar_instance.has_method("configure_boar"):
		boar_instance.configure_boar(boar_config)

	print("NPCManager: WildBoar ditambahkan ke scene di posisi ", spawn_position)

func _on_npc_harvested_fruits(harvested_kg: int):
	total_npc_harvest += harvested_kg
	npc_total_harvest_updated.emit(total_npc_harvest)

func _on_npc_returned_to_spawn(npc_instance: HarvesterNPC):
	if npc_instance.has_signal("npc_harvested_fruits"):
		npc_instance.npc_harvested_fruits.disconnect(_on_npc_harvested_fruits)
	if npc_instance.has_signal("npc_returned_to_spawn"):
		npc_instance.npc_returned_to_spawn.disconnect(_on_npc_returned_to_spawn)
	
	if npc_instance in active_npcs:
		active_npcs.erase(npc_instance)
	
	print("NPC kembali ke spawn. TOTAL yang pernah spawn: ", spawned_npcs_count, "/", max_npcs)

func reset_npc_harvest():
	total_npc_harvest = 0
	# spawned_npcs_count direset ke 0 hanya di sini (saat round baru)
	spawned_npcs_count = 0
	
	for npc in active_npcs:
		if is_instance_valid(npc):
			if npc.has_method("reset_after_carrying"):
				npc.reset_after_carrying()
			npc.queue_free()
	active_npcs.clear()
	
	# Reset queue
	spawn_queue.clear()
	is_spawning = false
	
	npc_total_harvest_updated.emit(0)

	# Reset timer untuk round baru (samakan rumus dengan initialize_spawn_system).
	spawn_timer = spawn_interval - npc_first_spawn_time
	boar_spawn_timer = boar_spawn_interval - boar_first_spawn_time
	spawned_wildboars_count = 0
	
	print("NPCManager: Reset untuk round baru. Total spawn count: ", spawned_npcs_count)

func get_active_npc_count() -> int:
	return active_npcs.size()

# DITAMBAHKAN: Getter untuk jumlah WildBoar aktif
func get_active_wildboar_count() -> int:
	return active_wildboars.size()

func add_spawn_point(marker: Marker3D):
	if is_instance_valid(marker) and marker is Marker3D:
		if marker not in spawn_points:
			spawn_points.append(marker)

func remove_spawn_point(marker: Marker3D):
	if marker in spawn_points:
		spawn_points.erase(marker)

func clear_spawn_points():
	spawn_points.clear()

func refresh_spawn_points():
	find_spawn_points()

func configure_manager(npc_scene: PackedScene, max_count: int = 1):
	harvester_npc_scene = npc_scene
	max_npcs = max_count

func get_total_npc_harvest() -> int:
	return total_npc_harvest

func get_spawned_npc_count() -> int:
	return spawned_npcs_count

# DITAMBAHKAN: Getter untuk jumlah WildBoar yang sudah di-spawn
func get_spawned_wildboar_count() -> int:
	return spawned_wildboars_count

func get_remaining_npc_slots() -> int:
	return max(max_npcs - spawned_npcs_count, 0)

# DITAMBAHKAN: Getter untuk slot WildBoar yang tersisa
func get_remaining_wildboar_slots() -> int:
	return max(max_wildboars - spawned_wildboars_count, 0)

func are_all_npcs_spawned() -> bool:
	return spawned_npcs_count >= max_npcs

# DITAMBAHKAN: Cek apakah semua WildBoar sudah di-spawn
func are_all_wildboars_spawned() -> bool:
	return spawned_wildboars_count >= max_wildboars

# NPCManager.gd - Tambahkan fungsi ini
func remove_wildboar_from_active(boar: WildBoar):
	if boar in active_wildboars:
		active_wildboars.erase(boar)
		spawned_wildboars_count -= 1
		print("WildBoar dihapus dari active list. Slots tersedia: ", get_remaining_wildboar_slots())
