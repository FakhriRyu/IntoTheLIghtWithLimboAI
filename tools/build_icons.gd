extends SceneTree
## Membuat ikon Android dari logo game, dengan skala bilangan bulat supaya pixel tetap tajam.
## Jalankan dari folder proyek Godot:
##   godot --headless --path . -s tools/build_icons.gd
## Logo berukuran 85x85 pixel asli yang diperbesar 8x.
const SOURCE := "res://Assets/menu/game_logo.png"
const SOURCE_CELL := 8
const OUTPUT_DIR := "res://Assets/menu/"
const MAIN_SIZE := 192
const MAIN_SCALE := 2
## Ikon adaptif: 3x = 255 px, masih di dalam zona aman 264 px dari kanvas 432 px.
const ADAPTIVE_SIZE := 432
const ADAPTIVE_SCALE := 3
## Themed icon Android 13+ hanya memakai alpha: pixel seterang ini ke atas yang tampil.
const MONOCHROME_MIN_LUMINANCE := 0.45


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	source.convert(Image.FORMAT_RGBA8)
	var logo := _native_pixels(source)
	_save_icon(logo, MAIN_SIZE, MAIN_SCALE, "android_icon_main.png")
	_save_icon(logo, ADAPTIVE_SIZE, ADAPTIVE_SCALE, "android_icon_foreground.png")
	_save_icon(_monochrome(logo), ADAPTIVE_SIZE, ADAPTIVE_SCALE, "android_icon_monochrome.png")
	quit()


func _native_pixels(source: Image) -> Image:
	var size := source.get_width() / SOURCE_CELL
	var native := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var center := SOURCE_CELL / 2
			native.set_pixel(x, y, source.get_pixel(x * SOURCE_CELL + center, y * SOURCE_CELL + center))
	return native


func _monochrome(logo: Image) -> Image:
	var mono := Image.create_empty(logo.get_width(), logo.get_height(), false, Image.FORMAT_RGBA8)
	for y in logo.get_height():
		for x in logo.get_width():
			var c := logo.get_pixel(x, y)
			if c.a > 0.5 and c.get_luminance() >= MONOCHROME_MIN_LUMINANCE:
				mono.set_pixel(x, y, Color.WHITE)
	return mono


func _save_icon(logo: Image, canvas_size: int, pixel_scale: int, file_name: String) -> void:
	var scaled := logo.duplicate() as Image
	scaled.resize(logo.get_width() * pixel_scale, logo.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create_empty(canvas_size, canvas_size, false, Image.FORMAT_RGBA8)
	var offset := (canvas_size - scaled.get_width()) / 2
	canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i(offset, offset))
	var err := canvas.save_png(OUTPUT_DIR + file_name)
	print(file_name, " ", canvas.get_size(), " err=", err)
