# 🎮 QUICK REFERENCE - FITUR DARI BRANCH ANSELMARIO

---

## 1️⃣ RANDOM GENANGAN SPAWN 💧

**File:** `Script/Genangan.gd`

```gdscript
extends Area3D
class_name Genangan

@export var slow_percentage: float = 35
@export var permanent_slow: bool = true

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("water_pools")

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		body.apply_water_slowdown(slow_percentage / 100.0)

func _on_body_exited(body: Node3D):
	if body.is_in_group("player") and permanent_slow:
		body.remove_water_slowdown()
```

**Integration Points:**
- Player.gd: `apply_water_slowdown()`, `remove_water_slowdown()`, `update_speed_with_water()`
- Berfungsi sebagai slowdown field yang mengurangi kecepatan player

---

## 2️⃣ CROSSHAIR SYSTEM 🎯

**File:** `Script/UIManager.gd`

```gdscript
@onready var crosshair: Control = $Crosshair

func _process(_delta):
	var player_controller = _find_player_controller()
	if player_controller and player_controller.has_method("is_ketapel_active"):
		update_crosshair_visibility(player_controller.is_ketapel_active())

func update_crosshair_visibility(should_show: bool):
	if crosshair:
		crosshair.visible = should_show
```

**Integration Points:**
- PlayerController.gd: `is_ketapel_active()` method
- Muncul hanya saat player menggunakan Ketapel (tombol 3)

---

## 3️⃣ HEALTH BAR SYSTEM ❤️

**File:** `Script/Player.gd`

```gdscript
const MAX_HEALTH: int = 100
var current_health: int = MAX_HEALTH
var is_dead: bool = false

signal health_changed(current_health, max_health)
signal player_died

func take_damage(damage: int):
	if is_dead:
		return
	
	current_health = max(0, current_health - damage)
	health_changed.emit(current_health, MAX_HEALTH)
	
	if current_health <= 0:
		die()

func die():
	is_dead = true
	current_health = 0
	health_changed.emit(0, MAX_HEALTH)
	player_died.emit()
```

**Integration Points:**
- UIManager.gd: `update_health_display()` method
- WildBoar/HarvesterNPC: Memanggil `player.take_damage(damage)`

---

## 4️⃣ BABI LARI KETIKA DI-HIT 🐗

**File:** `Script/WildBoar.gd`

```gdscript
enum BoarState { SPAWN, CHASE, ATTACK, IDLE, FLEE }

func flee_from_player():
	transition_to_state(BoarState.FLEE)

func state_enter(state: BoarState):
	match state:
		BoarState.FLEE:
			play_animation(chase_animation_name, true)
			play_hit_sound()  # pig3.mp3

func state_process(delta):
	if current_state == BoarState.FLEE:
		var flee_direction = (global_position - player_node.global_position).normalized()
		velocity.x = flee_direction.x * move_speed * 1.5
		velocity.z = flee_direction.z * move_speed * 1.5
		
		flee_timer -= delta
		if flee_timer <= 0:
			queue_free()
```

**Integration Points:**
- PlayerController: Memanggil `boar.flee_from_player()` saat hit
- Sound: Mainkan `res://soundeffect/pig3.mp3`

---

## 📊 FILE YANG PERLU DIMODIFIKASI

```
Script/
├── Player.gd (+ health system)
├── PlayerController.gd (+ ketapel active check)
├── UIManager.gd (+ crosshair & health display)
├── WildBoar.gd (+ flee state & sound)
├── HarvesterNPC.gd (+ scream sound)
└── Genangan.gd (NEW - water slowdown)
```

---

## 🚀 IMPLEMENTATION STEPS

### Step 1: Tambahkan Genangan.gd
```bash
# Copy dari branch atau buat baru
Script/Genangan.gd
```

### Step 2: Update Player.gd
- Tambahkan health variables
- Tambahkan water slowdown functions
- Tambahkan health_changed signal

### Step 3: Update PlayerController.gd
- Tambahkan is_ketapel_active() method
- Ensure ketapel detection

### Step 4: Update UIManager.gd
- Tambahkan crosshair reference
- Tambahkan update_crosshair_visibility() method
- Tambahkan health display methods

### Step 5: Update WildBoar.gd
- Tambahkan FLEE state
- Tambahkan flee_from_player() method
- Tambahkan audio untuk pig3.mp3

---

## ✅ TESTING CHECKLIST

- [ ] Genangan slowdown berfungsi (test dengan player)
- [ ] Crosshair muncul saat ketapel aktif
- [ ] Health bar tampil dan update saat damage
- [ ] Babi lari dengan suara saat di-hit ketapel
- [ ] Semua integrasi signal terhubung
- [ ] Tidak ada console errors

---

**Total Implementation Time:** ~30-45 minutes  
**Difficulty Level:** Medium  
**Dependencies:** Audio files (pig3.mp3, screamman.mp3 sudah ada)

