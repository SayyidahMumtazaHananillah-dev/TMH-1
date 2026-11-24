extends Node3D

var _sedang_dipegang: bool = false
var _pemegang: Node = null

func interact() -> void:
	if _sedang_dipegang:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Tahan F (1s) buat simpan atau E buat buang.")
		return

	_sedang_dipegang = true
	_pemegang = player
	_set_collision_aktif(false)

	if player.has_method("pegang_item"):
		player.pegang_item(self, "kunci_resepsionis")
	else:
		if "punya_kunci_resepsionis" in GameManager:
			GameManager.punya_kunci_resepsionis = true
		print("🗝️ Kunci Resepsionis berhasil diambil!")
		queue_free()

func _physics_process(_delta: float) -> void:
	if not _sedang_dipegang:
		return
	if is_instance_valid(_pemegang) and "item_dipegang" in _pemegang and _pemegang.item_dipegang != self:
		_sedang_dipegang = false
		_pemegang = null
		_set_collision_aktif(true)

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
