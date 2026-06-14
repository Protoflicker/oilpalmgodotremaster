extends StaticBody3D
class_name Pondok
## Pondok (rumah/gubuk) si penghuni kebun di tengah peta (GDD: pria gila tinggal di pondok).
## Dibangun dari primitif (BoxMesh) — 100% royalty-free karena geometri orisinal.
## Dinding memblokir garis pandang & gerak, jadi player bisa bersembunyi di balik/di dalamnya.

func _ready() -> void:
	add_to_group("madman_home")
	collision_layer = 1
	collision_mask = 0
	_build()

func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.11, 0.08, 0.06)
	wood.roughness = 1.0

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.05, 0.04, 0.04)
	roof_mat.roughness = 1.0

	var w := 7.0
	var d := 7.0
	var h := 3.2
	var t := 0.25
	var door := 1.7

	# Lantai & atap
	_box(Vector3(w, t, d), Vector3(0, t * 0.5, 0), wood)
	_box(Vector3(w + 0.8, t, d + 0.8), Vector3(0, h, 0), roof_mat)

	# Dinding belakang & samping
	_box(Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), wood)
	_box(Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), wood)
	_box(Vector3(t, h, d), Vector3(w * 0.5, h * 0.5, 0), wood)

	# Dinding depan dengan celah pintu di tengah
	var seg := (w - door) * 0.5
	_box(Vector3(seg, h, t), Vector3(-(door * 0.5 + seg * 0.5), h * 0.5, d * 0.5), wood)
	_box(Vector3(seg, h, t), Vector3(door * 0.5 + seg * 0.5, h * 0.5, d * 0.5), wood)
	# Ambang atas pintu
	var lintel := h - 2.3
	_box(Vector3(door, lintel, t), Vector3(0, h - lintel * 0.5, d * 0.5), wood)

	# Lampu interior temaram & mencekam
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.45, 0.18)
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, h - 0.7, 0)
	add_child(lamp)

	# Marker patroli di depan pintu (penghuni kebun "menjaga" rumahnya).
	var m := Marker3D.new()
	m.add_to_group("patrol_point")
	m.position = Vector3(0, 0.5, d * 0.5 + 2.5)
	add_child(m)

func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	add_child(cs)
