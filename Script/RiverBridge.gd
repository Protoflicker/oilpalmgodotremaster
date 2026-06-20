extends Node3D
class_name RiverBridge
## Sungai + jembatan prosedural (level 3 & 4). Air = visual tembus pandang; mengarungi air
## di luar jembatan memperlambat (zona Genangan di kiri/kanan), sedangkan menyeberang lewat
## celah jembatan (papan kayu) tidak melambat. Royalty-free (geometri orisinal).

@export var length: float = 200.0   # panjang sungai (sepanjang sumbu X)
@export var width: float = 16.0     # lebar sungai (sepanjang sumbu Z)

const BRIDGE_GAP: float = 4.5       # setengah-lebar celah jembatan (x dalam [-gap, gap])

func _ready() -> void:
	add_to_group("river")
	_build()

func _build() -> void:
	# Air (visual, tembus pandang)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.13, 0.32, 0.46, 0.62)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.12
	water_mat.metallic = 0.25
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(length, width)
	water.mesh = pm
	water.material_override = water_mat
	water.position = Vector3(0, 0.06, 0)
	add_child(water)

	# Zona lambat (mengarungi air) di kiri & kanan celah jembatan.
	var half := length / 2.0
	var seg := half - BRIDGE_GAP
	if seg > 1.0:
		_add_slow(Vector3(-(half + BRIDGE_GAP) / 2.0, 1.0, 0.0), Vector3(seg, 2.0, width))
		_add_slow(Vector3((half + BRIDGE_GAP) / 2.0, 1.0, 0.0), Vector3(seg, 2.0, width))

	# Jembatan: papan kayu di celah (x dalam [-gap, gap]) — menyeberang di sini tidak melambat.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.26, 0.17, 0.09)
	wood.roughness = 1.0
	var deck := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(BRIDGE_GAP * 2.0, 0.18, width + 4.0)
	deck.mesh = dbox
	deck.material_override = wood
	deck.position = Vector3(0, 0.13, 0)
	add_child(deck)

	# Pagar jembatan (visual)
	for s in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(BRIDGE_GAP * 2.0, 0.7, 0.18)
		rail.mesh = rbox
		rail.material_override = wood
		rail.position = Vector3(0, 0.5, s * ((width + 4.0) / 2.0))
		add_child(rail)

func _add_slow(pos: Vector3, box_size: Vector3) -> void:
	var area := Area3D.new()
	area.set_script(load("res://Script/Genangan.gd"))
	area.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	cs.shape = box
	area.add_child(cs)
	add_child(area)
