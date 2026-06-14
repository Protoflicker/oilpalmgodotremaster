# 🎮 DOKUMENTASI FITUR DARI BRANCH ANSELMARIO

**Tanggal:** 3 Desember 2025  
**Sumber:** Branch `anselmario`  
**Deskripsi:** 4 Fitur Gameplay yang Ditambahkan ke Oil Palm Godot Game

---

## 📋 DAFTAR FITUR

1. ✅ **Random Genangan Spawn** - Spawn titik genangan secara acak
2. ✅ **Crosshair System** - UI crosshair untuk targeting
3. ✅ **Health Bar System** - System kesehatan player
4. ✅ **Babi Lari Ketika Di-Hit** - Logika lari babi saat terkena ketapel

---

## 1️⃣ RANDOM GENANGAN SPAWN 💧

### File: `Script/Genangan.gd`

**Deskripsi:**
Genangan adalah area kecil yang memperlambat gerakan player. Script ini menangani deteksi kolisi player dengan genangan dan menerapkan efek slowdown.

**Kode Lengkap:**
```gdscript
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
```

### Integrasi dengan Player.gd

**Fungsi Slowdown:**
```gdscript
func apply_water_slowdown(factor: float):
	if not is_in_water:
		is_in_water = true
		water_slow_factor = factor  # factor = 0.35 dari Genangan
		print("Player terkena efek air: ", factor * 100, "% slowdown")
		update_speed_with_water()
	else:
		# Jika sudah di air, update faktor (jika berbeda)
		water_slow_factor = max(water_slow_factor, factor)
		update_speed_with_water()

func remove_water_slowdown():
	if is_in_water:
		is_in_water = false
		water_slow_factor = 0.0
		print("Player keluar dari air")
		update_speed_with_water()
```

**Kalkulasi Speed dengan Water:**
```gdscript
func update_speed_with_water():
	# Hitung reduksi dari buah
	var total_kg = carried_ripe_kg
	var weight_reduction = total_kg * speed_reduction_factor
	
	# Hitung reduksi dari air (jika ada)
	var water_reduction = 0.0
	if is_in_water and water_slow_factor > 0:
		water_reduction = BASE_SPEED * water_slow_factor
	
	# Total speed
	var new_speed = max(1.0, BASE_SPEED - weight_reduction - water_reduction)
	
	if player_controller:
		player_controller.set_current_speed(new_speed)
	
	# DEBUG
	print("===== SPEED CALCULATION =====")
	print("Base Speed: ", BASE_SPEED)
	print("Carried KG: ", total_kg, " | Weight Reduction: ", weight_reduction)
	print("In Water: ", is_in_water, " | Water Slow Factor: ", water_slow_factor)
	print("Water Reduction: ", water_reduction)
	print("New Speed: ", new_speed)
	print("=============================")
```

### Variabel di Player.gd
```gdscript
# VARIABEL BARU
var water_slow_factor: float = 0  # 0 = no slow, 0.35 = 35% slow
var is_in_water: bool = false
var original_speed: float = BASE_SPEED
```

**Mekanisme:**
1. Player memasuki Area3D (Genangan)
2. Signal `body_entered` dipicu
3. Genangan memanggil `apply_water_slowdown(0.35)` pada player
4. Player speed berkurang sebesar 35%
5. Ketika player keluar, kecepatan kembali normal

**Setting di Inspector:**
- `slow_percentage`: 35 (persen)
- `permanent_slow`: true (efek permanen hingga keluar)

---

## 2️⃣ CROSSHAIR SYSTEM 🎯

### File: `Script/UIManager.gd`

**Deskripsi:**
Crosshair adalah UI visual yang menunjukkan titik pusat layar. Muncul hanya ketika player menggunakan Ketapel.

**Kode Utama di UIManager.gd:**
```gdscript
@onready var crosshair: Control = $Crosshair

func _ready():
	# Setup crosshair
	if crosshair:
		crosshair.visible = false
	
	call_deferred("setup_crosshair")

func _process(_delta):
	if not should_show_ui_labels():
		update_sensitive_labels_visibility()
		if crosshair:
			crosshair.visible = false
	else:
		# Update crosshair visibility berdasarkan tool aktif
		var player_controller = _find_player_controller()
		if player_controller:
			if player_controller.has_method("is_ketapel_active"):
				var is_ketapel = player_controller.is_ketapel_active()
				update_crosshair_visibility(is_ketapel)
			else:
				if crosshair:
					crosshair.visible = false
		else:
			if crosshair and crosshair.visible:
				crosshair.visible = false

func setup_crosshair():
	if crosshair:
		# Posisikan di tengah layar
		crosshair.anchor_left = 0.5
		crosshair.anchor_top = 0.5
		crosshair.anchor_right = 0.5
		crosshair.anchor_bottom = 0.5
		crosshair.offset_left = -crosshair.size.x / 2
		crosshair.offset_top = -crosshair.size.y / 2

func update_crosshair_visibility(should_show: bool):
	if crosshair:
		crosshair.visible = should_show
```

**Integrasi dengan PlayerController.gd:**
```gdscript
enum Tool { EGREK, TOJOK, KETAPEL } 
var current_tool: Tool = Tool.EGREK

func is_ketapel_active() -> bool:
	return current_tool == Tool.KETAPEL

func is_egrek_active() -> bool:
	return current_tool == Tool.EGREK

func is_tojok_active() -> bool:
	return current_tool == Tool.TOJOK

func switch_tool(new_tool: Tool):
	if current_tool == new_tool:
		return
	
	# Sembunyikan semua tool terlebih dahulu
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = false
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = false
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.visible = false
	
	current_tool = new_tool
	
	# Tampilkan tool yang baru
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = true
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = true
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.visible = true
	
	update_tool_position()
```

**Desain Crosshair (Possible):**
- Simple dot di tengah
- Atau bisa berupa TextureRect dengan gambar crosshair

**Mekanisme:**
1. Player tekan tombol untuk Ketapel (tombol 3)
2. PlayerController switch_tool(Tool.KETAPEL)
3. UIManager.update_crosshair_visibility(true)
4. Crosshair muncul di tengah layar
5. Ketika ganti tool, crosshair hilang

---

## 3️⃣ HEALTH BAR SYSTEM ❤️

### File: `Script/Player.gd`

**Deskripsi:**
System kesehatan player dengan health bar dan damage system.

**Variabel Health di Player.gd:**
```gdscript
# Health system
const MAX_HEALTH: int = 100
var current_health: int = MAX_HEALTH
var is_dead: bool = false

signal health_changed(current_health, max_health)
signal player_died
```

**Fungsi Health:**
```gdscript
func take_damage(damage: int):
	if is_dead:
		return
	
	current_health = max(0, current_health - damage)
	health_changed.emit(current_health, MAX_HEALTH)
	
	print("Player terkena damage: ", damage, " HP. Health sekarang: ", current_health, "/", MAX_HEALTH)
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	current_health = 0
	health_changed.emit(0, MAX_HEALTH)
	player_died.emit()
	
	print("Player MATI! Game Over")

func is_player_dead() -> bool:
	return is_dead

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return MAX_HEALTH
```

### Integrasi dengan UIManager.gd

**Setup UI:**
```gdscript
@onready var health_label: Label = $HealthBarContainer/HealthLabel
@onready var health_bar: ProgressBar = $HealthBarContainer/HealthBar

func _ready():
	# Setup health bar - make sure it's visible
	if health_bar:
		health_bar.visible = true
	if health_label:
		health_label.visible = true

func connect_to_game_systems():
	# Connect health system
	if player and player.has_signal("health_changed"):
		if not player.health_changed.is_connected(update_health_display):
			player.health_changed.connect(update_health_display)
		# Initialize health display
		if player.has_method("get_current_health") and player.has_method("get_max_health"):
			update_health_display(player.get_current_health(), player.get_max_health())

func update_health_display(current: int, max_hp: int):
	if health_bar:
		health_bar.max_value = float(max_hp)
		health_bar.value = float(current)
	
	if health_label:
		health_label.text = "%d / %d" % [current, max_hp]
		
		# Change color berdasarkan health
		if current <= max_hp * 0.3:
			health_label.modulate = Color.RED  # Kritis
		elif current <= max_hp * 0.6:
			health_label.modulate = Color.YELLOW  # Warning
		else:
			health_label.modulate = Color.GREEN  # Normal
```

**Health Bar Configuration:**
- `max_value`: 100
- `value`: current_health
- `fill_mode`: ProgressBar.FILL_LEFT_TO_RIGHT
- `color`: Green → Yellow → Red (gradient)

**Mekanisme:**
1. Babi/Pencuri attack player
2. PlayerController.take_damage(damage_value) dipanggil
3. current_health berkurang
4. Signal `health_changed` dipancar
5. UIManager.update_health_display() memperbarui UI
6. Jika health <= 0, player mati

---

## 4️⃣ BABI LARI KETIKA DI-HIT 🐗

### File: `Script/WildBoar.gd`

**Deskripsi:**
Ketika babi terkena ketapel, dia akan lari dari player (flee state).

**Enum State:**
```gdscript
enum BoarState {
	SPAWN,
	CHASE,
	ATTACK,
	IDLE,
	FLEE  # ← DITAMBAHKAN
}
```

**Fungsi Flee:**
```gdscript
func flee_from_player():
	print("WildBoar berhasil ditembak! Lari dari area")
	transition_to_state(BoarState.FLEE)

func return_to_spawn():
	print("WildBoar kembali ke spawn dan akan hilang...")
	
	# Mainkan animasi kabur jika ada
	if animation_player and animation_player.has_animation("RunAway"):
		play_animation("RunAway", false)
		await animation_player.animation_finished
	
	# DESTROY objek
	queue_free()
```

**State Enter Flee:**
```gdscript
func state_enter(state: BoarState):
	match state:
		BoarState.SPAWN:
			play_animation(idle_animation_name, true)
			
		BoarState.CHASE:
			can_attack = true
			attack_timer = 0.0
			is_attack_playing = false
			play_animation(chase_animation_name, true)
			
		BoarState.ATTACK:
			# Hanya set state, animasi akan diputar di perform_attack()
			pass
			
		BoarState.IDLE:
			play_animation(idle_animation_name, true)
		
		BoarState.FLEE:
			can_attack = false
			is_attack_playing = false
			is_performing_attack = false
			play_animation(chase_animation_name, true)
			play_hit_sound()  # ← Mainkan pig3.mp3
```

**State Process Flee:**
```gdscript
func state_process(delta):
	match current_state:
		BoarState.FLEE:
			# Jika ada target spawn (biasanya di tepi map)
			var flee_direction = (global_position - player_node.global_position).normalized()
			velocity.x = flee_direction.x * move_speed * 1.5  # Lari lebih cepat
			velocity.z = flee_direction.z * move_speed * 1.5
			
			# Setelah beberapa detik, hilang
			flee_timer -= delta
			if flee_timer <= 0:
				return_to_spawn()
```

**Integrasi dengan PlayerController:**
```gdscript
func shoot_ketapel():
	# Raycast untuk detect boar
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.is_in_group("wild_boar"):
		var boar = result.collider
		if boar.has_method("flee_from_player"):
			boar.flee_from_player()
```

**Sound Effect Integration:**
```gdscript
# Variabel di WildBoar.gd
var audio_player: AudioStreamPlayer3D
var pig3_sound: AudioStream

func setup_audio_player():
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.bus = "Master"
	audio_player.volume_db = 0
	audio_player.max_distance = 20
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	pig3_sound = load("res://soundeffect/pig3.mp3")

func play_hit_sound():
	if audio_player and pig3_sound:
		audio_player.stream = pig3_sound
		audio_player.play()
```

**Mekanisme:**
1. Player menembak ketapel → mengenai babi
2. WildBoar.flee_from_player() dipanggil
3. State berubah ke FLEE
4. Babi lari menjauhi player dengan kecepatan 1.5x
5. Sound pig3.mp3 diputar
6. Setelah timer habis, babi hilang (queue_free)

---

## 📊 RINGKASAN INTEGRASI

| Fitur | File | Fungsi Utama | Signal | Status |
|-------|------|-------------|--------|--------|
| Genangan | Genangan.gd | apply_water_slowdown() | body_entered | ✅ |
| Crosshair | UIManager.gd | update_crosshair_visibility() | _process() | ✅ |
| Health Bar | Player.gd, UIManager.gd | take_damage(), update_health_display() | health_changed | ✅ |
| Babi Lari | WildBoar.gd | flee_from_player(), state_enter(FLEE) | - | ✅ |

---

## 🔄 DATA FLOW

### Genangan Flow:
```
Player memasuki Genangan
    ↓
Genangan._on_body_entered(player)
    ↓
apply_water_slowdown(0.35)
    ↓
water_slow_factor = 0.35
    ↓
update_speed_with_water()
    ↓
new_speed = BASE_SPEED - weight_reduction - water_reduction
    ↓
player_controller.set_current_speed(new_speed)
    ↓
🐌 Player bergerak lambat
```

### Crosshair Flow:
```
Player tekan Tombol 3 (Ketapel)
    ↓
PlayerController.switch_tool(Tool.KETAPEL)
    ↓
UIManager._process()
    ↓
is_ketapel_active() == true
    ↓
update_crosshair_visibility(true)
    ↓
🎯 Crosshair muncul
```

### Health Flow:
```
Babi/Pencuri attack player
    ↓
player.take_damage(20)
    ↓
current_health -= 20
    ↓
health_changed.emit(current_health, MAX_HEALTH)
    ↓
UIManager.update_health_display()
    ↓
❤️ Health bar berubah
```

### Babi Lari Flow:
```
Player menembak ketapel ke babi
    ↓
WildBoar.flee_from_player()
    ↓
transition_to_state(BoarState.FLEE)
    ↓
state_enter(BoarState.FLEE)
    ↓
play_hit_sound() + play_animation()
    ↓
state_process() → gerakan lari
    ↓
🐗 Babi lari dengan suara
```

---

## ✨ KESIMPULAN

Keempat fitur ini menciptakan gameplay loop yang lengkap:

1. **Genangan** → Menambah difficulty dengan slowdown
2. **Crosshair** → Membantu player aim Ketapel
3. **Health Bar** → Show player status dan challenge
4. **Babi Lari** → Feedback visual/audio ketika hit

Semua terintegrasi seamlessly dalam oil palm harvesting game!

