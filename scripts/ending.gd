extends Control
## Cutscene ending: Nobma berhasil keluar lewat gerbang -> "GOOD ENDING".
## Scene : res://scenes/cutscenes/ending.tscn
## Skrip : res://scripts/ending.gd

const ASSET_DIR := "res://scenes/cutscenes/assets/"
const NOBMA := "nobma"
const NARASI := "narasi"

enum Phase { INTRO, DIALOG, TRANSITION, TITLE_WAIT, TITLE_READY, LEAVING }

@export_file("*.tscn") var main_menu_path: String = ""

@export_group("Fokus Pembicara")
@export var active_color := Color(1.0, 1.0, 1.0, 1.0)
@export var dim_color := Color(0.55, 0.55, 0.58, 1.0)
@export_range(0.8, 1.0, 0.01) var dim_scale_factor: float = 0.94
@export_range(0.05, 1.0, 0.01) var focus_time: float = 0.22

@export_group("Efek Tuing")
## Fraksi tinggi layar (0.013 = 14 px di 1080p).
@export var pop_height: float = 0.013
@export var pop_up_time: float = 0.07
@export var pop_down_time: float = 0.11

@export_group("Layout Nobma")
## Semua posisi & pivot berupa FRAKSI ukuran layar (0..1).
## Pivot x = 0 supaya sisi kiri sprite (meja) tetap menempel di tepi kiri layar.
@export var nobma_position := Vector2(0.0, 0.0)
@export var nobma_base_scale := Vector2(1.0, 1.0)
@export var nobma_pivot := Vector2(0.0, 1.0)

@export_group("Teks & Transisi")
@export var seconds_per_char: float = 0.03
@export var fade_time: float = 1.0
@export var name_font_ratio: float = 0.036
@export var text_font_ratio: float = 0.032
@export var title_font_ratio: float = 0.14
@export var hint_font_ratio: float = 0.032
@export var mono_text_color := Color(0.72, 0.82, 1.0, 1.0)
@export var normal_text_color := Color(1.0, 1.0, 1.0, 1.0)

var _bg: TextureRect
var _nobma: TextureRect
var _dialog_box: Control
var _name_label: Label
var _text_label: Label
var _fade_rect: ColorRect
var _title_label: Label
var _hint_label: Label

var _nobma_sprite: String = ""
var _nobma_base_pos: Vector2 = Vector2.ZERO
var _nobma_shown: bool = true

var _tex_cache: Dictionary = {}
var _steps: Array[Dictionary] = []
var _index: int = -1
var _phase: Phase = Phase.INTRO
var _typing: bool = false

var _type_tween: Tween
var _fade_tween: Tween
var _focus_tween: Tween
var _pop_tween: Tween
var _title_tween: Tween
var _hint_tween: Tween


func _ready() -> void:
	_bg = get_node_or_null("Background") as TextureRect
	_nobma = get_node_or_null("Nobma") as TextureRect
	_dialog_box = get_node_or_null("DialogBox") as Control
	_name_label = get_node_or_null("%NameLabel") as Label
	_text_label = get_node_or_null("%TextLabel") as Label
	_fade_rect = get_node_or_null("Fade") as ColorRect
	_title_label = get_node_or_null("%TitleLabel") as Label
	_hint_label = get_node_or_null("%HintLabel") as Label

	if _bg == null or _nobma == null or _dialog_box == null \
			or _name_label == null or _text_label == null:
		push_error("ending.gd: node wajib tidak ditemukan (Background, Nobma, DialogBox, %NameLabel, %TextLabel). Cek struktur ending.tscn.")
		return

	# Game utama kemungkinan menangkap mouse (first person): tampilkan kursor lagi.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_nobma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nobma.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nobma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nobma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_nobma.scale = nobma_base_scale * dim_scale_factor
	_nobma.modulate = dim_color
	_dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.visible_characters = 0

	for n: Control in [_title_label, _hint_label]:
		if n != null:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.modulate.a = 0.0

	resized.connect(_relayout)
	_relayout()
	_relayout.call_deferred()

	_steps = _build_script()

	_set_bg("background_gerbang.png")
	_set_nobma("nobma_tegak_biasa.png", false)
	_apply_focus(NARASI, true)

	if _fade_rect != null:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.color = Color(0, 0, 0, 1)
		await _fade_to(0.0, fade_time)

	_phase = Phase.DIALOG
	_play_from(0)


func _exit_tree() -> void:
	for t: Tween in [_type_tween, _fade_tween, _focus_tween, _pop_tween, _title_tween, _hint_tween]:
		_kill(t)


# ---------------------------------------------------------------- Naskah ----

func _build_script() -> Array[Dictionary]:
	var s: Array[Dictionary] = []
	s.append({"who": NOBMA, "mono": true, "text": "Gerbangnya... kebuka. Beneran kebuka.", "nobma": "nobma_tegak_biasa.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Aku... berhasil keluar dari sekolah?!", "nobma": "nobma_tegak_kaget.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Haaah... lega banget! Akhirnya bisa keluar juga!", "nobma": "nobma_tegak_melek.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Udah malam begini. Mending cepat pulang sebelum ada yang lihat.", "nobma": "nobma_tegak_mikir.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Soal PR... urusan besok aja deh. Yang penting sekarang pulang dulu.", "nobma": "nobma_nunduk_melek.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Bayangin aja... sampai rumah, mandi air hangat, makan, terus langsung rebahan.", "nobma": "nobma_tegak_merem.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Kasur... tunggu aku ya...", "nobma": "nobma_nunduk_merem.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Hehe... sampai rumah dengan selamat. Misi selesai!", "nobma": "nobma_tegak_melek.png"})
	s.append({"type": "title"})
	return s


# ----------------------------------------------------------- Alur dialog ----

func _input(event: InputEvent) -> void:
	var pressed := false
	if event.is_action_pressed("ui_accept"):
		pressed = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	get_viewport().set_input_as_handled()

	match _phase:
		Phase.DIALOG:
			if _typing:
				_finish_typing()
			else:
				_play_from(_index + 1)
		Phase.TITLE_READY:
			_go_to_main_menu()
		_:
			pass


func _play_from(start: int) -> void:
	_index = start
	while _index < _steps.size():
		var step: Dictionary = _steps[_index]
		var kind: String = step.get("type", "line")
		match kind:
			"line":
				_show_line(step)
				return
			"title":
				_phase = Phase.TRANSITION
				await _play_title()
				return
			_:
				push_warning("ending.gd: tipe step tidak dikenal: %s" % kind)
				_index += 1
	_phase = Phase.TRANSITION
	await _play_title()


func _show_line(step: Dictionary) -> void:
	var who: String = step.get("who", NARASI)
	var is_mono: bool = step.get("mono", false)
	var text: String = step.get("text", "")

	if step.has("nobma"):
		_set_nobma(step["nobma"], true)
	_apply_focus(who)

	if who == NOBMA:
		_name_label.text = "Nobma (dalam hati)" if is_mono else "Nobma"
	else:
		_name_label.text = ""
	_name_label.visible = _name_label.text != ""

	_text_label.add_theme_color_override("font_color", mono_text_color if is_mono else normal_text_color)
	_start_typing("(%s)" % text if is_mono else text)


func _play_title() -> void:
	_kill(_type_tween)
	_typing = false
	await _fade_to(1.0, fade_time)

	_dialog_box.visible = false
	_nobma.visible = false
	_nobma_shown = false
	_phase = Phase.TITLE_WAIT

	if _title_label != null:
		_kill(_title_tween)
		_title_label.pivot_offset = _title_label.size * 0.5
		_title_label.scale = Vector2(0.85, 0.85)
		_title_label.modulate.a = 0.0
		_title_tween = create_tween().set_parallel(true)
		_title_tween.tween_property(_title_label, "modulate:a", 1.0, 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_title_tween.tween_property(_title_label, "scale", Vector2.ONE, 1.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _title_tween.finished

	await get_tree().create_timer(0.6).timeout

	if _hint_label != null:
		_kill(_hint_tween)
		_hint_tween = create_tween()
		_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.6)
		await _hint_tween.finished
		# Denyut halus sampai pemain menekan tombol.
		_hint_tween = create_tween().set_loops()
		_hint_tween.tween_property(_hint_label, "modulate:a", 0.35, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_phase = Phase.TITLE_READY


func _go_to_main_menu() -> void:
	if main_menu_path.is_empty():
		push_warning("ending.gd: main_menu_path kosong. Isi di Inspector (node Ending).")
		return
	if not ResourceLoader.exists(main_menu_path):
		push_error("ending.gd: scene main menu tidak ditemukan: %s" % main_menu_path)
		return
	_phase = Phase.LEAVING
	get_tree().change_scene_to_file(main_menu_path)


# ------------------------------------------------------------- Typewriter ---

func _start_typing(text: String) -> void:
	_kill(_type_tween)
	_text_label.text = text
	_text_label.visible_characters = 0
	var count := text.length()
	if count == 0:
		_typing = false
		return
	_typing = true
	_type_tween = create_tween()
	_type_tween.tween_property(_text_label, "visible_characters", count, maxf(count * seconds_per_char, 0.05))
	_type_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	_kill(_type_tween)
	_typing = false
	_text_label.visible_characters = -1


# --------------------------------------------------------------- Karakter ---

func _relayout() -> void:
	if _nobma != null:
		_nobma.size = size
		_nobma.pivot_offset = nobma_pivot * size
		_nobma_base_pos = nobma_position * size
		if _pop_tween == null or not _pop_tween.is_valid():
			_nobma.position = _nobma_base_pos
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", maxi(int(size.y * title_font_ratio), 16))
		_title_label.pivot_offset = _title_label.size * 0.5
	if _hint_label != null:
		_hint_label.add_theme_font_size_override("font_size", maxi(int(size.y * hint_font_ratio), 10))
	if _name_label != null and _text_label != null:
		_name_label.add_theme_font_size_override("font_size", maxi(int(size.y * name_font_ratio), 10))
		_text_label.add_theme_font_size_override("font_size", maxi(int(size.y * text_font_ratio), 10))
	var margin := get_node_or_null("DialogBox/Margin") as MarginContainer
	if margin != null:
		var mx := int(size.x * 0.018)
		var my := int(size.y * 0.012)
		margin.add_theme_constant_override("margin_left", mx)
		margin.add_theme_constant_override("margin_right", mx)
		margin.add_theme_constant_override("margin_top", my)
		margin.add_theme_constant_override("margin_bottom", my)
	var vbox := get_node_or_null("DialogBox/Margin/VBox") as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", int(size.y * 0.004))


func _set_nobma(file_name: String, do_pop: bool) -> void:
	if _nobma_sprite == file_name:
		return
	var tex := _get_texture(file_name)
	if tex == null:
		return
	_nobma.texture = tex
	_nobma_sprite = file_name
	if do_pop and _nobma_shown:
		_pop()


func _pop() -> void:
	_kill(_pop_tween)
	_nobma.position = _nobma_base_pos  # reset dulu supaya tidak pernah melenceng
	var lift := pop_height * size.y
	_pop_tween = create_tween()
	_pop_tween.tween_property(_nobma, "position:y", _nobma_base_pos.y - lift, pop_up_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_nobma, "position:y", _nobma_base_pos.y, pop_down_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _apply_focus(speaker: String, instant: bool = false) -> void:
	if not _nobma_shown:
		return
	var active := speaker == NOBMA
	var target_mod := active_color if active else dim_color
	var target_scale := nobma_base_scale if active else nobma_base_scale * dim_scale_factor
	_kill(_focus_tween)
	if instant:
		_nobma.modulate = target_mod
		_nobma.scale = target_scale
		return
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(_nobma, "modulate", target_mod, focus_time)
	_focus_tween.tween_property(_nobma, "scale", target_scale, focus_time)


# ------------------------------------------------------------------ Util ----

func _set_bg(file_name: String) -> void:
	var tex := _get_texture(file_name)
	if tex != null:
		_bg.texture = tex


func _get_texture(file_name: String) -> Texture2D:
	if _tex_cache.has(file_name):
		return _tex_cache[file_name]
	var path := ASSET_DIR + file_name
	if not ResourceLoader.exists(path):
		push_warning("ending.gd: aset tidak ditemukan: %s" % path)
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		_tex_cache[file_name] = tex
	return tex


func _fade_to(alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	_kill(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await _fade_tween.finished


func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


func _on_audio_stream_player_finished() -> void:
	$AudioStreamPlayer.play()
