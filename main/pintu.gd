extends Area3D

@export var nomor_pintu: int = 1
@export var pintu_mesh: Node3D          # node pintu yang kelihatan di game
@export var sudut_buka: float = 90.0
@export var offset_engsel: Vector3 = Vector3(0.5, 0, 0)  # posisi engsel dari tengah pintu
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
	if pintu_mesh == null:
		print("Pintu Mesh belum diisi di Inspector!")
		return
	transform_awal = pintu_mesh.transform
	var tween := create_tween()
	tween.tween_method(_putar, 0.0, sudut_buka, 0.8)

func _putar(derajat: float) -> void:
	var pivot: Vector3 = transform_awal.origin + transform_awal.basis * offset_engsel
	var rotasi := Transform3D(Basis(Vector3.UP, deg_to_rad(derajat)), Vector3.ZERO)
	var ke_pivot := Transform3D(Basis(), pivot)
	var dari_pivot := Transform3D(Basis(), -pivot)
	pintu_mesh.transform = ke_pivot * rotasi * dari_pivot * transform_awal
