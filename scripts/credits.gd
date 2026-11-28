extends Control
# Credits bergulir ke atas. Seluruh tampilan dibuat lewat kode,
# jadi scene cukup berisi satu node Control dengan skrip ini.

@export_file("*.tscn") var scene_setelah_credit: String = "res://scenes/main-menu/main_menu.tscn"
@export var kecepatan: float = 60.0          # piksel per detik (skala 720p)
@export var musik: AudioStream               # opsional, mis. happy_ending.ogg
@export var warna_judul: Color = Color("e8c872")
@export var warna_teks: Color = Color.WHITE

const JUDUL_GAME = "TOO MUCH HOMEWORK"
const PENUTUP = "Terima kasih sudah bermain!"

# [judul bagian, [baris-baris]]. Bagian dengan daftar kosong otomatis dilewati,
# jadi isi aset pihak ketiga di bawah kalau sudah ada.
const KREDIT = [
	["DIREKSI & DESAIN", [
		"Game Direction: Sayyidah Mumtaza Hananillah",
		"Game Designer: Muhammad Rafka Aleandra",
	]],
	["PEMROGRAMAN", [
		"Gameplay & Systems Programmer: Muhammad Fajri Maliki",
		"AI & System Programmer: Abil El Shirazy Zulahi",
	]],
	["ARTISTIK & VISUAL", [
		"3D Environment & Level Artist: Sayyidah Mumtaza Hananillah",
		"UI/UX & 2D Artist: Muhammad Rafka Aleandra",
	]],
	["AUDIO", [
		"Sound Designer & Foley Artist: Muhammad Rafka Aleandra",
	]],
	["KONTRIBUSI ASET PIHAK KETIGA - ASET 3D & LINGKUNGAN", [
		# contoh: "Nama Aset - Pembuat (Sumber)",
	]],
	["KONTRIBUSI ASET PIHAK KETIGA - AUDIO & MUSIK", [
		# contoh: "\"Horror Ambience\" - AtlasAudio (Pixabay)",
	]],
	["BANTUAN AI", [
		"Claude (Anthropic)",
		"Bantuan skrip transisi ending dan credits,",
		"serta musik happy ending & bad ending",
	]],
	["TERIMA KASIH KHUSUS", [
		"Guru Pembimbing - Pak Maul & Bu Anissa",
		"SMKN 21 Jakarta",
		"Komunitas Godot Engine Indonesia",
	]],
]

var _gulungan: VBoxContainer
var _tween: Tween
var _skala: float = 1.0
var _sudah_selesai: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ukuran := get_viewport_rect().size
	_skala = maxf(ukuran.y / 720.0, 0.5)

	var latar := ColorRect.new()
	latar.color = Color.BLACK
	latar.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(latar)

	if musik != null:
		var pemutar := AudioStreamPlayer.new()
		pemutar.stream = musik
		add_child(pemutar)
		pemutar.play()

	_gulungan = VBoxContainer.new()
	_gulungan.add_theme_constant_override("separation", int(12 * _skala))
	_gulungan.custom_minimum_size = Vector2(ukuran.x * 0.8, 0)
	_gulungan.position = Vector2(ukuran.x * 0.1, ukuran.y)
	add_child(_gulungan)

	_tambah_teks(JUDUL_GAME, 64, warna_judul)
	_tambah_jarak(70)

	for bagian in KREDIT:
		var baris: Array = bagian[1]
		if baris.is_empty():
			continue
		_tambah_teks(bagian[0], 32, warna_judul)
		for teks in baris:
			_tambah_teks(teks, 24, warna_teks)
		_tambah_jarak(60)

	_tambah_jarak(40)
	_tambah_teks(PENUTUP, 36, warna_teks)
	_tambah_jarak(int(ukuran.y / _skala * 0.5))

	# Fade-in dari hitam
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)

	# Tunggu layout selesai dihitung supaya tinggi gulungan akurat
	await get_tree().process_frame
	await get_tree().process_frame

	var tinggi_layar := get_viewport_rect().size.y
	var posisi_akhir := -_gulungan.size.y
	var durasi := (tinggi_layar - posisi_akhir) / (kecepatan * _skala)

	_tween = create_tween()
	_tween.tween_property(_gulungan, "position:y", posisi_akhir, durasi)
	await _tween.finished
	await get_tree().create_timer(1.0).timeout
	_selesai()

func _process(_delta: float) -> void:
	# Tahan Enter/Spasi untuk mempercepat
	if _tween != null and _tween.is_valid():
		_tween.set_speed_scale(3.0 if Input.is_action_pressed("ui_accept") else 1.0)

func _unhandled_input(event: InputEvent) -> void:
	# Esc untuk melewati credits
	if event.is_action_pressed("ui_cancel"):
		_selesai()

func _tambah_teks(teks: String, ukuran_font: int, warna: Color) -> void:
	var label := Label.new()
	label.text = teks
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", int(ukuran_font * _skala))
	label.add_theme_color_override("font_color", warna)
	_gulungan.add_child(label)

func _tambah_jarak(tinggi: int) -> void:
	var jarak := Control.new()
	jarak.custom_minimum_size = Vector2(0, tinggi * _skala)
	_gulungan.add_child(jarak)

func _selesai() -> void:
	if _sudah_selesai:
		return
	_sudah_selesai = true
	if _tween != null:
		_tween.kill()

	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.8)
	await fade_out.finished

	if ResourceLoader.exists(scene_setelah_credit):
		get_tree().change_scene_to_file(scene_setelah_credit)
	else:
		push_warning("scene_setelah_credit tidak ditemukan: " + scene_setelah_credit)
		get_tree().quit()
