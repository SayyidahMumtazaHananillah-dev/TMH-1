extends Node3D

func interact() -> void:
	GameManager.punya_kunci_ruangan = true
	print("🔑 Kamu menemukan KUNCI RUANGAN / PERPUSTAKAAN!")
	queue_free()
