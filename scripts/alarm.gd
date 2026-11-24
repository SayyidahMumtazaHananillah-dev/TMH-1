extends Node3D

@export var durasi_matikan: float = 1.5
@export var interval_bunyi_ulang: float = 2.0
@export var sfx_alarm: AudioStream

var _sedang_dipegang: bool = false
var _alarm_aktif: bool = false
var _pemegang: Node = null
var _timer_matikan: float = 0.0
var _sedang_tahan_matikan: bool = false
var _timer_bunyi_ulang: float = 0.0
var _audio_player: AudioStreamPlayer3D

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	if sfx_alarm:
		_audio_player.stream = sfx_alarm
	add_child(_audio_player)

func interact() -> void:
	if _sedang_dipegang:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Buang item yang sedang dipegang pakai E dulu.")
		return

	_sedang_dipegang = true
	_alarm_aktif = true
	_pemegang = player
	_timer_matikan = 0.0
	_sedang_tahan_matikan = false
	_timer_bunyi_ulang = interval_bunyi_ulang
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "alarm")

	_picu_bunyi_alarm()
	print("🚨 TRAP ALARM! Otomatis bunyi! Tahan F (%.1fs) untuk mematikan alarm!" % durasi_matikan)

func _physics_process(delta: float) -> void:
	if not _sedang_dipegang:
		return

	# Kalau item dibuang lewat E dari player, lepaskan alarm & hentikan suara
	if is_instance_valid(_pemegang) and "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_lepas_paksa()
		return

	if _alarm_aktif:
		_timer_bunyi_ulang -= delta
		if _timer_bunyi_ulang <= 0.0:
			_timer_bunyi_ulang = interval_bunyi_ulang
			_picu_bunyi_alarm()

		# Tahan F selama 1.5 detik untuk mematikan alarm
		if Input.is_key_pressed(KEY_F):
			_sedang_tahan_matikan = true
			_timer_matikan += delta
			if _timer_matikan >= durasi_matikan:
				_matikan_alarm()
		else:
			if _sedang_tahan_matikan:
				_sedang_tahan_matikan = false
				_timer_matikan = 0.0

func _picu_bunyi_alarm() -> void:
	if _audio_player and _audio_player.stream:
		if not _audio_player.playing:
			_audio_player.play()

	var posisi_suara := global_position
	if is_instance_valid(_pemegang) and _pemegang is Node3D:
		posisi_suara = (_pemegang as Node3D).global_position

	print("🔊 TIIIT-TIIIT! Alarm trap menyala, memancing guru!")
	var guru := get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(posisi_suara)

func _matikan_alarm() -> void:
	_alarm_aktif = false
	_sedang_dipegang = false
	_sedang_tahan_matikan = false
	_timer_matikan = 0.0

	if _audio_player and _audio_player.playing:
		_audio_player.stop()

	if is_instance_valid(_pemegang):
		if "item_dipegang" in _pemegang and _pemegang.item_dipegang == self:
			_pemegang.item_dipegang = null
		if "_tipe_item_dipegang" in _pemegang:
			_pemegang._tipe_item_dipegang = ""
		if "_sedang_tahan_store" in _pemegang:
			_pemegang._sedang_tahan_store = false
		if "_timer_store" in _pemegang:
			_pemegang._timer_store = 0.0

	print("🔇 Alarm berhasil dimatikan dan dilepas!")
	queue_free()

func _lepas_paksa() -> void:
	_alarm_aktif = false
	_sedang_dipegang = false
	_sedang_tahan_matikan = false
	_timer_matikan = 0.0
	_pemegang = null
	if _audio_player and _audio_player.playing:
		_audio_player.stop()
	_set_collision_aktif(true)

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
