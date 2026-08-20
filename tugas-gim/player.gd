extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

@onready var camera = $Camera3D

var camera_rotation_x = 0.0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	# Gerakan mouse untuk kamera
	if event is InputEventMouseMotion:
		# Player berputar kiri dan kanan
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		# Kamera melihat atas dan bawah
		camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation_x = clamp(camera_rotation_x, -1.5, 1.5)

		camera.rotation.x = camera_rotation_x

	# Tekan ESC untuk melepas mouse
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta):
	# Gravitasi
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	# Lompat
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Input WASD
	var input_dir = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1

	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1

	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1

	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	# Arah gerakan mengikuti arah player/kamera
	var direction = Vector3(input_dir.x, 0, input_dir.y)

	if direction.length() > 0:
		direction = direction.normalized()

		# Mengikuti rotasi player
		direction = transform.basis * direction
		direction.y = 0
		direction = direction.normalized()

		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# Gerakkan player
	move_and_slide()
