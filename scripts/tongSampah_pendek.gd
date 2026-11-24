extends Node3D

@export var max_interaksi: int = 5
@export_range(0.0, 1.0) var peluang_alarm: float = 0.18

var jumlah_interaksi: int = 0
var antrean_isi: Array[String] = []

func interact() -> void:
	if jumlah_interaksi >= max_interaksi:
		print("🗑️ Tong sampah ini sudah tidak bisa diaduk lagi!")
		return

	jumlah_interaksi += 1

	# Cek pemicu alarm dulu dengan peluang kecil
	if randf() < peluang_alarm:
		print("🚨 PRANG! Tutup tong sampah berisik, guru mengarah ke sini!")
		_panggil_guru()
		return

	# Ambil item dari antrean jika ada
	if not antrean_isi.is_empty():
		var item: String = antrean_isi.pop_front()
		match item:
			"kertas_soal":
				GameManager.jumlah_soal += 1
				print("📄 Dapat KERTAS SOAL dari tong sampah! (" + str(GameManager.jumlah_soal) + "/5)")
			"crowbar":
				GameManager.punya_linggis = true
				print("🔧 Dapat CROWBAR!")
		return

	print("🗑️ Zonk! Cuma sampah kertas bekas.")

func _panggil_guru() -> void:
	var guru = get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)
