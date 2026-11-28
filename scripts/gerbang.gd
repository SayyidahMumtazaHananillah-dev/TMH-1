extends Node3D

# Isi lewat Inspector kalau lokasi scene ending kamu beda.
# Kalau kosong / tidak ketemu, script akan mencari di beberapa lokasi umum.
@export_file("*.tscn") var ending_scene_path: String = "res://scenes/cutscenes/ending.tscn"
@export var nama_kunci_gerbang: String = "kunci_gerbang"
@export var durasi_fade: float = 0.8

const KANDIDAT_ENDING := [
	"res://scenes/ending.tscn",
	"res://scenes/cutscenes/ending.tscn",
	"res://scenes/cutscene/ending.tscn",
	"res://ending.tscn",
]

var _sedang_pindah: bool = false


func interact() -> void:
	print("GERBANG interact() dipanggil")
	if _sedang_pindah:
		return

	if not _punya_kunci():
		print("🔒 Gerbang terkunci! Cari kunci gerbang dulu.")
		return

	var tujuan := _cari_scene_ending()
	if tujuan.is_empty():
		push_error("gerbang.gd: scene ending tidak ditemukan. Isi 'Ending Scene Path' di Inspector gerbang.")
		return

	_sedang_pindah = true
	print("🔓 Kunci gerbang cocok! Menuju scene ending: ", tujuan)
	_pindah_ke_ending(tujuan)


func _pindah_ke_ending(tujuan: String) -> void:
	# Fade ke hitam dulu biar transisinya halus
	var layer := CanvasLayer.new()
	layer.layer = 100
	var gelap := ColorRect.new()
	gelap.color = Color(0, 0, 0, 0)
	gelap.set_anchors_preset(Control.PRESET_FULL_RECT)
	gelap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(gelap)
	get_tree().root.add_child(layer)

	var tween := create_tween()
	tween.tween_property(gelap, "color:a", 1.0, durasi_fade)
	await tween.finished

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(tujuan)
	layer.queue_free()


func _cari_scene_ending() -> String:
	if not ending_scene_path.is_empty() and ResourceLoader.exists(ending_scene_path):
		return ending_scene_path
	for path in KANDIDAT_ENDING:
		if ResourceLoader.exists(path):
			return path
	return ""


func _punya_kunci() -> bool:
	# 1. Cek di autoload GameManager
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null:
		if "punya_kunci_gerbang" in game_manager and bool(game_manager.get("punya_kunci_gerbang")):
			return true
		if "kunci_gerbang" in game_manager and bool(game_manager.get("kunci_gerbang")):
			return true
		if game_manager.has_method("punya_kunci") and bool(game_manager.call("punya_kunci", nama_kunci_gerbang)):
			return true

	# 2. Cek di node player (item yang sedang dipegang atau status kunci di player)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if "item_dipegang" in player and player.item_dipegang != null:
			var item: Node = player.item_dipegang
			if str(item.name).to_lower().contains("kunci_gerbang") or ("jenis_item" in item and str(item.jenis_item) == nama_kunci_gerbang):
				return true
		if "punya_kunci_gerbang" in player and bool(player.get("punya_kunci_gerbang")):
			return true
		if "_tipe_item_dipegang" in player and str(player.get("_tipe_item_dipegang")) == nama_kunci_gerbang:
			return true
		if player.has_method("punya_kunci") and bool(player.call("punya_kunci", nama_kunci_gerbang)):
			return true

	return false
