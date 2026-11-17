class_name LayarTangkap
extends Control

# =====================================================================
# LAYAR SETELAH KETANGKAP: 5 hati, 1 hati redup tiap ketangkap.
# Hati habis -> tulisan beda & progres diulang dari awal.
# Butuh Godot 4.1+ (pakai static var, jadi TIDAK perlu autoload baru).
# =====================================================================

const MAKS_NYAWA := 5
const SCENE_LAYAR := "res://scenes/layar_tangkap.tscn"   # ubah kalau file .tscn dipindah folder

static var jumlah_tertangkap := 0
static var scene_kembali := "res://scenes/main-map/main.tscn"   # scene gameplay yang dimuat lagi saat "Lanjut"
static var scene_awal := ""      # kosong = pakai Main Scene dari Project Settings


# Dipanggil dari player.gd setelah ketangkap
static func pindah_ke_layar(tree: SceneTree) -> void:
	jumlah_tertangkap += 1
	if tree.current_scene:
		scene_kembali = tree.current_scene.scene_file_path
	tree.change_scene_to_file(SCENE_LAYAR)


# Mengulang progres dari awal (dipanggil saat semua hati habis)
static func reset_progress() -> void:
	jumlah_tertangkap = 0
	GameManager.hit_guru_count = 0
	# TODO: reset progres lain di sini (kunci, item, dll) kalau ada


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var habis := jumlah_tertangkap >= MAKS_NYAWA

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	# judul
	var judul := _buat_label("NYAWA HABIS" if habis else "Kamu tertangkap!", 44)
	box.add_child(judul)

	# 5 hati (dari kanan yang redup duluan)
	var baris := HBoxContainer.new()
	baris.alignment = BoxContainer.ALIGNMENT_CENTER
	baris.add_theme_constant_override("separation", 16)
	box.add_child(baris)
	var sisa := MAKS_NYAWA - jumlah_tertangkap
	for i in MAKS_NYAWA:
		baris.add_child(Heart.new(i < sisa))

	# teks 1/5, 2/5, ...
	box.add_child(_buat_label("%d/%d" % [jumlah_tertangkap, MAKS_NYAWA], 36))

	# pesan
	var pesan_teks := "Semua nyawa habis. Progres akan diulang dari awal." if habis \
		else "Hati-hati, guru masih berkeliaran."
	var pesan := _buat_label(pesan_teks, 22)
	pesan.custom_minimum_size.x = 600
	pesan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pesan.modulate = Color(1, 1, 1, 0.75)
	box.add_child(pesan)

	# tombol
	var tombol := Button.new()
	tombol.text = "Mulai dari awal" if habis else "Lanjut"
	tombol.custom_minimum_size = Vector2(260, 56)
	tombol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tombol.add_theme_font_size_override("font_size", 24)
	tombol.pressed.connect(_on_tombol_pressed)
	box.add_child(tombol)
	tombol.grab_focus()


func _buat_label(teks: String, ukuran: int) -> Label:
	var l := Label.new()
	l.text = teks
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", ukuran)
	return l


func _on_tombol_pressed() -> void:
	if jumlah_tertangkap >= MAKS_NYAWA:
		reset_progress()
		var tujuan: String = scene_awal
		if tujuan == "":
			tujuan = str(ProjectSettings.get_setting("application/run/main_scene"))
		get_tree().change_scene_to_file(tujuan)
	else:
		get_tree().change_scene_to_file(scene_kembali)


# Hati digambar pakai kode (tanpa gambar/asset)
class Heart extends Control:
	var menyala := true

	func _init(nyala: bool) -> void:
		menyala = nyala
		custom_minimum_size = Vector2(72, 66)

	func _draw() -> void:
		var warna := Color(0.9, 0.1, 0.18) if menyala else Color(0.28, 0.08, 0.1)
		var titik := PackedVector2Array()
		var langkah := 48
		for i in langkah:
			var t := TAU * float(i) / float(langkah)
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			titik.append(Vector2(x, y - 2.5))
		var skala := minf(size.x / 34.0, size.y / 31.0)
		for i in titik.size():
			titik[i] = size * 0.5 + titik[i] * skala
		draw_colored_polygon(titik, warna)
