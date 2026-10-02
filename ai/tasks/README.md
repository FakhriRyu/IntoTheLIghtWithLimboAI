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

### 7. check_distance_to_target.gd
**Type:** BTCondition  
**Fungsi:** Mengecek apakah jarak agent ke target berada dalam rentang tertentu. Dipakai untuk memisahkan jurus berdasarkan pita jarak (mis. trap untuk jarak dekat, panah untuk jarak jauh).

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target (default: "target")
- `min_distance` (float): Jarak minimal, inklusif. 0 = tanpa batas bawah (default: 0.0)
- `max_distance` (float): Jarak maksimal, inklusif. 0 = tanpa batas atas (default: 0.0)

**Returns:**
- `SUCCESS`: Jika jarak berada di antara `min_distance` dan `max_distance`
- `FAILURE`: Jika target tidak valid atau jarak di luar rentang

---

### 8. check_cooldown.gd
**Type:** BTCondition  
**Fungsi:** Mengecek apakah cooldown sebuah jurus sudah selesai. Cooldown disimpan di blackboard sebagai timestamp absolut (detik), ditulis oleh `animated_attack.gd` atau `blink_away.gd`. Pasangkan di dalam Sequence sebelum task serangannya.

**Parameters:**
- `cooldown_var` (StringName): Variable blackboard berisi waktu cooldown berakhir (default: "cooldown_end")

**Returns:**
- `SUCCESS`: Jika variable belum pernah diset, atau waktunya sudah lewat
- `FAILURE`: Jika masih dalam masa cooldown

---

### 9. face_target.gd
**Type:** BTAction  
**Fungsi:** Menghadapkan agent ke arah target tanpa memindahkan posisinya. Dipakai musuh yang menyerang dari tempat (mis. boss ranged) supaya proyektilnya tidak terbang ke arah yang salah. Memanggil `agent.update_facing(direction)`, dengan fallback membalik `$Sprite2D` jika method itu tidak ada.

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target (default: "target")

**Returns:**
- `SUCCESS`: Jika target valid dan arah hadap sudah diupdate
- `FAILURE`: Jika target tidak valid

---

### 10. animated_attack.gd
**Type:** BTAction  
**Fungsi:** Memainkan animasi serangan lalu memanggil sebuah method pada agent tepat di detik tertentu, sehingga proyektil/trap muncul di **tengah** animasi, bukan di akhirnya. Cara ini tidak memerlukan call-method track di AnimationPlayer. Satu task ini dipakai ulang untuk beberapa jurus berbeda cukup dengan mengganti parameternya.

Opsional, task ini juga bisa memanggil method kedua lebih dulu (`telegraph_method`) untuk memunculkan indikator peringatan, sehingga player punya waktu untuk menghindar sebelum serangan dilepas.

**Parameters:**
- `animation_player_path` (NodePath): Path ke AnimationPlayer agent (default: "AnimationPlayer")
- `animation` (StringName): Nama animasi serangan yang dimainkan
- `attack_method` (StringName): Nama method pada agent yang dipanggil saat serangan dilepas (mis. "shoot_arrow", "spawn_trap")
- `fire_time` (float): Detik ke berapa sejak animasi mulai, method serangan dipanggil (default: 0.0)
- `telegraph_method` (StringName): Nama method pada agent untuk memunculkan indikator peringatan, opsional (mis. "show_arrow_warning"). Dipanggil dengan satu argumen: jeda (detik) sampai serangan dilepas
- `telegraph_time` (float): Detik ke berapa indikator peringatan dimunculkan, biasanya 0.0 = awal animasi (default: 0.0)
- `duration` (float): Durasi total task. 0 = pakai panjang animasi (default: 0.0)
- `cooldown_duration` (float): Durasi cooldown setelah serangan selesai. 0 = tanpa cooldown (default: 0.0)
- `cooldown_var` (StringName): Variable blackboard untuk menyimpan waktu cooldown berakhir (default: "attack_cooldown_end")

**Returns:**
- `RUNNING`: Selama animasi berjalan
- `SUCCESS`: Setelah durasi selesai (dan cooldown diset)
- `FAILURE`: Jika AnimationPlayer atau animasinya tidak ditemukan

---

### 11. blink_away.gd
**Type:** BTAction  
**Fungsi:** Menghilang lalu muncul kembali di **titik acak yang aman** di arena (blink/teleport). Dibuat untuk musuh yang **tidak punya animasi jalan** tapi tetap perlu berpindah posisi. Urutannya: animasi menghilang ➜ pilih titik & pindah ➜ animasi muncul ➜ set cooldown. Ketinggian (`y`) dipertahankan supaya agent tetap berpijak di lantai setinggi sekarang.

**Cara memilih titik:** seluruh arena dipindai tiap `scan_step` piksel. Titik dijadikan kandidat kalau jaraknya ke target ada di antara `min_distance`..`max_distance`, cukup jauh dari posisi sekarang (`min_travel`), dan **aman**. Lalu satu kandidat dipilih **acak berbobot**: bisa mundur, maju melewati target, atau ke sisi lain arena.
- Titik dengan jalur tembak bersih ke target lebih sering terpilih (`clear_shot_weight`). Dicek lewat `agent.has_line_of_fire_from(pos)` kalau ada.
- Titik di dekat blink terakhir peluangnya dikurangi (`recent_*`), jadi agent tidak bolak-balik ke tempat yang sama.
- `require_clear_shot` mewajibkan jalur tembak bersih (untuk blink yang tujuannya menembak). Kalau tidak ada titik yang memenuhi, syaratnya dilonggarkan bertahap: sisi mana pun untuk mode sergap, lalu tanpa syarat jalur tembak. Kalau tetap tidak ada, agent muncul lagi di tempat semula.

**Titik aman** = badan agent muat di sana (cek `intersect_shape` dengan collision shape agent: tidak masuk ke dalam tembok/ledge), ada ruang kosong di atas kepala (`headroom`) dan di kiri-kanan badan (`elbow_room`, supaya tidak terjepit di ceruk sempit), serta ada lantai selebar pijakan tepat di bawah kaki (raycast memakai `collision_mask` agent sendiri, maksimal `max_drop` di bawah kaki).

Selama task ini berjalan, agent ditandai **tidak bisa dihentikan** lewat `agent.set_uninterruptible(true)` (dipanggil di `_enter`, dimatikan lagi di `_exit`). Agent tetap menerima damage, tapi tidak boleh membatalkan blink. Ini yang mencegah player mengunci musuh dengan serangan beruntun.

**Parameters:**
- `target_var` (StringName): Variable blackboard yang menyimpan target (default: "target")
- `animation_player_path` (NodePath): Path ke AnimationPlayer agent (default: "AnimationPlayer")
- `out_animation` / `in_animation` (StringName): Animasi menghilang / muncul (default: "fadeaway" / "fadein")
- `min_distance` / `max_distance` (float): Rentang jarak horizontal titik tujuan dari target (default: 160 / 480)
- `min_travel` (float): Jarak minimal dari posisi agent sekarang (default: 96)
- `land_behind_target` (bool): Hanya muncul di sisi seberang target, untuk menyergap dari belakang (default: false)
- `cooldown_duration` (float) / `cooldown_var` (StringName): Cooldown setelah blink (default: 5.0 / "blink_cooldown_end")
- `arena_area_path` (NodePath): Area2D penanda lebar arena. Batasnya direkam sekali saat setup, jadi tidak ikut bergeser saat agent berpindah (default: "DetectionAreaBoss")
- `scan_step` (float): Jarak antar titik yang dipindai (default: 8)
- `clear_shot_weight` (float): Pengali peluang titik yang punya jalur tembak bersih (default: 4)
- `require_clear_shot` (bool): Wajibkan jalur tembak bersih (default: false)
- `recent_count` / `recent_radius` / `recent_weight`: Berapa titik terakhir diingat, radius, dan pengali peluangnya (default: 3 / 64 / 0.15)
- `max_drop` (float): Jarak maksimal lantai di bawah kaki (default: 24)
- `foothold_half_width` (float): Setengah lebar pijakan yang wajib ada lantainya (default: 12)
- `headroom` (float): Ruang kosong wajib di atas badan (default: 24)
- `elbow_room` (float): Ruang kosong wajib di kiri dan kanan badan (default: 32)

**Returns:**
- `RUNNING`: Selama proses blink berlangsung
- `SUCCESS`: Setelah animasi muncul selesai (dan cooldown diset)
- `FAILURE`: Jika target tidak valid atau animasinya tidak ditemukan

---

### 12. check_line_of_fire.gd
**Type:** BTCondition  
**Fungsi:** Mengecek apakah agent punya jalur tembak bersih ke target dengan memanggil method bool milik agent (default `has_line_of_fire`). Pada Norc'Thex method itu mengecek sudut bidikan (maks. `max_aim_angle_deg`) dan melakukan raycast ke layer world, sehingga bos tidak lagi menembaki dinding. Bungkus dengan `BTInvert` untuk branch "tidak ada jalur tembak" (pasang trap / reposition).

**Parameters:**
- `check_method` (StringName): Nama method pada agent yang mengembalikan bool (default: "has_line_of_fire")

**Returns:**
- `SUCCESS`: Jika jalur tembak bersih
- `FAILURE`: Jika terhalang tembok, sudut terlalu curam, atau method tidak ada

---

### 13. consume_agent_flag.gd
**Type:** BTCondition  
**Fungsi:** Mengecek properti bool milik agent lalu langsung mematikannya (sekali pakai). Dipakai supaya kejadian di luar tree, mis. state HSM `Stagger` Norc'Thex yang menyalakan `panic_requested`, bisa memicu satu branch tepat satu kali tanpa bergantung pada scope blackboard antar `BTState`.

**Parameters:**
- `flag` (StringName): Nama properti bool pada agent

**Returns:**
- `SUCCESS`: Jika flag bernilai true (flag lalu diset false)
- `FAILURE`: Jika flag false atau tidak ada

---

## Norc'Thex: LimboHSM + Behavior Tree

Norc'Thex memakai `LimboHSM` untuk mode bos, dan behavior tree (lewat node `BTState`) untuk memilih jurus di tiap fase:

```
LimboHSM
├── Dormant     menunggu player masuk arena, meraung        ─engage─▶ Phase1
├── Phase1      BTState: ai/trees/norcthex.tres             ─stagger─▶ Stagger, ─phase_shift─▶ PhaseShift
├── PhaseShift  HP ≤ 50%: meraung + trap, tidak bisa disela ─phase_done─▶ Phase2
├── Phase2      BTState: ai/trees/norcthex_phase2.tres      ─stagger─▶ Stagger
├── Stagger     poise habis (3 pukulan beruntun): knockback ─recover_p1/p2─▶ Phase1/Phase2 (+Panic Blink)
└── Dead        (ANYSTATE ─die─▶)
```

Fase 1: Panic Blink, Trap (dekat), Aimed Shot (perlu line of fire), Trap saat tidak ada line of fire, Keep Distance, Reposition, Idle.
Fase 2: Panic Blink, Blink Ambush, `BTProbabilitySelector` (Volley 3 panah + reload, Aimed Shot, Trap ×5), Keep Distance, Reposition, Idle.

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

