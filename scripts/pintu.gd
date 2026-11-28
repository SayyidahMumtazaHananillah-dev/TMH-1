extends Node3D

@export var nomor_pintu: int = 1
@export var pintu_mesh: Node3D          # node pintu yang kelihatan di game
@export var sudut_buka: float = 90.0
@export var offset_engsel: Vector3 = Vector3(0.5, 0, 0)  # posisi engsel dari tengah pintu

@export_group("Ending")
@export_file("*.tscn") var scene_ending: String = "res://scenes/cutscenes/ending.tscn"
@export var durasi_gelap: float = 1.5       # lama layar memudar jadi hitam
@export var durasi_terang: float = 1.0      # lama fade-in di scene ending

var sudah_terbuka: bool = false
var transform_awal: Transform3D

func interact() -> void:
	if sudah_terbuka:
		print("Pintu ini sudah terbuka!")
		return

	match nomor_pintu:
		1:
			if GameManager.punya_kunci_resepsionis:
				_buka_pintu()
			else:
				print("Pintu terkunci! Butuh kunci resepsionis.")
		3:
			if GameManager.punya_kunci_gerbang:
				_buka_pintu()
			else:
				print("Pintu terkunci! Butuh kunci gerbang.")
		_:
			_buka_pintu()

func _buka_pintu() -> void:
	sudah_terbuka = true
	print("Pintu nomor " + str(nomor_pintu) + " terbuka!")

	var tween: Tween = null
	if pintu_mesh == null:
		print("Pintu Mesh belum diisi di Inspector!")
	else:
		transform_awal = pintu_mesh.transform
		tween = create_tween()
		tween.tween_method(_putar, 0.0, sudut_buka, 0.8)

	# Gerbang (nomor 3): setelah terbuka, layar gelap lalu ke ending
	if nomor_pintu == 3:
		if tween != null:
			await tween.finished
		_transisi_ke_ending()

func _putar(derajat: float) -> void:
	var pivot: Vector3 = transform_awal.origin + transform_awal.basis * offset_engsel
	var rotasi := Transform3D(Basis(Vector3.UP, deg_to_rad(derajat)), Vector3.ZERO)
	var ke_pivot := Transform3D(Basis(), pivot)
	var dari_pivot := Transform3D(Basis(), -pivot)
	pintu_mesh.transform = ke_pivot * rotasi * dari_pivot * transform_awal

func _transisi_ke_ending() -> void:
	# Layar hitam dibuat lewat kode, ditaruh di root supaya tidak hilang saat scene berganti
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().root.add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	# Fade ke hitam
	var fade_out := create_tween()
	fade_out.tween_property(overlay, "color:a", 1.0, durasi_gelap)
	await fade_out.finished

	# Fade-in di scene ending (pakai layer, karena pintu ini dihapus saat scene ganti)
	var fade_in := layer.create_tween()
	fade_in.tween_interval(0.3)
	fade_in.tween_property(overlay, "color:a", 0.0, durasi_terang)
	fade_in.tween_callback(layer.queue_free)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene_ending)
