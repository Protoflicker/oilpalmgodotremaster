extends Control


func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Level2.tscn")


func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel1.tscn")

func _ready():
	# Pastikan setiap kali masuk menu ini, mouse dan input direset
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
