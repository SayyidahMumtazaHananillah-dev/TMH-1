extends Node3D

func interact() -> void:
	GameManager.punya_linggis = true
	print("🔧 Kamu menemukan LINGGIS / CROWBAR!")
	queue_free()
