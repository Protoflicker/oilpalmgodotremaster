extends Control

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Level.tscn")

func _on_option_button_pressed() -> void:
	# Ganti path ini ke menu Options kamu
	get_tree().change_scene_to_file("res://Scene/options.tscn")

func _on_quit_button_pressed() -> void:
	# Ini buat keluar game
	get_tree().quit()
