extends Node3D

var sudah_diaduk: bool = false

# Fungsi utama yang dipanggil oleh RayCast player
func interact() -> void:
	# Cari node HUD di dalam scene
	var hud = get_tree().root.find_child("HUD", true, false)

	if sudah_diaduk:
		print("🗑️ Tong sampah ini sudah kosong!")
		if hud and hud.has_method("tampilkan_notif"):
			hud.tampilkan_notif("🗑️ Tong sampah ini sudah kosong!")
		return

	sudah_diaduk = true
	var gacha = randi_range(1, 3)

	match gacha:
		1:
			GameManager.jumlah_soal += 1
			var pesan = "📄 Dapat KERTAS SOAL! (" + str(GameManager.jumlah_soal) + "/5)"
			print(pesan)
			if hud and hud.has_method("tampilkan_notif"):
				hud.tampilkan_notif(pesan)
		2:
			if not GameManager.punya_linggis:
				GameManager.punya_linggis = true
				var pesan = "🔧 Kamu menemukan LINGGIS!"
				print(pesan)
				if hud and hud.has_method("tampilkan_notif"):
					hud.tampilkan_notif(pesan)
			else:
				GameManager.jumlah_soal += 1
				var pesan = "📄 Dapat KERTAS SOAL! (" + str(GameManager.jumlah_soal) + "/5)"
				print(pesan)
				if hud and hud.has_method("tampilkan_notif"):
					hud.tampilkan_notif(pesan)
		3:
			var pesan = "🚨 ALARM BUNYI! Guru mengarah ke sini!"
			print(pesan)
			if hud and hud.has_method("tampilkan_notif"):
				hud.tampilkan_notif(pesan)
			_bunyikan_alarm()

func _bunyikan_alarm() -> void:
	var guru = get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)	
