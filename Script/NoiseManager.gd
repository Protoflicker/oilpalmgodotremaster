extends Node
## NoiseManager (Autoload)
## Pusat "event bus" untuk kebisingan. Aksi player (langkah, panen, batu jatuh)
## memancarkan noise ke sini, dan musuh (PenghuniKebun) mendengarkannya untuk
## berpindah ke INVESTIGATE. Inti dari Noise & Visibility System di GDD.

## position  : titik sumber suara di dunia
## loudness  : radius dengar efektif dalam satuan world (semakin besar = semakin jauh terdengar)
signal noise_emitted(position: Vector3, loudness: float)

# Nilai loudness acuan (radius world unit). Dipakai player & dekoy.
const LOUDNESS_SILENT: float = 0.0
const LOUDNESS_CROUCH_STEP: float = 2.0
const LOUDNESS_WALK_STEP: float = 7.0
const LOUDNESS_RUN_STEP: float = 16.0
const LOUDNESS_HARVEST: float = 22.0      # buah sawit jatuh saat dipanen
const LOUDNESS_FRUIT_LAND: float = 10.0   # buah menyentuh tanah
const LOUDNESS_STONE: float = 18.0        # batu dekoy mendarat

# Pelacakan suara terakhir (untuk debug / patroli adaptif)
var last_noise_position: Vector3 = Vector3.ZERO
var last_noise_loudness: float = 0.0
var noise_count: int = 0

# Untuk meter noise di HUD: nilai 0..1 yang meluruh seiring waktu.
var current_noise_level: float = 0.0
const NOISE_METER_DECAY: float = 1.2   # per detik
const NOISE_METER_REFERENCE: float = LOUDNESS_RUN_STEP

func _process(delta: float) -> void:
	if current_noise_level > 0.0:
		current_noise_level = maxf(0.0, current_noise_level - NOISE_METER_DECAY * delta)

## Pancarkan kebisingan ke seluruh pendengar.
func emit_noise(position: Vector3, loudness: float) -> void:
	if loudness <= 0.0:
		return
	last_noise_position = position
	last_noise_loudness = loudness
	noise_count += 1

	# Update meter HUD (dinormalisasi terhadap suara lari).
	var normalized: float = clampf(loudness / NOISE_METER_REFERENCE, 0.0, 1.0)
	current_noise_level = maxf(current_noise_level, normalized)

	noise_emitted.emit(position, loudness)

## Level noise saat ini untuk HUD (0..1).
func get_noise_level() -> float:
	return current_noise_level
