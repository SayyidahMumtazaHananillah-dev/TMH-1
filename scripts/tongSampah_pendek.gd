extends Area3D

var sudah_diaduk: bool = false

func interact() -> void:
	if sudah_diaduk:
		print("🗑️ Tong sampah ini sudah kosong!")
		return

	sudah_diaduk = true
	var gacha = randi_range(1, 3)

	match gacha:
		1:
			GameManager.jumlah_soal += 1
			print("📄 Dapat KERTAS SOAL! (" + str(GameManager.jumlah_soal) + "/5)")
		2:
			if not GameManager.punya_linggis:
				GameManager.punya_linggis = true
				print("🔧 Kamu menemukan LINGGIS!")
			else:
				GameManager.jumlah_soal += 1
				print("📄 Dapat KERTAS SOAL! (" + str(GameManager.jumlah_soal) + "/5)")
		3:
			print("🚨 ALARM BUNYI! Guru mengarah ke sini!")
			_bunyikan_alarm()

func _bunyikan_alarm() -> void:
	var guru = get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)
