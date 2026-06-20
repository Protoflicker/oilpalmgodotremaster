extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_update_locks()

func _update_locks() -> void:
	# Tombol MASUK (kanan) level 1 selalu terbuka.
	var play := get_node_or_null("level1") as Button
	if play:
		play.disabled = false
	# Tombol NEXT (tengah) bebas untuk menelusuri level berikutnya.
	var nxt := get_node_or_null("NextLevelButton") as Button
	if nxt:
		nxt.disabled = false
		nxt.text = Loc.t("next")

func _on_level_1_pressed() -> void:
	# MASUK ke Level 1.
	get_tree().change_scene_to_file("res://Scene/Level.tscn")

func _on_next_level_pressed() -> void:
	# Telusuri layar pilih Level berikutnya.
	get_tree().change_scene_to_file("res://Script/MenuLevel2.tscn")

func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Menu.tscn")
