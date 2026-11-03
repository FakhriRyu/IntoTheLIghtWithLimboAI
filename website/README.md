# Landing page Into the Light

Situs statis (HTML + CSS, tanpa build) untuk game Into the Light. Semua gambar, sprite, dan font diambil dari aset game di `Assets/`.

- `index.html`: seluruh halaman.
- `assets/img`: latar parallax menu, panel cutscene, tangkapan layar gameplay.
- `assets/sprites`: lembar sprite horizontal (Fiora, Goblin, Skull Wolf, Norc'Thex, obor) untuk animasi CSS.
- `assets/ui`: tombol, panel kartu, bar HUD, dan ikon upgrade dari game.
- `assets/media/trailer.mp4`: cuplikan cutscene 30 detik.
- `.gdignore`: supaya Godot tidak mengimpor folder ini ke proyek game.

## Mencoba di komputer

Buka `website/index.html` langsung di browser, atau jalankan `python3 -m http.server -d website` lalu buka http://localhost:8000.

## Online lewat GitHub Pages

1. Di GitHub buka **Settings → Pages**, pilih **Source: GitHub Actions**.
2. Setiap push ke `main` yang mengubah `website/` akan menjalankan workflow `.github/workflows/pages.yml`, lalu situs tampil di `https://fakhriryu.github.io/IntoTheLIghtWithLimboAI/`.

## Tombol unduh APK

Tombol "Unduh APK" mengarah ke `releases/latest`. APK (sekitar 114 MB) terlalu besar untuk disimpan di git, jadi unggah lewat **Releases → Draft a new release**, lampirkan file `.apk`, lalu publish.
