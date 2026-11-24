extends Node3D

# Sudut berdiri saat dipegang di tangan (sesuaikan X/Y/Z di Inspector crowbar.tscn)
@export var rotasi_dipegang_deg: Vector3 = Vector3(0.0, 0.0, 90.0)

var _sedang_dipegang: bool = false
var _pemegang: Node = null
var _rotasi_awal_deg: Vector3 = Vector3.ZERO
var _kecepatan_lempar: Vector3 = Vector3.ZERO
var _sedang_terlempar: bool = false

func _ready() -> void:
	_rotasi_awal_deg = rotation_degrees

func interact() -> void:
	if _sedang_dipegang:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Tekan E buat lempar item yang sedang dipegang.")
		return

	_rotasi_awal_deg = rotation_degrees
	_sedang_dipegang = true
	_sedang_terlempar = false
	_kecepatan_lempar = Vector3.ZERO
	_pemegang = player
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "crowbar")
		rotation_degrees = rotasi_dipegang_deg
	else:
		if "punya_linggis" in GameManager:
			GameManager.punya_linggis = true
		print("🔧 Kamu menemukan LINGGIS / CROWBAR!")
		queue_free()

func _physics_process(delta: float) -> void:
	if _sedang_terlempar:
		_proses_jatuh_lempar(delta)
		return

	if not _sedang_dipegang:
		return

	if is_instance_valid(_pemegang) and "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_lepas_dari_tangan()
		return

	# Jaga agar tetap berdiri tegak sejak frame pertama dipegang
	rotation_degrees = rotasi_dipegang_deg

func _lepas_dari_tangan() -> void:
	_sedang_dipegang = false
	_pemegang = null
	rotation_degrees = _rotasi_awal_deg
	_set_collision_aktif(true)

func terima_lemparan(impuls: Vector3, _pelempar: Node3D) -> void:
	_sedang_dipegang = false
	_pemegang = null
	rotation_degrees = _rotasi_awal_deg
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

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
