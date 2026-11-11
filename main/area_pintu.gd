extends Area3D

@export var nomor_pintu: int = 1
@export var pintu_mesh: Node3D
@export var sudut_buka: float = 90.0
var sudah_terbuka: bool = false

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
	if pintu_mesh:
		var tween := create_tween()
		tween.tween_property(pintu_mesh, "rotation_degrees:y", pintu_mesh.rotation_degrees.y + sudut_buka, 0.8)
