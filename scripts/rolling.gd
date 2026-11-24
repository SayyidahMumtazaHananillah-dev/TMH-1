extends Area3D

# Tarik node pintu 3D (Mesh) kamu langsung ke kolom ini di Inspector
@export var node_pintu: Node3D

var player_dekat: bool = false
var sudah_terbuka: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if sudah_terbuka:
		return
	# Cek apakah yang mendekat adalah Player
	if body is CharacterBody3D or body.name.to_lower().contains("player"):
		player_dekat = true
		print(">>> Player berada di dekat pintu! Tekan E. <<<")

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.name.to_lower().contains("player"):
		player_dekat = false

func _input(event: InputEvent) -> void:
	if sudah_terbuka or not player_dekat:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if not GameManager.punya_linggis:
			print("🔒 Rolling door terkunci! Butuh CROWBAR untuk membukanya.")
			return

		sudah_terbuka = true
		player_dekat = false
		print(">>> PROSES MEMBUKA PINTU DENGAN CROWBAR... <<<")

		# Jika node_pintu diisi di Inspector, geser node_pintu tersebut.
		# Jika tidak, geser node ini sendiri.
		var target_node = node_pintu if node_pintu else self

		var tween = create_tween()
		tween.tween_property(target_node, "position:y", target_node.position.y + 5.0, 1.0)
