extends Area3D
class_name Genangan

# Setting utama
@export var slow_percentage: float = 35  # 35% dalam persen (lebih intuitive)
@export var permanent_slow: bool = true

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("water_pools")

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and body.has_method("apply_water_slowdown"):
		body.apply_water_slowdown(slow_percentage / 100.0)  # Convert % to decimal

func _on_body_exited(body: Node3D):
	if body.is_in_group("player") and body.has_method("remove_water_slowdown"):
		if permanent_slow:
			body.remove_water_slowdown()
