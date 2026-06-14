extends RigidBody3D
class_name DecoyStone
## Batu dekoy (GDD: Q lempar batu). Saat mendarat, memancarkan noise ke NoiseManager
## sehingga penghuni kebun bergerak menyelidiki sumber suara, lalu batu hilang.

var has_landed: bool = false
var life_timer: float = 0.0
const MAX_LIFETIME: float = 8.0

var land_sound: AudioStream = null
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("decoy_stone")
	contact_monitor = true
	max_contacts_reported = 4
	mass = 0.4
	body_entered.connect(_on_body_entered)

	# Suara mendarat (pakai aset yang ada bila tersedia).
	audio_player = AudioStreamPlayer3D.new()
	audio_player.bus = "SFX"
	audio_player.max_distance = 20.0
	add_child(audio_player)
	if ResourceLoader.exists("res://soundeffect/katapel.mp3"):
		land_sound = load("res://soundeffect/katapel.mp3")

func _process(delta: float) -> void:
	life_timer += delta
	if life_timer >= MAX_LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if has_landed:
		return
	# Abaikan tabrakan dengan player atau batu lain
	if body.is_in_group("player") or body.is_in_group("decoy_stone"):
		return

	has_landed = true
	NoiseManager.emit_noise(global_position, NoiseManager.LOUDNESS_STONE)

	if audio_player and land_sound:
		audio_player.stream = land_sound
		audio_player.play()

	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self):
		queue_free()
