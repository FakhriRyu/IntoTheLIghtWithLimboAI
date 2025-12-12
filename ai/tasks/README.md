# Frogo AI Tasks

Task-task LimboAI untuk membuat behavior tree Frogo yang dapat mengejar player.

## Tasks yang Tersedia

### 1. get_player_location.gd
**Type:** BTAction  
**Fungsi:** Mendapatkan referensi player dari group "player" dan menyimpannya ke blackboard.

**Parameters:**
- `output_var` (StringName): Variable blackboard untuk menyimpan player (default: "target")

**Returns:**
- `SUCCESS`: Jika player ditemukan
- `FAILURE`: Jika player tidak ditemukan

---

### 2. check_player_in_range.gd
**Type:** BTCondition  
**Fungsi:** Mengecek apakah player berada dalam jangkauan detection area.

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target/player (default: "target")
- `detection_range` (float): Jarak maksimal untuk mendeteksi player (default: 250.0)

**Returns:**
- `SUCCESS`: Jika player dalam jangkauan
- `FAILURE`: Jika player di luar jangkauan

---

### 3. pursue_target.gd
**Type:** BTAction  
**Fungsi:** Mengejar target secara agresif hingga sangat dekat. Akan berhenti mengejar dan kembali ke idle jika player terlalu jauh.

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target (default: "target")
- `speed` (float): Kecepatan gerak (default: 120.0) - lebih cepat untuk aggressive chase
- `approach_distance` (float): Jarak berhenti dari target (default: 20.0) - sangat dekat
- `max_chase_distance` (float): Jarak maksimal chase - jika player lebih jauh, kembali ke idle (default: 300.0)
- `animation_player_path` (NodePath): Path ke AnimationPlayer (default: "AnimationPlayer")
- `move_animation` (StringName): Nama animasi untuk bergerak (default: "Hop")

**Returns:**
- `RUNNING`: Saat sedang bergerak menuju target
- `SUCCESS`: Saat sudah sangat dekat dengan target
- `FAILURE`: Jika target tidak valid atau terlalu jauh (melewati max_chase_distance)

---

### 4. check_target_in_area.gd
**Type:** BTCondition  
**Fungsi:** Mengecek apakah target berada di dalam `Area2D` (mis. `DetectionArea`). Jika target keluar area, task gagal sehingga Sequence chase berhenti dan selector kembali ke Chill.

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target (default: "target")
- `detection_area_path` (NodePath): Path ke `Area2D` pada agent (default: "DetectionArea")

**Returns:**
- `SUCCESS`: Jika target berada di dalam area
- `FAILURE`: Jika target tidak valid atau berada di luar area

---

### 5. check_low_hp.gd
**Type:** BTCondition  
**Fungsi:** Mengecek apakah HP agent di bawah threshold tertentu (default 30%). Juga cek cooldown agar tidak langsung flee lagi setelah selesai.

**Parameters:**
- `hp_threshold` (float): Persentase HP threshold dalam 0.0-1.0 (default: 0.3 = 30%)
- `health_node_path` (NodePath): Path ke Health node pada agent (default: "Health")
- `cooldown_var` (StringName): Blackboard variable untuk cek cooldown (default: "flee_cooldown_end")

**Returns:**
- `SUCCESS`: Jika HP di bawah threshold DAN tidak dalam cooldown
- `FAILURE`: Jika HP cukup tinggi, dalam cooldown, atau health tidak ditemukan

---

### 6. flee_from_target.gd
**Type:** BTAction  
**Fungsi:** Kabur menjauhi target selama durasi tertentu. Setelah selesai, set cooldown agar tidak langsung flee lagi.

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target (default: "target")
- `flee_speed` (float): Kecepatan kabur (default: 150.0)
- `flee_duration` (float): Durasi flee dalam detik (default: 2.0)
- `cooldown_duration` (float): Durasi cooldown setelah flee (default: 5.0)
- `cooldown_var` (StringName): Blackboard variable untuk menyimpan cooldown (default: "flee_cooldown_end")

**Returns:**
- `RUNNING`: Saat sedang berlari menjauh
- `SUCCESS`: Setelah durasi flee selesai (dan set cooldown)
- `FAILURE`: Jika target tidak valid

---

## Cara Menggunakan dalam Behavior Tree

Berikut adalah contoh struktur behavior tree untuk Frogo:

```
BTSelector (Root)
├── BTSequence (Aggressive Chase Player)
│   ├── GetPlayer (output_var: "target")
│   ├── CheckTargetInArea (target_var: "target", detection_area_path: "DetectionArea")
│   └── PursueTarget (target_var: "target", speed: 120, approach_distance: 20)
└── BTSequence (Idle/Chill)
    ├── BTPlayAnimation (animation: "Idle")
    └── BTRandomWait
```

### Behavior Flow Berbasis Area2D:
- Masuk area (`CheckTargetInArea` sukses) → lanjut ke `PursueTarget`
- Keluar area (`CheckTargetInArea` gagal) → Sequence gagal → Selector fallback ke Chill

### Penjelasan Logika:

1. **BTSelector** akan mencoba menjalankan child pertama (Aggressive Chase Player)
2. Jika player ditemukan DAN dalam range (250px), maka Frogo akan mengejar secara agresif
3. Jika player tidak ditemukan ATAU di luar range, maka akan fallback ke behavior Idle
4. Frogo akan terus mengejar (RUNNING) sampai sangat dekat dengan player (~20px)
5. **PENTING**: Jika saat mengejar player kabur dan jaraknya melebihi 300px, Frogo akan **berhenti mengejar** dan kembali ke idle
6. Chase bersifat **agresif** - Frogo bergerak lebih cepat (120 speed) dan mendekati hingga sangat dekat

### Behavior Flow:
```
1. Frogo Idle
2. Player masuk detection_range (250px) → Mulai Chase
3. Frogo mengejar player dengan speed 120
4. Jika player kabur > max_chase_distance (300px) → Kembali ke Idle
5. Jika Frogo sampai dekat (20px) → Success → Kembali ke Idle
```

### Visual Diagram:
```
       Frogo                                Player
         🐸                                    🤺
         |                                     |
         |<-------- 250px (detection) ------->|
         |                                     |
    [IDLE STATE]                               |
         |                                     |
         |  Player masuk detection range       |
         |                                     |
    [START CHASE] ========================>    |
         |           (speed: 120)              |
         |                                     |
         |<-------- 300px (max chase) -------->|
         |                                     |
         |  Jika > 300px: STOP CHASE          |
         |  Kembali ke IDLE                    |
         |                                     |
         |<- 20px ->|                         |
    [SUCCESS - VERY CLOSE]                     |
         |                                     |
    [BACK TO IDLE]                             |
```

### Setup di Godot Editor:

1. Buka `ai/trees/frogo.tres` di Godot Editor
2. Klik pada Root BTSelector
3. Tambahkan child baru: BTSequence (beri nama "Chase Player")
4. Dalam BTSequence "Chase Player", tambahkan:
   - Script task: `ai/tasks/get_player_location.gd`
   - Script task: `ai/tasks/check_player_in_range.gd`
   - Script task: `ai/tasks/pursue_target.gd`
5. Atur parameter sesuai kebutuhan
6. Save behavior tree

### Menyesuaikan Detection Range:

Untuk mengubah jarak deteksi, edit parameter `detection_range` pada task `check_player_in_range`:
- Nilai kecil (100-150): Frogo hanya mengejar jika player dekat
- Nilai sedang (200-300): Range deteksi normal - **Default: 250px**
- Nilai besar (350+): Frogo dapat mendeteksi player dari sangat jauh

### Menyesuaikan Aggressiveness:

Edit parameter pada task `pursue_target`:

**Speed** (default: 120): Kecepatan Frogo mengejar
  - 80-100: Chase lambat/casual
  - 120-150: Chase agresif (default)
  - 150+: Chase sangat agresif/cepat
  
**Approach Distance** (default: 20): Jarak berhenti dari player
  - 10-20: **Sangat dekat/agresif** (default)
  - 30-50: Dekat tapi masih ada jarak
  - 60+: Mengikuti dari jauh
  
**Max Chase Distance** (default: 300): Jarak maksimal chase sebelum kembali ke idle
  - 200-250: Frogo mudah menyerah, cocok untuk area kecil
  - 300-400: Balanced (default)
  - 500+: Frogo persistent, terus mengejar walau player jauh
  - **TIP**: Set lebih besar dari `detection_range` untuk menghindari Frogo langsung berhenti
  
**Move Animation**: Ganti dengan animasi lain seperti "Attack" jika ingin animasi berbeda saat mengejar

---

## Tips & Troubleshooting

### Frogo tidak mengejar player:
1. Pastikan player ada di group "player" (cek di script player.gd: `add_to_group("player")`)
2. Cek nilai `detection_range` - mungkin terlalu kecil
3. Pastikan behavior tree sudah di-assign ke BTPlayer node di scene Frogo

### Frogo bergerak terlalu lambat/cepat:
- Adjust parameter `speed` di task `pursue_target`
- Default: 120.0 (agresif)
- Turunkan ke 80-100 untuk chase lebih lambat
- Naikkan ke 150-200 untuk chase sangat cepat

### Frogo tidak cukup dekat/terlalu dekat:
- Adjust parameter `approach_distance` di task `pursue_target`
- Default: 20.0 (sangat dekat/agresif)
- Turunkan ke 10-15 untuk lebih dekat lagi
- Naikkan ke 40-60 jika ingin Frogo berhenti lebih jauh

### Frogo mengejar dari terlalu jauh/dekat:
- Adjust parameter `detection_range` di task `check_player_in_range`
- Default: 250.0
- Sesuaikan berdasarkan kebutuhan gameplay

### Frogo terlalu cepat kembali ke idle saat chase:
- Naikkan parameter `max_chase_distance` di task `pursue_target`
- Default: 300.0
- **Rekomendasi**: Set `max_chase_distance` minimal 50px lebih besar dari `detection_range`
- Contoh: `detection_range: 250` → `max_chase_distance: 350`

### Frogo tidak mau berhenti chase (terus mengejar):
- Turunkan parameter `max_chase_distance` di task `pursue_target`
- Ini akan membuat Frogo lebih mudah "menyerah" jika player kabur

### Animasi tidak berjalan:
- Pastikan `animation_player_path` mengarah ke node AnimationPlayer yang benar
- Pastikan nama animasi di `move_animation` sesuai dengan yang ada di AnimationPlayer

---

## Skenario Penggunaan

### Skenario 1: Guard yang Teritorial
Frogo hanya mengejar dalam area terbatas:
- `detection_range`: 150
- `max_chase_distance`: 200
- `speed`: 100

### Skenario 2: Hunter Agresif (Default)
Frogo mengejar dengan agresif tapi masih bisa kabur:
- `detection_range`: 250
- `max_chase_distance`: 300
- `speed`: 120
- `approach_distance`: 20

### Skenario 3: Stalker Persistent
Frogo terus mengejar sampai dapat:
- `detection_range`: 300
- `max_chase_distance`: 600
- `speed`: 130
- `approach_distance`: 30

### Skenario 4: Smart Enemy dengan Flee
Enemy yang kabur saat HP rendah:
```
BTSelector (Root)
├── BTSequence (Flee when Low HP)
│   ├── CheckLowHP (hp_threshold: 0.3)
│   └── FleeFromTarget (flee_speed: 150, safe_distance: 250)
├── BTSequence (Chase Player)
│   ├── GetPlayer (output_var: "target")
│   ├── CheckTargetInArea (target_var: "target")
│   └── PursueTarget (target_var: "target", speed: 120)
└── BTSequence (Idle)
    └── BTRandomWait
```

**Behavior Flow:**
1. Setiap tick, cek apakah HP < 30% DAN tidak dalam cooldown
2. Jika HP rendah & tidak cooldown → Kabur selama 2 detik
3. Setelah flee selesai → Set cooldown 5 detik → Kembali ke chase/idle
4. Selama cooldown, walau HP < 30%, enemy tetap chase/idle
5. Setelah cooldown habis & HP masih < 30% → Flee lagi

