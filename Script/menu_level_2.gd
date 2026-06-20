extends Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_update_locks()

func _update_locks() -> void:
	# Tombol MASUK (kanan) Level 2 terkunci sampai Level 2 terbuka.
	var play := get_node_or_null("level1") as Button
	if play:
		play.disabled = not GameState.is_unlocked(2)
	# NEXT (tengah) bebas menelusuri Level 3.
	var nxt := get_node_or_null("NextLevelButton") as Button
	if nxt:
		nxt.disabled = false
		nxt.text = Loc.t("next")

func _on_level_1_pressed() -> void:
	if GameState.is_unlocked(2):
		get_tree().change_scene_to_file("res://Scene/Level2.tscn")

func _on_next_level_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel3.tscn")

func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel1.tscn")
