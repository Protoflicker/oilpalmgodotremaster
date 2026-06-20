extends Control
## Tombol TENGAH = MASUK Level 2 (terkunci sampai Level 2 terbuka).
## Tombol KANAN = NEXT (ke Level 3). KIRI = Back.

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_update_locks()

func _update_locks() -> void:
	var enter_btn := get_node_or_null("NextLevelButton") as Button
	if enter_btn:
		var unlocked := GameState.is_unlocked(2)
		enter_btn.disabled = not unlocked
		enter_btn.text = Loc.t("enter") if unlocked else Loc.t("locked")
	var next_btn := get_node_or_null("level1") as Button
	if next_btn:
		next_btn.disabled = false

func _on_enter_pressed() -> void:
	if GameState.is_unlocked(2):
		get_tree().change_scene_to_file("res://Scene/Level2.tscn")

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel3.tscn")

func _on_backmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://Script/MenuLevel1.tscn")
