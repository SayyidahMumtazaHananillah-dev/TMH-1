extends Node3D

@export var teks_notif: String = "🎬 [NOTIF CUTSCENE] Kamu memeriksa foto misterius ini! (Cutscene menyusul)"
@export var bisa_diulang: bool = true

var _sudah_dipicu: bool = false

func interact() -> void:
	if _sudah_dipicu and not bisa_diulang:
		return
	_sudah_dipicu = true
	print(teks_notif)

	var notif_label := get_tree().root.find_child("NotifLabel", true, false) as Label
	if notif_label:
		notif_label.text = teks_notif
		notif_label.visible = true
