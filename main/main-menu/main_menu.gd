extends Control

# Isi dengan scene gameplay-mu (bisa juga diisi lewat Inspector).
@export_file("*.tscn") var game_scene: String = ""

@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var open_sound: AudioStreamPlayer = $OpenSound

# ---------- path ----------
const UI_FONT := "res://asset/font/chinese_rocks/chinese rocks rg.otf"
const TITLE_FONT := "res://asset/font/chinese_rocks/chinese rocks rg.otf"
const BOOK := "res://asset/book/"
const SAVE_PATH := "user://settings.cfg"

# ---------- warna ----------
const C_INK := Color("2f4272")        # tinta pulpen biru
const C_RED := Color("b3202a")        # pulpen merah guru
const C_CREAM := Color("e6dcc6")
const C_PAPER_WHITE := Color("f6f1e4")
const C_DIM := Color("6b6f86")
const C_TITLE_RED := Color(0.67268705, 0, 0.0883074, 1)

# ---------- ukuran (satuan desain 1152x648) ----------
const COVER_SIZE := Vector2(450, 560)
const OPEN_SIZE := Vector2(980, 560)
const MENU_X := 98.0
const ROW_TOP := 136.0      # baris pertama pas di antara 2 garis buku
const ROW_H := 40.0

const DEFAULTS := {"master": 100.0, "music": 100.0, "sfx": 100.0, "bright": 100.0}

# Ubah isi kredit di sini. [peran, nama] (peran boleh "")
const CR_LEFT_COUNT := 4   # jumlah bagian yang tampil di halaman kiri
const CR_DATA := [
	{"title": "DIREKSI & DESAIN", "items": [
		["Game Designer", "Muhammad Rafka Aleandra"]]},
	{"title": "PEMROGRAMAN", "items": [
		["Gameplay & Systems Programmer", "Muhammad Fajri Maliki"],
		["AI & System Programmer", "Abil El Shirazy Zulahi"]]},
	{"title": "ARTISTIK & VISUAL", "items": [
		["3D Environment & Level Artist", "Sayyidah Mumtaza Hananillah"],
		["UI/UX & 2D Artist", "Muhammad Rafka Aleandra"]]},
	{"title": "AUDIO", "items": [
		["Sound Designer & Foley Artist", "Muhammad Rafka Aleandra"]]},
	{"title": "ASET PIHAK KETIGA", "groups": [
		{"label": "Aset 3D & Lingkungan", "items": []},
		{"label": "Audio & Musik", "items": [""]}]},
	{"title": "TERIMA KASIH KHUSUS", "items": [
		["Guru Pembimbing", "Pak Maul & Bu Anisa"],
		["", "SMKN 21 Jakarta"],
		["", "Komunitas Godot Engine Indonesia"]]},
]

var _font: Font
var _title_font: Font
var _menu_book: Control
var _open_book: Control
var _page_title: Label
var _settings_box: Control
var _credits_box: Control
var _back_btn: Button
var _rows: Array[Control] = []
var _sliders := {}
var _vals := {}
var _win_label: Label
var _fullscreen := false
var _mode := ""                     # "", "settings", "credits"
var _book_tw: Tween
var _dim: ColorRect
var _exit_note: Control
var _bright: ColorRect
var _base_click_db := 0.0
var _menu_pos := Vector2.ZERO
var _open_pos := Vector2.ZERO


func _ready() -> void:
	_font = _load_font(UI_FONT)
	_title_font = _load_font(TITLE_FONT)
	_base_click_db = click_sound.volume_db
	_build_menu_book()
	_build_open_book()
	_build_exit_popup()
	_build_brightness()
	_load_settings()
	resized.connect(_layout)
	_layout()
	call_deferred("_layout")
	_menu_book.modulate.a = 0.0
	create_tween().tween_property(_menu_book, "modulate:a", 1.0, 0.6)


# =====================================================================
#  helper
# =====================================================================
func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return ThemeDB.fallback_font

func _tex(file: String) -> Texture2D:
	var p := BOOK + file
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	push_warning("Aset buku tidak ditemukan: " + p)
	return null

func _art(file: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(file)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = pos
	t.size = sz
	return t

func _label(text: String, px: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _sbox(file: String, pad_left: int) -> StyleBox:
	var t := _tex(file)
	if t == null:
		return StyleBoxEmpty.new()
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = 24
	sb.texture_margin_right = 24
	sb.content_margin_left = pad_left
	sb.content_margin_right = 10
	return sb

func _click() -> void:
	if click_sound:
		click_sound.play()
		

func _play_book_open() -> void:
	if open_sound:
		open_sound.play()

func _style_button(b: Button, normal: StyleBox, hover: StyleBox, px: int, col: Color, col_hover: Color) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", px)
	for n in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(n, col)
	for n in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(n, col_hover)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# =====================================================================
#  BUKU TERTUTUP (judul + tombol)
# =====================================================================
func _build_menu_book() -> void:
	_menu_book = Control.new()
	_menu_book.size = COVER_SIZE
	_menu_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_book)
	_menu_book.add_child(_art("book_cover_bersih.png", Vector2.ZERO, COVER_SIZE))

	_menu_book.add_child(_art("judul_tmh.png", Vector2(MENU_X - 1.0, 85), Vector2(280, 110)))

	var items: Array = [
		["PLAY", _on_play],
		["SETTING", _on_settings],
		["CREDIT", _on_credits],
		["EXIT", _on_exit],
	]
	var y := 232.0
	for it in items:
		var b := _menu_button(String(it[0]), it[1] as Callable)
		b.position = Vector2(MENU_X, y)
		_menu_book.add_child(b)
		y += 54.0

func _title(text: String, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _title_font)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size = Vector2(226, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var col := Color("e0646c") if text == "EXIT" else C_CREAM
	_style_button(b, _sbox("book_strip_dark.png", 24), _sbox("book_strip_red.png", 24), 22, col, Color.WHITE)
	b.pressed.connect(func(): _click(); cb.call())
	b.mouse_entered.connect(_nudge.bind(b, true))
	b.mouse_exited.connect(_nudge.bind(b, false))
	return b

func _nudge(b: Control, on: bool) -> void:
	if on:
		_click()
	create_tween().tween_property(
		b,
		"position:x",
		MENU_X + (10.0 if on else 0.0),
		0.12
	)


# =====================================================================
#  BUKU TERBUKA (Settings & Credits)
# =====================================================================
func _build_open_book() -> void:
	_open_book = Control.new()
	_open_book.size = OPEN_SIZE
	_open_book.pivot_offset = OPEN_SIZE * 0.5
	_open_book.visible = false
	_open_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_open_book)
	_open_book.add_child(_art("book_open_bersih.png", Vector2.ZERO, OPEN_SIZE))

	# judul halaman (selotip)
	_open_book.add_child(_art("book_tape.png", Vector2(66, 60), Vector2(230, 52)))
	_page_title = _label("SETTINGS", 28, C_PAPER_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_page_title.position = Vector2(66, 60)
	_page_title.size = Vector2(230, 52)
	_open_book.add_child(_page_title)

	_settings_box = _page_root()
	_credits_box = _page_root()
	_open_book.add_child(_settings_box)
	_open_book.add_child(_credits_box)
	_build_settings(_settings_box)
	_build_credits(_credits_box)

	# tombol BACK (label tag hitam)
	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.position = Vector2(6, 462)
	_back_btn.size = Vector2(150, 46)
	_back_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tag := _sbox("book_back_tag.png", 42)
	var tag_hover := _sbox("book_back_tag.png", 42)
	if tag is StyleBoxTexture:
		(tag as StyleBoxTexture).texture_margin_left = 40
		(tag as StyleBoxTexture).texture_margin_right = 4
		(tag_hover as StyleBoxTexture).texture_margin_left = 40
		(tag_hover as StyleBoxTexture).texture_margin_right = 4
		(tag_hover as StyleBoxTexture).modulate_color = Color(1.5, 0.45, 0.45)
	_style_button(_back_btn, tag, tag_hover, 22, Color.WHITE, Color.WHITE)
	_back_btn.pressed.connect(func(): _click(); _close_book())
	_back_btn.mouse_entered.connect(_click)
	_open_book.add_child(_back_btn)

func _page_root() -> Control:
	var c := Control.new()
	c.size = OPEN_SIZE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	return c


# ---------- SETTINGS ----------
func _build_settings(root: Control) -> void:
	var defs: Array = [
		["master", "MASTER VOLUME"],
		["music", "MUSIC VOLUME"],
		["sfx", "SFX VOLUME"],
		["bright", "BRIGHTNESS"],
		["window", "WINDOW MODE"],
	]
	var i := 0
	for d in defs:
		var key := String(d[0])
		var row := Control.new()
		row.position = Vector2(84, ROW_TOP + ROW_H * i)
		row.size = Vector2(782, ROW_H)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		root.add_child(row)
		_rows.append(row)

		var lb := _label(String(d[1]), 20, C_INK)
		lb.position = Vector2(18, 0)
		lb.size = Vector2(340, ROW_H)
		row.add_child(lb)
		row.set_meta("label", lb)

		if key == "window":
			_build_window_selector(row)
		else:
			_build_slider(row, key)
		i += 1

	var reset := Button.new()
	reset.text = "RESET TO DEFAULTS"
	reset.flat = true
	reset.position = Vector2(540, ROW_TOP + ROW_H * 6.0)
	reset.size = Vector2(300, ROW_H)
	_style_button(reset, StyleBoxEmpty.new(), StyleBoxEmpty.new(), 20, C_INK, C_RED)
	reset.pressed.connect(func(): _click(); _reset_defaults())
	root.add_child(reset)

func _build_slider(row: Control, key: String) -> void:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = 100.0
	s.position = Vector2(430, 1)
	s.size = Vector2(220, 38)
	s.focus_mode = Control.FOCUS_NONE
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = Color(C_INK, 0.85)
	track.set_corner_radius_all(2)
	track.content_margin_top = 1.5
	track.content_margin_bottom = 1.5
	for n in ["slider", "grabber_area", "grabber_area_highlight"]:
		s.add_theme_stylebox_override(n, track)
	var tick := _tex("book_tick.png")
	if tick:
		for n in ["grabber", "grabber_highlight", "grabber_disabled"]:
			s.add_theme_icon_override(n, tick)
	s.value_changed.connect(_on_slider.bind(key))
	row.add_child(s)
	_sliders[key] = s

	var v := _label("100", 22, C_INK)
	v.position = Vector2(664, 0)
	v.size = Vector2(80, ROW_H)
	row.add_child(v)
	_vals[key] = v

func _build_window_selector(row: Control) -> void:
	row.add_child(_arrow(Vector2(430, 3), true))
	row.add_child(_arrow(Vector2(626, 3), false))
	_win_label = _label("WINDOWED", 20, C_INK, HORIZONTAL_ALIGNMENT_CENTER)
	_win_label.position = Vector2(458, 0)
	_win_label.size = Vector2(164, ROW_H)
	row.add_child(_win_label)

func _arrow(pos: Vector2, flip: bool) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = _tex("book_arrow.png")
	b.flip_h = flip
	b.position = pos
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _click(); _set_fullscreen(not _fullscreen))
	b.mouse_entered.connect(func(): b.self_modulate = Color(1.6, 0.4, 0.4))
	b.mouse_exited.connect(func(): b.self_modulate = Color.WHITE)
	return b

func _on_slider(v: float, key: String) -> void:
	(_vals[key] as Label).text = str(int(v))
	_apply(key, v)

func _apply(key: String, v: float) -> void:
	match key:
		"master":
			_set_bus("Master", v)
		"music":
			_set_bus("Music", v)
		"sfx":
			if AudioServer.get_bus_index("SFX") >= 0:
				_set_bus("SFX", v)
			else:
				click_sound.volume_db = _base_click_db + linear_to_db(maxf(v, 0.001) / 100.0)
		"bright":
			_bright.color.a = (1.0 - v / 100.0) * 0.7

func _set_bus(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001) / 100.0))

func _set_fullscreen(on: bool) -> void:
	_fullscreen = on
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_win_label.text = "FULLSCREEN" if on else "WINDOWED"

func _reset_defaults() -> void:
	for key in DEFAULTS.keys():
		var s: HSlider = _sliders[key]
		s.value = float(DEFAULTS[key])      # memicu value_changed
	_set_fullscreen(false)


# ---------- CREDITS ----------
func _build_credits(root: Control) -> void:
	var left: Array = CR_DATA.slice(0, CR_LEFT_COUNT)
	var right: Array = CR_DATA.slice(CR_LEFT_COUNT)
	root.add_child(_credit_page(Vector2(100, 122), Vector2(346, 378), left))
	root.add_child(_credit_page(Vector2(498, 76), Vector2(350, 424), right))

func _credit_page(pos: Vector2, sz: Vector2, sections: Array) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.position = pos
	sc.size = sz
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.get_v_scroll_bar().modulate.a = 0.0
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = sz.x - 8.0
	box.add_theme_constant_override("separation", 2)
	sc.add_child(box)
	for sec in sections:
		var lines: Array = []       # [peran, nama]
		if sec.has("items"):
			for it in sec["items"]:
				lines.append([String(it[0]), String(it[1])])
		if sec.has("groups"):
			for g in sec["groups"]:
				for line in g["items"]:
					lines.append([String(g["label"]), String(line)])
		if lines.is_empty():
			continue
		box.add_child(_spacer(10))
		box.add_child(_label(String(sec["title"]), 22, C_RED, HORIZONTAL_ALIGNMENT_CENTER))
		for ln in lines:
			if String(ln[0]) != "":
				box.add_child(_label(String(ln[0]).to_upper(), 13, C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
			var nm := _label(String(ln[1]), 19, C_INK, HORIZONTAL_ALIGNMENT_CENTER)
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nm.custom_minimum_size.y = 30
			box.add_child(nm)
		box.add_child(_spacer(8))
	return sc

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# =====================================================================
#  buka / tutup buku
# =====================================================================
func _calc() -> void:
	_menu_pos = Vector2(-24.0, (size.y - COVER_SIZE.y) * 0.5)
	_open_pos = (size - OPEN_SIZE) * 0.5

func _layout() -> void:
	_calc()
	if _mode == "":
		_menu_book.position = _menu_pos
	else:
		_menu_book.position = Vector2(-COVER_SIZE.x - 40.0, _menu_pos.y)
		_open_book.position = _open_pos
	_exit_note.position = (size - _exit_note.size) * 0.5

func _show_book(mode: String) -> void:
	if _mode == mode:
		_close_book()
		return
	var first := _mode == ""
	_mode = mode
	_page_title.text = "SETTINGS" if mode == "settings" else "CREDITS"
	_settings_box.visible = mode == "settings"
	_credits_box.visible = mode == "credits"
	var page: Control = _settings_box if mode == "settings" else _credits_box
	if _book_tw:
		_book_tw.kill()
	if first:
		_play_book_open()
		_calc()
		_open_book.visible = true
		_open_book.position = Vector2(_open_pos.x, size.y + 30.0)
		_open_book.rotation_degrees = 4.0
		_open_book.modulate.a = 0.0
		_book_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_book_tw.tween_property(_open_book, "position", _open_pos, 0.6)
		_book_tw.tween_property(_open_book, "rotation_degrees", 0.0, 0.6)
		_book_tw.tween_property(_open_book, "modulate:a", 1.0, 0.35)
		_book_tw.tween_property(_menu_book, "position:x", -COVER_SIZE.x - 40.0, 0.5)
	else:
		page.modulate.a = 0.0
		_book_tw = create_tween()
		_book_tw.tween_property(page, "modulate:a", 1.0, 0.25)

func _close_book() -> void:
	if _mode == "":
		return
	_mode = ""
	_save_settings()
	_calc()
	if _book_tw:
		_book_tw.kill()
	_book_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_book_tw.tween_property(_open_book, "position:y", size.y + 30.0, 0.5)
	_book_tw.tween_property(_open_book, "rotation_degrees", 3.0, 0.5)
	_book_tw.tween_property(_open_book, "modulate:a", 0.0, 0.4)
	_book_tw.tween_property(_menu_book, "position:x", _menu_pos.x, 0.5)
	_book_tw.finished.connect(func():
		if _mode == "":
			_open_book.visible = false)


# =====================================================================
#  tombol menu
# =====================================================================
func _on_play() -> void:
	_save_settings()
	if game_scene != "":
		get_tree().change_scene_to_file(game_scene)
	else:
		print("MainMenu: isi 'Game Scene' di Inspector (node MainMenu) supaya tombol PLAY jalan.")

func _on_settings() -> void:
	_show_book("settings")

func _on_credits() -> void:
	_show_book("credits")


# =====================================================================
#  popup EXIT (kertas bergaris)
# =====================================================================
func _build_exit_popup() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.65)
	_dim.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_exit_note = Control.new()
	_exit_note.size = Vector2(380, 260)
	_exit_note.pivot_offset = _exit_note.size * 0.5
	_exit_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(_exit_note)
	_exit_note.add_child(_art("book_note.png", Vector2.ZERO, Vector2(380, 260)))

	var t := _label("KELUAR?", 36, C_RED, HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(50, 44)
	t.size = Vector2(300, 50)
	_exit_note.add_child(t)
	var m := _label("Yakin ingin keluar dari game?", 18, C_INK, HORIZONTAL_ALIGNMENT_CENTER)
	m.position = Vector2(30, 104)
	m.size = Vector2(320, 40)
	_exit_note.add_child(m)

	var yes := _choice("YA", Vector2(52, 172))
	yes.pressed.connect(_on_yes)
	var no := _choice("TIDAK", Vector2(208, 172))
	no.pressed.connect(_on_no)
	_exit_note.add_child(yes)
	_exit_note.add_child(no)

func _choice(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(120, 46)
	var hover := _sbox("book_strip_red.png", 0)
	_style_button(b, StyleBoxEmpty.new(), hover, 24, C_INK, Color.WHITE)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_entered.connect(_click)
	return b

func _on_exit() -> void:
	_play_book_open()
	_dim.visible = true
	_dim.modulate.a = 0.0
	_exit_note.position = (size - _exit_note.size) * 0.5
	_exit_note.scale = Vector2(0.85, 0.85)
	_exit_note.rotation_degrees = -4.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(_exit_note, "scale", Vector2.ONE, 0.3)
	tw.tween_property(_exit_note, "rotation_degrees", -1.0, 0.3)

func _on_no() -> void:
	_dim.visible = false

func _on_yes() -> void:
	_save_settings()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _dim.visible:
			_on_no()
		elif _mode != "":
			_close_book()


# =====================================================================
#  brightness + simpan/muat pengaturan
# =====================================================================
func _build_brightness() -> void:
	_bright = ColorRect.new()
	_bright.color = Color(0, 0, 0, 0)
	_bright.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bright)
	_bright.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(SAVE_PATH) == OK
	for key in DEFAULTS.keys():
		var v := float(DEFAULTS[key])
		if ok:
			v = float(cfg.get_value("settings", key, v))
		(_sliders[key] as HSlider).set_value_no_signal(v)
		(_vals[key] as Label).text = str(int(v))
		_apply(key, v)
	_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_win_label.text = "FULLSCREEN" if _fullscreen else "WINDOWED"
	if ok and cfg.has_section_key("settings", "fullscreen"):
		_set_fullscreen(bool(cfg.get_value("settings", "fullscreen")))

# File ini bisa dibaca scene gameplay: [settings] bright = 0..100 dst.
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in DEFAULTS.keys():
		cfg.set_value("settings", key, (_sliders[key] as HSlider).value)
	cfg.set_value("settings", "fullscreen", _fullscreen)
	cfg.save(SAVE_PATH)
