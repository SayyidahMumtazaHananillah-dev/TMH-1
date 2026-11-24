extends Node3D

var _sedang_dipegang: bool = false
var _pemegang: Node = null
var _kecepatan_lempar: Vector3 = Vector3.ZERO
var _sedang_terlempar: bool = false

func interact() -> void:
	if _sedang_dipegang:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Tekan E buat lempar item yang sedang dipegang.")
		return

	_sedang_dipegang = true
	_sedang_terlempar = false
	_kecepatan_lempar = Vector3.ZERO
	_pemegang = player
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "kunci_gerbang")
	else:
		if "punya_kunci_gerbang" in GameManager:
			GameManager.punya_kunci_gerbang = true
		print("🗝️ Kunci Gerbang berhasil diambil!")
		queue_free()

func _physics_process(delta: float) -> void:
	if _sedang_terlempar:
		_proses_jatuh_lempar(delta)
		return

	if not _sedang_dipegang:
		return

	# Kalau dilempar lewat E, item_dipegang di player akan berubah/kosong
	if is_instance_valid(_pemegang) and "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_sedang_dipegang = false
		_pemegang = null
		_set_collision_aktif(true)

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
	global_position += _kecepatan_lempar * delta

	# Redam gerak mendatar biar nggak meluncur kejauhan
	_kecepatan_lempar.x = move_toward(_kecepatan_lempar.x, 0.0, 5.0 * delta)
	_kecepatan_lempar.z = move_toward(_kecepatan_lempar.z, 0.0, 5.0 * delta)

	# Cek tanah di bawah kunci gerbang saat sedang turun
	if _kecepatan_lempar.y <= 0.0:
		var space := get_world_3d().direct_space_state
		var start := global_position + Vector3(0.0, 0.25, 0.0)
		var end := global_position + Vector3(0.0, -0.35, 0.0)
		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			global_position.y = (hit.position as Vector3).y + 0.04
			_kecepatan_lempar = Vector3.ZERO
			_sedang_terlempar = false

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
