extends Node3D

func interact() -> void:
	if "punya_kunci_gerbang" in GameManager:
		GameManager.punya_kunci_gerbang = true
	print("🗝️ Kunci Gerbang berhasil diambil!")
	queue_free()
