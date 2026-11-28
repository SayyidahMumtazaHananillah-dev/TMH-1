extends CharacterBody3D

@export var chase_speed := 4.0
@export var walk_speed := 1.5
@export var attack_range := 1.5
@export var attack_damage := 10
@export var attack_cooldown := 0.8
@export var max_chase_distance := 10.0
@export var wander_radius := 5.0
@export var wander_interval := 3.0
@export var debug_log := false

var target: Node3D = null

var is_attacking := false

var wander_target := Vector3.ZERO
var wander_timer := 0.0
var is_wandering := false
var _menuju_alarm := false   # lagi jalan ke arah suara alarm

# Deteksi nyangkut
var _stuck_timer := 0.0
var _last_pos := Vector3.ZERO
var _wants_move := false
var _sedang_ngejar := false
var _detour_timer := 0.0
var _detour_dir := Vector3.ZERO

var _retry_target_timer := 0.0


func _ready() -> void:
	_last_pos = global_position
	if debug_log:
		print("Guru siap di posisi: ", global_position)

	await get_tree().create_timer(0.1).timeout
	_find_player_target()
	_set_new_wander_target()


func _find_player_target() -> void:
	target = get_tree().get_first_node_in_group("player") as Node3D
	if target == null:
		# Fallback cari node bernama Player jika lupa dimasukkan ke group "player"
		var root := get_tree().current_scene
		if root != null:
			target = root.find_child("Player", true, false) as Node3D

	if debug_log:
		if target != null:
			print("Target ketemu: ", target.name)
		else:
			print("WARN: Target player belum ketemu, akan dicoba lagi.")


func _physics_process(delta: float) -> void:
	var punya_target := target != null and is_instance_valid(target)

	# Coba cari ulang target kalau belum ketemu
	if not punya_target:
		_retry_target_timer += delta
		if _retry_target_timer >= 0.5:
			_retry_target_timer = 0.0
			_find_player_target()

	var distance := INF
	if punya_target:
		distance = global_position.distance_to(target.global_position)

	_wants_move = false
	_sedang_ngejar = false

	# MODE NGEJAR
	if punya_target and distance <= max_chase_distance:
		_sedang_ngejar = true
		is_wandering = false
		_menuju_alarm = false

		if distance > 0.5:
			var target_pos := target.global_position
			target_pos.y = global_position.y
			if global_position.distance_to(target_pos) > 0.01:
				look_at(target_pos, Vector3.UP)

		if distance > attack_range:
			var direction := target.global_position - global_position
			direction.y = 0.0

			# Kalau lagi nyangkut, belok sebentar menghindari halangan
			if _detour_timer > 0.0:
				_detour_timer -= delta
				direction = _detour_dir

			if direction.length() > 0.1:
				direction = direction.normalized()
				velocity.x = direction.x * chase_speed
				velocity.z = direction.z * chase_speed
				_wants_move = true
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_attacking:
				attack()

	# MODE JALAN ACAK / MENUJU ALARM
	else:
		_process_wander(delta)

	_apply_gravity_and_move(delta)
	_check_stuck(delta)

	if debug_log and Engine.get_process_frames() % 60 == 0:
		var dist_str := "%.2f" % distance if distance != INF else "-1.0"
		print("Guru pos:", global_position, " | dist:", dist_str, " | wander:", is_wandering, " | alarm:", _menuju_alarm)


func _process_wander(delta: float) -> void:
	if not is_wandering:
		_set_new_wander_target()

	# Kalau lagi menuju alarm, jangan ganti tujuan sebelum sampai
	if not _menuju_alarm:
		wander_timer += delta
		if wander_timer >= wander_interval:
			wander_timer = 0.0
			_set_new_wander_target()

	var flat_self := Vector2(global_position.x, global_position.z)
	var flat_target := Vector2(wander_target.x, wander_target.z)
	var dist_to_wander := flat_self.distance_to(flat_target)

	if dist_to_wander > 0.8:
		var dir_2d := (flat_target - flat_self).normalized()
		velocity.x = dir_2d.x * walk_speed
		velocity.z = dir_2d.y * walk_speed
		_wants_move = true

		var look_pos := Vector3(wander_target.x, global_position.y, wander_target.z)
		if global_position.distance_to(look_pos) > 0.05:
			look_at(look_pos, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_menuju_alarm = false
		_set_new_wander_target()


func _apply_gravity_and_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


# Cek posisi tiap 0.6 detik. Kalau guru pengen jalan tapi hampir nggak pindah, berarti nyangkut.
func _check_stuck(delta: float) -> void:
	if not _wants_move:
		_stuck_timer = 0.0
		_last_pos = global_position
		return

	_stuck_timer += delta
	if _stuck_timer < 0.6:
		return

	_stuck_timer = 0.0
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	_last_pos = global_position

	if moved < 0.15:
		_on_stuck()


func _on_stuck() -> void:
	if _sedang_ngejar and target != null and is_instance_valid(target):
		# Belok ke samping dari arah player selama 1 detik
		var arah := target.global_position - global_position
		arah.y = 0.0
		if arah.length() < 0.01:
			arah = Vector3.FORWARD
		var sisi := PI * 0.5 if randf() < 0.5 else -PI * 0.5
		_detour_dir = arah.normalized().rotated(Vector3.UP, sisi + randf_range(-0.5, 0.5))
		_detour_timer = 1.0
	else:
		_menuju_alarm = false
		_set_new_wander_target()


func attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	print("👊 GURU NABOK!")

	if target and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(attack_damage)

	if target and is_instance_valid(target) and target.has_method("tertangkap"):
		target.tertangkap(self)

	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false


# DIPANGGIL DARI ITEM SAPU. Guru tidak lagi pingsan, cuma menghitung hit saja.
func kena_sapu() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and "hit_guru_count" in gm:
		gm.hit_guru_count += 1
		print("Hit guru ke: ", gm.hit_guru_count, "/5")
		if gm.hit_guru_count >= 5:
			print("🎉 Kunci Resepsionis telah dijatuhkan oleh Guru!")


func dengar_alarm(posisi_suara: Vector3) -> void:
	wander_target = Vector3(posisi_suara.x, global_position.y, posisi_suara.z)
	is_wandering = true
	_menuju_alarm = true
	wander_timer = 0.0


func _set_new_wander_target() -> void:
	var random_angle := randf() * TAU
	var random_distance := randf_range(2.0, wander_radius)

	wander_target = Vector3(
		global_position.x + cos(random_angle) * random_distance,
		global_position.y,
		global_position.z + sin(random_angle) * random_distance
	)
	is_wandering = true
	wander_timer = 0.0


# =====================================================================
# ANIMASI JALAN / LARI
# =====================================================================
const ANIM_WALK_BASE_SPEED := 1.5
const ANIM_RUN_BASE_SPEED := 4.0

var _anim_player: AnimationPlayer = null
var _anim_idle: StringName = &""
var _anim_walk: StringName = &""
var _anim_run: StringName = &""
var _anim_catch: StringName = &""
var _anim_current: StringName = &""
var _anim_ready := false


func _process(_delta: float) -> void:
	if not _anim_ready:
		_setup_animation()
		return

	if _anim_player == null or not is_instance_valid(_anim_player):
		return

	if is_attacking and _anim_catch != &"":
		if _anim_current != _anim_catch:
			_anim_current = _anim_catch
			_anim_player.speed_scale = 1.0
			_anim_player.play(_anim_catch, 0.1)
		return

	var speed := Vector2(velocity.x, velocity.z).length()

	if speed < 0.1:
		_play_anim(_anim_idle, 1.0)
	elif is_wandering or speed <= walk_speed + 0.2:
		_play_anim(_anim_walk, speed / ANIM_WALK_BASE_SPEED)
	else:
		_play_anim(_anim_run, speed / ANIM_RUN_BASE_SPEED)


func _setup_animation() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		return

	_anim_idle = _find_anim("idle")
	_anim_walk = _find_anim("walk")
	_anim_run = _find_anim("run")
	_anim_catch = _find_anim("catch")

	if _anim_catch != &"" and _anim_player.has_animation(_anim_catch):
		_anim_player.get_animation(_anim_catch).loop_mode = Animation.LOOP_NONE
	for a in [_anim_idle, _anim_walk, _anim_run]:
		if a != &"" and _anim_player.has_animation(a):
			_anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	_anim_ready = true


func _find_anim(keyword: String) -> StringName:
	for a in _anim_player.get_animation_list():
		if String(a).to_lower().contains(keyword):
			return a
	return &""


func _play_anim(anim_name: StringName, speed_scale: float) -> void:
	if anim_name == &"" or not _anim_player.has_animation(anim_name):
		return
	if _anim_current != anim_name:
		_anim_current = anim_name
		_anim_player.play(anim_name, 0.2)
	_anim_player.speed_scale = maxf(speed_scale, 0.1)
