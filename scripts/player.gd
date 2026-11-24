extends CharacterBody3D

@export var offset_tangan: Vector3 = Vector3(0.35, -0.32, -0.75) # kanan bawah kamera
@export var rotasi_tangan_deg: Vector3 = Vector3(-15.0, 20.0, -10.0)
@export var gaya_lempar_item: float = 8.0
@export var dorongan_naik_lempar: float = 0.15
@export var durasi_store_kertas: float = 1.0
@export var speed: float = 4.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var ray_length: float = 4.0
@export var sprint_speed: float = 5.5
@export var bob_freq_walk: float = 9.0    # kecepatan ayunan saat jalan
@export var bob_freq_sprint: float = 13.0 # kecepatan ayunan saat lari
@export var bob_amp_walk: float = 0.04    # besar ayunan saat jalan
@export var bob_amp_sprint: float = 0.07  # besar ayunan saat lari
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 25.0   # berkurang per detik saat lari
@export var stamina_regen: float = 15.0   # bertambah per detik saat tidak lari
@export var regen_delay: float = 1.0      # jeda sebelum stamina mulai pulih
@export var stamina_bar_width: float = 420.0  # panjang bar stamina
@export var stamina_bar_height: float = 6.0   # tebal bar stamina

@export var sfx_jalan: AudioStream = preload("res://assets/sfx/jalan.mp3")
@export var sfx_sprint: AudioStream = preload("res://assets/sfx/sprint.mp3")

@export var sfx_rolling: AudioStream = preload("res://assets/sfx/rolling_door.mp3")

@export var sfx_pintu_buka: AudioStream = preload("res://assets/sfx/door_open.mp3")
@export var sfx_pintu_tutup: AudioStream = preload("res://assets/sfx/door_closed.mp3")

var langkah_player: AudioStreamPlayer
var pintu_player: AudioStreamPlayer
var rolling_player: AudioStreamPlayer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var stamina: float = 0.0
var stamina_habis: bool = false
var regen_timer: float = 0.0
var stamina_root: Control
var stamina_fill: Panel
var stamina_fill_style: StyleBoxFlat

var bob_time: float = 0.0
var camera_base_pos: Vector3 = Vector3.ZERO

# --- SISTEM 1 ITEM DI TANGAN / STORE KERTAS / LEMPAR PHYSICS ---
var item_dipegang: Node3D = null
var _tipe_item_dipegang: String = "" # "kertas", "crowbar", "sapu", "bola", "alarm", "kunci_ruangan", "kunci_resepsionis", "kunci_gerbang"
var _sedang_tahan_store: bool = false
var _timer_store: float = 0.0
var _cooldown_aksi_item: float = 0.0
var _preview_kertas_ui: Control = null
var _label_preview_kertas: Label = null

# --- STATUS TERTANGKAP ---
@export var look_at_guru_speed: float = 8.0       # makin besar = makin cepat menoleh ke guru
@export var guru_head_height: float = 1.5         # tinggi titik yang dilihat (kepala guru)
@export var delay_layar_tangkap: float = 2.5   # detik sebelum pindah ke layar hati
var is_caught: bool = false
var guru_penangkap: Node3D = null

@onready var camera: Camera3D = $Camera3D
@onready var ray_cast: RayCast3D = $Camera3D/RayCast3D
@onready var senter_hp: SpotLight3D = $Camera3D/senterHp
@onready var senter_tengah: SpotLight3D = $Camera3D/senterTengah
@onready var prompt_label: Label = get_tree().root.find_child("PromptLabel", true, false)

func _ready() -> void:
	print("ANIM PLAYER: ", find_child("AnimationPlayer", true, false))
	speed = 4.0
	sprint_speed = 6.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if senter_hp:
		senter_hp.visible = false
	if senter_tengah:
		senter_tengah.visible = false
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.target_position = Vector3(0, 0, -ray_length)
	stamina = max_stamina
	_buat_audio_langkah()
	if camera:
		camera_base_pos = camera.position
	_buat_stamina_bar()
	_buat_preview_kertas_ui()

func _unhandled_input(event: InputEvent) -> void:
	if is_cutscene: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_caught:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
			camera.rotation.y = 0.0
			camera.rotation.z = 0.0

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventKey and event.pressed and not event.echo and not is_caught:
		if event.keycode == KEY_E:
			if item_dipegang != null:
				if _cooldown_aksi_item <= 0.0:
					_lempar_item_dipegang()
			else:
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
				var terbuka_sebelum = target.get("sudah_terbuka")
				target.interact()
				_mainkan_suara_pintu(target, terbuka_sebelum)
				found = true
				break
			target = target.get_parent()
		
		if not found:
			# Cuma "rolling" (bukan "rolling2") yang bisa dibuka, dan wajib punya crowbar
			if hit_object.name == "rolling" or (hit_object.get_parent() and hit_object.get_parent().name == "rolling"):
				var pintu_node = hit_object if hit_object.name == "rolling" else hit_object.get_parent()
				if not GameManager.punya_linggis:
					print("🔒 Rolling door terkunci! Butuh crowbar.")
					return
				if pintu_node.get_meta("sudah_terbuka", false):
					return
				pintu_node.set_meta("sudah_terbuka", true)
				if rolling_player and not rolling_player.playing:
					rolling_player.play()
				var tween = create_tween()
				tween.tween_property(pintu_node, "position:y", pintu_node.position.y + 4.0, 1.0)

func _physics_process(delta: float) -> void:
	if is_cutscene: return
	# Kalau lagi ketangkap: tidak bisa gerak, cuma menoleh ke guru
	if is_caught:
		_proses_tertangkap(delta)
		return

	if item_dipegang != null:
		_proses_aksi_item_dipegang(delta)

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
	
	var current_speed := speed
	var sedang_lari := _update_stamina(delta, direction != Vector3.ZERO)
	if sedang_lari:
		current_speed = sprint_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	_cek_target_interaksi()
	move_and_slide()
	_update_langkah(sedang_lari)
	_update_bob(delta, sedang_lari)

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

# =====================================================================
# ATURAN 1 ITEM DIPEGANG + STORE KHUSUS KERTAS + LEMPAR PHYSICS (E)
# =====================================================================
func bisa_ambil_item() -> bool:
	return item_dipegang == null

func pegang_item(node_item: Node3D, tipe: String) -> bool:
	if item_dipegang != null or node_item == null:
		return false

	item_dipegang = node_item
	_tipe_item_dipegang = tipe
	_sedang_tahan_store = false
	_timer_store = 0.0
	_cooldown_aksi_item = 0.2

	if tipe == "kertas":
		node_item.visible = false
		_tampilkan_kertas_di_layar(true)
		print("📄 Memegang kertas | Tahan F (%.1fs) untuk simpan, tekan E untuk buang/lempar." % durasi_store_kertas)
	else:
		_tampilkan_kertas_di_layar(false)
		if node_item.get_parent() != null:
			node_item.get_parent().remove_child(node_item)
		if camera:
			camera.add_child(node_item)
		node_item.position = offset_tangan
		node_item.rotation_degrees = rotasi_tangan_deg
		node_item.visible = true
		if tipe == "alarm":
			print("🚨 TRAP ALARM menyala! Tahan F (1.5s) untuk mematikan, tekan E untuk lempar.")
		else:
			print("✋ Memegang '%s' | Tekan E untuk lempar." % tipe)

	return true

func _proses_aksi_item_dipegang(delta: float) -> void:
	if _cooldown_aksi_item > 0.0:
		_cooldown_aksi_item -= delta

	# Hanya KERTAS yang bisa di-store (tahan F 1 detik).
	# Alarm dimatikan lewat alarm.gd (tahan F 1.5s). Item lain tidak bisa di-store.
	if _tipe_item_dipegang != "kertas":
		_sedang_tahan_store = false
		_timer_store = 0.0
		return

	if Input.is_key_pressed(KEY_F):
		_sedang_tahan_store = true
		_timer_store += delta
		var sisa := maxf(0.0, durasi_store_kertas - _timer_store)
		if _label_preview_kertas and _label_preview_kertas.visible:
			_label_preview_kertas.text = "📄 KERTAS DITEMUKAN\n[Tahan F: %.1fs] Simpan  |  [E] Buang" % sisa
		if _timer_store >= durasi_store_kertas:
			_simpan_kertas_dipegang()
	else:
		if _sedang_tahan_store:
			_sedang_tahan_store = false
			_timer_store = 0.0
			if _label_preview_kertas and _label_preview_kertas.visible:
				_label_preview_kertas.text = "📄 KERTAS DITEMUKAN\n[Tahan F: %.1fs] Simpan  |  [E] Buang" % durasi_store_kertas

func _simpan_kertas_dipegang() -> void:
	if item_dipegang == null or _tipe_item_dipegang != "kertas":
		return

	var item := item_dipegang
	item_dipegang = null
	_tipe_item_dipegang = ""
	_sedang_tahan_store = false
	_timer_store = 0.0
	_tampilkan_kertas_di_layar(false)

	if "jumlah_soal" in GameManager:
		GameManager.jumlah_soal += 1
		print("✅ Kertas disimpan! Total soal: ", GameManager.jumlah_soal)
	else:
		print("✅ Kertas disimpan!")

	if is_instance_valid(item):
		item.queue_free()

func _lempar_item_dipegang() -> void:
	if item_dipegang == null:
		return

	var item := item_dipegang
	var tipe := _tipe_item_dipegang
	item_dipegang = null
	_tipe_item_dipegang = ""
	_sedang_tahan_store = false
	_timer_store = 0.0
	_cooldown_aksi_item = 0.25
	_tampilkan_kertas_di_layar(false)

	var parent_dunia: Node = get_tree().current_scene
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	if parent_dunia and is_instance_valid(item):
		parent_dunia.add_child(item)

	var acuan: Node3D = camera if camera else self
	var arah := -acuan.global_transform.basis.z.normalized()
	var impuls := (arah + Vector3(0, dorongan_naik_lempar, 0)).normalized() * gaya_lempar_item

	if is_instance_valid(item):
		item.global_position = acuan.global_position + arah * 1.15 + Vector3(0, -0.05, 0)
		item.rotation = Vector3.ZERO
		item.visible = true

		# Kalau item punya method lempar sendiri (misal bola.gd), panggil
		if item.has_method("terima_lemparan"):
			item.terima_lemparan(impuls, self)
		elif item is RigidBody3D:
			var rb := item as RigidBody3D
			rb.freeze = false
			rb.sleeping = false
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
			rb.apply_central_impulse(impuls)

	print("💨 '%s' dilempar!" % tipe)

func _buat_preview_kertas_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_preview_kertas_ui = Control.new()
	_preview_kertas_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_kertas_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_kertas_ui.visible = false
	layer.add_child(_preview_kertas_ui)

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.92, 0.84, 0.96)
	style.border_color = Color(0.25, 0.18, 0.12, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_preview_kertas_ui.add_child(panel)

	_label_preview_kertas = Label.new()
	_label_preview_kertas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_preview_kertas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label_preview_kertas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_preview_kertas.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_preview_kertas.add_theme_color_override("font_color", Color(0.15, 0.1, 0.06, 1.0))
	_label_preview_kertas.text = "📄 KERTAS DITEMUKAN\n[Tahan F: %.1fs] Simpan  |  [E] Buang" % durasi_store_kertas
	panel.add_child(_label_preview_kertas)

func _tampilkan_kertas_di_layar(tampil: bool) -> void:
	if _preview_kertas_ui:
		_preview_kertas_ui.visible = tampil
	if _label_preview_kertas and tampil:
		_label_preview_kertas.text = "📄 KERTAS DITEMUKAN\n[Tahan F: %.1fs] Simpan  |  [E] Buang" % durasi_store_kertas

func _buat_stamina_bar() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# wadah bar: panjang & tipis, di bawah tengah layar
	stamina_root = Control.new()
	stamina_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_root.anchor_left = 0.5
	stamina_root.anchor_right = 0.5
	stamina_root.anchor_top = 1.0
	stamina_root.anchor_bottom = 1.0
	stamina_root.offset_left = -stamina_bar_width * 0.5
	stamina_root.offset_right = stamina_bar_width * 0.5
	stamina_root.offset_bottom = -36.0
	stamina_root.offset_top = -36.0 - stamina_bar_height
	stamina_root.modulate.a = 0.0  # tersembunyi saat stamina penuh
	layer.add_child(stamina_root)

	var radius := int(stamina_bar_height * 0.5)

	# latar bar
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)
	bg_style.set_corner_radius_all(radius)
	bg.add_theme_stylebox_override("panel", bg_style)
	stamina_root.add_child(bg)

	# isi bar (mengecil dari kiri & kanan menuju tengah)
	stamina_fill = Panel.new()
	stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_fill_style = StyleBoxFlat.new()
	stamina_fill_style.bg_color = Color(0.95, 0.95, 0.95)
	stamina_fill_style.set_corner_radius_all(radius)
	stamina_fill.add_theme_stylebox_override("panel", stamina_fill_style)
	stamina_root.add_child(stamina_fill)

	_update_stamina_ui(0.0, false)

func _update_stamina_ui(delta: float, sedang_lari: bool) -> void:
	if not stamina_root or not stamina_fill:
		return

	var ratio := clampf(stamina / max_stamina, 0.0, 1.0)
	var w := stamina_bar_width * ratio
	stamina_fill.visible = w >= 1.0
	stamina_fill.size = Vector2(w, stamina_bar_height)
	# isi selalu di tengah, jadi habisnya dari kiri & kanan menuju tengah
	stamina_fill.position = Vector2((stamina_bar_width - w) * 0.5, 0.0)

	if stamina_habis:
		stamina_fill_style.bg_color = Color(0.9, 0.2, 0.2)    # merah: kehabisan
	elif ratio < 0.3:
		stamina_fill_style.bg_color = Color(1.0, 0.65, 0.2)   # oranye: hampir habis
	else:
		stamina_fill_style.bg_color = Color(0.95, 0.95, 0.95) # putih: normal

	# muncul saat dipakai, memudar saat penuh
	var tampil := ratio < 0.999 or sedang_lari
	var target_alpha := 1.0 if tampil else 0.0
	var kecepatan_fade := 8.0 if tampil else 1.5
	stamina_root.modulate.a = move_toward(stamina_root.modulate.a, target_alpha, kecepatan_fade * delta)

func _update_stamina(delta: float, bergerak: bool) -> bool:
	var ingin_lari := Input.is_key_pressed(KEY_SHIFT) and bergerak and not stamina_habis
	var sedang_lari := false

	if ingin_lari and stamina > 0.0:
		sedang_lari = true
		stamina -= stamina_drain * delta
		regen_timer = regen_delay
		if stamina <= 0.0:
			stamina = 0.0
			stamina_habis = true  # harus pulih dulu sebelum bisa lari lagi
	else:
		if regen_timer > 0.0:
			regen_timer -= delta
		else:
			stamina = min(stamina + stamina_regen * delta, max_stamina)
		if stamina_habis and stamina >= max_stamina * 0.2:
			stamina_habis = false

	_update_stamina_ui(delta, sedang_lari)

	return sedang_lari

func _update_bob(delta: float, sedang_lari: bool) -> void:
	if not camera:
		return

	var kecepatan_datar := Vector2(velocity.x, velocity.z).length()
	var bergerak := is_on_floor() and kecepatan_datar > 0.1

	if bergerak:
		var freq := bob_freq_sprint if sedang_lari else bob_freq_walk
		var amp := bob_amp_sprint if sedang_lari else bob_amp_walk
		bob_time += delta * freq
		camera.position.y = camera_base_pos.y + sin(bob_time) * amp
		camera.position.x = camera_base_pos.x + cos(bob_time * 0.5) * amp * 0.5
	else:
		# kembali halus ke posisi awal saat diam / di udara
		bob_time = 0.0
		camera.position = camera.position.lerp(camera_base_pos, 10.0 * delta)

func _buat_audio_langkah() -> void:
	# loop supaya suara langkah terus berbunyi selama berjalan
	if sfx_jalan is AudioStreamMP3:
		sfx_jalan.loop = true
	if sfx_sprint is AudioStreamMP3:
		sfx_sprint.loop = true
	langkah_player = AudioStreamPlayer.new()
	add_child(langkah_player)
	rolling_player = AudioStreamPlayer.new()
	rolling_player.stream = sfx_rolling
	add_child(rolling_player)
	pintu_player = AudioStreamPlayer.new()
	add_child(pintu_player)

func _update_langkah(sedang_lari: bool) -> void:
	var kecepatan_datar := Vector2(velocity.x, velocity.z).length()
	var bergerak := is_on_floor() and kecepatan_datar > 0.1

	if not bergerak:
		if langkah_player.playing:
			langkah_player.stop()
		return

	var stream_target: AudioStream = sfx_sprint if sedang_lari else sfx_jalan
	# ganti suara saat pindah jalan <-> sprint, atau mulai lagi kalau sempat berhenti
	if langkah_player.stream != stream_target or not langkah_player.playing:
		langkah_player.stream = stream_target
		langkah_player.play()

func _mainkan_suara_pintu(target: Object, terbuka_sebelum) -> void:
	# hanya untuk objek yang punya variabel "sudah_terbuka" (pintu)
	if terbuka_sebelum == null:
		print("Interaksi dengan ", target, " (tidak punya sudah_terbuka, tanpa suara pintu)")
		return
	var terbuka_sesudah = target.get("sudah_terbuka")
	if terbuka_sebelum and terbuka_sesudah:
		return  # sudah terbuka dari tadi, tanpa suara
	if terbuka_sesudah:
		pintu_player.stream = sfx_pintu_buka   # tertutup -> terbuka
		print("Suara pintu: buka")
	elif terbuka_sebelum:
		pintu_player.stream = sfx_pintu_tutup  # terbuka -> sedang ditutup
		print("Suara pintu: tutup")
	else:
		pintu_player.stream = sfx_pintu_tutup  # tetap tertutup = terkunci
		print("Suara pintu: terkunci")
	pintu_player.play()


# =====================================================================
# TERTANGKAP GURU (TAMBAHAN)
# Dipanggil dari guru.gd saat guru berhasil nangkep player.
# =====================================================================
func tertangkap(guru: Node3D) -> void:
	if is_caught:
		return
	is_caught = true
	guru_penangkap = guru
	velocity = Vector3.ZERO
	stamina_habis = false
	if langkah_player and langkah_player.playing:
		langkah_player.stop()
	_set_hud_visible(false)
	print("Player ketangkap oleh: ", guru.name)
	_ke_layar_tangkap()


func _ke_layar_tangkap() -> void:
	await get_tree().create_timer(delay_layar_tangkap).timeout
	LayarTangkap.pindah_ke_layar(get_tree())


# Panggil ini kalau nanti mau melepas player (respawn / restart dll)
func bebas() -> void:
	is_caught = false
	guru_penangkap = null
	_set_hud_visible(true)


# Sembunyikan / tampilkan HUD. Stamina bar & prompt "E" otomatis.
# HUD lain (HP, crosshair, dll): masukkan node-nya ke Group "hud".
func _set_hud_visible(tampil: bool) -> void:
	if stamina_root and stamina_root.get_parent():
		stamina_root.get_parent().visible = tampil   # CanvasLayer stamina bar
	if prompt_label and not tampil:
		prompt_label.visible = false
	for n in get_tree().get_nodes_in_group("hud"):
		if "visible" in n:
			n.visible = tampil


func _proses_tertangkap(delta: float) -> void:
	# diam di tempat (gravitasi tetap jalan biar ga melayang)
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if langkah_player and langkah_player.playing:
		langkah_player.stop()
	if prompt_label:
		prompt_label.visible = false

	# kamera kembali halus ke posisi awal (tanpa bobbing)
	if camera:
		camera.position = camera.position.lerp(camera_base_pos, 10.0 * delta)

	# menoleh halus ke kepala guru
	if guru_penangkap == null or not is_instance_valid(guru_penangkap) or camera == null:
		return

	var titik_lihat := guru_penangkap.global_position + Vector3(0, guru_head_height, 0)
	var arah := titik_lihat - camera.global_position
	var jarak_datar := Vector2(arah.x, arah.z).length()
	if jarak_datar < 0.001:
		return

	var t := clampf(look_at_guru_speed * delta, 0.0, 1.0)

	# yaw (kiri-kanan) -> badan player. Depan = -Z
	var yaw_target := atan2(-arah.x, -arah.z)
	rotation.y = lerp_angle(rotation.y, yaw_target, t)

	# pitch (atas-bawah) -> kamera
	var pitch_target := clampf(atan2(arah.y, jarak_datar), deg_to_rad(-80.0), deg_to_rad(80.0))
	camera.rotation.x = lerpf(camera.rotation.x, pitch_target, t)
	camera.rotation.y = 0.0
	camera.rotation.z = 0.0


# =====================================================================
# ANIMASI JALAN / LARI MODEL SISWA (TAMBAHAN - kode di atas tidak diubah)
# Butuh AnimationPlayer di dalam model (siswa.glb).
# =====================================================================
@export var anim_walk_base_speed: float = 2.2  # makin kecil = animasi jalan makin cepat
@export var anim_run_base_speed: float = 3.7   # makin kecil = animasi lari makin cepat
@export var anim_speed_scale_max: float = 1.8  # batas atas kecepatan putar animasi

var _anim_player: AnimationPlayer = null
var _anim_idle: StringName = &""
var _anim_walk: StringName = &""
var _anim_run: StringName = &""
var _anim_current: StringName = &""
var _anim_ready: bool = false


func _process(_delta: float) -> void:
	if is_cutscene: return
	if not _anim_ready:
		_setup_animation()
		return

	# di udara (lompat): biarkan animasi terakhir tetap berjalan
	if not is_on_floor():
		return

	var kecepatan := Vector2(velocity.x, velocity.z).length()
	var batas_lari := (speed + sprint_speed) * 0.5

	if kecepatan < 0.1:
		_play_anim(_anim_idle, 1.0)
	elif kecepatan >= batas_lari:
		_play_anim(_anim_run, clampf(kecepatan / anim_run_base_speed, 0.8, anim_speed_scale_max))
	else:
		_play_anim(_anim_walk, clampf(kecepatan / anim_walk_base_speed, 0.8, anim_speed_scale_max))


func _setup_animation() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		return
	_anim_idle = _find_anim("idle")
	_anim_walk = _find_anim("walk")
	_anim_run = _find_anim("run")
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


# ===== CUTSCENE =====
var is_cutscene: bool = false

func mulai_cutscene() -> void:
	is_cutscene = true
	velocity = Vector3.ZERO
	if langkah_player and langkah_player.playing:
		langkah_player.stop()
	_set_hud_visible(false)

func selesai_cutscene() -> void:
	is_cutscene = false
	_set_hud_visible(true)
	camera.make_current()
