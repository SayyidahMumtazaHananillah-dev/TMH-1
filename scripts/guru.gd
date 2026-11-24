extends CharacterBody3D

@export var nonaktif_saat_tes: bool = false # centang / set true kalau lagi tes map

@export var chase_speed := 4.0
@export var walk_speed := 1.5
@export var attack_range := 1.5
@export var attack_damage := 10
@export var attack_cooldown := 0.8
@export var max_chase_distance := 10.0
@export var wander_radius := 5.0
@export var wander_interval := 3.0

var target: Node3D = null

var is_attacking := false
var is_stunned := false # Status kalau guru lagi pingsan
var stun_timer := 0.0

var wander_target := Vector3.ZERO
var wander_timer := 0.0
var is_wandering := false


func _ready() -> void:
	print("Guru siap!")
	# Mencari player secara otomatis berdasarkan Group "player" atau nama node
	await get_tree().create_timer(0.1).timeout # Tunggu node lain siap
	target = get_tree().get_first_node_in_group("player")
	
	if target:
		print("Target ketemu: ", target.name)
	else:
		print("ERROR: Target player ga ketemu! Masukkan player ke Group 'player'.")
		
	_set_new_wander_target()


func _physics_process(delta: float) -> void:
	if nonaktif_saat_tes:
		return

	# JIKA GURU LAGI PINGSAN (DIKENAKAN SAPU)
	if is_stunned:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		
		# Kurangi timer pingsan (25 detik)
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			print("Guru bangun kembali!")
		return

	if target == null:
		return

	# Gravitasi
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	var distance = global_position.distance_to(target.global_position)

	# MODE NGEJAR
	if distance <= max_chase_distance:
		is_wandering = false
		
		if distance > 0.5:
			var target_pos = target.global_position
			target_pos.y = global_position.y
			look_at(target_pos, Vector3.UP)
		
		if distance > attack_range:
			var direction = global_position.direction_to(target.global_position)
			direction.y = 0
			
			if direction.length() > 0.5:
				direction = direction.normalized()
				velocity.x = direction.x * chase_speed
				velocity.z = direction.z * chase_speed
			else:
				velocity.x = 0
				velocity.z = 0
			
			move_and_slide()
		else:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			
			if not is_attacking:
				attack()
	
	# MODE JALAN ACAK
	else:
		if not is_wandering:
			_set_new_wander_target()
			is_wandering = true
		
		wander_timer += delta
		if wander_timer >= wander_interval:
			wander_timer = 0.0
			_set_new_wander_target()
		
		var dist_to_wander = global_position.distance_to(wander_target)
		
		if dist_to_wander > 1.0:
			var direction = global_position.direction_to(wander_target)
			direction.y = 0
			
			if direction.length() > 0.5:
				direction = direction.normalized()
				velocity.x = direction.x * walk_speed
				velocity.z = direction.z * walk_speed
				
				if dist_to_wander > 0.5:
					var look_pos = wander_target
					look_pos.y = global_position.y
					look_at(look_pos, Vector3.UP)
			else:
				velocity.x = 0
				velocity.z = 0
			
			move_and_slide()
		else:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			_set_new_wander_target()


func attack() -> void:
	if is_attacking:
		return
		
	is_attacking = true
	print("👊 GURU NABOK!")
	
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)
	
	# Player ketangkap: dikunci & dipaksa menghadap guru
	if target and target.has_method("tertangkap"):
		target.tertangkap(self)
	
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false


# FUNGSI KETIKA GURU DIPUKUL PAKAI SAPU (DIPANGGIL DARI ITEM SAPU)
func kena_sapu() -> void:
	is_stunned = true
	stun_timer = 25.0 # Pingsan selama 25 detik
	velocity = Vector3.ZERO
	print("🧹 Guru pingsan selama 25 detik!")
	
	# Tambah hit counter di GameManager untuk syarat kunci resepsionis (butuh 5x pukul)
	GameManager.hit_guru_count += 1
	print("Hit guru ke: ", GameManager.hit_guru_count, "/5")
	
	if GameManager.hit_guru_count >= 5:
		print("🎉 Kunci Resepsionis telah dijatuhkan oleh Guru!")
		# Di sini nanti bisa ditambahin fungsi spawn item Kunci Resepsionis di map


func dengar_alarm(posisi_suara: Vector3) -> void:
	if nonaktif_saat_tes or is_stunned:
		return
	wander_target = Vector3(posisi_suara.x, global_position.y, posisi_suara.z)
	is_wandering = true
	wander_timer = 0.0


func _set_new_wander_target() -> void:
	var random_angle = randf() * 2 * PI
	var random_distance = randf_range(2.0, wander_radius)
	
	var new_target = global_position + Vector3(
		cos(random_angle) * random_distance,
		0,
		sin(random_angle) * random_distance
	)
	
	new_target.y = global_position.y
	wander_target = new_target
	is_wandering = true
	wander_timer = 0.0



# =====================================================================
# ANIMASI JALAN / LARI (TAMBAHAN - kode di atas tidak diubah)
# Butuh node AnimationPlayer di dalam model (dari pak_guru_anim.glb).
# =====================================================================
const ANIM_WALK_BASE_SPEED := 1.5  # kecepatan asli animasi jalan
const ANIM_RUN_BASE_SPEED := 4.0   # kecepatan asli animasi lari

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

	# ANIMASI NANGKEP PEMAIN (main sekali selama is_attacking, lalu balik normal)
	if is_attacking and _anim_catch != &"":
		if _anim_current != _anim_catch:
			_anim_current = _anim_catch
			_anim_player.speed_scale = 1.0
			_anim_player.play(_anim_catch, 0.1)
		return

	var speed := Vector2(velocity.x, velocity.z).length()

	if is_stunned or speed < 0.1:
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
	if _anim_catch != &"":
		_anim_player.get_animation(_anim_catch).loop_mode = Animation.LOOP_NONE
	for a in [_anim_idle, _anim_walk, _anim_run]:
		if a != &"":
			_anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_anim_ready = true


func _find_anim(keyword: String) -> StringName:
	for a in _anim_player.get_animation_list():
		if String(a).contains(keyword):
			return a
	push_warning("Animasi '%s' tidak ditemukan di AnimationPlayer" % keyword)
	return &""


func _play_anim(anim_name: StringName, speed_scale: float) -> void:
	if anim_name == &"":
		return
	if _anim_current != anim_name:
		_anim_current = anim_name
		_anim_player.play(anim_name, 0.2) # blend 0.2 detik
	_anim_player.speed_scale = speed_scale
