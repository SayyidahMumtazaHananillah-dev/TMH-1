extends RigidBody3D

@export var gaya_lempar: float = 7.5
@export var dorongan_naik: float = 0.08
@export var cooldown_suara: float = 0.6
@export var cooldown_ambil: float = 0.4

var _sedang_dipegang: bool = false
var _sudah_dilempar: bool = false
var _cooldown_suara_timer: float = 0.0
var _cooldown_ambil_timer: float = 0.0
var _pemegang: Node3D = null

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = max(max_contacts_reported, 4)
	continuous_cd = true
	if linear_damp < 0.15:
		linear_damp = 0.25
	if angular_damp < 0.2:
		angular_damp = 0.35
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _cooldown_suara_timer > 0.0:
		_cooldown_suara_timer -= delta
	if _cooldown_ambil_timer > 0.0:
		_cooldown_ambil_timer -= delta

	if _sedang_dipegang and is_instance_valid(_pemegang):
		var cam: Camera3D = _pemegang.get_node_or_null("Camera3D")
		var acuan: Node3D = cam if cam else _pemegang
		var arah := -acuan.global_transform.basis.z.normalized()
		var jarak := 1.1

		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(acuan.global_position, acuan.global_position + arah * jarak)
		query.exclude = [self, _pemegang]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			jarak = clampf(acuan.global_position.distance_to(hit.position as Vector3) - 0.22, 0.2, 1.1)

		global_position = acuan.global_position + (arah * jarak) + Vector3(0, -0.05, 0)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

func interact() -> void:
	if _sedang_dipegang or _cooldown_ambil_timer > 0.0:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("Bola: node dalam group 'player' tidak ditemukan!")
		return

	if player.has_method("bisa_ambil_item") and not player.bisa_ambil_item():
		print("⚠️ Kamu cuma bisa megang 1 item! Tahan F (1s) buat simpan atau E buat buang.")
		return

	_pemegang = player
	_sedang_dipegang = true
	_sudah_dilempar = false
	freeze = true
	sleeping = false
	print("⚽ Bola diambil! Tekan E lagi untuk melempar.")

func _unhandled_input(event: InputEvent) -> void:
	if not _sedang_dipegang:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_lempar_bola()

func _lempar_bola() -> void:
	if not _sedang_dipegang:
		return

	_sedang_dipegang = false
	_sudah_dilempar = true
	_cooldown_suara_timer = 0.2
	_cooldown_ambil_timer = cooldown_ambil

	var arah := -global_transform.basis.z.normalized()
	var posisi_spawn := global_position
	var arah_lempar := arah

	if is_instance_valid(_pemegang):
		var cam: Camera3D = _pemegang.get_node_or_null("Camera3D")
		var acuan: Node3D = cam if cam else _pemegang
		arah = -acuan.global_transform.basis.z.normalized()
		arah_lempar = arah

		var jarak_spawn := 1.35
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(acuan.global_position, acuan.global_position + arah * jarak_spawn)
		query.exclude = [self, _pemegang]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var normal := hit.normal as Vector3
			posisi_spawn = (hit.position as Vector3) + normal * 0.25 + Vector3(0, 0.05, 0)
			# Arahkan lemparan menjauh/menyamping dari dinding supaya tidak menempel/terjepit
			arah_lempar = (arah + normal * 0.5).normalized()
		else:
			posisi_spawn = acuan.global_position + (arah * jarak_spawn) + Vector3(0, 0.05, 0)

	global_position = posisi_spawn
	freeze = false
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var vektor_lempar := (arah_lempar + Vector3(0, dorongan_naik, 0)).normalized() * gaya_lempar
	apply_central_impulse(vektor_lempar)
	print("💨 Bola dilempar pelan!")

func _on_body_entered(body: Node) -> void:
	if not _sudah_dilempar or _cooldown_suara_timer > 0.0:
		return
	if body == _pemegang:
		return

	_cooldown_suara_timer = cooldown_suara
	print("🔊 BUK! Bola memantul di lantai, menarik perhatian guru!")
	var guru := get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)
