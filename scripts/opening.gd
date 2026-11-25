extends Control
## Cutscene pembuka: Nobma ketiduran di kelas.
## Scene : res://scenes/cutscenes/opening.tscn
## Skrip : res://scripts/opening.gd

const ASSET_DIR := "res://scenes/cutscenes/assets/"
const NOBMA := "nobma"
const GURU := "guru"
const NARASI := "narasi"

@export_file("*.tscn") var next_scene_path: String = ""

@export_group("Fokus Pembicara")
@export var active_color := Color(1.0, 1.0, 1.0, 1.0)
@export var dim_color := Color(0.55, 0.55, 0.58, 1.0)
@export_range(0.8, 1.0, 0.01) var dim_scale_factor: float = 0.94
@export_range(0.05, 1.0, 0.01) var focus_time: float = 0.22

@export_group("Efek Tuing")
## Tinggi tuing sebagai fraksi tinggi layar (0.013 = 14 px di 1080p).
@export var pop_height: float = 0.013
@export var pop_up_time: float = 0.07
@export var pop_down_time: float = 0.11

@export_group("Layout Nobma (kiri)")
## Semua posisi & pivot berupa FRAKSI ukuran layar (0..1), jadi aman di resolusi apa pun.
@export var nobma_position := Vector2(-0.016, 0.0)
@export var nobma_base_scale := Vector2(0.88, 0.88)
## Pivot: tengah-bawah badan Nobma.
@export var nobma_pivot := Vector2(0.3005, 1.0)

@export_group("Layout Guru (kanan)")
@export var guru_position := Vector2(0.038, 0.0)
@export var guru_base_scale := Vector2(0.9, 0.9)
## Pivot: tengah-bawah badan Guru.
@export var guru_pivot := Vector2(0.6214, 1.0)

@export_group("Teks & Transisi")
@export var seconds_per_char: float = 0.03
@export var fade_time: float = 0.8
## Ukuran font sebagai fraksi tinggi layar.
@export var name_font_ratio: float = 0.036
@export var text_font_ratio: float = 0.032
@export var mono_text_color := Color(0.72, 0.82, 1.0, 1.0)
@export var normal_text_color := Color(1.0, 1.0, 1.0, 1.0)


class CharState extends RefCounted:
	var key: String = ""
	var node: TextureRect
	var base_pos: Vector2 = Vector2.ZERO
	var pos_frac: Vector2 = Vector2.ZERO
	var pivot_frac: Vector2 = Vector2.ZERO
	var base_scale: Vector2 = Vector2.ONE
	var shown: bool = true
	var sprite_name: String = ""
	var focus_tween: Tween
	var pop_tween: Tween


var _bg: TextureRect
var _dialog_box: Control
var _name_label: Label
var _text_label: Label
var _fade_rect: ColorRect

var _chars: Dictionary = {}          # String -> CharState
var _tex_cache: Dictionary = {}      # String -> Texture2D
var _steps: Array[Dictionary] = []
var _index: int = -1

var _busy: bool = true               # true = input diabaikan (intro/transisi/akhir)
var _typing: bool = false
var _type_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	_bg = get_node_or_null("Background") as TextureRect
	_dialog_box = get_node_or_null("DialogBox") as Control
	_name_label = get_node_or_null("%NameLabel") as Label
	_text_label = get_node_or_null("%TextLabel") as Label
	_fade_rect = get_node_or_null("Fade") as ColorRect

	var guru_node := get_node_or_null("Guru") as TextureRect
	var nobma_node := get_node_or_null("Nobma") as TextureRect

	if _bg == null or guru_node == null or nobma_node == null \
			or _dialog_box == null or _name_label == null or _text_label == null:
		push_error("opening.gd: node wajib tidak ditemukan (Background, Guru, Nobma, DialogBox, %NameLabel, %TextLabel). Cek struktur opening.tscn.")
		return

	_setup_char(NOBMA, nobma_node, nobma_position, nobma_base_scale, nobma_pivot)
	_setup_char(GURU, guru_node, guru_position, guru_base_scale, guru_pivot)

	_dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.visible_characters = 0
	resized.connect(_relayout)
	_relayout()
	_relayout.call_deferred()

	_steps = _build_script()

	# Kondisi awal (siang, Guru ngajar, Nobma biasa) lalu fade-in dari hitam.
	_set_bg("background_siang.png")
	_set_sprite(GURU, "guru_diam.png", false)
	_set_sprite(NOBMA, "nobma_tegak_biasa.png", false)
	_apply_focus(NARASI, true)

	if _fade_rect != null:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.color = Color(0, 0, 0, 1)
		await _fade_to(0.0, fade_time)

	_busy = false
	_play_from(0)


func _exit_tree() -> void:
	_kill(_type_tween)
	_kill(_fade_tween)
	for k in _chars:
		var cs: CharState = _chars[k]
		_kill(cs.focus_tween)
		_kill(cs.pop_tween)


# ---------------------------------------------------------------- Naskah ----

func _build_script() -> Array[Dictionary]:
	var s: Array[Dictionary] = []

	# --- SIANG ---
	s.append({"who": GURU, "text": "Jadi, kalau kita perhatikan rumus tadi, hasilnya akan berubah tergantung nilai variabelnya. Coba catat baik-baik.", "guru": "guru_bicara.png", "nobma": "nobma_tegak_biasa.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Hoaaam... kenapa suara Pak Guru terdengar seperti lagu pengantar tidur...", "guru": "guru_diam.png", "nobma": "nobma_nunduk_melek.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Mata... berat banget. Merem sebentar aja deh... sebentar...", "nobma": "nobma_nunduk_merem.png"})
	s.append({"who": GURU, "text": "Nobma! Kamu tidur, ya?!", "guru": "guru_marah.png"})
	s.append({"who": NOBMA, "text": "E-eh?! Enggak, Pak!", "nobma": "nobma_tegak_kaget.png"})
	s.append({"who": NOBMA, "text": "Saya nggak tidur kok, Pak. Cuma lagi mikir keras, hehe...", "nobma": "nobma_tegak_melek.png"})
	s.append({"who": GURU, "text": "Ooh... begitu.", "guru": "guru_bicara.png", "nobma": "nobma_tegak_biasa.png"})
	s.append({"who": GURU, "text": "Kalau begitu, tetap fokus. Jangan sampai Bapak lihat kamu merem lagi.", "guru": "guru_marah.png"})
	s.append({"who": NOBMA, "text": "I-iya, Pak. Siap.", "nobma": "nobma_tegak_merem.png"})
	s.append({"who": GURU, "text": "Baik, kita lanjut ke materi berikutnya. Perhatikan papan tulis.", "guru": "guru_bicara.png", "nobma": "nobma_tegak_biasa.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Fokus... fokus... ugh, kepalaku berat...", "guru": "guru_diam.png", "nobma": "nobma_nunduk_melek.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Zzz... zzz...", "nobma": "nobma_nunduk_merem.png"})

	# --- TRANSISI KE MALAM ---
	s.append({"type": "transition", "bg": "background_malam.png", "hide": GURU})

	# --- MALAM ---
	s.append({"who": NARASI, "text": "...beberapa jam kemudian.", "nobma": "nobma_nunduk_merem.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Hah?! Kok... sudah gelap? Kelasnya sepi banget...", "nobma": "nobma_tegak_kaget.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Tunggu... bukannya besok ada PR yang harus dikumpulin?", "nobma": "nobma_tegak_mikir.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Kertas PR-ku... tadi kan ada di laci. Lho? Kok nggak ada?!", "nobma": "nobma_nunduk_melek.png"})
	s.append({"who": NOBMA, "mono": true, "text": "Pasti ini ulah Eko sama Ali. Awas ya, kalian berdua!", "nobma": "nobma_tegak_mikir.png"})

	# --- AKHIR ---
	s.append({"type": "end"})
	return s


# ----------------------------------------------------------- Alur dialog ----

func _input(event: InputEvent) -> void:
	var pressed := false
	if event.is_action_pressed("ui_accept"):
		pressed = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if _busy:
		return
	if _typing:
		_finish_typing()
		return
	_play_from(_index + 1)


func _play_from(start: int) -> void:
	_index = start
	while _index < _steps.size():
		var step: Dictionary = _steps[_index]
		var kind: String = step.get("type", "line")
		match kind:
			"line":
				_show_line(step)
				return
			"transition":
				_busy = true
				await _do_transition(step)
				_busy = false
				_index += 1
			"end":
				_busy = true
				await _finish_cutscene()
				return
			_:
				push_warning("opening.gd: tipe step tidak dikenal: %s" % kind)
				_index += 1
	_busy = true
	await _finish_cutscene()


func _show_line(step: Dictionary) -> void:
	var who: String = step.get("who", NARASI)
	var is_mono: bool = step.get("mono", false)
	var text: String = step.get("text", "")

	if step.has("guru"):
		_set_sprite(GURU, step["guru"], true)
	if step.has("nobma"):
		_set_sprite(NOBMA, step["nobma"], true)

	_apply_focus(who)

	match who:
		GURU:
			_name_label.text = "Pak Guru"
		NOBMA:
			_name_label.text = "Nobma (dalam hati)" if is_mono else "Nobma"
		_:
			_name_label.text = ""
	_name_label.visible = _name_label.text != ""

	var color := mono_text_color if is_mono else normal_text_color
	_text_label.add_theme_color_override("font_color", color)
	_start_typing("(%s)" % text if is_mono else text)


func _do_transition(step: Dictionary) -> void:
	_kill(_type_tween)
	_typing = false
	await _fade_to(1.0, fade_time)

	_dialog_box.visible = false
	if step.has("bg"):
		_set_bg(step["bg"])
	if step.has("hide"):
		var key: String = step["hide"]
		if _chars.has(key):
			var cs: CharState = _chars[key]
			cs.shown = false
			cs.node.visible = false
	_apply_focus(NARASI, true)

	await get_tree().create_timer(0.5).timeout
	_dialog_box.visible = true
	await _fade_to(0.0, fade_time)


func _finish_cutscene() -> void:
	_kill(_type_tween)
	_typing = false
	await _fade_to(1.0, fade_time)
	if next_scene_path.is_empty():
		push_warning("opening.gd: next_scene_path kosong. Isi di Inspector (node Opening).")
		return
	if not ResourceLoader.exists(next_scene_path):
		push_error("opening.gd: scene tujuan tidak ditemukan: %s" % next_scene_path)
		return
	get_tree().change_scene_to_file(next_scene_path)


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
	_type_tween.finished.connect(_on_typing_done)


func _on_typing_done() -> void:
	_typing = false
	_text_label.visible_characters = -1


func _finish_typing() -> void:
	_kill(_type_tween)
	_typing = false
	_text_label.visible_characters = -1


# --------------------------------------------------------------- Karakter ---

func _setup_char(key: String, node: TextureRect, pos_frac: Vector2, base_scale: Vector2, pivot_frac: Vector2) -> void:
	var cs := CharState.new()
	cs.key = key
	cs.node = node
	cs.pos_frac = pos_frac
	cs.pivot_frac = pivot_frac
	cs.base_scale = base_scale
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.scale = base_scale * dim_scale_factor
	node.modulate = dim_color
	_chars[key] = cs
	_layout_char(cs)


## Sprite selalu seukuran layar; posisi & pivot dihitung dari fraksi.
func _layout_char(cs: CharState) -> void:
	cs.node.size = size
	cs.node.pivot_offset = cs.pivot_frac * size
	cs.base_pos = cs.pos_frac * size
	if cs.pop_tween == null or not cs.pop_tween.is_valid():
		cs.node.position = cs.base_pos


func _relayout() -> void:
	for k in _chars:
		_layout_char(_chars[k] as CharState)
	_apply_dialog_style()


func _apply_dialog_style() -> void:
	if _name_label == null or _text_label == null:
		return
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


func _set_sprite(key: String, file_name: String, do_pop: bool) -> void:
	if not _chars.has(key):
		return
	var cs: CharState = _chars[key]
	if cs.sprite_name == file_name:
		return
	var tex := _get_texture(file_name)
	if tex == null:
		return
	cs.node.texture = tex
	cs.sprite_name = file_name
	if do_pop and cs.shown:
		_pop(cs)


func _pop(cs: CharState) -> void:
	_kill(cs.pop_tween)
	cs.node.position = cs.base_pos  # reset dulu supaya tidak pernah melenceng
	var lift := pop_height * size.y
	cs.pop_tween = create_tween()
	cs.pop_tween.tween_property(cs.node, "position:y", cs.base_pos.y - lift, pop_up_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cs.pop_tween.tween_property(cs.node, "position:y", cs.base_pos.y, pop_down_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _apply_focus(speaker: String, instant: bool = false) -> void:
	for k in _chars:
		var cs: CharState = _chars[k]
		if not cs.shown:
			continue
		var active: bool = (cs.key == speaker)
		var target_mod := active_color if active else dim_color
		var target_scale := cs.base_scale if active else cs.base_scale * dim_scale_factor
		_kill(cs.focus_tween)
		if instant:
			cs.node.modulate = target_mod
			cs.node.scale = target_scale
			continue
		cs.focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		cs.focus_tween.tween_property(cs.node, "modulate", target_mod, focus_time)
		cs.focus_tween.tween_property(cs.node, "scale", target_scale, focus_time)


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
		push_warning("opening.gd: aset tidak ditemukan: %s" % path)
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
