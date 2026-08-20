extends CanvasLayer

@onready var inventory = $Inventory


func _ready():
	inventory.visible = false


func _process(delta):
	if Input.is_key_pressed(KEY_I):
		inventory.visible = !inventory.visible
		await get_tree().create_timer(0.2).timeout
