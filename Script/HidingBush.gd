extends Area3D
class_name HidingBush
## Semak persembunyian (GDD: Hiding & Stealth Mechanic) + bahaya ULAR (Wildlife Hazard).
## Saat player di dalam semak ia bisa bersembunyi (jongkok + senter mati = nyaris tak terlihat).
## Namun ada peluang ular bersembunyi di semak: bila player berlama-lama, ular menggigit
## (game over). Pola acak ini menambah elemen kejutan sesuai GDD.

var snake_chance: float = 0.0
var has_snake_rolled: bool = false
var player_inside: Node = null

func _ready() -> void:
	add_to_group("hiding_bush")
	snake_chance = float(GameState.get_config().get("snake_chance", 0.0))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_in_bush"):
		body.set_in_bush(true)
	player_inside = body
	_maybe_snake(body)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_in_bush"):
		body.set_in_bush(false)
	if player_inside == body:
		player_inside = null

func _maybe_snake(body: Node) -> void:
	if snake_chance <= 0.0 or has_snake_rolled:
		return
	has_snake_rolled = true
	if randf() > snake_chance:
		return

	# Peringatan singkat sebelum gigitan — beri kesempatan player kabur.
	var uis = get_tree().get_nodes_in_group("ui_manager")
	if uis.size() > 0 and uis[0].has_method("show_notification"):
		uis[0].show_notification("Ssshh... ada yang bergerak di semak! Cepat menjauh!")

	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(self) and player_inside == body and is_instance_valid(body):
		if body.has_method("catch"):
			body.catch("Digigit ular di semak-semak!")
