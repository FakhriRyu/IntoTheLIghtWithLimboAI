# Naskah Cutscene — Into the Light

Tiga cutscene: **Prolog** (awal game), **Boss Intro** (setelah menyentuh cahaya di puncak tower, sebelum zone_two), dan **Ending** (setelah Norc'Thex dikalahkan).

Setiap shot berisi: durasi perkiraan, visual, gerak kamera, audio, dialog, dan **prompt video** (bahasa Inggris, biasanya lebih akurat untuk generator video). Satu shot ≈ satu klip video (5–10 detik).

> **Aturan misteri:** sebelum foto di rumah sakit (Ending, shot E-23) **tidak boleh ada petunjuk apa pun** bahwa lelaki tua adalah ayah Fiora. Ia tidak punya nama, tidak memanggil "Nak", tidak menyinggung masa kecil Fiora, dan baru menyebut nama Fiora setelah Fiora sendiri menyebutkannya. Kata "Ayah" tidak pernah diucapkan.

---

## Panduan karakter & gaya (tempel di awal setiap prompt agar konsisten)

**Gaya:** `16-bit pixel art, dark fantasy, limited palette of deep blues and purples with warm golden lantern light, cinematic lighting, side-scroller game cutscene`

| Karakter | Deskripsi prompt |
|---|---|
| **Fiora** | `young woman with long wavy orange hair, silver plate armor with gold trim, dark red cape, blue eyes` |
| **Lelaki Tua** | `old man in a worn brown hooded cloak over chainmail, grey beard, kind tired eyes, holding an old brass lantern` |
| **Norc'Thex** | `towering shadow creature with a cracked white bird skull for a head, one glowing teal eye, red markings on the skull, body of black feathers and purple smoke` |
| **Lentera** | `small hexagonal brass lantern with a warm flickering flame` (lentera yang sama muncul di prolog, ending, dan meja rumah sakit) |

---

## CUTSCENE 1 — PROLOG "Dasar Kastil"

**Inti cerita:** Fiora tiba-tiba terbangun di dasar kastil tanpa ingatan. Seorang lelaki tua misterius menemukannya dan memberi petunjuk: naik ke puncak menara untuk tahu kenapa ia kehilangan ingatan.
**Durasi total:** ± 1,5–2 menit

| # | Durasi | Visual & kamera | Audio | Dialog |
|---|---|---|---|---|
| P-01 | 5 dtk | Layar hitam. Garis monitor jantung berwarna teal bergerak pelan, lalu memudar. | bip… bip… (monitor jantung), hujan samar, lalu hening | — |
| P-02 | 4 dtk | Hitam. Satu tetes air jatuh ke genangan. | *tes* | — |
| P-03 | 5 dtk | Close-up mata Fiora perlahan terbuka. Gelap, cahaya biru dingin. | dengung rendah | — |
| P-04 | 6 dtk | Wide: Fiora terbaring di lantai batu dasar kastil yang lembap, dinding berlumut, partikel debu melayang. Kamera turun pelan. | tetesan air | **Fiora:** "Ngh… dingin sekali…" |
| P-05 | 6 dtk | Fiora bangun dan duduk, memegang kepala, menoleh ke sekeliling dengan bingung. | — | **Fiora:** "Di mana aku? Kenapa… aku tidak bisa mengingat apa pun?" |
| P-06 | 6 dtk | Langkah kaki terdengar dulu. Lalu cahaya lentera hangat muncul dari pintu lengkung; lelaki tua bertudung melangkah keluar. Wajahnya setengah tertutup bayangan. | langkah kaki, *klink* lentera | **???:** "Jadi, kau sudah bangun." |
| P-07 | 8 dtk | Two-shot: Fiora (kiri) dan lelaki tua (kanan) berhadapan, diterangi lentera. | — | **Fiora:** "Siapa kau?" <br>**Lelaki Tua:** "Hanya orang tua yang sudah terlalu lama berjaga di tempat ini." |
| P-08 | 8 dtk | Close-up Fiora, ragu dan sedih. | — | **Fiora:** "Aku hanya ingat namaku… Fiora. Selebihnya kosong." |
| P-09 | 7 dtk | Close-up lelaki tua, menatap ke kegelapan sekitar. | — | **Lelaki Tua:** "Dasar kastil ini selalu begitu. Ia mengambil ingatan siapa pun yang jatuh terlalu dalam." |
| P-10 | 6 dtk | Lelaki tua mengangkat tangan dan menunjuk ke atas; Fiora menoleh mengikuti arah tangannya. | — | **Fiora:** "Lalu bagaimana aku mendapatkannya kembali?" <br>**Lelaki Tua:** "Naik." |
| P-11 | 9 dtk | Kamera bergerak naik menyusuri menara batu yang sangat tinggi, dari dasar yang gelap hingga ke puncak, tempat cahaya keemasan kecil bersinar. | *shiiing* lembut di puncak | **Lelaki Tua (VO):** "Di puncak menara itu ada cahaya. Sentuhlah, dan kau akan tahu kenapa kau terbangun di sini tanpa ingatan." |
| P-12 | 6 dtk | Kembali ke two-shot. Fiora melangkah maju; lelaki tua tidak bergerak. | — | **Fiora:** "Kau tidak ikut denganku?" <br>**Lelaki Tua:** "Jalan itu hanya untukmu." |
| P-13 | 6 dtk | Close-up tangan: lelaki tua menyerahkan lentera ke tangan Fiora yang bersarung zirah. Api lentera berkedip. | *klink* | **Lelaki Tua:** "Bawa lentera ini. Tempat ini membenci cahaya." |
| P-14 | 7 dtk | Lelaki tua mundur perlahan ke dalam kegelapan hingga tak terlihat. Fiora berdiri sendiri, lentera di tangan. | langkah menjauh | **Lelaki Tua (dari kegelapan):** "Naiklah, Fiora. Dan jangan menoleh ke bawah." |
| P-15 | 8 dtk | Fiora dari belakang mengangkat lentera, menatap pilar cahaya jauh di atas. Kilat putih → judul **INTO THE LIGHT** (emas) muncul. | musik naik, *sting* | — |

**Transisi:** fade ke putih → gameplay level Tower.

### Prompt video — Prolog
- **P-03:** `[gaya] extreme close-up of Fiora's eyes slowly opening in darkness, cold blue light, water droplets, slow push-in`
- **P-04:** `[gaya] Fiora lying unconscious on a wet stone floor at the bottom of a dark castle dungeon, mossy walls, floating dust particles, slow camera descent`
- **P-05:** `[gaya] Fiora sits up holding her head, looking around confused and frightened, dim dungeon`
- **P-06:** `[gaya] warm lantern light appears from a stone archway, a hooded old man with a grey beard steps out holding a brass lantern, face half in shadow, mysterious`
- **P-07:** `[gaya] two-shot, Fiora and the hooded old man facing each other in a dark dungeon, lit only by his lantern, quiet conversation`
- **P-10:** `[gaya] the old man raises his hand and points upward, Fiora turns her head to look up`
- **P-11:** `[gaya] vertical camera pan up an impossibly tall dark stone tower from the dungeon floor to the top, a small golden light shining at the summit`
- **P-13:** `[gaya] close-up of an old weathered hand handing a glowing brass lantern to an armored gauntlet hand, flame flickering, embers floating`
- **P-14:** `[gaya] the old man slowly steps backward into darkness until he disappears, Fiora stands alone holding the lantern`
- **P-15:** `[gaya] Fiora seen from behind raising her lantern toward a huge beam of golden light at the top of the tower, heroic, rain, light rays`

---

## CUTSCENE 2 — BOSS INTRO "Bisikan di Puncak"

**Inti cerita:** Fiora sampai di puncak tower dan menyentuh cahaya, tapi cahayanya berubah gelap. Norc'Thex muncul dan menghasut Fiora agar tidak kembali ke atas lewat iri, derita, takut, dan putus asa. Fiora tetap melawan, dan pertarungan dimulai.
**Durasi total:** ± 1,5 menit
**Transisi masuk:** dari gameplay, ketika player menyentuh pilar cahaya di puncak tower.

| # | Durasi | Visual & kamera | Audio | Dialog |
|---|---|---|---|---|
| B-01 | 6 dtk | Puncak menara. Fiora, terengah, berjalan ke pilar cahaya keemasan dan mengulurkan tangan. | angin, dengung cahaya | **Fiora:** "Akhirnya… cahaya itu." |
| B-02 | 3 dtk | Ujung jari menyentuh cahaya → kilat putih. | *shiiing* | — |
| B-03 | 6 dtk | Cahaya berkedip lalu berubah ungu. Asap gelap merayap dari lantai dan menelan sekeliling Fiora. Layar bergetar. | gemuruh, cahaya "retak" | **Fiora:** "Apa—?! Cahayanya…" |
| B-04 | 6 dtk | Dari asap, tengkorak burung raksasa muncul perlahan; satu mata teal menyala terbuka. | *krak*, dengung berat | **Norc'Thex:** "Begitu terburu-buru, gadis kecil." |
| B-05 | 5 dtk | Close-up mata Norc'Thex. | — | **Norc'Thex:** "Kau pikir jawaban yang kau cari ada di atas sana?" |
| B-06 | 9 dtk | Fiora jatuh berlutut, asap berputar di sekelilingnya; lenteranya meredup. Kata **"iri…"** muncul samar di asap. Tampak bayangan orang-orang tertawa di kejauhan. | bisikan berlapis | **Norc'Thex (iri):** "Lihat mereka di atas sana. Hidup utuh, tertawa tanpa beban. Kenapa dunia memberi mereka segalanya… dan kau hanya luka?" |
| B-07 | 8 dtk | Asap membentuk serpihan ingatan yang buram dan retak, lalu hancur. Kata **"derita…"** | bisikan | **Norc'Thex (derita):** "Ingatanmu tidak hilang. Kau sendiri yang membuangnya, karena terlalu menyakitkan untuk diingat." |
| B-08 | 7 dtk | Close-up wajah Fiora yang ketakutan; tangannya gemetar. Kata **"takut…"** | detak jantung pelan | **Norc'Thex (takut):** "Naiklah, dan semua rasa sakit itu akan kembali kepadamu. Sekaligus." |
| B-09 | 9 dtk | Asap melingkari Fiora dengan lembut seperti selimut; matanya hampir tertutup. Kata **"putus asa…"** dan **"tidurlah…"** | bisikan memelan | **Norc'Thex (putus asa):** "Di sini sunyi. Tak ada yang menuntut, tak ada yang hilang. Tinggallah… dan tidurlah selamanya." |
| B-10 | 5 dtk | Fiora hampir terpejam, kepalanya tertunduk. | hening | **Fiora:** "(bergetar) Aku… lelah sekali…" |
| B-11 | 4 dtk | Close-up lentera: apinya yang hampir padam tiba-tiba menyala lagi. | *fwoosh* | — |
| B-12 | 8 dtk | Fiora berdiri perlahan. Lentera menyala terang dan mendorong asap menjauh. | musik mulai naik | **Fiora:** "Mungkin kau benar. Mungkin di atas sana memang sakit." |
| B-13 | 8 dtk | Fiora mengangkat kepala dan menatap Norc'Thex lurus. | — | **Fiora:** "Tapi aku tidak mau terus tertidur di tempat yang bahkan tidak kuingat." |
| B-14 | 6 dtk | Fiora menghunus senjata, lentera di tangan satunya. | *sring* | **Fiora:** "Aku akan naik. Dan kau tidak akan menghentikanku." |
| B-15 | 6 dtk | Wide shot: Norc'Thex membentangkan sayap asap, menjulang di atas Fiora. Layar bergetar. | raungan | **Norc'Thex:** "Kalau begitu, akan kuseret kau kembali ke dasar!" |
| B-16 | 4 dtk | Freeze frame. Teks besar **NORC'THEX — Penjaga Limbo**. | *sting* | — |

**Transisi:** potong ke hitam → gameplay zone_two (pertarungan bos).

### Prompt video — Boss Intro
- **B-01:** `[gaya] top of a dark tower at night, exhausted Fiora walks toward a tall pillar of golden light and reaches out her hand`
- **B-03:** `[gaya] the golden light pillar flickers and turns sickly purple, dark smoke crawls across the floor and engulfs everything around Fiora, screen shake`
- **B-04:** `[gaya] a giant cracked white bird skull slowly emerges from purple smoke, a single teal eye ignites, menacing, low angle`
- **B-06:** `[gaya] Fiora falls to her knees surrounded by swirling purple smoke, her lantern dims, ghostly silhouettes of laughing people in the distance`
- **B-07:** `[gaya] purple smoke forms blurry fragments of memories that crack and shatter like glass`
- **B-09:** `[gaya] purple smoke wraps gently around kneeling Fiora like a blanket, her eyes almost closing, hypnotic slow motion`
- **B-11:** `[gaya] extreme close-up of a nearly extinguished lantern flame suddenly flaring bright gold`
- **B-12:** `[gaya] Fiora slowly stands up, her lantern blazes with golden light pushing the purple smoke away, determined`
- **B-15:** `[gaya] wide shot, the bird-skull shadow creature Norc'Thex spreads enormous wings of smoke and towers over Fiora who stands ready with sword and lantern, boss battle begins`

---

## CUTSCENE 3 — ENDING "Ke Dalam Cahaya"

**Inti cerita:** Norc'Thex kalah. Lelaki tua datang lagi; ia bangga dan mengucapkan kata-kata yang mengharukan. Fiora mulai melayang ke langit dan ingin meraih tangan lelaki tua untuk mengajaknya ikut naik, tapi lelaki tua menolak dan tangannya tidak bisa dipegang. Fiora terbang sendiri, lalu terbangun di rumah sakit: ternyata selama ini ia koma. Di meja ada foto Fiora kecil bersama ayahnya, dan wajah sang ayah adalah wajah lelaki tua itu saat masih muda.
**Durasi total:** ± 3 menit

| # | Durasi | Visual & kamera | Audio | Dialog |
|---|---|---|---|---|
| E-01 | 6 dtk | Tengkorak Norc'Thex retak dari mata hingga ke paruh, lalu luruh menjadi bulu hitam dan asap. Layar bergetar. | *krak… krak*, gemuruh memudar | — |
| E-02 | 5 dtk | Fiora berlutut dengan satu kaki, terengah, menatap sisa asap. | napas berat | **Fiora:** "Sudah… berakhir?" |
| E-03 | 6 dtk | Kabut ungu menghilang perlahan; cahaya hangat keemasan memenuhi puncak menara. | angin tenang, musik lembut | — |
| E-04 | 6 dtk | Langkah kaki terdengar. Lelaki tua muncul dari cahaya, tudungnya terbuka dan wajahnya tersenyum. | langkah kaki, *klink* lentera | **Fiora:** "Kau…!" |
| E-05 | 6 dtk | Close-up lelaki tua tersenyum. | — | **Lelaki Tua:** "Kau berhasil, Fiora." |
| E-06 | 8 dtk | Two-shot; lelaki tua menatap Fiora dengan mata berkaca-kaca. | — | **Lelaki Tua:** "Aku melihat semuanya. Setiap kali kau jatuh, dan setiap kali kau bangkit lagi." |
| E-07 | 5 dtk | Close-up lelaki tua. | — | **Lelaki Tua:** "Aku bangga padamu. Sungguh." |
| E-08 | 7 dtk | Close-up Fiora, tersenyum haru. | — | **Fiora:** "Kalau bukan karena petunjukmu, aku pasti masih terbaring di bawah sana." |
| E-09 | 7 dtk | Lelaki tua menggeleng pelan. | — | **Lelaki Tua:** "Tidak. Kau sendiri yang memilih untuk bangun. Aku hanya menunjukkan jalannya." |
| E-10 | 6 dtk | Partikel cahaya naik dari kaki Fiora; tubuhnya perlahan terangkat dari lantai. | denting lembut | **Fiora:** "Eh? Tubuhku… melayang?" |
| E-11 | 5 dtk | Lelaki tua menatap ke atas sambil tersenyum. | — | **Lelaki Tua:** "Sudah waktunya kau pulang." |
| E-12 | 7 dtk | Fiora, masih melayang, mengulurkan tangan ke bawah ke arah lelaki tua. | — | **Fiora:** "Kalau begitu ikutlah! Pegang tanganku, kita naik bersama!" |
| E-13 | 7 dtk | Lelaki tua tersenyum dan menggeleng pelan; tangannya tetap di sisi tubuhnya. | — | **Lelaki Tua:** "Tidak bisa. Jalanku berakhir di sini." |
| E-14 | 7 dtk | Close-up tangan (komposisi cermin P-13): Fiora meraih tangan lelaki tua, tapi tangannya **menembus** tangan itu seperti cahaya. Tangan lelaki tua tampak transparan. | denting rapuh | **Fiora:** "Kenapa…? Kenapa aku tidak bisa memegangmu?!" |
| E-15 | 8 dtk | Close-up Fiora menangis. Lelaki tua menatapnya dengan lembut. | — | **Lelaki Tua:** "Jangan menangis. Kau sudah membuktikan bahwa kau bisa naik sendiri." |
| E-16 | 6 dtk | Lelaki tua mundur selangkah dan melambai pelan. | musik memuncak | **Lelaki Tua:** "Pergilah. Hiduplah dengan baik." |
| E-17 | 9 dtk | Kamera mengikuti Fiora naik ke langit yang terang. Di bawah, lelaki tua semakin kecil, masih menatap ke atas. Fiora berteriak ke bawah. | angin, musik | **Fiora:** "Tunggu! Aku bahkan belum tahu namamu—!" |
| E-18 | 4 dtk | Layar memutih penuh. | hening | — |
| E-19 | 6 dtk | Hitam. Bunyi monitor jantung (bip… bip…, sama seperti P-01), hujan di jendela. | bip, hujan | **Perawat (suara):** "…Fiora? Fiora, kau dengar aku?" |
| E-20 | 6 dtk | Wide: kamar rumah sakit yang redup, hujan di jendela, Fiora terbaring di ranjang dengan infus dan monitor jantung. | bip, hujan | — |
| E-21 | 6 dtk | POV: mata terbuka, langit-langit rumah sakit yang buram perlahan menjadi jelas. | langkah tergesa | **Perawat (suara):** "Dia sadar! Panggil dokter… setelah berbulan-bulan koma…" |
| E-22 | 5 dtk | Fiora menoleh ke sekeliling kamar. Tidak ada siapa-siapa. | — | **Fiora:** "…Di mana dia?" |
| E-23 | 9 dtk | Pandangan Fiora jatuh ke meja samping ranjang. Kamera mendekat pelan ke sebuah **foto berbingkai**: Fiora kecil tertawa di pundak seorang pria. Wajah pria itu adalah lelaki tua versi muda (mata sama, janggut masih gelap). Di sebelah foto ada **lentera kuningan kecil** yang sama. | hujan mereda, musik piano | — (tanpa dialog) |
| E-24 | 8 dtk | Fiora memeluk foto itu di dadanya. Air mata mengalir, tapi ia tersenyum. Cahaya pagi masuk dari jendela. | — | **Fiora:** "…Terima kasih." |
| E-25 | 8 dtk | Fade ke hitam → judul **INTO THE LIGHT** → **TAMAT**. | musik penutup | — |

**Transisi:** kembali ke main menu (statistik run bisa tetap ditampilkan di game setelah video).

### Prompt video — Ending
- **E-01:** `[gaya] a giant cracked bird skull shatters from the eye down and dissolves into black feathers and purple smoke, screen shake`
- **E-03:** `[gaya] purple fog slowly clears from the top of the tower, warm golden light fills the scene, peaceful`
- **E-04:** `[gaya] the old man walks out of a warm golden light, hood lowered, gentle smile, holding his brass lantern`
- **E-06:** `[gaya] two-shot, the old man looks at Fiora with proud teary eyes, golden light, emotional`
- **E-10:** `[gaya] glowing particles rise from Fiora's feet as she slowly begins to float off the ground, surprised`
- **E-12:** `[gaya] Fiora floating in the air reaches her hand down toward the old man standing below`
- **E-14:** `[gaya] close-up, Fiora's armored hand tries to grab the old man's hand but passes through it like light, his hand is translucent and glowing, sparkles`
- **E-16:** `[gaya] the old man steps back and waves gently, smiling, golden light behind him`
- **E-17:** `[gaya] Fiora rises alone into a bright sky full of light, camera follows her upward, far below the tiny old man still looking up`
- **E-20:** `[gaya] dim hospital room on a rainy night, rain on the window, a young orange-haired woman lying in bed with IV drip and heart monitor`
- **E-21:** `[gaya] first-person view, eyes opening, a blurry hospital ceiling slowly coming into focus`
- **E-23:** `[gaya] slow push-in on a bedside table: a framed photo of a laughing little orange-haired girl on the shoulders of a smiling bearded man in his thirties (the same face as the old man, but younger, with a dark beard), next to a small brass lantern`
- **E-24:** `[gaya] the young woman sitting in a hospital bed hugs the framed photo to her chest, tears and a gentle smile, soft morning sunlight through the window`

---

## Daftar dialog lengkap (untuk subtitle / voice over)

**Prolog**
1. Fiora: Ngh… dingin sekali…
2. Fiora: Di mana aku? Kenapa… aku tidak bisa mengingat apa pun?
3. ???: Jadi, kau sudah bangun.
4. Fiora: Siapa kau?
5. Lelaki Tua: Hanya orang tua yang sudah terlalu lama berjaga di tempat ini.
6. Fiora: Aku hanya ingat namaku… Fiora. Selebihnya kosong.
7. Lelaki Tua: Dasar kastil ini selalu begitu. Ia mengambil ingatan siapa pun yang jatuh terlalu dalam.
8. Fiora: Lalu bagaimana aku mendapatkannya kembali?
9. Lelaki Tua: Naik.
10. Lelaki Tua: Di puncak menara itu ada cahaya. Sentuhlah, dan kau akan tahu kenapa kau terbangun di sini tanpa ingatan.
11. Fiora: Kau tidak ikut denganku?
12. Lelaki Tua: Jalan itu hanya untukmu.
13. Lelaki Tua: Bawa lentera ini. Tempat ini membenci cahaya.
14. Lelaki Tua: Naiklah, Fiora. Dan jangan menoleh ke bawah.

**Boss Intro**
1. Fiora: Akhirnya… cahaya itu.
2. Fiora: Apa—?! Cahayanya…
3. Norc'Thex: Begitu terburu-buru, gadis kecil.
4. Norc'Thex: Kau pikir jawaban yang kau cari ada di atas sana?
5. Norc'Thex: Lihat mereka di atas sana. Hidup utuh, tertawa tanpa beban. Kenapa dunia memberi mereka segalanya… dan kau hanya luka?
6. Norc'Thex: Ingatanmu tidak hilang. Kau sendiri yang membuangnya, karena terlalu menyakitkan untuk diingat.
7. Norc'Thex: Naiklah, dan semua rasa sakit itu akan kembali kepadamu. Sekaligus.
8. Norc'Thex: Di sini sunyi. Tak ada yang menuntut, tak ada yang hilang. Tinggallah… dan tidurlah selamanya.
9. Fiora: Aku… lelah sekali…
10. Fiora: Mungkin kau benar. Mungkin di atas sana memang sakit.
11. Fiora: Tapi aku tidak mau terus tertidur di tempat yang bahkan tidak kuingat.
12. Fiora: Aku akan naik. Dan kau tidak akan menghentikanku.
13. Norc'Thex: Kalau begitu, akan kuseret kau kembali ke dasar!

**Ending**
1. Fiora: Sudah… berakhir?
2. Fiora: Kau…!
3. Lelaki Tua: Kau berhasil, Fiora.
4. Lelaki Tua: Aku melihat semuanya. Setiap kali kau jatuh, dan setiap kali kau bangkit lagi.
5. Lelaki Tua: Aku bangga padamu. Sungguh.
6. Fiora: Kalau bukan karena petunjukmu, aku pasti masih terbaring di bawah sana.
7. Lelaki Tua: Tidak. Kau sendiri yang memilih untuk bangun. Aku hanya menunjukkan jalannya.
8. Fiora: Eh? Tubuhku… melayang?
9. Lelaki Tua: Sudah waktunya kau pulang.
10. Fiora: Kalau begitu ikutlah! Pegang tanganku, kita naik bersama!
11. Lelaki Tua: Tidak bisa. Jalanku berakhir di sini.
12. Fiora: Kenapa…? Kenapa aku tidak bisa memegangmu?!
13. Lelaki Tua: Jangan menangis. Kau sudah membuktikan bahwa kau bisa naik sendiri.
14. Lelaki Tua: Pergilah. Hiduplah dengan baik.
15. Fiora: Tunggu! Aku bahkan belum tahu namamu—!
16. Perawat: …Fiora? Fiora, kau dengar aku?
17. Perawat: Dia sadar! Panggil dokter… setelah berbulan-bulan koma…
18. Fiora: …Di mana dia?
19. Fiora: …Terima kasih.
