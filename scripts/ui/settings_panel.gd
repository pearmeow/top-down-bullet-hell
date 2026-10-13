extends PanelContainer

## Volume sliders and display toggles. Shared by the title screen and the pause menu.

signal closed

var first_control: Control

func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for bus in Settings.BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = {"Master": "Volume", "Music": "Music", "SFX": "Effects"}[bus]
		name_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.volumes[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)
		var percent := Label.new()
		percent.custom_minimum_size = Vector2(54, 0)
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		percent.text = "%d%%" % roundi(slider.value * 100.0)
		row.add_child(percent)
		slider.value_changed.connect(_volume_changed.bind(bus, percent))
		if first_control == null:
			first_control = slider
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	box.add_child(fullscreen)
	var shake := CheckButton.new()
	shake.text = "Screen shake"
	shake.button_pressed = Settings.screen_shake
	shake.toggled.connect(func(on: bool) -> void: Settings.screen_shake = on)
	box.add_child(shake)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	box.add_child(back)

func open() -> void:
	show()
	if first_control != null:
		first_control.grab_focus()

func close() -> void:
	Settings.save()
	hide()
	closed.emit()

func _volume_changed(value: float, bus: String, percent: Label) -> void:
	Settings.volumes[bus] = value
	Settings.apply()
	percent.text = "%d%%" % roundi(value * 100.0)
