extends Node3D
class_name InteractionSystem

@export var camera: Camera3D
@export var player_controller: Node
@export var ui_manager: UIManager

const RAY_LENGTH = 5.25

var current_target = null
var player_node: Node3D = null

# Variabel audio - DITAMBAHKAN DARI BRANCH ANSELMARIO
var audio_player: AudioStreamPlayer3D
var tusuk_sound: AudioStream
var enggrek_sound: AudioStream

func _ready():
	find_ui_manager()
	player_node = get_parent()
	setup_audio_player()

func find_ui_manager():
	var paths_to_try = [
		"/root/Node3D/UIManager",
		"../../UIManager",
		"../UIManager"
	]
	
	for path in paths_to_try:
		ui_manager = get_node_or_null(path)
		if ui_manager:
			return
	
	var ui_managers = get_tree().get_nodes_in_group("ui_manager")
	if ui_managers.size() > 0:
		ui_manager = ui_managers[0]
	
	if ui_manager == null:
		ui_manager = get_tree().root.find_child("UIManager", true, false)

# Setup audio player - DITAMBAHKAN DARI BRANCH ANSELMARIO
func setup_audio_player():
	# Membuat AudioStreamPlayer3D untuk sound effects
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.bus = "SFX"
	audio_player.volume_db = 0
	audio_player.max_distance = 15
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# Memuat file suara
	tusuk_sound = load("res://soundeffect/tusuk.mp3")
	enggrek_sound = load("res://soundeffect/enggrek.mp3")
	
	if not tusuk_sound:
		print("Peringatan: File audio tusuk.mp3 tidak ditemukan di res://soundeffect/")
	if not enggrek_sound:
		print("Peringatan: File audio enggrek.mp3 tidak ditemukan di res://soundeffect/")

# Play tusuk sound - DITAMBAHKAN DARI BRANCH ANSELMARIO
func play_tusuk_sound():
	if audio_player and tusuk_sound:
		audio_player.stream = tusuk_sound
		audio_player.play()

# Play enggrek sound - DITAMBAHKAN DARI BRANCH ANSELMARIO
func play_enggrek_sound():
	if audio_player and enggrek_sound:
		audio_player.stream = enggrek_sound
		audio_player.play()

func _input(event):
	# GDD: E untuk memanen/berinteraksi. Klik kiri tetap didukung.
	if event.is_action_pressed("harvest") or event.is_action_pressed("shoot"):
		handle_interaction()

func _physics_process(_delta):
	raycast_system()

func handle_interaction():
	if player_controller and player_controller.has_method("play_tool_animation"):
		player_controller.play_tool_animation()
	
	if current_target:
		handle_target_interaction()
	else:
		if player_node and player_node.has_method("deliver_fruits"):
			var can_deliver = player_node.deliver_fruits()
			if not can_deliver and player_node.in_delivery_zone and player_node.get_carried_ripe_fruits() == 0:
				if ui_manager:
					ui_manager.show_interaction_label("Tidak ada buah matang untuk diantar")

func handle_target_interaction():
	if current_target.is_in_group("buah"):
		if player_controller and player_controller.has_method("is_egrek_active") and player_controller.is_egrek_active():
			handle_fruit_harvest()
		else:
			if ui_manager:
				ui_manager.show_interaction_label("Gunakan Egrek (Tombol 1) untuk menjatuhkan buah")
			
	elif current_target.is_in_group("buah_jatuh") and current_target.has_touched_surface:
		if player_controller and player_controller.has_method("is_tojok_active") and player_controller.is_tojok_active():
			collect_fruit(current_target)
		else:
			if ui_manager:
				ui_manager.show_interaction_label("Gunakan Tojok (Tombol 2) untuk mengumpulkan buah")

func handle_fruit_harvest():
	var player_position = get_parent().global_position

	play_enggrek_sound()
	# GDD: memanen menghasilkan suara yang menarik perhatian penghuni kebun.
	NoiseManager.emit_noise(player_position, NoiseManager.LOUDNESS_HARVEST)
	current_target.fall_from_tree(player_position)

func raycast_system():
	if !camera:
		return
	
	if player_node and player_node.in_delivery_zone and player_node.get_carried_ripe_fruits() > 0:
		if ui_manager:
			ui_manager.show_interaction_label("Tekan untuk menyerahkan buah")
		return
		
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_position
	var end = origin - camera.global_transform.basis.z * RAY_LENGTH
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_parent()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		handle_raycast_result(result.collider)
	else:
		clear_target()

func handle_raycast_result(collider):
	if is_fruit(collider):
		current_target = collider
		
		if player_controller and player_controller.has_method("is_egrek_active"):
			if player_controller.is_egrek_active():
				if ui_manager:
					ui_manager.show_interaction_label("Klik untuk menjatuhkan buah")
			else:
				if ui_manager:
					ui_manager.show_interaction_label("Pakai Egrek (1) jatuhkan buah")
				
	elif is_collectable_fruit(collider):
		current_target = collider
		var fruit_type = collider.get("fruit_type")
		var type_text = "masak" if fruit_type == "Masak" else "mentah"
		
		if player_controller and player_controller.has_method("is_tojok_active"):
			if player_controller.is_tojok_active():
				if collider.can_be_collected:
					if ui_manager:
						ui_manager.show_interaction_label("Klik untuk mengambil buah " + type_text)
				else:
					if ui_manager:
						ui_manager.show_interaction_label("Buah " + type_text + " belum sampai tanah")
			else:
				if ui_manager:
					ui_manager.show_interaction_label("Pakai Tojok (2) ambil buah")
	else:
		clear_target()

func is_fruit(collider) -> bool:
	return collider.is_in_group("buah")

func is_collectable_fruit(collider) -> bool:
	return (collider.is_in_group("buah_jatuh") and 
			collider.get("has_touched_surface") and 
			collider.has_touched_surface and
			collider.get("can_be_collected") and
			collider.can_be_collected)

func clear_target():
	current_target = null
	if ui_manager:
		ui_manager.clear_target()

func collect_fruit(fruit):
	if not is_instance_valid(fruit):
		clear_target()
		return
		
	if fruit.is_in_group("buah_jatuh") and fruit.has_touched_surface and fruit.can_be_collected:
		var fruit_type = fruit.get("fruit_type")
		
		play_tusuk_sound()
		
		if fruit_type == "Masak":
			if player_node and player_node.has_method("add_to_inventory"):
				player_node.add_to_inventory("Masak")
		
		fruit.queue_free()
		clear_target()
