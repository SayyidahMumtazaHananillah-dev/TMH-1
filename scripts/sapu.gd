extends Node3D

@export var jarak_pukul: float = 3.0

var _punya_sapu: bool = false
var _pemegang: Node3D = null
var _kecepatan_lempar: Vector3 = Vector3.ZERO
var _sedang_terlempar: bool = false

func interact() -> void:
	if _punya_sapu:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Tekan E buat lempar item yang sedang dipegang.")
		return

	_punya_sapu = true
	_sedang_terlempar = false
	_kecepatan_lempar = Vector3.ZERO
	_pemegang = player
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "sapu")

	print("🧹 Sapu diambil! Tekan F untuk memukul guru, atau E untuk melempar.")

func _unhandled_input(event: InputEvent) -> void:
	if not _punya_sapu or not is_instance_valid(_pemegang):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_ayunkan_sapu()

func _physics_process(delta: float) -> void:
	if _sedang_terlempar:
		_proses_jatuh_lempar(delta)
		return

	if not _punya_sapu:
		return

	# Kalau sapu dilempar dari player lewat tombol E, lepaskan status pegang
	if is_instance_valid(_pemegang) and "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_lepas_dari_tangan()

func _ayunkan_sapu() -> void:
	var guru := get_tree().get_first_node_in_group("guru") as Node3D
	if guru == null:
		print("🧹 Sapu diayunkan, tapi tidak ada guru di dekat sini.")
		return

	var jarak := _pemegang.global_position.distance_to(guru.global_position)
	if jarak <= jarak_pukul and guru.has_method("kena_sapu"):
		guru.kena_sapu()
		print("💥 Guru kena pukul sapu!")
	else:
		print("🧹 Sapu diayunkan meleset (jarak ke guru: %.1f m)." % snapped(jarak, 0.1))

func _lepas_dari_tangan() -> void:
	_punya_sapu = false
	_pemegang = null
	_set_collision_aktif(true)

func terima_lemparan(impuls: Vector3, _pelempar: Node3D) -> void:
	_punya_sapu = false
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

	# Redam gerak mendatar biar nggak meluncur kejauhan
	_kecepatan_lempar.x = move_toward(_kecepatan_lempar.x, 0.0, 5.0 * delta)
	_kecepatan_lempar.z = move_toward(_kecepatan_lempar.z, 0.0, 5.0 * delta)

	# Cek tanah di bawah sapu saat sedang turun
	if _kecepatan_lempar.y <= 0.0:
		var space := get_world_3d().direct_space_state
		var start := global_position + Vector3(0.0, 0.25, 0.0)
		var end := global_position + Vector3(0.0, -2.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var lantai_y := (hit.position as Vector3).y + 0.04
			if global_position.y <= lantai_y:
				global_position.y = lantai_y
				_kecepatan_lempar = Vector3.ZERO
				_sedang_terlempar = false

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
