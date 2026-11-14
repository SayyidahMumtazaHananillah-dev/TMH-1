extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var ray_length: float = 4.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D
@onready var ray_cast: RayCast3D = $Camera3D/RayCast3D
@onready var senter_hp: SpotLight3D = $Camera3D/senterHp
@onready var senter_tengah: SpotLight3D = $Camera3D/senterTengah
@onready var prompt_label: Label = get_tree().root.find_child("PromptLabel", true, false)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if senter_hp:
		senter_hp.visible = false
	if senter_tengah:
		senter_tengah.visible = false
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.target_position = Vector3(0, 0, -ray_length)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
			camera.rotation.y = 0.0
			camera.rotation.z = 0.0

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_coba_interaksi()

func _coba_interaksi() -> void:
	if not ray_cast:
		return

	if ray_cast.is_colliding():
		var hit_object = ray_cast.get_collider()
		var target = hit_object
		var found = false
		
		while target:
			if target.has_method("interact"):
				target.interact()
				found = true
				break
			target = target.get_parent()
		
		if not found:
			if hit_object.name == "rolling" or (hit_object.get_parent() and hit_object.get_parent().name == "rolling"):
				var pintu_node = hit_object if hit_object.name == "rolling" else hit_object.get_parent()
				var tween = create_tween()
				tween.tween_property(pintu_node, "position:y", pintu_node.position.y + 4.0, 1.0)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("senter") and senter_hp:
		var status_baru := not senter_hp.visible
		senter_hp.visible = status_baru
		if senter_tengah:
			senter_tengah.visible = status_baru

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	_cek_target_interaksi()
	move_and_slide()

func _cek_target_interaksi() -> void:
	if not ray_cast or not prompt_label:
		return

	if ray_cast.is_colliding():
		var hit_object = ray_cast.get_collider()
		var target = hit_object
		var bisa_interaksi = false
		
		while target:
			if target.has_method("interact") or target.name == "rolling":
				bisa_interaksi = true
				break
			target = target.get_parent()
		
		if bisa_interaksi:
			prompt_label.visible = true
			
			
			return

	prompt_label.visible = false
