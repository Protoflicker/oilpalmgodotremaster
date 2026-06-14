extends GPUParticles3D

@export var player_path : NodePath
var player : Node3D

func _ready():
	if player_path:
		player = get_node(player_path)
	
	# --- SOLUSI 1: Agar Hujan Tidak Hilang di Sudut Tertentu ---
	# Kita paksa kotak batas visibilitas (AABB) menjadi sangat besar (100x100x100 meter).
	# Dengan ini, Godot akan selalu merender hujan meskipun kamu menengok ke langit atau ke bawah kaki.
	visibility_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))

func _process(delta):
	if player:
		# Pindahkan posisi hujan ke posisi X dan Z player
		global_position.x = player.global_position.x
		global_position.z = player.global_position.z
		
		# --- SOLUSI 2: Agar Hujan Tidak Spawn Terlalu Bawah ---
		# Naikkan nilainya. 10.0 mungkin terlalu dekat dengan kepala jika kamera jauh.
		# Coba ubah jadi 15.0 atau 20.0.
		global_position.y = player.global_position.y + 15.0
