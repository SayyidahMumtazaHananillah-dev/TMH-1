extends Control

# Scene tujuan setelah semua halaman selesai (bisa diisi lewat Inspector).
@export_file("*.tscn") var next_scene: String = "res://scenes/main-menu/main_menu.tscn"
# Opsional: ikon headphone untuk halaman ke-2 (kosongkan kalau tidak ada).
@export var headphone_icon: Texture2D

const UI_FONT := "res://scenes/main-menu/asset/font/chinese_rocks/chinese rocks rg.otf"
const C_RED := Color("b3202a")
const C_TEXT := Color("d8d4cc")
const C_DIM := Color("7a7a82")

const FADE_IN := 1.2
const AUTO_HOLD := 8.0      # detik sebelum otomatis lanjut (setelah skip aktif)
const FADE_OUT := 0.9
const SKIP_DELAY := 1.5     # skip baru bisa setelah sekian detik
const PAGE_GAP := 0.4       # jeda hitam antar halaman

# ---------- halaman 1: peringatan ----------
const TITLE_TEXT := "PERINGATAN"
const BODY_TEXT := "Game ini mengandung unsur horor: suasana mencekam, jumpscare mendadak, suara keras, dan adegan yang mungkin mengganggu."
const EPILEPSY_TEXT := "Terdapat efek kilatan cahaya dan layar berkedip yang dapat memicu kejang pada penderita epilepsi fotosensitif."
const ADVICE_TEXT := "Tidak disarankan untuk anak di bawah umur, orang dengan gangguan jantung, atau mudah cemas."

# ---------- halaman 2: headphone ----------
const HP_TITLE := "GUNAKAN HEADPHONE"
const HP_BODY := "Game ini dirancang untuk dimainkan dengan headphone atau headset."
const HP_BODY2 := "Suara di sekitarmu adalah bagian penting dari pengalaman."
const HP_ADVICE := "Mainkan di ruangan gelap dan atur volume sampai nyaman."

const HINT_TEXT := "TEKAN TOMBOL APA SAJA UNTUK LANJUT"

var _font: Font
var _pages: Array[Control] = []
var _hints: Array[Label] = []
var _titles: Array[Label] = []
var _idx := 0
var _can_skip := false
var _busy := false
var _tw: Tween
var _loops: Array[Tween] = []


func _ready() -> void:
	_font = ThemeDB.fallback_font
	if ResourceLoader.exists(UI_FONT):
		_font = load(UI_FONT) as Font

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_add_page([
		[BODY_TEXT, 24, C_TEXT],
		[EPILEPSY_TEXT, 24, C_TEXT],
		[ADVICE_TEXT, 20, C_DIM],
	], TITLE_TEXT, false)

	_add_page([
		[HP_BODY, 26, C_TEXT],
		[HP_BODY2, 24, C_TEXT],
		[HP_ADVICE, 20, C_DIM],
	], HP_TITLE, true)

	_show_page(0)


# =====================================================================
#  build
# =====================================================================
func _add_page(lines: Array, title: String, show_icon: bool) -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.modulate.a = 0.0
	center.visible = false
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 760.0
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	if show_icon:
		if headphone_icon != null:
			# kalau kamu isi gambar sendiri di Inspector, itu yang dipakai
			var tr := TextureRect.new()
			tr.texture = headphone_icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(0, 110)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(tr)
		else:
			# default: ikon headset yang digambar lewat kode
			box.add_child(HeadsetIcon.new())

	var t := _label(title, 60, C_RED, false)
	box.add_child(t)
	box.add_child(_line())
	for ln in lines:
		box.add_child(_label(String(ln[0]), int(ln[1]), ln[2] as Color, true))
	box.add_child(_spacer(10))
	var h := _label(HINT_TEXT, 18, C_DIM, false)
	h.modulate.a = 0.0
	box.add_child(h)

	_pages.append(center)
	_titles.append(t)
	_hints.append(h)


func _label(text: String, px: int, col: Color, autowrap: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _line() -> Control:
	var r := ColorRect.new()
	r.color = Color(C_RED, 0.6)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# =====================================================================
#  alur halaman
# =====================================================================
func _show_page(i: int) -> void:
	_idx = i
	_busy = false
	_can_skip = false
	var page := _pages[i]
	page.visible = true
	page.modulate.a = 0.0

	_tw = create_tween()
	_tw.tween_property(page, "modulate:a", 1.0, FADE_IN)
	_tw.tween_callback(_start_flicker)
	_tw.tween_interval(maxf(SKIP_DELAY - FADE_IN, 0.0))
	_tw.tween_callback(_enable_skip)
	_tw.tween_interval(AUTO_HOLD)
	_tw.tween_callback(_next)


# Judul berkedip pelan seperti lampu rusak.
func _start_flicker() -> void:
	var t := _titles[_idx]
	var ft := create_tween().set_loops()
	ft.tween_property(t, "modulate:a", 0.35, 0.07)
	ft.tween_property(t, "modulate:a", 1.0, 0.09)
	ft.tween_interval(randf_range(1.5, 3.5))
	ft.tween_property(t, "modulate:a", 0.6, 0.05)
	ft.tween_property(t, "modulate:a", 1.0, 0.05)
	ft.tween_interval(randf_range(2.0, 4.0))
	_loops.append(ft)


func _enable_skip() -> void:
	_can_skip = true
	var h := _hints[_idx]
	var ht := create_tween().set_loops()
	ht.tween_property(h, "modulate:a", 1.0, 0.8)
	ht.tween_property(h, "modulate:a", 0.25, 0.8)
	_loops.append(ht)


func _next() -> void:
	if _busy:
		return
	_busy = true
	_can_skip = false
	if _tw:
		_tw.kill()
	for l in _loops:
		if l:
			l.kill()
	_loops.clear()

	var page := _pages[_idx]
	var out := create_tween()
	out.tween_property(page, "modulate:a", 0.0, FADE_OUT)
	out.tween_interval(PAGE_GAP)
	out.tween_callback(func():
		page.visible = false
		if _idx + 1 < _pages.size():
			_show_page(_idx + 1)
		else:
			_change_scene())


func _change_scene() -> void:
	if next_scene != "" and ResourceLoader.exists(next_scene):
		get_tree().change_scene_to_file(next_scene)
	else:
		push_warning("Warning: 'next_scene' belum diisi / path salah: " + next_scene)


func _input(event: InputEvent) -> void:
	if not _can_skip or _busy:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_next()


# =====================================================================
#  ikon headset (digambar lewat kode, tanpa aset gambar)
# =====================================================================
class HeadsetIcon extends Control:
	const BAND := Color("d8d4cc")
	const CUP := Color("b3202a")
	const CUP_EDGE := Color("e0646c")

	var _cup_box := StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cup_box.bg_color = CUP
		_cup_box.border_color = CUP_EDGE
		_cup_box.set_border_width_all(2)
		_cup_box.set_corner_radius_all(9)

	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := 62.0
		var r := 44.0

		# headband (setengah lingkaran atas)
		draw_arc(Vector2(cx, cy), r, PI, TAU, 40, BAND, 6.0, true)

		# ear cup kiri & kanan
		var cup := Vector2(24, 50)
		draw_style_box(_cup_box, Rect2(Vector2(cx - r - cup.x * 0.5, cy - 4.0), cup))
		draw_style_box(_cup_box, Rect2(Vector2(cx + r - cup.x * 0.5, cy - 4.0), cup))

		# boom mic dari cup kiri ke depan mulut
		var mic: PackedVector2Array = [
			Vector2(cx - r - 4.0, cy + 46.0),
			Vector2(cx - r + 6.0, cy + 58.0),
			Vector2(cx - 18.0, cy + 62.0),
			Vector2(cx - 6.0, cy + 58.0),
		]
		draw_polyline(mic, BAND, 3.0, true)
		draw_circle(Vector2(cx - 6.0, cy + 58.0), 5.0, BAND)
