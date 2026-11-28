class_name BadEnding
extends Control
## Cutscene Bad Ending (Godot 4.x, typed GDScript).
## Tanpa aset gambar: semua visual dari ColorRect / Label + Tween.
## Simpan di: res://scripts/bad_ending.gd

signal ending_finished   ## dipancarkan saat pemain memilih lanjut (menu utama)
signal retry_requested   ## dipancarkan saat pemain memilih coba lagi

enum State { IDLE, TYPING, WAITING, OUTRO, TITLE, READY, EXITING }

## Isi cerita. "red" = intensitas kemerahan layar (0..1), "shake" = kekuatan getar (piksel).
const STORY: Array = [
	{"text": "Lorong itu seharusnya sudah Nobma hafal di luar kepala.\nLima kali ia mencoba. Lima kali ia berakhir di tempat yang sama.", "red": 0.0, "shake": 0.0},
	{"text": "Langkah sepatu yang bukan miliknya terdengar semakin dekat.\nLampu koridor berkedip... lalu padam satu per satu.", "red": 0.15, "shake": 0.0},
	{"text": "Gerbang sekolah terlihat di ujung halaman.\nHanya dua puluh meter dari kata \"pulang\".", "red": 0.2, "shake": 0.0},
	{"text": "Tangannya masih mencengkeram buku PR yang kusut itu.\nSatu-satunya hal yang berhasil ia selamatkan malam ini.", "red": 0.25, "shake": 0.0},
	{"text": "Ironis, bukan?\nIa berlari dari sekolah demi PR yang tak pernah sempat dikumpulkan.", "red": 0.3, "shake": 0.0},
	{"text": "Sesuatu di belakangnya berhenti berjalan.\nDan mendadak, semuanya menjadi sangat... tenang.", "red": 0.55, "shake": 9.0},
	{"text": "Pagi harinya, sekolah dibuka seperti biasa.\nBel berbunyi. Para siswa tertawa di koridor.", "red": 0.0, "shake": 0.0},
	{"text": "Di meja guru, buku absensi mencatat satu nama dengan tinta merah:\nNobma — tidak mengumpulkan PR.", "red": 0.3, "shake": 3.0},
	{"text": "Dan di laci bangku paling belakang, sebuah buku PR masih tergeletak,\nhalaman terakhirnya belum kering...\nmenunggu murid berikutnya.", "red": 0.4, "shake": 0.0},
]

@export_group("Pemicu")
## Jumlah kematian/kegagalan saat ini (diisi oleh pemanggil bila perlu).
@export var death_count: int = 5
## Batas kematian agar Bad Ending boleh diputar.
@export var required_deaths: int = 5
## Mulai otomatis saat scene dimuat.
@export var autoplay: bool = true

@export_group("Navigasi")
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main_menu.tscn"
## Kosongkan bila tidak ada opsi "Coba Lagi".
@export_file("*.tscn") var retry_scene: String = ""

@export_group("Timing")
@export_range(5.0, 120.0, 1.0) var chars_per_second: float = 28.0
@export var auto_advance: bool = false
@export_range(0.5, 10.0, 0.1) var auto_advance_delay: float = 2.5
## Jeda minimum antar input agar klik/Spasi cepat tidak melompati dua baris sekaligus.
@export_range(0.0, 1.0, 0.05) var input_cooldown: float = 0.15

var _state: State = State.IDLE
var _line_index: int = -1
var shake_amount: float = 0.0
var _last_input_msec: int = 0
var _nodes_ok: bool = false

var _type_tween: Tween
var _wait_tween: Tween
var _fx_tween: Tween
var _shake_tween: Tween
var _outro_tween: Tween
var _hint_tween: Tween
var _exit_tween: Tween

@onready var _content: Control = get_node_or_null("%Content") as Control
@onready var _red_overlay: ColorRect = get_node_or_null("%RedOverlay") as ColorRect
@onready var _story_label: Label = get_node_or_null("%StoryLabel") as Label
@onready var _title_label: Label = get_node_or_null("%TitleLabel") as Label
@onready var _subtitle_label: Label = get_node_or_null("%SubtitleLabel") as Label
@onready var _hint_label: Label = get_node_or_null("%HintLabel") as Label
@onready var _fade_rect: ColorRect = get_node_or_null("%FadeRect") as ColorRect


## Helper statis: panggil dari mana saja untuk mengecek apakah Bad Ending harus dipicu.
static func should_trigger(current_deaths: int, required: int = 5) -> bool:
	return current_deaths >= required


func _ready() -> void:
	set_process(false)
	_nodes_ok = _validate_nodes()
	if not _nodes_ok:
		return
	_reset_visuals()
	_title_label.resized.connect(_update_pivot)
	_update_pivot()
	if autoplay:
		start()


func _exit_tree() -> void:
	_kill_all_tweens()


## Mulai cutscene. Aman dipanggil manual bila autoplay = false.
func start() -> void:
	if not _nodes_ok or _state != State.IDLE:
		return
	if not should_trigger(death_count, required_deaths):
		push_warning("BadEnding: death_count (%d) < required_deaths (%d), cutscene tidak diputar." % [death_count, required_deaths])
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_line(0)


# ---------------------------------------------------------------- cerita

func _show_line(index: int) -> void:
	_kill(_type_tween)
	_kill(_wait_tween)
	_line_index = index
	var data: Dictionary = STORY[index]
	var text: String = str(data.get("text", ""))
	_story_label.text = text
	_story_label.modulate.a = 1.0
	_story_label.visible_ratio = 0.0
	_set_red(float(data.get("red", 0.0)))
	_pulse_shake(float(data.get("shake", 0.0)))
	_state = State.TYPING
	var duration: float = maxf(float(text.length()) / maxf(chars_per_second, 1.0), 0.1)
	_type_tween = create_tween()
	_type_tween.tween_property(_story_label, "visible_ratio", 1.0, duration)
	_type_tween.finished.connect(_on_typing_done)


func _skip_typing() -> void:
	if _state != State.TYPING:
		return
	_kill(_type_tween)
	_story_label.visible_ratio = 1.0
	_on_typing_done()


func _on_typing_done() -> void:
	if _state != State.TYPING:
		return
	_state = State.WAITING
	if auto_advance:
		_kill(_wait_tween)
		_wait_tween = create_tween()
		_wait_tween.tween_interval(auto_advance_delay)
		_wait_tween.tween_callback(_next_line)


func _next_line() -> void:
	if _state != State.WAITING:
		return
	_kill(_wait_tween)
	var next_index: int = _line_index + 1
	if next_index >= STORY.size():
		_begin_outro()
	else:
		_show_line(next_index)


# ---------------------------------------------------------------- outro & judul

func _begin_outro() -> void:
	_state = State.OUTRO
	_kill(_type_tween)
	_kill(_wait_tween)
	_kill(_outro_tween)
	_set_red(0.0)
	_outro_tween = create_tween()
	_outro_tween.tween_property(_story_label, "modulate:a", 0.0, 1.6)
	_outro_tween.tween_interval(0.9)
	_outro_tween.tween_callback(_show_title)


func _show_title() -> void:
	_state = State.TITLE
	_kill(_outro_tween)
	_title_label.modulate.a = 0.0
	_title_label.scale = Vector2(1.35, 1.35)
	_subtitle_label.modulate.a = 0.0
	_pulse_shake(6.0)
	_set_red(0.3)
	_outro_tween = create_tween()
	_outro_tween.set_parallel(true)
	_outro_tween.tween_property(_title_label, "modulate:a", 1.0, 1.2)
	_outro_tween.tween_property(_title_label, "scale", Vector2.ONE, 1.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_outro_tween.chain().tween_property(_subtitle_label, "modulate:a", 1.0, 1.0)
	_outro_tween.chain().tween_callback(_on_title_shown)


func _on_title_shown() -> void:
	if _state != State.TITLE:
		return
	_state = State.READY
	var hint: String = "[Spasi / Enter / Klik]  Menu Utama"
	if not retry_scene.is_empty():
		hint += "      [R]  Coba Lagi"
	_hint_label.text = hint
	_hint_label.modulate.a = 0.0
	_kill(_hint_tween)
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.8)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.35, 0.8)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not _nodes_ok or _state == State.IDLE or _state == State.EXITING:
		return

	var is_confirm: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")
	var is_retry: bool = false

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			is_confirm = true
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_R:
			is_retry = true

	if not (is_confirm or is_retry):
		return

	var now: int = Time.get_ticks_msec()
	if now - _last_input_msec < int(input_cooldown * 1000.0):
		return
	_last_input_msec = now

	if is_retry:
		if _state == State.READY and not retry_scene.is_empty():
			_exit(true)
			get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()
	match _state:
		State.TYPING:
			_skip_typing()
		State.WAITING:
			_next_line()
		State.READY:
			_exit(false)
		_:
			pass


# ---------------------------------------------------------------- keluar

func _exit(go_retry: bool) -> void:
	if _state == State.EXITING:
		return
	_state = State.EXITING
	_kill(_hint_tween)
	_kill(_exit_tween)
	var path: String = retry_scene if go_retry else main_menu_scene
	_exit_tween = create_tween()
	_exit_tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.8)
	_exit_tween.tween_callback(_change_scene.bind(path, go_retry))


func _change_scene(path: String, go_retry: bool) -> void:
	if go_retry:
		retry_requested.emit()
	else:
		ending_finished.emit()

	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("BadEnding: scene tujuan tidak valid: '%s'. Atur di Inspector." % path)
		# Jangan biarkan pemain terjebak di layar hitam.
		_kill(_exit_tween)
		_exit_tween = create_tween()
		_exit_tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.5)
		_state = State.READY
		return

	if not is_inside_tree():
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("BadEnding: gagal pindah scene (%s), error %d." % [path, err])


# ---------------------------------------------------------------- efek

func _set_red(amount: float) -> void:
	_kill(_fx_tween)
	var target: float = clampf(amount, 0.0, 1.0) * 0.55
	_fx_tween = create_tween()
	_fx_tween.tween_property(_red_overlay, "modulate:a", target, 1.0)


func _pulse_shake(strength: float) -> void:
	if strength <= 0.0:
		return
	_kill(_shake_tween)
	shake_amount = strength
	set_process(true)
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "shake_amount", 0.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if _content == null:
		set_process(false)
		return
	if shake_amount <= 0.05:
		shake_amount = 0.0
		_content.position = Vector2.ZERO
		set_process(false)
		return
	_content.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount


func _update_pivot() -> void:
	if _title_label != null:
		_title_label.pivot_offset = _title_label.size / 2.0


# ---------------------------------------------------------------- util

func _reset_visuals() -> void:
	_red_overlay.modulate.a = 0.0
	_story_label.text = ""
	_story_label.visible_ratio = 0.0
	_story_label.modulate.a = 1.0
	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	_hint_label.modulate.a = 0.0
	_fade_rect.modulate.a = 0.0
	_content.position = Vector2.ZERO


func _validate_nodes() -> bool:
	var missing: PackedStringArray = []
	var checks: Dictionary = {
		"Content": _content, "RedOverlay": _red_overlay, "StoryLabel": _story_label,
		"TitleLabel": _title_label, "SubtitleLabel": _subtitle_label,
		"HintLabel": _hint_label, "FadeRect": _fade_rect,
	}
	for node_name: String in checks:
		if checks[node_name] == null:
			missing.append(node_name)
	if not missing.is_empty():
		push_error("BadEnding: node tidak ditemukan (aktifkan 'Access as Unique Name'): %s" % ", ".join(missing))
		return false
	return true


func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


func _kill_all_tweens() -> void:
	for t: Tween in [_type_tween, _wait_tween, _fx_tween, _shake_tween, _outro_tween, _hint_tween, _exit_tween]:
		_kill(t)


func _on_audio_stream_player_finished() -> void:
	$AudioStreamPlayer.play()
