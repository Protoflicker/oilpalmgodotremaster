# 📚 DOKUMENTASI FITUR DARI BRANCH ANSELMARIO - RINGKASAN FINAL

**Tanggal Dokumentasi:** 3 Desember 2025  
**Sumber:** Branch `anselmario` pada repository Oil-Palm-Godot  
**Status:** ✅ READY FOR IMPLEMENTATION

---

## 🎯 OVERVIEW

Dokumentasi ini menjelaskan 4 fitur gameplay utama yang berada di branch `anselmario` dan belum diimplementasikan di branch `main`:

1. **Random Genangan Spawn** - Water slowdown mechanic
2. **Crosshair System** - UI targeting crosshair
3. **Health Bar System** - Player health management
4. **Babi Lari Ketika Di-Hit** - Boar flee mechanic dengan sound

---

## 📁 FILE DOKUMENTASI YANG TELAH DIBUAT

### 1. **FITUR_ANSELMARIO_DOCUMENTATION.md** (Lengkap)
   - Penjelasan detail setiap fitur
   - Kode source lengkap
   - Data flow diagram
   - Integration points

### 2. **QUICK_REFERENCE_FEATURES.md** (Ringkas)
   - Quick reference untuk setiap fitur
   - Code snippets
   - Implementation steps
   - Testing checklist

---

## 🔍 SUMMARY SETIAP FITUR

### 1️⃣ RANDOM GENANGAN SPAWN 💧

**Apa:** Area yang memperlambat gerakan player  
**Dimana:** Script/Genangan.gd (NEW)  
**Bagaimana:** 
- Genangan adalah Area3D yang detect player collision
- Saat player masuk, apply slowdown 35%
- Saat player keluar, remove slowdown
- Speed = BASE_SPEED - weight_reduction - water_reduction

**Integration:**
```
Genangan.gd → Player.gd → PlayerController.gd
```

**Config Export:**
- `slow_percentage`: 35 (%)
- `permanent_slow`: true

---

### 2️⃣ CROSSHAIR SYSTEM 🎯

**Apa:** UI visual untuk targeting ketapel  
**Dimana:** Script/UIManager.gd (UPDATE)  
**Bagaimana:**
- Control node bernama "Crosshair" di scene
- Visible hanya saat current_tool == KETAPEL
- Check di _process() setiap frame

**Integration:**
```
PlayerController.is_ketapel_active() → UIManager.update_crosshair_visibility()
```

**Desain:** Simple dot atau gambar crosshair di tengah layar

---

### 3️⃣ HEALTH BAR SYSTEM ❤️

**Apa:** System damage dan kesehatan player  
**Dimana:** 
  - Script/Player.gd (UPDATE - add health system)
  - Script/UIManager.gd (UPDATE - display health)
  
**Bagaimana:**
- MAX_HEALTH = 100 HP
- take_damage(damage) → mengurangi health
- Signal health_changed emit → UI update
- Jika health <= 0 → player die

**Integration:**
```
WildBoar/HarvesterNPC.take_damage() → Player.take_damage() → health_changed signal → UIManager.update_health_display()
```

**Display:**
- Health Label: "80 / 100"
- Health Bar: ProgressBar dengan color gradient
- Color: Green (normal) → Yellow (warning) → Red (kritis)

---

### 4️⃣ BABI LARI KETIKA DI-HIT 🐗

**Apa:** Babi lari ketika terkena ketapel  
**Dimana:** Script/WildBoar.gd (UPDATE)  
**Bagaimana:**
- Tambah state baru: FLEE
- Saat terkena ketapel: transition_to_state(FLEE)
- Di FLEE: play animation + sound + run away
- Setelah timer: queue_free()

**Integration:**
```
PlayerController.shoot() → WildBoar.flee_from_player() → state_enter(FLEE) → play_hit_sound()
```

**Audio:** res://soundeffect/pig3.mp3 (sudah ada)

---

## 📊 FILE CHANGES SUMMARY

| File | Type | Changes | Lines |
|------|------|---------|-------|
| Genangan.gd | NEW | Complete file | 20 |
| Player.gd | UPDATE | Health system | +50 |
| PlayerController.gd | UPDATE | Ketapel check | +10 |
| UIManager.gd | UPDATE | Crosshair + Health | +30 |
| WildBoar.gd | UPDATE | FLEE state + sound | +40 |

**Total Changes:** 5 files, ~150 lines of code

---

## 🎮 GAMEPLAY MECHANICS

### Genangan Effect:
```
Normal Speed = 14 km/h
In Genangan = 14 - (14 × 0.35) = 9.1 km/h
Carrying 50kg = 14 - 1.5 = 12.5 km/h
Carrying 50kg in Genangan = 14 - 1.5 - 4.9 = 7.6 km/h
```

### Health System:
```
Max Health: 100 HP
Boar Attack: -20 HP
NPC Attack: -15 HP
Dead: Health <= 0 HP
Game Over: Player Dead
```

### Crosshair Toggle:
```
Tool Switch
├─ EGREK → No crosshair
├─ TOJOK → No crosshair
└─ KETAPEL → Show crosshair
```

### Boar Flee Mechanic:
```
Hit by Ketapel
  ├─ Play sound: pig3.mp3
  ├─ Play animation: Run
  ├─ Move away: speed × 1.5
  ├─ Timer counting: 5 seconds
  └─ Disappear: queue_free()
```

---

## 🔗 DEPENDENCIES & CONNECTIONS

### Signal Chain:
```
Player Health Changed
  ↓
health_changed signal
  ↓
UIManager.update_health_display()
  ↓
Health Bar & Label update
```

### Tool Detection Chain:
```
PlayerController.current_tool
  ↓
UIManager._process()
  ↓
is_ketapel_active() check
  ↓
update_crosshair_visibility()
```

### Slowdown Chain:
```
Player enters Genangan
  ↓
Genangan._on_body_entered()
  ↓
Player.apply_water_slowdown(0.35)
  ↓
Player.update_speed_with_water()
  ↓
Speed recalculated
```

---

## 📋 IMPLEMENTATION CHECKLIST

- [ ] Create/Copy Genangan.gd
- [ ] Update Player.gd with health system
- [ ] Update Player.gd with water slowdown
- [ ] Update PlayerController.gd with ketapel check
- [ ] Update UIManager.gd with crosshair
- [ ] Update UIManager.gd with health display
- [ ] Update WildBoar.gd with FLEE state
- [ ] Update WildBoar.gd with sound integration
- [ ] Test genangan slowdown
- [ ] Test crosshair visibility toggle
- [ ] Test health damage system
- [ ] Test boar flee mechanic
- [ ] Test audio playback
- [ ] Verify no console errors
- [ ] Test gameplay flow

---

## 🎓 TECHNICAL NOTES

### Best Practices Implemented:
1. **State Machine Pattern** - Untuk boar flee state
2. **Signal System** - Untuk health change notification
3. **Group System** - Untuk detection (player, wild_boar, water_pools)
4. **Export Variables** - Untuk easy configuration
5. **Error Handling** - Resource loading checks

### Performance Considerations:
- Genangan slowdown calc hanya saat speed change
- Crosshair check di _process() (light operation)
- Health bar update via signal (efficient)
- Boar flee dengan simple direction calculation

### Compatibility:
- Godot 4.x ✅
- GDScript modern syntax ✅
- Built-in AudioStreamPlayer3D ✅
- No external dependencies ✅

---

## 🎯 NEXT STEPS

1. **Review Documentation**
   - Baca FITUR_ANSELMARIO_DOCUMENTATION.md
   - Review code snippets
   - Pahami data flow

2. **Prepare Files**
   - Checkout Genangan.gd dari branch anselmario
   - Siapkan update untuk 4 file lainnya

3. **Implementation**
   - Mulai dari Genangan.gd
   - Lanjut ke Player.gd
   - Update PlayerController.gd
   - Update UIManager.gd
   - Update WildBoar.gd

4. **Testing**
   - Test setiap fitur individual
   - Test integrasi antar fitur
   - Verifikasi gameplay flow
   - Check console untuk errors

5. **Deployment**
   - Commit changes
   - Push ke repository
   - Create pull request (jika perlu)

---

## 📞 REFERENCE

### Files Locations:
```
c:\Godot\Oil-Palm-Godot\
├── Script/
│   ├── Player.gd (❌ NEED UPDATE)
│   ├── PlayerController.gd (❌ NEED UPDATE)
│   ├── UIManager.gd (❌ NEED UPDATE)
│   ├── WildBoar.gd (❌ NEED UPDATE)
│   └── Genangan.gd (❌ NEED CREATE)
└── soundeffect/
    ├── pig3.mp3 (✅ EXISTS)
    └── screamman.mp3 (✅ EXISTS)
```

### Documentation Files:
```
c:\Godot\Oil-Palm-Godot\
├── FITUR_ANSELMARIO_DOCUMENTATION.md (📖 Full Documentation)
├── QUICK_REFERENCE_FEATURES.md (⚡ Quick Reference)
└── DOCUMENTATION_SUMMARY.md (📚 This File)
```

### Source Branch:
```
Branch: origin/anselmario
URL: https://github.com/SinagaPande/Oil-Palm-Godot/tree/anselmario
```

---

## ✨ CONCLUSION

Keempat fitur ini akan meningkatkan gameplay experience dengan:
- **Challenge** (Genangan slowdown)
- **Usability** (Crosshair targeting)
- **Feedback** (Health bar status)
- **Polish** (Boar flee dengan sound)

Implementasi dapat diselesaikan dalam 30-45 menit dengan dokumentasi yang sudah tersedia.

---

**Status:** ✅ READY FOR IMPLEMENTATION  
**Dokumentasi:** ✅ COMPLETE  
**Tanggal:** 3 Desember 2025  
**Siap untuk:** Development Sprint

