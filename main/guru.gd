extends CharacterBody3D

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
