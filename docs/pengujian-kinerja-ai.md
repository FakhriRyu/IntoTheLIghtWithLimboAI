# Pengujian Kinerja AI Musuh

Scene `Scenes/Benchmark/ai_benchmark.tscn` mengukur biaya komputasi AI tiap musuh
untuk menjawab rumusan masalah no. 2 (kinerja Behavior Tree dan Finite State Machine).

## Yang dibandingkan

| Varian (`--variants`) | Musuh | Metode | Catatan |
|---|---|---|---|
| `wolf_bt` | Skull Wolf | BT (BTPlayer) | Versi yang dipakai di game |
| `wolf_fsm` | Skull Wolf | FSM (LimboHSM) | Versi pembanding, aset dan fisika sama |
| `goblin_fsm` | Goblin | FSM (LimboHSM) | |
| `norcthex_p1` | Norc'Thex fase 1 | Hibrida: LimboHSM + BTState | Bos dibangunkan dengan 1 damage |
| `norcthex_p2` | Norc'Thex fase 2 | Hibrida: LimboHSM + BTState | HP diturunkan di bawah 50% lewat jalur damage biasa, pengukuran dimulai setelah masuk Phase2 |

Bos dibatasi 1 instance (`--boss-max`), karena di game hanya ada satu.

## Cara kerja

1. Arena datar 1600 px dengan lantai dan dua dinding. Sebuah **target pengganti player**
   (`Scripts/Benchmark/bench_target.gd`) berjalan bolak-balik 60 px/detik di tengah arena
   dan melompat tiap 3 detik. Target ini tidak punya HurtBox, jadi serangan musuh tidak
   melukai apa pun dan kondisi uji sama untuk semua varian.
2. N musuh dimunculkan merata selebar 600 px di sekitar target, sehingga hampir semua
   musuh terus mendeteksi, mengejar, dan menyerang.
3. `update_mode` BTPlayer / LimboHSM tiap musuh diubah ke **MANUAL** sebelum masuk scene.
   Scene benchmark lalu memanggil `update(delta)` sendiri setiap physics frame (60 Hz),
   diapit `Time.get_ticks_usec()`. Itulah **waktu CPU AI per musuh per tick**: evaluasi
   pohon/state ditambah aksi di dalam task/state. Fisika (`move_and_slide`) dan animasi
   tidak termasuk, karena keduanya sama pada BT dan FSM. Overhead pemanggilan timer
   diukur di awal dan dikurangkan dari setiap sampel.
4. Tiap run: pemanasan (default 2 dtk), lalu pengukuran (default 10 dtk), lalu musuh
   dihapus. Setiap kombinasi varian dan N diulang (default 3 kali) dengan seed acak
   yang sama antar varian.

## Menjalankan

Dari editor: buka `Scenes/Benchmark/ai_benchmark.tscn`, atur properti di Inspector bila
perlu, lalu tekan **F6** (Run Current Scene). Progres tampil di pojok kiri atas.

Dari terminal tanpa jendela (lebih stabil untuk waktu CPU AI):

```bash
godot --headless --path . res://Scenes/Benchmark/ai_benchmark.tscn -- \
    --variants=wolf_bt,wolf_fsm,goblin_fsm,norcthex_p1,norcthex_p2 \
    --counts=1,10,50,100 --warmup=2 --duration=10 --reps=3
```

Di macOS, `godot` adalah `/Applications/Godot.app/Contents/MacOS/Godot`.

| Opsi | Default | Arti |
|---|---|---|
| `--variants=` | semua | Daftar varian, dipisah koma |
| `--counts=` | `1,10,50,100` | Jumlah musuh per run |
| `--boss-max=` | `1` | Batas jumlah Norc'Thex |
| `--warmup=` | `2` | Detik pemanasan sebelum mengukur |
| `--duration=` | `10` | Detik pengukuran |
| `--reps=` | `3` | Ulangan per kombinasi |
| `--seed=` | `12345` | Seed acak (ditambah nomor ulangan) |
| `--raw` | mati | Simpan juga data mentah per tick |
| `--quit` | otomatis saat headless | Keluar setelah selesai |

## Hasil

File ditulis ke folder data pengguna Godot, `user://ai_benchmark/`
(macOS: `~/Library/Application Support/Godot/app_userdata/IntoTheLightLIMBO/ai_benchmark/`).
Lokasi lengkapnya dicetak di akhir run.

`ringkasan_<waktu>.csv` berisi satu baris per run. Baris pertama (diawali `#`) mencatat
versi Godot, CPU, OS, dan jenis build.

| Kolom | Arti |
|---|---|
| `ai_us_per_musuh_mean/median/p95/p99/max` | Waktu CPU satu kali update AI satu musuh (mikrodetik) |
| `ai_ms_per_tick_total_mean/p95` | Total waktu AI semua musuh dalam satu physics tick (milidetik) |
| `physics_ms_mean/p95` | Waktu seluruh physics step (termasuk AI dan `move_and_slide`) |
| `process_ms_mean`, `frame_ms_mean/p95/max`, `fps_mean/min` | Waktu frame dan FPS |
| `memori_kb_per_musuh` | Kenaikan memori statis setelah memunculkan musuh, dibagi N |
| `memori_puncak_mb` | Puncak memori statis sejak program jalan |
| `node_per_musuh`, `objek_per_musuh` | Tambahan node/objek per musuh |
| `gerak_px_per_s_mean` | Rata-rata kecepatan horizontal musuh: bukti AI aktif. Norc'Thex berpindah dengan teleport, jadi nilainya bisa 0 |
| `tick_ai`, `musuh_hidup_akhir` | Jumlah tick yang terukur dan musuh yang masih hidup di akhir |

## Hal yang perlu diperhatikan saat menulis Bab 4

- **Kesetaraan perilaku.** Skull Wolf FSM saat ini hanya punya Idle, Chase, Hurt, Dead,
  sedangkan versi BT punya Flee, Attack (terkaman), Chase, Hold, Chill. Selisih waktu
  sebagian berasal dari perilaku yang lebih banyak, bukan hanya dari metodenya.
- **`print()` di state FSM.** State Idle dan Chase Skull Wolf FSM mencetak teks setiap
  kali masuk state. `print` relatif mahal dan ikut terukur sebagai waktu AI FSM.
- **Resolusi timer 1 mikrodetik.** Satu sampel per musuh dibulatkan ke mikrodetik, jadi
  median/p95 tampak berkelompok (mis. 8,91). Rata-rata dari ribuan sampel tetap teliti.
- **Jalankan dengan N yang sama** saat membandingkan. Waktu per musuh pada N=1 cenderung
  lebih tinggi (cache CPU dingin, overhead per frame dibagi satu musuh).
- **FPS saat `--headless`** tertahan di sekitar 145 fps dan tidak mencerminkan
  rendering. Untuk FPS dan waktu frame, jalankan dari editor atau build ekspor di perangkat
  target. Waktu CPU AI dan waktu fisika tetap valid saat headless.
- **Memori statis** paling andal diukur dari editor atau build debug; puncak memori
  bisa bernilai 0 pada build release.
- Tutup aplikasi lain dan colokkan charger saat mengukur, lalu laporkan spesifikasi
  perangkat (baris pertama CSV).
