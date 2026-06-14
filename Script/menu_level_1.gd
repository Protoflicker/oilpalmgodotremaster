extends Control


func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Level.tscn")


func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Menu.tscn")
