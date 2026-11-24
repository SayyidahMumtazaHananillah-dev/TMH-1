extends Node

@export var scene_kertas_soal: PackedScene
@export var scene_crowbar: PackedScene
@export var scene_kunci_perpus: PackedScene

@export var total_kertas_soal: int = 5
@export var total_crowbar: int = 1
@export var jumlah_soal_ke_tong_sampah: int = 2
@export var crowbar_ke_tong_sampah: bool = true

@onready var wadah_item: Node = get_parent().get_node_or_null("item")

var _spot_terpakai: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	sebarkan_item()

func sebarkan_item() -> void:
	_spot_terpakai.clear()

	var ruangan_list: Array = get_tree().get_nodes_in_group("ruangan_spawn")
	var rak_list: Array = get_tree().get_nodes_in_group("spawn_rak")
	var tong_list: Array = get_tree().get_nodes_in_group("spawn_tong_sampah")

	# 1. Kunci resepsionis diacak ke salah satu rak buku (maksimal 1 rak)
	if not rak_list.is_empty():
		rak_list.shuffle()
		for rak in rak_list:
			if "antrean_isi" in rak:
				rak.antrean_isi.append("kunci_resepsionis")
				print("🔑 [Spawner] kunci_resepsionis masuk ke rak: ", rak.name)
				break
	else:
		push_warning("Group 'spawn_rak' masih kosong!")

	# Kumpulkan semua node tong sampah yang punya variabel antrean_isi
	var tong_valid: Array = []
	for t in tong_list:
		if "antrean_isi" in t:
			tong_valid.append(t)
	tong_valid.shuffle()

	var sisa_soal: int = total_kertas_soal
	var sisa_crowbar: int = total_crowbar

	# 2. Masukkan jatah item eksplisit ke tong sampah dulu
	if not tong_valid.is_empty():
		var t_idx: int = 0

		var target_soal_tong: int = min(jumlah_soal_ke_tong_sampah, sisa_soal)
		for i in range(target_soal_tong):
			var tong: Node = tong_valid[t_idx % tong_valid.size()]
			t_idx += 1
			tong.antrean_isi.append("kertas_soal")
			sisa_soal -= 1
			print("🗑️ [Spawner] kertas_soal masuk antrean tong sampah: ", tong.name)

		if crowbar_ke_tong_sampah and sisa_crowbar > 0:
			var tong_cb: Node = tong_valid[t_idx % tong_valid.size()]
			t_idx += 1
			tong_cb.antrean_isi.append("crowbar")
			sisa_crowbar -= 1
			print("🗑️ [Spawner] crowbar masuk antrean tong sampah: ", tong_cb.name)
	else:
		push_warning("Group 'spawn_tong_sampah' kosong atau tidak punya 'antrean_isi'!")

	if ruangan_list.is_empty():
		push_warning("Group 'ruangan_spawn' masih kosong!")
		return

	# 3. Gabung sisa item (kunci_perpus + sisa kertas_soal + sisa crowbar) untuk disebar ke ruangan
	var item_ruangan: Array[String] = ["kunci_perpus"]
	for i in range(max(0, sisa_soal)):
		item_ruangan.append("kertas_soal")
	for i in range(max(0, sisa_crowbar)):
		item_ruangan.append("crowbar")
	item_ruangan.shuffle()

	# 4. Sebar round-robin ke ruangan berbeda dulu sebelum putaran baru
	ruangan_list.shuffle()
	var ruangan_dipakai_putaran: Dictionary = {}
	var r_idx: int = 0

	for nama_item in item_ruangan:
		if ruangan_dipakai_putaran.size() >= ruangan_list.size():
			ruangan_dipakai_putaran.clear()

		var ruangan_terpilih: Node = null
		for step in range(ruangan_list.size()):
			var kandidat: Node = ruangan_list[(r_idx + step) % ruangan_list.size()]
			if not ruangan_dipakai_putaran.has(kandidat.get_instance_id()):
				ruangan_terpilih = kandidat
				r_idx = (r_idx + step + 1) % ruangan_list.size()
				break

		if ruangan_terpilih == null:
			ruangan_terpilih = ruangan_list[r_idx % ruangan_list.size()]
			r_idx += 1

		ruangan_dipakai_putaran[ruangan_terpilih.get_instance_id()] = true
		_taruh_di_spot_ruangan(nama_item, ruangan_terpilih)

func _taruh_di_spot_ruangan(nama_item: String, ruangan: Node) -> void:
	# Utamakan Marker3D di ruangan agar item fisik nyebar di ruangan & tidak numpuk di wadah
	var markers: Array = []
	var wadah_lokal: Array = []

	for c in ruangan.find_children("*", "", true, false):
		if c is Marker3D:
			markers.append(c)
		elif "antrean_isi" in c:
			wadah_lokal.append(c)

	var spots: Array = markers if not markers.is_empty() else wadah_lokal
	if spots.is_empty():
		push_warning("Ruangan '%s' tidak punya Marker3D maupun node dengan antrean_isi!" % ruangan.name)
		return

	var spots_kosong: Array = spots.filter(func(s): return not _spot_terpakai.has(s.get_instance_id()))
	var kandidat_spots: Array = spots_kosong if not spots_kosong.is_empty() else spots
	var spot: Node = kandidat_spots.pick_random()
	_spot_terpakai[spot.get_instance_id()] = true

	if spot is Marker3D:
		_spawn_item(nama_item, spot.global_transform)
		print("📦 [Spawner] %s spawn di %s (%s)" % [nama_item, ruangan.name, spot.name])
	elif "antrean_isi" in spot:
		spot.antrean_isi.append(nama_item)
		print("📥 [Spawner] %s masuk antrean %s di %s" % [nama_item, spot.name, ruangan.name])

func _spawn_item(nama_item: String, tf: Transform3D) -> void:
	var packed: PackedScene = null
	match nama_item:
		"kertas_soal":
			packed = scene_kertas_soal
		"crowbar":
			packed = scene_crowbar
		"kunci_perpus":
			packed = scene_kunci_perpus

	if packed:
		var inst = packed.instantiate()
		var target_parent: Node = wadah_item if wadah_item else get_parent()
		target_parent.add_child(inst)
		inst.global_transform = tf
