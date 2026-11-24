extends Node3D

@export var max_interaksi: int = 5
@export_range(0.0, 1.0) var peluang_alarm: float = 0.18
@export var scene_kertas: PackedScene
@export var scene_crowbar: PackedScene
@export var scene_alarm: PackedScene = preload("res://scenes/alarm.tscn")

var jumlah_interaksi: int = 0
var antrean_isi: Array[String] = []

func interact() -> void:
	if jumlah_interaksi >= max_interaksi:
		print("🗑️ Tong sampah ini sudah tidak bisa diaduk lagi!")
		return

	jumlah_interaksi += 1

	# Cek pemicu trap alarm dulu dengan peluang kecil
	if randf() < peluang_alarm:
		print("🚨 PRANG! Trap alarm dari tong sampah!")
		_picu_trap_alarm()
		return

	# Ambil item dari antrean jika ada
	if not antrean_isi.is_empty():
		var item: String = antrean_isi.pop_front()
		match item:
			"kertas_soal":
				_beri_kertas_ke_tangan()
			"crowbar":
				_beri_item_ke_tangan(scene_crowbar, "crowbar")
			"alarm":
				_picu_trap_alarm()
			_:
				print("🗑️ Dapat item tidak dikenal dari tong sampah: ", item)
		return

	print("🗑️ Zonk! Cuma sampah kertas bekas.")

func _panggil_guru() -> void:
	var guru = get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)

func _beri_kertas_ke_tangan() -> void:
	_beri_item_ke_tangan(scene_kertas, "kertas")

func _beri_item_ke_tangan(scene_item: PackedScene, tipe_item: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Tangan penuh! Tekan E buat lempar item yang sedang dipegang.")
		return

	if scene_item == null:
		push_warning("Scene untuk '%s' belum di-assign di Inspector tong sampah!" % tipe_item)
		return

	var item_node := scene_item.instantiate() as Node3D
	if item_node == null:
		return

	var parent_dunia: Node = get_tree().current_scene
	if parent_dunia:
		parent_dunia.add_child(item_node)

	if player.has_method("pegang_item"):
		player.pegang_item(item_node, tipe_item)
		if tipe_item == "kertas":
			print("📄 Dapat kertas dari tong sampah -> muncul di hadapanmu! Tahan F (1s) simpan, E lempar.")
		else:
			print("✋ Dapat '%s' dari tong sampah -> muncul di tangan! Tekan E untuk lempar." % tipe_item)

func _picu_trap_alarm() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if scene_alarm != null and player != null and player.has_method("bisa_ambil_item") and player.bisa_ambil_item():
		var alarm_node := scene_alarm.instantiate() as Node3D
		if alarm_node != null:
			var parent_dunia: Node = get_tree().current_scene
			if parent_dunia:
				parent_dunia.add_child(alarm_node)
			if alarm_node.has_method("_aktifkan_ke_tangan"):
				alarm_node._aktifkan_ke_tangan(player)
				return
			elif player.has_method("pegang_item"):
				player.pegang_item(alarm_node, "alarm")
				return

	# Fallback kalau tangan penuh atau scene_alarm kosong
	_panggil_guru()
