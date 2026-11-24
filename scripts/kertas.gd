extends Node3D

func interact() -> void:
	GameManager.jumlah_soal += 1
	print("📄 Dapat KERTAS SOAL! (" + str(GameManager.jumlah_soal) + "/5)")
	queue_free()
