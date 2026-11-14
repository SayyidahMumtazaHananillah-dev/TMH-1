extends VBoxContainer

const BLOOD := Color("b3121f")
const DIM := Color("8a8478")
const EXIT_C := Color("c4202c")
const BAR_DARK := Color("2a2622")
const MARGIN_N := 14.0
const MARGIN_H := 23.0
const FONT_PATH := "res://asset/font/Cinzel-Medium.ttf"

var st := {}

func _ready() -> void:
	add_theme_constant_override("separation", 7)
	for b in get_children():
		if b is Button:
			_setup(b)

func _setup(b: Button) -> void:
	var is_exit := b.name == "exit"
	var sb := StyleBoxEmpty.new()
	var ov := Control.new()
	st[b] = {
		"t": 0.0, "line": 0.0, "j": 0.0,
		"base": EXIT_C if is_exit else DIM,
		"hover": BLOOD if is_exit else Color.WHITE,
		"sb": sb, "ov": ov, "tw": null, "twj": null,
	}

	b.flat = false
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(276, 59)
	for n in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(n, sb)

	var fv := FontVariation.new()
	if ResourceLoader.exists(FONT_PATH):
		fv.base_font = load(FONT_PATH)
	else:
		fv.base_font = b.get_theme_font("font")
	fv.spacing_glyph = 8
	b.add_theme_font_override("font", fv)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_constant_override("shadow_offset_x", 0)
	b.add_theme_constant_override("shadow_offset_y", 0)
	b.add_theme_constant_override("shadow_outline_size", 3)

	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.show_behind_parent = true
	b.add_child(ov)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.draw.connect(_draw_overlay.bind(ov, b))

	b.mouse_entered.connect(_go.bind(b, true))
	b.mouse_exited.connect(_go.bind(b, false))
	_apply(b)

# ---------- gambar pelat, garis kiri, garis kanan ----------
func _grad_rect(ov: Control, w: float, h: float, c1: Color, c2: Color) -> void:
	ov.draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([c1, c2, c2, c1]))

func _draw_overlay(ov: Control, b: Button) -> void:
	var s: Dictionary = st[b]
	var w := ov.size.x
	var h := ov.size.y
	var t: float = clampf(s["t"], 0.0, 1.0)
	var ln: float = clampf(s["line"], 0.0, 1.0)
	ov.draw_set_transform(Vector2(s["j"], 0.0))

	_grad_rect(ov, w, h, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0))
	if t > 0.0:
		_grad_rect(ov, w, h, Color(0.7, 0.07, 0.12, 0.28 * t), Color(0.7, 0.07, 0.12, 0.0))

	ov.draw_rect(Rect2(0, 0, 2, h), BAR_DARK)
	if t > 0.0:
		var bh := h * t
		ov.draw_rect(Rect2(0, (h - bh) * 0.5, 2, bh), BLOOD)

	var lw := w * 0.6 * ln
	if lw > 0.5:
		var x0 := w - lw
		var y := floorf(h * 0.5)
		ov.draw_polygon(
			PackedVector2Array([Vector2(x0, y), Vector2(w, y), Vector2(w, y + 1.0), Vector2(x0, y + 1.0)]),
			PackedColorArray([BLOOD, Color(BLOOD, 0.0), Color(BLOOD, 0.0), BLOOD]))

# ---------- terapkan nilai animasi ke teks ----------
func _apply(b: Button) -> void:
	var s: Dictionary = st[b]
	var t: float = clampf(s["t"], 0.0, 1.0)
	var sb: StyleBoxEmpty = s["sb"]
	sb.content_margin_left = MARGIN_N + (MARGIN_H - MARGIN_N) * t + float(s["j"])
	var c: Color = (s["base"] as Color).lerp(s["hover"], t)
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(n, c)
	b.add_theme_color_override("font_shadow_color", Color(BLOOD, 0.35 * t))
	(s["ov"] as Control).queue_redraw()

func _set_t(v: float, b: Button) -> void:
	st[b]["t"] = v
	_apply(b)

func _set_line(v: float, b: Button) -> void:
	st[b]["line"] = v
	(st[b]["ov"] as Control).queue_redraw()

func _set_j(v: float, b: Button) -> void:
	st[b]["j"] = v
	_apply(b)

# ---------- animasi masuk / keluar ----------
func _go(b: Button, on: bool) -> void:
	var s: Dictionary = st[b]
	if s["tw"]:
		(s["tw"] as Tween).kill()
	var tw := b.create_tween().set_parallel(true)
	s["tw"] = tw
	tw.tween_method(_set_t.bind(b), float(s["t"]), 1.0 if on else 0.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_line.bind(b), float(s["line"]), 1.0 if on else 0.0, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if on:
		if s["twj"]:
			(s["twj"] as Tween).kill()
		var tj := b.create_tween()
		s["twj"] = tj
		tj.tween_method(_set_j.bind(b), 0.0, -3.0, 0.075)
		tj.tween_method(_set_j.bind(b), -3.0, 2.0, 0.075)
		tj.tween_method(_set_j.bind(b), 2.0, 0.0, 0.1)
