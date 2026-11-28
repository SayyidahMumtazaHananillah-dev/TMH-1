extends Node3D

var sfx_alarm: AudioStream = preload("res://assets/sfx/microsammy-clock-alarm-8761.mp3")

var _sedang_dipegang: bool = false
var _pemegang: Node = null
var _sudah_bunyi: bool = false   # alarm cuma bisa bunyi 1x seumur hidup
var _audio_player: AudioStreamPlayer3D

var _kecepatan_lempar: Vector3 = Vector3.ZERO
var _sedang_terlempar: bool = false

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	if sfx_alarm:
		_audio_player.stream = sfx_alarm
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_audio_player.unit_size = 5.0     # makin kecil = makin cepat samar
	_audio_player.max_distance = 40.0 # lebih jauh dari ini suara hilang
	add_child(_audio_player)

func interact() -> void:
	if _sedang_dipegang:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Tekan E buat lempar item yang sedang dipegang.")
		return

	_aktifkan_ke_tangan(player)

func _aktifkan_ke_tangan(player: Node) -> void:
	_sedang_dipegang = true
	_sedang_terlempar = false
	_kecepatan_lempar = Vector3.ZERO
	_pemegang = player
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "alarm")

	# Bunyi cuma pas pertama kali diambil. Kalau sudah pernah, diam saja.
	if not _sudah_bunyi:
		_sudah_bunyi = true
		_picu_bunyi_alarm()
		print("🚨 TRAP ALARM! Bunyi sekali sampai habis!")

func _physics_process(delta: float) -> void:
	if _sedang_terlempar:
		_proses_jatuh_lempar(delta)

	if not _sedang_dipegang:
		return

	# Kalau item dilempar lewat E dari player, lepaskan alarm (suara tetap lanjut)
	if is_instance_valid(_pemegang) and "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_lepas_paksa()

func terima_lemparan(impuls: Vector3, _pelempar: Node3D) -> void:
	_sedang_dipegang = false
	_pemegang = null

	_sedang_terlempar = true
	_kecepatan_lempar = impuls
	_set_collision_aktif(true)

func _proses_jatuh_lempar(delta: float) -> void:
	if not _sedang_terlempar:
		return

	var grav := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_kecepatan_lempar.y -= grav * delta

	var langkah := _kecepatan_lempar * delta
	if langkah.length() > 0.0001:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + langkah + langkah.normalized() * 0.14)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var normal := hit.normal as Vector3
			global_position = (hit.position as Vector3) + normal * 0.14
			_kecepatan_lempar.x = 0.0
			_kecepatan_lempar.z = 0.0
			if normal.y < 0.5:
				_kecepatan_lempar.y = minf(_kecepatan_lempar.y, -1.5)
			else:
				_kecepatan_lempar.y = 0.0

	global_position += _kecepatan_lempar * delta

	_kecepatan_lempar.x = move_toward(_kecepatan_lempar.x, 0.0, 5.0 * delta)
	_kecepatan_lempar.z = move_toward(_kecepatan_lempar.z, 0.0, 5.0 * delta)

	if _kecepatan_lempar.y <= 0.0:
		var space := get_world_3d().direct_space_state
		var start := global_position + Vector3(0.0, 0.25, 0.0)
		var end := global_position + Vector3(0.0, -2.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var lantai_y := (hit.position as Vector3).y + 0.05
			if global_position.y <= lantai_y:
				global_position.y = lantai_y
				_kecepatan_lempar = Vector3.ZERO
				_sedang_terlempar = false

func _picu_bunyi_alarm() -> void:
	if _audio_player and _audio_player.stream:
		_audio_player.play()

	var posisi_suara := global_position
	if is_instance_valid(_pemegang) and _pemegang is Node3D:
		posisi_suara = (_pemegang as Node3D).global_position

	print("🔊 TIIIT-TIIIT! Alarm trap menyala, memancing guru!")
	var guru := get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(posisi_suara)

func _lepas_paksa() -> void:
	_sedang_dipegang = false
	_pemegang = null
	_set_collision_aktif(true)

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
