extends Node3D

@export var jarak_pukul: float = 3.0
@export var durasi_store: float = 1.0

var _punya_sapu: bool = false
var _sedang_disimpan: bool = false
var _pemegang: Node3D = null
var _timer_store: float = 0.0
var _sedang_tahan_store: bool = false

func interact() -> void:
	if _punya_sapu or _sedang_disimpan:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Buang pakai E atau simpan pakai G (1s).")
		return

	_punya_sapu = true
	_pemegang = player
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "sapu")
	else:
		visible = false

	print("🧹 Sapu diambil! Tekan F untuk memukul guru, tahan G (1s) untuk simpan, atau E untuk buang.")

func _unhandled_input(event: InputEvent) -> void:
	if not _punya_sapu or _sedang_disimpan or not is_instance_valid(_pemegang):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_ayunkan_sapu()

func _physics_process(delta: float) -> void:
	if not _punya_sapu or _sedang_disimpan or not is_instance_valid(_pemegang):
		return

	# Sinkronkan status kalau item dibuang dari player lewat tombol E
	if "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_lepas_dari_tangan()
		return

	# Tahan G selama 1 detik untuk menyimpan sapu ke inventory
	if Input.is_key_pressed(KEY_G):
		_sedang_tahan_store = true
		_timer_store += delta
		if _timer_store >= durasi_store:
			_simpan_sapu()
	else:
		if _sedang_tahan_store:
			_sedang_tahan_store = false
			_timer_store = 0.0

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

func _simpan_sapu() -> void:
	_sedang_disimpan = true
	_punya_sapu = false
	_sedang_tahan_store = false
	_timer_store = 0.0

	if is_instance_valid(_pemegang):
		if "item_dipegang" in _pemegang and _pemegang.item_dipegang == self:
			_pemegang.item_dipegang = null
		if "_tipe_item_dipegang" in _pemegang:
			_pemegang._tipe_item_dipegang = ""

	print("✅ Sapu disimpan ke inventory!")
	queue_free()

func _lepas_dari_tangan() -> void:
	_punya_sapu = false
	_sedang_tahan_store = false
	_timer_store = 0.0
	_pemegang = null
	_set_collision_aktif(true)

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
