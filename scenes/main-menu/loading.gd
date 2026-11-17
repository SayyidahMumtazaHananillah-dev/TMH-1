extends Control

# Scene tujuan (diisi otomatis dari main menu lewat meta, lihat contoh _on_play di bawah).
@export_file("*.tscn") var target_scene: String = "res://scenes/main-map/main.tscn"

const FALLBACK_SCENE := "res://scenes/main-menu/main_menu.tscn"   # dipakai kalau target kosong / tidak ketemu
const META_KEY := "loading_target"

const READY_SIGNAL := "game_ready"   # opsional: signal dari root scene game kalau butuh waktu ekstra
const READY_TIMEOUT := 15.0          # batas tunggu signal di atas (detik)
const FADE_IN := 0.4
const FADE_OUT := 0.9                # transisi redup ke gameplay

# --- loading bar (tengah bawah) ---
const BAR_W := 460.0
const BAR_H := 22.0
const BAR_BOTTOM_MARGIN := 70.0      # jarak bar dari tepi bawah layar
const BAR_FILL_SPEED := 0.7          # kecepatan isi bar (1.0 = penuh dalam 1 detik)

var _layer: CanvasLayer
var _holder: Control
var _bar: ChalkBar
var _t := 0.0
var _requested := false
var _done := false
var _game_ready := false
var _target := 0.0     # progres sebenarnya (0..1)
var _shown := 0.0      # progres yang ditampilkan di bar (dihaluskan)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)

	# target dari main menu
	var root := get_tree().root
	if root.has_meta(META_KEY):
		target_scene = String(root.get_meta(META_KEY))
		root.remove_meta(META_KEY)

	# Gambar-gambar yang sudah kamu pasang di scene (TextureRect) dipindah ke CanvasLayer
	# paling atas, supaya tetap kelihatan menutupi game yang sedang disiapkan di belakangnya.
	var existing: Array[Node] = []
	for c in get_children():
		existing.append(c)

	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_STOP   # blok klik selama loading
	_holder.modulate.a = 0.0
	_layer.add_child(_holder)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for c in existing:
		c.reparent(_holder, false)

	_build_bar()

	create_tween().tween_property(_holder, "modulate:a", 1.0, FADE_IN)

	if target_scene != "" and ResourceLoader.exists(target_scene):
		ResourceLoader.load_threaded_request(target_scene)
		_requested = true
	else:
		push_warning("Loading: target_scene kosong / path salah: '" + target_scene + "'. Kembali ke " + FALLBACK_SCENE)


func _build_bar() -> void:
	_bar = ChalkBar.new()
	_bar.bar_w = BAR_W
	_bar.bar_h = BAR_H
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_bar)

	# tengah bawah
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -BAR_W * 0.5
	_bar.offset_right = BAR_W * 0.5
	_bar.offset_bottom = -BAR_BOTTOM_MARGIN
	_bar.offset_top = -BAR_BOTTOM_MARGIN - BAR_H
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	_t += delta

	# bar naik halus menuju progres, tidak pernah mundur
	_shown = move_toward(_shown, _target, delta * BAR_FILL_SPEED)
	_bar.progress = _shown
	_bar.queue_redraw()

	if _done or not _requested:
		if not _done and not _requested:
			_finish(null)
		return

	var prog: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_scene, prog)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var real: float = (prog[0] if prog.size() > 0 else 0.0) * 0.8
			var creep := minf(0.6, _t * 0.2)       # biar bar tetap bergerak walau engine tidak lapor progres
			_target = maxf(_target, maxf(real, creep))
		ResourceLoader.THREAD_LOAD_LOADED:
			_target = maxf(_target, 0.85)
			_finish(ResourceLoader.load_threaded_get(target_scene) as PackedScene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Loading: gagal memuat " + target_scene)
			_finish(null)


func _finish(packed: PackedScene) -> void:
	_done = true

	# gagal / kosong -> balik ke main menu
	if packed == null:
		var back := create_tween()
		back.tween_property(_holder, "modulate:a", 0.0, FADE_IN)
		back.tween_callback(func():
			if ResourceLoader.exists(FALLBACK_SCENE):
				get_tree().change_scene_to_file(FALLBACK_SCENE))
		return

	# Scene game dibuat & di-_ready() SELAGI loading masih tampil di atasnya
	var game := packed.instantiate()
	if game.has_signal(READY_SIGNAL):
		game.connect(READY_SIGNAL, func(): _game_ready = true)
	get_tree().root.add_child(game)
	_target = maxf(_target, 0.95)
	await get_tree().process_frame
	await get_tree().process_frame

	# opsional: tunggu signal "game_ready" dari root scene game
	if game.has_signal(READY_SIGNAL):
		var waited := 0.0
		while not _game_ready and waited < READY_TIMEOUT:
			await get_tree().process_frame
			waited += get_process_delta_time()

	# game siap -> bar penuh dulu, baru loading meredup ke gameplay
	_target = 1.0
	while _shown < 0.999:
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout

	get_tree().current_scene = game
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var out := create_tween()
	out.tween_property(_holder, "modulate:a", 0.0, FADE_OUT)
	await out.finished
	queue_free()


# =====================================================================
#  Loading bar gaya sketsa kapur: garis tepi bergetar ganda, isi berupa arsiran
#  miring yang "bergoyang" (boil), tanda 25% di bawah, dan selembar kertas kecil
#  yang melayang di ujung isi bar.
# =====================================================================
class ChalkBar extends Control:
	const CHALK := Color("e6dcc6")

	var progress := 0.0
	var bar_w := 460.0
	var bar_h := 22.0

	func _draw() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var rng := RandomNumberGenerator.new()
		rng.seed = int(now * 9.0) * 7919 + 13      # ~9 fps -> efek gambar tangan bergetar

		# badan gelap
		draw_rect(Rect2(0, 0, bar_w, bar_h), Color(0, 0, 0, 0.75))

		var inset := 5.0
		var top := inset
		var bot := bar_h - inset
		var xs := inset
		var xe := inset + (bar_w - inset * 2.0) * progress

		# isi: dasar tipis + arsiran miring
		if xe - xs > 0.5:
			draw_rect(Rect2(xs, top, xe - xs, bot - top), Color(CHALK, 0.2))
			var hh := bot - top
			var x0 := xs - hh
			while x0 < xe:
				var a := Vector2(x0 + rng.randf_range(-0.8, 0.8), bot + rng.randf_range(-0.6, 0.6))
				var b := Vector2(x0 + hh + rng.randf_range(-0.8, 0.8), top + rng.randf_range(-0.6, 0.6))
				var seg: Variant = _clip_x(a, b, xs, xe)
				if seg != null:
					draw_line(seg[0], seg[1], Color(CHALK, 0.92), 1.7, true)
				x0 += 4.0
			# tepi depan isi
			draw_line(Vector2(xe, top - 1.5), Vector2(xe + rng.randf_range(-0.8, 0.8), bot + 1.5), CHALK, 2.4, true)

		# garis tepi ganda
		draw_polyline(_rounded(rng, 1.0), CHALK, 2.2, true)
		draw_polyline(_rounded(rng, 1.7), Color(CHALK, 0.5), 1.2, true)

		# tanda 0 / 25 / 50 / 75 / 100 %
		for i in 5:
			var f := float(i) / 4.0
			var x := inset + (bar_w - inset * 2.0) * f
			var lit := progress >= f - 0.001
			var h := 9.0 if (i == 0 or i == 4) else 6.0
			draw_line(Vector2(x + rng.randf_range(-0.6, 0.6), bar_h + 5.0),
				Vector2(x + rng.randf_range(-0.6, 0.6), bar_h + 5.0 + h),
				Color(CHALK, 1.0 if lit else 0.35), 1.8, true)

		# kertas kecil melayang di ujung isi
		var px := clampf(xe, 12.0, bar_w - 12.0)
		var py := -15.0 + sin(now * 6.0) * 2.5
		draw_set_transform(Vector2(px, py), sin(now * 4.0) * 0.3 + 0.1, Vector2(1.0, 1.0))
		var paper := PackedVector2Array([
			Vector2(-8, -10), Vector2(3, -10), Vector2(8, -5),
			Vector2(8, 10), Vector2(-5, 10), Vector2(-8, 7),
		])
		draw_colored_polygon(paper, Color.BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(3, -10), Vector2(3, -5), Vector2(8, -5)]), Color(CHALK, 0.5))
		draw_line(Vector2(-5, -1), Vector2(5, -1.5), Color(CHALK, 0.9), 1.3, true)
		draw_line(Vector2(-5, 3), Vector2(5, 2.5), Color(CHALK, 0.9), 1.3, true)
		draw_line(Vector2(-5, 7), Vector2(1, 6.5), Color(CHALK, 0.9), 1.3, true)
		var outline := paper.duplicate()
		outline.append(paper[0])
		draw_polyline(outline, CHALK, 1.7, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))

	func _clip_x(a: Vector2, b: Vector2, xs: float, xe: float) -> Variant:
		var d := b - a
		if absf(d.x) < 0.001:
			return null
		var t0 := clampf((xs - a.x) / d.x, 0.0, 1.0)
		var t1 := clampf((xe - a.x) / d.x, 0.0, 1.0)
		if t1 <= t0:
			return null
		return PackedVector2Array([a + d * t0, a + d * t1])

	# persegi panjang dengan sudut membulat, titiknya digoyang sedikit seperti digambar tangan
	func _rounded(rng: RandomNumberGenerator, amt: float) -> PackedVector2Array:
		var rad := 7.0
		var cs: Array[Vector2] = [
			Vector2(rad, rad), Vector2(bar_w - rad, rad),
			Vector2(bar_w - rad, bar_h - rad), Vector2(rad, bar_h - rad),
		]
		var starts: Array[float] = [PI, PI * 1.5, 0.0, PI * 0.5]
		var pts := PackedVector2Array()
		for i in 4:
			for k in 5:
				var an: float = starts[i] + (PI * 0.5) * float(k) / 4.0
				pts.append(cs[i] + Vector2(cos(an), sin(an)) * rad + _j(rng, amt))
			var from: Vector2 = pts[pts.size() - 1]
			var ni := (i + 1) % 4
			var to := cs[ni] + Vector2(cos(starts[ni]), sin(starts[ni])) * rad
			var n := int(from.distance_to(to) / 40.0)
			for m in range(1, n):
				pts.append(from.lerp(to, float(m) / float(n)) + _j(rng, amt))
		pts.append(pts[0])
		return pts

	func _j(rng: RandomNumberGenerator, amt: float) -> Vector2:
		return Vector2(rng.randf_range(-amt, amt), rng.randf_range(-amt, amt))
