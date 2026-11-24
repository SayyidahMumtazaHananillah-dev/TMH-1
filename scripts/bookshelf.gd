extends Node3D

@export_range(0.0, 1.0) var peluang_buku_jatuh: float = 0.18

var antrean_isi: Array[String] = []
var sudah_diperiksa: bool = false

func interact() -> void:
	# Cek kejadian buku jatuh dengan peluang kecil
	if randf() < peluang_buku_jatuh:
		print("📚 BRUK! Tumpukan buku jatuh berisik, guru dengar suaranya!")
		_panggil_guru()

	if not antrean_isi.is_empty():
		var item: String = antrean_isi.pop_front()
		match item:
			"kunci_resepsionis":
				GameManager.punya_kunci_resepsionis = true
				print("🗝️ Kamu menemukan KUNCI RESEPSIONIS di sela rak buku!")
			"kertas_soal":
				GameManager.jumlah_soal += 1
				print("📄 Dapat KERTAS SOAL dari rak buku! (" + str(GameManager.jumlah_soal) + "/5)")
		return

	if sudah_diperiksa:
		print("📚 Rak buku ini sudah diperiksa, tidak ada apa-apa lagi.")
	else:
		sudah_diperiksa = true
		print("📚 Cuma deretan buku pelajaran lama.")

func _panggil_guru() -> void:
	var guru = get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)
