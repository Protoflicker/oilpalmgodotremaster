extends GPUParticles3D
## Hujan mengikuti player. Sebelumnya hanya mengikuti bila player_path di-set di scene
## (tidak di-set) → hujan diam di satu petak peta besar. Sekarang cari player via group
## sebagai fallback agar hujan selalu menyelimuti area di sekitar player.

@export var player_path: NodePath
var player: Node3D

func _ready():
	if player_path:
		player = get_node_or_null(player_path) as Node3D
	if not player:
		_find_player()
	# AABB besar agar hujan tidak hilang saat menengok ke segala arah di peta besar.
	visibility_aabb = AABB(Vector3(-90, -90, -90), Vector3(180, 180, 180))

func _find_player() -> void:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.size() > 0:
		player = ps[0]

func _process(_delta):
	if not player or not is_instance_valid(player):
		_find_player()
		return
	global_position.x = player.global_position.x
	global_position.z = player.global_position.z
	global_position.y = player.global_position.y + 15.0
