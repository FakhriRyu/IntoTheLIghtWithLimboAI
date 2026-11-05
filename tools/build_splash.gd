extends SceneTree
## Merender gambar boot splash dari scene menu utama, supaya splash dan menu menyambung.
## Jalankan dari folder proyek Godot (bukan headless, perlu jendela):
##   godot --path . --resolution 1067x480 --audio-driver Dummy -s tools/build_splash.gd
## Menghasilkan Assets/menu/boot_splash.png (20:9, tinggi sama dengan viewport game).
## Pada layar lain gambar dipotong oleh stretch mode Cover, jadi isi penting harus
## berada di tengah: area x 213..853 tetap terlihat sampai layar 4:3.
## Juga Assets/menu/android_icon_background.png: latar splash sistem Android 12+
## (tanpa Gradle, warnanya hanya bisa diatur lewat latar ikon adaptif).
const OUTPUT := "res://Assets/menu/boot_splash.png"
const ANDROID_BG_OUTPUT := "res://Assets/menu/android_icon_background.png"
const ANDROID_BG_SIZE := 432
## Sama dengan application/boot_splash/bg_color
const NIGHT := Color(0.039, 0.051, 0.071)
const MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const TITLE_SIZE := 96
const TITLE_TOP := 96.0
const TAGLINE_GAP := 4.0

func _initialize() -> void:
	# Autoload baru _ready setelah _initialize.
	await process_frame
	# Jendela yang tertutup jendela lain berhenti digambar, jadi tangkapan bisa basi.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	# Jangan sampai gambar splash lama ikut terender.
	root.get_node("RunState").boot_splash_pending = false
	var menu: Node = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	# Tunggu intro menu selesai, lalu bersihkan semua yang bukan judul.
	await create_timer(menu.INTRO_TIME + 1.5).timeout
	for path in ["Menu", "Marker", "Hint"]:
		menu.get_node("UI/Root/" + path).visible = false
	_center_labels(menu)
	await _save_frame()
	var android_bg := Image.create_empty(ANDROID_BG_SIZE, ANDROID_BG_SIZE, false, Image.FORMAT_RGB8)
	android_bg.fill(NIGHT)
	android_bg.save_png(ANDROID_BG_OUTPUT)
	quit()


func _center_labels(menu: Node) -> void:
	var width: float = root.get_visible_rect().size.x
	var title: Label = menu.get_node("UI/Root/Title")
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, TITLE_TOP)
	title.size = Vector2(width, title.get_minimum_size().y)
	var tagline: Label = menu.get_node("UI/Root/Subtitle")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.position = Vector2(0.0, TITLE_TOP + title.size.y + TAGLINE_GAP)
	tagline.size = Vector2(width, tagline.get_minimum_size().y)


func _save_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_png(OUTPUT)
	print("SPLASH ", img.get_size(), " err=", err)
