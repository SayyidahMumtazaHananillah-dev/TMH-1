extends Control

@onready var settings_panel = $SettingsPanel
@onready var credit_panel = $CreditPanel
@onready var exit_popup = $ExitPopup
@onready var click_sound = $ClickSound


func _ready():
	settings_panel.position.x = 1150
	credit_panel.position.x = 1150
	exit_popup.hide()


# =========================
# SETTINGS
# =========================

func _on_settings_pressed():
	click_sound.play()

	# Jika sedang terbuka, tutup
	if settings_panel.position.x == 773:
		var tween = create_tween()
		tween.tween_property(settings_panel, "position:x", 1150, 0.4)
		return

	# Tutup CreditPanel
	credit_panel.position.x = 1150

	# Buka SettingsPanel
	var tween = create_tween()
	tween.tween_property(settings_panel, "position:x", 773, 0.4)


func _on_closebutton_pressed():
	click_sound.play()

	var tween = create_tween()
	tween.tween_property(settings_panel, "position:x", 1150, 0.4)


# =========================
# CREDIT
# =========================

func _on_credit_pressed():
	click_sound.play()

	# Jika sedang terbuka, tutup
	if credit_panel.position.x == 773:
		var tween = create_tween()
		tween.tween_property(credit_panel, "position:x", 1150, 0.4)
		return

	# Tutup SettingsPanel
	settings_panel.position.x = 1150

	# Buka CreditPanel
	var tween = create_tween()
	tween.tween_property(credit_panel, "position:x", 773, 0.4)


func _on_closebuttoncredit_pressed():
	click_sound.play()

	var tween = create_tween()
	tween.tween_property(credit_panel, "position:x", 1150, 0.4)

func _on_music_slider_value_changed(value):
	var bus = AudioServer.get_bus_index("Music")

	if value == 0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(
			bus,
			linear_to_db(value / 100.0)
		)


func _on_exit_pressed() -> void:
	click_sound.play()
	exit_popup.show()


func _on_no_button_pressed():
	click_sound.play()
	exit_popup.hide()

func _on_yes_button_pressed():
	click_sound.play()
	await click_sound.finished
	get_tree().quit()
	
