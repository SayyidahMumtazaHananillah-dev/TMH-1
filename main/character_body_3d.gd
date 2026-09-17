extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Sensitivitas rotasi mouse
@export var MOUSE_SENSITIVITY: float = 0.003

# Batas sudut pandang atas & bawah (dalam radian)
const MIN_PITCH = deg_to_rad(-89.0)
const MAX_PITCH = deg_to_rad(89.0)

# Mengambil node Camera3D dan Crosshair
@onready var camera_3d: Camera3D = $Camera3D
@onready var crosshair: ColorRect = $CanvasLayer/Control/Crosshair


func _ready() -> void:
	# Sembunyikan dan kunci kursor di tengah layar
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Paksa crosshair tepat di tengah viewport
	var viewport_center = get_viewport().get_visible_rect().size / 2.0
	crosshair.global_position = viewport_center - (crosshair.size / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Putar badan karakter ke kanan/kiri
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Putar kamera ke atas/bawah
		camera_3d.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		
		# Batasi rotasi kamera supaya tidak terbalik
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, MIN_PITCH, MAX_PITCH)


func _physics_process(delta: float) -> void:
	# Tekan ESC untuk lepas kursor mouse
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
