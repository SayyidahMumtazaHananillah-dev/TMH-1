extends AudioStreamPlayer

func _ready():
	finished.connect(_on_finished)
	play()

func _on_finished():
	play()
