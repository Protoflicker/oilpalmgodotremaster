extends Control
## Level select. Tombol TENGAH (NextLevelButton, teks) = MASUK level.
## Tombol KANAN (level1, ikon panah) = NEXT (ke layar level berikutnya). KIRI = Back.

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_update_locks()

func _update_locks() -> void:
	# MASUK (tengah) Level 1 selalu terbuka.
	var enter_btn := get_node_or_null("NextLevelButton") as Button
	if enter_btn:
		enter_btn.disabled = false
		enter_btn.text = Loc.t("enter")
	# NEXT (kanan) bebas untuk telusuri Level berikutnya.
	var next_btn := get_node_or_null("level1") as Button
	if next_btn:
		next_btn.disabled = false

func _on_enter_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Level.tscn")

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel2.tscn")

func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Menu.tscn")
