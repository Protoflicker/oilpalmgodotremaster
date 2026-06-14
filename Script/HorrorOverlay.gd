extends CanvasLayer
## Overlay post-process horror. Dibangun penuh lewat kode (CanvasLayer layer=-1 → diproses
## di atas render 3D tapi di bawah HUD). Intensity efek naik saat penghuni kebun / satwa mendekat
## atau sedang mengejar, sehingga POV player jadi kabur & mencekam (GDD: kesan horror).

var rect: ColorRect
var mat: ShaderMaterial
var player: Node3D = null

const NEAR_DIST: float = 16.0
var cur_intensity: float = 0.0

func _ready() -> void:
	layer = -1

	# BackBufferCopy agar hint_screen_texture terisi (penting di renderer GL Compatibility).
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)

	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	mat = ShaderMaterial.new()
	mat.shader = load("res://Scene/horror_overlay.gdshader")
	mat.set_shader_parameter("intensity", 0.0)
	rect.material = mat
	add_child(rect)

	_find_player()

func _find_player() -> void:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.size() > 0:
		player = ps[0]

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_find_player()

	var target := 0.0
	if player:
		var nearest := 99999.0
		var chasing := false
		for e in get_tree().get_nodes_in_group("harvester_npc"):
			if is_instance_valid(e):
				var dd: float = player.global_position.distance_to(e.global_position)
				if dd < nearest:
					nearest = dd
				if e.has_method("is_chasing") and e.is_chasing():
					chasing = true
		for b in get_tree().get_nodes_in_group("wild_boar"):
			if is_instance_valid(b):
				var dd2: float = player.global_position.distance_to(b.global_position)
				if dd2 < nearest:
					nearest = dd2
		if nearest < NEAR_DIST:
			target = clampf(1.0 - nearest / NEAR_DIST, 0.0, 1.0)
		if chasing:
			target = maxf(target, 0.8)

	cur_intensity = lerpf(cur_intensity, target, clampf(delta * 3.0, 0.0, 1.0))
	if mat:
		mat.set_shader_parameter("intensity", cur_intensity)
