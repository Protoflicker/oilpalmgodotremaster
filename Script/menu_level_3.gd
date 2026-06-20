extends Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_update_locks()

func _update_locks() -> void:
	# Tombol MASUK (kanan) Level 3 terkunci sampai Level 3 terbuka.
	var play := get_node_or_null("level1") as Button
	if play:
		play.disabled = not GameState.is_unlocked(3)
	# NEXT (tengah) di sini menuju Level 4 (langsung) — terkunci sampai Level 4 terbuka.
	var nxt := get_node_or_null("NextLevelButton") as Button
	if nxt:
		var unlocked := GameState.is_unlocked(4)
		nxt.disabled = not unlocked
		nxt.text = "LEVEL 4" if unlocked else Loc.t("locked")

func _on_level_1_pressed() -> void:
	if GameState.is_unlocked(3):
		get_tree().change_scene_to_file("res://Scene/Level3.tscn")

func _on_next_level_pressed() -> void:
	if GameState.is_unlocked(4):
		get_tree().change_scene_to_file("res://Scene/Level4.tscn")

func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel2.tscn")
