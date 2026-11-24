extends RigidBody3D

@export var gaya_lempar: float = 12.0
@export var cooldown_suara: float = 0.6

var _sedang_dipegang: bool = false
var _sudah_dilempar: bool = false
var _cooldown_timer: float = 0.0
var _pemegang: Node3D = null

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = max(max_contacts_reported, 4)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _sedang_dipegang and is_instance_valid(_pemegang):
		var cam: Camera3D = _pemegang.get_node_or_null("Camera3D")
		var titik_acuan: Node3D = cam if cam else _pemegang
		global_position = titik_acuan.global_position + (-titik_acuan.global_transform.basis.z * 0.9) + Vector3(0, -0.15, 0)

func interact() -> void:
	if _sedang_dipegang:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	_pemegang = player
	_sedang_dipegang = true
	_sudah_dilempar = false
	freeze = true
	print("⚽ Bola diambil! Tekan E lagi untuk melempar bola.")

func _unhandled_input(event: InputEvent) -> void:
	if not _sedang_dipegang:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_lempar_bola()

func _lempar_bola() -> void:
	_sedang_dipegang = false
	_sudah_dilempar = true
	_cooldown_timer = 0.25
	freeze = false

	var arah := -global_transform.basis.z
	if _pemegang:
		var cam: Camera3D = _pemegang.get_node_or_null("Camera3D")
		if cam:
			arah = -cam.global_transform.basis.z.normalized()
		else:
			arah = -_pemegang.global_transform.basis.z.normalized()

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	apply_central_impulse((arah + Vector3(0, 0.22, 0)).normalized() * gaya_lempar)
	print("💨 Bola dilempar!")

func _on_body_entered(body: Node) -> void:
	if not _sudah_dilempar or _cooldown_timer > 0.0:
		return
	if body == _pemegang:
		return

	_cooldown_timer = cooldown_suara
	print("🔊 BUK! Bola memantul di lantai, menarik perhatian guru!")
	var guru := get_tree().get_first_node_in_group("guru")
	if guru and guru.has_method("dengar_alarm"):
		guru.dengar_alarm(global_position)
