extends CanvasLayer

@onready var slot_1: Panel = $KotakInventory/Slot1

func _process(_delta: float) -> void:
	# Slot 1: Kertas Soal
	if GameManager.jumlah_soal > 0:
		slot_1.modulate = Color(1, 1, 1, 1) # Terang
	else:
		slot_1.modulate = Color(1, 1, 1, 0.4) # Agak transparan kalau koson
