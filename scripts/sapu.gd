extends Node3D

@export var jarak_pukul: float = 3.0

var _punya_sapu: bool = false
var _pemegang: Node3D = null

func interact() -> void:
	if _punya_sapu:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	_punya_sapu = true
	_pemegang = player
	visible = false
	_set_collision_aktif(false)
	print("🧹 Sapu berhasil diambil! Dekati guru lalu tekan F untuk memukul.")

func _unhandled_input(event: InputEvent) -> void:
	if not _punya_sapu or not is_instance_valid(_pemegang):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_ayunkan_sapu()

func _ayunkan_sapu() -> void:
	var guru := get_tree().get_first_node_in_group("guru") as Node3D
	if guru == null:
		print("🧹 Sapu diayunkan, tapi tidak ada guru di dekat sini.")
		return

	var jarak := _pemegang.global_position.distance_to(guru.global_position)
	if jarak <= jarak_pukul and guru.has_method("kena_sapu"):
		guru.kena_sapu()
	else:
		print("🧹 Sapu diayunkan meleset (jarak ke guru: %.1f m)." % snapped(jarak, 0.1))

func _set_collision_aktif(aktif: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = not aktif
